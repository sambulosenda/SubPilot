//
//  AssistantContext.swift
//  Rubradar
//

import Foundation

/// Builds the compact, on-device data snapshot fed to the assistant as grounding.
///
/// The snapshot is plain text injected into the model's `instructions` so answers
/// stay anchored to the user's real subscriptions. Authoritative totals come from
/// `HomeMetrics`/`SpendSummary`; the model is told not to recompute them. Nothing
/// here leaves the device — it's assembled and consumed locally.
enum AssistantContext {
    /// Cap on listed subscriptions so a large library can't blow the model's
    /// context window. The biggest spenders are kept; the rest are summarised.
    private static let maxListed = 60

    static func make(
        subscriptions: [Subscription],
        metrics: HomeMetrics,
        profileName: String,
        preferred: String,
        rates: ExchangeRates,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        let active = subscriptions.filter { !$0.isCancelled }
        let cancelledCount = subscriptions.count - active.count

        var lines: [String] = []
        lines.append("Today's date: \(isoDay(now, calendar: calendar)).")
        lines.append("Preferred currency: \(preferred). Unless a line notes otherwise, amounts are in \(preferred).")
        lines.append("Profile in view: \(profileName).")
        lines.append("")
        lines.append("TOTALS (authoritative — use these verbatim):")
        lines.append("- Active subscriptions: \(metrics.activeCount)")
        lines.append("- Total monthly spend: \(metrics.summary.formattedMonthly)")
        lines.append("- Total yearly spend: \(metrics.summary.formattedYearly)")
        if let next = metrics.nextEvent {
            let label = next.isTrialEnd ? "trial ends" : "next charge"
            lines.append("- Soonest \(label): \(next.subscription.name) on \(isoDay(next.date, calendar: calendar)) (\(relative(to: next.date, now: now, calendar: calendar)))")
        }
        if metrics.summary.hasUnconvertible {
            lines.append("- Note: some subscriptions use a currency with no known exchange rate and are excluded from totals.")
        }

        // Per-category monthly spend (converted), largest first.
        let categoryTotals = categoryMonthly(active, preferred: preferred, rates: rates)
        if !categoryTotals.isEmpty {
            lines.append("")
            lines.append("MONTHLY SPEND BY CATEGORY:")
            for (category, total) in categoryTotals {
                lines.append("- \(category.label): \(total.formatted(.currency(code: preferred)))/mo")
            }
        }

        // Individual subscriptions, biggest monthly-equivalent first.
        lines.append("")
        if active.isEmpty {
            lines.append("SUBSCRIPTIONS: none active\(cancelledCount > 0 ? " (\(cancelledCount) cancelled)" : "").")
        } else {
            let sorted = active.sorted {
                monthlyPreferred($0, preferred: preferred, rates: rates)
                    > monthlyPreferred($1, preferred: preferred, rates: rates)
            }
            let listed = Array(sorted.prefix(maxListed))
            lines.append("SUBSCRIPTIONS (active, largest monthly cost first):")
            for sub in listed {
                lines.append(line(for: sub, preferred: preferred, rates: rates, now: now, calendar: calendar))
            }
            if sorted.count > listed.count {
                lines.append("- …and \(sorted.count - listed.count) more not listed.")
            }
            if cancelledCount > 0 {
                lines.append("(\(cancelledCount) cancelled subscription\(cancelledCount == 1 ? "" : "s") not listed; they don't count toward totals.)")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Lines

    private static func line(
        for sub: Subscription,
        preferred: String,
        rates: ExchangeRates,
        now: Date,
        calendar: Calendar
    ) -> String {
        let monthly = monthlyEquivString(sub, preferred: preferred, rates: rates)
        let billed = "billed \(sub.formattedAmount)/\(sub.billingCycle.shortLabel)"
        let date = nextOccurrence(for: sub, now: now, calendar: calendar)
        let when = "next \(isoDay(date, calendar: calendar)) (\(relative(to: date, now: now, calendar: calendar)))"
        let trial = sub.isFreeTrial ? "; free trial" : ""
        return "- \(sub.name): ~\(monthly)/mo (\(sub.category.label)); \(billed); \(when)\(trial)"
    }

    /// Monthly-equivalent cost expressed in the preferred currency when
    /// convertible, otherwise in the subscription's own currency with a note.
    private static func monthlyEquivString(_ sub: Subscription, preferred: String, rates: ExchangeRates) -> String {
        if let converted = rates.convert(sub.monthlyEquivalent, from: sub.currencyCode, to: preferred) {
            return converted.formatted(.currency(code: preferred))
        }
        return sub.monthlyEquivalent.formatted(.currency(code: sub.currencyCode)) + " (own currency)"
    }

    private static func monthlyPreferred(_ sub: Subscription, preferred: String, rates: ExchangeRates) -> Decimal {
        rates.convert(sub.monthlyEquivalent, from: sub.currencyCode, to: preferred) ?? sub.monthlyEquivalent
    }

    private static func categoryMonthly(
        _ active: [Subscription],
        preferred: String,
        rates: ExchangeRates
    ) -> [(SubscriptionCategory, Decimal)] {
        var totals: [SubscriptionCategory: Decimal] = [:]
        for sub in active {
            if let converted = rates.convert(sub.monthlyEquivalent, from: sub.currencyCode, to: preferred) {
                totals[sub.category, default: 0] += converted
            }
        }
        return totals.sorted { $0.value > $1.value }
    }

    // MARK: - Dates

    /// Next future renewal (or trial-end) for a subscription, mirroring
    /// `RenewalProjector`: a trial anchors the first occurrence and stale dates
    /// roll forward by the billing cycle.
    private static func nextOccurrence(for sub: Subscription, now: Date, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: now)
        var date = (sub.isFreeTrial && sub.trialEndDate != nil) ? sub.trialEndDate! : sub.nextRenewalDate
        var steps = 0
        while date < start && steps < 600 {
            date = sub.billingCycle.nextDate(after: date, customDays: sub.customCycleDays, calendar: calendar)
            steps += 1
        }
        return date
    }

    private static func isoDay(_ date: Date, calendar: Calendar) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year())
    }

    private static func relative(to date: Date, now: Date, calendar: Calendar) -> String {
        let days = calendar.dateComponents([.day],
                                           from: calendar.startOfDay(for: now),
                                           to: calendar.startOfDay(for: date)).day ?? 0
        switch days {
        case ..<0: return "overdue"
        case 0: return "today"
        case 1: return "tomorrow"
        default: return "in \(days) days"
        }
    }
}
