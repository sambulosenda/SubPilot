//
//  AppleReceiptParser.swift
//  Rubradar
//

import Foundation

/// Splits a receipt that lists several subscriptions — e.g. an Apple "Your
/// receipt from Apple" email, which itemises every app — into one `ReceiptDraft`
/// per line item. Heuristic and deterministic; the on-device LLM
/// (`IntelligenceReceiptParser.parseMultiple`) is preferred when available.
enum AppleReceiptParser {
    /// Lines that are document chrome, not subscription items.
    private static let metaKeywords = [
        "total", "subtotal", "tax", "vat", "order id", "document no", "apple id",
        "billed to", "payment", "receipt", "invoice", "report a problem",
        "redownload", "manage subscription", "app store", "your receipt",
    ]

    /// Lines that describe a plan/renewal rather than name the service.
    private static let descriptorKeywords = [
        "renew", "subscription", "monthly", "yearly", "annually", "annual",
        "weekly", "month", "year", "week", "plan", "trial", "auto-renew", "billed",
    ]

    private static let cycleHints: [(BillingCycle, [String])] = [
        (.yearly, ["year", "annual", "annually"]),
        (.weekly, ["week", "weekly"]),
        (.monthly, ["month", "monthly"]),
    ]

    static func parse(_ text: String, referenceDate: Date = Date(),
                      providers: [CatalogueProvider]? = nil) -> [ReceiptDraft] {
        let catalogue = providers ?? CatalogueLoader.load()
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var drafts: [ReceiptDraft] = []
        for (index, line) in lines.enumerated() {
            guard !isMeta(line),
                  let (amount, code) = HeuristicReceiptParser.amounts(in: line).first(where: { $0.0 > 0 })
            else { continue }

            let context = windowText(lines, around: index, back: 5)
            guard let name = itemName(before: index, in: lines, context: context, catalogue: catalogue)
            else { continue }

            var draft = ReceiptDraft()
            draft.providerName = name
            draft.amount = amount
            if let code { draft.currencyCode = code }
            draft.billingCycle = cycle(in: context)
            draft.isFreeTrial = context.localizedCaseInsensitiveContains("free trial")
                || context.localizedCaseInsensitiveContains("trial")
            draft.nextRenewalDate = renewalDate(in: context, referenceDate: referenceDate)
            drafts.append(draft)
        }
        return dedupe(drafts)
    }

    // MARK: - Item name

    /// Resolves the service name for a price line: the nearest preceding line that
    /// looks like a name, preferring a catalogue match anywhere in the block.
    private static func itemName(before index: Int, in lines: [String],
                                 context: String, catalogue: [CatalogueProvider]) -> String? {
        // Search backwards over a small window, skipping chrome/descriptors.
        let lower = max(0, index - 5)
        for j in stride(from: index - 1, through: lower, by: -1) {
            let candidate = lines[j]
            if isMeta(candidate) || isDescriptor(candidate) { continue }
            if !HeuristicReceiptParser.amounts(in: candidate).isEmpty { continue }
            if looksLikeName(candidate) {
                // Prefer the catalogue's canonical name when it recognises the line.
                return CatalogueLoader.match(in: candidate, providers: catalogue)?.name ?? candidate
            }
        }
        // Fall back to a catalogue match anywhere in the surrounding block.
        return CatalogueLoader.match(in: context, providers: catalogue)?.name
    }

    private static func looksLikeName(_ line: String) -> Bool {
        guard line.count >= 2, line.count <= 60 else { return false }
        return line.contains { $0.isLetter }
    }

    private static func isMeta(_ line: String) -> Bool {
        let lower = line.lowercased()
        return metaKeywords.contains { lower.contains($0) }
    }

    private static func isDescriptor(_ line: String) -> Bool {
        let lower = line.lowercased()
        return descriptorKeywords.contains { lower.contains($0) }
    }

    // MARK: - Cycle & date

    private static func cycle(in context: String) -> BillingCycle? {
        let lower = context.lowercased()
        for (cycle, hints) in cycleHints where hints.contains(where: lower.contains) {
            return cycle
        }
        return nil
    }

    private static func renewalDate(in context: String, referenceDate: Date) -> Date? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return nil }
        let dates = detector.matches(in: context, range: NSRange(context.startIndex..., in: context)).compactMap(\.date)
        guard !dates.isEmpty else { return nil }
        return dates.filter { $0 > referenceDate }.min() ?? dates.max()
    }

    // MARK: - Helpers

    private static func windowText(_ lines: [String], around index: Int, back: Int) -> String {
        let lower = max(0, index - back)
        return lines[lower...index].joined(separator: "\n")
    }

    /// Collapses items that resolve to the same provider + amount (OCR can repeat lines).
    private static func dedupe(_ drafts: [ReceiptDraft]) -> [ReceiptDraft] {
        var seen = Set<String>()
        var result: [ReceiptDraft] = []
        for draft in drafts {
            let key = "\((draft.providerName ?? "").lowercased())|\(draft.amount ?? 0)"
            if seen.insert(key).inserted { result.append(draft) }
        }
        return result
    }
}
