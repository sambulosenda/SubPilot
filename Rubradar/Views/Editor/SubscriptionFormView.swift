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

    // Quick-fill (create mode only): catalogue / scan feed the open form in place.
    @State private var showCatalogue = false
    @State private var showScan = false
    /// Loaded once for name → category auto-detect (avoids re-decoding per keystroke).
    @State private var catalogue: [CatalogueProvider] = []
    /// Set when the user taps a category chip — freezes auto-detect from overriding it.
    @State private var categoryManuallySet = false

    @Query(sort: \Profile.sortIndex) private var profiles: [Profile]
    @AppStorage("selectedProfileID") private var selectedProfileID = ""
    /// Profile this subscription belongs to; resolved on appear, applied on save.
    @State private var formProfileID = ""

    init(mode: FormMode, onSaved: (() -> Void)? = nil) {
        self.mode = mode
        self.onSaved = onSaved
        switch mode {
        case .create(let draft):
            let model = SubscriptionFormModel(source: draft)
            // New subscriptions inherit the global default reminder timing;
            // the per-subscription picker below still overrides it.
            model.reminderLeadDays = ReminderLead.storedDefault
            _model = State(initialValue: model)
        case .edit(let draft):
            _model = State(initialValue: SubscriptionFormModel(source: draft))
        }
    }

    private static let commonCurrencies = ["GBP", "USD", "EUR", "CAD", "AUD", "JPY", "CHF", "INR"]

    /// Common currencies first, then the rest of the ISO list. Built once — the
    /// set is constant, so it must not rebuild on every keystroke in the form.
    private static let currencyOptions: [String] = {
        let rest = Locale.commonISOCurrencyCodes.filter { !commonCurrencies.contains($0) }
        return commonCurrencies + rest
    }()

    var body: some View {
        NavigationStack {
            Form {
                if !mode.isEditing {
                    Section {
                        Button {
                            showCatalogue = true
                        } label: {
                            Label("Browse catalogue", systemImage: "magnifyingglass")
                        }
                        Button {
                            showScan = true
                        } label: {
                            Label("Scan receipt", systemImage: "doc.viewfinder")
                        }
                    } header: {
                        Text("Quick fill")
                    } footer: {
                        Text("Pick a known service or scan a receipt to fill the form for you.")
                    }
                }

                Section("Details") {
                    TextField("Name", text: $model.name)
                        .textInputAutocapitalization(.words)
                        // Placeholder stops being announced once filled.
                        .accessibilityLabel("Name")
                }

                if profiles.count > 1 {
                    Section("Profile") {
                        Picker("Profile", selection: $formProfileID) {
                            ForEach(profiles) { profile in
                                Label(profile.name, systemImage: profile.symbolName)
                                    .tag(profile.id.uuidString)
                            }
                        }
                    }
                }

                Section("Category") {
                    CategoryChipPicker(selection: model.category) { picked in
                        categoryManuallySet = true
                        model.category = picked
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section("Cost") {
                    HStack {
                        Text("Amount")
                            .accessibilityHidden(true)
                        Spacer()
                        TextField("0.00", value: $model.amount, format: .number.precision(.fractionLength(0...2)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            // One stop: "Amount, text field" — not label then field.
                            .accessibilityLabel("Amount")
                    }
                    Picker("Currency", selection: $model.currencyCode) {
                        ForEach(Self.currencyOptions, id: \.self) { code in
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
                        ForEach(ReminderLead.options, id: \.days) { option in
                            Text(option.label).tag(option.days)
                        }
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
                        .accessibilityLabel("Notes")
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
            .task {
                if !mode.isEditing && catalogue.isEmpty {
                    catalogue = CatalogueLoader.load()
                }
                if formProfileID.isEmpty { formProfileID = defaultProfileID }
            }
            .onChange(of: model.name) { _, newName in
                // Recognise a known service as the user types and pre-pick its
                // category + branding — unless they've already chosen a chip.
                guard !mode.isEditing, !categoryManuallySet else { return }
                if let match = CatalogueLoader.match(in: newName, providers: catalogue) {
                    model.applyBrand(match)
                }
            }
            .sheet(isPresented: $showCatalogue) {
                CatalogueView(onSelect: { provider in
                    model.fill(from: provider.makeDraft())
                })
            }
            .sheet(isPresented: $showScan) {
                ImportView(onParsed: { draft in
                    model.fill(from: draft)
                })
            }
        }
    }

    /// Profile a freshly-opened form should select: the edited sub's own profile,
    /// else the profile currently focused on Home, else the first profile.
    private var defaultProfileID: String {
        if case .edit(let existing) = mode, let id = existing.profile?.id.uuidString {
            return id
        }
        if !selectedProfileID.isEmpty, profiles.contains(where: { $0.id.uuidString == selectedProfileID }) {
            return selectedProfileID
        }
        return profiles.first?.id.uuidString ?? ""
    }

    private func save() {
        let target: Subscription
        switch mode {
        case .create:
            target = Subscription()
            model.apply(to: target)
            modelContext.insert(target)
        case .edit(let existing):
            model.apply(to: existing)
            target = existing
        }
        if let profile = profiles.first(where: { $0.id.uuidString == formProfileID }) {
            target.profile = profile
        }
        didSave = true
        Task { await NotificationManager.shared.rescheduleAll(modelContext: modelContext) }
        // Push the change to the Home/Lock Screen widget now; otherwise it shows
        // stale totals + next-renewal until the app is next backgrounded.
        WidgetSync.refresh(modelContext: modelContext)
        dismiss()
        onSaved?()
    }
}

// MARK: - Category chips

/// A horizontal, one-tap category selector. Each chip carries the category's own
/// icon + tint, rendered as interactive Liquid Glass capsules.
private struct CategoryChipPicker: View {
    let selection: SubscriptionCategory
    let onPick: (SubscriptionCategory) -> Void

    var body: some View {
        GlassEffectContainer(spacing: Spacing.sm) {
            ScrollView(.horizontal) {
                HStack(spacing: Spacing.sm) {
                    ForEach(SubscriptionCategory.allCases) { category in
                        chip(for: category)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func chip(for category: SubscriptionCategory) -> some View {
        let isSelected = category == selection
        return Button {
            onPick(category)
        } label: {
            Label(category.label, systemImage: category.defaultSymbol)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? category.tint : .primary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
        }
        .buttonStyle(.plain)
        .glassEffect(
            isSelected
                ? .regular.tint(category.tint.opacity(0.25)).interactive()
                : .regular.interactive(),
            in: .capsule
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
