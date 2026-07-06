//
//  RubradarApp.swift
//  Rubradar
//
//  Created by Sambulo Senda on 03/06/2026.
//

import SwiftUI
import SwiftData

@main
struct RubradarApp: App {
    init() {
        Analytics.start()
        #if DEBUG
        // One-shot CloudKit Development schema push (see the type's docs).
        CloudKitSchemaInitializer.runIfRequested()
        if ProcessInfo.processInfo.arguments.contains("-UITestLocalStore") {
            // Deterministic first-run, non-Pro state for UI tests, via *real*
            // writes — not `-key value` launch args, which land in the argument
            // domain and would pin the value, blocking the app's own writes
            // (e.g. completing onboarding). Keys mirror RootView's @AppStorage
            // and PurchaseManager.isProDefaultsKey.
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
            UserDefaults.standard.set(false, forKey: "isProEntitlement")
            // Also clear the deferred-upsell arm, or a paywall left unconsumed by
            // a previous test run fires at launch and breaks determinism.
            UserDefaults.standard.set(false, forKey: "pendingOnboardingUpsell")
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(CurrencyService.shared)
                .environment(Self.purchases)
        }
        .modelContainer(Self.container)
    }

    /// The entitlement source. Normally the live StoreKit-backed `.shared`;
    /// swapped for a Pro-unlocked demo instance under `-DemoSeed` (DEBUG only).
    static var purchases: PurchaseManager {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-DemoSeed") {
            return .demo
        }
        #endif
        return .shared
    }

    /// The store the app runs against. Normally the CloudKit-backed `.app` store;
    /// swapped for an in-memory `SampleData` seed when launched with `-DemoSeed`
    /// (DEBUG only) so App Store screenshots are deterministic.
    static var container: ModelContainer {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-DemoSeed") {
            return .demoSeeded
        }
        // CloudKit-free store for UI tests on iCloud-less simulators.
        if args.contains("-UITestLocalStore") {
            return .uiTestLocal
        }
        #endif
        return .app
    }
}
