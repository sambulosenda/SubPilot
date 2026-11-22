//
//  AttentionRadarTests.swift
//  RubradarTests
//

import Testing
import Foundation
import SwiftData
@testable import Rubradar

@MainActor
struct AttentionRadarTests {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Subscription.self, Profile.self, PriceChange.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        return ModelContext(container)
    }

    @discardableResult
    private func addChange(to sub: Subscription, from old: Decimal, to new: Decimal,
                           daysAgo: Double, in context: ModelContext) -> PriceChange {
        let change = PriceChange(oldAmount: old, newAmount: new, currencyCode: sub.currencyCode,
                                 source: .manual,
                                 changedAt: Date(timeIntervalSinceNow: -daysAgo * 86_400))
        change.subscription = sub
        context.insert(change)
        return change
    }

    @Test func flagsRecentRise() throws {
        let context = try makeContext()
        let sub = Subscription(name: "Netflix", amount: 12.99)
        context.insert(sub)
        addChange(to: sub, from: 10.99, to: 12.99, daysAgo: 3, in: context)

        let rises = AttentionRadar.priceRises(in: [sub])
        #expect(rises.count == 1)
        #expect(rises.first?.subscription.name == "Netflix")
    }

    @Test func ignoresDropsOldRisesAndCancelled() throws {
        let context = try makeContext()
        let drop = Subscription(name: "Drop", amount: 5)
        let old = Subscription(name: "Old", amount: 12)
        let cancelled = Subscription(name: "Gone", amount: 12, isCancelled: true)
        [drop, old, cancelled].forEach(context.insert)
        addChange(to: drop, from: 8, to: 5, daysAgo: 2, in: context)
        addChange(to: old, from: 10, to: 12, daysAgo: 45, in: context)
        addChange(to: cancelled, from: 10, to: 12, daysAgo: 2, in: context)

        #expect(AttentionRadar.priceRises(in: [drop, old, cancelled]).isEmpty)
    }

    @Test func onlyLatestChangeCounts() throws {
        // Went up, then back down: no longer a rise worth flagging.
        let context = try makeContext()
        let sub = Subscription(name: "Spotify", amount: 9.99)
        context.insert(sub)
        addChange(to: sub, from: 9.99, to: 11.99, daysAgo: 10, in: context)
        addChange(to: sub, from: 11.99, to: 9.99, daysAgo: 2, in: context)

        #expect(AttentionRadar.priceRises(in: [sub]).isEmpty)
    }

    @Test func keptRiseIsHiddenButALaterOneReturns() throws {
        let context = try makeContext()
        let sub = Subscription(name: "Netflix", amount: 14.99)
        context.insert(sub)
        let first = addChange(to: sub, from: 10.99, to: 12.99, daysAgo: 10, in: context)
        let token = try #require(AttentionRadar.items(in: [sub]).first?.dismissToken)
        #expect(token == "rise-\(first.id.uuidString)")
        #expect(AttentionRadar.items(in: [sub], dismissed: [token]).isEmpty)

        addChange(to: sub, from: 12.99, to: 14.99, daysAgo: 1, in: context)
        #expect(AttentionRadar.items(in: [sub], dismissed: [token]).count == 1)
    }

    @Test func trialsComeBeforePriceRises() throws {
        let context = try makeContext()
        let risen = Subscription(name: "Netflix", amount: 12.99)
        let end = Calendar.current.date(byAdding: .day, value: 2, to: Date())!
        let trial = Subscription(name: "ChatGPT", amount: 20, nextRenewalDate: end,
                                 isFreeTrial: true, trialEndDate: end)
        [risen, trial].forEach(context.insert)
        addChange(to: risen, from: 10.99, to: 12.99, daysAgo: 1, in: context)

        let items = AttentionRadar.items(in: [risen, trial])
        #expect(items.map(\.subscription.name) == ["ChatGPT", "Netflix"])
    }
}

