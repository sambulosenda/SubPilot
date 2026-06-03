//
//  SpendSummary.swift
//  Rubradar
//

import Foundation

/// Aggregated spend across subscriptions, converted to a preferred currency.
struct SpendSummary {
    let preferredCurrency: String
    let monthlyTotal: Decimal
    let yearlyTotal: Decimal
    /// True if any active subscription couldn't be converted (unknown currency).
    let hasUnconvertible: Bool

    var formattedMonthly: String { monthlyTotal.formatted(.currency(code: preferredCurrency)) }
    var formattedYearly: String { yearlyTotal.formatted(.currency(code: preferredCurrency)) }

    /// Sums active subscriptions' monthly-equivalent spend, converted to `preferred`.
    static func make(
        from subscriptions: [Subscription],
        preferred: String,
        rates: ExchangeRates
    ) -> SpendSummary {
        var monthly: Decimal = 0
        var unconvertible = false
        for sub in subscriptions where !sub.isCancelled {
            if let converted = rates.convert(sub.monthlyEquivalent, from: sub.currencyCode, to: preferred) {
                monthly += converted
            } else {
                unconvertible = true
            }
        }
        return SpendSummary(
            preferredCurrency: preferred,
            monthlyTotal: monthly,
            yearlyTotal: monthly * 12,
            hasUnconvertible: unconvertible
        )
    }
}
