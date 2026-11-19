//
//  InsightsView.swift
//  Rubradar
//

import SwiftUI
import SwiftData
import Charts

/// Spend analytics for the selected profile: where the monthly money goes
/// (category donut + ranked breakdown) and what's coming up (per-month charge
/// forecast). Derives entirely from existing subscription data — no extra store.
struct InsightsView: View {
    @Query(animation: .default) private var subscriptions: [Subscription]
    @Environment(CurrencyService.self) private var currency
    @AppStorage("preferredCurrencyCode") private var preferredCurrency =
        Locale.current.currency?.identifier ?? "GBP"
    @AppStorage("selectedProfileID") private var selectedProfileID = ""

    /// Starts an add from the empty state (routed through the shell's gates).
    var onAdd: () -> Void = {}

    @State private var selected: CategorySpend?
    @State private var showRecap = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Active + cancelled subs in the selected profile ("" = All); the breakdown
    /// itself drops cancelled, so totals match the Home hero.
    private var profileSubscriptions: [Subscription] {
        subscriptions.filter { $0.belongsToProfile(id: selectedProfileID) }
    }

    private var breakdown: SpendBreakdown {
        SpendBreakdown.make(from: profileSubscriptions, preferred: preferredCurrency, rates: currency.rates)
    }

    private var upcomingMonths: [RenewalMonth] {
        let events = RenewalProjector.events(for: profileSubscriptions, horizonMonths: 6)
        return Array(RenewalMonth.group(events, preferred: preferredCurrency, rates: currency.rates).prefix(6))
    }

    var body: some View {
        ScrollView {
            if breakdown.isEmpty {
                ContentUnavailableView {
                    Label("No spend to chart yet", systemImage: "chart.pie")
                } description: {
                    Text("Add an active subscription to see where your money goes each month.")
                } actions: {
                    Button("Add a subscription", action: onAdd)
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                }
                .padding(.top, Spacing.xl)
            } else {
                VStack(spacing: Spacing.md) {
                    statTiles
                        .appearEntrance(0)
                    categoryCard
                        .appearEntrance(1)
                    if !ranked.isEmpty {
                        rankedCard
                    }
                    if !upcomingMonths.isEmpty {
                        forecastCard
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.md)
            }
        }
        .background(Color.appBackground)
        .navigationTitle("Insights")
        // Large, like Settings: the two tabs with a plain title now share one
        // treatment. Home and Calendar keep their own headers on purpose.
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if !breakdown.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showRecap = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share monthly recap")
                }
            }
        }
        .sheet(isPresented: $showRecap) {
            RecapShareView(data: MonthlyRecapData.make(
                from: profileSubscriptions,
                preferred: preferredCurrency,
                rates: currency.rates
            ))
        }
    }

    // MARK: - Headline figures

    /// Active subscriptions, each with its monthly cost in the preferred
    /// currency, dearest first. Unconvertible ones are left out, as in the
    /// breakdown.
    private var ranked: [RankedSpend] {
        profileSubscriptions
            .filter { !$0.isCancelled }
            .compactMap { sub in
                currency.rates.convert(sub.monthlyEquivalent, from: sub.currencyCode, to: preferredCurrency)
                    .map { RankedSpend(subscription: sub, monthly: $0) }
            }
            .sorted { $0.monthly > $1.monthly }
    }

    private var statTiles: some View {
        // Side by side normally; stacked at accessibility text sizes, where
        // half the width broke "Subscriptions" across two lines.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: Spacing.md))
            : AnyLayout(HStackLayout(spacing: Spacing.md))
        return layout {
            StatTile(title: "Yearly", value: breakdown.format(breakdown.monthlyTotal * 12))
            StatTile(title: "Subscriptions",
                     value: profileSubscriptions.filter { !$0.isCancelled }.count.formatted())
        }
    }

    /// The five dearest subscriptions, each bar scaled to the top one: the
    /// answer to "what should I look at first?" that the category split
    /// can't give.
    private var rankedCard: some View {
        let top = Array(ranked.prefix(5))
        let peak = top.first?.monthly ?? 0
        return InsightCard(title: "Your subscriptions") {
            VStack(spacing: Spacing.md) {
                ForEach(top) { item in
                    RankedSpendRow(item: item,
                                   amount: breakdown.format(item.monthly),
                                   fraction: peak > 0
                                       ? NSDecimalNumber(decimal: item.monthly / peak).doubleValue
                                       : 0)
                }
            }
        }
    }

    // MARK: - Spend by category

    private var categoryCard: some View {
        InsightCard(title: "Where your money goes") {
            CategoryDonut(breakdown: breakdown, selected: $selected)

            if breakdown.hasUnconvertible {
                Label("Some charges use a currency without a known rate and are excluded.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: Spacing.sm) {
                ForEach(breakdown.categories) { slice in
                    CategoryLegendRow(
                        slice: slice,
                        breakdown: breakdown,
                        isSelected: selected?.id == slice.id
                    ) {
                        // Tap to focus a slice; tap again to clear.
                        selected = selected?.id == slice.id ? nil : slice
                    }
                }
            }
        }
    }

    // MARK: - Upcoming charges

    private var forecastCard: some View {
        InsightCard(title: "Upcoming charges") {
            Text("Projected total per month, next 6 months")
                .font(.caption)
                .foregroundStyle(.secondary)
            UpcomingChargesChart(months: upcomingMonths)
        }
    }
}

