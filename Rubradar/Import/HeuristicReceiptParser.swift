//
//  HeuristicReceiptParser.swift
//  Rubradar
//

import Foundation

/// Rule-based receipt parser used everywhere as a baseline (and the sole parser
/// on devices without Apple Intelligence). Extracts provider, amount, currency,
/// billing cycle and a renewal date from raw receipt text.
struct HeuristicReceiptParser {

    private static let symbolToCode: [Character: String] = [
        "£": "GBP", "$": "USD", "€": "EUR", "¥": "JPY"
    ]
    private static let knownCodes = ["GBP", "USD", "EUR", "CAD", "AUD", "JPY", "CHF", "INR", "NZD"]

    // Amount-matching patterns are constant — compile the regexes once instead of
    // per line per receipt.
    private static let numberPattern = "[0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{1,2})?|[0-9]+(?:[.,][0-9]{1,2})?"
    private static let symbolChars = "£$€¥"
    private static let codeAlternation = knownCodes.joined(separator: "|")

    private static let symbolPrefixedRegex = try? NSRegularExpression(pattern: "([\(symbolChars)])\\s?(\(numberPattern))")
    private static let symbolSuffixedRegex = try? NSRegularExpression(pattern: "(\(numberPattern))\\s?([\(symbolChars)])")
    private static let codeRegex = try? NSRegularExpression(
        pattern: "(?:(\(codeAlternation))\\s?)?(\(numberPattern))(?:\\s?(\(codeAlternation)))?",
        options: [.caseInsensitive]
    )

    func parse(_ text: String, referenceDate: Date = Date()) -> ReceiptDraft {
        var draft = ReceiptDraft()

        if let provider = CatalogueLoader.match(in: text) {
            draft.providerName = provider.name
        }

        if let (amount, code) = extractAmountAndCurrency(from: text) {
            draft.amount = amount
            if let code { draft.currencyCode = code }
        }

        draft.billingCycle = extractCycle(from: text)
        draft.nextRenewalDate = extractRenewalDate(from: text, referenceDate: referenceDate)
        draft.isFreeTrial = text.localizedCaseInsensitiveContains("free trial")
            || text.localizedCaseInsensitiveContains("trial period")

        return draft
    }

    // MARK: - Amount & currency

    private func extractAmountAndCurrency(from text: String) -> (Decimal, String?)? {
        var candidates: [(amount: Decimal, code: String?, prioritised: Bool)] = []
        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            let prioritised = ["total", "charged", "billed", "amount", "payment", "due"]
                .contains { line.localizedCaseInsensitiveContains($0) }
            for (amount, code) in Self.amounts(in: line) {
                candidates.append((amount, code, prioritised))
            }
        }

        guard !candidates.isEmpty else { return nil }
        // Prefer amounts on a "total"-style line; otherwise the largest amount.
        let prioritised = candidates.filter(\.prioritised)
        let pool = prioritised.isEmpty ? candidates : prioritised
        if let best = pool.max(by: { $0.amount < $1.amount }) {
            return (best.amount, best.code)
        }
        return nil
    }

    /// Finds `£9.99`, `9.99 GBP`, `$12`, etc. in a single line.
    static func amounts(in line: String) -> [(Decimal, String?)] {
        var results: [(Decimal, String?)] = []
        let range = NSRange(line.startIndex..., in: line)

        // Symbol-prefixed: £9.99
        if let regex = symbolPrefixedRegex {
            for match in regex.matches(in: line, range: range) {
                if let symRange = Range(match.range(at: 1), in: line),
                   let numRange = Range(match.range(at: 2), in: line),
                   let value = decimal(from: String(line[numRange])) {
                    let code = symbolToCode[line[symRange].first ?? " "]
                    results.append((value, code))
                }
            }
        }

        // Symbol-suffixed: 9,99 €
        if let regex = symbolSuffixedRegex {
            for match in regex.matches(in: line, range: range) {
                if let numRange = Range(match.range(at: 1), in: line),
                   let symRange = Range(match.range(at: 2), in: line),
                   let value = decimal(from: String(line[numRange])) {
                    let code = symbolToCode[line[symRange].first ?? " "]
                    results.append((value, code))
                }
            }
        }

        // Code-suffixed/prefixed: 9.99 GBP / GBP 9.99
        if let regex = codeRegex {
            for match in regex.matches(in: line, range: range) {
                guard let numRange = Range(match.range(at: 2), in: line),
                      let value = decimal(from: String(line[numRange])) else { continue }
                var code: String?
                if let r = Range(match.range(at: 1), in: line) { code = String(line[r]).uppercased() }
                else if let r = Range(match.range(at: 3), in: line) { code = String(line[r]).uppercased() }
                if code != nil { results.append((value, code)) }
            }
        }
        return results
    }

    private static func decimal(from raw: String) -> Decimal? {
        var s = raw
        if s.contains(",") && s.contains(".") {
            s = s.replacingOccurrences(of: ",", with: "")          // comma = thousands
        } else if s.contains(",") {
            s = s.replacingOccurrences(of: ",", with: ".")          // comma = decimal
        }
        return Decimal(string: s)
    }

    // MARK: - Billing cycle

    private func extractCycle(from text: String) -> BillingCycle? {
        let lower = text.lowercased()
        if ["year", "annual", "/yr", "annually", "per year"].contains(where: lower.contains) { return .yearly }
        if ["week", "/wk", "weekly", "per week"].contains(where: lower.contains) { return .weekly }
        if ["month", "/mo", "monthly", "per month"].contains(where: lower.contains) { return .monthly }
        return nil
    }

    // MARK: - Date

    private func extractRenewalDate(from text: String, referenceDate: Date) -> Date? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return nil }
        let matches = detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
        let dates = matches.compactMap(\.date)
        guard !dates.isEmpty else { return nil }
        // The soonest future date is the most likely "next renewal"; else the latest seen.
        let future = dates.filter { $0 > referenceDate }.min()
        return future ?? dates.max()
    }
}
