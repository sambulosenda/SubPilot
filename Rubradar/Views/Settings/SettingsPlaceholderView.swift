//
//  SettingsPlaceholderView.swift
//  Rubradar
//

import SwiftUI
import SwiftData
import UIKit
import UserNotifications
import CloudKit
import StoreKit

/// App settings: iCloud sync, preferred currency, reminders, and FX status.
struct SettingsView: View {
    @Environment(CurrencyService.self) private var currency
    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    /// All subscriptions, for CSV export (a complete backup, every profile).
    @Query private var subscriptions: [Subscription]

    @AppStorage("preferredCurrencyCode") private var preferredCurrency =
        Locale.current.currency?.identifier ?? "GBP"
    @AppStorage("remindersEnabled") private var remindersEnabled = true
    @AppStorage(ReminderLead.defaultsKey) private var defaultReminderLeadDays = ReminderLead.defaultDays
    @AppStorage(MonthlyRecap.enabledKey) private var monthlyRecapEnabled = true
    @AppStorage(Analytics.optInDefaultsKey) private var analyticsOptIn = true

    /// System notification authorization, so we can surface a recovery path
    /// when reminders are enabled in-app but blocked at the system level.
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    /// iCloud account availability, so we can show whether sync/backup is active
    /// and nudge the user to sign in when it isn't.
    @State private var iCloudStatus: CKAccountStatus = .couldNotDetermine

    /// Convertible currencies, always including the current selection so the
    /// picker never shows a blank value when the preferred code has no FX rate.
    private var currencyOptions: [String] {
        var codes = Set(currency.rates.supportedCodes)
        codes.insert(preferredCurrency)
        return codes.sorted()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if purchases.isPro {
                        LabeledContent("SubHelm Pro") {
                            Label("Active", systemImage: "checkmark.seal.fill")
                                .labelStyle(.titleAndIcon)
                                .foregroundStyle(.green)
                        }
                    } else {
                        Button {
                            purchases.paywallContext = .generic
                        } label: {
                            Label("Unlock SubHelm Pro", systemImage: "crown.fill")
                        }
                    }
                    Button("Restore Purchases") {
                        Task { await purchases.restore() }
                    }
                    .disabled(purchases.purchaseInProgress)
                } header: {
                    Text("SubHelm Pro")
                }

