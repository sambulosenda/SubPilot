//
//  SubscriptionRow.swift
//  Rubradar
//

import SwiftUI

struct SubscriptionRow: View {
    let subscription: Subscription

    @Environment(CurrencyService.self) private var currency
    @AppStorage("preferredCurrencyCode") private var preferredCurrency =
        Locale.current.currency?.identifier ?? "GBP"

    /// The price in the preferred currency when the subscription bills in
    /// another one and a rate is known, so rows add up to the total above them
    /// and match the Calendar's rows. The native amount stays on the detail
    /// screen. Also narrower ("£45.62" against "US$59.99"), which gives a long
    /// name the room it was losing.
    private var priceText: String {
        subscription.priceLabel(in: preferredCurrency, rates: currency.rates)
    }

    /// "Cancel by 3 Nov" when cancelling needs notice: the date that matters
    /// is then weeks ahead of the charge. Otherwise "Renews 4 Dec". For a
    /// cancel-any-time subscription the two are a day apart, and the longer
    /// label widened this column until "Adobe Creative Cloud" truncated (far
    /// worse in Spanish and Italian); its cancel-by date is on the detail
    /// screen.
    private var scheduleText: String {
        let format = Date.FormatStyle.dateTime.day().month(.abbreviated)
        if let deadline = subscription.cancelDeadline(), deadline.needsNotice {
            return String(localized: "Cancel by \(deadline.date.formatted(format))")
        }
        return String(localized: "Renews \(subscription.projectedNextRenewal().formatted(format))")
    }

    var body: some View {
        RowStack {
            BrandLogoView(subscription: subscription)
                .opacity(subscription.isCancelled ? 0.5 : 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(subscription.name)
                    .font(.headline)
                    .strikethrough(subscription.isCancelled)
                    // Shrink rather than wrap or clip. Once the price column
                    // is fixed the name gets ~150pt, which truncated "Adobe
                    // Creative Cloud" to "Adobe Crea…"; wrapping instead
                    // made row heights ragged. Scaling keeps every row the
                    // same height and still fits the long names.
                    .rowTitle()
                // Badges ride the category line, not the name's: beside the
                // name a "Trial" pill cut "ChatGPT Plus" down to "ChatGPT…".
                HStack(spacing: Spacing.sm) {
                    Text(subscription.category.label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if subscription.isFreeTrial { TrialBadge() }
                    if subscription.isCancelled { CancelledBadge() }
                }
            }
            // Takes all the width the price leaves. With a Spacer here instead,
            // HStack split that width between the two and the name truncated
            // with room to spare.
            .frame(maxWidth: .infinity, alignment: .leading)

            // Price wins the width fight. Without this both columns are offered
            // half the row and *both* truncate — "ChatG…" beside "US$20.00 /…".
            // The amount is the row's reason for existing, so it stays whole and
            // the name takes the ellipsis.
            VStack(alignment: .trailing, spacing: 2) {
                Text(priceText)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .rowValue()
                Text(scheduleText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .rowValue()
            }
            .layoutPriority(1)
        }
        .opacity(subscription.isCancelled ? 0.6 : 1)
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var parts = [subscription.name, subscription.category.label, priceText]
        if subscription.isFreeTrial { parts.append("free trial") }
        if subscription.isCancelled { parts.append("cancelled") }
        parts.append(scheduleText)
        return parts.joined(separator: ", ")
    }
}

extension Subscription {
    /// `priceLabel` in the preferred currency when this bills in another one
    /// and a rate is known; the native label otherwise. Shared by the Home
    /// rows so every price on the screen is in the currency of its total.
    func priceLabel(in preferred: String, rates: ExchangeRates) -> String {
        guard currencyCode != preferred,
              let converted = rates.convert(amount, from: currencyCode, to: preferred)
        else { return priceLabel }
        return "\(converted.formatted(.currency(code: preferred))) / \(billingCycle.shortLabel)"
    }
}

#Preview {
    List {
        ForEach(SampleData.makeSamples()) { sub in
            SubscriptionRow(subscription: sub)
        }
    }
    .environment(CurrencyService())
}
