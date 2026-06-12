//
//  AddSubscriptionControl.swift
//  SubPilotWidget
//
//  Control Center / Lock Screen / Action button control that opens the app
//  straight into the add-subscription flow. The intent runs in the widget
//  process, so it hands the request to the app via the App Group flag rather
//  than touching the app's router.
//

import AppIntents
import SwiftUI
import WidgetKit

struct OpenAddSubscriptionIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Subscription"
    static let description = IntentDescription("Opens SubPilot ready to add a new subscription.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        WidgetSnapshotStore.requestAdd()
        return .result()
    }
}

struct AddSubscriptionControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.sambulosenda.subradar.add-control") {
            ControlWidgetButton(action: OpenAddSubscriptionIntent()) {
                Label("Add Subscription", systemImage: "plus.rectangle.on.folder")
            }
        }
        .displayName("Add Subscription")
        .description("Track a new subscription in SubPilot.")
    }
}
