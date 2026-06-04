//
//  MerchantNormalizer.swift
//  Rubradar
//

import Foundation

/// Cleans the noisy merchant strings banks print (`SQ *NETFLIX 0123`,
/// `PAYPAL *SPOTIFY`, `NETFLIX.COM 866-...`) into a stable grouping key and a
/// human-friendly display name. Used both to group recurring charges and to
/// feed the catalogue matcher.
enum MerchantNormalizer {
    /// Payment-processor / aggregator prefixes that prepend the real merchant.
    private static let prefixes = [
        "sq *", "sq*", "tst* ", "tst*", "paypal *", "pp*", "pp *", "sp *", "sp*",
        "sumup *", "zettle *", "izettle *", "iz *", "dd ", "direct debit ", "www.",
    ]

    /// Aggressive, lowercased key for grouping and dedup.
    static func key(for raw: String) -> String { clean(raw) }

    /// Title-cased cleaned name for display (catalogue match usually overrides this).
    static func displayName(for raw: String) -> String {
        let cleaned = clean(raw)
        guard !cleaned.isEmpty else { return raw.trimmingCharacters(in: .whitespaces) }
        return cleaned.split(separator: " ").map { $0.capitalized }.joined(separator: " ")
    }

    private static func clean(_ raw: String) -> String {
        var s = " " + raw.lowercased() + " "
        for prefix in prefixes { s = s.replacingOccurrences(of: " " + prefix, with: " ") }
        // Drop common TLD tails so "netflix.com" groups with "netflix".
        s = s.replacingOccurrences(of: #"\.(com|co\.uk|net|org|io|tv|app|ai)\b"#,
                                   with: " ", options: .regularExpression)
        // Strip store/reference numbers, phone numbers, and dates.
        s = s.replacingOccurrences(of: #"#?\d{3,}"#, with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\b\d{1,2}/\d{1,2}(/\d{2,4})?\b"#, with: " ", options: .regularExpression)
        // Everything that isn't a letter/digit/space becomes a space.
        s = s.replacingOccurrences(of: #"[^a-z0-9 ]"#, with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespaces)
    }
}
