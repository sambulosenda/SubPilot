//
//  CloudKitSchemaInitializer.swift
//  Rubradar
//

#if DEBUG
import CoreData
import SwiftData

/// One-shot developer tool: force-uploads the full model schema to the
/// CloudKit **Development** environment, so new record types (e.g.
/// `CD_PriceChange`) appear in the console for "Deploy Schema Changes"
/// without waiting on organic mirroring exports.
///
/// Run the app once with the `-InitCKSchema` launch argument (Debug builds
/// only; a device or iCloud-capable environment with network). Watch the
/// console for the ✅/❌ line, then check Schema → Record Types in the
/// CloudKit console. Never ships: DEBUG-compiled and argument-gated.
enum CloudKitSchemaInitializer {
    static func runIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-InitCKSchema") else { return }
        do {
            guard let model = NSManagedObjectModel.makeManagedObjectModel(
                for: [Subscription.self, Profile.self, PriceChange.self]
            ) else {
                print("❌ CK schema init: couldn't build NSManagedObjectModel from SwiftData models")
                return
            }
            // A throwaway store — schema init only needs the model + container.
            let url = URL.temporaryDirectory.appending(path: "ck-schema-init.sqlite")
            let description = NSPersistentStoreDescription(url: url)
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: ModelContainer.cloudKitContainerID
            )
            let container = NSPersistentCloudKitContainer(name: "SchemaInit", managedObjectModel: model)
            container.persistentStoreDescriptions = [description]
            var loadError: Error?
            container.loadPersistentStores { _, error in loadError = error }
            if let loadError { throw loadError }
            try container.initializeCloudKitSchema(options: [])
            print("✅ CK schema init: full schema pushed to the Development environment")
        } catch {
            print("❌ CK schema init failed: \(error)")
        }
    }
}
#endif
