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
    @Environment(CurrencyService.self) private var currency
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    /// Backs the personalised onboarding hero — the user's own spend, the
    /// strongest argument the paywall has. Scoped to the selected profile +
    /// preferred currency so it matches the Home dashboard exactly.
    @Query private var subscriptions: [Subscription]
    @AppStorage("preferredCurrencyCode") private var preferredCurrency =
        Locale.current.currency?.identifier ?? "GBP"
    @AppStorage("selectedProfileID") private var selectedProfileID = ""

    /// Selected product id. Defaults to annual (the value option we steer toward).
    @State private var selectedID = PurchaseManager.ProductID.annual

    /// Apple-hosted standard EULA; privacy policy on the marketing site.
    private let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    private let privacyURL = URL(string: "https://subhelm.app/privacy/")!

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
                    hero.appearEntrance(0)
                    benefitList.appearEntrance(1)
                    productSection.appearEntrance(2)
                    legal.appearEntrance(3)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.lg)
            }
            .background(alignment: .top) { heroAmbience }
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
        // Failed/pending purchases and empty restores must never end in
        // silence — the user just tried to pay.
        .alert(
            purchases.feedback?.title ?? "",
            isPresented: Binding(
                get: { purchases.feedback != nil },
                set: { if !$0 { purchases.feedback = nil } }
            ),
            presenting: purchases.feedback
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { feedback in
            Text(feedback.message)
        }
    }

    // MARK: - Hero

    /// A quiet brand backdrop behind the hero: a soft teal glow bleeding from the
    /// top plus a faint oversized app mark. Ambient only — type-free, low-contrast,
    /// non-interactive — so it lifts the hero without adding any chrome.
    private var heroAmbience: some View {
        ZStack(alignment: .top) {
            RadialGradient(
                colors: [.brand.opacity(0.18), .brand.opacity(0)],
                center: .top,
                startRadius: 0,
                endRadius: 340
            )
            RecurraMarkView(size: 260, style: .plain, tint: .brand, animated: false)
                .opacity(0.06)
                .offset(y: 56)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 380, alignment: .top)
        .allowsHitTesting(false)
        .ignoresSafeArea(edges: .top)
    }

    private var hero: some View {
        let pitch = onboardingPitch   // computed once per render
        return VStack(spacing: Spacing.md) {
            Image(systemName: "crown.fill")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 76, height: 76)
                .background(
                    LinearGradient(
                        colors: [.brand, .brandDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: .circle
                )
                .shadow(color: .brand.opacity(0.3), radius: 12, y: 6)
                .accessibilityHidden(true)

            VStack(spacing: Spacing.sm) {
                heroHeadline(pitch)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                heroSubtitle(pitch)
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
            VStack(spacing: Spacing.md) {
                ForEach(purchases.products, id: \.id) { product in
                    ProductOptionRow(
                        tier: tierName(product),
                        caption: planCaption(for: product),
                        priceAmount: priceAmount(for: product),
                        pricePeriod: pricePeriod(for: product),
                        ribbon: product.id == PurchaseManager.ProductID.annual ? annualSavingsBadge : nil,
                        isRecommended: product.id == PurchaseManager.ProductID.annual,
                        isSelected: product.id == selectedID
                    ) {
                        selectedID = product.id
                    }
                }
            }
            .sensoryFeedback(.selection, trigger: selectedID)
        }
    }

    // MARK: - Purchase bar

    private var purchaseBar: some View {
        VStack(spacing: Spacing.sm) {
            // Guideline 3.1.2(c): the billed amount must be the most clear and
            // conspicuous pricing element in the flow, so it sits bold and primary
            // right above the CTA; the trial rides below it as a subordinate caption.
            if let product = selectedProduct {
                VStack(spacing: 2) {
                    Text(billedAmountLine(for: product))
                        .font(.title3.bold())
                    if hasFreeTrial(product) {
                        Text("after your 7-day free trial")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }

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

            // First-run upsell stays soft: an explicit, low-friction exit into
            // the free tier so the paywall never reads as a forced wall.
            if context == .onboarding {
                Button("Maybe later") { dismiss() }
                    .font(.subheadline)
                    .controlSize(.large)
                    .padding(.top, 2)
            }
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

    // MARK: - Personalised onboarding copy

    /// The data behind the personalised onboarding hero, derived in one pass
    /// (scoped + converted exactly like the Home dashboard). `nil` outside the
    /// onboarding context or when there's no real total to lead with.
    private struct OnboardingPitch { let yearly: String; let count: Int }

    private var onboardingPitch: OnboardingPitch? {
        guard context == .onboarding else { return nil }
        let scoped = subscriptions.filter { $0.belongsToProfile(id: selectedProfileID) }
        let count = scoped.filter { !$0.isCancelled }.count
        let summary = SpendSummary.make(from: scoped, preferred: preferredCurrency, rates: currency.rates)
        guard count > 0, summary.monthlyTotal > 0 else { return nil }
        return OnboardingPitch(yearly: summary.formattedYearly, count: count)
    }

    /// Hero copy returned as `Text` so the personalised onboarding subtitle can
    /// use automatic grammar agreement (`^[…](inflect: true)`) for correct
    /// per-locale pluralisation — the markup is only applied through `Text`'s
    /// `LocalizedStringKey`, not `String(localized:)`. Matches the convention
    /// used elsewhere in the app. Falls back to the context's generic copy.
    private func heroHeadline(_ pitch: OnboardingPitch?) -> Text {
        guard let pitch else { return Text(context.headline) }
        return Text("You're spending \(pitch.yearly) a year")
    }

    private func heroSubtitle(_ pitch: OnboardingPitch?) -> Text {
        guard let pitch else { return Text(context.subtitle) }
        return Text("Across ^[\(pitch.count) subscription](inflect: true). We'll remind you before every renewal.")
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

    /// CTA copy stays price/trial-neutral — the billed amount directly above the
    /// button carries the pricing (Guideline 3.1.2(c)).
    private var ctaTitle: String {
        guard let product = selectedProduct,
              product.id != PurchaseManager.ProductID.lifetime else {
            return String(localized: "Unlock Pro")
        }
        return String(localized: "Subscribe")
    }

    /// The total billed amount for the selected plan, spelled out with its
    /// billing period — the loudest pricing element on the screen.
    private func billedAmountLine(for product: Product) -> String {
        switch product.id {
        case PurchaseManager.ProductID.monthly:
            return String(localized: "\(product.displayPrice) per month")
        case PurchaseManager.ProductID.annual:
            return String(localized: "\(product.displayPrice) per year")
        case PurchaseManager.ProductID.lifetime:
            return String(localized: "\(product.displayPrice) one-time")
        default:
            return product.displayPrice
        }
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

    /// The prominent price figure for a plan row: always the *actual billed
    /// amount* (App Store Guideline 3.1.2(c) — the charged price must be the most
    /// clear and conspicuous pricing element). The calculated per-month figure is
    /// demoted to the subordinate caption.
    private func priceAmount(for product: Product) -> String {
        product.displayPrice
    }

    /// The small unit beside the billed amount — matched to the billing period.
    /// Empty for the one-time Lifetime.
    private func pricePeriod(for product: Product) -> String {
        switch product.id {
        case PurchaseManager.ProductID.monthly:
            return String(localized: "/mo")
        case PurchaseManager.ProductID.annual:
            return String(localized: "/year")
        default:
            return ""
        }
    }

    /// The supporting line under the tier name — the calculated per-month
    /// equivalent first, trial last, kept subordinate in size and colour to the
    /// billed amount beside it (Guideline 3.1.2(c): never lead with the trial).
    /// Word joiner (U+2060) keeps "$1.67/mo" from wrapping mid-unit.
    private func planCaption(for product: Product) -> String? {
        switch product.id {
        case PurchaseManager.ProductID.monthly:
            return nil
        case PurchaseManager.ProductID.annual:
            let perMonth = (product.price / 12).formatted(product.priceFormatStyle)
            return hasFreeTrial(product)
                ? String(localized: "≈\(perMonth)/\u{2060}mo · 7 days free")
                : String(localized: "Just \(perMonth)/\u{2060}mo")
        case PurchaseManager.ProductID.lifetime:
            return String(localized: "One-time purchase")
        default:
            return nil
        }
    }

    private func hasFreeTrial(_ product: Product) -> Bool {
        product.subscription?.introductoryOffer?.paymentMode == .freeTrial
    }
}

// MARK: - Product option row

private struct ProductOptionRow: View {
    let tier: String
    let caption: String?
    let priceAmount: String
    let pricePeriod: String
    let ribbon: String?
    var isRecommended: Bool = false
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Spacing.md) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(tier)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if let caption {
                        Text(caption)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: Spacing.sm)

                // Price hierarchy: the figure is the loud element, the period quiet.
                // Right-aligned so the eye scans one column of prices down the list.
                VStack(alignment: .trailing, spacing: 3) {
                    if let ribbon {
                        Text(ribbon)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 3)
                            .background(.tint, in: .capsule)
                            .foregroundStyle(.white)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text(priceAmount)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.primary)
                        if !pricePeriod.isEmpty {
                            Text(pricePeriod)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Radius.card)
                    .fill(Color.cardBackground)
                    // Subtle brand wash on the chosen plan — richer than a bare border.
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.card)
                            .fill(.tint.opacity(isSelected ? 0.08 : 0))
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: Radius.card)
                    .strokeBorder(.tint, lineWidth: isSelected ? 2 : 0)
            }
            // Soft depth on every card so they lift off the background; the
            // recommended plan sits highest. Depth, not decoration.
            .shadow(color: .black.opacity(isRecommended ? 0.14 : 0.05),
                    radius: isRecommended ? 14 : 6, y: isRecommended ? 6 : 2)
            // Spring the border + brand wash in when a plan is picked, so the
            // selection reads as a deliberate change rather than a hard repaint.
            .animation(AppMotion.select, value: isSelected)
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            [tier,
             isRecommended ? String(localized: "Best value") : nil,
             caption,
             pricePeriod.isEmpty ? priceAmount : "\(priceAmount) \(pricePeriod)",
             ribbon]
                .compactMap { $0 }.joined(separator: ", ")
        )
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    PaywallView(context: .onboarding)
        .modelContainer(.preview)
        .environment(CurrencyService())
        .environment(PurchaseManager.preview(isPro: false))
}