struct CancelDeadlineTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        DateComponents(calendar: calendar, year: y, month: m, day: d).date!
    }

    @Test func monthNoticeUsesCalendarMonths() {
        // One month before 31 March is the end of February, not 1 March.
        let last = NoticePeriod.oneMonth.lastDayToCancel(before: date(2026, 3, 31), calendar: calendar)
        #expect(last == date(2026, 2, 28))
        #expect(NoticePeriod.twoWeeks.lastDayToCancel(before: date(2026, 3, 31), calendar: calendar)
                == date(2026, 3, 17))
    }

    @Test func noDeadlineOnceCancelledOrForATrialWithoutNotice() {
        let gone = Subscription(name: "Gym", amount: 40, nextRenewalDate: date(2026, 6, 1),
                                isCancelled: true, noticePeriod: .oneMonth)
        // A trial's end date is the decision point; `TrialRadar` owns it.
        let trial = Subscription(name: "Max", amount: 10, nextRenewalDate: date(2026, 6, 1),
                                 isFreeTrial: true, trialEndDate: date(2026, 5, 10))
        #expect(gone.cancelDeadline(asOf: date(2026, 5, 1), calendar: calendar) == nil)
        #expect(trial.cancelDeadline(asOf: date(2026, 5, 1), calendar: calendar) == nil)
    }

    @Test func withoutNoticeTheDeadlineIsTheDayBeforeRenewal() throws {
        let plain = Subscription(name: "Netflix", amount: 10, nextRenewalDate: date(2026, 6, 1))
        let deadline = try #require(plain.cancelDeadline(asOf: date(2026, 5, 20), calendar: calendar))
        #expect(deadline.date == date(2026, 5, 31))
        #expect(deadline.renewal == date(2026, 6, 1))
        #expect(deadline.daysLeft == 11)
        #expect(!deadline.needsNotice)
    }

    @Test func aCancelAnyTimeChargeLandingTodayIsLockedIn() throws {
        // On the renewal day yesterday was the last chance, so the next
        // decision is the day before the following charge.
        let plain = Subscription(name: "Netflix", amount: 10, nextRenewalDate: date(2026, 6, 1))
        let deadline = try #require(plain.cancelDeadline(asOf: date(2026, 6, 1), calendar: calendar))
        #expect(deadline.date == date(2026, 6, 30))
        #expect(deadline.renewal == date(2026, 7, 1))
    }

    @Test func deadlineIsNoticeBeforeNextRenewal() throws {
        let gym = Subscription(name: "Gym", amount: 40, billingCycle: .yearly,
                               nextRenewalDate: date(2026, 9, 1), noticePeriod: .oneMonth)
        let deadline = try #require(gym.cancelDeadline(asOf: date(2026, 7, 20), calendar: calendar))
        #expect(deadline.date == date(2026, 8, 1))
        #expect(deadline.renewal == date(2026, 9, 1))
        #expect(deadline.daysLeft == 12)
        #expect(deadline.needsNotice)
    }

    @Test func lastDayItselfStillCounts() throws {
        let gym = Subscription(name: "Gym", amount: 40, billingCycle: .yearly,
                               nextRenewalDate: date(2026, 9, 1), noticePeriod: .oneMonth)
        let deadline = try #require(gym.cancelDeadline(asOf: date(2026, 8, 1), calendar: calendar))
        #expect(deadline.daysLeft == 0)
        #expect(deadline.renewal == date(2026, 9, 1))
    }

    @Test func missedDeadlineRollsToTheFollowingRenewal() throws {
        // The 1 Sep renewal is locked in once 1 Aug has passed.
        let gym = Subscription(name: "Gym", amount: 40, billingCycle: .yearly,
                               nextRenewalDate: date(2026, 9, 1), noticePeriod: .oneMonth)
        let deadline = try #require(gym.cancelDeadline(asOf: date(2026, 8, 2), calendar: calendar))
        #expect(deadline.renewal == date(2027, 9, 1))
        #expect(deadline.date == date(2027, 8, 1))
    }

    @Test func attentionFlagsDeadlinesInsideWindowOnly() {
        let now = date(2026, 7, 20)
        let soon = Subscription(name: "Gym", amount: 40, billingCycle: .yearly,
                                nextRenewalDate: date(2026, 9, 1), noticePeriod: .oneMonth)   // 12 days
        let far = Subscription(name: "Mobile", amount: 20, billingCycle: .yearly,
                               nextRenewalDate: date(2026, 12, 1), noticePeriod: .oneMonth)
        let items = AttentionRadar.items(in: [soon, far], now: now, calendar: calendar)
        #expect(items.map(\.subscription.name) == ["Gym"])

        let token = items.first?.dismissToken
        #expect(token != nil)
        #expect(AttentionRadar.items(in: [soon, far], dismissed: Set([token].compactMap { $0 }),
                                     now: now, calendar: calendar).isEmpty)
    }

    @Test func attentionSkipsCancelAnyTimeMonthliesButFlagsYearlies() {
        // Both renew in five days. Only the yearly one is worth a row: a
        // monthly renewal is routine, another year is not.
        let now = date(2026, 7, 20)
        let monthly = Subscription(name: "Netflix", amount: 10, nextRenewalDate: date(2026, 7, 25))
        let yearly = Subscription(name: "Disney+", amount: 90, billingCycle: .yearly,
                                  nextRenewalDate: date(2026, 7, 25))
        let items = AttentionRadar.items(in: [monthly, yearly], now: now, calendar: calendar)
        #expect(items.map(\.subscription.name) == ["Disney+"])
    }
}

