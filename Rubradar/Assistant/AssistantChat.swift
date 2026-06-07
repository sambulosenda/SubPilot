//
//  AssistantChat.swift
//  Rubradar
//

import Foundation
import Observation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Whether the on-device assistant can run right now, with a reason when it can't
/// so the UI can explain how to enable it.
enum AssistantAvailability: Equatable {
    case available
    case deviceNotEligible
    case notEnabled
    case modelNotReady
    case unsupported
}

/// Conversation state and on-device inference for the assistant tab.
///
/// Wraps Apple's Foundation Models (Apple Intelligence). One `LanguageModelSession`
/// is kept per data snapshot so multi-turn memory works; it's rebuilt when the
/// grounding data changes so answers never go stale. Everything runs on-device —
/// no network, no API keys — which keeps the app's "no data collected" posture.
@MainActor
@Observable
final class AssistantChat {
    struct Message: Identifiable {
        enum Role { case user, assistant }
        let id = UUID()
        let role: Role
        var text: String
        var isError = false
    }

    private(set) var messages: [Message] = []
    private(set) var isResponding = false

    #if canImport(FoundationModels)
    private var session: LanguageModelSession?
    private var groundingContext: String?
    #endif

    /// Live availability of the on-device model. `nonisolated` so views can seed
    /// state from it outside the main actor; it only reads a value-type status.
    nonisolated static var availability: AssistantAvailability {
        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible: return .deviceNotEligible
            case .appleIntelligenceNotEnabled: return .notEnabled
            case .modelNotReady: return .modelNotReady
            @unknown default: return .unsupported
            }
        @unknown default:
            return .unsupported
        }
        #else
        return .unsupported
        #endif
    }

    /// Warms the model on tab appearance to cut first-response latency.
    func prewarm(context: String) {
        #if canImport(FoundationModels)
        guard Self.availability == .available else { return }
        ensureSession(context: context)
        session?.prewarm()
        #endif
    }

    /// Sends a user turn and appends the assistant's reply. `context` is the
    /// freshly built data snapshot; the session is rebuilt if it changed.
    func send(_ prompt: String, context: String) async {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isResponding else { return }

        messages.append(Message(role: .user, text: trimmed))
        isResponding = true
        defer { isResponding = false }

        #if canImport(FoundationModels)
        ensureSession(context: context)
        guard let session else {
            appendError()
            return
        }
        do {
            let response = try await session.respond(to: trimmed)
            messages.append(Message(role: .assistant, text: response.content))
        } catch {
            appendError()
        }
        #else
        appendError()
        #endif
    }

    /// Clears the conversation and forgets the session/transcript.
    func reset() {
        messages.removeAll()
        #if canImport(FoundationModels)
        session = nil
        groundingContext = nil
        #endif
    }

    #if canImport(FoundationModels)
    /// Creates the session if missing or rebuilds it when the grounding data
    /// changed, so the model always answers against current subscriptions.
    private func ensureSession(context: String) {
        guard session == nil || context != groundingContext else { return }
        session = LanguageModelSession(instructions: Self.instructions(context: context))
        groundingContext = context
    }

    private static func instructions(context: String) -> String {
        """
        You are the SubPilot Assistant, a concise, friendly helper inside a \
        subscription-tracking app. You answer the user's questions about their own \
        subscriptions and spending, using ONLY the DATA section below.

        Rules:
        - Ground every answer in the DATA. Never invent subscriptions, prices, or dates that aren't listed.
        - For total monthly or yearly spend, use the TOTALS verbatim. Do not recompute them.
        - Amounts are in the user's preferred currency unless a line says "(own currency)".
        - Be brief and direct: a short sentence or a tight list beats a paragraph. Keep the currency symbols shown.
        - If the DATA doesn't contain the answer, say so plainly. If asked something unrelated to subscriptions or money, steer back politely.
        - You cannot change anything: you can't add, edit, cancel, or open subscriptions. If asked, explain that they can do it from the Home or subscription screens.

        DATA:
        \(context)
        """
    }
    #endif

    private func appendError() {
        messages.append(Message(
            role: .assistant,
            text: "Sorry — I couldn't answer that just now. Please try again.",
            isError: true
        ))
    }
}
