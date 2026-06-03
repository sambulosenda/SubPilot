//
//  IntelligenceReceiptParser.swift
//  Rubradar
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels

/// On-device LLM parser using Apple's Foundation Models (Apple Intelligence).
/// Available only on capable devices; callers fall back to the heuristic parser
/// when `isAvailable` is false. Nothing leaves the device.
struct IntelligenceReceiptParser {

    @Generable
    struct Parsed {
        @Guide(description: "The subscription service or provider name, e.g. Netflix. Empty if unknown.")
        var provider: String
        @Guide(description: "The recurring charge amount as a number, e.g. 9.99. Zero if unknown.")
        var amount: Double
        @Guide(description: "ISO 4217 currency code such as GBP, USD or EUR. Empty if unknown.")
        var currencyCode: String
        @Guide(description: "Billing frequency: one of weekly, monthly, yearly. Empty if unknown.")
        var billingCycle: String
        @Guide(description: "Next renewal or billing date as yyyy-MM-dd. Empty if unknown.")
        var nextRenewalDate: String
        @Guide(description: "True only if the receipt mentions a free trial.")
        var isFreeTrial: Bool
    }

    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    func parse(_ text: String) async throws -> ReceiptDraft {
        let session = LanguageModelSession(
            instructions: """
            You extract subscription billing details from receipt or confirmation-email text.
            Only use information that is actually present. Leave a field empty (or zero) when unsure.
            """
        )
        let response = try await session.respond(
            to: "Extract the subscription details from this text:\n\n\(text)",
            generating: Parsed.self
        )
        return Self.draft(from: response.content)
    }

    static func draft(from p: Parsed) -> ReceiptDraft {
        var draft = ReceiptDraft()
        let provider = p.provider.trimmingCharacters(in: .whitespacesAndNewlines)
        if !provider.isEmpty { draft.providerName = provider }
        if p.amount > 0 { draft.amount = Decimal(p.amount) }

        let code = p.currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if code.count == 3 { draft.currencyCode = code }

        switch p.billingCycle.lowercased() {
        case let s where s.contains("year") || s.contains("annual"): draft.billingCycle = .yearly
        case let s where s.contains("week"): draft.billingCycle = .weekly
        case let s where s.contains("month"): draft.billingCycle = .monthly
        default: break
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: p.nextRenewalDate.trimmingCharacters(in: .whitespacesAndNewlines)) {
            draft.nextRenewalDate = date
        }

        draft.isFreeTrial = p.isFreeTrial
        return draft
    }
}

#else

/// Stub when the Foundation Models framework isn't available in the SDK.
struct IntelligenceReceiptParser {
    static var isAvailable: Bool { false }
    func parse(_ text: String) async throws -> ReceiptDraft { ReceiptDraft() }
}

#endif
