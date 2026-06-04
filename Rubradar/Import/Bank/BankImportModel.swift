//
//  BankImportModel.swift
//  Rubradar
//

import Foundation
import Observation

/// Drives the multi-step bank-statement import: pick a file → confirm columns →
/// review detected subscriptions. Parsing and detection run on-device; nothing
/// is uploaded and the file is not retained beyond this object's lifetime.
@Observable
final class BankImportModel {
    enum Phase: Equatable { case pickFile, confirmColumns, detecting, review }

    var phase: Phase = .pickFile
    var rows: [[String]] = []
    var mapping = ColumnMapping(hasHeaderRow: false, dateIndex: 0, descriptionIndex: 1,
                                amountIndex: 2, debitIndex: nil, creditIndex: nil)
    /// Detected subscriptions, mapped to review candidates for `ImportReviewView`.
    var candidates: [ImportCandidate] = []
    var errorMessage: String?

    let preferredCurrency: String
    private var catalogue: [CatalogueProvider] = []

    init(preferredCurrency: String) { self.preferredCurrency = preferredCurrency }

    var columnCount: Int { rows.map(\.count).max() ?? 0 }

    /// First data row, used to show a sample value next to each column picker.
    var sampleRow: [String]? {
        let data = mapping.hasHeaderRow ? Array(rows.dropFirst()) : rows
        return data.first
    }

    func loadCatalogueIfNeeded() {
        if catalogue.isEmpty { catalogue = CatalogueLoader.load() }
    }

    /// Parses the picked CSV and advances to column confirmation.
    func load(data: Data) {
        let parsed = CSVParser.rows(from: data)
        guard parsed.count >= 2 else {
            errorMessage = "That file didn't have any rows we could read. Export a CSV from your bank and try again."
            return
        }
        rows = parsed
        mapping = StatementColumnMapper.autoDetect(rows: parsed)
        phase = .confirmColumns
    }

    /// Runs detection against the user's existing subscriptions. `Task.yield`
    /// lets the spinner paint before the (fast, on-device) work runs.
    func runDetection(existing: [Subscription]) async {
        loadCatalogueIfNeeded()
        phase = .detecting
        await Task.yield()

        let transactions = StatementParser.transactions(rows: rows, mapping: mapping,
                                                         defaultCurrency: preferredCurrency)
        let detected = RecurringChargeDetector().detect(transactions, catalogue: catalogue)
        let marked = SubscriptionDeduplicator.mark(detected, against: existing)
        candidates = marked.map { item in
            let count = item.occurrenceCount == 1 ? "1 charge" : "\(item.occurrenceCount) charges"
            return ImportCandidate(
                id: item.id,
                subscription: item.makeDraft().makeSubscription(),
                subtitle: "\(count) · \(item.cycle.label)",
                alreadyTracked: item.alreadyTracked,
                // Pre-select confident, not-yet-tracked detections.
                isPreselected: item.confidence >= 0.6
            )
        }
        phase = .review
    }
}