struct UsageCheckInTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        DateComponents(calendar: calendar, year: y, month: m, day: d).date!
    }

    private func sub(_ name: String, created: Date, cancelled: Bool = false, trial: Bool = false) -> Subscription {
        Subscription(name: name, amount: 10, isCancelled: cancelled, isFreeTrial: trial, createdAt: created)
    }

    @Test func asksOnlyAboutActiveSubsTrackedBeforeThisMonth() {
        let now = date(2026, 11, 19)
        let subs = [
            sub("Old", created: date(2026, 9, 1)),
            sub("New", created: date(2026, 11, 3)),
            sub("Gone", created: date(2026, 9, 1), cancelled: true),
            sub("Trial", created: date(2026, 9, 1), trial: true),
        ]
        #expect(UsageCheckIn.candidates(in: subs, now: now, calendar: calendar).map(\.name) == ["Old"])
    }

    @Test func dueOncePerMonth() {
        let now = date(2026, 11, 19)
        let subs = [sub("Old", created: date(2026, 9, 1))]
        #expect(UsageCheckIn.isDue(lastDoneMonthKey: "2026-10", subscriptions: subs, now: now, calendar: calendar))
        #expect(!UsageCheckIn.isDue(lastDoneMonthKey: "2026-11", subscriptions: subs, now: now, calendar: calendar))
        // Nothing old enough to ask about: stay quiet.
        #expect(!UsageCheckIn.isDue(lastDoneMonthKey: "", subscriptions: [sub("New", created: now)],
                                    now: now, calendar: calendar))
    }

    @Test func unusedStreakGrowsAndResets() {
        let a = sub("A", created: date(2026, 9, 1))
        let b = sub("B", created: date(2026, 9, 1))
        UsageCheckIn.record(unused: [a.id], among: [a, b])
        UsageCheckIn.record(unused: [a.id, b.id], among: [a, b])
        #expect(a.unusedMonths == 2)
        #expect(b.unusedMonths == 1)

        UsageCheckIn.record(unused: [], among: [a, b])
        #expect(a.unusedMonths == 0)
    }

    @Test func flaggedAfterTwoUnusedMonthsAndKeepIsPerStreak() {
        let a = sub("A", created: date(2026, 9, 1))
        a.unusedMonths = 1
        #expect(AttentionRadar.items(in: [a]).isEmpty)

        a.unusedMonths = 2
        let token = AttentionRadar.items(in: [a]).first?.dismissToken
        #expect(token != nil)
        let kept = Set([token].compactMap { $0 })
        #expect(AttentionRadar.items(in: [a], dismissed: kept).isEmpty)

        // A third unused month asks again.
        a.unusedMonths = 3
        #expect(AttentionRadar.items(in: [a], dismissed: kept).count == 1)
    }
}

struct CutSummaryTests {
    @Test func sumsYearlyCostOfCancelledOnly() {
        let subs = [
            Subscription(name: "Gym", amount: 40, currencyCode: "GBP", isCancelled: true),
            Subscription(name: "Mag", amount: 120, currencyCode: "GBP", billingCycle: .yearly, isCancelled: true),
            Subscription(name: "Netflix", amount: 10, currencyCode: "GBP"),
        ]
        let cut = CutSummary.make(from: subs, preferred: "GBP", rates: .fallback)
        #expect(cut.count == 2)
        #expect(cut.yearlyTotal == 600)   // 40 × 12 + 120
    }

    @Test func emptyWhenNothingCancelled() {
        let cut = CutSummary.make(from: [Subscription(name: "Netflix", amount: 10)],
                                  preferred: "GBP", rates: .fallback)
        #expect(cut.count == 0)
        #expect(cut.yearlyTotal == 0)
        #expect(cut.savedSoFar == 0)
    }

    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        DateComponents(calendar: calendar, year: y, month: m, day: d).date!
    }

    @Test func savedSoFarCountsOnlyChargesThatNeverHappened() {
        // Bills on the 20th, cancelled 5 Sep: by 22 Nov the September,
        // October and November charges were avoided.
        let gym = Subscription(name: "Gym", amount: 40, currencyCode: "GBP",
                               nextRenewalDate: date(2026, 1, 20), isCancelled: true)
        gym.cancelledAt = date(2026, 9, 5)
        // Yearly and not due until March: nothing saved yet, whatever the
        // yearly rate says.
        let mag = Subscription(name: "Mag", amount: 120, currencyCode: "GBP", billingCycle: .yearly,
                               nextRenewalDate: date(2027, 3, 1), isCancelled: true)
        mag.cancelledAt = date(2026, 9, 5)

        let cut = CutSummary.make(from: [gym, mag], preferred: "GBP", rates: .fallback,
                                  now: date(2026, 11, 22), calendar: calendar)
        #expect(cut.savedSoFar == 120)
        #expect(cut.yearlyTotal == 600)
        #expect(gym.chargesAvoided(asOf: date(2026, 9, 19), calendar: calendar) == 0)
        #expect(gym.chargesAvoided(asOf: date(2026, 9, 20), calendar: calendar) == 1)
        #expect(mag.chargesAvoided(asOf: date(2026, 11, 22), calendar: calendar) == 0)
    }

    @Test func aChargeOnTheDayOfCancellingIsNotCountedAsSaved() {
        let gym = Subscription(name: "Gym", amount: 40, currencyCode: "GBP",
                               nextRenewalDate: date(2026, 9, 20), isCancelled: true)
        gym.cancelledAt = date(2026, 9, 20)
        #expect(gym.chargesAvoided(asOf: date(2026, 9, 20), calendar: calendar) == 0)
        #expect(gym.chargesAvoided(asOf: date(2026, 10, 20), calendar: calendar) == 1)
        #expect(Subscription(name: "Netflix", amount: 10).chargesAvoided() == 0)
    }
}
