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
    func nextDate(after date: Date, customDays: Int? = nil, calendar: Calendar = .current) -> Date {
        switch self {
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: date) ?? date
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date) ?? date
        case .custom:
            let days = max(1, customDays ?? 30)
            return calendar.date(byAdding: .day, value: days, to: date) ?? date
        }
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
