//
//  HomeFlowUITests.swift
//  RubradarUITests
//

import XCTest

/// End-to-end checks of Home's decision loop: flagged → decide → cancel or
/// keep → the result shows on Home. Runs on the in-memory demo store
/// (`-DemoSeed`) with `-DemoAttention`, which seeds a trial about to convert,
/// a cancel deadline, an unused streak and a price rise.
final class HomeFlowUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchOnHome() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-DemoSeed", "-UITestLocalStore", "-DemoAttention"]
        app.launch()

        // `-DemoSeed` asks for notification permission on a fresh install.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deny = springboard.buttons["Don’t Allow"]
        if deny.waitForExistence(timeout: 5) { deny.tap() }

        let skip = app.buttons["Skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 15), "Onboarding 'Skip' did not appear")
        skip.tap()
        XCTAssertTrue(element(in: app, containing: "Next 30 days").waitForExistence(timeout: 10),
                      "Home did not appear after onboarding")
        return app
    }

    /// Rows are combined accessibility elements, so match on a label fragment.
    @MainActor
    private func element(in app: XCUIApplication, containing text: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", text))
            .firstMatch
    }

    /// Cancelling through the guided flow shows the saved amount, and the
    /// running total on Home is there when the user returns.
    @MainActor
    func testGuidedCancelShowsSavingAndHomeTotal() throws {
        let app = launchOnHome()

        let trial = app.buttons["ChatGPT Plus free trial"]
        XCTAssertTrue(trial.waitForExistence(timeout: 5), "Trial row missing from Needs attention")
        trial.tap()

        let cancel = app.buttons["Cancel subscription…"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "Detail screen did not offer the cancel flow")
        cancel.tap()

        // The closing action sits below the fold of the half-height sheet, and
        // the list only builds rows as they scroll in.
        XCTAssertTrue(app.buttons["Manage Apple subscriptions"].waitForExistence(timeout: 5)
                      || app.staticTexts["How it works"].waitForExistence(timeout: 5),
                      "Cancel helper did not present")
        let done = app.buttons["Done — mark as cancelled"]
        for _ in 0..<3 where !done.exists { app.swipeUp() }
        XCTAssertTrue(done.waitForExistence(timeout: 3), "Cancel helper has no closing action")
        done.tap()

        XCTAssertTrue(element(in: app, containing: "Saved ").waitForExistence(timeout: 5),
                      "The saved-amount confirmation did not appear after cancelling")
        XCTAssertTrue(app.buttons["Mark as active"].waitForExistence(timeout: 5),
                      "Subscription was not marked cancelled")

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(element(in: app, containing: "You've cut").waitForExistence(timeout: 5),
                      "Home is missing the savings total")
        XCTAssertFalse(app.buttons["ChatGPT Plus free trial"].exists,
                       "A cancelled trial should leave Needs attention")
    }

    /// "Keep" on a cancel deadline removes it from Needs attention.
    @MainActor
    func testKeepDismissesACancelDeadline() throws {
        let app = launchOnHome()

        let deadline = element(in: app, containing: "Last day to cancel")
        XCTAssertTrue(deadline.waitForExistence(timeout: 5), "Deadline row missing from Needs attention")
        deadline.swipeLeft()

        let keep = app.buttons["Keep"]
        XCTAssertTrue(keep.waitForExistence(timeout: 3), "Swipe did not reveal Keep")
        keep.tap()

        XCTAssertFalse(element(in: app, containing: "Last day to cancel").waitForExistence(timeout: 2),
                       "Deadline should be dismissed after Keep")
    }

    /// The monthly check-in opens from Home, and finishing it retires the
    /// prompt for the month.
    @MainActor
    func testMonthlyCheckInCompletesAndRetiresItsPrompt() throws {
        let app = launchOnHome()

        let prompt = element(in: app, containing: "Monthly check-in")
        XCTAssertTrue(prompt.waitForExistence(timeout: 5), "Check-in prompt missing from Home")
        prompt.tap()

        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5), "Check-in sheet did not present")
        XCTAssertGreaterThan(app.switches.count, 0, "Check-in listed no subscriptions")

        // Switch one off by its trailing edge (the switch itself, not the label).
        app.switches.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        done.tap()

        XCTAssertFalse(element(in: app, containing: "Which did you use").waitForExistence(timeout: 2),
                       "Check-in prompt should be gone once the check-in is done")
    }
}
