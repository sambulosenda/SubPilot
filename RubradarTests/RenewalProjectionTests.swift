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

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        DateComponents(calendar: calendar, year: y, month: m, day: d).date!
    }

    /// A subscription billing on the 31st must clamp through February and then
    /// RETURN to the 31st — chaining month-adds would drift it to the 28th
    /// forever (Jan 31 → Feb 28 → Mar 28 …).
    @Test func monthEndAnchorRecoversAfterFebruary() {
        let sub = Subscription(name: "iCloud", amount: 2.99, billingCycle: .monthly,
                               nextRenewalDate: day(2026, 1, 31))
        #expect(sub.projectedNextRenewal(asOf: day(2026, 2, 10), calendar: calendar) == day(2026, 2, 28))
        #expect(sub.projectedNextRenewal(asOf: day(2026, 3, 10), calendar: calendar) == day(2026, 3, 31))
        #expect(sub.projectedNextRenewal(asOf: day(2026, 4, 10), calendar: calendar) == day(2026, 4, 30))
    }

    /// Same guarantee for the calendar's event list: each occurrence is computed
    /// from the anchor, so the projected series is Feb 28, Mar 31, Apr 30, May 31.
    @Test func projectorEventsKeepMonthEndDay() {
        let sub = Subscription(name: "iCloud", amount: 2.99, billingCycle: .monthly,
                               nextRenewalDate: day(2026, 1, 31))
        let events = RenewalProjector.events(for: [sub], from: day(2026, 2, 1),
                                             horizonMonths: 4, calendar: calendar)
        let dates = events.map(\.date)
        #expect(dates == [day(2026, 2, 28), day(2026, 3, 31), day(2026, 4, 30), day(2026, 5, 31)])
    }

    /// A leap-day yearly anchor clamps to Feb 28 in common years and returns to
    /// Feb 29 in the next leap year.
    @Test func leapDayYearlyAnchor() {
        let sub = Subscription(name: "Domain", amount: 12, billingCycle: .yearly,
                               nextRenewalDate: day(2024, 2, 29))
        #expect(sub.projectedNextRenewal(asOf: day(2026, 1, 1), calendar: calendar) == day(2026, 2, 28))
        #expect(sub.projectedNextRenewal(asOf: day(2027, 3, 1), calendar: calendar) == day(2028, 2, 29))
    }

    /// An arbitrarily stale short-cycle anchor must resolve to a FUTURE date —
    /// the old 600-step walk gave up and could surface (and schedule reminders
    /// for) dates years in the past.
    @Test func veryStaleShortCycleAnchorNeverReturnsPast() {
        let anchor = day(2020, 6, 15)
        let now = day(2026, 7, 1)
        let sub = Subscription(name: "Daily thing", amount: 1, billingCycle: .custom,
                               customCycleDays: 1, nextRenewalDate: anchor)
        #expect(sub.projectedNextRenewal(asOf: now, calendar: calendar) >= now)

        let events = RenewalProjector.events(for: [sub], from: now, horizonMonths: 1, calendar: calendar)
        #expect(!events.isEmpty)
        #expect(events.allSatisfy { $0.date >= calendar.startOfDay(for: now) })
    }
}
