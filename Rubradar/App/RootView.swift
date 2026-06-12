//
//  RootView.swift
//  Rubradar
//

import SwiftUI
import SwiftData
import CoreData
import StoreKit

enum AppTab: Hashable {
    case subscriptions, calendar, assistant, settings

    /// Tab the shell opens on. Normally Home; overridable in DEBUG via the
    /// `-StartTab <calendar|assistant|settings>` launch argument so App Store
    /// screenshots of each tab can be captured by relaunching, no UI taps needed.
    static var launchSelection: AppTab {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-StartTab"), i + 1 < args.count {
            switch args[i + 1] {
            case "calendar": return .calendar
            case "assistant": return .assistant
            case "settings": return .settings
            default: break
            }
        }
        #endif
        return .subscriptions
    }
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
    @Environment(\.requestReview) private var requestReview
    @State private var selection: AppTab = .launchSelection
    @State private var presentedSheet: AddSheet?
    /// Active-subscription count when an add sheet was presented, so dismissal
    /// can tell "added something" (rating-prompt moment) from "cancelled".
    @State private var activeCountBeforeAdd: Int?
    /// Singleton bridge from App Intents (Siri/Shortcuts/Spotlight) — observed
    /// here so an intent's navigation request lands whether the app was cold-
    /// launched or already foregrounded.
    private var router = AppRouter.shared

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
        .sheet(item: $presentedSheet, onDismiss: maybeRequestReview) { sheet in
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
            ReviewPrompter.noteLaunch()
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
            // Deep links from the widget (subpilot://renewals | home | add).
            guard url.scheme == WidgetDeepLink.scheme else { return }
            switch url.host {
            case "renewals": selection = .calendar
            case "home": selection = .subscriptions
            case "add":
                selection = .subscriptions
                requestAdd(.manual)
            default: break
            }
        }
        // initial: true catches a cold launch where the intent ran before the
        // shell's first body evaluation.
        .onChange(of: router.pendingAction, initial: true) { _, action in
            guard let action else { return }
            router.pendingAction = nil
            // Don't fight the first-run cover; onboarding wins.
            guard hasCompletedOnboarding else { return }
            switch action {
            case .addSubscription:
                selection = .subscriptions
                requestAdd(.manual)
            case .showRenewals:
                selection = .calendar
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

    private func activeSubscriptionCount() -> Int {
        (try? modelContext.fetchCount(
            FetchDescriptor<Subscription>(predicate: #Predicate { !$0.isCancelled })
        )) ?? 0
    }

    /// Asks for a rating right after an add flow actually added something —
    /// the user just invested in the app. `ReviewPrompter` applies the gates
    /// (3+ subs, 3+ days installed, 120-day spacing); the short delay lets the
    /// sheet's dismissal settle before the system alert appears.
    private func maybeRequestReview() {
        guard let before = activeCountBeforeAdd else { return }
        activeCountBeforeAdd = nil
        let count = activeSubscriptionCount()
        guard count > before else { return }
        Task {
            try? await Task.sleep(for: .seconds(1))
            ReviewPrompter.maybePrompt(activeCount: count) { requestReview() }
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
            guard PurchaseGate.canAddSubscription(activeCount: activeSubscriptionCount(), isPro: purchases.isPro) else {
                purchases.paywallContext = .subscriptionLimit
                return
            }
        case .sharedImport:
            break // Handed in via the iOS share sheet; presented as-is.
        }
        activeCountBeforeAdd = activeSubscriptionCount()
        presentedSheet = sheet
    }

    /// Presents the import flow for the next receipt shared in from the extension.
    /// Skips while onboarding or another sheet is up; the next foreground retries.
    private func checkSharedInbox() {
        guard hasCompletedOnboarding, presentedSheet == nil else { return }
        if let source = SharedInbox.consumeNext() {
            activeCountBeforeAdd = activeSubscriptionCount()
            presentedSheet = .sharedImport(source)
            return
        }
        // Control Center "Add Subscription" — its intent runs in the widget
        // process and can only raise this App Group flag before opening us.
        if WidgetSnapshotStore.consumeAddRequest() {
            selection = .subscriptions
            requestAdd(.manual)
        }
    }
}

#Preview {
    RootView()
        .modelContainer(.preview)
        .environment(CurrencyService())
        .environment(PurchaseManager.preview(isPro: true))
}