                Section {
                    LabeledContent("iCloud Sync") {
                        Label(iCloudStatusText, systemImage: iCloudStatusSymbol)
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(iCloudStatus == .available ? .green : .secondary)
                    }
                    if iCloudStatus == .noAccount {
                        Button("Open iCloud Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                    }
                } header: {
                    Text("iCloud")
                } footer: {
                    Text(iCloudStatus == .available
                         ? "Your subscriptions sync and back up across your devices via iCloud."
                         : "Sign in to iCloud to sync and back up your subscriptions across your devices.")
                }

                Section {
                    NavigationLink {
                        ManageProfilesView()
                    } label: {
                        Label("Profiles", systemImage: "person.2.crop.square.stack.fill")
                    }
                }

                Section("Currency") {
                    Picker("Preferred currency", selection: $preferredCurrency) {
                        ForEach(currencyOptions, id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }
                }

                // No footers on the plain sections: the labels say what the
                // controls do. Exchange rates are gone from here altogether;
                // they refresh on their own and were never the user's job.
                Section("Reminders") {
                    // The problem leads when iOS is blocking notifications,
                    // and the switches show what is actually happening: they
                    // used to sit green above a small note saying nothing
                    // would arrive.
                    if notificationsBlocked {
                        reminderRecovery
                    }
                    Toggle("Renewal reminders", isOn: effective($remindersEnabled))
                        .disabled(notificationsBlocked)
                    if remindersEnabled && !notificationsBlocked {
                        Picker("Default reminder", selection: $defaultReminderLeadDays) {
                            ForEach(ReminderLead.options, id: \.days) { option in
                                Text(option.label).tag(option.days)
                            }
                        }
                        reminderRecovery
                    }
                    Toggle("Monthly spending recap", isOn: effective($monthlyRecapEnabled))
                        .disabled(notificationsBlocked)
                }

                Section("Data") {
                    ShareLink(
                        item: SubscriptionCSVExport.make(from: subscriptions),
                        preview: SharePreview("SubHelm Subscriptions", image: Image(systemName: "tablecells"))
                    ) {
                        Label("Export to CSV", systemImage: "square.and.arrow.up")
                    }
                    .disabled(subscriptions.isEmpty)
                }

                Section {
                    Toggle("Share anonymous usage data", isOn: $analyticsOptIn)
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Helps improve SubHelm with anonymous usage stats — which features get used and how the app performs. Never your subscriptions, amounts, notes, or anything that identifies you. Turn it off anytime.")
                }

                Section {
                    NavigationLink {
                        SupportView()
                    } label: {
                        Label("Help & Support", systemImage: "questionmark.circle.fill")
                    }
                }
            }
            .navigationTitle("Settings")
            .task {
                await refreshNotificationStatus()
                await refreshICloudStatus()
            }
            .onChange(of: remindersEnabled) {
                Task { await NotificationManager.shared.rescheduleAll(modelContext: modelContext) }
            }
            .onChange(of: monthlyRecapEnabled) {
                Task { await NotificationManager.shared.rescheduleAll(modelContext: modelContext) }
            }
            .onChange(of: analyticsOptIn) { _, optedIn in
                Analytics.setOptedIn(optedIn)
            }
            .onChange(of: scenePhase) { _, phase in
                // The user may have flipped a system toggle (notifications or
                // iCloud sign-in) while away.
                if phase == .active {
                    Task {
                        await refreshNotificationStatus()
                        await refreshICloudStatus()
                    }
                }
            }
        }
    }

    private var notificationsBlocked: Bool { notificationStatus == .denied }

    /// A switch that reads off while iOS is blocking notifications, without
    /// touching the stored preference, so it comes back as the user left it
    /// once notifications are allowed again.
    private func effective(_ stored: Binding<Bool>) -> Binding<Bool> {
        Binding(
            get: { stored.wrappedValue && !notificationsBlocked },
            set: { stored.wrappedValue = $0 }
        )
    }

    /// Recovery path (FR-21) shown only when reminders are on in-app but the
    /// system permission is missing — so reminders would silently never fire.
    @ViewBuilder
    private var reminderRecovery: some View {
        switch notificationStatus {
        case .denied:
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Label("Notifications are turned off in iOS Settings, so reminders won't appear.", systemImage: "bell.slash")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            }
        case .notDetermined:
            Button("Turn on reminders") {
                Task {
                    _ = await NotificationManager.shared.requestAuthorization()
                    await refreshNotificationStatus()
                    await NotificationManager.shared.rescheduleAll(modelContext: modelContext)
                }
            }
        default:
            EmptyView()
        }
    }

    private func refreshNotificationStatus() async {
        notificationStatus = await NotificationManager.shared.authorizationStatus
    }

    private func refreshICloudStatus() async {
        let container = CKContainer(identifier: ModelContainer.cloudKitContainerID)
        iCloudStatus = (try? await container.accountStatus()) ?? .couldNotDetermine
    }

    private var iCloudStatusText: String {
        switch iCloudStatus {
        case .available: String(localized: "On", comment: "iCloud sync status")
        case .noAccount: String(localized: "Not signed in")
        case .restricted: String(localized: "Restricted")
        case .temporarilyUnavailable: String(localized: "Unavailable")
        case .couldNotDetermine: String(localized: "Checking…")
        @unknown default: String(localized: "Unavailable")
        }
    }

    private var iCloudStatusSymbol: String {
        iCloudStatus == .available ? "checkmark.icloud.fill" : "icloud.slash"
    }
}

#Preview {
    SettingsView()
        .environment(CurrencyService())
        .environment(PurchaseManager.preview(isPro: false))
        .modelContainer(.preview)
}
