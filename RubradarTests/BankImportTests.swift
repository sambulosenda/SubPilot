//
//  BankImportTests.swift
//  RubradarTests
//

import Testing
import Foundation
@testable import Rubradar

struct CSVParserTests {
    @Test func parsesSimpleRows() {
        let rows = CSVParser.rows(from: "a,b,c\n1,2,3\n")
        #expect(rows == [["a", "b", "c"], ["1", "2", "3"]])
    }

    @Test func handlesQuotedFieldsWithCommas() {
        let rows = CSVParser.rows(from: "date,desc,amount\n2026-01-01,\"NETFLIX, INC\",-9.99")
        #expect(rows.count == 2)
        #expect(rows[1] == ["2026-01-01", "NETFLIX, INC", "-9.99"])
    }

    @Test func handlesEscapedQuotesAndCRLF() {
        let rows = CSVParser.rows(from: "a,b\r\n\"say \"\"hi\"\"\",2\r\n")
        #expect(rows[1][0] == "say \"hi\"")
        #expect(rows[1][1] == "2")
    }

    @Test func stripsBOMAndBlankLines() {
        let data = Data("\u{FEFF}a,b\n\n1,2\n".utf8)
        let rows = CSVParser.rows(from: data)
        #expect(rows.first == ["a", "b"])
        #expect(rows.count == 2) // blank line dropped
    }
}

struct StatementColumnMapperTests {
    @Test func detectsStandardHeaderLayout() {
        let rows = [
            ["Date", "Description", "Amount"],
            ["2026-01-15", "NETFLIX.COM", "-9.99"],
            ["2026-01-16", "TESCO", "-42.10"],
        ]
        let mapping = StatementColumnMapper.autoDetect(rows: rows)
        #expect(mapping.hasHeaderRow)
        #expect(mapping.dateIndex == 0)
        #expect(mapping.descriptionIndex == 1)
        #expect(mapping.amountIndex == 2)
    }

    @Test func detectsDebitCreditPair() {
        let rows = [
            ["Date", "Details", "Money Out", "Money In"],
            ["2026-01-15", "SPOTIFY", "11.99", ""],
            ["2026-01-20", "SALARY", "", "2000.00"],
        ]
        let mapping = StatementColumnMapper.autoDetect(rows: rows)
        #expect(mapping.debitIndex == 2)
        #expect(mapping.creditIndex == 3)
        #expect(mapping.amountIndex == nil)
        #expect(mapping.descriptionIndex == 1)
    }

    @Test func infersHeaderlessLayoutByShape() {
        let rows = [
            ["15/01/2026", "NETFLIX SUBSCRIPTION", "-9.99"],
            ["16/01/2026", "SPOTIFY PREMIUM PLAN", "-11.99"],
            ["17/01/2026", "DISNEY PLUS MONTHLY", "-7.99"],
        ]
        let mapping = StatementColumnMapper.autoDetect(rows: rows)
        #expect(!mapping.hasHeaderRow)
        #expect(mapping.dateIndex == 0)
        #expect(mapping.amountIndex == 2)
        #expect(mapping.descriptionIndex == 1)
    }
}

struct MerchantNormalizerTests {
    @Test func stripsProcessorPrefixes() {
        #expect(MerchantNormalizer.key(for: "SQ *COFFEE 0123") == "coffee")
        #expect(MerchantNormalizer.key(for: "PAYPAL *SPOTIFY") == "spotify")
    }

    @Test func collapsesDomainAndPhoneNoise() {
        #expect(MerchantNormalizer.key(for: "NETFLIX.COM 866-579-7172") == "netflix")
    }

    @Test func variantsShareAKey() {
        let a = MerchantNormalizer.key(for: "SQ *NETFLIX")
        let b = MerchantNormalizer.key(for: "NETFLIX.COM")
        #expect(a == b)
    }
}

struct StatementParserTests {
    private let mapping = ColumnMapping(hasHeaderRow: true, dateIndex: 0, descriptionIndex: 1,
                                        amountIndex: 2, debitIndex: nil, creditIndex: nil)

