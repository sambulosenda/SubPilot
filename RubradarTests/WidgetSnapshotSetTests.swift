//
//  WidgetSnapshotSetTests.swift
//  RubradarTests
//

import Foundation
import Testing
@testable import Rubradar

struct WidgetSnapshotSetTests {
    private func makeSet(appSelectedID: String = "") -> WidgetSnapshotSet {
        WidgetSnapshotSet(
            slices: [
                .init(id: "", name: nil, snapshot: .empty),
                .init(id: "personal", name: "Personal", snapshot: .empty),
                .init(id: "business", name: "Business", snapshot: .empty)
            ],
            appSelectedID: appSelectedID
        )
    }

    @Test func sliceForExplicitIDWins() {
        #expect(makeSet().slice(for: "business")?.name == "Business")
    }

    @Test func sliceFallsBackToAppSelection() {
        let set = makeSet(appSelectedID: "personal")
        #expect(set.slice(for: nil)?.name == "Personal")
        // Stale widget override (deleted profile) also lands on the app's pick.
        #expect(set.slice(for: "deleted-profile")?.name == "Personal")
    }

    @Test func sliceFallsBackToFirstWhenSelectionUnknown() {
        let set = makeSet(appSelectedID: "gone")
        #expect(set.slice(for: nil)?.id == "")
    }

    /// A widget updated before the app first runs must still decode the old
    /// single-snapshot file format.
    @Test func legacySnapshotDecodesAsLoneSlice() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(WidgetSnapshot.placeholder)
        #expect((try? decoder.decode(WidgetSnapshotSet.self, from: data)) == nil)
        let legacy = try decoder.decode(WidgetSnapshot.self, from: data)
        #expect(legacy.upcoming.count == WidgetSnapshot.placeholder.upcoming.count)
    }
}
