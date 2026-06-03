//
//  RootView.swift
//  Rubradar
//

import SwiftUI
import SwiftData

enum AppTab: Hashable {
    case subscriptions, add, calendar, settings
}

/// Which add flow to present.
enum AddSheet: Identifiable {
    case manual
    case catalogue
    var id: Int { hashValue }
}

/// App shell: a tab bar over the four primary destinations. The centre "Add"
/// tab doesn't navigate — it offers a chooser that presents the catalogue or a
/// blank manual form as a sheet.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selection: AppTab = .subscriptions
    @State private var presentedSheet: AddSheet?
    @State private var showAddChooser = false

    var body: some View {
        TabView(selection: $selection) {
            Tab("Subscriptions", systemImage: "rectangle.stack.fill", value: AppTab.subscriptions) {
                SubscriptionListView(presentAdd: { presentedSheet = $0 })
            }

            Tab("Add", systemImage: "plus.circle.fill", value: AppTab.add) {
                Color.clear
            }

            Tab("Calendar", systemImage: "calendar", value: AppTab.calendar) {
                CalendarPlaceholderView()
            }

            Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                SettingsView()
            }
        }
        .onChange(of: selection) { old, new in
            // The Add tab is an action, not a destination — revert and offer the chooser.
            if new == .add {
                selection = old
                showAddChooser = true
            }
        }
        .confirmationDialog("Add a subscription", isPresented: $showAddChooser, titleVisibility: .visible) {
            Button("Browse catalogue") { presentedSheet = .catalogue }
            Button("Add manually") { presentedSheet = .manual }
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .manual:
                SubscriptionFormView(mode: .create(Subscription()))
            case .catalogue:
                CatalogueView()
            }
        }
        .task {
            await CurrencyService.shared.refreshIfNeeded()
            await NotificationManager.shared.requestAuthorization()
            await NotificationManager.shared.rescheduleAll(modelContext: modelContext)
        }
    }
}

#Preview {
    RootView()
        .modelContainer(.preview)
}
