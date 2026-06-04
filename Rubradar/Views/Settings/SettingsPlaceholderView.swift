//
//  SettingsPlaceholderView.swift
//  Rubradar
//

import SwiftUI
import SwiftData
import UIKit
import UserNotifications

/// App settings: preferred currency, reminders, and FX status.
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
            }
            .navigationTitle("Settings")
            .task { await refreshNotificationStatus() }
            .onChange(of: remindersEnabled) {
                Task { await NotificationManager.shared.rescheduleAll(modelContext: modelContext) }
            }
            .onChange(of: scenePhase) { _, phase in
                // The user may have flipped the system toggle while away.
                if phase == .active { Task { await refreshNotificationStatus() } }
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
