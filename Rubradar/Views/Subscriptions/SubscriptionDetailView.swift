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

    /// The headline figure scales with Dynamic Type from a 52pt base.
    @ScaledMetric(relativeTo: .largeTitle) private var figureSize: CGFloat = 52

    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var showCancelHelper = false
    @State private var stateChanged = false
    /// Drives the "Saved £X a year" moment after a guided cancel.
    @State private var savedMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                header
                verdictCard
                costCard
                if !subscription.priceHistory.isEmpty {
                    card("Price history") {
                        let history = subscription.priceHistory
                        ForEach(Array(history.enumerated()), id: \.element.id) { index, change in
                            priceChangeRow(change)
                            if index < history.count - 1 { rowDivider }
                        }
                    }
                }
                remindersCard
                if !subscription.notes.isEmpty {
                    card("Notes") {
                        Text(subscription.notes)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, 14)
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.lg)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .scrollBounceBehavior(.basedOnSize)
        // The one decision this screen exists for sits under the thumb, always
        // visible, instead of a teal row at the bottom of a scroll.
        .safeAreaInset(edge: .bottom) { actionBar }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showEdit = true }
            }
            // Rare actions live here so the screen only shows the common ones.
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        toggleFreeTrial()
                    } label: {
                        Label(subscription.isFreeTrial ? "Not a free trial" : "Mark as free trial",
                              systemImage: "gift")
                    }
                    Divider()
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("More")
            }
        }
        .sheet(isPresented: $showEdit) {
            SubscriptionFormView(mode: .edit(subscription))
        }
        .sheet(isPresented: $showCancelHelper) {
            CancelHelperView(subscription: subscription) {
                withAnimation(.snappy) { subscription.isCancelled = true }
                subscription.cancelledAt = Date()
                subscription.updatedAt = Date()
                stateChanged.toggle()
                reschedule()
                WidgetSync.refresh(modelContext: modelContext)
                withAnimation(.snappy) { savedMessage = String(localized: "Saved \(yearlyText) a year") }
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

    // MARK: - Money

    /// Monthly cost in the preferred currency when a rate is known, otherwise
    /// in the subscription's own. The same figure Home's total is built from.
    private var monthly: (amount: Decimal, code: String) {
        let native = subscription.currencyCode
        if native != preferredCurrency,
           let converted = currency.rates.convert(subscription.monthlyEquivalent,
                                                  from: native, to: preferredCurrency) {
            return (converted, preferredCurrency)
        }
        return (subscription.monthlyEquivalent, native)
    }

    private var monthlyText: String {
        monthly.amount.formatted(.currency(code: monthly.code))
    }

    private var yearlyText: String {
        (monthly.amount * 12).formatted(.currency(code: monthly.code))
    }

    private var billingText: String {
        subscription.billingCycle == .custom
            ? String(localized: "Every \(subscription.customCycleDays ?? 30) days")
            : subscription.billingCycle.label
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Spacing.md) {
            // On a card-coloured tile: transparent black marks (ChatGPT,
            // Netflix) vanish against the black page background in dark mode.
            BrandLogoView(subscription: subscription, size: 52)
                .background(Color.cardBackground,
                            in: .rect(cornerRadius: 52 * 0.28, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(subscription.name)
                    .font(.title2.weight(.bold))
                    .lineLimit(2)
                HStack(spacing: Spacing.sm) {
                    Text(subscription.category.label)
                        .foregroundStyle(.secondary)
                    if subscription.isFreeTrial { TrialBadge() }
                    if subscription.isCancelled { CancelledBadge() }
                }
                .font(.subheadline)
            }
            Spacer(minLength: 0)
        }
        // "Netflix, Streaming, Free trial" as one VoiceOver stop.
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Verdict

    /// What the screen leads with: the next thing that will happen to this
    /// subscription and what it costs, worked out from its state.
    private struct Verdict {
        var title: String
        var systemImage: String
        var tint: Color
        var figure: String
        var caption: String
        /// How far through the trial or billing period today is, 0...1.
        var progress: Double?
    }

    private var verdict: Verdict {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)

        if subscription.isCancelled {
            let caption = subscription.cancelledAt.map {
                String(localized: "Cancelled \($0.formatted(.dateTime.day().month())) · was \(subscription.priceLabel)")
            } ?? String(localized: "Was \(subscription.priceLabel)")
            return Verdict(title: String(localized: "Saving \(yearlyText) a year"),
                           systemImage: "scissors",
                           tint: .green,
                           figure: yearlyText,
                           caption: caption,
                           progress: nil)
        }

        let renewal = subscription.projectedNextRenewal(asOf: now, calendar: calendar)
        let days = calendar.dateComponents([.day], from: today,
                                           to: calendar.startOfDay(for: renewal)).day ?? 0
        let dateText = renewal.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))

        if subscription.isFreeTrial, let end = subscription.trialEndDate {
            let title: String = switch days {
            case ...0: String(localized: "Trial ends today")
            case 1: String(localized: "Trial ends tomorrow")
            default: inflected("Trial ends in ^[\(days) day](inflect: true)")
            }
            return Verdict(title: title,
                           systemImage: "bell.fill",
                           tint: .attention,
                           figure: subscription.formattedAmount,
                           caption: "\(dateText) · \(String(localized: "then \(subscription.priceLabel)"))",
                           progress: trialProgress(end: end, now: now))
        }

        // Where the provider needs notice, the cancel-by date is the real
        // deadline; lead with it once it is close.
        if let deadline = subscription.cancelDeadline(asOf: now, calendar: calendar),
           deadline.needsNotice, deadline.daysLeft <= 14 {
            let date = deadline.date.formatted(.dateTime.day().month())
            return Verdict(title: String(localized: "Cancel by \(date)"),
                           systemImage: "exclamationmark.circle.fill",
                           tint: .attention,
                           figure: subscription.formattedAmount,
                           caption: "\(dateText) · \(billingText)",
                           progress: billingProgress(now: now, calendar: calendar))
        }

        let title: String = switch days {
        case ...0: String(localized: "Renews today")
        case 1: String(localized: "Renews tomorrow")
        default: inflected("Renews in ^[\(days) day](inflect: true)")
        }
        return Verdict(title: title,
                       systemImage: "arrow.trianglehead.2.clockwise",
                       tint: .brand,
                       figure: subscription.formattedAmount,
                       caption: "\(dateText) · \(billingText)",
                       progress: billingProgress(now: now, calendar: calendar))
    }

    /// `String(localized:)` leaves `^[…](inflect: true)` markup as literal
    /// text; the attributed initialiser applies the grammar agreement.
    private func inflected(_ resource: LocalizedStringResource) -> String {
        String(AttributedString(localized: resource).characters)
    }

    private func fraction(from start: Date, to end: Date, now: Date) -> Double? {
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return nil }
        return min(max(now.timeIntervalSince(start) / total, 0), 1)
    }

    /// The trial's start isn't stored, so it is taken as the day the
    /// subscription was added. Only shown once that is at least a day ago:
    /// a trial added today would always read as an empty bar.
    private func trialProgress(end: Date, now: Date) -> Double? {
        guard now.timeIntervalSince(subscription.createdAt) >= 86_400 else { return nil }
        return fraction(from: subscription.createdAt, to: end, now: now)
    }

    /// Progress through the current billing period: the last renewal before
    /// today to the next one.
    private func billingProgress(now: Date, calendar: Calendar) -> Double? {
        let cycle = subscription.billingCycle
        let anchor = subscription.nextRenewalDate
        let next = cycle.firstOccurrence(onOrAfter: calendar.startOfDay(for: now), anchor: anchor,
                                         customDays: subscription.customCycleDays, calendar: calendar)
        let previous = cycle.date(byAddingCycles: next.index - 1, to: anchor,
                                  customDays: subscription.customCycleDays, calendar: calendar)
        return fraction(from: previous, to: next.date, now: now)
    }

    private var verdictCard: some View {
        let v = verdict
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: v.systemImage)
                    .accessibilityHidden(true)
                Text(v.title)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(v.tint)
            .contentTransition(.numericText())

            Text(v.figure)
                .font(.system(size: figureSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())

            Text(v.caption)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let progress = v.progress {
                ProgressView(value: progress)
                    .tint(v.tint)
                    .padding(.top, Spacing.xs)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(Color.cardBackground, in: .rect(cornerRadius: Radius.card + 8))
        .accessibilityElement(children: .combine)
        .animation(.snappy, value: subscription.isCancelled)
        .animation(.snappy, value: subscription.isFreeTrial)
    }

    // MARK: - Cost

    /// Monthly, yearly and cycle side by side, so the yearly size of a
    /// "small" monthly charge is visible without arithmetic.
    private var costCard: some View {
        HStack(spacing: 0) {
            stat("Per month", monthlyText)
            Divider()
            stat("Per year", yearlyText)
            Divider()
            stat("Billing", billingText)
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.cardBackground, in: .rect(cornerRadius: Radius.card))
    }

    private func stat(_ label: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.weight(.semibold))
                .fontDesign(.rounded)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }

    // MARK: - Reminders

    private var remindersCard: some View {
        card {
            detailRow("Remind me", reminderText)
            rowDivider
            detailRow("Notice period", subscription.noticePeriod?.label ?? String(localized: "None"))
            if let deadline = subscription.cancelDeadline(), deadline.needsNotice {
                rowDivider
                detailRow("Cancel by", deadline.date.formatted(.dateTime.day().month().year()))
            }
        }
    }

    private var reminderText: String {
        ReminderLead.options.first { $0.days == subscription.reminderLeadDays }?.label
            ?? inflected("^[\(subscription.reminderLeadDays) day](inflect: true) before")
    }

    // MARK: - Actions

    private var actionBar: some View {
        GlassEffectContainer(spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                primaryButton
                if let url = subscription.providerURL, !subscription.isCancelled {
                    Button {
                        openURL(url)
                    } label: {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.body.weight(.semibold))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .controlSize(.extraLarge)
                    .accessibilityLabel("Open \(subscription.name)")
                    .accessibilityHint("Opens \(url.host() ?? "the provider's website") in the app or browser")
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.sm)
    }

    /// Explicit HStack labels: a Label inside a full-width glass button
    /// mis-centres its content.
    @ViewBuilder
    private var primaryButton: some View {
        if subscription.isCancelled {
            Button {
                withAnimation(.snappy) { subscription.isCancelled = false }
                subscription.cancelledAt = nil
                subscription.updatedAt = Date()
                stateChanged.toggle()
                reschedule()
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "arrow.clockwise.circle")
                        .accessibilityHidden(true)
                    Text("Mark as active")
                }
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .controlSize(.extraLarge)
        } else {
            // Guided flow: the sheet links to the provider's cancel page (or
            // Apple's subscription manager) and marks it cancelled when done.
            Button {
                showCancelHelper = true
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "xmark.circle")
                        .accessibilityHidden(true)
                    Text(subscription.isFreeTrial ? "Cancel before it charges" : "Cancel subscription…")
                }
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(.brand)
            .controlSize(.extraLarge)
        }
    }

    private func toggleFreeTrial() {
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

    // MARK: - Building blocks

    /// Grouped card: an optional secondary header above a rounded surface that
    /// holds the rows, matching the system inset-grouped look.
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
        // Read as "Notice period, 1 month" rather than two separate stops.
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

    /// The app just saved the user money: the best moment it has to ask for
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
