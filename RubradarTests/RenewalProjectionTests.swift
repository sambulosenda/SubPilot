//
//  RenewalProjectionTests.swift
//  RubradarTests
//

import Testing
import Foundation
@testable import Rubradar

/// `nextRenewalDate` is a fixed anchor that is never advanced once a charge
/// passes; `projectedNextRenewal(asOf:)` rolls it forward to the next future
/// occurrence. These cover the cases the Home row, list sort, and renewal
/// reminders all depend on — a stale anchor must not surface a past date.
struct RenewalProjectionTests {
    private let calendar = Calendar(identifier: .gregorian)

    @Test func futureAnchorIsReturnedUnchanged() {
        let now = Date()
        let future = calendar.date(byAdding: .day, value: 10, to: now)!
        let sub = Subscription(name: "Netflix", amount: 9.99, billingCycle: .monthly, nextRenewalDate: future)
        #expect(sub.projectedNextRenewal(asOf: now, calendar: calendar) == future)
    }

    @Test func staleMonthlyAnchorRollsToFirstFutureOccurrence() {
        let now = Date()
        let start = calendar.startOfDay(for: now)
        let staleAnchor = calendar.date(byAdding: .month, value: -5, to: now)!
        let sub = Subscription(name: "Spotify", amount: 11.99, billingCycle: .monthly, nextRenewalDate: staleAnchor)

        let projected = sub.projectedNextRenewal(asOf: now, calendar: calendar)
        // In the future …
        #expect(projected >= start)
        // … and it's the FIRST such occurrence: one cycle earlier is still past.
        let previousCycle = calendar.date(byAdding: .month, value: -1, to: projected)!
        #expect(previousCycle < start)
    }

    @Test func staleWeeklyAnchorRollsForward() {
        let now = Date()
        let start = calendar.startOfDay(for: now)
        let staleAnchor = calendar.date(byAdding: .day, value: -100, to: now)!
        let sub = Subscription(name: "Gym", amount: 5, billingCycle: .weekly, nextRenewalDate: staleAnchor)

        let projected = sub.projectedNextRenewal(asOf: now, calendar: calendar)
        #expect(projected >= start)
        let previousCycle = calendar.date(byAdding: .day, value: -7, to: projected)!
        #expect(previousCycle < start)
    }

    @Test func freeTrialAnchorsOnTrialEndDate() {
        let now = Date()
        let trialEnd = calendar.date(byAdding: .day, value: 4, to: now)!
        let renewal = calendar.date(byAdding: .day, value: 30, to: now)!
        let sub = Subscription(
            name: "Disney+", amount: 7.99, billingCycle: .monthly,
            nextRenewalDate: renewal, isFreeTrial: true, trialEndDate: trialEnd
        )
        #expect(sub.projectedNextRenewal(asOf: now, calendar: calendar) == trialEnd)
    }
}
