//
//  CSVParser.swift
//  Rubradar
//

import Foundation

/// Minimal RFC 4180 CSV tokenizer. Bank exports are messy — fields can be
/// quoted, contain commas or newlines, and use escaped (`""`) quotes — so we
/// never `split(",")`. Handles CRLF / LF / CR line endings and a UTF-8 BOM.
enum CSVParser {
    static func rows(from data: Data) -> [[String]] {
        rows(from: decodeText(data))
    }

    static func rows(from text: String) -> [[String]] {
        var rows: [[String]] = []
        var field = ""
        var record: [String] = []
        var inQuotes = false
        // Normalise line endings first: Swift treats "\r\n" as a single grapheme
        // cluster, so it would never match a "\r"/"\n" case below.
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let chars = Array(normalized.unicodeScalars)
        var i = 0

        func endField() { record.append(field); field = "" }
        func endRecord() { endField(); rows.append(record); record = [] }

        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    // Escaped quote inside a quoted field is a doubled quote.
                    if i + 1 < chars.count, chars[i + 1] == "\"" {
                        field.unicodeScalars.append("\""); i += 2; continue
                    }
                    inQuotes = false; i += 1; continue
                }
                field.unicodeScalars.append(c); i += 1; continue
            }
            switch c {
            case "\"": inQuotes = true; i += 1
            case ",": endField(); i += 1
            case "\n": endRecord(); i += 1
            default: field.unicodeScalars.append(c); i += 1
            }
        }
        // Flush a trailing field/record when the file has no final newline.
        if !field.isEmpty || !record.isEmpty { endRecord() }

        // Drop blank lines (a single empty field).
        return rows.filter { !($0.count == 1 && $0[0].trimmingCharacters(in: .whitespaces).isEmpty) }
    }

    private static func decodeText(_ data: Data) -> String {
        if let s = String(data: data, encoding: .utf8) {
            return s.hasPrefix("\u{FEFF}") ? String(s.dropFirst()) : s
        }
        return String(data: data, encoding: .isoLatin1) ?? ""
    }
}
