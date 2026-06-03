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

struct CurrencyTests {
    private let rates = ExchangeRates(
        base: "GBP",
        date: Date(),
        rates: ["USD": 1.25, "EUR": 1.20]
    )

    @Test func baseConvertsToItself() {
        #expect(rates.convert(10, from: "GBP", to: "GBP") == 10)
    }

    @Test func convertsViaBase() {
        // 10 USD -> GBP: 10 / 1.25 = 8
        #expect(rates.convert(10, from: "USD", to: "GBP") == 8)
        // 12 EUR -> USD: (12 / 1.20) * 1.25 = 12.5
        #expect(rates.convert(12, from: "EUR", to: "USD") == 12.5)
    }

    @Test func unknownCurrencyReturnsNil() {
        #expect(rates.convert(10, from: "XYZ", to: "GBP") == nil)
    }

    @Test func summarySumsActiveOnlyInPreferred() {
        let subs = [
            Subscription(amount: 10, currencyCode: "GBP", billingCycle: .monthly),
            Subscription(amount: 25, currencyCode: "USD", billingCycle: .monthly),      // -> 20 GBP
            Subscription(amount: 120, currencyCode: "GBP", billingCycle: .yearly),       // -> 10 GBP/mo
            Subscription(amount: 99, currencyCode: "GBP", billingCycle: .monthly, isCancelled: true), // excluded
        ]
        let summary = SpendSummary.make(from: subs, preferred: "GBP", rates: rates)
        #expect(summary.monthlyTotal == 40)
        #expect(summary.yearlyTotal == 480)
        #expect(summary.hasUnconvertible == false)
    }

    @Test func summaryFlagsUnconvertible() {
        let subs = [Subscription(amount: 5, currencyCode: "ZZZ", billingCycle: .monthly)]
        let summary = SpendSummary.make(from: subs, preferred: "GBP", rates: rates)
        #expect(summary.hasUnconvertible == true)
    }
}

struct ReceiptParsingTests {
    let parser = HeuristicReceiptParser()

    @Test func parsesNetflixReceipt() {
        let text = """
        Netflix
        Your receipt
        Total £17.99
        Next billing date 15 July 2027
        Monthly plan
        """
        let draft = parser.parse(text)
        #expect(draft.providerName == "Netflix")
        #expect(draft.amount == Decimal(string: "17.99"))
        #expect(draft.currencyCode == "GBP")
        #expect(draft.billingCycle == .monthly)
        #expect(draft.nextRenewalDate != nil)
    }

    @Test func parsesPastedEmailWithDollar() {
        let text = "Spotify Premium\nWe charged your card $11.99\nBilled monthly"
        let draft = parser.parse(text)
        #expect(draft.providerName == "Spotify")
        #expect(draft.amount == Decimal(string: "11.99"))
        #expect(draft.currencyCode == "USD")
        #expect(draft.billingCycle == .monthly)
    }

    @Test func prefersTotalLineOverSubtotal() {
        let text = "Subtotal £8.00\nVAT £1.60\nTotal £9.60"
        let draft = parser.parse(text)
        #expect(draft.amount == Decimal(string: "9.60"))
    }

    @Test func handlesEuroSuffixAndCommaDecimal() {
        let text = "Annual subscription\nTotal 9,99 €"
        let draft = parser.parse(text)
        #expect(draft.amount == Decimal(string: "9.99"))
        #expect(draft.currencyCode == "EUR")
        #expect(draft.billingCycle == .yearly)
    }

    @Test func detectsFreeTrial() {
        let draft = parser.parse("Your free trial of ChatGPT Plus has started. £0.00")
        #expect(draft.isFreeTrial == true)
    }

    @Test func emptyTextYieldsEmptyDraft() {
        #expect(parser.parse("hello there").isEmpty)
    }

    @Test func draftBuildsSubscriptionWithCatalogueBranding() {
        let draft = ReceiptDraft(providerName: "Netflix", amount: 17.99,
                                 currencyCode: "GBP", billingCycle: .monthly)
        let sub = draft.makeSubscription()
        #expect(sub.name == "Netflix")
        #expect(sub.category == .streaming)
        #expect(sub.catalogueID == "netflix")
        #expect(sub.symbolName != nil)
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
