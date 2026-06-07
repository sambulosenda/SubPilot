//
//  RootView.swift
//  Rubradar
//

import SwiftUI
import SwiftData
import CoreData

enum AppTab: Hashable {
    case subscriptions, calendar, assistant, settings
}

/// Which add flow to present. `.sharedImport` carries a receipt handed in by the
/// Share Extension so it rides the same single `.sheet(item:)` as every add flow
/// (one sheet modifier avoids only-one-sheet-at-a-time conflicts).
enum AddSheet: Identifiable {
    case manual
    case catalogue
    case scan
    case bankImport
    case sharedImport(ReceiptSource)

    var id: String {
        switch self {
        case .manual: "manual"
        case .catalogue: "catalogue"
        case .scan: "scan"
        case .bankImport: "bankImport"
        case .sharedImport: "sharedImport"
        }
    }
}

/// App shell: a tab bar over the three primary destinations. Adding a
/// subscription is an in-content action (Home toolbar + dashboard CTA), so it
/// presents a sheet rather than occupying a tab.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
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

            Tab("Assistant", systemImage: "sparkles", value: AppTab.assistant) {
                AssistantView()
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
            case .bankImport:
                BankImportView()
            case .sharedImport(let source):
                ImportView(initialSource: source)
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
            WidgetSync.refresh(modelContext: modelContext)
            // Notification permission is requested via the onboarding primer
            // (FR-21), not cold here. rescheduleAll no-ops until authorized.
            await NotificationManager.shared.rescheduleAll(modelContext: modelContext)
            checkSharedInbox()
        }
        .onChange(of: scenePhase) { _, phase in
            // A receipt may have been shared in while the app was backgrounded.
            if phase == .active { checkSharedInbox() }
            // Capture any edits made this session in the widget snapshot before
            // the user glances at the Home/Lock Screen.
            if phase == .background { WidgetSync.refresh(modelContext: modelContext) }
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
                    WidgetSync.refresh(modelContext: modelContext)
                }
            }
        }
    }

    /// Presents the import flow for the next receipt shared in from the extension.
    /// Skips while onboarding or another sheet is up; the next foreground retries.
    private func checkSharedInbox() {
        guard hasCompletedOnboarding, presentedSheet == nil else { return }
        if let source = SharedInbox.consumeNext() {
            presentedSheet = .sharedImport(source)
        }
    }
}

#Preview {
    RootView()
        .modelContainer(.preview)
        .environment(CurrencyService())
}
