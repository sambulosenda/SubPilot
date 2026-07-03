//
//  SubscriptionDeduplicator.swift
//  Rubradar
//

import Foundation

/// Flags detected subscriptions the user already tracks, so the review list can
/// deselect / disable them instead of creating duplicates. Pure (no SwiftData):
/// the caller passes in the current subscriptions.
enum SubscriptionDeduplicator {
    static func mark(_ detected: [DetectedSubscription], against existing: [Subscription]) -> [DetectedSubscription] {
        detected.map { item in
            var copy = item
            copy.alreadyTracked = match(item, in: existing) != nil
            return copy
        }
    }

    /// The tracked subscription a detection corresponds to, if any. Also used by
    /// `PriceUpdateDetector` to diff a re-imported charge against the stored price.
    static func match(_ detected: DetectedSubscription, in existing: [Subscription]) -> Subscription? {
        existing.first { matches(detected, $0) }
    }

    private static func matches(_ detected: DetectedSubscription, _ subscription: Subscription) -> Bool {
        // Strongest signal: the same catalogue provider.
        if let id = detected.matchedProviderID, subscription.catalogueID == id { return true }
        // Otherwise: same normalized name and a comparable amount.
        guard MerchantNormalizer.key(for: subscription.name) == detected.normalizedKey else { return false }
        return amountClose(detected.amount, subscription.amount)
    }

    private static func amountClose(_ a: Decimal, _ b: Decimal) -> Bool {
        let x = NSDecimalNumber(decimal: a).doubleValue
        let y = NSDecimalNumber(decimal: b).doubleValue
        guard x > 0, y > 0 else { return false }
        return abs(x - y) / max(x, y) <= 0.2
    }
}
