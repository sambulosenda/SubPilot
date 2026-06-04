//
//  ImportView.swift
//  Rubradar
//

import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

/// AI import flow (FR-03/04/05): pick a photo, a PDF, or paste text from a
/// receipt or confirmation email, parse it on-device, then confirm on the form.
struct ImportView: View {
    /// When set, a parsed receipt is handed back to the caller (to fill an open
    /// form) instead of presenting a fresh confirmation form. `nil` = standalone.
    var onParsed: ((Subscription) -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var photoItem: PhotosPickerItem?
    @State private var pastedText = ""
    @State private var showPDFImporter = false

    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var draftSubscription: Subscription?
    @State private var usedIntelligence = false

    var body: some View {
        NavigationStack {
            List {
                scanSection
                pasteSection
            }
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .disabled(isWorking)
            .overlay {
                if isWorking {
                    ProgressView("Reading receipt…")
                        .padding(Spacing.lg)
                        .background(.regularMaterial, in: .rect(cornerRadius: Radius.card))
                }
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        run(.image(data))
                    } else {
                        errorMessage = "Couldn't load that photo."
                    }
                }
            }
            .fileImporter(isPresented: $showPDFImporter, allowedContentTypes: [.pdf]) { result in
                guard case .success(let url) = result else { return }
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                if let data = try? Data(contentsOf: url) {
                    run(.pdf(data))
                } else {
                    errorMessage = "Couldn't read that PDF."
                }
            }
            .alert("Import failed", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .sheet(item: $draftSubscription) { draft in
                SubscriptionFormView(mode: .create(draft), onSaved: { dismiss() })
            }
        }
    }

    private var scanSection: some View {
        Section {
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("Choose a photo", systemImage: "photo.on.rectangle")
            }
            Button {
                showPDFImporter = true
            } label: {
                Label("Choose a PDF", systemImage: "doc.text")
            }
        } header: {
            Text("Scan a receipt")
        } footer: {
            Text("Pick a screenshot or PDF of a subscription receipt. We read it on your device.")
        }
    }

    private var pasteSection: some View {
        Section {
            TextEditor(text: $pastedText)
                .frame(minHeight: 120)
                .overlay(alignment: .topLeading) {
                    if pastedText.isEmpty {
                        Text("Paste a receipt or confirmation email…")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .allowsHitTesting(false)
                    }
                }
            Button {
                run(.text(pastedText))
            } label: {
                Label("Parse pasted text", systemImage: "text.viewfinder")
            }
            .disabled(pastedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } header: {
            Text("Paste text")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func run(_ source: ReceiptSource) {
        isWorking = true
        Task {
            do {
                let result = try await ReceiptImporter().run(source)
                usedIntelligence = result.usedIntelligence
                if let onParsed {
                    onParsed(result.draft.makeSubscription())
                    isWorking = false
                    dismiss()
                    return
                }
                draftSubscription = result.draft.makeSubscription()
            } catch {
                errorMessage = friendlyMessage(for: error)
            }
            isWorking = false
        }
    }

    private func friendlyMessage(for error: Error) -> String {
        if error is ReceiptTextError {
            return "We couldn't find any readable text. Try a clearer image, or paste the text instead."
        }
        return "Something went wrong reading that. Please try again."
    }
}

#Preview {
    ImportView()
        .modelContainer(.preview)
}
