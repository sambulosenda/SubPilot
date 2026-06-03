//
//  SubscriptionFormView.swift
//  Rubradar
//

import SwiftUI
import SwiftData

/// Shared add / edit form. Drives a `SubscriptionFormModel` working copy and
/// commits to SwiftData only on Save.
struct SubscriptionFormView: View {
    let mode: FormMode
    /// Called after a successful save (e.g. so a presenting catalogue can dismiss too).
    var onSaved: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var model: SubscriptionFormModel
    @State private var didSave = false

    init(mode: FormMode, onSaved: (() -> Void)? = nil) {
        self.mode = mode
        self.onSaved = onSaved
        switch mode {
        case .create(let draft), .edit(let draft):
            _model = State(initialValue: SubscriptionFormModel(source: draft))
        }
    }

    private static let commonCurrencies = ["GBP", "USD", "EUR", "CAD", "AUD", "JPY", "CHF", "INR"]

    private var currencyOptions: [String] {
        let all = Locale.commonISOCurrencyCodes
        let rest = all.filter { !Self.commonCurrencies.contains($0) }
        return Self.commonCurrencies + rest
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $model.name)
                        .textInputAutocapitalization(.words)

                    Picker("Category", selection: $model.category) {
                        ForEach(SubscriptionCategory.allCases) { cat in
                            Label(cat.label, systemImage: cat.defaultSymbol).tag(cat)
                        }
                    }
                }

                Section("Cost") {
                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField("0.00", value: $model.amount, format: .number.precision(.fractionLength(0...2)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    Picker("Currency", selection: $model.currencyCode) {
                        ForEach(currencyOptions, id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }
                    Picker("Billing cycle", selection: $model.billingCycle) {
                        ForEach(BillingCycle.allCases) { cycle in
                            Text(cycle.label).tag(cycle)
                        }
                    }
                    if model.billingCycle == .custom {
                        Stepper("Every \(model.customCycleDays) days",
                                value: $model.customCycleDays, in: 1...365)
                    }
                }

                Section("Renewal") {
                    DatePicker("Next renewal", selection: $model.nextRenewalDate, displayedComponents: .date)
                    Picker("Remind me", selection: $model.reminderLeadDays) {
                        Text("On the day").tag(0)
                        Text("1 day before").tag(1)
                        Text("2 days before").tag(2)
                        Text("3 days before").tag(3)
                        Text("1 week before").tag(7)
                    }
                }

                Section("Free trial") {
                    Toggle("This is a free trial", isOn: $model.isFreeTrial)
                    if model.isFreeTrial {
                        DatePicker("Trial ends", selection: $model.trialEndDate, displayedComponents: .date)
                    }
                }

                Section("Notes") {
                    TextField("Notes", text: $model.notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(mode.isEditing ? "Edit Subscription" : "New Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!model.isValid)
                }
            }
            .sensoryFeedback(.success, trigger: didSave)
        }
    }

    private func save() {
        switch mode {
        case .create:
            let subscription = Subscription()
            model.apply(to: subscription)
            modelContext.insert(subscription)
        case .edit(let existing):
            model.apply(to: existing)
        }
        didSave = true
        Task { await NotificationManager.shared.rescheduleAll(modelContext: modelContext) }
        dismiss()
        onSaved?()
    }
}

#Preview("Create") {
    SubscriptionFormView(mode: .create(Subscription()))
        .modelContainer(.preview)
}

#Preview("Edit") {
    SubscriptionFormView(mode: .edit(SampleData.makeSamples()[0]))
        .modelContainer(.preview)
}
