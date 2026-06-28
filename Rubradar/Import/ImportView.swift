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

    /// When set (e.g. from a Share Extension hand-off), this source is parsed
    /// automatically on appear instead of waiting for the user to pick one.
    var initialSource: ReceiptSource?

    /// Receipts handed in by the Share Extension count as `.share`; receipts the
    /// user picks inside the app are `.scan`. Drives the activation funnel.
    private var addMethod: AddMethod { initialSource == nil ? .scan : .share }

    @Environment(\.dismiss) private var dismiss
    @Query private var existingSubscriptions: [Subscription]

    @State private var photoItem: PhotosPickerItem?
    @State private var pastedText = ""
    @State private var showPDFImporter = false
    @State private var didAutoRun = false

    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var draftSubscription: Subscription?
    /// Set when a receipt yields several subscriptions (e.g. an Apple receipt).
    @State private var reviewBundle: ReviewBundle?

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
            .task {
                guard let initialSource, !didAutoRun else { return }
                didAutoRun = true
                run(initialSource)
            }
            .overlay {
                if isWorking {
                    RecurraLoaderView("Reading receipt…")
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
                SubscriptionFormView(mode: .create(draft), addMethod: addMethod, onSaved: { dismiss() })
            }
            .sheet(item: $reviewBundle) { bundle in
                NavigationStack {
                    ImportReviewView(
                        candidates: bundle.candidates,
                        footer: "We found these subscriptions in your receipt. Pick the ones to add.",
                        emptyTitle: "No subscriptions found",
                        emptyMessage: "We couldn't find subscriptions in that receipt.",
                        origin: addMethod,
                        onFinish: { reviewBundle = nil; dismiss() }
                    )
                    .navigationTitle("Add subscriptions")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { reviewBundle = nil }
                        }
                    }
                }
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
                // The faux placeholder overlay below is invisible to VoiceOver.
                .accessibilityLabel("Receipt or confirmation email text")
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
                let drafts = try await ReceiptImporter().runMultiple(source)
                if let onParsed {
                    // Filling an open form takes a single subscription.
                    onParsed((drafts.first ?? ReceiptDraft()).makeSubscription())
                    isWorking = false
                    dismiss()
                    return
                }
                if drafts.count > 1 {
                    reviewBundle = ReviewBundle(candidates: makeCandidates(from: drafts))
                } else {
                    draftSubscription = (drafts.first ?? ReceiptDraft()).makeSubscription()
                }
            } catch {
                errorMessage = friendlyMessage(for: error)
            }
            isWorking = false
        }
    }

    private func makeCandidates(from drafts: [ReceiptDraft]) -> [ImportCandidate] {
        drafts.enumerated().map { index, draft in
            let subscription = draft.makeSubscription()
            return ImportCandidate(
                id: "\(index)-\(subscription.name.lowercased())",
                subscription: subscription,
                subtitle: subscription.billingCycle.label,
                alreadyTracked: isTracked(subscription),
                isPreselected: true
            )
        }
    }

    /// Flags a draft that matches an existing subscription (same catalogue entry,
    /// or same normalised name and a comparable amount).
    private func isTracked(_ draft: Subscription) -> Bool {
        existingSubscriptions.contains { existing in
            if let id = draft.catalogueID, existing.catalogueID == id { return true }
            guard MerchantNormalizer.key(for: existing.name) == MerchantNormalizer.key(for: draft.name) else { return false }
            let a = NSDecimalNumber(decimal: existing.amount).doubleValue
            let b = NSDecimalNumber(decimal: draft.amount).doubleValue
            return abs(a - b) < 0.5
        }
    }

    private func friendlyMessage(for error: Error) -> String {
        if error is ReceiptTextError {
            return "We couldn't find any readable text. Try a clearer image, or paste the text instead."
        }
        return "Something went wrong reading that. Please try again."
    }
}

/// Wraps the candidates for `.sheet(item:)` presentation of the review.
private struct ReviewBundle: Identifiable {
    let id = UUID()
    let candidates: [ImportCandidate]
}

#Preview {
    ImportView()
        .modelContainer(.preview)
}
