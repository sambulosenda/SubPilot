//
//  CutListView.swift
//  Rubradar
//

import SwiftUI

/// "What you've cut": the cancelled subscriptions behind Home's savings pill,
/// with the yearly total they add up to. Rows push the standard detail screen
/// (the host stack's `navigationDestination(for: Subscription.self)`), where a
/// subscription can be marked active again.
struct CutListView: View {
    let subscriptions: [Subscription]
    let summary: CutSummary

    @ScaledMetric(relativeTo: .largeTitle) private var amountSize: CGFloat = 44

    var body: some View {
        List {
            Section {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    Text(summary.formattedYearly)
                        .font(.system(size: amountSize, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.brand)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                    Text("/year")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("You've cut \(summary.formattedYearly) a year")
            }

            Section {
                ForEach(subscriptions) { sub in
                    NavigationLink(value: sub) {
                        CutRow(subscription: sub)
                    }
                }
            }
        }
        .navigationTitle("What you've cut")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A cancelled subscription shown as a win: full strength, with what it was
/// costing per year — not the struck-through, dimmed row the main list uses.
private struct CutRow: View {
    let subscription: Subscription

    private var yearly: String {
        (subscription.monthlyEquivalent * 12).formatted(.currency(code: subscription.currencyCode))
    }

    var body: some View {
        RowStack {
            BrandLogoView(subscription: subscription)
            VStack(alignment: .leading, spacing: 2) {
                Text(subscription.name)
                    .font(.headline)
                    .rowTitle()
                Text(subscription.category.label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            // Takes all the width the price leaves. With a Spacer here instead,
            // HStack split that width between the two and the name truncated
            // with room to spare.
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(yearly) / year")
                .font(.subheadline.weight(.semibold))
                .rowValue()
                .layoutPriority(1)
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let subs = SampleData.makeSamples().filter(\.isCancelled)
    return NavigationStack {
        CutListView(subscriptions: subs,
                    summary: CutSummary.make(from: subs, preferred: "GBP", rates: .fallback))
    }
}
