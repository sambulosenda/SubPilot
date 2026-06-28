//
//  CycleWidgetProfileIntent.swift
//  SubPilotWidget
//
//  Runs in the widget process when the profile capsule is tapped — flips the
//  widget to the next profile's snapshot in place, no app launch. WidgetKit
//  reloads the timeline automatically once perform() returns.
//

import AppIntents
import Foundation

struct CycleWidgetProfileIntent: AppIntent {
    static let title: LocalizedStringResource = "Switch Widget Profile"
    static let description = IntentDescription("Shows the next profile in the Recurra widget.")
    /// Pure widget-state change; never opens the app.
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        guard let set = WidgetSnapshotStore.readSet(), set.slices.count > 1 else {
            return .result()
        }
        let current = set.slice(for: WidgetSnapshotStore.widgetProfileID)?.id ?? ""
        let index = set.slices.firstIndex { $0.id == current } ?? 0
        WidgetSnapshotStore.widgetProfileID = set.slices[(index + 1) % set.slices.count].id
        return .result()
    }
}
