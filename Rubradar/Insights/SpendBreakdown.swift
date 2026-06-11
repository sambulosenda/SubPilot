//
//  SpendBreakdown.swift
//  Rubradar
//

import Foundation

/// One category's share of monthly spend, in the preferred currency.
struct CategorySpend: Identifiable {
    let category: SubscriptionCategory
    /// Monthly-equivalent spend for this category, converted to the preferred currency.
    let monthlyAmount: Decimal
    /// Share of the whole monthly spend (0...1).
    let fraction: Double

    var id: SubscriptionCategory { category }
}

/// Monthly spend grouped by category, converted to a preferred currency and
/// ranked highest-first. Pure aggregation over active subscriptions: it derives
/// entirely from existing data (each subscription's `monthlyEquivalent`), so it
/// needs no extra persistence and stays unit-testable.
struct SpendBreakdown {
    let preferredCurrency: String
    let monthlyTotal: Decimal
    /// Categories with spend, ranked by amount descending.
    let categories: [CategorySpend]
    /// True if any active subscription used a currency without a known rate.
    let hasUnconvertible: Bool

    var isEmpty: Bool { categories.isEmpty }
    var formattedTotal: String { format(monthlyTotal) }

    /// Localised currency string in the preferred currency (e.g. "£42.97").
    func format(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: preferredCurrency))
    }

    /// Sums each active subscription's monthly-equivalent spend by category,
    /// converting to `preferred`. Mirrors `SpendSummary.make` so the category
    /// subtotals always reconcile to the Home hero's monthly total.
    static func make(
        from subscriptions: [Subscription],
        preferred: String,
        rates: ExchangeRates
    ) -> SpendBreakdown {
        var totals: [SubscriptionCategory: Decimal] = [:]
        var unconvertible = false
        for sub in subscriptions where !sub.isCancelled {
            if let converted = rates.convert(sub.monthlyEquivalent, from: sub.currencyCode, to: preferred) {
                totals[sub.category, default: 0] += converted
            } else {
                unconvertible = true
            }
        }

        let total: Decimal = totals.values.reduce(0, +)
        let totalDouble = NSDecimalNumber(decimal: total).doubleValue

        var slices: [CategorySpend] = []
        for (category, amount) in totals {
            let amountDouble = NSDecimalNumber(decimal: amount).doubleValue
            let fraction = totalDouble > 0 ? amountDouble / totalDouble : 0
            slices.append(CategorySpend(category: category, monthlyAmount: amount, fraction: fraction))
        }

        // Amount descending; category label keeps ties deterministic (stable
        // legend + colour order across body passes).
        let categories = slices.sorted { lhs, rhs in
            if lhs.monthlyAmount == rhs.monthlyAmount {
                return lhs.category.label < rhs.category.label
            }
            return lhs.monthlyAmount > rhs.monthlyAmount
        }

        return SpendBreakdown(
            preferredCurrency: preferred,
            monthlyTotal: total,
            categories: categories,
            hasUnconvertible: unconvertible
        )
    }
}
