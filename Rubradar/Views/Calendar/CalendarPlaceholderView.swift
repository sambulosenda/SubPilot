//
//  CalendarPlaceholderView.swift
//  Rubradar
//

import SwiftUI

/// Placeholder for the renewal calendar (built in a later milestone).
struct CalendarPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Calendar coming soon",
                systemImage: "calendar",
                description: Text("A timeline of your upcoming renewals will live here.")
            )
            .navigationTitle("Calendar")
        }
    }
}

#Preview {
    CalendarPlaceholderView()
}
