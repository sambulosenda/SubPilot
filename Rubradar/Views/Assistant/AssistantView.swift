//
//  AssistantView.swift
//  Rubradar
//

import SwiftUI
import SwiftData

/// The Assistant, presented as a sheet from Home: an on-device chat that answers questions about the user's
/// subscriptions and spending. Grounding data is scoped to the selected profile,
/// matching the Home dashboard. Runs entirely via Apple Intelligence — private,
/// offline, no account.
struct AssistantView: View {
    /// Adds a Close button — set when presented as a sheet.
    var showsClose = false
    /// Opens a subscription the assistant mentioned. When set, each answer
    /// lists the subscriptions it names as tappable chips, so advice like
    /// "cancel X before it renews" leads somewhere instead of ending in text.
    var onOpen: ((Subscription) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Query(animation: .default) private var subscriptions: [Subscription]
    @Query(sort: \Profile.sortIndex, animation: .default) private var profiles: [Profile]
    @Environment(CurrencyService.self) private var currency
    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("preferredCurrencyCode") private var preferredCurrency =
        Locale.current.currency?.identifier ?? "GBP"
    /// Selected profile's UUID string; empty means "All Profiles".
    @AppStorage("selectedProfileID") private var selectedProfileID = ""

    @State private var chat = AssistantChat()
    @State private var input = ""
    @State private var confirmClear = false
    /// Cached availability so the view reacts when the user enables Apple
    /// Intelligence or the model finishes downloading (re-checked on foreground).
    @State private var availability = AssistantChat.availability

    private let suggestions = [
        String(localized: "How much do I spend per year?"),
        String(localized: "What's my most expensive subscription?"),
        String(localized: "What renews in the next 7 days?"),
        String(localized: "Where could I cut back?")
    ]

    /// True when launched for App Store screenshot capture (`-DemoAssistant`),
    /// which seeds a scripted conversation and shows the chat even where the
    /// on-device model can't run (e.g. the Simulator). DEBUG-only.
    private var isScreenshotDemo: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-DemoAssistant")
        #else
        false
        #endif
    }

    /// Subscriptions in the selected profile, matching Home's scoping.
    private var profileSubscriptions: [Subscription] {
        subscriptions.filter { $0.belongsToProfile(id: selectedProfileID) }
    }

    private var metrics: HomeMetrics {
        HomeMetrics.make(from: profileSubscriptions, preferred: preferredCurrency, rates: currency.rates)
    }

    private var profileName: String {
        guard !selectedProfileID.isEmpty,
              let profile = profiles.first(where: { $0.id.uuidString == selectedProfileID })
        else { return String(localized: "All Profiles") }
        return profile.name
    }

    /// Fresh grounding snapshot for the model, rebuilt each access so answers
    /// track edits made elsewhere in the app.
    private var context: String {
        AssistantContext.make(
            subscriptions: profileSubscriptions,
            metrics: metrics,
            profileName: profileName,
            preferred: preferredCurrency,
            rates: currency.rates
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if !purchases.isPro {
                    assistantLocked
                } else if availability == .available || isScreenshotDemo {
                    chatBody
                } else {
                    AssistantUnavailableView(availability: availability)
                }
            }
            .navigationTitle("Assistant")
            .toolbar {
                if showsClose {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
                if !chat.messages.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear", systemImage: "trash") { confirmClear = true }
                    }
                }
            }
            // One tap on a bin used to wipe the whole conversation.
            .confirmationDialog("Clear", isPresented: $confirmClear) {
                Button("Clear", role: .destructive) { chat.reset() }
            }
        }
        .onAppear {
            availability = AssistantChat.availability
            #if DEBUG
            if isScreenshotDemo { chat.seedScreenshotConversation() }
            #endif
            chat.prewarm(context: context)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { availability = AssistantChat.availability }
        }
    }

    // MARK: - Pro gate

    /// Shown to free users in place of the chat — the assistant is a Pro feature.
    private var assistantLocked: some View {
        ContentUnavailableView {
            Label("Assistant is a Pro feature", systemImage: "sparkles")
        } description: {
            Text("Ask about your spending and renewals — answered privately on your device.")
        } actions: {
            Button("Unlock Pro") { purchases.paywallContext = .assistant }
                .buttonStyle(.glassProminent)
        }
    }

    // MARK: - Chat

    private var chatBody: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.md) {
                    if chat.messages.isEmpty {
                        emptyState
                    } else {
                        ForEach(chat.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                            if message.role != .user, let onOpen {
                                MentionChips(subscriptions: mentioned(in: message.text), onOpen: onOpen)
                            }
                        }
                    }
                    if chat.isResponding {
                        TypingIndicator()
                    }
                    // Stable bottom anchor so scroll-to-end clears the input bar
                    // and works for both messages and the typing indicator.
                    Color.clear
                        .frame(height: 1)
                        .id(bottomID)
                }
                .padding(Spacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: chat.messages.count) { scrollToEnd(proxy) }
            .onChange(of: chat.isResponding) { scrollToEnd(proxy) }
        }
        .safeAreaInset(edge: .bottom) { inputBar }
    }

    private var emptyState: some View {
        VStack(alignment: .center, spacing: Spacing.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(.tint)
                .padding(.top, Spacing.xl)
                .accessibilityHidden(true)
            Text("Ask about your subscriptions")
                .font(.title3.weight(.semibold))
            Text("Spending, renewals, where to cut back — answered privately on your device.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: Spacing.sm) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button { send(suggestion) } label: {
                        Text(suggestion)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm + 2)
                            .background(Color.cardBackground, in: .rect(cornerRadius: Radius.card))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, Spacing.sm)
        }
        .frame(maxWidth: .infinity)
    }

    private var inputBar: some View {
        HStack(spacing: Spacing.sm) {
            TextField("Ask a question…", text: $input, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm + 2)
                .background(Color.cardBackground, in: .capsule)

            Button {
                send(input)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .symbolRenderingMode(.hierarchical)
            }
            .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chat.isResponding)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(.bar)
    }

    private let bottomID = "chat-bottom"

    /// Subscriptions an answer names, in the order they're listed on Home.
    /// Matched on the name alone, so it works on whatever the model wrote.
    private func mentioned(in text: String) -> [Subscription] {
        Array(subscriptions
            .filter { !$0.name.isEmpty && text.localizedCaseInsensitiveContains($0.name) }
            .prefix(4))
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(bottomID, anchor: .bottom)
        }
    }

    private func send(_ text: String) {
        let prompt = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !chat.isResponding else { return }
        input = ""
        let snapshot = context
        Task { await chat.send(prompt, context: snapshot) }
    }
}

