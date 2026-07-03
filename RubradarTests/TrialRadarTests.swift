//
//  TrialRadarTests.swift
//  RubradarTests
//

import Testing
import Foundation
@testable import Rubradar

struct TrialRadarTests {
    private let calendar = Calendar.current
    private var now: Date { calendar.startOfDay(for: Date()) }

    private func trial(_ name: String, endsInDays days: Int,
                       cancelled: Bool = false, isTrial: Bool = true) -> Subscription {
        Subscription(
            name: name, amount: 9.99,
            nextRenewalDate: calendar.date(byAdding: .day, value: days, to: now)!,
            isCancelled: cancelled, isFreeTrial: isTrial,
            trialEndDate: calendar.date(byAdding: .day, value: days, to: now)!
        )
    }

    @Test func findsTrialsInsideWindowSoonestFirst() {
        let subs = [trial("Later", endsInDays: 10), trial("Soon", endsInDays: 2)]
        let trials = TrialRadar.endingTrials(in: subs, now: now, calendar: calendar)
        #expect(trials.map(\.subscription.name) == ["Soon", "Later"])
        #expect(trials.first?.daysLeft == 2)
    }

    @Test func excludesBeyondWindow() {
        let trials = TrialRadar.endingTrials(in: [trial("Far", endsInDays: 20)],
                                             now: now, calendar: calendar)
        #expect(trials.isEmpty)
    }

    @Test func excludesEndedTrials() {
        // Already converted — it's an ordinary paid subscription now.
        let trials = TrialRadar.endingTrials(in: [trial("Past", endsInDays: -1)],
                                             now: now, calendar: calendar)
        #expect(trials.isEmpty)
    }

    @Test func excludesCancelledAndNonTrials() {
        let subs = [trial("Cancelled", endsInDays: 2, cancelled: true),
                    trial("Paid", endsInDays: 2, isTrial: false)]
        #expect(TrialRadar.endingTrials(in: subs, now: now, calendar: calendar).isEmpty)
    }

    @Test func endsTodayCountsAndIsUrgent() {
        let trials = TrialRadar.endingTrials(in: [trial("Today", endsInDays: 0)],
                                             now: now, calendar: calendar)
        #expect(trials.first?.daysLeft == 0)
        #expect(trials.first?.isUrgent == true)
    }

    @Test func urgencyBoundary() {
        let close = TrialRadar.endingTrials(in: [trial("Close", endsInDays: 3)],
                                            now: now, calendar: calendar)
        let far = TrialRadar.endingTrials(in: [trial("Far", endsInDays: 4)],
                                          now: now, calendar: calendar)
        #expect(close.first?.isUrgent == true)
        #expect(far.first?.isUrgent == false)
    }
}
