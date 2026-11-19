//
//  UsageCheckIn.swift
//  Rubradar
//

import Foundation

/// The monthly "which of these did you actually use?" check-in. One pass a
/// month, a switch per subscription; a subscription that goes unused two
/// months running is flagged on Home. Pure logic so it unit-tests without
/// SwiftData or the clock.
enum UsageCheckIn {
    /// Consecutive unused months before a subscription asks for attention.
    static let flagAfterMonths = 2

    /// "2026-11" — identifies the month a check-in was done in.
    static func monthKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
    }

    /// The month being asked about: the one before `now`.
    static func reviewedMonth(asOf now: Date = Date(), calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .month, value: -1, to: now) ?? now
    }

    /// Subscriptions worth asking about: active, past any trial, and tracked
    /// since before this month began — so there's a whole month to judge and
    /// a new user isn't quizzed on day one.
    static func candidates(
        in subscriptions: [Subscription],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Subscription] {
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
        return subscriptions.filter { !$0.isCancelled && !$0.isFreeTrial && $0.createdAt < monthStart }
    }

    /// Due once per calendar month, when there is something to ask about.
    static func isDue(
        lastDoneMonthKey: String,
        subscriptions: [Subscription],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        lastDoneMonthKey != monthKey(for: now, calendar: calendar)
            && !candidates(in: subscriptions, now: now, calendar: calendar).isEmpty
    }

    /// Records the answers: unused subscriptions extend their streak, used
    /// ones reset it.
    static func record(unused: Set<UUID>, among candidates: [Subscription], now: Date = Date()) {
        for sub in candidates {
            let streak = unused.contains(sub.id) ? sub.unusedMonths + 1 : 0
            guard streak != sub.unusedMonths else { continue }
            sub.unusedMonths = streak
            sub.updatedAt = now
        }
    }
}
