//
//  SpendBreakdownTests.swift
//  RubradarTests
//

import Testing
import Foundation
@testable import Rubradar

/// `SpendBreakdown` groups monthly-equivalent spend by category and must always
/// reconcile to the same total `SpendSummary` shows on Home, in the preferred
/// currency, ignoring cancelled subscriptions.
struct SpendBreakdownTests {
    /// GBP-only rates so amounts pass through unconverted (1.0 each).
    private let rates = ExchangeRates(base: "GBP", date: Date(), rates: ["GBP": 1])

    private func sub(_ name: String, _ amount: Decimal,
                     _ category: SubscriptionCategory,
                     cycle: BillingCycle = .monthly,
                     cancelled: Bool = false) -> Subscription {
        Subscription(name: name, amount: amount, currencyCode: "GBP",
                     billingCycle: cycle, category: category, isCancelled: cancelled)
    }

    @Test func sumsAndRanksByCategory() {
        let subs = [
            sub("Netflix", 9.99, .streaming),
            sub("Disney+", 7.99, .streaming),
            sub("Spotify", 11.99, .music),
        ]
        let breakdown = SpendBreakdown.make(from: subs, preferred: "GBP", rates: rates)

        #expect(breakdown.categories.count == 2)
        // Streaming (17.98) outranks music (11.99).
        #expect(breakdown.categories.first?.category == .streaming)
        #expect(breakdown.categories.first?.monthlyAmount == Decimal(string: "17.98"))
        #expect(breakdown.monthlyTotal == Decimal(string: "29.97"))
    }

    @Test func reconcilesWithSpendSummary() {
        let subs = [
            sub("Netflix", 9.99, .streaming),
            sub("Adobe", 120, .software, cycle: .yearly),   // 10/mo
            sub("Spotify", 11.99, .music),
        ]
        let breakdown = SpendBreakdown.make(from: subs, preferred: "GBP", rates: rates)
        let summary = SpendSummary.make(from: subs, preferred: "GBP", rates: rates)

        #expect(breakdown.monthlyTotal == summary.monthlyTotal)
    }

    @Test func fractionsSumToOne() {
        let subs = [
            sub("Netflix", 10, .streaming),
            sub("Spotify", 30, .music),
        ]
        let breakdown = SpendBreakdown.make(from: subs, preferred: "GBP", rates: rates)
        let totalFraction = breakdown.categories.reduce(0) { $0 + $1.fraction }
        #expect(abs(totalFraction - 1.0) < 0.0001)
        // Music is 30 of 40 = 75%.
        #expect(breakdown.categories.first?.category == .music)
        #expect(abs((breakdown.categories.first?.fraction ?? 0) - 0.75) < 0.0001)
    }

    @Test func excludesCancelled() {
        let subs = [
            sub("Netflix", 9.99, .streaming),
            sub("Old Gym", 40, .fitness, cancelled: true),
        ]
        let breakdown = SpendBreakdown.make(from: subs, preferred: "GBP", rates: rates)
        #expect(breakdown.categories.count == 1)
        #expect(breakdown.categories.first?.category == .streaming)
    }

    @Test func emptyWhenNoActiveSpend() {
        let breakdown = SpendBreakdown.make(from: [], preferred: "GBP", rates: rates)
        #expect(breakdown.isEmpty)
        #expect(breakdown.monthlyTotal == 0)
    }

    @Test func flagsUnconvertibleCurrency() {
        let subs = [sub("Foreign", 100, .other)].map { s -> Subscription in
            s.currencyCode = "JPY"  // no rate in GBP-only table
            return s
        }
        let breakdown = SpendBreakdown.make(from: subs, preferred: "GBP", rates: rates)
        #expect(breakdown.hasUnconvertible)
        #expect(breakdown.isEmpty)
    }
}
