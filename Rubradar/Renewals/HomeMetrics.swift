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
    /// Charges landing within `upcomingWindowDays`, soonest first — drives the
    /// Home strip that places each one on its day.
    let upcoming: [UpcomingCharge]
    /// Sum of `upcoming` in the preferred currency (unconvertible charges are
    /// left out, as in `SpendSummary`).
    let upcomingTotal: Decimal
    let preferredCurrency: String

    /// Yearly cost of what the user has cancelled — Home's savings pill.
    let cut: CutSummary

    /// How far ahead the Home strip looks.
    static let upcomingWindowDays = 30

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

        let today = calendar.startOfDay(for: now)
        var upcoming: [UpcomingCharge] = []
        var upcomingTotal: Decimal = 0
        for event in events {
            let away = calendar.dateComponents([.day], from: today,
                                               to: calendar.startOfDay(for: event.date)).day ?? 0
            // `events` is date-sorted, so the first one past the window ends it.
            // Half-open (today ..< today + 30): an inclusive end would count a
            // monthly charge that lands today twice.
            guard away < upcomingWindowDays else { break }
            upcoming.append(UpcomingCharge(event: event, daysAway: max(0, away)))
            upcomingTotal += rates.convert(event.subscription.amount,
                                           from: event.subscription.currencyCode, to: preferred) ?? 0
        }

        return HomeMetrics(
            summary: summary,
            activeCount: activeCount,
            nextEvent: next,
            dueThisMonthFraction: fraction,
            upcoming: upcoming,
            upcomingTotal: upcomingTotal,
            preferredCurrency: preferred,
            cut: CutSummary.make(from: subscriptions, preferred: preferred, rates: rates),
            daysUntilNextCharge: days
        )
    }

    /// Friendly "29 days" / "Today" / "Tomorrow" label for the next charge.
    var nextChargeLabel: String {
        guard let days = daysUntilNextCharge else { return "—" }
        switch days {
        case ..<0: return String(localized: "Due")
        case 0: return String(localized: "Today")
        case 1: return String(localized: "Tomorrow")
        default: return String(localized: "\(days) days")
        }
    }

    /// "Today" / "Tomorrow" / "in 5 days" — the sentence form of the countdown.
    var nextChargeRelativeLabel: String? {
        guard let days = daysUntilNextCharge else { return nil }
        switch days {
        case ...0: return String(localized: "Today")
        case 1: return String(localized: "Tomorrow")
        default: return String(localized: "in \(days) days")
        }
    }

    var formattedUpcomingTotal: String {
        upcomingTotal.formatted(.currency(code: preferredCurrency))
    }
}

/// One projected charge inside the Home strip's window.
struct UpcomingCharge: Identifiable {
    let event: RenewalEvent
    /// Whole days from today; 0 = today.
    let daysAway: Int

    var id: String { event.id }
}
