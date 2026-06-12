//
//  ReviewPrompter.swift
//  Rubradar
//

import Foundation

/// When to ask for an App Store rating. Pure logic so the gates are testable;
/// the stored state lives in `ReviewPrompter`.
///
/// We only ever ask right after a win — the user just added a subscription —
/// and only once they're invested (3+ active, 3+ days in). Apple hard-caps the
/// system sheet at 3 shows per year; the 120-day spacing keeps us well under it
/// so a prompt is always available for the moments we choose.
struct ReviewPromptRule {
    var minActiveSubscriptions = 3
    var minDaysInstalled = 3
    var minDaysBetweenPrompts = 120

    func shouldPrompt(
        now: Date,
        firstLaunch: Date,
        lastPrompt: Date?,
        activeCount: Int,
        calendar: Calendar = .current
    ) -> Bool {
        guard activeCount >= minActiveSubscriptions else { return false }

        let installedDays = calendar.dateComponents([.day], from: firstLaunch, to: now).day ?? 0
        guard installedDays >= minDaysInstalled else { return false }

        if let lastPrompt {
            let gap = calendar.dateComponents([.day], from: lastPrompt, to: now).day ?? 0
            guard gap >= minDaysBetweenPrompts else { return false }
        }
        return true
    }
}

/// Stored state + the single entry point the UI calls after an add completes.
@MainActor
enum ReviewPrompter {
    private static let firstLaunchKey = "review.firstLaunchDate"
    private static let lastPromptKey = "review.lastPromptDate"

    /// Anchors the "days installed" gate. Call once per launch; existing users
    /// start their grace period at the update that introduced prompting.
    static func noteLaunch(defaults: UserDefaults = .standard, now: Date = Date()) {
        if defaults.object(forKey: firstLaunchKey) == nil {
            defaults.set(now, forKey: firstLaunchKey)
        }
    }

    /// Shows the system rating sheet via `request` if every gate passes.
    static func maybePrompt(
        activeCount: Int,
        defaults: UserDefaults = .standard,
        now: Date = Date(),
        request: () -> Void
    ) {
        noteLaunch(defaults: defaults, now: now)
        let rule = ReviewPromptRule()
        guard rule.shouldPrompt(
            now: now,
            firstLaunch: defaults.object(forKey: firstLaunchKey) as? Date ?? now,
            lastPrompt: defaults.object(forKey: lastPromptKey) as? Date,
            activeCount: activeCount
        ) else { return }

        defaults.set(now, forKey: lastPromptKey)
        request()
    }
}
