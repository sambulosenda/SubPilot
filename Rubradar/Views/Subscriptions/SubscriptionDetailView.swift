//
//  SubscriptionDetailView.swift
//  Rubradar
//

import SwiftUI
import SwiftData

struct SubscriptionDetailView: View {
    @Bindable var subscription: Subscription
    /// Matched-source id + namespace for the row→detail zoom transition. Optional
    /// so the view still builds standalone (previews, deep links) without one.
    var transitionID: UUID? = nil
    var transitionNamespace: Namespace.ID? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var stateChanged = false

    var body: some View {
        // A ScrollView (not a List) so the teal hero can be a real scrolling
        // header that bleeds under the bar and *stretches* on overscroll. A List
        // clips its rows at the safe area, which is what forced every earlier
        // workaround (parallax slab / pinned header / overscroll gap). The grouped
        // info cards below are hand-built to match the system inset-grouped look.
        ScrollView {
            VStack(spacing: 0) {
                hero
                content
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        // Only bounce when content genuinely overflows — short subscriptions that
        // fit the screen shouldn't rubber-band. When it does bounce, the hero's
        // upward teal fill keeps the overscroll on-brand (no grey gap).
        .scrollBounceBehavior(.basedOnSize)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        // Opaque brand-teal bar: the hero tucks cleanly *under the bar* as it
        // scrolls (standard scroll-under-navbar) instead of overflowing a
        // transparent bar. Dark scheme keeps back + Edit white on teal.
        .toolbarBackground(Color.brand, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
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
        .zoomNavigationTransition(id: transitionID, in: transitionNamespace)
    }

    // MARK: - Hero

    /// Branded hero banner: full-bleed teal gradient with logo + name + status in
    /// white. Its background is two layers (see `.background` below) so the teal
    /// stretches upward on pull-down instead of revealing the grey scroll
    /// background, and scrolls *with* the hero so there's no parallax.
    private var hero: some View {
        VStack(spacing: Spacing.sm) {
            BrandLogoView(subscription: subscription, size: 76)
                .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
            VStack(spacing: Spacing.xs) {
                Text(subscription.name)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                HStack(spacing: Spacing.sm) {
                    Text(subscription.category.label)
                        .foregroundStyle(.white.opacity(0.85))
                    if subscription.isFreeTrial { heroBadge("Trial", a11y: "Free trial") }
                    if subscription.isCancelled { heroBadge("Cancelled", a11y: "Cancelled") }
                }
                .font(.subheadline)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.lg)
        // Layer 1 (front): a vertical brand gradient, sized to the hero band.
        // Top edge stays pure `.brand` so it meets Layer 2's solid fill with no
        // seam; it just deepens gently downward (a diagonal angle made the top
        // corners read as two distinct greens).
        .background(alignment: .bottom) {
            LinearGradient(colors: [.brand, .brandDeep],
                           startPoint: .top,
                           endPoint: .bottom)
        }
        // Layer 2 (back): a tall solid-brand fill anchored to the hero's bottom,
        // extending far upward. It colours the top overscroll region (and behind
        // the bar) teal and moves with the hero — so pull-down reveals teal, not
        // grey, with no fixed slab to parallax against.
        .background(alignment: .bottom) {
            Color.brand
                .frame(height: 1200)
                .ignoresSafeArea(edges: .top)
        }
        // One element so VoiceOver reads "Netflix, Streaming, Free trial" as a
        // unit instead of three fragments.
        .accessibilityElement(children: .combine)
    }

    /// White-on-translucent status pill, legible on the teal hero (the standard
    /// `TrialBadge`/`CancelledBadge` are tuned for light cards).
    private func heroBadge(_ text: LocalizedStringKey, a11y: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 2)
            .background(.white.opacity(0.22), in: .capsule)
            .foregroundStyle(.white)
            .accessibilityLabel(a11y)
            .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Content

    private var content: some View {
        VStack(spacing: Spacing.lg) {
            if let url = subscription.providerURL {
                openProviderButton(url)
            }

            card("Cost") {
                detailRow("Amount", subscription.formattedAmount)
                rowDivider
                detailRow("Billing", subscription.billingCycle == .custom
                          ? "Every \(subscription.customCycleDays ?? 30) days"
                          : subscription.billingCycle.label)
                rowDivider
                detailRow("Per month (approx.)",
                          subscription.monthlyEquivalent.formatted(.currency(code: subscription.currencyCode)))
            }

            if !subscription.priceHistory.isEmpty {
                card("Price history") {
                    let history = subscription.priceHistory
                    ForEach(Array(history.enumerated()), id: \.element.id) { index, change in
                        priceChangeRow(change)
                        if index < history.count - 1 { rowDivider }
                    }
                }
            }

            card("Renewal") {
                detailRow("Next renewal",
                          subscription.projectedNextRenewal().formatted(.dateTime.day().month().year()))
                if subscription.isFreeTrial, let end = subscription.trialEndDate {
                    rowDivider
                    detailRow("Trial ends", end.formatted(.dateTime.day().month().year()))
                }
            }

            if !subscription.notes.isEmpty {
                card("Notes") {
                    Text(subscription.notes)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, 14)
                }
            }

            card { statusActions }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.xl)
    }

    /// Grouped card: an optional secondary header above a rounded surface that
    /// holds the rows — mirrors the system inset-grouped section look.
    @ViewBuilder
    private func card(_ header: LocalizedStringKey? = nil,
                      @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let header {
                Text(header)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, Spacing.md)
            }
            VStack(spacing: 0) { content() }
                .frame(maxWidth: .infinity)
                .background(Color.cardBackground, in: .rect(cornerRadius: Radius.card))
        }
    }

    /// Leading-inset hairline between rows, matching grouped-list separators.
    private var rowDivider: some View {
        Divider().padding(.leading, Spacing.md)
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
        VStack(spacing: 0) {
            actionRow(subscription.isCancelled ? "Mark as active" : "Mark as cancelled",
                      systemImage: subscription.isCancelled ? "arrow.clockwise.circle" : "xmark.circle") {
                // Animate so the header badge and this label's icon morph
                // rather than snap; the model write itself is non-visual.
                withAnimation(.snappy) { subscription.isCancelled.toggle() }
                subscription.updatedAt = Date()
                stateChanged.toggle()
                reschedule()
            }
            rowDivider
            actionRow(subscription.isFreeTrial ? "Not a free trial" : "Mark as free trial",
                      systemImage: "gift") {
                withAnimation(.snappy) {
                    subscription.isFreeTrial.toggle()
                    if subscription.isFreeTrial && subscription.trialEndDate == nil {
                        subscription.trialEndDate = subscription.nextRenewalDate
                    }
                }
                subscription.updatedAt = Date()
                stateChanged.toggle()
                reschedule()
            }
            rowDivider
            actionRow("Delete", systemImage: "trash", role: .destructive) {
                showDeleteConfirm = true
            }
        }
    }

    /// A tappable action row inside a card. Teal (accent) by default, red for the
    /// destructive role — matching how the buttons read inside a grouped List.
    private func actionRow(_ title: LocalizedStringKey, systemImage: String,
                           role: ButtonRole? = nil,
                           action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            Label(title, systemImage: systemImage)
                .contentTransition(.symbolEffect(.replace))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 14)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(role == .destructive ? Color.red : Color.accentColor)
    }

    /// One price movement: date on the left, "£10.99 → £12.99" plus a tinted
    /// percentage on the right (red rise, green drop).
    private func priceChangeRow(_ change: PriceChange) -> some View {
        HStack {
            Text(change.changedAt.formatted(.dateTime.day().month().year()))
                .foregroundStyle(.secondary)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(change.transitionLabel)
                if let relative = change.relativeChange {
                    Text(relative.formatted(.percent.precision(.fractionLength(0...1)).sign(strategy: .always())))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(change.newAmount > change.oldAmount ? Color.red : Color.green)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(change.changedAt.formatted(.dateTime.day().month().year())))
        .accessibilityValue(change.transitionLabel)
    }

    private func detailRow(_ label: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 14)
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
