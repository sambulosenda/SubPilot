//
//  BillingCycle.swift
//  Rubradar
//

import Foundation

/// How often a subscription bills. `.custom` uses an explicit day interval.
enum BillingCycle: String, CaseIterable, Identifiable, Codable {
    case weekly
    case monthly
    case yearly
    case custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .weekly: String(localized: "Weekly")
        case .monthly: String(localized: "Monthly")
        case .yearly: String(localized: "Yearly")
        case .custom: String(localized: "Custom")
        }
    }

    /// Short form for compact price labels, e.g. "£9.99 / mo".
    var shortLabel: String {
        switch self {
        case .weekly: String(localized: "wk", comment: "Compact billing cycle: week")
        case .monthly: String(localized: "mo", comment: "Compact billing cycle: month")
        case .yearly: String(localized: "yr", comment: "Compact billing cycle: year")
        case .custom: String(localized: "cycle", comment: "Compact billing cycle: custom")
        }
    }

    /// Advances a date by one billing cycle.
    /// For `.custom`, `customDays` is used (defaults to 30 if absent).
    ///
    /// Only for single-step advances from a true anchor (e.g. defaulting a new
    /// subscription's first renewal). Never chain this to walk occurrences —
    /// month-end anchors clamp and drift (Jan 31 → Feb 28 → Mar 28 forever).
    /// Use `date(byAddingCycles:to:)` / `firstOccurrence(onOrAfter:anchor:)`.
    func nextDate(after date: Date, customDays: Int? = nil, calendar: Calendar = .current) -> Date {
        self.date(byAddingCycles: 1, to: date, customDays: customDays, calendar: calendar)
    }

    /// The date `n` cycles after `anchor`, always computed from the anchor
    /// rather than chained from the previous occurrence, so month-end anchors
    /// stay on the right day: Jan 31 → Feb 28 → Mar 31, not → Mar 28.
    func date(byAddingCycles n: Int, to anchor: Date, customDays: Int? = nil, calendar: Calendar = .current) -> Date {
        switch self {
        case .weekly:
            return calendar.date(byAdding: .day, value: 7 * n, to: anchor) ?? anchor
        case .monthly:
            return calendar.date(byAdding: .month, value: n, to: anchor) ?? anchor
        case .yearly:
            return calendar.date(byAdding: .year, value: n, to: anchor) ?? anchor
        case .custom:
            let days = max(1, customDays ?? 30)
            return calendar.date(byAdding: .day, value: days * n, to: anchor) ?? anchor
        }
    }

    /// The first occurrence on or after `target`: its cycle index from the
    /// anchor (0 = the anchor itself) and its date. Jumps via an estimated
    /// index instead of stepping, so arbitrarily stale anchors resolve in O(1)
    /// and can never emit a past date.
    func firstOccurrence(
        onOrAfter target: Date,
        anchor: Date,
        customDays: Int? = nil,
        calendar: Calendar = .current
    ) -> (index: Int, date: Date) {
        guard anchor < target else { return (0, anchor) }

        let estimate: Int
        switch self {
        case .weekly:
            estimate = (calendar.dateComponents([.day], from: anchor, to: target).day ?? 0) / 7
        case .monthly:
            estimate = calendar.dateComponents([.month], from: anchor, to: target).month ?? 0
        case .yearly:
            estimate = calendar.dateComponents([.year], from: anchor, to: target).year ?? 0
        case .custom:
            let interval = max(1, customDays ?? 30)
            estimate = (calendar.dateComponents([.day], from: anchor, to: target).day ?? 0) / interval
        }

        // The truncated estimate can land a step early (or, around month-end
        // clamping, a step late) — nudge to the exact boundary.
        var n = max(0, estimate)
        var date = date(byAddingCycles: n, to: anchor, customDays: customDays, calendar: calendar)
        while date < target {
            n += 1
            date = self.date(byAddingCycles: n, to: anchor, customDays: customDays, calendar: calendar)
        }
        while n > 0 {
            let previous = self.date(byAddingCycles: n - 1, to: anchor, customDays: customDays, calendar: calendar)
            guard previous >= target else { break }
            n -= 1
            date = previous
        }
        return (n, date)
    }

    /// Approximate number of months this cycle spans — used to normalise spend.
    /// `.custom` is approximated from its day count (30 days ≈ 1 month).
    func monthsPerCycle(customDays: Int? = nil) -> Decimal {
        switch self {
        case .weekly: return Decimal(7) / Decimal(30)
        case .monthly: return 1
        case .yearly: return 12
        case .custom: return Decimal(max(1, customDays ?? 30)) / Decimal(30)
        }
    }
}