    @Test func keepsDebitsDropsCredits() {
        let rows = [
            ["Date", "Description", "Amount"],
            ["2026-01-15", "NETFLIX", "-9.99"],
            ["2026-01-20", "REFUND", "12.00"], // positive = money in, dropped
        ]
        let txns = StatementParser.transactions(rows: rows, mapping: mapping)
        #expect(txns.count == 1)
        #expect(txns.first?.description == "NETFLIX")
        #expect(txns.first?.amount == Decimal(string: "9.99"))
    }

    @Test func parsesDebitCreditColumns() {
        let mapping = ColumnMapping(hasHeaderRow: true, dateIndex: 0, descriptionIndex: 1,
                                    amountIndex: nil, debitIndex: 2, creditIndex: 3)
        let rows = [
            ["Date", "Details", "Out", "In"],
            ["2026-01-15", "SPOTIFY", "11.99", ""],
            ["2026-01-20", "SALARY", "", "2000.00"],
        ]
        let txns = StatementParser.transactions(rows: rows, mapping: mapping)
        #expect(txns.count == 1)
        #expect(txns.first?.amount == Decimal(string: "11.99"))
    }

    @Test func parsesAmountWithSymbolAndThousands() {
        #expect(StatementParser.parseAmount("£1,234.56")?.magnitude == Decimal(string: "1234.56"))
        #expect(StatementParser.parseAmount("(9.99)")?.isNegative == true)
        #expect(StatementParser.parseAmount("9,99")?.magnitude == Decimal(string: "9.99")) // EU decimal comma
        #expect(StatementParser.parseAmount("1,234")?.magnitude == Decimal(string: "1234")) // thousands, no decimal
    }

    /// European statements/receipts write €1.234,56 — the separator that occurs
    /// last is the decimal one. A lone separator with a 3-digit tail is
    /// grouping ("1,234" = 1234), except after a bare zero ("0,999" = 0.999).
    @Test func parsesEuropeanAndGroupedAmounts() {
        #expect(HeuristicReceiptParser.decimal(from: "1.234,56") == Decimal(string: "1234.56")) // EU
        #expect(HeuristicReceiptParser.decimal(from: "1,234.56") == Decimal(string: "1234.56")) // US
        #expect(HeuristicReceiptParser.decimal(from: "1.234") == Decimal(string: "1234"))       // EU thousands
        #expect(HeuristicReceiptParser.decimal(from: "1,234") == Decimal(string: "1234"))       // US thousands
        #expect(HeuristicReceiptParser.decimal(from: "9,99") == Decimal(string: "9.99"))
        #expect(HeuristicReceiptParser.decimal(from: "0,999") == Decimal(string: "0.999"))
        #expect(HeuristicReceiptParser.decimal(from: "12.345.678,90") == Decimal(string: "12345678.90"))
        #expect(StatementParser.parseAmount("1.234,56 €")?.magnitude == Decimal(string: "1234.56"))
    }

    /// Receipt lines reach `decimal(from:)` straight from the regex capture —
    /// "¥1,500" must import as 1500, not 1.5.
    @Test func receiptAmountsKeepThousandsGrouping() {
        let matches = HeuristicReceiptParser.amounts(in: "Total ¥1,500")
        #expect(matches.contains { $0.0 == Decimal(1500) && $0.1 == "JPY" })
    }
}

