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
    /// Set when first-run onboarding closes for a non-Pro user; consumed the
    /// first time the user actually engages (see `presentDeferredUpsellIfReady`).
    /// Persisted so a relaunch before the user engaged still honours it once.
    @AppStorage("pendingOnboardingUpsell") private var pendingOnboardingUpsell = false
    @Environment(\.requestReview) private var requestReview
    @State private var selection: AppTab = .launchSelection
    @State private var presentedSheet: AddSheet?
    /// Active-subscription count when an add sheet was presented, so dismissal
    /// can tell "added something" (rating-prompt moment) from "cancelled".
    @State private var activeCountBeforeAdd: Int?
    /// Drives the brief success HUD shown after an add actually adds something.
    @State private var addedMessage: String?
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
        .fullScreenCover(isPresented: onboardingPresented, onDismiss: armOnboardingUpsell) {
            OnboardingView {
                hasCompletedOnboarding = true
                Analytics.onboardingCompleted()
                Task { await NotificationManager.shared.rescheduleAll(modelContext: modelContext) }
            }
            .interactiveDismissDisabled()
        }
        .successHUD($addedMessage)
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
            // Cold relaunch after onboarding (session 2+): onChange(scenePhase)
            // doesn't fire on first appearance, so consume any pending upsell here.
            presentDeferredUpsellIfReady()
        }
        .onChange(of: scenePhase) { _, phase in
            // A receipt may have been shared in while the app was backgrounded.
            if phase == .active {
                checkSharedInbox()
                // A warm return is a "came back" signal — a good moment to surface
                // the deferred onboarding upsell to an engaged, retained user.
                presentDeferredUpsellIfReady()
            }
            // Capture any edits made this session in the widget snapshot before
            // the user glances at the Home/Lock Screen.
            if phase == .background { WidgetSync.refresh(modelContext: modelContext) }
        }
        .onChange(of: selection) {
            // First tab switch after onboarding = the user has seen their populated
            // dashboard and is exploring. Surface the deferred upsell now — the ask
            // lands after the value, not before it.
            presentDeferredUpsellIfReady()
        }
        .onChange(of: selectedProfileID) {
            // The widget renders the selected profile's totals + renewals.
            WidgetSync.refresh(modelContext: modelContext)
        }
        .onChange(of: preferredCurrencyCode) {
            WidgetSync.refresh(modelContext: modelContext)
        }
        // Widget deep links and App Intents both arrive as `pendingAction`
        // (the URL handler lives on AppRootView so cold launches can't drop
        // it). initial: true catches an action set before the shell's first
        // body evaluation.
        .onChange(of: router.pendingAction, initial: true) { _, _ in
            consumePendingRouterAction()
        }
        .onChange(of: hasCompletedOnboarding) {
            // An action that arrived during first-run stays pending (we don't
            // fight the onboarding cover) — deliver it now.
            consumePendingRouterAction()
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

    /// Delivers a buffered intent/deep-link action. During first-run the action
    /// stays pending (onboarding wins); `onChange(of: hasCompletedOnboarding)`
    /// re-invokes this so a Siri "Add Subscription" from a brand-new install
    /// lands after setup instead of being discarded.
    private func consumePendingRouterAction() {
        guard hasCompletedOnboarding, let action = router.pendingAction else { return }
        router.pendingAction = nil
        switch action {
        case .addSubscription:
            selection = .subscriptions
            requestAdd(.manual)
        case .showRenewals:
            selection = .calendar
        case .showHome:
            selection = .subscriptions
        }
    }

    /// Arms the one-time Pro offer instead of firing it immediately. Presenting
    /// the paywall the instant onboarding closed — before the user had seen their
    /// populated dashboard or felt any value — read as a wall and converted
    /// poorly on day one. We now defer it to the first real engagement signal
    /// (tab switch, warm return, or next launch). Soft + non-Pro only; the
    /// cover only ever closes on first launch, so this arms exactly once.
    private func armOnboardingUpsell() {
        guard !purchases.isPro else { return }
        pendingOnboardingUpsell = true
    }

    /// Presents the deferred onboarding upsell once the user has engaged. Guarded
    /// so it fires at most once, never to a Pro user, and never on top of another
    /// sheet. The brief delay lets the triggering transition (tab change / launch)
    /// settle before the sheet presents, so SwiftUI doesn't drop it.
    private func presentDeferredUpsellIfReady() {
        guard pendingOnboardingUpsell,
              !purchases.isPro,
              presentedSheet == nil,
              purchases.paywallContext == nil else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            // Re-check after the delay: a shared-inbox import or add sheet may
            // have presented meanwhile, which would swallow the paywall sheet.
            // The one-shot flag is only consumed when we actually present, so
            // a lost race keeps the offer armed for the next engagement signal.
            guard pendingOnboardingUpsell,
                  !purchases.isPro,
                  presentedSheet == nil,
                  purchases.paywallContext == nil else { return }
            pendingOnboardingUpsell = false
            purchases.paywallContext = .onboarding
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
        let added = count - before
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            addedMessage = added == 1 ? "Subscription added" : "\(added) subscriptions added"
        }
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
