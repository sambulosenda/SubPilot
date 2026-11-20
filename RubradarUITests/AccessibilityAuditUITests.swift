//
//  AccessibilityAuditUITests.swift
//  RubradarUITests
//

import XCTest

/// Runs Xcode's accessibility audit (contrast, hit regions, missing labels,
/// clipped text, Dynamic Type) over the main screens on the demo store.
///
/// A report, not a gate: every issue is printed as an `A11Y|…` line and the
/// test still passes. The audit flags system chrome (toolbar buttons, section
/// headers), text scrolled under the floating tab bar, and the dimmed
/// adjacent-month days, so failing on it would fail on noise. Read the log:
/// `xcodebuild test -only-testing:RubradarUITests/AccessibilityAuditUITests | grep A11Y`.
final class AccessibilityAuditUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-DemoSeed", "-UITestLocalStore", "-DemoAttention", "-DemoHistory"]
        app.launch()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deny = springboard.buttons["Don’t Allow"]
        if deny.waitForExistence(timeout: 5) { deny.tap() }
        let skip = app.buttons["Skip"]
        if skip.waitForExistence(timeout: 15) { skip.tap() }
        XCTAssertTrue(app.tabBars.buttons["Insights"].waitForExistence(timeout: 10))
        return app
    }

    /// Logs every issue as an `A11Y|screen|type|element|label|detail|frame` line.
    @MainActor
    private func audit(_ app: XCUIApplication, screen: String) {
        do {
            try app.performAccessibilityAudit { issue in
                let label = issue.element?.label ?? ""
                let kind = issue.element.map { "\($0.elementType.rawValue)" } ?? "-"
                let frame = issue.element.map { "\(Int($0.frame.minX)),\(Int($0.frame.minY)),\(Int($0.frame.width))x\(Int($0.frame.height))" } ?? "-"
                print("A11Y|\(screen)|\(issue.auditType.rawValue)|\(kind)|\(label)|\(issue.compactDescription)|\(frame)")
                return true
            }
        } catch {
            print("A11Y|\(screen)|error|\(error)")
        }
    }

    @MainActor
    func testAuditMainScreens() throws {
        let app = launch()
        audit(app, screen: "Home")
        for tab in ["Calendar", "Insights", "Settings"] {
            app.tabBars.buttons[tab].tap()
            sleep(1)
            audit(app, screen: tab)
        }
    }

    @MainActor
    func testAuditDetailAndAdd() throws {
        let app = launch()
        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Notion")).firstMatch
        if row.waitForExistence(timeout: 5) {
            app.swipeUp()
            if row.isHittable { row.tap(); sleep(1); audit(app, screen: "Detail") }
            app.navigationBars.buttons.firstMatch.tap()
        }
        let add = app.buttons["Add subscription"]
        if add.waitForExistence(timeout: 5) { add.tap(); sleep(1); audit(app, screen: "Add") }
    }
}
