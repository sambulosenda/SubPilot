//
//  SubscriptionDetailView.swift
//  Rubradar
//

import SwiftUI
import SwiftData

struct SubscriptionDetailView: View {
    @Bindable var subscription: Subscription

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var stateChanged = false

    var body: some View {
        List {
            Section {
                header
                if let url = subscription.providerURL {
                    openProviderButton(url)
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Section("Cost") {
                detailRow("Amount", subscription.formattedAmount)
                detailRow("Billing", subscription.billingCycle == .custom
                          ? "Every \(subscription.customCycleDays ?? 30) days"
                          : subscription.billingCycle.label)
                detailRow("Per month (approx.)",
                          subscription.monthlyEquivalent.formatted(.currency(code: subscription.currencyCode)))
            }

            Section("Renewal") {
                detailRow("Next renewal",
                          subscription.projectedNextRenewal().formatted(.dateTime.day().month().year()))
                if subscription.isFreeTrial, let end = subscription.trialEndDate {
                    detailRow("Trial ends", end.formatted(.dateTime.day().month().year()))
                }
            }

            if !subscription.notes.isEmpty {
                Section("Notes") { Text(subscription.notes) }
            }

            Section { statusActions }
        }
        .navigationTitle(subscription.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showEdit = true }
            }
        }
        .sheet(isPresented: $showEdit) {
            SubscriptionFormView(mode: .edit(subscription))
        }
        .confirmationDialog("Delete this subscription?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { delete() }
        } message: {
            Text("This can't be undone.")
        }
        .sensoryFeedback(.selection, trigger: stateChanged)
    }

    private var header: some View {
        HStack(spacing: Spacing.md) {
            BrandLogoView(subscription: subscription, size: 56)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(subscription.name).font(.title3.weight(.semibold))
                HStack(spacing: Spacing.sm) {
                    Text(subscription.category.label).foregroundStyle(.secondary)
                    if subscription.isFreeTrial { TrialBadge() }
                    if subscription.isCancelled { CancelledBadge() }
                }
                .font(.subheadline)
            }
            Spacer()
        }
        .padding(.vertical, Spacing.sm)
        // One element so VoiceOver reads "Netflix, Streaming, Free trial" as a
        // unit instead of three fragments.
        .accessibilityElement(children: .combine)
    }

    /// Full-width glass CTA to the provider's site; universal links hand off to
    /// the provider's app when installed. Explicit HStack — a Label inside a
    /// full-width glass button mis-centers its content.
    private func openProviderButton(_ url: URL) -> some View {
        Button {
            openURL(url)
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "arrow.up.forward.app")
                Text("Open \(subscription.name)")
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xs)
        }
        .buttonStyle(.glass)
        .accessibilityHint("Opens \(url.host() ?? "the provider's website") in the app or browser")
    }

    private var statusActions: some View {
        Group {
            Button {
                subscription.isCancelled.toggle()
                subscription.updatedAt = Date()
                stateChanged.toggle()
                reschedule()
            } label: {
                Label(subscription.isCancelled ? "Mark as active" : "Mark as cancelled",
                      systemImage: subscription.isCancelled ? "arrow.clockwise.circle" : "xmark.circle")
            }

            Button {
                subscription.isFreeTrial.toggle()
                if subscription.isFreeTrial && subscription.trialEndDate == nil {
                    subscription.trialEndDate = subscription.nextRenewalDate
                }
                subscription.updatedAt = Date()
                stateChanged.toggle()
                reschedule()
            } label: {
                Label(subscription.isFreeTrial ? "Not a free trial" : "Mark as free trial",
                      systemImage: "gift")
            }

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
        // Read as "Amount, £9.99 a month" rather than two separate stops.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }

    private func delete() {
        modelContext.delete(subscription)
        reschedule()
        WidgetSync.refresh(modelContext: modelContext)
        dismiss()
    }

    private func reschedule() {
        let context = modelContext
        Task { await NotificationManager.shared.rescheduleAll(modelContext: context) }
    }
}

#Preview {
    NavigationStack {
        SubscriptionDetailView(subscription: SampleData.makeSamples()[0])
    }
    .modelContainer(.preview)
}
