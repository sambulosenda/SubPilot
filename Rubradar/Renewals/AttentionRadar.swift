//
//  AttentionRadar.swift
//  Rubradar
//

import Foundation

/// A recent price increase on an active subscription — a prompt to decide
/// whether it's still worth it at the new price.
struct PriceRise: Identifiable {
    /// The underlying `PriceChange` id, so keeping this rise doesn't silence
    /// a later one on the same subscription.
    let id: UUID
    let subscription: Subscription
    /// "£10.99 → £12.99"
    let transition: String
    /// 0.18 for +18%.
    let relativeChange: Decimal?
    let changedAt: Date
}

/// A subscription whose last day to cancel is coming up.
struct UpcomingDeadline: Identifiable {
    let subscription: Subscription
    let deadline: CancelDeadline

    var id: UUID { subscription.id }
    /// Close enough that missing it locks in another term.
    var isUrgent: Bool { deadline.daysLeft <= 3 }
}

/// One thing on Home that wants a decision from the user.
enum AttentionItem: Identifiable {
    case trial(EndingTrial)
    case deadline(UpcomingDeadline)
    /// Unused for `months` check-ins in a row.
    case unused(Subscription, months: Int)
    case priceRise(PriceRise)

    var id: String {
        switch self {
        case .trial(let trial): "trial-\(trial.id.uuidString)"
        case .deadline(let item): "deadline-\(item.id.uuidString)"
        case .unused(let sub, _): "unused-\(sub.id.uuidString)"
        // Includes the streak, so keeping it at two months lets it ask again
        // if a third goes by unused.
        case .unused(let sub, let months): "unused-\(sub.id.uuidString)-\(months)"
        case .priceRise(let rise): "rise-\(rise.id.uuidString)"
        }
    }

    var subscription: Subscription {
        switch self {
        case .trial(let trial): trial.subscription
        case .deadline(let item): item.subscription
        case .unused(let sub, _): sub
        case .priceRise(let rise): rise.subscription
        }
    }

    /// What "Keep" stores to stop flagging this item. Scoped to the specific
    /// event — this price rise, this deadline — so the next one still shows.
    /// Trials can't be kept quiet: they convert whether or not you look.
    var dismissToken: String? {
        switch self {
        case .trial: nil
        case .deadline(let item):
            "deadline-\(item.id.uuidString)-\(Int(item.deadline.date.timeIntervalSinceReferenceDate))"
        // Includes the streak, so keeping it at two months lets it ask again
        // if a third goes by unused.
        case .unused(let sub, let months): "unused-\(sub.id.uuidString)-\(months)"
        case .priceRise(let rise): "rise-\(rise.id.uuidString)"
        }
    }

    /// When the decision is due; price rises have no due date.
    fileprivate var dueDate: Date? {
        switch self {
        case .trial(let trial): trial.endDate
        case .deadline(let item): item.deadline.date
        case .unused, .priceRise: nil
        }
    }
}

/// Gathers everything that needs a keep-or-cancel decision: trials about to
/// convert and cancel deadlines coming up, then recent price rises. Pure &
/// synchronous like `TrialRadar`.
enum AttentionRadar {
    /// How long a price rise stays flagged if the user never acts on it.
    static let priceRiseWindowDays = 30
    /// How far ahead a cancel deadline starts asking for a decision.
    static let deadlineWindowDays = 14

    /// Dated items first, soonest first (trials and cancel deadlines), then
    /// subscriptions that keep going unused (costliest first), then price
    /// rises, newest first. `dismissed` holds the `dismissToken`s of
    /// items the user chose to keep.
    static func items(
        in subscriptions: [Subscription],
        dismissed: Set<String> = [],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [AttentionItem] {
        let trials = TrialRadar.endingTrials(in: subscriptions, now: now, calendar: calendar)
            .map(AttentionItem.trial)
        let deadlines = upcomingDeadlines(in: subscriptions, now: now, calendar: calendar)
            .map(AttentionItem.deadline)
        let dated = (trials + deadlines).sorted {
            ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
        }
        let unused = subscriptions
            .filter { !$0.isCancelled && $0.unusedMonths >= UsageCheckIn.flagAfterMonths }
            .sorted { $0.monthlyEquivalent > $1.monthlyEquivalent }
            .map { AttentionItem.unused($0, months: $0.unusedMonths) }
        let rises = priceRises(in: subscriptions, now: now).map(AttentionItem.priceRise)
        return (dated + unused + rises).filter { item in
            item.dismissToken.map { !dismissed.contains($0) } ?? true
        }
    }

    /// Active subscriptions whose last day to cancel falls inside the window.
    /// A trial is left to `TrialRadar` — its end date is the decision point.
    static func upcomingDeadlines(
        in subscriptions: [Subscription],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [UpcomingDeadline] {
        subscriptions.compactMap { sub -> UpcomingDeadline? in
            guard !sub.isFreeTrial,
                  let deadline = sub.cancelDeadline(asOf: now, calendar: calendar),
                  deadline.daysLeft <= deadlineWindowDays else { return nil }
            return UpcomingDeadline(subscription: sub, deadline: deadline)
        }
    }

    /// The latest price change of each active subscription, when it is a rise
    /// recorded inside the window. Only the latest counts: a
    /// rise that was since reversed is no longer a rise.
    static func priceRises(
        in subscriptions: [Subscription],
        now: Date = Date()
    ) -> [PriceRise] {
        let cutoff = now.addingTimeInterval(-Double(priceRiseWindowDays) * 86_400)
        return subscriptions
            .compactMap { sub -> PriceRise? in
                guard !sub.isCancelled,
                      let latest = sub.priceHistory.max(by: { $0.changedAt < $1.changedAt }),
                      latest.newAmount > latest.oldAmount,
                      latest.changedAt >= cutoff, latest.changedAt <= now else { return nil }
                return PriceRise(id: latest.id, subscription: sub,
                                 transition: latest.transitionLabel,
                                 relativeChange: latest.relativeChange,
                                 changedAt: latest.changedAt)
            }
            .sorted { $0.changedAt > $1.changedAt }
    }
}

/// What the user has stopped paying for: the yearly cost of their cancelled
/// subscriptions. Derived from the same records as the spend totals, so there
/// is nothing extra to store or sync.
struct CutSummary {
    let preferredCurrency: String
    let yearlyTotal: Decimal
    let count: Int

    var formattedYearly: String { yearlyTotal.formatted(.currency(code: preferredCurrency)) }

    static func make(
        from subscriptions: [Subscription],
        preferred: String,
        rates: ExchangeRates
    ) -> CutSummary {
        var yearly: Decimal = 0
        var count = 0
        for sub in subscriptions where sub.isCancelled {
            count += 1
            // Unconvertible currencies are left out, as in `SpendSummary`.
            yearly += (rates.convert(sub.monthlyEquivalent, from: sub.currencyCode, to: preferred) ?? 0) * 12
        }
        return CutSummary(preferredCurrency: preferred, yearlyTotal: yearly, count: count)
    }
}
