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
            let anchor = usesTrialAnchor ? sub.trialEndDate! : sub.nextRenewalDate
            let cycle = sub.billingCycle

            // Occurrences are always computed from the anchor by index, never
            // chained date-to-date — chaining clamps month-end anchors and
            // drifts them permanently (Jan 31 → Feb 28 → Mar 28 …).
            var (n, date) = cycle.firstOccurrence(
                onOrAfter: start, anchor: anchor, customDays: sub.customCycleDays, calendar: calendar
            )
            var steps = 0
            while date <= end && steps < maxOccurrences {
                // "Trial ends" only if the trial-end anchor itself is still
                // upcoming (n == 0); a rolled-forward stale trial has already
                // converted, so its occurrences are plain renewals.
                events.append(RenewalEvent(subscription: sub, date: date, isTrialEnd: usesTrialAnchor && n == 0))
                n += 1
                date = cycle.date(byAddingCycles: n, to: anchor, customDays: sub.customCycleDays, calendar: calendar)
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
