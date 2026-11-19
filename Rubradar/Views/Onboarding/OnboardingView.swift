//
//  OnboardingView.swift
//  Rubradar
//

import SwiftUI
import SwiftData

/// First-run onboarding (FR-20). A short, skippable intro that explains what
/// Rubradar does, reassures on privacy, shows how to add, and — crucially —
/// *primes* the notification permission before the system prompt appears
/// (FR-21). The hard ask is only fired from the reminders page; nothing here
/// blocks the user from reaching the app.
///
/// Layout is a stationary frame — top chrome, hero anchor, bottom well — with
/// only the middle content changing per page, so the flow reads as one composed
/// surface. See `OnboardingChrome` for the backdrop, hero slot, and transition.
struct OnboardingView: View {
    /// Called when the user finishes or skips. The parent marks onboarding
    /// complete and reschedules reminders.
    var onFinish: () -> Void

    // `fileprivate` so the page's content lives in one extension at the bottom
    // of this file rather than bloating the view body.
    /// Two pages. The flow used to open on two explanation pages (what the app
    /// does, that it's private) before the user could do anything; it now opens
    /// on the starter step, which shows both by letting them use it. The
    /// privacy promise rides along as a line on that step.
    fileprivate enum Page: Int, CaseIterable { case add, reminders }

