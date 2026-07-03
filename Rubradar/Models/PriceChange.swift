//
//  PriceChange.swift
//  Rubradar
//

import Foundation
import SwiftData

/// Where a recorded price change came from. Raw values are persisted — don't
/// rename without a migration.
enum PriceChangeSource: String {
    case manual       // user edited the amount in the form
    case bankImport   // a re-imported statement showed a different charge
    case receipt      // a scanned receipt showed a different charge
}

/// One historical price movement for a subscription, e.g. £10.99 → £12.99 on a
/// given date. Stored on-device via SwiftData and mirrored to CloudKit with the
/// rest of the store (all fields defaulted / optional, relationship optional).
@Model
final class PriceChange {
    var id: UUID = UUID()
    var oldAmount: Decimal = 0
    var newAmount: Decimal = 0
    /// Currency both amounts are in. Changes across a currency switch aren't
    /// recorded — comparing 9.99 USD to 9.99 GBP is meaningless.
    var currencyCode: String = "GBP"
    var changedAt: Date = Date()
    var sourceRaw: String = PriceChangeSource.manual.rawValue

    /// Owning subscription. Optional for CloudKit; the inverse (with cascade
    /// delete) lives on `Subscription.priceChanges`.
    var subscription: Subscription?

    init(
        oldAmount: Decimal,
        newAmount: Decimal,
        currencyCode: String,
        source: PriceChangeSource,
        changedAt: Date = Date()
    ) {
        self.id = UUID()
        self.oldAmount = oldAmount
        self.newAmount = newAmount
        self.currencyCode = currencyCode
        self.sourceRaw = source.rawValue
        self.changedAt = changedAt
    }
}

// MARK: - Bridges & display helpers

extension PriceChange {
    var source: PriceChangeSource {
        get { PriceChangeSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    /// Signed relative change, e.g. 0.18 for +18%. Nil when the old amount is
    /// zero (a free plan gaining a price isn't a percentage rise).
    var relativeChange: Decimal? {
        guard oldAmount > 0 else { return nil }
        return (newAmount - oldAmount) / oldAmount
    }

    /// "£10.99 → £12.99"
    var transitionLabel: String {
        let old = oldAmount.formatted(.currency(code: currencyCode))
        let new = newAmount.formatted(.currency(code: currencyCode))
        return "\(old) → \(new)"
    }
}

// MARK: - Recording

extension PriceChange {
    /// Records a price change on `subscription` if the amount genuinely moved:
    /// same currency, both values meaningful, different amounts. Call *after*
    /// the new amount has been written to the subscription. Returns the recorded
    /// change, or nil when nothing was recorded.
    @discardableResult
    static func record(
        on subscription: Subscription,
        oldAmount: Decimal,
        oldCurrencyCode: String,
        source: PriceChangeSource,
        in context: ModelContext
    ) -> PriceChange? {
        guard oldCurrencyCode == subscription.currencyCode,
              oldAmount != subscription.amount,
              subscription.amount > 0, oldAmount > 0 else { return nil }
        let change = PriceChange(
            oldAmount: oldAmount,
            newAmount: subscription.amount,
            currencyCode: subscription.currencyCode,
            source: source
        )
        change.subscription = subscription
        context.insert(change)
        return change
    }
}
