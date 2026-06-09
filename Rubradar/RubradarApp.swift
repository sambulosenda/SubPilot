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
        if ProcessInfo.processInfo.arguments.contains("-DemoSeed") {
            return .demoSeeded
        }
        #endif
        return .app
    }
}
