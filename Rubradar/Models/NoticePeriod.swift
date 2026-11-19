//
//  NoticePeriod.swift
//  Rubradar
//

import Foundation

/// How much notice a provider needs before a renewal to accept a cancellation
/// (a contract's "Kündigungsfrist"). Raw values are persisted — don't rename
/// without a migration.
enum NoticePeriod: String, CaseIterable, Identifiable {
    case twoWeeks
    case oneMonth
    case sixWeeks
    case threeMonths

    var id: String { rawValue }

    var label: String {
        switch self {
        case .twoWeeks: String(localized: "2 weeks")
        case .oneMonth: String(localized: "1 month")
        case .sixWeeks: String(localized: "6 weeks")
        case .threeMonths: String(localized: "3 months")
        }
    }

    /// The last day a cancellation still stops `renewal`. Month-based periods
    /// use calendar months, as contracts do — one month before 31 March is the
    /// end of February, not 1 March.
    func lastDayToCancel(before renewal: Date, calendar: Calendar = .current) -> Date {
        let day = calendar.startOfDay(for: renewal)
        let result: Date? = switch self {
        case .twoWeeks: calendar.date(byAdding: .day, value: -14, to: day)
        case .oneMonth: calendar.date(byAdding: .month, value: -1, to: day)
        case .sixWeeks: calendar.date(byAdding: .day, value: -42, to: day)
        case .threeMonths: calendar.date(byAdding: .month, value: -3, to: day)
        }
        return result ?? day
    }
}

/// The next cancellation deadline that can still be met, and the renewal it
/// would stop.
struct CancelDeadline: Equatable {
    /// Start of the last day to cancel.
    let date: Date
    let renewal: Date
    /// Whole days from today; 0 = today is the last day.
    let daysLeft: Int
}

extension Subscription {
    var noticePeriod: NoticePeriod? {
        get { noticePeriodRaw.flatMap(NoticePeriod.init(rawValue:)) }
        set { noticePeriodRaw = newValue?.rawValue }
    }

    /// The next cancel-by date that hasn't passed. Nil without a notice period
    /// or once cancelled. When the deadline for the upcoming renewal is already
    /// gone, that renewal is locked in, so this returns the deadline for the
    /// one after — the next decision the user can actually make.
    func cancelDeadline(asOf now: Date = Date(), calendar: Calendar = .current) -> CancelDeadline? {
        guard let notice = noticePeriod, !isCancelled else { return nil }
        let today = calendar.startOfDay(for: now)
        let anchor = (isFreeTrial && trialEndDate != nil) ? trialEndDate! : nextRenewalDate
        let first = billingCycle.firstOccurrence(
            onOrAfter: today, anchor: anchor, customDays: customCycleDays, calendar: calendar
        ).index
        // A notice longer than the cycle (3 months on a monthly plan) skips
        // several renewals; the cap only guards against a degenerate cycle.
        for n in first..<(first + 400) {
            let renewal = billingCycle.date(byAddingCycles: n, to: anchor,
                                            customDays: customCycleDays, calendar: calendar)
            let deadline = notice.lastDayToCancel(before: renewal, calendar: calendar)
            guard deadline >= today else { continue }
            let days = calendar.dateComponents([.day], from: today, to: deadline).day ?? 0
            return CancelDeadline(date: deadline, renewal: renewal, daysLeft: days)
        }
        return nil
    }
}
