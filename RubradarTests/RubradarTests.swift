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

    /// A malformed price file decodes to an empty book and silently drops every
    /// prefilled price, so the decode itself needs a guard.
    @Test func priceBookDecodesAndOnlyReferencesKnownProviders() {
        let book = CataloguePriceBook.load(bundle: .main)
        let ids = Set(CatalogueLoader.load(bundle: .main).map(\.id))
        #expect(!book.isEmpty)
        #expect(book.keys.allSatisfy { ids.contains($0) })
        #expect(book.values.allSatisfy { plans in
            !plans.isEmpty && plans.allSatisfy { !$0.amounts.isEmpty && $0.amounts.values.allSatisfy { $0 > 0 } }
        })
        // Plan ids drive ForEach identity in the quick-add sheet.
        #expect(book.values.allSatisfy { Set($0.map(\.id)).count == $0.count })
    }

    @Test func plansAreFilteredToTheRequestedCurrency() {
        let book = ["svc": [
            CataloguePlan(name: "US only", cycle: .monthly, amounts: ["USD": 999], isDefault: nil),
            CataloguePlan(name: "Both", cycle: .yearly, amounts: ["USD": 1799, "GBP": 1299], isDefault: nil),
        ]]
        let gbp = CataloguePriceBook.plans(for: "svc", currencyCode: "GBP", in: book)
        #expect(gbp.map(\.name) == ["Both"])
        #expect(gbp.first?.amount(in: "GBP") == Decimal(string: "12.99"))
        #expect(CataloguePriceBook.plans(for: "svc", currencyCode: "JPY", in: book).isEmpty)
        #expect(CataloguePriceBook.defaultPlan(for: "missing", currencyCode: "USD", in: book) == nil)
    }

    @Test func defaultPlanPrefersTheFlaggedTier() {
        let book = ["svc": [
            CataloguePlan(name: "Small", cycle: .monthly, amounts: ["USD": 99], isDefault: nil),
            CataloguePlan(name: "Medium", cycle: .monthly, amounts: ["USD": 299], isDefault: true),
        ]]
        #expect(CataloguePriceBook.defaultPlan(for: "svc", currencyCode: "USD", in: book)?.name == "Medium")
        // The flag only wins where that tier is priced in the currency asked for.
        let partial = ["svc": [
            CataloguePlan(name: "Small", cycle: .monthly, amounts: ["GBP": 99], isDefault: nil),
            CataloguePlan(name: "Medium", cycle: .monthly, amounts: ["USD": 299], isDefault: true),
        ]]
        #expect(CataloguePriceBook.defaultPlan(for: "svc", currencyCode: "GBP", in: partial)?.name == "Small")
    }

    /// Onboarding stamps a starter's monthly price onto a draft whose cycle comes
    /// from the default plan — a yearly default would bill that price yearly.
    @Test func onboardingStartersDefaultToMonthlyPlans() {
        let book = CataloguePriceBook.load(bundle: .main)
        for starter in OnboardingStarter.load() {
            for currency in ["USD", "GBP", "EUR"] {
                let plan = CataloguePriceBook.defaultPlan(for: starter.id, currencyCode: currency, in: book)
                #expect(plan.map { $0.cycle == .monthly } ?? true, "\(starter.id) \(currency)")
            }
        }
    }

    @Test func draftUsesAnExplicitPlan() throws {
        let netflix = try #require(CatalogueLoader.load(bundle: .main).first { $0.id == "netflix" })
        let currency = Locale.current.currency?.identifier ?? "GBP"
        let plan = CataloguePlan(name: "Test", cycle: .yearly, amounts: [currency: 4250], isDefault: nil)
        let draft = netflix.makeDraft(plan: plan)
        #expect(draft.amount == Decimal(string: "42.5"))
        #expect(draft.billingCycle == .yearly)
        #expect(draft.currencyCode == currency)
    }

    /// Guards against a silent decode failure: CatalogueLoader returns [] if any
    /// row's category/cycle doesn't match the enums, which would empty the UI.
    @Test func catalogueDecodesFullyWithUniqueIDsAndDomains() {
        let providers = CatalogueLoader.load(bundle: .main)
        #expect(providers.count == 243)
        #expect(Set(providers.map(\.id)).count == providers.count)
        #expect(providers.allSatisfy { ($0.domain ?? "").contains(".") })
    }

    @Test func catalogueCoversEveryCategory() {
        let providers = CatalogueLoader.load(bundle: .main)
        #expect(Set(providers.map(\.category)) == Set(SubscriptionCategory.allCases))
    }

    @Test func catalogueMatchesNewProvidersInReceiptText() {
        let providers = CatalogueLoader.load(bundle: .main)
        #expect(CatalogueLoader.match(in: "Your NordVPN receipt", providers: providers)?.name == "NordVPN")
        #expect(CatalogueLoader.match(in: "DUOLINGO Super", providers: providers)?.name == "Duolingo")
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

struct RenewalProjectorTests {
    let calendar = Calendar(identifier: .gregorian)

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        DateComponents(calendar: calendar, year: y, month: m, day: d).date!
    }

    private let rates = ExchangeRates(base: "GBP", date: Date(), rates: ["USD": 1.25])

    @Test func excludesCancelledSubscriptions() {
        let sub = Subscription(amount: 10, billingCycle: .monthly,
                               nextRenewalDate: date(2026, 6, 20), isCancelled: true)
        let events = RenewalProjector.events(for: [sub], from: date(2026, 6, 1), calendar: calendar)
        #expect(events.isEmpty)
    }

    @Test func rollsStaleAnchorForwardToFuture() {
        let sub = Subscription(amount: 10, billingCycle: .monthly, nextRenewalDate: date(2026, 4, 10))
        let events = RenewalProjector.events(for: [sub], from: date(2026, 6, 15), calendar: calendar)
        #expect(events.first?.date == date(2026, 7, 10))
        #expect(events.allSatisfy { $0.date >= date(2026, 6, 15) })
    }

    @Test func yearlyYieldsSingleEventWithinHorizon() {
        let sub = Subscription(amount: 99, billingCycle: .yearly, nextRenewalDate: date(2026, 9, 1))
        let events = RenewalProjector.events(for: [sub], from: date(2026, 6, 1),
                                             horizonMonths: 12, calendar: calendar)
        #expect(events.count == 1)
        #expect(events.first?.date == date(2026, 9, 1))
    }

    @Test func freeTrialFirstEventIsMarked() {
        let sub = Subscription(amount: 12, billingCycle: .monthly, nextRenewalDate: date(2026, 6, 1),
                               isFreeTrial: true, trialEndDate: date(2026, 6, 8))
        let events = RenewalProjector.events(for: [sub], from: date(2026, 6, 1), calendar: calendar)
        #expect(events.first?.date == date(2026, 6, 8))
        #expect(events.first?.isTrialEnd == true)
        // Subsequent recurrences are normal renewals.
        #expect(events.dropFirst().allSatisfy { !$0.isTrialEnd })
    }

    @Test func eventsAreSortedByDate() {
        let subs = [
            Subscription(amount: 5, billingCycle: .monthly, nextRenewalDate: date(2026, 6, 25)),
            Subscription(amount: 5, billingCycle: .monthly, nextRenewalDate: date(2026, 6, 10)),
        ]
        let events = RenewalProjector.events(for: subs, from: date(2026, 6, 1),
                                             horizonMonths: 1, calendar: calendar)
        let dates = events.map(\.date)
        #expect(dates == dates.sorted())
    }

    @Test func groupsByMonthAndSumsConverted() {
        let subs = [
            Subscription(amount: 10, currencyCode: "GBP", billingCycle: .monthly, nextRenewalDate: date(2026, 6, 20)),
            Subscription(amount: 25, currencyCode: "USD", billingCycle: .monthly, nextRenewalDate: date(2026, 6, 25)),
        ]
        let events = RenewalProjector.events(for: subs, from: date(2026, 6, 1),
                                             horizonMonths: 1, calendar: calendar)
        let months = RenewalMonth.group(events, preferred: "GBP", rates: rates, calendar: calendar)
        #expect(months.count == 1)
        #expect(months.first?.total == 30) // 10 GBP + (25 USD / 1.25 = 20 GBP)
        #expect(months.first?.hasUnconvertible == false)
    }

    @Test func flagsUnconvertibleCurrencyInMonth() {
        let sub = Subscription(amount: 5, currencyCode: "ZZZ", billingCycle: .monthly,
                               nextRenewalDate: date(2026, 6, 20))
        let events = RenewalProjector.events(for: [sub], from: date(2026, 6, 1),
                                             horizonMonths: 1, calendar: calendar)
        let months = RenewalMonth.group(events, preferred: "GBP", rates: rates, calendar: calendar)
        #expect(months.first?.hasUnconvertible == true)
    }
}

