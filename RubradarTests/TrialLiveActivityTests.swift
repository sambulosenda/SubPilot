//
//  TrialLiveActivityTests.swift
//  RubradarTests
//

import Foundation
import Testing
@testable import Rubradar

struct TrialLiveActivityTests {
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    private func date(_ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    @Test func noTrialsNoPlan() {
        #expect(TrialLiveActivity.plan(for: [], now: date(20), calendar: calendar) == nil)
    }

    @Test func futureTrialIsScheduledForNineOnItsLastDay() {
        let id = UUID()
        let plan = TrialLiveActivity.plan(for: [(id, date(25, hour: 0))], now: date(20), calendar: calendar)
        #expect(plan == .init(subscriptionID: id, start: date(25, hour: 9), end: date(26, hour: 0)))
    }

    @Test func trialEndingTodayStartsInThePast() {
        let plan = TrialLiveActivity.plan(for: [(UUID(), date(20, hour: 0))], now: date(20, hour: 14), calendar: calendar)
        #expect(plan?.start == date(20, hour: 9))
        #expect(plan.map { $0.start <= date(20, hour: 14) } == true)
    }

    @Test func finishedTrialIsSkippedAndSoonestWins() {
        let soon = UUID()
        let plan = TrialLiveActivity.plan(
            for: [(UUID(), date(19)), (UUID(), date(28)), (soon, date(22))],
            now: date(20), calendar: calendar)
        #expect(plan?.subscriptionID == soon)
    }
}
