import Foundation
import StoreKit

/// Centralized coordinator for all in-app purchase (IAP) concerns.
///
/// Wraps StoreKit 2's async/await APIs and exposes a small, Swifty surface to the rest of the
/// app: "what can I buy", "buy this", "restore my purchases", "am I subscribed right now".
///
/// ## Why a singleton
/// IAP state is inherently app-global — multiple screens (home gate, paywall, settings) all need
/// to read the same subscription flag and observe the same product catalog. A singleton avoids
/// re-subscribing to `Transaction.updates` from each caller (that listener must run exactly once
/// per app launch to avoid duplicate-processing renewals).
///
/// ## Transaction verification
/// StoreKit 2 signs every transaction with the App Store's key. We treat `.unverified` results
/// as hard failures — see `checkVerified(_:)`. This prevents accepting a forged receipt and is
/// the recommended posture per Apple's "In-App Purchase" documentation.
///
/// ## Threading
/// `@MainActor` because the `@Published` properties feed SwiftUI. The long-lived transaction
/// listener is `Task.detached` so it doesn't inherit the actor and can receive updates off-main;
/// it then hops back to the main actor via `await self?.updateSubscriptionStatus()`.
@MainActor
final class StoreKitService: ObservableObject {
    /// App-wide shared instance. See "Why a singleton" above.
    static let shared = StoreKitService()

    /// Product identifiers. Must match the bundle IDs configured in `Products.storekit` (local
    /// testing) and in App Store Connect (production). A typo here silently yields an empty
    /// product list at runtime because `Product.products(for:)` returns only recognized IDs.
    private let productIDs = ["habitr.monthly", "habitr.yearly"]

    /// Subscription products fetched from the store, sorted ascending by price. Populated
    /// asynchronously in `loadProducts()` — callers must handle the empty-array case while the
    /// initial fetch is in flight.
    @Published var products: [Product] = []

    /// Whether the user currently holds an unexpired subscription. Refreshed after every
    /// purchase, restore, and automatic transaction update.
    @Published var isSubscribed: Bool = false

    /// User-facing error string from the last purchase attempt. `nil` when the most recent
    /// purchase succeeded or was cancelled (cancellation is not an error).
    @Published var purchaseError: String?

    /// Long-lived listener for `Transaction.updates`. Retained so we can cancel it in `deinit`
    /// — without cancellation, the Task would leak and keep the service alive indefinitely.
    private var transactionListener: Task<Void, Never>?

    private init() {
        // [Interview] Listener must start BEFORE any network/product calls. If it starts late,
        // we can miss renewal transactions that fire during app launch, leaving `isSubscribed`
        // stuck at `false` even though the subscription is active.
        transactionListener = listenForTransactions()

        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }

    deinit {
        // [Interview] Singletons never actually deinit under normal operation, but the cancel
        // call is defensive — Apple recommends always tearing down `Task.updates` listeners.
        transactionListener?.cancel()
    }

    // MARK: - Product Catalog

    /// Fetch product metadata (price, title, description) from the store.
    ///
    /// Sorted by price ascending so the cheapest plan (monthly) is shown first in the paywall.
    /// Silently no-ops on network failure — the paywall will show an empty state and the user
    /// can retry by re-opening the sheet.
    func loadProducts() async {
        do {
            products = try await Product.products(for: productIDs)
            products.sort { $0.price < $1.price }
        } catch {
            print("Failed to load products: \(error)")
        }
    }

    // MARK: - Purchase

    /// Initiate a purchase for `product`.
    ///
    /// Outcomes:
    /// - `.success(.verified)`  → finish the transaction, refresh subscription state, return `true`.
    /// - `.success(.unverified)` → treated as verification failure via `checkVerified`.
    /// - `.userCancelled`       → return `false` with no error surfaced.
    /// - `.pending`             → return `false`; caller may poll later (Ask to Buy / SCA flows).
    ///
    /// - Returns: `true` on a verified, finished purchase. `false` for any non-success path.
    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                // [Interview] `checkVerified` throws if the signature doesn't validate. Finishing
                // the transaction acknowledges receipt to StoreKit — skipping this would cause
                // StoreKit to re-deliver the transaction on every app launch.
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await updateSubscriptionStatus()
                return true

            case .userCancelled:
                // User dismissed the purchase sheet — not an error state.
                return false

            case .pending:
                // Parental approval / Strong Customer Authentication in progress. The transaction
                // will arrive later via `Transaction.updates` and our listener will finalize it.
                return false

            @unknown default:
                // Future enum case we don't know about yet — fail closed.
                return false
            }
        } catch {
            purchaseError = error.localizedDescription
            return false
        }
    }

    // MARK: - Restore

    /// Force a sync with the App Store and re-evaluate entitlements.
    ///
    /// Required by App Store Review Guideline 3.1.1 — users who reinstall the app or switch
    /// devices must be able to recover their subscription without paying again.
    func restorePurchases() async {
        try? await AppStore.sync()
        await updateSubscriptionStatus()
    }

    // MARK: - Entitlement Check

    /// Walk current entitlements and set `isSubscribed` based on whether any of our product IDs
    /// are active. Called after purchases, restores, and on every transaction update.
    ///
    /// `Transaction.currentEntitlements` returns only *currently valid* entitlements — it filters
    /// out expired subscriptions automatically, so a bare presence check is sufficient.
    func updateSubscriptionStatus() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if productIDs.contains(transaction.productID) {
                    isSubscribed = true
                    return
                }
            }
        }
        isSubscribed = false
    }

    // MARK: - Private

    /// Unwrap a StoreKit `VerificationResult`, throwing on unverified payloads.
    ///
    /// This is where receipt-tampering protection lives. Returning `false` / ignoring unverified
    /// results would let a jailbroken device spoof a purchase. Throwing forces the caller to
    /// treat unverified results as purchase failures.
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreKitError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    /// Subscribe to `Transaction.updates` for the lifetime of the process.
    ///
    /// This catches transactions that occur **outside** an in-app purchase flow: auto-renewals,
    /// cancellations, refunds, family-sharing grants, and Ask-to-Buy approvals. Without this
    /// listener, a renewal that lands while the app is running would not refresh `isSubscribed`
    /// until the next cold launch.
    ///
    /// `Task.detached` is used so the listener doesn't hold a strong reference to the main actor
    /// task stack. `[weak self]` prevents a retain cycle in case the service is ever released.
    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.updateSubscriptionStatus()
                }
            }
        }
    }
}

/// Custom `Error` attached to `StoreKitError` for use in `checkVerified(_:)`.
///
/// We bolt this onto the system namespace as a static rather than defining a brand-new type so
/// the call site reads `StoreKitError.failedVerification` — matching the ergonomics of the other
/// StoreKit errors.
extension StoreKitError {
    static let failedVerification = NSError(
        domain: "StoreKitService",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Transaction verification failed"]
    ) as Error
}
