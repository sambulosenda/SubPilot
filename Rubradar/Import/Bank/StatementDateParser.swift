//
//  StatementDateParser.swift
//  Rubradar
//

import Foundation

/// Parses the many date formats banks export. To disambiguate `01/02/2026`
/// (day-first vs month-first) we pick the single format that parses the most
/// cells across the whole column, then apply it consistently. Day-first is
/// preferred on a tie (matches the GBP-default audience).
enum StatementDateParser {
    /// Day-first variants are listed before month-first so ties resolve to dd/MM.
    static let formats = [
        "yyyy-MM-dd", "yyyy/MM/dd",
        "dd/MM/yyyy", "MM/dd/yyyy",
        "dd-MM-yyyy", "MM-dd-yyyy",
        "dd.MM.yyyy",
        "d MMM yyyy", "dd MMM yyyy", "dd MMMM yyyy", "MMM d, yyyy", "MMMM d, yyyy",
    ]

    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = format
        f.isLenient = false
        return f
    }

    /// The format parsing the most of the given samples, or nil if none parse.
    static func bestFormat(for samples: [String]) -> String? {
        var best: (format: String, count: Int)?
        for format in formats {
            let f = formatter(format)
            let count = samples.reduce(0) {
                $0 + (f.date(from: $1.trimmingCharacters(in: .whitespaces)) != nil ? 1 : 0)
            }
            if count > 0, best == nil || count > best!.count { best = (format, count) }
        }
        return best?.format
    }

    static func parse(_ string: String, format: String?) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        if let format, let date = formatter(format).date(from: trimmed) { return date }
        return detect(trimmed)
    }

    /// Fallback for one-off formats the explicit list misses.
    static func detect(_ string: String) -> Date? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return nil
        }
        let range = NSRange(string.startIndex..., in: string)
        return detector.firstMatch(in: string, range: range)?.date
    }

    static func looksLikeDate(_ string: String) -> Bool {
        bestFormat(for: [string]) != nil || detect(string) != nil
    }
}
