//
//  QuickAddSheet.swift
//  Rubradar
//

import SwiftUI
import SwiftData

/// The short add path for a catalogue pick: confirm the price and the next
/// renewal, tap Add. A known service already supplies its name, category and
/// branding, so sending it through the full eight-section form made the user
/// scroll past fields that were either filled or irrelevant. Everything else
/// stays one tap away behind "More options".
struct QuickAddSheet: View {
    let provider: CatalogueProvider
    /// Called after the subscription is saved, here or via the full form.
    var onSaved: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Profile.sortIndex) private var profiles: [Profile]
    @AppStorage("selectedProfileID") private var selectedProfileID = ""

    @State private var model: SubscriptionFormModel
    /// Set once the user picks a renewal date, so choosing another plan stops
    /// re-deriving it from the plan's cycle.
    @State private var dateEdited = false
    @State private var fullFormDraft: Subscription?
    @State private var didSave = false
    @FocusState private var amountFocused: Bool

    /// Plans priced in the device currency; empty when we have none.
    private let plans: [CataloguePlan]
    /// Custom cycles need a day count — that lives in the full form.
    private static let cycles: [BillingCycle] = [.weekly, .monthly, .yearly]

    init(provider: CatalogueProvider, onSaved: (() -> Void)? = nil) {
        self.provider = provider
        self.onSaved = onSaved
        let draft = provider.makeDraft()
        plans = CataloguePriceBook.plans(for: provider.id, currencyCode: draft.currencyCode)
        let model = SubscriptionFormModel(source: draft)
        model.reminderLeadDays = ReminderLead.storedDefault
        _model = State(initialValue: model)
    }

    /// The plan matching what's currently entered. Derived rather than stored so
    /// the checkmark clears by itself the moment the user types their own price.
    private var selectedPlan: CataloguePlan? {
        plans.first {
            $0.cycle == model.billingCycle && $0.amount(in: model.currencyCode) == model.amount
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    header
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                if plans.count > 1 {
                    Section("Plan") {
                        ForEach(plans) { plan in
                            Button { select(plan) } label: { planRow(plan) }
                                .tint(.primary)
                        }
                    }
                }

                Section {
                    HStack {
                        Text("Amount")
                            .accessibilityHidden(true)
                        Spacer()
                        TextField("0.00", value: $model.amount, format: .number.precision(.fractionLength(0...2)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($amountFocused)
                            .accessibilityLabel("Amount")
                        Text(model.currencyCode)
                            .foregroundStyle(.secondary)
                    }
                    Picker("Billing cycle", selection: $model.billingCycle) {
                        ForEach(Self.cycles) { cycle in
                            Text(cycle.label).tag(cycle)
                        }
                    }
                    DatePicker("Next renewal", selection: renewalDate, displayedComponents: .date)
                } footer: {
                    if !plans.isEmpty {
                        Text("Typical price. Change it if yours is different.")
                    }
                }

                Section {
                    Button("More options") { openFullForm() }
                }
            }
            .navigationTitle("Add Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { add() }
                        .disabled(!model.isValid)
                }
                // The decimal pad has no return key.
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { amountFocused = false }
                }
            }
            .sensoryFeedback(.success, trigger: didSave)
            .task {
                // No known price: the amount is the one thing left to type, so
                // open into it. The delay lets the sheet finish presenting.
                guard model.amount == 0 else { return }
                try? await Task.sleep(for: .milliseconds(350))
                amountFocused = true
            }
            .sheet(item: $fullFormDraft) { draft in
                SubscriptionFormView(mode: .create(draft), addMethod: .catalogue, onSaved: {
                    dismiss()
                    onSaved?()
                })
            }
        }
        .presentationDetents(plans.count > 1 ? [.large] : [.medium, .large])
    }

    private var header: some View {
        HStack(spacing: Spacing.md) {
            BrandLogoView(
                symbolName: provider.symbolName,
                logoAssetName: provider.logoAssetName,
                brandDomain: provider.domain,
                tint: Color(hex: provider.brandColorHex ?? "") ?? provider.category.tint,
                category: provider.category,
                size: 52
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: provider.name)
                    .font(.title3.bold())
                Text(provider.category.label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.xs)
        .accessibilityElement(children: .combine)
    }

    private func planRow(_ plan: CataloguePlan) -> some View {
        let isSelected = plan.id == selectedPlan?.id
        return HStack {
            // Plan names are the provider's own product names — not translated.
            Text(verbatim: plan.name)
            Spacer()
            if let amount = plan.amount(in: model.currencyCode) {
                Text(verbatim: "\(amount.formatted(.currency(code: model.currencyCode))) / \(plan.cycle.shortLabel)")
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "checkmark")
                .fontWeight(.semibold)
                .foregroundStyle(.tint)
                .opacity(isSelected ? 1 : 0)
                .accessibilityHidden(true)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var renewalDate: Binding<Date> {
        Binding(
            get: { model.nextRenewalDate },
            set: { model.nextRenewalDate = $0; dateEdited = true }
        )
    }

    private func select(_ plan: CataloguePlan) {
        guard let amount = plan.amount(in: model.currencyCode) else { return }
        model.amount = amount
        model.billingCycle = plan.cycle
        if !dateEdited {
            model.nextRenewalDate = plan.cycle.nextDate(after: Date())
        }
    }

    /// Hands the values entered so far to the full form.
    private func openFullForm() {
        let draft = Subscription()
        model.apply(to: draft)
        fullFormDraft = draft
    }

    /// Mirrors the create path of `SubscriptionFormView.save()` — keep the two
    /// in step when a save-time side effect is added there.
    private func add() {
        let target = Subscription()
        model.apply(to: target)
        modelContext.insert(target)
        target.profile = profiles.first { $0.id.uuidString == selectedProfileID } ?? profiles.first
        didSave = true
        let activeCount = (try? modelContext.fetchCount(
            FetchDescriptor<Subscription>(predicate: #Predicate { !$0.isCancelled })
        )) ?? 0
        Analytics.subscriptionAdded(method: .catalogue, totalActive: activeCount)
        Task { await NotificationManager.shared.rescheduleAll(modelContext: modelContext) }
        WidgetSync.refresh(modelContext: modelContext)
        dismiss()
        onSaved?()
    }
}

#Preview("With plans") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            QuickAddSheet(provider: CatalogueLoader.load().first { $0.id == "netflix" }!)
        }
        .modelContainer(.preview)
}
