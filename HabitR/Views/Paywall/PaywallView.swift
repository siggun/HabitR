import SwiftUI
import StoreKit

// Paywall shown when the user tries to add a 4th habit without a subscription
// Displays benefits, pricing, and purchase/restore buttons
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = PaywallViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero section
                    heroSection

                    // Benefits list
                    benefitsSection

                    // Subscription options
                    productsSection

                    // Legal text — required by App Store
                    legalSection
                }
                .padding()
            }
            .navigationTitle("Upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.medium))
                    }
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
            .alert("Error", isPresented: showingError) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .onChange(of: viewModel.purchaseSucceeded) { _, succeeded in
                if succeeded { dismiss() }
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.accentColor)

            Text("Unlock Unlimited Habits")
                .font(.title2)
                .fontWeight(.bold)

            Text("You've reached the 3-habit free limit.\nUpgrade to track as many habits as you want.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 10)
    }

    // MARK: - Benefits

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BenefitRow(icon: "infinity", text: "Unlimited habits")
            BenefitRow(icon: "flame.fill", text: "Track all your streaks")
            BenefitRow(icon: "chart.bar.fill", text: "Full progress history")
            BenefitRow(icon: "heart.fill", text: "Support indie development")
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Products

    private var productsSection: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.products, id: \.id) { product in
                ProductButton(product: product) {
                    Task { await viewModel.purchase(product) }
                }
            }

            // Restore purchases button — required by App Store guidelines
            Button {
                Task { await viewModel.restorePurchases() }
            } label: {
                Text("Restore Purchases")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Legal

    private var legalSection: some View {
        Text("Subscriptions auto-renew unless cancelled at least 24 hours before the end of the current period. Manage subscriptions in Settings > Apple ID > Subscriptions.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
    }

    // MARK: - Helpers

    private var showingError: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

// MARK: - Supporting Views

/// A row in the benefits list
struct BenefitRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)

            Text(text)
                .font(.body)
        }
    }
}

/// A button for a subscription product showing name and price
struct ProductButton: View {
    let product: Product
    let action: () -> Void

    private var isYearly: Bool {
        product.id == "habitr.yearly"
    }

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.displayName)
                        .font(.headline)
                    if isYearly {
                        Text("Save 44%")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }
                }

                Spacer()

                Text(product.displayPrice)
                    .font(.headline)
                    + Text(isYearly ? "/year" : "/month")
                    .font(.caption)
            }
            .padding()
            .background(isYearly ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isYearly ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
