//
//  OnboardingView.swift
//  Rubradar
//

import SwiftUI

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

    var body: some View {
        VStack(spacing: 0) {
            skipBar

            Spacer(minLength: 0)

            content
                .id(page)
                .transition(.opacity)

            Spacer(minLength: 0)

            PageDots(count: Page.allCases.count, index: page.rawValue)
                .padding(.bottom, Spacing.lg)

            actions
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.xl)
        }
        // Declarative haptic on page advance (preferred over UIKit generators).
        .sensoryFeedback(.selection, trigger: page)
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
                symbol: "rectangle.stack.badge.plus",
                tint: .accentColor,
                title: "Track every subscription",
                message: "Keep all your recurring payments in one place and always know what's coming out next."
            )
        case .privacy:
            OnboardingPage(
                symbol: "lock.shield.fill",
                tint: .green,
                title: "Private by default",
                message: "Your subscriptions stay on your device. No account, no sign-up, and no sharing your bank."
            )
        case .add:
            OnboardingPage(
                symbol: "doc.viewfinder",
                tint: .blue,
                title: "Add in seconds",
                message: "Pick from the catalogue or scan a receipt — we read it on your device and fill in the details."
            )
        case .reminders:
            OnboardingPage(
                symbol: "bell.badge.fill",
                tint: .orange,
                title: "Never miss a renewal",
                message: "Get a reminder before each renewal or free-trial conversion, so you can cancel in time."
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
                        Text("Continue").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.extraLarge)
                }
            }
        }
    }

    // MARK: - Actions

    private func advance() {
        guard let next = Page(rawValue: page.rawValue + 1) else { onFinish(); return }
        withAnimation(.smooth) { page = next }
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
    let symbol: String
    let tint: Color
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: symbol)
                .font(.system(size: 72))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .accessibilityHidden(true)

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
