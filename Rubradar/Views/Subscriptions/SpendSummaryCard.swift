//
//  SpendSummaryCard.swift
//  Rubradar
//

import SwiftUI

/// Header card showing total monthly + yearly spend in the preferred currency.
struct SpendSummaryCard: View {
    let summary: SpendSummary
    var isStale: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Monthly spend")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(summary.formattedMonthly)
                .font(.largeTitle.weight(.bold))
                .contentTransition(.numericText())
            HStack(spacing: Spacing.xs) {
                Text("\(summary.formattedYearly) / year")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if summary.hasUnconvertible {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .help("Some subscriptions use a currency without a known exchange rate.")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Monthly spend \(summary.formattedMonthly), \(summary.formattedYearly) per year")
    }
}

#Preview {
    SpendSummaryCard(
        summary: SpendSummary(preferredCurrency: "GBP", monthlyTotal: 89.97,
                              yearlyTotal: 1079.64, hasUnconvertible: true)
    )
    .padding()
}