struct HomeMetricsTests {
    let calendar = Calendar(identifier: .gregorian)
    private let rates = ExchangeRates(base: "GBP", date: Date(), rates: ["USD": 1.25])

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        DateComponents(calendar: calendar, year: y, month: m, day: d).date!
    }

    @Test func countsActiveSubscriptionsOnly() {
        let subs = [
            Subscription(amount: 10, billingCycle: .monthly, nextRenewalDate: date(2026, 6, 20)),
            Subscription(amount: 5, billingCycle: .monthly, nextRenewalDate: date(2026, 6, 25)),
            Subscription(amount: 9, billingCycle: .monthly, nextRenewalDate: date(2026, 6, 28), isCancelled: true),
        ]
        let metrics = HomeMetrics.make(from: subs, preferred: "GBP", rates: rates,
                                       now: date(2026, 6, 1), calendar: calendar)
        #expect(metrics.activeCount == 2)
    }

    @Test func daysUntilNextChargeUsesSoonestEvent() {
        let subs = [
            Subscription(amount: 10, billingCycle: .monthly, nextRenewalDate: date(2026, 6, 20)),
            Subscription(amount: 5, billingCycle: .monthly, nextRenewalDate: date(2026, 6, 6)),
        ]
        let metrics = HomeMetrics.make(from: subs, preferred: "GBP", rates: rates,
                                       now: date(2026, 6, 1), calendar: calendar)
        #expect(metrics.daysUntilNextCharge == 5)
        #expect(metrics.nextChargeLabel == "5 days")
    }

    @Test func dueThisMonthFractionIsFullWhenAllSpendRenewsThisMonth() {
        let sub = Subscription(amount: 10, currencyCode: "GBP", billingCycle: .monthly,
                               nextRenewalDate: date(2026, 6, 20))
        let metrics = HomeMetrics.make(from: [sub], preferred: "GBP", rates: rates,
                                       now: date(2026, 6, 1), calendar: calendar)
        #expect(metrics.dueThisMonthFraction == 1)
    }

    @Test func dueThisMonthFractionIsZeroWhenNothingRenewsThisMonth() {
        // Yearly bill three months out — no charge this calendar month.
        let sub = Subscription(amount: 120, currencyCode: "GBP", billingCycle: .yearly,
                               nextRenewalDate: date(2026, 9, 1))
        let metrics = HomeMetrics.make(from: [sub], preferred: "GBP", rates: rates,
                                       now: date(2026, 6, 1), calendar: calendar)
        #expect(metrics.dueThisMonthFraction == 0)
    }

    @Test func emptyHasNoNextChargeLabel() {
        let metrics = HomeMetrics.make(from: [], preferred: "GBP", rates: rates,
                                       now: date(2026, 6, 1), calendar: calendar)
        #expect(metrics.daysUntilNextCharge == nil)
        #expect(metrics.nextChargeLabel == "—")
    }
}

@MainActor
struct PersistenceTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([Subscription.self, Profile.self, PriceChange.self])
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
