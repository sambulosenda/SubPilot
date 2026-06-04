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
    var footer: String = "Pick the subscriptions you'd like to track."
    var emptyTitle: String = "Nothing found"
    var emptyMessage: String = "We couldn't find any subscriptions to add."
    /// Called after a successful add. When nil, the view dismisses itself; supply
    /// this when the review is nested so the whole flow can close.
    var onFinish: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Profile.sortIndex) private var profiles: [Profile]
    @AppStorage("selectedProfileID") private var selectedProfileID = ""
    @State private var selected: Set<String>
    @State private var didAdd = false

    init(candidates: [ImportCandidate],
         footer: String = "Pick the subscriptions you'd like to track.",
         emptyTitle: String = "Nothing found",
         emptyMessage: String = "We couldn't find any subscriptions to add.",
         onFinish: (() -> Void)? = nil) {
        self.candidates = candidates
        self.footer = footer
        self.emptyTitle = emptyTitle
        self.emptyMessage = emptyMessage
        self.onFinish = onFinish
        _selected = State(initialValue: Set(candidates.filter { $0.isPreselected && !$0.alreadyTracked }.map(\.id)))
    }

    var body: some View {
        Group {
            if candidates.isEmpty {
                ContentUnavailableView(emptyTitle, systemImage: "magnifyingglass", description: Text(emptyMessage))
            } else {
                List {
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
        .safeAreaInset(edge: .bottom) {
            if !selected.isEmpty {
                Button {
                    addSelected()
                } label: {
                    Text("Add \(selected.count) subscription\(selected.count == 1 ? "" : "s")")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.extraLarge)
                .padding()
            }
        }
        .sensoryFeedback(.success, trigger: didAdd)
    }

    private func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    private func addSelected() {
        let profile = activeProfile
        for candidate in candidates where selected.contains(candidate.id) {
            modelContext.insert(candidate.subscription)
            candidate.subscription.profile = profile
        }
        try? modelContext.save()
        didAdd = true
        Task { await NotificationManager.shared.rescheduleAll(modelContext: modelContext) }
        if let onFinish { onFinish() } else { dismiss() }
    }

    private var activeProfile: Profile? {
        if !selectedProfileID.isEmpty, let profile = profiles.first(where: { $0.id.uuidString == selectedProfileID }) {
            return profile
        }
        return profiles.first
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
