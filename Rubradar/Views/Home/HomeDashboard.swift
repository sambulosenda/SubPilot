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

            HStack(spacing: Spacing.md) {
                StatCard(icon: "bell.fill", value: metrics.nextChargeLabel, caption: "Until next charge")
                StatCard(icon: "creditcard.fill", value: nextChargeAmount, caption: "Next charge")
            }

            Button(action: onAdd) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "plus")
                        .accessibilityHidden(true)
                    Text("Add a Subscription")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.extraLarge)
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
