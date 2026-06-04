//
//  SettingsPlaceholderView.swift
//  Rubradar
//

import SwiftUI
import SwiftData

/// App settings: preferred currency, reminders, and FX status.
struct SettingsView: View {
    @Environment(CurrencyService.self) private var currency
    @Environment(\.modelContext) private var modelContext

    @AppStorage("preferredCurrencyCode") private var preferredCurrency =
        Locale.current.currency?.identifier ?? "GBP"
    @AppStorage("remindersEnabled") private var remindersEnabled = true

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
                } header: {
                    Text("Reminders")
                } footer: {
                    Text("Get a local notification before each subscription renews. Set the timing per subscription when editing it.")
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
            .onChange(of: remindersEnabled) {
                Task { await NotificationManager.shared.rescheduleAll(modelContext: modelContext) }
            }
        }
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
