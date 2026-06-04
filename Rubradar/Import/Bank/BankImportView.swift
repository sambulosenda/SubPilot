//
//  BankImportView.swift
//  Rubradar
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Import recurring subscriptions from a bank-statement CSV. Three steps: pick a
/// file, confirm which columns hold the date / description / amount, then review
/// and add the detected subscriptions. Everything runs on-device.
struct BankImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var existingSubscriptions: [Subscription]

    @State private var model: BankImportModel
    @State private var showFileImporter = false

    init() {
        let currency = UserDefaults.standard.string(forKey: "preferredCurrencyCode")
            ?? Locale.current.currency?.identifier ?? "GBP"
        _model = State(initialValue: BankImportModel(preferredCurrency: currency))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Import statement")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
                .safeAreaInset(edge: .bottom) { bottomBar }
                .task { model.loadCatalogueIfNeeded() }
                .fileImporter(isPresented: $showFileImporter,
                              allowedContentTypes: [.commaSeparatedText, .text]) { handlePick($0) }
                .alert("Import failed", isPresented: errorBinding) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(model.errorMessage ?? "")
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .pickFile: pickFileStep
        case .confirmColumns: confirmColumnsStep
        case .detecting: ProgressView("Finding subscriptions…").frame(maxWidth: .infinity, maxHeight: .infinity)
        case .review: reviewStep
        }
    }

    // MARK: - Step 1: pick file

    private var pickFileStep: some View {
        List {
            Section {
                Button {
                    showFileImporter = true
                } label: {
                    Label("Choose CSV file", systemImage: "doc.badge.arrow.up")
                }
            } header: {
                Text("Bank statement")
            } footer: {
                Text("Export a statement as CSV from your bank, then pick it here. We scan it on your device to find recurring charges — your statement is never uploaded or saved.")
            }
        }
    }

    // MARK: - Step 2: confirm columns

    private var confirmColumnsStep: some View {
        Form {
            Section {
                Toggle("First row is a header", isOn: headerBinding)
                columnPicker("Date", binding(\.dateIndex))
                columnPicker("Description", binding(\.descriptionIndex))
                if model.mapping.debitIndex != nil {
                    columnPicker("Money out", binding(\.debitIndex))
                } else {
                    columnPicker("Amount", binding(\.amountIndex))
                }
            } header: {
                Text("Match your columns")
            } footer: {
                Text(model.mapping.debitIndex != nil
                     ? "We'll treat this column as money going out."
                     : "Negative amounts in this column are treated as money going out.")
            }
            sampleSection
        }
    }

    private var sampleSection: some View {
        let data = model.mapping.hasHeaderRow ? Array(model.rows.dropFirst()) : model.rows
        let amountCol = model.mapping.debitIndex ?? model.mapping.amountIndex ?? 0
        return Section("Preview") {
            ForEach(Array(data.prefix(3).enumerated()), id: \.offset) { _, row in
                VStack(alignment: .leading, spacing: 2) {
                    Text(cell(row, model.mapping.descriptionIndex)).font(.subheadline).lineLimit(1)
                    HStack {
                        Text(cell(row, model.mapping.dateIndex)).foregroundStyle(.secondary)
                        Spacer()
                        Text(cell(row, amountCol)).fontWeight(.medium)
                    }
                    .font(.caption)
                }
            }
        }
    }

    // MARK: - Step 3: review (shared with the receipt importer)

    private var reviewStep: some View {
        ImportReviewView(
            candidates: model.candidates,
            footer: "We look for charges that repeat on a regular schedule. Pick the ones you'd like to track.",
            emptyTitle: "No subscriptions found",
            emptyMessage: "We couldn't spot recurring charges in this statement. Try a statement covering a longer period, or add subscriptions manually."
        )
    }

    // MARK: - Bottom action bar

    @ViewBuilder
    private var bottomBar: some View {
        // The review step supplies its own "Add" bar via ImportReviewView.
        if model.phase == .confirmColumns {
            primaryButton("Find subscriptions") {
                Task { await model.runDetection(existing: existingSubscriptions) }
            }
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.extraLarge)
        .padding()
    }

    // MARK: - File picking

    private func handlePick(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        guard url.startAccessingSecurityScopedResource() else {
            model.errorMessage = "Couldn't open that file."
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let data = try? Data(contentsOf: url) else {
            model.errorMessage = "Couldn't read that file."
            return
        }
        model.load(data: data)
    }

    // MARK: - Helpers

    private func columnPicker(_ title: String, _ selection: Binding<Int>) -> some View {
        Picker(title, selection: selection) {
            // Array(...) avoids ForEach's non-constant-range runtime warning.
            ForEach(Array(0..<model.columnCount), id: \.self) { index in
                Text(columnLabel(index)).tag(index)
            }
        }
    }

    private func columnLabel(_ index: Int) -> String {
        let header: String
        if model.mapping.hasHeaderRow, let value = model.rows.first?[safe: index], !value.isEmpty {
            header = value
        } else {
            header = "Column \(index + 1)"
        }
        if let sample = model.sampleRow?[safe: index], !sample.isEmpty { return "\(header) — \(sample)" }
        return header
    }

    private func cell(_ row: [String], _ index: Int) -> String {
        row[safe: index]?.trimmingCharacters(in: .whitespaces).nilIfEmpty ?? "—"
    }

    // MARK: - Bindings

    private var headerBinding: Binding<Bool> {
        Binding(get: { model.mapping.hasHeaderRow }, set: { model.mapping.hasHeaderRow = $0 })
    }

    private func binding(_ keyPath: WritableKeyPath<ColumnMapping, Int>) -> Binding<Int> {
        Binding(get: { model.mapping[keyPath: keyPath] }, set: { model.mapping[keyPath: keyPath] = $0 })
    }

    private func binding(_ keyPath: WritableKeyPath<ColumnMapping, Int?>) -> Binding<Int> {
        Binding(get: { model.mapping[keyPath: keyPath] ?? 0 }, set: { model.mapping[keyPath: keyPath] = $0 })
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

#Preview {
    BankImportView()
        .modelContainer(.preview)
}