struct RecurringChargeDetectorTests {
    let calendar = Calendar(identifier: .gregorian)
    private var detector: RecurringChargeDetector { RecurringChargeDetector(calendar: calendar) }
    private let reference = DateComponents(calendar: Calendar(identifier: .gregorian), year: 2026, month: 7, day: 1).date!

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        DateComponents(calendar: calendar, year: y, month: m, day: d).date!
    }

    private func monthly(_ name: String, amount: Decimal, months: Int) -> [BankTransaction] {
        (0..<months).map { BankTransaction(date: day(2026, 1 + $0, 15), description: name, amount: amount, currencyCode: "GBP") }
    }

    @Test func detectsMonthlySubscription() {
        let txns = monthly("NETFLIX.COM", amount: 9.99, months: 6)
        let detected = detector.detect(txns, referenceDate: reference)
        let netflix = detected.first { $0.normalizedKey == "netflix" }
        #expect(netflix?.cycle == .monthly)
        #expect(netflix?.occurrenceCount == 6)
        #expect((netflix?.confidence ?? 0) >= 0.6)
    }

    @Test func detectsAnnualSubscription() {
        let txns = [
            BankTransaction(date: day(2025, 3, 10), description: "Amazon Prime", amount: 95, currencyCode: "GBP"),
            BankTransaction(date: day(2026, 3, 10), description: "Amazon Prime", amount: 95, currencyCode: "GBP"),
        ]
        let detected = detector.detect(txns, referenceDate: reference)
        #expect(detected.first?.cycle == .yearly)
    }

    @Test func rejectsIrregularSpending() {
        let txns = [
            BankTransaction(date: day(2026, 1, 3), description: "TESCO STORES", amount: 42.10, currencyCode: "GBP"),
            BankTransaction(date: day(2026, 1, 9), description: "TESCO STORES", amount: 7.80, currencyCode: "GBP"),
            BankTransaction(date: day(2026, 2, 2), description: "TESCO STORES", amount: 88.40, currencyCode: "GBP"),
            BankTransaction(date: day(2026, 2, 19), description: "TESCO STORES", amount: 15.00, currencyCode: "GBP"),
        ]
        let detected = detector.detect(txns, referenceDate: reference)
        // Irregular intervals + wildly varying amounts → not a subscription.
        #expect(detected.first { $0.normalizedKey == "tesco stores" } == nil)
    }

    @Test func groupsMerchantVariantsAndMatchesCatalogue() {
        let txns = [
            BankTransaction(date: day(2026, 1, 15), description: "SQ *NETFLIX", amount: 9.99, currencyCode: "GBP"),
            BankTransaction(date: day(2026, 2, 15), description: "NETFLIX.COM", amount: 9.99, currencyCode: "GBP"),
            BankTransaction(date: day(2026, 3, 15), description: "NETFLIX.COM 866", amount: 9.99, currencyCode: "GBP"),
        ]
        let detected = detector.detect(txns, referenceDate: reference)
        let netflix = detected.first { $0.normalizedKey == "netflix" }
        #expect(netflix != nil)
        #expect(netflix?.occurrenceCount == 3)
        #expect(netflix?.matchedProviderID == "netflix")
        #expect(netflix?.displayName == "Netflix")
    }

    @Test func singleUnknownChargeIsNotProposed() {
        let txns = [BankTransaction(date: day(2026, 6, 1), description: "RANDOM SHOP 42", amount: 5, currencyCode: "GBP")]
        #expect(detector.detect(txns, referenceDate: reference).isEmpty)
    }

    @Test func nextRenewalIsInTheFuture() {
        let txns = monthly("NETFLIX.COM", amount: 9.99, months: 6)
        let detected = detector.detect(txns, referenceDate: reference).first { $0.normalizedKey == "netflix" }
        let draft = detected?.makeDraft(referenceDate: reference, calendar: calendar)
        #expect((draft?.nextRenewalDate ?? .distantPast) >= reference)
    }
}

struct SubscriptionDeduplicatorTests {
    private func detection(key: String, providerID: String?, amount: Decimal) -> DetectedSubscription {
        DetectedSubscription(displayName: key, rawMerchant: key, normalizedKey: key, amount: amount,
                             currencyCode: "GBP", cycle: .monthly, lastSeen: Date(),
                             occurrenceCount: 3, confidence: 0.9, matchedProviderID: providerID)
    }

    @Test func flagsByCatalogueID() {
        let existing = [Subscription(name: "Netflix", amount: 9.99, catalogueID: "netflix")]
        let marked = SubscriptionDeduplicator.mark([detection(key: "netflix", providerID: "netflix", amount: 9.99)], against: existing)
        #expect(marked.first?.alreadyTracked == true)
    }

    @Test func flagsByNameAndCloseAmount() {
        let existing = [Subscription(name: "Acme Box", amount: 10.00)]
        let marked = SubscriptionDeduplicator.mark([detection(key: "acme box", providerID: nil, amount: 11.00)], against: existing)
        #expect(marked.first?.alreadyTracked == true)
    }

    @Test func doesNotFlagDifferentAmount() {
        let existing = [Subscription(name: "Acme Box", amount: 10.00)]
        let marked = SubscriptionDeduplicator.mark([detection(key: "acme box", providerID: nil, amount: 30.00)], against: existing)
        #expect(marked.first?.alreadyTracked == false)
    }
}
