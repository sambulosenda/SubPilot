//
//  StatementColumnMapper.swift
//  Rubradar
//

import Foundation

/// Which columns of a statement hold what. The "money out" amount is either a
/// single signed column (`amountIndex`, negative = out) or a separate debit
/// column (`debitIndex`), optionally with a matching credit column.
struct ColumnMapping: Equatable {
    var hasHeaderRow: Bool
    var dateIndex: Int
    var descriptionIndex: Int
    var amountIndex: Int?
    var debitIndex: Int?
    var creditIndex: Int?

    var isUsable: Bool {
        dateIndex >= 0 && descriptionIndex >= 0 && (amountIndex != nil || debitIndex != nil)
    }
}

/// Best-effort guess of a statement's column layout. Always surfaced to the user
/// for confirmation — auto-detection is a head start, not the final word.
enum StatementColumnMapper {
    private static let dateHeaders = ["transaction date", "posting date", "posted date", "value date", "completed date", "date"]
    private static let descHeaders = ["description", "details", "narrative", "merchant", "payee", "reference", "particulars", "memo", "name", "transaction"]
    private static let amountHeaders = ["amount", "value"]
    private static let debitHeaders = ["money out", "paid out", "debit amount", "withdrawal", "withdrawals", "debit", "spent", "out"]
    private static let creditHeaders = ["money in", "paid in", "credit amount", "deposit", "deposits", "credit", "received", "in"]

    static func autoDetect(rows: [[String]]) -> ColumnMapping {
        guard let first = rows.first, !first.isEmpty else {
            return ColumnMapping(hasHeaderRow: false, dateIndex: 0, descriptionIndex: 1,
                                 amountIndex: 2, debitIndex: nil, creditIndex: nil)
        }
        let colCount = rows.map(\.count).max() ?? first.count
        let hasHeader = looksLikeHeader(first)
        let dataRows = hasHeader ? Array(rows.dropFirst()) : rows

        var used = Set<Int>()
        func take(_ index: Int?) -> Int? {
            guard let index, !used.contains(index) else { return nil }
            used.insert(index)
            return index
        }

        // 1) Header-keyword guesses (most reliable when present).
        var dateIdx: Int?, descIdx: Int?, amountIdx: Int?, debitIdx: Int?, creditIdx: Int?
        if hasHeader {
            let cells = first.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
            dateIdx = take(matchHeader(cells, dateHeaders, excluding: used))
            debitIdx = take(matchHeader(cells, debitHeaders, excluding: used))
            creditIdx = take(matchHeader(cells, creditHeaders, excluding: used))
            if debitIdx == nil { amountIdx = take(matchHeader(cells, amountHeaders, excluding: used)) }
            descIdx = take(matchHeader(cells, descHeaders, excluding: used))
        }

        // 2) Data-shape inference fills any gaps.
        let shape = inferShape(dataRows: dataRows, colCount: colCount)
        if dateIdx == nil { dateIdx = take(shape.dateIndex) }
        if amountIdx == nil, debitIdx == nil { amountIdx = take(shape.amountIndex) }
        if descIdx == nil { descIdx = take(shape.descriptionIndex) ?? take(firstUnused(colCount, used: used)) }

        return ColumnMapping(
            hasHeaderRow: hasHeader,
            dateIndex: dateIdx ?? 0,
            descriptionIndex: descIdx ?? min(1, colCount - 1),
            amountIndex: debitIdx == nil ? (amountIdx ?? max(0, colCount - 1)) : nil,
            debitIndex: debitIdx,
            creditIndex: creditIdx
        )
    }

    // MARK: - Header detection

    private static func looksLikeHeader(_ row: [String]) -> Bool {
        let cells = row.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        // A header has keyword-like cells and (crucially) no parseable amount in
        // the row itself — a data row's "amount" cell would parse as a number.
        let keywordHit = cells.contains { cell in
            ["date", "amount", "description", "details", "debit", "credit", "balance", "payee", "merchant", "reference", "narrative", "value"]
                .contains { cell.contains($0) }
        }
        let hasNumber = cells.contains { StatementParser.parseAmount($0) != nil }
        return keywordHit && !hasNumber
    }

    private static func matchHeader(_ cells: [String], _ keywords: [String], excluding used: Set<Int>) -> Int? {
        // Exact match first, then contains — keywords are ordered most-specific first.
        for keyword in keywords {
            if let i = cells.firstIndex(where: { $0 == keyword }), !used.contains(i) { return i }
        }
        for keyword in keywords {
            if let i = cells.firstIndex(where: { $0.contains(keyword) }), !used.contains(i) { return i }
        }
        return nil
    }

    // MARK: - Data-shape inference

    private struct Shape { var dateIndex: Int?; var amountIndex: Int?; var descriptionIndex: Int? }

    private static func inferShape(dataRows: [[String]], colCount: Int) -> Shape {
        guard colCount > 0, !dataRows.isEmpty else { return Shape() }
        let sample = Array(dataRows.prefix(40))

        var dateRate = [Double](repeating: 0, count: colCount)
        var amountRate = [Double](repeating: 0, count: colCount)
        var avgLen = [Double](repeating: 0, count: colCount)

        for col in 0..<colCount {
            let cells = sample.compactMap { $0.indices.contains(col) ? $0[col].trimmingCharacters(in: .whitespaces) : nil }
                .filter { !$0.isEmpty }
            guard !cells.isEmpty else { continue }
            let dates = cells.reduce(0) { $0 + (StatementDateParser.looksLikeDate($1) ? 1 : 0) }
            let amounts = cells.reduce(0) { $0 + (StatementParser.parseAmount($1) != nil ? 1 : 0) }
            dateRate[col] = Double(dates) / Double(cells.count)
            amountRate[col] = Double(amounts) / Double(cells.count)
            avgLen[col] = Double(cells.reduce(0) { $0 + $1.count }) / Double(cells.count)
        }

        let dateIndex = dateRate.enumerated().filter { $0.element >= 0.5 }.max { $0.element < $1.element }?.offset
        let amountIndex = amountRate.enumerated()
            .filter { $0.element >= 0.5 && $0.offset != dateIndex }
            .max { $0.element < $1.element }?.offset
        // Description = longest mostly-text column that isn't date/amount.
        let descriptionIndex = avgLen.enumerated()
            .filter { $0.offset != dateIndex && $0.offset != amountIndex && amountRate[$0.offset] < 0.5 }
            .max { $0.element < $1.element }?.offset

        return Shape(dateIndex: dateIndex, amountIndex: amountIndex, descriptionIndex: descriptionIndex)
    }

    private static func firstUnused(_ colCount: Int, used: Set<Int>) -> Int? {
        (0..<colCount).first { !used.contains($0) }
    }
}
