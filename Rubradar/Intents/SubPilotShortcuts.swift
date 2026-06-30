//
//  SubPilotShortcuts.swift
//  Rubradar
//
//  Surfaces the App Intents in Siri, Spotlight and the Shortcuts gallery with
//  ready-made phrases. Every phrase must contain `\(.applicationName)` —
//  "SubHelm" — for Siri to route it.
//

import AppIntents

struct SubPilotShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NextRenewalIntent(),
            phrases: [
                "What's my next renewal in \(.applicationName)",
                "When is my next \(.applicationName) renewal",
                "Ask \(.applicationName) what renews next"
            ],
            shortTitle: "Next Renewal",
            systemImageName: "calendar.badge.clock"
        )
        AppShortcut(
            intent: MonthlySpendIntent(),
            phrases: [
                "What's my monthly spend in \(.applicationName)",
                "How much am I spending on subscriptions in \(.applicationName)",
                "Ask \(.applicationName) for my subscription spend"
            ],
            shortTitle: "Monthly Spend",
            systemImageName: "sterlingsign.circle"
        )
        AppShortcut(
            intent: AddSubscriptionIntent(),
            phrases: [
                "Add a subscription in \(.applicationName)",
                "Track a subscription in \(.applicationName)"
            ],
            shortTitle: "Add Subscription",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: OpenRenewalsIntent(),
            phrases: [
                "Show my renewals in \(.applicationName)",
                "Open the \(.applicationName) calendar"
            ],
            shortTitle: "Renewal Calendar",
            systemImageName: "calendar"
        )
    }
}