    @State private var page: Page = .add
    @State private var isRequesting = false

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("selectedProfileID") private var selectedProfileID = ""
    @State private var starterItems: [OnboardingStarter] = []
    @State private var selectedStarters: Set<String> = []
    @State private var didCommitStarters = false
    /// Currency for the starter prices + total — the device locale's, matching
    /// what `CatalogueProvider.makeDraft()` stamps on each new subscription.
    private let currencyCode = Locale.current.currency?.identifier ?? "GBP"

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Insets rather than a VStack: the starter step's ScrollView then
            // scrolls *under* both bars and insets its own content, instead of
            // being clipped by them (the old layout hid the last chip row).
            .safeAreaInset(edge: .top, spacing: 0) { skipBar }
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomWell }
            .background { OnboardingBackdrop(tint: page.tint, phase: page.rawValue) }
            // Declarative haptic on page advance (preferred over UIKit generators).
            .sensoryFeedback(.selection, trigger: page)
            .task { if starterItems.isEmpty { starterItems = OnboardingStarter.load() } }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        Group {
            if page == .add {
                OnboardingStarterStep(
                    items: starterItems,
                    selected: $selectedStarters,
                    currencyCode: currencyCode
                )
            } else {
                infoPage
            }
        }
        // Identity is pinned to the page so the transition fires between them.
        .id(page)
        .transition(pageTransition)
    }

    /// A hero anchored above copy, optically centred and biased just clear of
    /// the bottom well.
    ///
    /// It scrolls, and the centring is a *minimum* height rather than a fixed
    /// one: at accessibility text sizes a fixed frame squeezed `Text` until the
    /// message truncated mid-sentence. `minHeight` centres the block while it
    /// fits and lets it grow — and scroll — once it doesn't.
    private var infoPage: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    OnboardingHero(kind: page.hero, tint: page.tint)

                    VStack(spacing: Spacing.sm) {
                        Text(page.title)
                            .font(.largeTitle.bold())
                            // Long localisations (de/pt-BR) otherwise run to
                            // three lines and crowd the message.
                            .minimumScaleFactor(0.8)
                            // Already display-sized: past this, a long word no
                            // longer fits one line and breaks mid-word
                            // ("subscrip-tion"). The message below still scales
                            // all the way.
                            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                        Text(page.message)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
                }
                .frame(
                    maxWidth: .infinity,
                    minHeight: max(0, proxy.size.height - bottomBias),
                    alignment: .center
                )
                .padding(.bottom, bottomBias)
                .accessibilityElement(children: .combine)
            }
            // At accessibility sizes the copy runs under the bottom bar, so say
            // so: show the indicator and flash it, rather than leave the user to
            // guess there is more.
            .scrollIndicators(dynamicTypeSize.isAccessibilitySize ? .visible : .hidden)
            .scrollIndicatorsFlash(onAppear: dynamicTypeSize.isAccessibilitySize)
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    /// Lifts the composition above the true centre so it doesn't sag toward the
    /// CTA. Dropped at accessibility sizes, where the copy needs every point.
    private var bottomBias: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 0 : 72
    }

    private var pageTransition: AnyTransition {
        // Reduce Motion: no travel, no defocus — a plain cross-fade.
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: AnyTransition(PageSlide(edge: .trailing)),
            removal: AnyTransition(PageSlide(edge: .leading))
        )
    }

    // MARK: - Chrome

    /// Progress leads, Skip trails. The indicator lives up here rather than
    /// above the CTA because the starter step scrolls *under* the bottom bar —
    /// down there the dots landed on top of brand logos.
    private var skipBar: some View {
        HStack {
            PageProgress(count: Page.allCases.count, index: page.rawValue)
            Spacer()
            // No Skip on the reminders page — it already offers "Not now".
            if page != .reminders {
                Button("Skip", action: onFinish)
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    // The pill stays small; the clear square behind it takes
                    // taps that land just outside, for a 44pt target.
                    .background {
                        Color.clear
                            .frame(minWidth: 60, minHeight: 44)
                            .contentShape(.rect)
                            .onTapGesture(perform: onFinish)
                            .accessibilityHidden(true)
                    }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .frame(height: 52)   // reserve space so the layout doesn't jump
    }

    private var bottomWell: some View {
        actions
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.md)
    }

    @ViewBuilder
    private var actions: some View {
        GlassEffectContainer(spacing: Spacing.md) {
            VStack(spacing: Spacing.md) {
                if page == .reminders {
                    Button(action: enableReminders) {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "bell.badge.fill")
                                .accessibilityHidden(true)
                            Text("Enable reminders")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.extraLarge)
                    .disabled(isRequesting)

                    Button("Not now", action: onFinish)
                        .controlSize(.large)
                        // ~20pt of text otherwise, under the main button.
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(.rect)
                        .disabled(isRequesting)
                } else {
                    Button(action: advance) {
                        Text(continueLabel)
                            .contentTransition(.numericText())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.extraLarge)
                }
            }
        }
        // The label counts up as starters are picked; animate it rather than
        // letting it snap between "Continue" and "Add 3 & Continue".
        .animation(.snappy(duration: 0.28), value: selectedStarters.count)
    }

    // MARK: - Actions

    private var continueLabel: String {
        if page == .add, !selectedStarters.isEmpty {
            return String(localized: "Add \(selectedStarters.count) & Continue")
        }
        return String(localized: "Continue")
    }

    private func advance() {
        if page == .add { commitStarters() }
        guard let next = Page(rawValue: page.rawValue + 1) else { onFinish(); return }
        withAnimation(.smooth) { page = next }
    }

    /// Persists the subscriptions selected on the starter step as real,
    /// profile-assigned records — seeding the app so the user never hits an empty
    /// list, and feeding the same add-funnel event as every other add path.
    private func commitStarters() {
        guard !didCommitStarters else { return }
        let chosen = starterItems.filter { selectedStarters.contains($0.id) }
        guard !chosen.isEmpty else { return }
        didCommitStarters = true

        ProfileSetup.ensureDefault(in: modelContext)
        let profiles = (try? modelContext.fetch(FetchDescriptor<Profile>())) ?? []
        let profile = profiles.first { $0.id.uuidString == selectedProfileID } ?? profiles.first

        for starter in chosen {
            let sub = starter.provider.makeDraft()
            sub.amount = starter.monthlyPrice
            sub.currencyCode = currencyCode
            sub.profile = profile
            modelContext.insert(sub)
        }

        let total = (try? modelContext.fetchCount(
            FetchDescriptor<Subscription>(predicate: #Predicate { !$0.isCancelled })
        )) ?? chosen.count
        for _ in chosen { Analytics.subscriptionAdded(method: .catalogue, totalActive: total) }

        Task { await NotificationManager.shared.rescheduleAll(modelContext: modelContext) }
        WidgetSync.refresh(modelContext: modelContext)
    }

    private func enableReminders() {
        isRequesting = true
        Task {
            // Hard ask — only ever fired here, after the primer above.
            _ = await NotificationManager.shared.requestAuthorization()
            isRequesting = false
            onFinish()
        }
    }
}

// MARK: - Page content

private extension OnboardingView.Page {
    var tint: Color {
        switch self {
        case .add: return .accentColor
        case .reminders: return .orange
        }
    }

    var hero: OnboardingHero.Kind {
        switch self {
        case .add: return .brandMark          // unused — the starter step draws its own
        case .reminders: return .symbol("bell.badge.fill")
        }
    }

    var title: String {
        switch self {
        case .add: return ""
        case .reminders: return String(localized: "Never miss a renewal")
        }
    }

    var message: String {
        switch self {
        case .add:
            return ""
        case .reminders:
            return String(localized: "Get a reminder before each renewal or free-trial conversion, so you can cancel in time.")
        }
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
