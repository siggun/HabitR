import Foundation
import StoreKit

// Manages in-app subscription purchases using StoreKit 2
// StoreKit 2 uses modern async/await APIs instead of the older delegate pattern
@MainActor
final class StoreKitService: ObservableObject {
    static let shared = StoreKitService()

    // Product identifiers matching Products.storekit configuration
    private let productIDs = ["habitr.monthly", "habitr.yearly"]

    // Published properties automatically update any SwiftUI view observing this object
    @Published var products: [Product] = []
    @Published var isSubscribed: Bool = false
    @Published var purchaseError: String?

    // Task that listens for transaction updates (renewals, cancellations, etc.)
    private var transactionListener: Task<Void, Never>?

    private init() {
        transactionListener = listenForTransactions()
        // Check subscription status on init
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    /// Load available products from the App Store (or StoreKit config in testing)
    func loadProducts() async {
        do {
            products = try await Product.products(for: productIDs)
            // Sort so monthly appears first
            products.sort { $0.price < $1.price }
        } catch {
            print("Failed to load products: \(error)")
        }
    }

    /// Purchase a subscription product
    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                // StoreKit 2 automatically verifies the transaction
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await updateSubscriptionStatus()
                return true

            case .userCancelled:
                // User tapped cancel — not an error
                return false

            case .pending:
                // Transaction needs approval (e.g., Ask to Buy for kids)
                return false

            @unknown default:
                return false
            }
        } catch {
            purchaseError = error.localizedDescription
            return false
        }
    }

    /// Restore previous purchases — required by App Store guidelines
    func restorePurchases() async {
        try? await AppStore.sync()
        await updateSubscriptionStatus()
    }

    /// Check if the user has an active subscription
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

    // MARK: - Private Helpers

    /// Verify a transaction's authenticity
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreKitError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    /// Listen for transaction updates in the background
    /// Handles renewals, cancellations, and revocations
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

// Custom error type for StoreKit verification failures
extension StoreKitError {
    static let failedVerification = NSError(
        domain: "StoreKitService",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Transaction verification failed"]
    ) as Error
}
