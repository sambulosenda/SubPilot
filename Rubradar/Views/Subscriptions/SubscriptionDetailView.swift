//
//  SubscriptionDetailView.swift
//  Rubradar
//

import SwiftUI
import SwiftData
import StoreKit

struct SubscriptionDetailView: View {
    @Bindable var subscription: Subscription
    /// Matched-source id + namespace for the row→detail zoom transition. Optional
    /// so the view still builds standalone (previews, deep links) without one.
    var transitionID: UUID? = nil
    var transitionNamespace: Namespace.ID? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @Environment(CurrencyService.self) private var currency
    @AppStorage("preferredCurrencyCode") private var preferredCurrency =
        Locale.current.currency?.identifier ?? "GBP"

    /// The monthly cost, in the preferred currency when a rate is known.
    /// `nil` when it would only repeat the Amount row.
    private var perMonthText: String? {
        let native = subscription.currencyCode
        if native != preferredCurrency,
           let converted = currency.rates.convert(subscription.monthlyEquivalent,
                                                  from: native, to: preferredCurrency) {
            return converted.formatted(.currency(code: preferredCurrency))
        }
        guard subscription.billingCycle != .monthly else { return nil }
        return subscription.monthlyEquivalent.formatted(.currency(code: native))
    }

    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var showCancelHelper = false
    @State private var stateChanged = false
    /// Drives the "Saved £X a year" moment after a guided cancel.
    @State private var savedMessage: String?

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
        // No bar background: Back and Edit are glass buttons floating over the
        // hero and then over the content, as on every other iOS 26 screen. The
        // old opaque teal bar was the one painted toolbar in the app.
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showEdit = true }
            }
        }
        .sheet(isPresented: $showEdit) {
            SubscriptionFormView(mode: .edit(subscription))
        }
        .sheet(isPresented: $showCancelHelper) {
            CancelHelperView(subscription: subscription) {
                withAnimation(.snappy) { subscription.isCancelled = true }
                subscription.updatedAt = Date()
                stateChanged.toggle()
                reschedule()
                WidgetSync.refresh(modelContext: modelContext)
                // In the preferred currency when a rate is known, so it
                // matches the "You've cut" total this adds to on Home.
                let nativeYearly = subscription.monthlyEquivalent * 12
                let yearly: String
                if subscription.currencyCode != preferredCurrency,
                   let converted = currency.rates.convert(nativeYearly,
                                                          from: subscription.currencyCode,
                                                          to: preferredCurrency) {
                    yearly = converted.formatted(.currency(code: preferredCurrency))
                } else {
                    yearly = nativeYearly.formatted(.currency(code: subscription.currencyCode))
                }
                withAnimation(.snappy) { savedMessage = String(localized: "Saved \(yearly) a year") }
                requestReviewAfterSaving()
            }
        }
        .successHUD($savedMessage)
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
            BrandLogoView(subscription: subscription, size: 60)
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
        // A band, not a third of the screen: the first card of facts should
        // sit well above the fold.
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.md)
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
                // Only when it says something the Amount row doesn't: a
                // monthly subscription in the user's own currency had the
                // same figure twice. In another currency it shows the
                // converted cost, the number Home's total is built from.
                if let perMonth = perMonthText {
                    rowDivider
                    detailRow("Per month (approx.)", perMonth)
                }
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
                if let deadline = subscription.cancelDeadline() {
                    rowDivider
                    detailRow("Cancel by", deadline.date.formatted(.dateTime.day().month().year()))
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

            // On its own, below everything: the one action that can't be
            // undone shouldn't share a card with "Mark as free trial".
            card {
                actionRow("Delete", systemImage: "trash", role: .destructive) {
                    showDeleteConfirm = true
                }
            }
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
            if subscription.isCancelled {
                actionRow("Mark as active", systemImage: "arrow.clockwise.circle") {
                    // Animate so the header badge and this label's icon morph
                    // rather than snap; the model write itself is non-visual.
                    withAnimation(.snappy) { subscription.isCancelled = false }
                    subscription.updatedAt = Date()
                    stateChanged.toggle()
                    reschedule()
                }
            } else {
                // Guided flow instead of a bare state flip: the sheet links to
                // the provider's cancel page (or Apple's subscription manager)
                // and marks the sub cancelled once the user is done.
                actionRow("Cancel subscription…", systemImage: "xmark.circle") {
                    showCancelHelper = true
                }
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

    /// The app just saved the user money — the best moment it has to ask for
    /// a rating. Waits for the HUD to clear; `ReviewPrompter` applies the same
    /// gates and 120-day spacing as the post-add prompt, so the two never
    /// stack. Counts every tracked subscription: the one just cancelled still
    /// shows the user is invested.
    private func requestReviewAfterSaving() {
        let tracked = (try? modelContext.fetchCount(FetchDescriptor<Subscription>())) ?? 0
        Task {
            try? await Task.sleep(for: .seconds(2))
            ReviewPrompter.maybePrompt(activeCount: tracked) { requestReview() }
        }
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
