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
        let heuristic = HeuristicReceiptParser().parse(text)

        if IntelligenceReceiptParser.isAvailable,
           let smart = try? await IntelligenceReceiptParser().parse(text), !smart.isEmpty {
            return ReceiptImportResult(draft: smart.overlaid(on: heuristic), usedIntelligence: true, rawText: text)
        }
        return ReceiptImportResult(draft: heuristic, usedIntelligence: false, rawText: text)
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
