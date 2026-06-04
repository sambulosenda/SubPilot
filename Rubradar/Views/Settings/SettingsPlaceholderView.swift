//
//  SettingsPlaceholderView.swift
//  Rubradar
//

import SwiftUI
import SwiftData
import UIKit
import UserNotifications
import CloudKit

/// App settings: iCloud sync, preferred currency, reminders, and FX status.
struct SettingsView: View {
    @Environment(CurrencyService.self) private var currency
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    @AppStorage("preferredCurrencyCode") private var preferredCurrency =
        Locale.current.currency?.identifier ?? "GBP"
    @AppStorage("remindersEnabled") private var remindersEnabled = true
    @AppStorage(ReminderLead.defaultsKey) private var defaultReminderLeadDays = ReminderLead.defaultDays

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

                Section {
                    Toggle("Renewal reminders", isOn: $remindersEnabled)
                    if remindersEnabled {
                        Picker("Default reminder", selection: $defaultReminderLeadDays) {
                            ForEach(ReminderLead.options, id: \.days) { option in
                                Text(option.label).tag(option.days)
                            }
                        }
                        reminderRecovery
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    Text("Get a local notification at 9 AM before each subscription renews. New subscriptions use the default timing above; change it per subscription when editing.")
                }

                Section {
                    LabeledContent("Rates updated", value: ratesUpdatedText)
                    Button {
                        Task { await currency.refresh() }
                    } label: {
                        if currency.isRefreshing {
                            ProgressView()
                        } else {
                            Text("Refresh rates now")
                        }
                    }
                    .disabled(currency.isRefreshing)
                } header: {
                    Text("Exchange rates")
                } footer: {
                    Text("Rates from frankfurter.app, refreshed daily. A bundled set is used offline.")
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
        case .available: "On"
        case .noAccount: "Not signed in"
        case .restricted: "Restricted"
        case .temporarilyUnavailable: "Unavailable"
        case .couldNotDetermine: "Checking…"
        @unknown default: "Unavailable"
        }
    }

    private var iCloudStatusSymbol: String {
        iCloudStatus == .available ? "checkmark.icloud.fill" : "icloud.slash"
    }

    private var ratesUpdatedText: String {
        if currency.lastUpdated == Date(timeIntervalSince1970: 0) { return "Offline set" }
        return currency.lastUpdated.formatted(.dateTime.day().month().year())
    }
}

#Preview {
    SettingsView()
        .environment(CurrencyService())
        .modelContainer(.preview)
}
