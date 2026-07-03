//
//  TrialRadar.swift
//  Rubradar
//

import Foundation

/// An active free trial with its end approaching, for the Home radar section.
struct EndingTrial: Identifiable {
    let subscription: Subscription
    let endDate: Date
    /// Whole days from today to the end date; 0 = ends today.
    let daysLeft: Int

    var id: UUID { subscription.id }

    /// Close enough that missing it costs money — drives the warning tint.
    var isUrgent: Bool { daysLeft <= 3 }

    /// "Ends today" / "Ends tomorrow" / "Ends in 5 days"
    var endsLabel: String {
        switch daysLeft {
        case 0: String(localized: "Ends today")
        case 1: String(localized: "Ends tomorrow")
        default: String(localized: "Ends in \(daysLeft) days")
        }
    }
}

/// Finds free trials that are about to convert into paid charges. Pure &
/// synchronous (like `RenewalProjector`) so it unit-tests without SwiftData.
enum TrialRadar {
    /// How far ahead the Home section looks.
    static let defaultWindowDays = 14

    /// Active (non-cancelled) free trials ending within `windowDays` of `now`,
    /// soonest first. Trials whose end has already passed are excluded — they've
    /// converted and are ordinary paid subscriptions now.
    static func endingTrials(
        in subscriptions: [Subscription],
        within windowDays: Int = defaultWindowDays,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [EndingTrial] {
        let today = calendar.startOfDay(for: now)
        return subscriptions
            .compactMap { sub -> EndingTrial? in
                guard sub.isFreeTrial, !sub.isCancelled, let end = sub.trialEndDate else { return nil }
                let endDay = calendar.startOfDay(for: end)
                guard let days = calendar.dateComponents([.day], from: today, to: endDay).day,
                      days >= 0, days <= windowDays else { return nil }
                return EndingTrial(subscription: sub, endDate: end, daysLeft: days)
            }
            .sorted { $0.endDate < $1.endDate }
    }
}
