//
//  RenewalProjector.swift
//  Rubradar
//

import Foundation

/// A single projected renewal (or trial-end) occurrence for a subscription.
///
/// Subscriptions store only one `nextRenewalDate`; the projector walks that date
/// forward by the billing cycle to materialise the upcoming occurrences shown in
/// the renewal calendar.
struct RenewalEvent: Identifiable {
    let subscription: Subscription
    let date: Date
    /// True for the first charge after a free trial — rendered as "Trial ends".
    let isTrialEnd: Bool

    var id: String {
        "\(subscription.id.uuidString)-\(date.timeIntervalSinceReferenceDate)-\(isTrialEnd)"
    }
}

/// Projects upcoming renewals for active subscriptions over a fixed horizon.
enum RenewalProjector {
    /// Safety cap so a tiny custom cycle can't loop forever.
    private static let maxOccurrences = 600

    /// Returns every projected renewal in `[now, now + horizonMonths]`, sorted by date.
    /// Cancelled subscriptions are skipped. A free trial's end date anchors its first
    /// (trial-end) occurrence; recurring renewals continue from there.
    static func events(
        for subscriptions: [Subscription],
        from now: Date = Date(),
        horizonMonths: Int = 12,
        calendar: Calendar = .current
    ) -> [RenewalEvent] {
        let start = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .month, value: horizonMonths, to: start) else { return [] }

        var events: [RenewalEvent] = []
        for sub in subscriptions where !sub.isCancelled {
            // A free trial's end is the first meaningful (first-charge) event.
            let usesTrialAnchor = sub.isFreeTrial && sub.trialEndDate != nil
            var date = usesTrialAnchor ? sub.trialEndDate! : sub.nextRenewalDate

            // Roll a stale anchor forward to the next future occurrence.
            var steps = 0
            while date < start && steps < maxOccurrences {
                date = sub.billingCycle.nextDate(after: date, customDays: sub.customCycleDays, calendar: calendar)
                steps += 1
            }

            var isFirst = true
            steps = 0
            while date <= end && steps < maxOccurrences {
                events.append(RenewalEvent(subscription: sub, date: date, isTrialEnd: usesTrialAnchor && isFirst))
                date = sub.billingCycle.nextDate(after: date, customDays: sub.customCycleDays, calendar: calendar)
                isFirst = false
                steps += 1
            }
        }
        return events.sorted { $0.date < $1.date }
    }
}

/// A month bucket of renewal events with a converted spend subtotal.
struct RenewalMonth: Identifiable {
    /// First day of the month — stable identity and sort key.
    let id: Date
    let title: String
    let events: [RenewalEvent]
    let total: Decimal
    let preferredCurrency: String
    /// True if a charge used a currency without a known exchange rate.
    let hasUnconvertible: Bool

    var formattedTotal: String { total.formatted(.currency(code: preferredCurrency)) }

    /// Groups events by calendar month, summing each month's charges in `preferred`.
    static func group(
        _ events: [RenewalEvent],
        preferred: String,
        rates: ExchangeRates,
        calendar: Calendar = .current
    ) -> [RenewalMonth] {
        let buckets = Dictionary(grouping: events) { event -> Date in
            let comps = calendar.dateComponents([.year, .month], from: event.date)
            return calendar.date(from: comps) ?? event.date
        }
        return buckets.keys.sorted().map { monthStart in
            let monthEvents = buckets[monthStart]!.sorted { $0.date < $1.date }
            var total: Decimal = 0
            var unconvertible = false
            for event in monthEvents {
                if let converted = rates.convert(event.subscription.amount,
                                                 from: event.subscription.currencyCode, to: preferred) {
                    total += converted
                } else {
                    unconvertible = true
                }
            }
            return RenewalMonth(
                id: monthStart,
                title: monthStart.formatted(.dateTime.month(.wide).year()),
                events: monthEvents,
                total: total,
                preferredCurrency: preferred,
                hasUnconvertible: unconvertible
            )
        }
    }
}