// MARK: - Category donut

/// Interactive donut of monthly spend by category. The hole shows the total, or
/// the focused slice's amount + share when one is selected (via tap or scrub).
private struct CategoryDonut: View {
    let breakdown: SpendBreakdown
    @Binding var selected: CategorySpend?
    @State private var selectedAngle: Double?

    var body: some View {
        Chart(breakdown.categories) { slice in
            SectorMark(
                angle: .value("Spend", amount(slice)),
                innerRadius: .ratio(0.68),
                angularInset: 2
            )
            .cornerRadius(6)
            .foregroundStyle(by: .value("Category", slice.category.label))
            .opacity(selected == nil || selected?.id == slice.id ? 1 : 0.3)
        }
        .chartForegroundStyleScale(
            domain: breakdown.categories.map(\.category.label),
            range: breakdown.categories.map(\.category.tint)
        )
        .chartLegend(.hidden)
        .chartAngleSelection(value: $selectedAngle)
        .onChange(of: selectedAngle) { _, value in
            selected = category(at: value)
        }
        .frame(height: 220)
        .overlay { center.allowsHitTesting(false) }
        .animation(.easeInOut(duration: 0.2), value: selected?.id)
        .accessibilityLabel("Monthly spend by category")
        .accessibilityValue(breakdown.categories
            .map { "\($0.category.label) \(breakdown.format($0.monthlyAmount))" }
            .joined(separator: ", "))
    }

