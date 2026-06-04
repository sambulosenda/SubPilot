//
//  RootView.swift
//  Rubradar
//

import SwiftUI
import SwiftData

enum AppTab: Hashable {
    case subscriptions, calendar, settings
}

/// Which add flow to present.
enum AddSheet: Identifiable {
    case manual
    case catalogue
    case scan
    var id: Int { hashValue }
}

/// App shell: a tab bar over the three primary destinations. Adding a
/// subscription is an in-content action (Home toolbar + dashboard CTA), so it
/// presents a sheet rather than occupying a tab.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selection: AppTab = .subscriptions
    @State private var presentedSheet: AddSheet?

    var body: some View {
        TabView(selection: $selection) {
            Tab("Home", systemImage: "house.fill", value: AppTab.subscriptions) {
                SubscriptionListView(
                    presentAdd: { presentedSheet = $0 },
                    onViewAllRenewals: { selection = .calendar }
                )
            }

            Tab("Calendar", systemImage: "calendar", value: AppTab.calendar) {
                RenewalCalendarView()
            }

            Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                SettingsView()
            }
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .manual:
                SubscriptionFormView(mode: .create(Subscription()))
            case .catalogue:
                CatalogueView()
            case .scan:
                ImportView()
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
        .environment(CurrencyService())
}
