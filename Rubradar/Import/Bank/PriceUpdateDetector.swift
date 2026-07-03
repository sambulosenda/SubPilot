//
//  PriceUpdateDetector.swift
//  Rubradar
//

import Foundation

/// A tracked subscription whose latest imported charge differs from the stored
/// price — i.e. a price change the user hasn't recorded yet.
struct PriceUpdate: Identifiable {
    let subscription: Subscription
    let newAmount: Decimal

    var id: UUID { subscription.id }
    var oldAmount: Decimal { subscription.amount }

    /// "£10.99 → £12.99"
    var transitionLabel: String {
        let code = subscription.currencyCode
        return "\(oldAmount.formatted(.currency(code: code))) → \(newAmount.formatted(.currency(code: code)))"
    }
}

/// Diffs detected recurring charges against already-tracked subscriptions to
/// surface price changes on re-import. Pure (no SwiftData queries): the caller
/// passes in the current subscriptions, like `SubscriptionDeduplicator`.
enum PriceUpdateDetector {
    static func updates(from detected: [DetectedSubscription],
                        against existing: [Subscription]) -> [PriceUpdate] {
        var seen = Set<UUID>()
        return detected.compactMap { item in
            guard let sub = SubscriptionDeduplicator.match(item, in: existing),
                  // One update per subscription even if two merchant keys match it.
                  !seen.contains(sub.id),
                  // Only compare like for like: same currency and same cadence —
                  // an annual charge isn't a "price change" on a monthly plan.
                  item.currencyCode == sub.currencyCode,
                  item.cycle == sub.billingCycle,
                  item.amount > 0, sub.amount > 0,
                  item.amount != sub.amount,
                  !sub.isCancelled
            else { return nil }
            seen.insert(sub.id)
            return PriceUpdate(subscription: sub, newAmount: item.amount)
        }
    }
}
