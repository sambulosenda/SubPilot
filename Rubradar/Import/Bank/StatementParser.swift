//
//  StatementParser.swift
//  Rubradar
//

import Foundation

/// Turns tokenized CSV rows + a confirmed column mapping into `BankTransaction`s.
/// Keeps only money-out (debits) — credits can't be subscription charges.
enum StatementParser {
    static func transactions(rows: [[String]], mapping: ColumnMapping,
                             defaultCurrency: String? = nil) -> [BankTransaction] {
        guard mapping.isUsable else { return [] }
        let dataRows = mapping.hasHeaderRow ? Array(rows.dropFirst()) : rows

        // Resolve one date format for the whole file (disambiguates dd/MM vs MM/dd).
        let dateSamples = dataRows.compactMap { cell($0, mapping.dateIndex) }
        let dateFormat = StatementDateParser.bestFormat(for: dateSamples)

        var out: [BankTransaction] = []
        for row in dataRows {
            guard let dateString = cell(row, mapping.dateIndex),
                  let date = StatementDateParser.parse(dateString, format: dateFormat) else { continue }
            let description = (cell(row, mapping.descriptionIndex) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !description.isEmpty else { continue }
            guard let (magnitude, isDebit, currency) = amount(in: row, mapping: mapping),
                  isDebit, magnitude > 0 else { continue }
            out.append(BankTransaction(date: date, description: description,
                                       amount: magnitude, currencyCode: currency ?? defaultCurrency))
        }
        return out
    }

    // MARK: - Amount

    /// Returns the charge magnitude, whether it's money out, and any detected currency.
    private static func amount(in row: [String], mapping: ColumnMapping) -> (Decimal, Bool, String?)? {
        if let debitIndex = mapping.debitIndex {
            if let raw = cell(row, debitIndex), let (mag, _) = parseAmount(raw), mag > 0 {
                return (mag, true, detectCurrency(in: raw))
            }
            if let creditIndex = mapping.creditIndex, let raw = cell(row, creditIndex),
               let (mag, _) = parseAmount(raw), mag > 0 {
                return (mag, false, detectCurrency(in: raw)) // money in — caller drops it
            }
            return nil
        }
        if let amountIndex = mapping.amountIndex, let raw = cell(row, amountIndex),
           let (mag, isNegative) = parseAmount(raw) {
            return (mag, isNegative, detectCurrency(in: raw)) // negative = money out
        }
        return nil
    }

    /// Parses a money cell into (magnitude, isNegative). Handles currency symbols
    /// and ISO codes, thousands separators, and `(x)` / trailing `-` / `DR`/`CR` signs.
    static func parseAmount(_ raw: String) -> (magnitude: Decimal, isNegative: Bool)? {
        var s = raw.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return nil }
        var negative = false

        if s.hasPrefix("("), s.hasSuffix(")") { negative = true }
        let upper = s.uppercased()
        if upper.hasSuffix("DR") { negative = true; s = String(s.dropLast(2)) }
        else if upper.hasSuffix("CR") { negative = false; s = String(s.dropLast(2)) }

        if s.contains("-") { negative = true }

        // Keep only digits and separators.
        s = s.replacingOccurrences(of: "[^0-9.,]", with: "", options: .regularExpression)
        guard s.contains(where: \.isNumber) else { return nil }

        // Pure thousands grouping with no decimal part: "1,234" / "1,234,567" -> strip commas.
        if s.range(of: #"^\d{1,3}(,\d{3})+$"#, options: .regularExpression) != nil {
            s = s.replacingOccurrences(of: ",", with: "")
        }
        guard let value = HeuristicReceiptParser.decimal(from: s) else { return nil }
        return (value, negative)
    }

    private static func detectCurrency(in raw: String) -> String? {
        if raw.contains("£") { return "GBP" }
        if raw.contains("€") { return "EUR" }
        if raw.contains("$") { return "USD" }
        let upper = raw.uppercased()
        for code in ["GBP", "USD", "EUR", "CAD", "AUD", "JPY", "CHF", "INR"] where upper.contains(code) {
            return code
        }
        return nil
    }

    private static func cell(_ row: [String], _ index: Int) -> String? {
        guard index >= 0, row.indices.contains(index) else { return nil }
        let value = row[index].trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }
}
