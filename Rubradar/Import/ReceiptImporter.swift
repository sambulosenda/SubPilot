//
//  ReceiptImporter.swift
//  Rubradar
//

import Foundation

enum ReceiptSource {
    case image(Data)
    case pdf(Data)
    case text(String)
}

struct ReceiptImportResult {
    let draft: ReceiptDraft
    let usedIntelligence: Bool
    let rawText: String
}

/// Extracts text from a receipt source then parses it. Uses Apple Intelligence
/// when available and always layers the heuristic parser underneath to fill gaps.
struct ReceiptImporter {

    func run(_ source: ReceiptSource) async throws -> ReceiptImportResult {
        let text = try await extractText(from: source)
        let (draft, usedIntelligence) = await parseSingle(from: text)
        return ReceiptImportResult(draft: draft, usedIntelligence: usedIntelligence, rawText: text)
    }

    /// Parses a receipt that may list several subscriptions (e.g. an Apple
    /// receipt itemising multiple apps). Prefers the on-device LLM, then a
    /// heuristic multi-item split, and finally falls back to a single draft.
    func runMultiple(_ source: ReceiptSource) async throws -> [ReceiptDraft] {
        let text = try await extractText(from: source)

        if IntelligenceReceiptParser.isAvailable,
           let items = try? await IntelligenceReceiptParser().parseMultiple(text), items.count >= 2 {
            return items
        }
        let appleItems = AppleReceiptParser.parse(text)
        if appleItems.count >= 2 { return appleItems }

        let (single, _) = await parseSingle(from: text)
        return single.isEmpty ? [] : [single]
    }

    private func parseSingle(from text: String) async -> (ReceiptDraft, Bool) {
        let heuristic = HeuristicReceiptParser().parse(text)
        if IntelligenceReceiptParser.isAvailable,
           let smart = try? await IntelligenceReceiptParser().parse(text), !smart.isEmpty {
            return (smart.overlaid(on: heuristic), true)
        }
        return (heuristic, false)
    }

    private func extractText(from source: ReceiptSource) async throws -> String {
        switch source {
        case .image(let data): return try await ReceiptTextExtractor.text(fromImageData: data)
        case .pdf(let data): return try await ReceiptTextExtractor.text(fromPDFData: data)
        case .text(let text): return text
        }
    }
}

extension ReceiptDraft {
    /// Returns self with any missing fields filled in from `base`.
    func overlaid(on base: ReceiptDraft) -> ReceiptDraft {
        ReceiptDraft(
            providerName: providerName ?? base.providerName,
            amount: amount ?? base.amount,
            currencyCode: currencyCode ?? base.currencyCode,
            billingCycle: billingCycle ?? base.billingCycle,
            nextRenewalDate: nextRenewalDate ?? base.nextRenewalDate,
            isFreeTrial: isFreeTrial || base.isFreeTrial
        )
    }
}
