//
//  ModelContainer+App.swift
//  Rubradar
//

import Foundation
import SwiftData

extension ModelContainer {
    /// The CloudKit container identifier. Must match the entitlement and the
    /// container registered for the app's team in the developer portal.
    static let cloudKitContainerID = "iCloud.com.sambulosenda.subradar"

    /// The on-disk container used by the running app.
    ///
    /// The primary store mirrors to the user's private CloudKit database for
    /// automatic multi-device sync + backup. SwiftData degrades to local-only
    /// behaviour at runtime when the user isn't signed into iCloud. If the
    /// CloudKit store can't load at all (e.g. the iCloud capability hasn't been
    /// provisioned yet on this build), we fall back to the same on-disk store
    /// without mirroring so the app always launches instead of crashing.
    static let app: ModelContainer = {
        let schema = Schema([Subscription.self, Profile.self])
        let cloudConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private(cloudKitContainerID)
        )
        if let container = try? ModelContainer(for: schema, configurations: cloudConfig) {
            return container
        }

        let localConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: localConfig)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    #if DEBUG
    /// In-memory container seeded with `SampleData`, selected at launch via the
    /// `-DemoSeed` argument. Used to capture deterministic App Store screenshots
    /// without touching the user's real CloudKit/on-disk store. Never ships in
    /// Release (the whole block is compiled out).
    static let demoSeeded: ModelContainer = {
        let container = try! ModelContainer(
            for: Subscription.self, Profile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        // First access happens from the main-actor App body, so this is safe.
        MainActor.assumeIsolated {
            SampleData.seed(into: container.mainContext)
        }
        return container
    }()
    #endif

    /// An in-memory container seeded with sample data, for SwiftUI previews.
    /// CloudKit mirroring is disabled so previews/tests never touch the network.
    @MainActor
    static let preview: ModelContainer = {
        do {
            let container = try ModelContainer(
                for: Subscription.self, Profile.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            )
            SampleData.seed(into: container.mainContext)
            return container
        } catch {
            fatalError("Failed to create preview ModelContainer: \(error)")
        }
    }()
}
