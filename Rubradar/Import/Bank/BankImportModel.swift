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
    var detections: [DetectedSubscription] = []
    var selected: Set<String> = []
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
        detections = SubscriptionDeduplicator.mark(detected, against: existing)
        // Pre-select confident, not-yet-tracked detections.
        selected = Set(detections.filter { !$0.alreadyTracked && $0.confidence >= 0.6 }.map(\.id))
        phase = .review
    }

    func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    var selectedDetections: [DetectedSubscription] {
        detections.filter { selected.contains($0.id) }
    }

    func provider(for detected: DetectedSubscription) -> CatalogueProvider? {
        guard let id = detected.matchedProviderID else { return nil }
        return catalogue.first { $0.id == id }
    }
}
