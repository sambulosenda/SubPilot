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
struct OnboardingView: View {
    /// Called when the user finishes or skips. The parent marks onboarding
    /// complete and reschedules reminders.
    var onFinish: () -> Void

    private enum Page: Int, CaseIterable { case welcome, privacy, add, reminders }

    @State private var page: Page = .welcome
    @State private var isRequesting = false

    @Environment(\.modelContext) private var modelContext
    @AppStorage("selectedProfileID") private var selectedProfileID = ""
    @State private var starterItems: [OnboardingStarter] = []
    @State private var selectedStarters: Set<String> = []
    @State private var didCommitStarters = false
    /// Currency for the starter prices + total — the device locale's, matching
    /// what `CatalogueProvider.makeDraft()` stamps on each new subscription.
    private let currencyCode = Locale.current.currency?.identifier ?? "GBP"

    var body: some View {
        VStack(spacing: 0) {
            skipBar

            // The starter step scrolls and fills the available height; the
            // info pages stay vertically centred between flexible spacers.
            if page == .add {
                content
                    .id(page)
                    .transition(.opacity)
            } else {
                Spacer(minLength: 0)
                content
                    .id(page)
                    .transition(.opacity)
                Spacer(minLength: 0)
            }

            PageDots(count: Page.allCases.count, index: page.rawValue)
                .padding(.bottom, Spacing.lg)

            actions
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.xl)
        }
        // Declarative haptic on page advance (preferred over UIKit generators).
        .sensoryFeedback(.selection, trigger: page)
        .task { if starterItems.isEmpty { starterItems = OnboardingStarter.load() } }
    }

    // MARK: - Chrome

    private var skipBar: some View {
        HStack {
            Spacer()
            // No Skip on the reminders page — it already offers "Not now".
            if page != .reminders {
                Button("Skip", action: onFinish)
                    .padding(.trailing, Spacing.md)
                    .padding(.top, Spacing.sm)
            }
        }
        .frame(height: 44)   // reserve space so the layout doesn't jump
    }

    @ViewBuilder
    private var content: some View {
        switch page {
        case .welcome:
            OnboardingPage(
                hero: .brandMark,
                tint: .accentColor,
                title: String(localized: "Track every subscription"),
                message: String(localized: "Keep all your recurring payments in one place and always know what's coming out next.")
            )
        case .privacy:
            OnboardingPage(
                hero: .symbol("lock.shield.fill"),
                tint: .green,
                title: String(localized: "Private by default"),
                message: String(localized: "Your subscriptions stay on your device. No account, no sign-up, and no sharing your bank.")
            )
        case .add:
            OnboardingStarterStep(
                items: starterItems,
                selected: $selectedStarters,
                currencyCode: currencyCode
            )
        case .reminders:
            OnboardingPage(
                hero: .symbol("bell.badge.fill"),
                tint: .orange,
                title: String(localized: "Never miss a renewal"),
                message: String(localized: "Get a reminder before each renewal or free-trial conversion, so you can cancel in time.")
            )
        }
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
                        .disabled(isRequesting)
                } else {
                    Button(action: advance) {
                        Text(continueLabel).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.extraLarge)
                }
            }
        }
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

// MARK: - Page layout

private struct OnboardingPage: View {
    /// The page's leading visual: either an SF Symbol or the animated brand mark.
    enum Hero {
        case symbol(String)
        case brandMark
    }

    let hero: Hero
    let tint: Color
    let title: String
    let message: String

    @State private var symbolPlayed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Spacing.lg) {
            heroView

            VStack(spacing: Spacing.sm) {
                Text(title)
                    .font(.largeTitle.bold())
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Spacing.xl)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var heroView: some View {
        switch hero {
        case .brandMark:
            // Reuse the shipped app mark (ring draws on, dot pops, soft sonar
            // idle) so the very first screen is unmistakably Recurra.
            RecurraMarkView(size: 120, style: .plain, tint: tint, looping: true)
                .accessibilityHidden(true)
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: 72))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                // Bounce once as the page settles in — native, no dependency.
                .symbolEffect(.bounce, options: .nonRepeating, value: symbolPlayed)
                .accessibilityHidden(true)
                .task {
                    guard !reduceMotion else { return }
                    try? await Task.sleep(for: .milliseconds(280))
                    symbolPlayed = true
                }
        }
    }
}

// MARK: - Page indicator

private struct PageDots: View {
    let count: Int
    let index: Int

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(i == index ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .animation(.smooth, value: index)
        // Surface progress to VoiceOver instead of hiding the dots outright.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(index + 1) of \(count)")
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
