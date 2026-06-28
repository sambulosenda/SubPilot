//
//  SubscriptionCSVExport.swift
//  Rubradar
//

import Foundation
import CoreTransferable
import UniformTypeIdentifiers

/// A `Transferable` CSV export of the user's subscriptions, for `ShareLink`.
///
/// The CSV text is built eagerly (cheap — a handful of rows) so the share sheet
/// can hand the same bytes to AirDrop, Mail, Files, etc. The suggested filename
/// carries the export date.
struct SubscriptionCSVExport: Transferable {
    let csv: String
    /// Base filename without extension, e.g. "Recurra Subscriptions 2026-06-11".
    let filename: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { export in
            Data(export.csv.utf8)
        }
        .suggestedFileName { $0.filename }
    }
}

extension SubscriptionCSVExport {
    /// Builds an export for `subscriptions`, stamping today's date into the name.
    static func make(from subscriptions: [Subscription], date: Date = Date()) -> SubscriptionCSVExport {
        let stamp = DateFormatter.exportStamp.string(from: date)
        return SubscriptionCSVExport(
            csv: SubscriptionCSV.export(subscriptions),
            filename: "Recurra Subscriptions \(stamp)"
        )
    }
}

private extension DateFormatter {
    static let exportStamp: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
