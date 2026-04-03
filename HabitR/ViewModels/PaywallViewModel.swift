import Foundation
import StoreKit

// ViewModel for the PaywallView — handles subscription purchase and restore flows
@MainActor
final class PaywallViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var purchaseSucceeded = false

    private let storeKit = StoreKitService.shared

    /// Available subscription products
    var products: [Product] {
        storeKit.products
    }

    /// Purchase a subscription product
    func purchase(_ product: Product) async {
        isLoading = true
        errorMessage = nil

        let success = await storeKit.purchase(product)

        isLoading = false
        if success {
            purchaseSucceeded = true
        } else if let error = storeKit.purchaseError {
            errorMessage = error
        }
    }

    /// Restore previous purchases
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
