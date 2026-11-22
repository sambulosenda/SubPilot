//
//  TrialLiveActivity.swift
//  Rubradar
//

import ActivityKit
import Foundation

/// Keeps one Live Activity in step with the soonest free trial: scheduled to
/// appear at 9 AM on the day the trial ends (when the day-of reminder fires),
/// or started at once if that time has already passed. Scheduling is local,
/// so no push server is involved.
///
/// Only trials get one. A Live Activity per renewal would be on the Lock
/// Screen several days a month; a trial's last day is the one date where
/// acting the same day saves money.
@MainActor
enum TrialLiveActivity {
    struct Plan: Equatable {
        let subscriptionID: UUID
        /// When the activity should appear.
        let start: Date
        /// End of the trial's last day.
        let end: Date
    }

    /// The soonest trial whose last day hasn't finished, with the window its
    /// activity should cover. Pure, so the choice is unit-testable.
    nonisolated static func plan(
        for trials: [(id: UUID, trialEnd: Date)],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Plan? {
        trials
            .compactMap { trial -> Plan? in
                let day = calendar.startOfDay(for: trial.trialEnd)
                guard let end = calendar.date(byAdding: .day, value: 1, to: day), end > now,
                      let start = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day)
                else { return nil }
                return Plan(subscriptionID: trial.id, start: start, end: end)
            }
            .min { $0.end < $1.end }
    }

    /// Ends activities that no longer match the data and requests the one that
    /// should exist. Call wherever reminders are rescheduled.
    static func sync(subscriptions: [Subscription], enabled: Bool, now: Date = Date()) async {
        let trials = subscriptions
            .filter { !$0.isCancelled && $0.isFreeTrial }
            .compactMap { sub in sub.trialEndDate.map { (id: sub.id, trialEnd: $0) } }
        let wanted = enabled && ActivityAuthorizationInfo().areActivitiesEnabled
            ? plan(for: trials, now: now) : nil
        let subscription = wanted.flatMap { plan in subscriptions.first { $0.id == plan.subscriptionID } }

        var alreadyThere = false
        for activity in Activity<TrialEndingAttributes>.activities {
            let live = activity.activityState == .active || activity.activityState == .pending
            if live, !alreadyThere, let wanted, let subscription,
               activity.attributes.subscriptionID == wanted.subscriptionID.uuidString,
               activity.attributes.endsOn == wanted.end,
               activity.attributes.name == subscription.name,
               activity.content.state.formattedAmount == subscription.formattedAmount {
                alreadyThere = true
            } else {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        guard let wanted, let subscription, !alreadyThere else { return }

        let name = subscription.name
        let amount = subscription.formattedAmount
        let attributes = TrialEndingAttributes(
            subscriptionID: subscription.id.uuidString,
            name: name,
            title: String(localized: "\(name) trial ends today"),
            body: String(localized: "You'll be charged \(amount) today unless you cancel."),
            symbolName: subscription.brandSymbol,
            brandColorHex: subscription.brandColorHex,
            categoryRaw: subscription.categoryRaw,
            endsOn: wanted.end
        )
        let content = ActivityContent(
            state: TrialEndingAttributes.ContentState(formattedAmount: amount),
            staleDate: wanted.end
        )
        // Requests fail when the app isn't in the foreground (e.g. the
        // notification's Cancel action) or the system's activity budget is
        // spent. The reminders still cover the trial, so nothing to recover.
        if wanted.start <= now {
            _ = try? Activity.request(attributes: attributes, content: content, pushType: nil)
        } else {
            _ = try? Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil,
                style: .standard,
                alertConfiguration: AlertConfiguration(
                    title: "\(name) trial ends today",
                    body: "You'll be charged \(amount) today unless you cancel.",
                    sound: .default
                ),
                start: wanted.start
            )
        }
    }
}
