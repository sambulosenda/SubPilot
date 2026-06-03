//
//  SettingsPlaceholderView.swift
//  Rubradar
//

import SwiftUI

/// Placeholder for settings (preferred currency, reminders, backup — later milestones).
struct SettingsPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Settings coming soon",
                systemImage: "gearshape",
                description: Text("Preferred currency, reminders and iCloud backup will live here.")
            )
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsPlaceholderView()
}
