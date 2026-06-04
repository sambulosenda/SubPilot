//
//  RootView.swift
//  Rubradar
//

import SwiftUI
import SwiftData
import CoreData

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
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selection: AppTab = .subscriptions
    @State private var presentedSheet: AddSheet?

    /// Drives the first-run onboarding cover. Finishing/skipping sets the
    /// stored flag, which flips this to `false` and dismisses. The setter also
    /// persists completion so any system-driven dismissal can't re-present it.
    private var onboardingPresented: Binding<Bool> {
        Binding(
            get: { !hasCompletedOnboarding },
            set: { presented in if !presented { hasCompletedOnboarding = true } }
        )
    }

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
        .fullScreenCover(isPresented: onboardingPresented) {
            OnboardingView {
                hasCompletedOnboarding = true
                Task { await NotificationManager.shared.rescheduleAll(modelContext: modelContext) }
            }
            .interactiveDismissDisabled()
        }
        .task {
            // Guarantee a default profile exists and adopt any pre-profile data.
            ProfileSetup.ensureDefault(in: modelContext)
            await CurrencyService.shared.refreshIfNeeded()
            // Notification permission is requested via the onboarding primer
            // (FR-21), not cold here. rescheduleAll no-ops until authorized.
            await NotificationManager.shared.rescheduleAll(modelContext: modelContext)
        }
        .task {
            // Subscriptions synced in from another device (CloudKit import) need
            // local reminders scheduled. Consuming the async sequence on this
            // MainActor task keeps state updates on the main thread; the loop is
            // cancelled automatically when the view disappears. Debounce so a
            // burst of imports reschedules just once.
            var pending: Task<Void, Never>?
            for await _ in NotificationCenter.default.notifications(named: .NSPersistentStoreRemoteChange) {
                pending?.cancel()
                pending = Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    guard !Task.isCancelled else { return }
                    await NotificationManager.shared.rescheduleAll(modelContext: modelContext)
                }
            }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(.preview)
        .environment(CurrencyService())
}
