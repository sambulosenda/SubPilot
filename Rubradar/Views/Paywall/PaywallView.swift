//
//  PaywallView.swift
//  Rubradar
//

import SwiftUI
import SwiftData
import StoreKit

/// The Pro upsell. Presented as a single `.sheet(item:)` host in `RootView`,
/// driven by `PurchaseManager.paywallContext`. The `context` only tailors the
/// headline/subtitle — every entry point sells the same Pro unlock.
struct PaywallView: View {
    let context: PaywallContext

    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    /// Selected product id. Defaults to annual (the value option we steer toward).
    @State private var selectedID = PurchaseManager.ProductID.annual

    /// Apple-hosted standard EULA. Privacy policy URL is set once the policy is hosted.
    private let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    private let privacyURL = URL(string: "https://gist.github.com/sambulosenda/744ff503ade4a19c0a4ac298160248f9")!

    private let benefits: [(symbol: String, text: String)] = [
        ("infinity", String(localized: "Track unlimited subscriptions")),
        ("doc.viewfinder", String(localized: "Scan receipts on device")),
        ("doc.badge.arrow.up", String(localized: "Import bank statements")),
        ("sparkles", String(localized: "Ask the on-device assistant")),
        ("person.2.fill", String(localized: "Separate work & personal profiles"))
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
        .task {
            let activeCount = (try? modelContext.fetchCount(
                FetchDescriptor<Subscription>(predicate: #Predicate { !$0.isCancelled })
            )) ?? 0
            Analytics.paywallShown(context: context, activeCount: activeCount)
            await purchases.loadProducts()
        }
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
                        badge: product.id == PurchaseManager.ProductID.annual ? annualSavingsBadge : nil,
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

    /// Percentage saved by paying annually vs. 12× the monthly price (e.g. "SAVE 58%").
    /// Computed from the live products so it stays correct if prices change.
    private var annualSavingsBadge: String? {
        guard let monthly = purchases.product(for: PurchaseManager.ProductID.monthly),
              let annual = purchases.product(for: PurchaseManager.ProductID.annual) else { return nil }
        let yearlyAtMonthlyRate = monthly.price * 12
        guard yearlyAtMonthlyRate > 0 else { return nil }
        let fractionSaved = (yearlyAtMonthlyRate - annual.price) / yearlyAtMonthlyRate
        let percent = Int((NSDecimalNumber(decimal: fractionSaved).doubleValue * 100).rounded())
        guard percent > 0 else { return nil }
        return String(localized: "SAVE \(percent)%")
    }

    private var ctaTitle: String {
        if let product = selectedProduct, hasFreeTrial(product) { return String(localized: "Start Free Trial") }
        return String(localized: "Unlock Pro")
    }

    private func buySelected() {
        guard let product = selectedProduct else { return }
        Task { await purchases.purchase(product) }
    }

    private func tierName(_ product: Product) -> String {
        switch product.id {
        case PurchaseManager.ProductID.monthly:  return String(localized: "Monthly")
        case PurchaseManager.ProductID.annual:   return String(localized: "Annual")
        case PurchaseManager.ProductID.lifetime: return String(localized: "Lifetime")
        default:                                 return product.displayName
        }
    }

    /// A short pricing line beneath each tier's name.
    private func detail(for product: Product) -> String {
        switch product.id {
        case PurchaseManager.ProductID.monthly:
            return String(localized: "\(product.displayPrice) / month")
        case PurchaseManager.ProductID.annual:
            if hasFreeTrial(product) {
                return String(localized: "7 days free, then \(product.displayPrice) / year")
            }
            return String(localized: "\(product.displayPrice) / year")
        case PurchaseManager.ProductID.lifetime:
            return String(localized: "\(product.displayPrice) · pay once")
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
    let badge: String?
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
                Spacer(minLength: Spacing.sm)
                if let badge {
                    Text(badge)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 3)
                        .background(.tint, in: .capsule)
                        .foregroundStyle(.white)
                }
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
        .accessibilityLabel(badge.map { "\(tier), \(detail), \($0)" } ?? "\(tier), \(detail)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    PaywallView(context: .subscriptionLimit)
        .environment(PurchaseManager.preview(isPro: false))
}
