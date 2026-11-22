//
//  RubradarUITestsLaunchTests.swift
//  RubradarUITests
//
//  Created by Sambulo Senda on 03/06/2026.
//

import XCTest

final class RubradarUITestsLaunchTests: XCTestCase {

    /// One launch, not one per UI configuration: with eight languages,
    /// both appearances and every orientation that was 129 launches, long
    /// enough that the test was always skipped.
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        false
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-DemoSeed", "-UITestLocalStore"]
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