// MARK: - Message bubble

private struct MessageBubble: View {
    let message: AssistantChat.Message

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: Spacing.xl) }
            Text(message.text)
                .font(.body)
                .foregroundStyle(foreground)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm + 2)
                .background(background, in: .rect(cornerRadius: Radius.card))
                .textSelection(.enabled)
                .accessibilityLabel("\(isUser ? "You said" : "Assistant said"): \(message.text)")
            if !isUser { Spacer(minLength: Spacing.xl) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private var background: AnyShapeStyle {
        if message.isError { return AnyShapeStyle(.red.opacity(0.15)) }
        return isUser ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.cardBackground)
    }

    private var foreground: Color {
        if message.isError { return .red }
        return isUser ? .white : .primary
    }
}

// MARK: - Typing indicator

/// The subscriptions an answer mentions, as buttons to their detail screens.
private struct MentionChips: View {
    let subscriptions: [Subscription]
    let onOpen: (Subscription) -> Void

    var body: some View {
        if !subscriptions.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                ForEach(subscriptions) { sub in
                    Button { onOpen(sub) } label: {
                        HStack(spacing: Spacing.sm) {
                            BrandLogoView(subscription: sub, size: 24)
                                .accessibilityHidden(true)
                            Text(verbatim: sub.name)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                            Image(systemName: "chevron.forward")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background(Color.cardBackground, in: .capsule)
                        .contentShape(.capsule)
                    }
                    .buttonStyle(.pressable)
                    .foregroundStyle(.primary)
                }
            }
        }
    }
}

private struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .frame(width: 7, height: 7)
                    .foregroundStyle(.secondary)
                    .opacity(animating ? 1 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever().delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.md)
        .background(Color.cardBackground, in: .rect(cornerRadius: Radius.card))
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { animating = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Thinking")
    }
}

// MARK: - Unavailable state

/// Shown when Apple Intelligence isn't usable, with a reason-specific hint.
struct AssistantUnavailableView: View {
    let availability: AssistantAvailability

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text(message)
        }
    }

    private var title: String {
        switch availability {
        case .modelNotReady: String(localized: "Getting ready")
        default: String(localized: "Assistant unavailable")
        }
    }

    private var symbol: String {
        availability == .modelNotReady ? "arrow.down.circle" : "sparkles.slash"
    }

    private var message: String {
        switch availability {
        case .deviceNotEligible:
            String(localized: "The on-device assistant needs an Apple Intelligence–capable device. Your other subscription features work as normal.")
        case .notEnabled:
            String(localized: "Turn on Apple Intelligence in Settings → Apple Intelligence & Siri to ask questions about your subscriptions.")
        case .modelNotReady:
            String(localized: "Apple Intelligence is still downloading its model. This finishes automatically — check back shortly.")
        case .unsupported, .available:
            String(localized: "The on-device assistant isn't available right now.")
        }
    }
}

#Preview("Pro") {
    AssistantView()
        .modelContainer(.preview)
        .environment(CurrencyService())
        .environment(PurchaseManager.preview(isPro: true))
}

#Preview("Locked") {
    AssistantView()
        .modelContainer(.preview)
        .environment(CurrencyService())
        .environment(PurchaseManager.preview(isPro: false))
}