    private var center: some View {
        VStack(spacing: 2) {
            if let selected {
                Text(selected.category.label)
                    .font(.subheadline.weight(.semibold))
                Text(breakdown.format(selected.monthlyAmount))
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .contentTransition(.numericText())
                Text(selected.fraction.formatted(.percent.precision(.fractionLength(0))))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Per month")
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Text(breakdown.formattedTotal)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .contentTransition(.numericText())
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .padding(.horizontal, Spacing.lg)
        // The hole is a fixed size, so its text can't grow without limit:
        // past this it ran over the ring.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private func amount(_ slice: CategorySpend) -> Double {
        NSDecimalNumber(decimal: slice.monthlyAmount).doubleValue
    }

    /// Maps a selected cumulative angle value back to the slice that contains it.
    private func category(at value: Double?) -> CategorySpend? {
        guard let value, value >= 0 else { return nil }
        var cumulative = 0.0
        for slice in breakdown.categories {
            cumulative += amount(slice)
            if value <= cumulative { return slice }
        }
        return nil
    }
}

// MARK: - Legend row

/// A ranked category row: colour swatch, label, share + amount, and a thin
/// proportion bar. Tapping focuses the matching donut slice.
private struct CategoryLegendRow: View {
    let slice: CategorySpend
    let breakdown: SpendBreakdown
    let isSelected: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(slice.category.tint)
                        .frame(width: 10, height: 10)
                    Text(slice.category.label)
                        .font(.subheadline.weight(isSelected ? .semibold : .regular))
                        // Shrink before breaking mid-word ("Soft-ware").
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Spacer(minLength: Spacing.sm)
                    Text(slice.fraction.formatted(.percent.precision(.fractionLength(0))))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(breakdown.format(slice.monthlyAmount))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }

                Capsule()
                    .fill(.quaternary)
                    .frame(height: 4)
                    .overlay(alignment: .leading) {
                        GeometryReader { geo in
                            Capsule()
                                .fill(slice.category.tint)
                                .frame(width: geo.size.width * slice.fraction)
                        }
                    }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(slice.category.label), \(breakdown.format(slice.monthlyAmount)), \(slice.fraction.formatted(.percent.precision(.fractionLength(0)))) of spend")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Forecast bar chart

/// Per-month projected charges for the next few months. Scrub a bar to read its
/// exact total.
private struct UpcomingChargesChart: View {
    let months: [RenewalMonth]
    @State private var selectedLabel: String?

    /// Months go on a category axis, not a date one. On a date axis each bar
    /// sits at its month's midpoint, and months of 28 to 31 days put the bars
    /// at visibly uneven gaps.
    private func label(_ month: RenewalMonth) -> String {
        month.id.formatted(.dateTime.month(.abbreviated))
    }

    var body: some View {
        Chart(months) { month in
            let name = label(month)
            BarMark(
                x: .value("Month", name),
                y: .value("Charges", total(month)),
                width: .ratio(0.62)
            )
            .foregroundStyle(
                LinearGradient(colors: [.brand, .brand.opacity(0.55)], startPoint: .top, endPoint: .bottom)
            )
            .cornerRadius(7)
            .opacity(selectedLabel == nil || selectedLabel == name ? 1 : 0.35)
            .annotation(position: .top, spacing: 4) {
                if selectedLabel == name {
                    Text(month.formattedTotal)
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                }
            }
            .accessibilityLabel(month.title)
            .accessibilityValue(month.formattedTotal)
        }
        .chartXSelection(value: $selectedLabel)
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.quaternary)
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(amount.formatted(.number.notation(.compactName)))
                    }
                }
            }
        }
        .frame(height: 180)
        .animation(.easeInOut(duration: 0.2), value: selectedLabel)
        .accessibilityLabel("Projected charges per month")
        .accessibilityValue(months
            .map { "\($0.title) \($0.formattedTotal)" }
            .joined(separator: ", "))
    }

    private func total(_ month: RenewalMonth) -> Double {
        NSDecimalNumber(decimal: month.total).doubleValue
    }
}

// MARK: - Headline tiles and ranking

/// One subscription's monthly cost in the preferred currency.
private struct RankedSpend: Identifiable {
    let subscription: Subscription
    let monthly: Decimal
    var id: PersistentIdentifier { subscription.persistentModelID }
}

/// A small figure-over-label tile for the top of the screen.
private struct StatTile: View {
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(Color.cardBackground, in: .rect(cornerRadius: Radius.card))
        .accessibilityElement(children: .combine)
    }
}

/// A subscription with its monthly cost and a bar scaled to the dearest one.
private struct RankedSpendRow: View {
    let item: RankedSpend
    let amount: String
    let fraction: Double

    var body: some View {
        HStack(spacing: Spacing.md) {
            BrandLogoView(subscription: item.subscription, size: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.subscription.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Spacer(minLength: Spacing.sm)
                    Text(amount)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .fixedSize()
                }
                Capsule()
                    .fill(.quaternary)
                    .frame(height: 4)
                    .overlay(alignment: .leading) {
                        GeometryReader { geo in
                            Capsule()
                                .fill(Color.brand)
                                .frame(width: geo.size.width * fraction)
                        }
                    }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Card container

/// A titled card matching the Home dashboard's surface treatment.
private struct InsightCard<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(title)
                .font(.headline)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(Color.cardBackground, in: .rect(cornerRadius: Radius.card))
    }
}

#Preview {
    NavigationStack {
        InsightsView()
            .modelContainer(.preview)
            .environment(CurrencyService())
    }
}
