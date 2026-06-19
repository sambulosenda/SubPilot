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

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
