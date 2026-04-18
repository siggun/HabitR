import Foundation
import StoreKit

/// View model backing `PaywallView`.
///
/// Acts as a thin coordination layer on top of `StoreKitService`, translating async purchase /
/// restore calls into observable UI state (loading spinner, error banner, success dismissal).
///
/// Why the extra indirection over calling `StoreKitService` directly from the view?
/// - The service is a singleton that also tracks long-lived state (subscription status, product
///   catalog) used across the app. Binding the paywall UI to it directly would couple every view
///   update to unrelated state changes. This VM owns only the paywall's transient concerns.
/// - Keeps the view dumb: no async/await plumbing, no error string translation — just reads
///   published properties and dispatches intents.
///
/// Threading: `@MainActor` because all `@Published` mutations must occur on the main thread in
/// order for SwiftUI to consume them without warnings.
@MainActor
final class PaywallViewModel: ObservableObject {
    /// `true` while a purchase or restore is in flight. Drives the spinner and disables buttons
    /// to prevent duplicate submissions.
    @Published var isLoading = false

    /// User-facing error copy. `nil` when no error is being surfaced. The view watches this and
    /// renders an error banner when non-nil.
    @Published var errorMessage: String?

    /// Flips to `true` on a successful purchase or restore. The view observes this to dismiss
    /// itself — we use a flag rather than a completion closure so SwiftUI's declarative sheet
    /// dismissal stays idiomatic.
    @Published var purchaseSucceeded = false

    /// Shared StoreKit coordinator. Injected via singleton for simplicity; a real test suite
    /// would parameterize this through the initializer to substitute a mock.
    private let storeKit = StoreKitService.shared

    /// Products offered on the paywall. Sourced straight from the service so the catalog stays
    /// in sync if it reloads (e.g., after a network reachability change).
    var products: [Product] {
        storeKit.products
    }

    /// Attempt to purchase `product`.
    ///
    /// Contract:
    /// - Sets `isLoading = true` for the duration of the call.
    /// - On success, flips `purchaseSucceeded` so the view dismisses.
    /// - On failure, surfaces `storeKit.purchaseError` via `errorMessage` (nil-safe: a silent
    ///   cancellation — user tapped "Cancel" in the sheet — yields no error and no success).
    func purchase(_ product: Product) async {
        isLoading = true
        errorMessage = nil

        // [Interview] `await` here suspends this function, yielding the actor. UIKit/SwiftUI
        // stay responsive while StoreKit brokers the sheet and network calls.
        let success = await storeKit.purchase(product)

        isLoading = false
        if success {
            purchaseSucceeded = true
        } else if let error = storeKit.purchaseError {
            errorMessage = error
        }
        // [Interview] Third branch — !success && no error — is user cancellation. Deliberately
        // silent: interrupting the user with a banner after they chose "Cancel" is bad UX.
    }

    /// Restore previously-purchased subscriptions. Required by App Store Review Guideline 3.1.1.
    ///
    /// After the underlying `AppStore.sync()` completes, we re-read the subscription flag. If
    /// the user has no active entitlement, we surface a benign "none found" message rather than
    /// an error — this path is frequently hit by users who just wanted to confirm.
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil

        await storeKit.restorePurchases()

        isLoading = false
        if storeKit.isSubscribed {
            purchaseSucceeded = true
        } else {
            errorMessage = "No active subscription found."
        }
    }
}
