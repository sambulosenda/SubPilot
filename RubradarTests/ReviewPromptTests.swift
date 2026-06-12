//
//  ReviewPromptTests.swift
//  RubradarTests
//

import Foundation
import Testing
@testable import Rubradar

struct ReviewPromptTests {
    private let rule = ReviewPromptRule()
    private let now = Date(timeIntervalSince1970: 1_780_000_000)

    private func days(_ n: Int) -> TimeInterval { TimeInterval(n) * 86_400 }

    @Test func promptsWhenAllGatesPass() {
        #expect(rule.shouldPrompt(
            now: now, firstLaunch: now - days(7), lastPrompt: nil, activeCount: 3
        ))
    }

    @Test func tooFewSubscriptionsBlocks() {
        #expect(!rule.shouldPrompt(
            now: now, firstLaunch: now - days(7), lastPrompt: nil, activeCount: 2
        ))
    }

    @Test func freshInstallBlocks() {
        #expect(!rule.shouldPrompt(
            now: now, firstLaunch: now - days(1), lastPrompt: nil, activeCount: 5
        ))
    }

    @Test func recentPromptBlocks() {
        #expect(!rule.shouldPrompt(
            now: now, firstLaunch: now - days(200), lastPrompt: now - days(30), activeCount: 5
        ))
    }

    @Test func oldPromptAllowsAgain() {
        #expect(rule.shouldPrompt(
            now: now, firstLaunch: now - days(400), lastPrompt: now - days(150), activeCount: 5
        ))
    }

    @MainActor
    @Test func maybePromptRecordsAndFiresOnce() {
        let defaults = UserDefaults(suiteName: "review-prompt-tests")!
        defaults.removePersistentDomain(forName: "review-prompt-tests")

        // Backdate the install so only the prompt-spacing gate is in play.
        ReviewPrompter.noteLaunch(defaults: defaults, now: now - days(10))

        var fired = 0
        ReviewPrompter.maybePrompt(activeCount: 4, defaults: defaults, now: now) { fired += 1 }
        #expect(fired == 1)

        // Immediately again: blocked by the just-recorded prompt date.
        ReviewPrompter.maybePrompt(activeCount: 4, defaults: defaults, now: now) { fired += 1 }
        #expect(fired == 1)
    }
}
