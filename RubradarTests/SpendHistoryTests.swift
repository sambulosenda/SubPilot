//
//  SpendHistoryTests.swift
//  RubradarTests
//

import Foundation
import SwiftData
import Testing
@testable import Rubradar

@MainActor
struct SpendHistoryTests {
    private let rates = ExchangeRates(base: "GBP", date: Date(), rates: ["GBP": 1])
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Subscription.self, Profile.self, PriceChange.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        return ModelContext(container)
    }

    private func history(_ subs: [Subscription], now: Date, maxMonths: Int = 6) -> SpendHistory {
        SpendHistory.make(from: subs, preferred: "GBP", rates: rates,
                          maxMonths: maxMonths, now: now, calendar: calendar)
    }

    @Test func noTrendInTheFirstMonth() throws {
        let context = try makeContext()
        let sub = Subscription(name: "A", amount: 10, createdAt: date(2026, 11, 3))
        context.insert(sub)
        let result = history([sub], now: date(2026, 11, 20))
        #expect(result.points.map(\.total) == [10])
        #expect(!result.hasTrend)
        #expect(result.change == nil)
    }

    @Test func subscriptionCountsFromTheMonthItWasAdded() throws {
        let context = try makeContext()
        let old = Subscription(name: "A", amount: 10, createdAt: date(2026, 9, 10))
        let new = Subscription(name: "B", amount: 5, createdAt: date(2026, 11, 2))
        [old, new].forEach(context.insert)
        let result = history([old, new], now: date(2026, 11, 20))
        #expect(result.points.map(\.total) == [10, 10, 15])
        #expect(result.change == 5)
    }

    @Test func priceRiseAppliesFromItsMonth() throws {
        let context = try makeContext()
        let sub = Subscription(name: "A", amount: 12, createdAt: date(2026, 8, 1))
        context.insert(sub)
        let rise = PriceChange(oldAmount: 10, newAmount: 12, currencyCode: "GBP",
                               source: .manual, changedAt: date(2026, 10, 15))
        rise.subscription = sub
        context.insert(rise)
        let result = history([sub], now: date(2026, 11, 20))
        #expect(result.points.map(\.total) == [10, 10, 12, 12])
    }

    @Test func cancelledDropsOutFromItsMonth() throws {
        let context = try makeContext()
        let kept = Subscription(name: "A", amount: 10, createdAt: date(2026, 9, 1))
        let gone = Subscription(name: "B", amount: 7, isCancelled: true, createdAt: date(2026, 9, 1))
        gone.cancelledAt = date(2026, 10, 20)
        [kept, gone].forEach(context.insert)
        let result = history([kept, gone], now: date(2026, 11, 20))
        #expect(result.points.map(\.total) == [17, 10, 10])
        #expect(result.change == -7)
    }

    @Test func cancelledWithoutADateFallsBackToUpdatedAt() throws {
        let context = try makeContext()
        let gone = Subscription(name: "B", amount: 7, isCancelled: true, createdAt: date(2026, 9, 1))
        gone.updatedAt = date(2026, 11, 5)
        context.insert(gone)
        let result = history([gone], now: date(2026, 11, 20))
        #expect(result.points.map(\.total) == [7, 7, 0])
    }

    @Test func yearlyPlanIsSpreadAcrossMonths() throws {
        let context = try makeContext()
        let sub = Subscription(name: "A", amount: 120, billingCycle: .yearly, createdAt: date(2026, 10, 1))
        context.insert(sub)
        let result = history([sub], now: date(2026, 11, 20))
        #expect(result.points.map(\.total) == [10, 10])
    }

    @Test func windowIsCappedAtMaxMonths() throws {
        let context = try makeContext()
        let sub = Subscription(name: "A", amount: 10, createdAt: date(2025, 1, 1))
        context.insert(sub)
        let result = history([sub], now: date(2026, 11, 20), maxMonths: 6)
        #expect(result.points.count == 6)
        #expect(result.points.first?.month == calendar.date(from: DateComponents(year: 2026, month: 6)))
    }
}
