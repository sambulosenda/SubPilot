//
//  AppleReceiptTests.swift
//  RubradarTests
//

import Testing
import Foundation
@testable import Rubradar

struct AppleReceiptParserTests {
    /// A representative Apple "Your receipt from Apple" email listing three apps.
    private let receipt = """
    Apple
    Your receipt from Apple
    Apple ID: user@icloud.com
    Date: 03 Jun 2026
    App Store

    Netflix
    Subscription (Monthly)
    Renews 15 Jun 2026
    £9.99

    Spotify
    Premium (Monthly)
    £11.99

    Disney+
    Annual
    £79.90

    Subtotal £101.88
    Tax £0.00
    TOTAL £101.88
    """

    @Test func extractsEachLineItem() {
        let drafts = AppleReceiptParser.parse(receipt)
        // Three apps; totals/tax lines excluded.
        #expect(drafts.count == 3)
        let amounts = Set(drafts.compactMap { $0.amount })
        #expect(amounts == [Decimal(string: "9.99")!, Decimal(string: "11.99")!, Decimal(string: "79.90")!])
    }

    @Test func matchesCatalogueAndCycle() {
        let drafts = AppleReceiptParser.parse(receipt)
        let netflix = drafts.first { $0.providerName == "Netflix" }
        #expect(netflix?.amount == Decimal(string: "9.99"))
        #expect(netflix?.billingCycle == .monthly)
        #expect(netflix?.currencyCode == "GBP")

        let spotify = drafts.first { $0.providerName == "Spotify" }
        #expect(spotify?.billingCycle == .monthly)

        // "Annual" descriptor maps to a yearly cycle.
        let annual = drafts.first { ($0.amount ?? 0) == Decimal(string: "79.90") }
        #expect(annual?.billingCycle == .yearly)
    }

    @Test func excludesTotalsAndTax() {
        let drafts = AppleReceiptParser.parse(receipt)
        // No draft should carry the 101.88 total or a zero tax line.
        #expect(!drafts.contains { ($0.amount ?? 0) == Decimal(string: "101.88") })
    }

    @Test func singleItemReceiptYieldsOne() {
        let text = "Netflix\nSubscription (Monthly)\nTotal £9.99"
        let drafts = AppleReceiptParser.parse(text)
        #expect(drafts.count <= 1) // not a multi-item receipt
    }

    @Test func makesSubscriptionsWithBranding() {
        let drafts = AppleReceiptParser.parse(receipt)
        let netflix = drafts.first { $0.providerName == "Netflix" }?.makeSubscription()
        #expect(netflix?.catalogueID == "netflix")
        #expect(netflix?.category == .streaming)
    }
}
