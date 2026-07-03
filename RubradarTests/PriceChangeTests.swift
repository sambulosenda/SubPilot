//
//  PriceChangeTests.swift
//  RubradarTests
//

import Testing
import Foundation
import SwiftData
@testable import Rubradar

struct PriceUpdateDetectorTests {
    private func detection(key: String, providerID: String? = nil, amount: Decimal,
                           currency: String = "GBP", cycle: BillingCycle = .monthly) -> DetectedSubscription {
        DetectedSubscription(displayName: key, rawMerchant: key, normalizedKey: key, amount: amount,
                             currencyCode: currency, cycle: cycle, lastSeen: Date(),
                             occurrenceCount: 3, confidence: 0.9, matchedProviderID: providerID)
    }

    @Test func detectsRaisedPriceOnTrackedSubscription() {
        let existing = [Subscription(name: "Netflix", amount: 10.99, catalogueID: "netflix")]
        let updates = PriceUpdateDetector.updates(
            from: [detection(key: "netflix", providerID: "netflix", amount: 12.99)],
            against: existing)
        #expect(updates.count == 1)
        #expect(updates.first?.oldAmount == 10.99)
        #expect(updates.first?.newAmount == 12.99)
    }

    @Test func detectsLoweredPrice() {
        let existing = [Subscription(name: "Acme Box", amount: 12.00)]
        let updates = PriceUpdateDetector.updates(
            from: [detection(key: "acme box", amount: 10.00)], against: existing)
        #expect(updates.first?.newAmount == 10.00)
    }

    @Test func ignoresUnchangedPrice() {
        let existing = [Subscription(name: "Netflix", amount: 9.99, catalogueID: "netflix")]
        let updates = PriceUpdateDetector.updates(
            from: [detection(key: "netflix", providerID: "netflix", amount: 9.99)],
            against: existing)
        #expect(updates.isEmpty)
    }

    @Test func ignoresUntrackedMerchants() {
        let updates = PriceUpdateDetector.updates(
            from: [detection(key: "acme box", amount: 10.00)], against: [])
        #expect(updates.isEmpty)
    }

    @Test func ignoresCurrencyMismatch() {
        let existing = [Subscription(name: "Netflix", amount: 10.99, currencyCode: "GBP", catalogueID: "netflix")]
        let updates = PriceUpdateDetector.updates(
            from: [detection(key: "netflix", providerID: "netflix", amount: 12.99, currency: "USD")],
            against: existing)
        #expect(updates.isEmpty)
    }

    @Test func ignoresCycleMismatch() {
        // An annual charge is not a price change on a monthly plan.
        let existing = [Subscription(name: "Netflix", amount: 10.99, billingCycle: .monthly, catalogueID: "netflix")]
        let updates = PriceUpdateDetector.updates(
            from: [detection(key: "netflix", providerID: "netflix", amount: 99.99, cycle: .yearly)],
            against: existing)
        #expect(updates.isEmpty)
    }

    @Test func ignoresCancelledSubscriptions() {
        let existing = [Subscription(name: "Netflix", amount: 10.99, isCancelled: true, catalogueID: "netflix")]
        let updates = PriceUpdateDetector.updates(
            from: [detection(key: "netflix", providerID: "netflix", amount: 12.99)],
            against: existing)
        #expect(updates.isEmpty)
    }

    @Test func oneUpdatePerSubscription() {
        // Two merchant keys resolving to the same sub must not produce two updates.
        let existing = [Subscription(name: "Netflix", amount: 10.99, catalogueID: "netflix")]
        let updates = PriceUpdateDetector.updates(
            from: [detection(key: "netflix", providerID: "netflix", amount: 12.99),
                   detection(key: "netflix com", providerID: "netflix", amount: 12.99)],
            against: existing)
        #expect(updates.count == 1)
    }
}

