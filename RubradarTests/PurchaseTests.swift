//
//  PurchaseTests.swift
//  RubradarTests
//

import Testing
@testable import Rubradar

/// Covers the free-tier gating boundary — the rules that actually decide when the
/// paywall appears. Pure and deterministic; the StoreKit purchase/restore flow is
/// verified manually against the `Products.storekit` scheme configuration.
struct PurchaseGateTests {
    @Test func freeUserMayAddUpToTheLimit() {
        #expect(PurchaseGate.canAddSubscription(activeCount: 0, isPro: false))
        #expect(PurchaseGate.canAddSubscription(activeCount: PurchaseGate.freeSubscriptionLimit - 1, isPro: false))
    }

    @Test func freeUserBlockedAtTheLimit() {
        #expect(!PurchaseGate.canAddSubscription(activeCount: PurchaseGate.freeSubscriptionLimit, isPro: false))
        #expect(!PurchaseGate.canAddSubscription(activeCount: PurchaseGate.freeSubscriptionLimit + 10, isPro: false))
    }

    @Test func proUserIsNeverBlocked() {
        #expect(PurchaseGate.canAddSubscription(activeCount: PurchaseGate.freeSubscriptionLimit, isPro: true))
        #expect(PurchaseGate.canAddSubscription(activeCount: 9_999, isPro: true))
    }

    @Test func freeUserKeepsOneProfile() {
        #expect(PurchaseGate.canAddProfile(currentCount: 0, isPro: false))
        #expect(!PurchaseGate.canAddProfile(currentCount: PurchaseGate.freeProfileLimit, isPro: false))
        #expect(PurchaseGate.canAddProfile(currentCount: 5, isPro: true))
    }
}

/// Every paywall trigger must produce real, non-empty copy so no entry point
/// shows a blank headline.
struct PaywallContextTests {
    @Test func everyContextHasCopy() {
        for context in PaywallContext.allCases {
            #expect(!context.headline.isEmpty)
            #expect(!context.subtitle.isEmpty)
        }
    }
}
