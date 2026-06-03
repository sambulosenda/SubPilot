//
//  HomeMetrics.swift
//  Rubradar
//

import Foundation

/// Dashboard figures for the Home screen, derived from the user's subscriptions.
struct HomeMetrics {
    let summary: SpendSummary
    /// Count of non-cancelled subscriptions ("From N subscriptions").
    let activeCount: Int
    /// Soonest upcoming renewal, if any.
    let nextEvent: RenewalEvent?
    /// Share of the monthly spend still due before this calendar month ends (0...1).
    let dueThisMonthFraction: Double

    /// Whole days from today until the next charge. `nil` when nothing is upcoming.
    let daysUntilNextCharge: Int?

    static func make(
        from subscriptions: [Subscription],
        preferred: String,
        rates: ExchangeRates,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> HomeMetrics {
        let summary = SpendSummary.make(from: subscriptions, preferred: preferred, rates: rates)
        let activeCount = subscriptions.filter { !$0.isCancelled }.count
        let events = RenewalProjector.events(for: subscriptions, from: now, calendar: calendar)
        let next = events.first

        let monthEnd = calendar.dateInterval(of: .month, for: now)?.end ?? now
        let dueThisMonth = events
            .filter { $0.date < monthEnd }
            .reduce(Decimal(0)) { acc, event in
                acc + (rates.convert(event.subscription.amount,
                                     from: event.subscription.currencyCode, to: preferred) ?? 0)
            }
        let fraction: Double
        if summary.monthlyTotal > 0 {
            let ratio = NSDecimalNumber(decimal: dueThisMonth / summary.monthlyTotal).doubleValue
            fraction = min(max(ratio, 0), 1)
        } else {
            fraction = 0
        }

        let days = next.map { event in
            calendar.dateComponents([.day],
                                    from: calendar.startOfDay(for: now),
                                    to: calendar.startOfDay(for: event.date)).day ?? 0
        }

        return HomeMetrics(
            summary: summary,
            activeCount: activeCount,
            nextEvent: next,
            dueThisMonthFraction: fraction,
            daysUntilNextCharge: days
        )
    }

    /// Friendly "29 days" / "Today" / "Tomorrow" label for the next charge.
    var nextChargeLabel: String {
        guard let days = daysUntilNextCharge else { return "—" }
        switch days {
        case ..<0: return "Due"
        case 0: return "Today"
        case 1: return "Tomorrow"
        default: return "\(days) days"
        }
    }
}
