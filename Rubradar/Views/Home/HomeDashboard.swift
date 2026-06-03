//
//  HomeDashboard.swift
//  Rubradar
//

import SwiftUI

/// The Home screen's hero + stats header: spend carousel, two stat cards,
/// and the primary "Add a Subscription" call to action.
struct DashboardHeader: View {
    let metrics: HomeMetrics
    var presentAdd: (AddSheet) -> Void

    @State private var showAddChooser = false

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

            Button {
                showAddChooser = true
            } label: {
                Label("Add a Subscription", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.extraLarge)
        }
        .padding(.top, Spacing.xs)
        .confirmationDialog("Add a subscription", isPresented: $showAddChooser, titleVisibility: .visible) {
            Button("Scan a receipt") { presentAdd(.scan) }
            Button("Browse catalogue") { presentAdd(.catalogue) }
            Button("Add manually") { presentAdd(.manual) }
        }
    }
}

// MARK: - Hero spend carousel

/// The spend hero: monthly total leads, with the yearly figure as a quiet
/// secondary line. Sits on an opaque card so the numbers stay crisp.
private struct HeroSpendCard: View {
    let metrics: HomeMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Total monthly".uppercased())
                .font(.caption.weight(.semibold))
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

            Text("From \(metrics.activeCount) subscription\(metrics.activeCount == 1 ? "" : "s")")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, Spacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(Color.cardBackground, in: .rect(cornerRadius: Radius.card))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Total monthly \(metrics.summary.formattedMonthly), \(metrics.summary.formattedYearly) per year, from \(metrics.activeCount) subscriptions")
    }
}

// MARK: - Stat card

/// A compact glass card: an icon + value above a caption.
private struct StatCard: View {
    let icon: String
    let value: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
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
        DashboardHeader(metrics: metrics, presentAdd: { _ in })
            .padding(.horizontal, Spacing.md)
    }
}
