//
//  RecurringChargeDetector.swift
//  Rubradar
//

import Foundation

/// A recurring charge the detector believes is a subscription.
struct DetectedSubscription: Identifiable, Equatable {
    var displayName: String
    var rawMerchant: String
    var normalizedKey: String
    var amount: Decimal           // the most recent charge (current price)
    var currencyCode: String
    var cycle: BillingCycle
    var lastSeen: Date
    var occurrenceCount: Int
    var confidence: Double
    var matchedProviderID: String?
    var alreadyTracked: Bool = false

    var id: String { normalizedKey }

    /// Builds a draft for the add path so all catalogue branding / defaults
    /// (`ReceiptDraft.makeSubscription`) are reused — no duplicated logic.
    func makeDraft(referenceDate: Date = Date(), calendar: Calendar = .current) -> ReceiptDraft {
        // Project forward from the last observed charge (start-of-day, so a
        // renewal landing today isn't pushed a full cycle out). Index 0 is the
        // charge we already saw — the draft's next renewal is at least one
        // cycle after it.
        let today = calendar.startOfDay(for: referenceDate)
        let (n, projected) = cycle.firstOccurrence(onOrAfter: today, anchor: lastSeen, calendar: calendar)
        let next = n == 0 ? cycle.date(byAddingCycles: 1, to: lastSeen, calendar: calendar) : projected
        return ReceiptDraft(providerName: displayName, amount: amount,
                            currencyCode: currencyCode, billingCycle: cycle, nextRenewalDate: next)
    }
}

/// Finds recurring charges in a list of statement transactions: groups by
/// normalized merchant, infers a billing cycle from the median interval between
/// charges, gates on amount stability, and scores confidence. Pure & synchronous
/// so it unit-tests without SwiftData (like `RenewalProjector`).
struct RecurringChargeDetector {
    var minConfidence: Double = 0.5
    var calendar: Calendar = .current

    func detect(_ transactions: [BankTransaction],
                referenceDate: Date = Date(),
                catalogue: [CatalogueProvider]? = nil) -> [DetectedSubscription] {
        let providers = catalogue ?? CatalogueLoader.load()

        var groups: [String: [BankTransaction]] = [:]
        for transaction in transactions {
            let key = MerchantNormalizer.key(for: transaction.description)
            guard !key.isEmpty else { continue }
            groups[key, default: []].append(transaction)
        }

        return groups
            .compactMap { evaluate(key: $0.key, transactions: $0.value, referenceDate: referenceDate, providers: providers) }
            .sorted { $0.confidence > $1.confidence }
    }

    // MARK: - Per-merchant evaluation

    private func evaluate(key: String, transactions: [BankTransaction],
                          referenceDate: Date, providers: [CatalogueProvider]) -> DetectedSubscription? {
        let sorted = transactions.sorted { $0.date < $1.date }
        guard let last = sorted.last else { return nil }
        let rawMerchant = last.description
        let matched = CatalogueLoader.match(in: MerchantNormalizer.displayName(for: rawMerchant), providers: providers)
            ?? CatalogueLoader.match(in: rawMerchant, providers: providers)
        let currency = last.currencyCode ?? Locale.current.currency?.identifier ?? "GBP"

        // A single charge is only a subscription if it's a recognised service.
        if sorted.count < 2 {
            guard let matched else { return nil }
            return DetectedSubscription(
                displayName: matched.name, rawMerchant: rawMerchant, normalizedKey: key,
                amount: last.amount, currencyCode: currency, cycle: matched.defaultCycle,
                lastSeen: last.date, occurrenceCount: 1, confidence: 0.5, matchedProviderID: matched.id)
        }

        // Cadence from the median gap between consecutive charges.
        let intervals = zip(sorted, sorted.dropFirst())
            .map { calendar.dateComponents([.day], from: $0.date, to: $1.date).day ?? 0 }
            .filter { $0 > 0 }
            .map(Double.init)
        guard !intervals.isEmpty, let cycle = bucket(median(intervals)) else { return nil }

        let amounts = sorted.map(\.amount)
        let stability = amountStability(amounts)
        let regularity = regularity(of: intervals)
        let confidence = score(count: sorted.count, regularity: regularity,
                               stability: stability, catalogueMatch: matched != nil)
        guard confidence >= minConfidence else { return nil }

        return DetectedSubscription(
            displayName: matched?.name ?? MerchantNormalizer.displayName(for: rawMerchant),
            rawMerchant: rawMerchant, normalizedKey: key, amount: last.amount, currencyCode: currency,
            cycle: cycle, lastSeen: last.date, occurrenceCount: sorted.count,
            confidence: confidence, matchedProviderID: matched?.id)
    }

    // MARK: - Math

    /// Maps a median day-gap to a billing cycle. v1 covers the common cadences;
    /// stable-but-off-bucket intervals are rejected to avoid false positives.
    private func bucket(_ medianDays: Double) -> BillingCycle? {
        switch medianDays {
        case 5...10: return .weekly
        case 25...35: return .monthly
        case 350...380: return .yearly
        default: return nil
        }
    }

    private func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let n = sorted.count
        return n.isMultiple(of: 2) ? (sorted[n / 2 - 1] + sorted[n / 2]) / 2 : sorted[n / 2]
    }

    /// 1.0 = identical amounts; falls toward 0 as the coefficient of variation grows.
    private func amountStability(_ amounts: [Decimal]) -> Double {
        let values = amounts.map { NSDecimalNumber(decimal: $0).doubleValue }.filter { $0 > 0 }
        guard values.count >= 2 else { return 1 }
        let mean = values.reduce(0, +) / Double(values.count)
        guard mean > 0 else { return 0 }
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count)
        return max(0, 1 - sqrt(variance) / mean)
    }

    /// 1.0 = perfectly even spacing between charges.
    private func regularity(of intervals: [Double]) -> Double {
        guard intervals.count >= 1 else { return 0 }
        let mean = intervals.reduce(0, +) / Double(intervals.count)
        guard mean > 0 else { return 0 }
        if intervals.count == 1 { return 1 }
        let variance = intervals.reduce(0) { $0 + pow($1 - mean, 2) } / Double(intervals.count)
        return max(0, 1 - sqrt(variance) / mean)
    }

    private func score(count: Int, regularity: Double, stability: Double, catalogueMatch: Bool) -> Double {
        let countScore = min(1.0, Double(count - 1) / 3.0) // 2→0.33, 4+→1.0
        var total = 0.35 * regularity + 0.30 * stability + 0.20 * countScore
        if catalogueMatch { total += 0.15 }
        return min(1.0, total)
    }
}
