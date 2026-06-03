//
//  ModelContainer+App.swift
//  Rubradar
//

import Foundation
import SwiftData

extension ModelContainer {
    /// The on-disk container used by the running app.
    static let app: ModelContainer = {
        let schema = Schema([Subscription.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    /// An in-memory container seeded with sample data, for SwiftUI previews.
    @MainActor
    static let preview: ModelContainer = {
        do {
            let container = try ModelContainer(
                for: Subscription.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            SampleData.seed(into: container.mainContext)
            return container
        } catch {
            fatalError("Failed to create preview ModelContainer: \(error)")
        }
    }()
}
