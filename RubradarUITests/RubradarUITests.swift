//
//  RubradarUITests.swift
//  RubradarUITests
//
//  Created by Sambulo Senda on 03/06/2026.
//

import XCTest

final class RubradarUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    /// First-run onboarding must hand off into the soft Pro upsell: finishing
    /// (or skipping) onboarding presents the `.onboarding` paywall, which stays
    /// skippable via "Maybe later". Runs against the CloudKit-free test store so
    /// it launches on simulators without an iCloud account; launch-argument
    /// overrides force a first-run, non-Pro state regardless of prior runs.
    @MainActor
    func testOnboardingPresentsSoftPaywall() throws {
        let app = XCUIApplication()
        // `-UITestLocalStore` selects a CloudKit-free store (no iCloud account on
        // CI sims) AND resets onboarding + Pro state via real writes in the app's
        // init — so this single flag yields a deterministic first-run, non-Pro
        // launch without argument-domain pins that would block the app's writes.
        app.launchArguments = ["-UITestLocalStore"]
        app.launch()

        // Onboarding is up (after splash); skip straight through.
        let skip = app.buttons["Skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 15), "Onboarding 'Skip' did not appear")
        skip.tap()

        // The upsell is deferred to the first engagement signal (tab switch,
        // warm return, or next launch) — see RootView.armOnboardingUpsell. Use a
        // warm return: unlike a tab tap it can't be swallowed by the cover's
        // dismissal animation. Settle first so onDismiss has armed the flag.
        XCTAssertTrue(app.tabBars.buttons["Calendar"].waitForExistence(timeout: 5),
                      "Tab bar did not appear after onboarding")
        Thread.sleep(forTimeInterval: 1.5)
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 1.0)
        app.activate()

        // The soft onboarding paywall should now present.
        let maybeLater = app.buttons["Maybe later"]
        XCTAssertTrue(maybeLater.waitForExistence(timeout: 5),
                      "Soft onboarding paywall did not present after onboarding")

        // Headline is part of a combined accessibility element, so match by substring.
        let headline = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Never pay for a subscription you forget"))
            .firstMatch
        XCTAssertTrue(headline.exists, "Onboarding paywall headline missing")

        // "Maybe later" keeps it soft — tapping it drops into the free app.
        maybeLater.tap()
        XCTAssertFalse(maybeLater.waitForExistence(timeout: 3),
                       "Paywall should dismiss into the free tier on 'Maybe later'")
    }

    /// The onboarding value-moment: on the starter step the user taps popular
    /// subscriptions, sees a live spend total, and the CTA reflects the count;
    /// advancing seeds those subscriptions (proven by reaching the next step
    /// without crashing on persistence). Runs against the CloudKit-free store.
    @MainActor
    func testOnboardingStarterStepShowsSpendAndSeeds() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestLocalStore"]
        app.launch()

        // Onboarding opens straight on the starter step.
        XCTAssertTrue(app.staticTexts["What are you paying for?"].waitForExistence(timeout: 15),
                      "Starter step did not appear")

        // Tap a provider chip; the live total should appear.
        let netflix = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Netflix'")).firstMatch
        XCTAssertTrue(netflix.waitForExistence(timeout: 5), "Netflix starter chip missing")
        netflix.tap()

        let total = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "tracking")).firstMatch
        XCTAssertTrue(total.waitForExistence(timeout: 5), "Live spend total did not appear after selecting")

        // CTA reflects the selection count, then advances (commits the seed).
        let cta = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Add 1'")).firstMatch
        XCTAssertTrue(cta.waitForExistence(timeout: 3), "CTA did not reflect selection count")
        cta.tap()

        // Reaching the reminders step proves the seed persisted without crashing.
        XCTAssertTrue(app.buttons["Enable reminders"].waitForExistence(timeout: 5),
                      "Did not advance past the starter step after seeding")
    }

    /// Guideline 3.1.2(c) regression guard (App Review rejection, Jul 2026): the
    /// billed amount must stay the most conspicuous pricing element — the CTA is
    /// trial-neutral ("Subscribe") with the billed amount right above it.
    /// Attaches a screenshot as review evidence.
    @MainActor
    func testPaywallBilledAmountProminence() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestLocalStore"]
        app.launch()

        let skip = app.buttons["Skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 15), "Onboarding 'Skip' did not appear")
        skip.tap()

        // Deferred upsell fires on the first engagement signal — use a warm
        // return (background → foreground; see note in the test above).
        XCTAssertTrue(app.tabBars.buttons["Calendar"].waitForExistence(timeout: 5),
                      "Tab bar did not appear after onboarding")
        Thread.sleep(forTimeInterval: 1.5)
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 1.0)
        app.activate()

        // CTA must read "Subscribe" (not "Start Free Trial") once products load.
        let subscribe = app.buttons["Subscribe"]
        XCTAssertTrue(subscribe.waitForExistence(timeout: 10), "'Subscribe' CTA missing")

        // The billed amount line ("$19.99 per year") sits directly above the CTA.
        let billed = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS 'per year'")).firstMatch
        XCTAssertTrue(billed.waitForExistence(timeout: 5), "Billed amount line missing")

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "paywall-3-1-2c"
        shot.lifetime = .keepAlways
        add(shot)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
