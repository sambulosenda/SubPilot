//
//  SubPilotIntents.swift
//  Rubradar
//
//  App Intents exposed to Siri, Shortcuts and Spotlight. The data intents read
//  the same App Group snapshot the widget renders (see `WidgetSnapshotStore`),
//  so they answer instantly without touching SwiftData and stay correct even
//  when the app isn't running.
//

import AppIntents
import Foundation

// MARK: - Next renewal

struct NextRenewalIntent: AppIntent {
    static let title: LocalizedStringResource = "Next Renewal"
    static let description = IntentDescription(
        "Tells you which subscription charges next, when, and how much.",
        categoryName: "Subscriptions"
    )

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        guard let snapshot = WidgetSnapshotStore.read() else {
            return .result(
                value: "",
                dialog: "Open SubPilot to set up your subscriptions first."
            )
        }

        let today = Calendar.current.startOfDay(for: Date())
        guard let event = snapshot.upcoming.first(where: { $0.date >= today }) else {
            return .result(
                value: "",
                dialog: "No upcoming renewals — you're all clear."
            )
        }

        let when = event.date.relativeDayPhrase()
        let dialog: IntentDialog = event.isTrialEnd
            ? "\(event.name)'s free trial ends \(when) — \(event.formattedAmount) after that."
            : "\(event.name) renews \(when) — \(event.formattedAmount)."
        return .result(value: "\(event.name) — \(event.formattedAmount) \(when)", dialog: dialog)
    }
}

// MARK: - Monthly spend

struct MonthlySpendIntent: AppIntent {
    static let title: LocalizedStringResource = "Monthly Subscription Spend"
    static let description = IntentDescription(
        "Tells you your total monthly subscription spend.",
        categoryName: "Subscriptions"
    )

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        guard let snapshot = WidgetSnapshotStore.read(), snapshot.activeCount > 0 else {
            return .result(
                value: "",
                dialog: "No subscriptions tracked yet — open SubPilot to add your first one."
            )
        }

        let total = snapshot.formattedMonthlyTotal
        let count = snapshot.activeCount
        return .result(
            value: total,
            dialog: "You're spending \(total) a month across \(count) subscription\(count == 1 ? "" : "s")."
        )
    }
}

// MARK: - Add subscription (opens the app)

struct AddSubscriptionIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Subscription"
    static let description = IntentDescription(
        "Opens SubPilot ready to add a new subscription.",
        categoryName: "Subscriptions"
    )
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppRouter.shared.pendingAction = .addSubscription
        return .result()
    }
}

// MARK: - Open renewals calendar (opens the app)

struct OpenRenewalsIntent: AppIntent {
    static let title: LocalizedStringResource = "View Renewal Calendar"
    static let description = IntentDescription(
        "Opens the SubPilot renewals calendar.",
        categoryName: "Subscriptions"
    )
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppRouter.shared.pendingAction = .showRenewals
        return .result()
    }
}

// MARK: - Date phrasing

private extension Date {
    /// Compact spoken phrase: "today", "tomorrow", "in 5 days", or "on 12 Jul".
    func relativeDayPhrase(now: Date = Date(), calendar: Calendar = .current) -> String {
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: self)
        ).day ?? 0
        switch days {
        case 0: return "today"
        case 1: return "tomorrow"
        case 2...13: return "in \(days) days"
        default: return "on \(formatted(date: .abbreviated, time: .omitted))"
        }
    }
}
