//
//  ImportReview.swift
//  Rubradar
//

import SwiftUI
import SwiftData

/// One reviewable subscription produced by a bulk import (bank statement or
/// multi-item receipt). Holds an un-inserted draft `Subscription` so the row can
/// render real branding/price and selected rows can be inserted as-is.
struct ImportCandidate: Identifiable {
    let id: String
    let subscription: Subscription
    var subtitle: String?
    var alreadyTracked: Bool = false
    var isPreselected: Bool = true
}

/// Shared multi-select review used after a bulk import. Lets the user pick which
/// detected subscriptions to add, then inserts the selected ones into the active
/// profile and reschedules reminders once. Embed inside a `NavigationStack`; the
/// caller supplies the navigation title.
struct ImportReviewView: View {
    let candidates: [ImportCandidate]
    /// Tracked subscriptions whose imported charge differs from the stored
    /// price. Shown in their own section; accepting one updates the stored
    /// amount and records a `PriceChange`.
    var priceUpdates: [PriceUpdate] = []
    var footer: LocalizedStringKey = "Pick the subscriptions you'd like to track."
    var emptyTitle: LocalizedStringKey = "Nothing found"
    var emptyMessage: LocalizedStringKey = "We couldn't find any subscriptions to add."
    /// Which bulk path produced these candidates — recorded per add for the
    /// activation funnel (`.scan` for receipts, `.bankImport` for statements).
    var origin: AddMethod = .scan
    /// Called after a successful add. When nil, the view dismisses itself; supply
    /// this when the review is nested so the whole flow can close.
    var onFinish: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Profile.sortIndex) private var profiles: [Profile]
    @AppStorage("selectedProfileID") private var selectedProfileID = ""
    @State private var selected: Set<String>
    @State private var selectedUpdates: Set<UUID>
    @State private var didAdd = false

    init(candidates: [ImportCandidate],
         priceUpdates: [PriceUpdate] = [],
         footer: LocalizedStringKey = "Pick the subscriptions you'd like to track.",
         emptyTitle: LocalizedStringKey = "Nothing found",
         emptyMessage: LocalizedStringKey = "We couldn't find any subscriptions to add.",
         origin: AddMethod = .scan,
         onFinish: (() -> Void)? = nil) {
        self.candidates = candidates
        self.priceUpdates = priceUpdates
        self.footer = footer
        self.emptyTitle = emptyTitle
        self.emptyMessage = emptyMessage
        self.origin = origin
        self.onFinish = onFinish
        _selected = State(initialValue: Set(candidates.filter { $0.isPreselected && !$0.alreadyTracked }.map(\.id)))
        _selectedUpdates = State(initialValue: Set(priceUpdates.map(\.id)))
    }

    var body: some View {
        Group {
            if candidates.isEmpty && priceUpdates.isEmpty {
                ContentUnavailableView(emptyTitle, systemImage: "magnifyingglass", description: Text(emptyMessage))
            } else {
                List {
                    if !priceUpdates.isEmpty {
                        Section {
                            ForEach(priceUpdates) { update in
                                PriceUpdateRow(
                                    update: update,
                                    isSelected: selectedUpdates.contains(update.id),
                                    onToggle: { toggleUpdate(update.id) }
                                )
                            }
                        } header: {
                            Text("Price changes")
                        } footer: {
                            Text("These subscriptions were charged a different amount than you have saved. Selected ones will be updated to the new price.")
                        }
                    }
                    if !candidates.isEmpty {
                        Section {
                            ForEach(candidates) { candidate in
                                ImportCandidateRow(
                                    candidate: candidate,
                                    isSelected: selected.contains(candidate.id),
                                    onToggle: { toggle(candidate.id) }
                                )
                            }
                        } footer: {
                            Text(footer)
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !selected.isEmpty || !selectedUpdates.isEmpty {
                Button {
                    addSelected()
                } label: {
                    Text(confirmLabel)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.extraLarge)
                .padding()
            }
        }
        .sensoryFeedback(.success, trigger: didAdd)
    }

    private var confirmLabel: LocalizedStringKey {
        switch (selected.count, selectedUpdates.count) {
        case (0, let updates): return "Update \(updates) prices"
        case (let adds, 0): return "Add \(adds) subscriptions"
        case (let adds, let updates): return "Add \(adds) · Update \(updates)"
        }
    }

    private func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    private func toggleUpdate(_ id: UUID) {
        if selectedUpdates.contains(id) { selectedUpdates.remove(id) } else { selectedUpdates.insert(id) }
    }

    private func addSelected() {
        let profile = activeProfile
        var added = 0
        for candidate in candidates where selected.contains(candidate.id) {
            modelContext.insert(candidate.subscription)
            candidate.subscription.profile = profile
            added += 1
        }
        for update in priceUpdates where selectedUpdates.contains(update.id) {
            let sub = update.subscription
            let oldAmount = sub.amount
            sub.amount = update.newAmount
            sub.updatedAt = Date()
            if PriceChange.record(on: sub, oldAmount: oldAmount,
                                  oldCurrencyCode: sub.currencyCode,
                                  source: .bankImport, in: modelContext) != nil {
                Analytics.priceChangeRecorded(source: .bankImport)
            }
        }
        try? modelContext.save()
        didAdd = true
        if added > 0 {
            // One event per added sub so volume is comparable to the manual path.
            let total = (try? modelContext.fetchCount(
                FetchDescriptor<Subscription>(predicate: #Predicate { !$0.isCancelled })
            )) ?? 0
            for _ in 0..<added { Analytics.subscriptionAdded(method: origin, totalActive: total) }
        }
        Task { await NotificationManager.shared.rescheduleAll(modelContext: modelContext) }
        WidgetSync.refresh(modelContext: modelContext)
        if let onFinish { onFinish() } else { dismiss() }
    }

    private var activeProfile: Profile? {
        if !selectedProfileID.isEmpty, let profile = profiles.first(where: { $0.id.uuidString == selectedProfileID }) {
            return profile
        }
        return profiles.first
    }
}

/// A tracked subscription whose imported charge differs from the saved price.
/// Selecting it accepts the new price; mirrors `ImportCandidateRow` styling.
private struct PriceUpdateRow: View {
    let update: PriceUpdate
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: Spacing.md) {
                BrandLogoView(subscription: update.subscription, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(update.subscription.name).font(.headline).lineLimit(1)
                    Text(update.transitionLabel).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: Spacing.sm)
                Text(update.newAmount.formatted(.currency(code: update.subscription.currencyCode)))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(update.newAmount > update.oldAmount ? Color.red : Color.green)
                    .lineLimit(1)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityValue(update.transitionLabel)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct ImportCandidateRow: View {
    let candidate: ImportCandidate
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: Spacing.md) {
                BrandLogoView(subscription: candidate.subscription, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(candidate.subscription.name).font(.headline).lineLimit(1)
                    if let subtitle = candidate.subtitle {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: Spacing.sm)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(candidate.subscription.priceLabel).font(.subheadline.weight(.semibold)).lineLimit(1)
                    if candidate.alreadyTracked {
                        Text("Already tracked").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
        .disabled(candidate.alreadyTracked)
        .opacity(candidate.alreadyTracked ? 0.55 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
