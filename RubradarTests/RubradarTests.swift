//
//  RubradarTests.swift
//  RubradarTests
//

import Testing
import Foundation
import SwiftData
@testable import Rubradar

struct BillingCycleTests {
    let calendar = Calendar(identifier: .gregorian)

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        DateComponents(calendar: calendar, year: y, month: m, day: d).date!
    }

    @Test func weeklyAdvancesSevenDays() {
        let start = date(2026, 1, 1)
        let next = BillingCycle.weekly.nextDate(after: start, calendar: calendar)
        #expect(next == date(2026, 1, 8))
    }

    @Test func monthlyAdvancesOneMonth() {
        let next = BillingCycle.monthly.nextDate(after: date(2026, 1, 15), calendar: calendar)
        #expect(next == date(2026, 2, 15))
    }

    @Test func yearlyAdvancesOneYear() {
        let next = BillingCycle.yearly.nextDate(after: date(2026, 3, 10), calendar: calendar)
        #expect(next == date(2027, 3, 10))
    }

    @Test func customUsesDayCount() {
        let next = BillingCycle.custom.nextDate(after: date(2026, 1, 1), customDays: 10, calendar: calendar)
        #expect(next == date(2026, 1, 11))
    }

    @Test func monthlyEquivalentNormalisesYearly() {
        let sub = Subscription(amount: 120, billingCycle: .yearly)
        #expect(sub.monthlyEquivalent == 10)
    }
}

struct CatalogueTests {
    @Test func bundledCatalogueDecodes() {
        let providers = CatalogueLoader.load(bundle: .main)
        #expect(!providers.isEmpty)
    }

    @Test func draftCarriesProviderBranding() {
        let providers = CatalogueLoader.load(bundle: .main)
        let netflix = try? #require(providers.first { $0.id == "netflix" })
        let draft = netflix?.makeDraft()
        #expect(draft?.name == "Netflix")
        #expect(draft?.category == .streaming)
        #expect(draft?.catalogueID == "netflix")
    }
}

@MainActor
struct PersistenceTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([Subscription.self])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @Test func canCreateContainer() throws {
        _ = try makeContext()
    }

    @Test func insertFetchDeleteRoundTrip() throws {
        let context = try makeContext()
        let sub = Subscription(name: "Test", amount: 9.99, category: .software)
        context.insert(sub)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Subscription>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.name == "Test")

        context.delete(sub)
        try context.save()
        #expect(try context.fetch(FetchDescriptor<Subscription>()).isEmpty)
    }

    @Test func formModelAppliesEditsOnly() throws {
        let context = try makeContext()
        let sub = Subscription(name: "Old", amount: 5, category: .other)
        context.insert(sub)

        let model = SubscriptionFormModel(source: sub)
        model.name = "New"
        model.amount = 12.50
        // Not applied yet — original unchanged (simulates Cancel).
        #expect(sub.name == "Old")

        model.apply(to: sub)
        #expect(sub.name == "New")
        #expect(sub.amount == 12.50)
    }
}
