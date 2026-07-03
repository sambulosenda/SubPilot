//
//  SubscriptionCSV.swift
//  Rubradar
//

import Foundation

/// Serialises subscriptions to RFC 4180 CSV so users can take their data
/// elsewhere (spreadsheet, backup, another app) — data portability, no lock-in.
///
/// Values are locale-independent and round-trip-friendly: amounts use a `.`
/// decimal point, dates are ISO `yyyy-MM-dd`, enums use their stored raw values,
/// and booleans are `Yes`/`No`. Quoting matches `CSVParser` (the import side):
/// fields containing a comma, quote, or newline are wrapped in quotes with
/// internal quotes doubled.
enum SubscriptionCSV {
    /// Column order. Mirrors the fields a user would want to keep or re-import.
    static let header = [
        "Name", "Amount", "Currency", "Billing Cycle", "Custom Cycle Days",
        "Next Renewal", "Category", "Free Trial", "Trial End", "Cancelled",
        "Reminder Lead Days", "Profile", "Notes",
    ]

    /// Builds the full CSV text (header + one row per subscription), ordered by
    /// name then creation date so exports are deterministic. `timeZone` controls
    /// how the stored dates map to a calendar day; defaults to the user's zone so
    /// the exported day matches what they see in the app.
    static func export(_ subscriptions: [Subscription], timeZone: TimeZone = .current) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = timeZone

        let sorted = subscriptions.sorted { lhs, rhs in
            let order = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
            return order == .orderedSame ? lhs.createdAt < rhs.createdAt : order == .orderedAscending
        }

        var lines: [String] = [row(header)]
        for sub in sorted {
            lines.append(row([
                sub.name,
                NSDecimalNumber(decimal: sub.amount).stringValue,
                sub.currencyCode,
                sub.billingCycle.rawValue,
                sub.customCycleDays.map(String.init) ?? "",
                dateFormatter.string(from: sub.nextRenewalDate),
                sub.category.rawValue,
                sub.isFreeTrial ? "Yes" : "No",
                sub.trialEndDate.map(dateFormatter.string(from:)) ?? "",
                sub.isCancelled ? "Yes" : "No",
                String(sub.reminderLeadDays),
                sub.profile?.name ?? "",
                sub.notes,
            ]))
        }
        // RFC 4180 uses CRLF line endings and a trailing newline.
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    // MARK: - Field encoding

    private static func row(_ fields: [String]) -> String {
        fields.map(escape).joined(separator: ",")
    }

    private static func escape(_ value: String) -> String {
        // Formula-injection guard: names/notes can carry imported (attacker-
        // influenceable) text, and spreadsheets execute cells starting with
        // = + - @ or a tab. A leading apostrophe makes Excel/Numbers/Sheets
        // render the cell as text.
        var value = value
        if let first = value.first, "=+-@\t".contains(first) {
            value = "'" + value
        }
        let needsQuoting = value.contains { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }
        guard needsQuoting else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
