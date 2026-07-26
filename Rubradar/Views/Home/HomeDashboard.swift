//
//  HomeDashboard.swift
//  Rubradar
//

import SwiftUI

/// The Home screen's hero + stats header: spend carousel, two stat cards,
/// and the primary "Add a Subscription" call to action.
struct DashboardHeader: View {
    let metrics: HomeMetrics
    /// Opens the add-subscription chooser (a bottom sheet owned by the host).
    var onAdd: () -> Void

    /// Amount of the soonest upcoming charge, in its own currency.
    private var nextChargeAmount: String {
        metrics.nextEvent?.subscription.formattedAmount ?? "—"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HeroSpendCard(metrics: metrics)
                .appearEntrance(0)

            HStack(spacing: Spacing.md) {
                StatCard(icon: "bell.fill", value: metrics.nextChargeLabel, caption: "Until next charge")
                StatCard(icon: "creditcard.fill", value: nextChargeAmount, caption: "Next charge")
            }
            .appearEntrance(1)

            // Secondary, not prominent: a full-width filled button out-shouted
            // the spend data it sits under, and the toolbar `+` is the primary
            // add affordance once the list is populated. Still full-width and
            // extraLarge, so it stays an easy target.
            Button(action: onAdd) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "plus")
                        .accessibilityHidden(true)
                    Text("Add a Subscription")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .controlSize(.extraLarge)
            .appearEntrance(2)
        }
        .padding(.top, Spacing.xs)
    }
}

// MARK: - Hero spend carousel

/// The spend hero: monthly total leads, with the yearly figure as a quiet
/// secondary line. Sits on an opaque card so the numbers stay crisp.
private struct HeroSpendCard: View {
    let metrics: HomeMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Total monthly")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            Text(metrics.summary.formattedMonthly)
                .font(.largeTitle.weight(.bold))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .contentTransition(.numericText())

            HStack(spacing: Spacing.xs) {
                Text("\(metrics.summary.formattedYearly) / year")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if metrics.summary.hasUnconvertible {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            // Where the money actually goes. The card was ~half empty with the
            // figures hugging the leading edge; this fills it with data the app
            // already computes (SpendBreakdown reconciles to the total above).
            //
            // Needs at least two categories to say anything — a lone full-width
            // bar reading "Streaming 100%" is decoration, not information.
            if metrics.breakdown.categories.count > 1 {
                CategoryBar(breakdown: metrics.breakdown)
                    .padding(.top, Spacing.md)
                CategoryLegend(breakdown: metrics.breakdown)
            }

            Text("From \(metrics.activeCount) subscriptions")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, Spacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(Color.cardBackground, in: .rect(cornerRadius: Radius.card))
        .accessibilityElement(children: .combine)
        // "approximately" voices what the warning triangle shows sighted users.
        .accessibilityLabel("Total monthly \(metrics.summary.hasUnconvertible ? "approximately " : "")\(metrics.summary.formattedMonthly), \(metrics.summary.formattedYearly) per year, from \(metrics.activeCount) subscriptions")
    }
}

// MARK: - Category breakdown

/// A single stacked bar of the month's spend, one segment per category. Sized
/// off the container so the segments always sum to the full width — the visual
/// counterpart to the total directly above it.
///
/// Deliberately not the Insights donut: this is a glanceable strip inside a
/// dashboard card, and Insights stays the place you go to interrogate the split.
private struct CategoryBar: View {
    let breakdown: SpendBreakdown

    private static let gap: CGFloat = 2
    private static let height: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            // Segments share the width left over once the gaps are removed, so
            // rounding never pushes the last one off the end.
            let gaps = Self.gap * CGFloat(max(0, breakdown.categories.count - 1))
            let usable = max(0, geo.size.width - gaps)
            HStack(spacing: Self.gap) {
                ForEach(breakdown.categories) { slice in
                    Capsule()
                        .fill(slice.category.tint.gradient)
                        // A floor keeps a 0.4% category from vanishing entirely.
                        .frame(width: max(3, usable * slice.fraction))
                }
            }
        }
        .frame(height: Self.height)
        .accessibilityHidden(true)   // the legend below carries the same data
    }
}

/// Compact legend under the bar: the three biggest categories with their share.
/// Capped at three because this is a summary — the full ranking lives in Insights.
private struct CategoryLegend: View {
    let breakdown: SpendBreakdown

    private var top: [CategorySpend] { Array(breakdown.categories.prefix(3)) }

    var body: some View {
        HStack(spacing: Spacing.md) {
            ForEach(top) { slice in
                HStack(spacing: Spacing.xs) {
                    Circle()
                        .fill(slice.category.tint)
                        .frame(width: 7, height: 7)
                    Text(slice.category.label)
                        .lineLimit(1)
                    Text(slice.fraction.formatted(.percent.precision(.fractionLength(0))))
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }
        }
        // Three long labels ("Cloud & Storage", "Food & Drink", "Education")
        // overrun the card width; shrink before any of them starts truncating.
        .minimumScaleFactor(0.75)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Monthly spend by category"))
        .accessibilityValue(
            top.map { "\($0.category.label), \($0.fraction.formatted(.percent.precision(.fractionLength(0))))" }
                .joined(separator: ", ")
        )
    }
}

// MARK: - Stat card

/// A compact glass card: an icon + value above a caption.
private struct StatCard: View {
    let icon: String
    let value: String
    let caption: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    // Rolls digits when subscriptions change, matching the hero
                    // total. Fires inside the @Query(animation:) update; degrades
                    // to a crossfade for non-numeric values ("Tomorrow").
                    .contentTransition(.numericText())
            }
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value), \(caption)")
    }
}

#Preview {
    let subs = SampleData.makeSamples()
    let metrics = HomeMetrics.make(from: subs, preferred: "GBP", rates: .fallback)
    return ScrollView {
        DashboardHeader(metrics: metrics, onAdd: {})
            .padding(.horizontal, Spacing.md)
    }
}
