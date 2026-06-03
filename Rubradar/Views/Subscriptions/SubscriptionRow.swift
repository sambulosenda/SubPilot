//
//  SubscriptionRow.swift
//  Rubradar
//

import SwiftUI

struct SubscriptionRow: View {
    let subscription: Subscription

    private var renewalText: String {
        subscription.nextRenewalDate.formatted(.dateTime.day().month(.abbreviated))
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            BrandLogoView(subscription: subscription)
                .opacity(subscription.isCancelled ? 0.5 : 1)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Spacing.sm) {
                    Text(subscription.name)
                        .font(.headline)
                        .strikethrough(subscription.isCancelled)
                        .lineLimit(1)
                    if subscription.isFreeTrial { TrialBadge() }
                    if subscription.isCancelled { CancelledBadge() }
                }
                Text(subscription.category.label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: Spacing.sm)

            VStack(alignment: .trailing, spacing: 2) {
                Text(subscription.priceLabel)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text("Renews \(renewalText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .opacity(subscription.isCancelled ? 0.6 : 1)
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var parts = [subscription.name, subscription.category.label, subscription.priceLabel]
        if subscription.isFreeTrial { parts.append("free trial") }
        if subscription.isCancelled { parts.append("cancelled") }
        parts.append("renews \(renewalText)")
        return parts.joined(separator: ", ")
    }
}

#Preview {
    List {
        ForEach(SampleData.makeSamples()) { sub in
            SubscriptionRow(subscription: sub)
        }
    }
}