@MainActor
struct PriceChangeRecordingTests {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Subscription.self, Profile.self, PriceChange.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        return ModelContext(container)
    }

    @Test func recordsAmountChange() throws {
        let context = try makeContext()
        let sub = Subscription(name: "Netflix", amount: 10.99)
        context.insert(sub)
        sub.amount = 12.99
        let change = PriceChange.record(on: sub, oldAmount: 10.99, oldCurrencyCode: "GBP",
                                        source: .bankImport, in: context)
        #expect(change != nil)
        #expect(change?.oldAmount == 10.99)
        #expect(change?.newAmount == 12.99)
        #expect(change?.source == .bankImport)
        #expect(sub.priceHistory.count == 1)
    }

    @Test func skipsWhenAmountUnchanged() throws {
        let context = try makeContext()
        let sub = Subscription(name: "Netflix", amount: 10.99)
        context.insert(sub)
        let change = PriceChange.record(on: sub, oldAmount: 10.99, oldCurrencyCode: "GBP",
                                        source: .manual, in: context)
        #expect(change == nil)
        #expect(sub.priceHistory.isEmpty)
    }

    @Test func skipsAcrossCurrencySwitch() throws {
        let context = try makeContext()
        let sub = Subscription(name: "Netflix", amount: 12.99, currencyCode: "USD")
        context.insert(sub)
        let change = PriceChange.record(on: sub, oldAmount: 10.99, oldCurrencyCode: "GBP",
                                        source: .manual, in: context)
        #expect(change == nil)
    }

    @Test func historyIsNewestFirst() throws {
        let context = try makeContext()
        let sub = Subscription(name: "Netflix", amount: 10.99)
        context.insert(sub)
        let older = PriceChange(oldAmount: 8.99, newAmount: 10.99, currencyCode: "GBP",
                                source: .manual, changedAt: Date(timeIntervalSinceNow: -86_400 * 30))
        older.subscription = sub
        context.insert(older)
        let newer = PriceChange(oldAmount: 10.99, newAmount: 12.99, currencyCode: "GBP",
                                source: .bankImport, changedAt: Date())
        newer.subscription = sub
        context.insert(newer)
        #expect(sub.priceHistory.map(\.newAmount) == [12.99, 10.99])
    }

    @Test func relativeChangeMath() {
        let rise = PriceChange(oldAmount: 10, newAmount: 12, currencyCode: "GBP", source: .manual)
        #expect(rise.relativeChange == 0.2)
        let fromFree = PriceChange(oldAmount: 0, newAmount: 5, currencyCode: "GBP", source: .manual)
        #expect(fromFree.relativeChange == nil)
    }
}

@MainActor
struct RecapPriceChangeTests {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Subscription.self, Profile.self, PriceChange.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        return ModelContext(container)
    }

    private func attach(_ change: PriceChange, to sub: Subscription, in context: ModelContext) {
        change.subscription = sub
        context.insert(change)
    }

    @Test func includesRecentChangeAndFlagsRise() throws {
        let context = try makeContext()
        let sub = Subscription(name: "Netflix", amount: 12.99)
        context.insert(sub)
        attach(PriceChange(oldAmount: 10.99, newAmount: 12.99, currencyCode: "GBP",
                           source: .bankImport, changedAt: Date(timeIntervalSinceNow: -5 * 86_400)),
               to: sub, in: context)
        let recent = MonthlyRecapData.recentPriceChanges(in: [sub])
        #expect(recent.count == 1)
        #expect(recent.first?.name == "Netflix")
        #expect(recent.first?.isRise == true)
    }

    @Test func excludesChangesOlderThanWindow() throws {
        let context = try makeContext()
        let sub = Subscription(name: "Netflix", amount: 12.99)
        context.insert(sub)
        attach(PriceChange(oldAmount: 10.99, newAmount: 12.99, currencyCode: "GBP",
                           source: .manual, changedAt: Date(timeIntervalSinceNow: -40 * 86_400)),
               to: sub, in: context)
        #expect(MonthlyRecapData.recentPriceChanges(in: [sub]).isEmpty)
    }

    @Test func excludesCancelledSubscriptions() throws {
        let context = try makeContext()
        let sub = Subscription(name: "Netflix", amount: 12.99, isCancelled: true)
        context.insert(sub)
        attach(PriceChange(oldAmount: 10.99, newAmount: 12.99, currencyCode: "GBP",
                           source: .manual, changedAt: Date(timeIntervalSinceNow: -5 * 86_400)),
               to: sub, in: context)
        #expect(MonthlyRecapData.recentPriceChanges(in: [sub]).isEmpty)
    }

    @Test func newestFirstAndDropFlagged() throws {
        let context = try makeContext()
        let netflix = Subscription(name: "Netflix", amount: 12.99)
        let spotify = Subscription(name: "Spotify", amount: 9.99)
        context.insert(netflix)
        context.insert(spotify)
        attach(PriceChange(oldAmount: 10.99, newAmount: 12.99, currencyCode: "GBP",
                           source: .manual, changedAt: Date(timeIntervalSinceNow: -10 * 86_400)),
               to: netflix, in: context)
        attach(PriceChange(oldAmount: 11.99, newAmount: 9.99, currencyCode: "GBP",
                           source: .manual, changedAt: Date(timeIntervalSinceNow: -2 * 86_400)),
               to: spotify, in: context)
        let recent = MonthlyRecapData.recentPriceChanges(in: [netflix, spotify])
        #expect(recent.map(\.name) == ["Spotify", "Netflix"])
        #expect(recent.first?.isRise == false)
    }
}
