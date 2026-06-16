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

    @State private var selected: CategorySpend?
    @State private var showRecap = false

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
                ContentUnavailableView(
                    "No spend to chart yet",
                    systemImage: "chart.pie",
                    description: Text("Add an active subscription to see where your money goes each month.")
                )
                .padding(.top, Spacing.xl)
            } else {
                VStack(spacing: Spacing.md) {
                    categoryCard
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
        .navigationBarTitleDisplayMode(.inline)
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
                innerRadius: .ratio(0.62),
                angularInset: 1.5
            )
            .cornerRadius(4)
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
                    .font(.title2.weight(.bold))
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
                    .font(.title2.weight(.bold))
                    .contentTransition(.numericText())
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .padding(.horizontal, Spacing.lg)
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
    @State private var selectedMonth: Date?

    var body: some View {
        Chart(months) { month in
            BarMark(
                x: .value("Month", month.id, unit: .month),
                y: .value("Charges", total(month))
            )
            .foregroundStyle(Color.accentColor.gradient)
            .cornerRadius(6)
            .opacity(selectedMonth == nil || selectedMonth == month.id ? 1 : 0.4)
            .annotation(position: .top, spacing: 4) {
                if selectedMonth == month.id {
                    Text(month.formattedTotal)
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                }
            }
        }
        .chartXSelection(value: $selectedMonth)
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) {
                AxisValueLabel(format: .dateTime.month(.abbreviated))
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(amount.formatted(.number.notation(.compactName)))
                    }
                }
            }
        }
        .frame(height: 180)
        .accessibilityLabel("Projected charges per month")
        .accessibilityValue(months
            .map { "\($0.title) \($0.formattedTotal)" }
            .joined(separator: ", "))
    }

    private func total(_ month: RenewalMonth) -> Double {
        NSDecimalNumber(decimal: month.total).doubleValue
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
