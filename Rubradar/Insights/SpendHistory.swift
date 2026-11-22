//
//  SpendHistory.swift
//  Rubradar
//

import Foundation

/// Total monthly spend as it stood at the end of one calendar month.
struct SpendHistoryPoint: Identifiable, Equatable {
    /// Start of the month.
    let month: Date
    let total: Decimal

    var id: Date { month }
}

/// Monthly spend over the months SubHelm has been tracking, rebuilt from what
/// is already stored: when each subscription was added, when it was cancelled,
/// and its recorded price changes. Nothing is snapshotted, so the history
/// exists from the first launch of this feature rather than starting empty.
///
/// It is the history of what was *tracked*: a subscription counts from the
/// month it was added to the app, not from when the user first paid for it.
/// Past months use today's exchange rates and billing cycle, so the line moves
/// only when a subscription is added, cancelled or repriced.
struct SpendHistory {
    let preferredCurrency: String
    /// Oldest first; the last point is the current month and matches the
    /// Home and Insights monthly total.
    let points: [SpendHistoryPoint]

    /// Two months are needed before there is anything to compare.
    var hasTrend: Bool { points.count >= 2 }

    /// Current month's spend minus the first charted month's.
    var change: Decimal? {
        guard hasTrend, let first = points.first, let last = points.last else { return nil }
        return last.total - first.total
    }

    /// Signed change, e.g. "+£12.00".
    var formattedChange: String {
        (change ?? 0).formatted(.currency(code: preferredCurrency).sign(strategy: .always(showZero: false)))
    }

    /// The charted span, e.g. "Jun – Nov 2026".
    var rangeLabel: String? {
        guard hasTrend, let first = points.first, let last = points.last else { return nil }
        return (first.month..<last.month).formatted(.interval.month(.abbreviated).year())
    }

    func format(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: preferredCurrency))
    }

    static func make(
        from subscriptions: [Subscription],
        preferred: String,
        rates: ExchangeRates,
        maxMonths: Int = 6,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> SpendHistory {
        func startOfMonth(_ date: Date) -> Date {
            calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
        }
        guard let earliest = subscriptions.map(\.createdAt).min() else {
            return SpendHistory(preferredCurrency: preferred, points: [])
        }
        let thisMonth = startOfMonth(now)
        let window = calendar.date(byAdding: .month, value: -(maxMonths - 1), to: thisMonth) ?? thisMonth
        var month = max(startOfMonth(earliest), window)

        var points: [SpendHistoryPoint] = []
        while month <= thisMonth {
            let next = calendar.date(byAdding: .month, value: 1, to: month) ?? now
            // Past months are read at their last moment, the current one now.
            let asOf = month == thisMonth ? now : next.addingTimeInterval(-1)
            var total: Decimal = 0
            for sub in subscriptions where sub.createdAt <= asOf {
                if sub.isCancelled, (sub.cancelledAt ?? sub.updatedAt) <= asOf { continue }
                let monthly = sub.monthlyEquivalent(forAmount: sub.amount(asOf: asOf))
                total += rates.convert(monthly, from: sub.currencyCode, to: preferred) ?? 0
            }
            points.append(SpendHistoryPoint(month: month, total: total))
            month = next
        }
        return SpendHistory(preferredCurrency: preferred, points: points)
    }
}

extension Subscription {
    /// The price in force at `date`: today's amount with every later recorded
    /// change undone, newest first. Changes in another currency are skipped,
    /// as they are when recording.
    func amount(asOf date: Date) -> Decimal {
        var amount = self.amount
        for change in priceHistory where change.changedAt > date && change.currencyCode == currencyCode {
            amount = change.oldAmount
        }
        return amount
    }

    /// `monthlyEquivalent` for an arbitrary amount on this billing cycle.
    func monthlyEquivalent(forAmount amount: Decimal) -> Decimal {
        let months = billingCycle.monthsPerCycle(customDays: customCycleDays)
        return months > 0 ? amount / months : amount
    }
}
