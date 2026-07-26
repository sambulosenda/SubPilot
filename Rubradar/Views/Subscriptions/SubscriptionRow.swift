//
//  SubscriptionRow.swift
//  Rubradar
//

import SwiftUI

struct SubscriptionRow: View {
    let subscription: Subscription

    private var renewalText: String {
        subscription.projectedNextRenewal().formatted(.dateTime.day().month(.abbreviated))
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
                        // Shrink rather than wrap or clip. Once the price column
                        // is fixed the name gets ~150pt, which truncated "Adobe
                        // Creative Cloud" to "Adobe Crea…"; wrapping instead
                        // made row heights ragged. Scaling keeps every row the
                        // same height and still fits the long names.
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if subscription.isFreeTrial { TrialBadge() }
                    if subscription.isCancelled { CancelledBadge() }
                }
                Text(subscription.category.label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: Spacing.sm)

            // Price wins the width fight. Without this both columns are offered
            // half the row and *both* truncate — "ChatG…" beside "US$20.00 /…".
            // The amount is the row's reason for existing, so it stays whole and
            // the name takes the ellipsis.
            VStack(alignment: .trailing, spacing: 2) {
                Text(subscription.priceLabel)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Text("Renews \(renewalText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .layoutPriority(1)
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
