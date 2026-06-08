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
    @Environment(PurchaseManager.self) private var purchases
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    // Mirror the two prefs the widget snapshot keys off so a profile switch or a
    // currency change repaints the widget immediately (see the .onChange below).
    @AppStorage("selectedProfileID") private var selectedProfileID = ""
    @AppStorage("preferredCurrencyCode") private var preferredCurrencyCode = ""
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
        @Bindable var purchases = purchases
        TabView(selection: $selection) {
            Tab("Home", systemImage: "house.fill", value: AppTab.subscriptions) {
                SubscriptionListView(
                    presentAdd: requestAdd,
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
        .sheet(item: $purchases.paywallContext) { context in
            PaywallView(context: context)
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
        .onChange(of: selectedProfileID) {
            // The widget renders the selected profile's totals + renewals.
            WidgetSync.refresh(modelContext: modelContext)
        }
        .onChange(of: preferredCurrencyCode) {
            WidgetSync.refresh(modelContext: modelContext)
        }
        .onOpenURL { url in
            // Deep links from the widget (subpilot://renewals | subpilot://home).
            guard url.scheme == WidgetDeepLink.scheme else { return }
            switch url.host {
            case "renewals": selection = .calendar
            case "home": selection = .subscriptions
            default: break
            }
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

    /// Routes an add request through the Pro gates before presenting. Receipt
    /// scanning and bank import are Pro-only; manual/catalogue add is capped on
    /// the free tier. Every add entry point funnels through this one closure.
    private func requestAdd(_ sheet: AddSheet) {
        switch sheet {
        case .scan:
            guard purchases.isPro else { purchases.paywallContext = .receiptScan; return }
        case .bankImport:
            guard purchases.isPro else { purchases.paywallContext = .bankImport; return }
        case .manual, .catalogue:
            let activeCount = (try? modelContext.fetchCount(
                FetchDescriptor<Subscription>(predicate: #Predicate { !$0.isCancelled })
            )) ?? 0
            guard PurchaseGate.canAddSubscription(activeCount: activeCount, isPro: purchases.isPro) else {
                purchases.paywallContext = .subscriptionLimit
                return
            }
        case .sharedImport:
            break // Handed in via the iOS share sheet; presented as-is.
        }
        presentedSheet = sheet
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
        .environment(PurchaseManager.preview(isPro: true))
}
