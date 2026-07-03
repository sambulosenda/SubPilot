//
//  SubscriptionCSVTests.swift
//  RubradarTests
//

import Testing
import Foundation
@testable import Rubradar

/// `SubscriptionCSV` must emit locale-independent, RFC 4180-quoted rows that the
/// import-side `CSVParser` can read back without mangling commas, quotes, or
/// newlines in user-entered names and notes.
struct SubscriptionCSVTests {
    private let utc = TimeZone(identifier: "UTC")!

    /// A fixed UTC date so the formatted day is stable across machines.
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = utc
        return cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    private func sub(_ name: String, amount: Decimal = 9.99,
                     cycle: BillingCycle = .monthly,
                     renewal: Date) -> Subscription {
        Subscription(name: name, amount: amount, currencyCode: "GBP",
                     billingCycle: cycle, nextRenewalDate: renewal,
                     category: .streaming, createdAt: renewal)
    }

    @Test func headerComesFirst() {
        let csv = SubscriptionCSV.export([], timeZone: utc)
        let firstLine = csv.split(separator: "\r\n", maxSplits: 1).first.map(String.init)
        #expect(firstLine == SubscriptionCSV.header.joined(separator: ","))
    }

    @Test func emptyExportIsHeaderOnly() {
        let csv = SubscriptionCSV.export([], timeZone: utc)
        #expect(csv == SubscriptionCSV.header.joined(separator: ",") + "\r\n")
    }

    @Test func formatsAmountDateAndEnums() {
        let s = sub("Netflix", amount: Decimal(string: "12.50")!, renewal: date(2026, 6, 15))
        let csv = SubscriptionCSV.export([s], timeZone: utc)
        let dataRow = csv.components(separatedBy: "\r\n")[1]
        // Amount has a `.` decimal point; date is ISO; enum is the raw value.
        #expect(dataRow.hasPrefix("Netflix,12.5,GBP,monthly,,2026-06-15,streaming,No,,No,3,,"))
    }

    @Test func quotesFieldsWithCommasQuotesNewlines() {
        let s = sub("Acme, Inc.", renewal: date(2026, 1, 1))
        s.notes = "Line one\nLine \"two\""
        let csv = SubscriptionCSV.export([s], timeZone: utc)
        // Comma in the name forces quoting.
        #expect(csv.contains("\"Acme, Inc.\""))
        // Internal quotes doubled, newline preserved inside quotes.
        #expect(csv.contains("\"Line one\nLine \"\"two\"\"\""))
    }

    /// Spreadsheets execute cells starting with = + - @ or a tab. Names and
    /// notes can carry imported text, so exported fields must be neutralized
    /// with a leading apostrophe.
    @Test func neutralizesSpreadsheetFormulas() {
        let s = sub("=HYPERLINK(\"http://evil.tld\")", renewal: date(2026, 1, 1))
        s.notes = "+SUM(A1:A9)"
        let csv = SubscriptionCSV.export([s], timeZone: utc)
        #expect(!csv.contains("\n=") && !csv.contains(",=") && !csv.contains("\"="))
        #expect(csv.contains("'=HYPERLINK"))
        #expect(csv.contains("'+SUM"))
    }

    @Test func roundTripsThroughCSVParser() {
        let s = sub("Spotify, Family", renewal: date(2026, 3, 9))
        s.notes = "Shared \"plan\""
        let csv = SubscriptionCSV.export([s], timeZone: utc)
        let rows = CSVParser.rows(from: csv)
        #expect(rows.count == 2)                 // header + one record
        #expect(rows[1][0] == "Spotify, Family") // comma survived
        #expect(rows[1].last == "Shared \"plan\"") // quotes survived
    }

    @Test func sortsByNameThenStable() {
        let a = sub("Zample", renewal: date(2026, 2, 2))
        let b = sub("Apple One", renewal: date(2026, 2, 2))
        let csv = SubscriptionCSV.export([a, b], timeZone: utc)
        let names = csv.components(separatedBy: "\r\n").dropFirst().compactMap {
            $0.isEmpty ? nil : $0.components(separatedBy: ",").first
        }
        #expect(names == ["Apple One", "Zample"])
    }

    @Test func includesCancelledAndTrial() {
        let trial = sub("Trial App", renewal: date(2026, 5, 1))
        trial.isFreeTrial = true
        trial.trialEndDate = date(2026, 5, 8)
        let cancelled = sub("Old Sub", renewal: date(2026, 5, 1))
        cancelled.isCancelled = true
        let csv = SubscriptionCSV.export([trial, cancelled], timeZone: utc)
        #expect(csv.contains("Trial App,9.99,GBP,monthly,,2026-05-01,streaming,Yes,2026-05-08,No,"))
        #expect(csv.contains("Old Sub,9.99,GBP,monthly,,2026-05-01,streaming,No,,Yes,"))
    }
}
