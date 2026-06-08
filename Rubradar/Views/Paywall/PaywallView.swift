//
//  PaywallView.swift
//  Rubradar
//

import SwiftUI
import StoreKit

/// The Pro upsell. Presented as a single `.sheet(item:)` host in `RootView`,
/// driven by `PurchaseManager.paywallContext`. The `context` only tailors the
/// headline/subtitle — every entry point sells the same Pro unlock.
struct PaywallView: View {
    let context: PaywallContext

    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    /// Selected product id. Defaults to annual (the value option we steer toward).
    @State private var selectedID = PurchaseManager.ProductID.annual

    /// Apple-hosted standard EULA. Privacy policy URL is set once the policy is hosted.
    private let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    private let privacyURL = URL(string: "https://sambulosenda.github.io/subpilot/privacy")!

    private let benefits: [(symbol: String, text: String)] = [
        ("infinity", "Track unlimited subscriptions"),
        ("doc.viewfinder", "Scan receipts on device"),
        ("doc.badge.arrow.up", "Import bank statements"),
        ("sparkles", "Ask the on-device assistant"),
        ("person.2.fill", "Separate work & personal profiles")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    hero
                    benefitList
                    productSection
                    legal
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.lg)
            }
            .background(Color.appBackground)
            .safeAreaInset(edge: .bottom) { purchaseBar }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .accessibilityLabel("Close")
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Restore") { Task { await purchases.restore() } }
                        .disabled(purchases.purchaseInProgress)
                }
            }
        }
        .task { await purchases.loadProducts() }
        .onChange(of: purchases.isPro) { _, isPro in
            // Dismiss once Pro is unlocked (purchase or restore).
            if isPro { dismiss() }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "crown.fill")
                .font(.system(size: 44))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
                .frame(width: 92, height: 92)
                .background(.tint.opacity(0.12), in: .circle)
                .accessibilityHidden(true)

            VStack(spacing: Spacing.sm) {
                Text(context.headline)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Text(context.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.sm)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Benefits

    private var benefitList: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ForEach(benefits, id: \.symbol) { benefit in
                HStack(spacing: Spacing.md) {
                    Image(systemName: benefit.symbol)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.tint)
                        .frame(width: 28)
                        .accessibilityHidden(true)
                    Text(benefit.text)
                        .font(.body)
                    Spacer(minLength: 0)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Products

    @ViewBuilder
    private var productSection: some View {
        if purchases.products.isEmpty {
            if purchases.isLoadingProducts {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, Spacing.lg)
            } else {
                VStack(spacing: Spacing.sm) {
                    Text("Couldn't load pricing.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Retry") { Task { await purchases.loadProducts() } }
                        .buttonStyle(.glass)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.lg)
            }
        } else {
            VStack(spacing: Spacing.sm) {
                ForEach(purchases.products, id: \.id) { product in
                    ProductOptionRow(
                        product: product,
                        tier: tierName(product),
                        detail: detail(for: product),
                        isSelected: product.id == selectedID
                    ) {
                        selectedID = product.id
                    }
                }
            }
        }
    }

    // MARK: - Purchase bar

    private var purchaseBar: some View {
        VStack(spacing: Spacing.sm) {
            Button(action: buySelected) {
                HStack(spacing: Spacing.xs) {
                    if purchases.purchaseInProgress {
                        ProgressView().tint(.white)
                    } else {
                        Text(ctaTitle)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.extraLarge)
            .disabled(purchases.purchaseInProgress || selectedProduct == nil)

            Text("Cancel anytime in the App Store.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.sm)
        .background(.bar)
    }

    private var legal: some View {
        VStack(spacing: Spacing.xs) {
            Text("Subscriptions renew automatically until cancelled. Lifetime is a one-time purchase. Payment is charged to your Apple Account.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: Spacing.md) {
                Button("Terms") { openURL(termsURL) }
                Button("Privacy") { openURL(privacyURL) }
            }
            .font(.caption2)
        }
        .padding(.top, Spacing.sm)
    }

    // MARK: - Derived

    private var selectedProduct: Product? { purchases.product(for: selectedID) }

    private var ctaTitle: String {
        if let product = selectedProduct, hasFreeTrial(product) { return "Start Free Trial" }
        return "Unlock Pro"
    }

    private func buySelected() {
        guard let product = selectedProduct else { return }
        Task { await purchases.purchase(product) }
    }

    private func tierName(_ product: Product) -> String {
        switch product.id {
        case PurchaseManager.ProductID.monthly:  return "Monthly"
        case PurchaseManager.ProductID.annual:   return "Annual"
        case PurchaseManager.ProductID.lifetime: return "Lifetime"
        default:                                 return product.displayName
        }
    }

    /// A short pricing line beneath each tier's name.
    private func detail(for product: Product) -> String {
        switch product.id {
        case PurchaseManager.ProductID.monthly:
            return "\(product.displayPrice) / month"
        case PurchaseManager.ProductID.annual:
            if hasFreeTrial(product) {
                return "7 days free, then \(product.displayPrice) / year"
            }
            return "\(product.displayPrice) / year"
        case PurchaseManager.ProductID.lifetime:
            return "\(product.displayPrice) · pay once"
        default:
            return product.displayPrice
        }
    }

    private func hasFreeTrial(_ product: Product) -> Bool {
        product.subscription?.introductoryOffer?.paymentMode == .freeTrial
    }
}

// MARK: - Product option row

private struct ProductOptionRow: View {
    let product: Product
    let tier: String
    let detail: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Spacing.md) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tier)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBackground, in: .rect(cornerRadius: Radius.card))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.card)
                    .strokeBorder(.tint, lineWidth: isSelected ? 2 : 0)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(tier), \(detail)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    PaywallView(context: .subscriptionLimit)
        .environment(PurchaseManager.preview(isPro: false))
}
