//
//  ShareViewController.swift
//  ShareExtension
//

import UIKit
import UniformTypeIdentifiers

/// Headless Share Extension. It copies the shared receipt (text / PDF / image /
/// URL) into the shared App Group folder, then completes immediately. The main
/// app drains that folder on next foreground and runs its normal on-device
/// import + review flow — so no parsing or CloudKit work happens here, keeping
/// the extension well inside its memory budget.
final class ShareViewController: UIViewController {
    /// Must match `SharedInbox.appGroupID` in the main app.
    private let appGroupID = "group.com.sambulosenda.subradar"
    private let folderName = "ShareInbox"

    override func viewDidLoad() {
        super.viewDidLoad()
        Task { await processAndFinish() }
    }

    private func processAndFinish() async {
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        for item in items {
            for provider in item.attachments ?? [] {
                await save(provider)
            }
        }
        extensionContext?.completeRequest(returningItems: nil)
    }

    /// Saves the first representation we understand. PDF and image win over text
    /// so a receipt screenshot isn't reduced to its filename.
    private func save(_ provider: NSItemProvider) async {
        if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier),
           let data = await loadData(provider, UTType.pdf.identifier) {
            write(data, ext: "pdf"); return
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier),
           let data = await loadData(provider, UTType.image.identifier) {
            write(data, ext: "img"); return
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
           let text = await loadItem(provider, UTType.plainText.identifier) as? String {
            write(Data(text.utf8), ext: "txt"); return
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
           let url = await loadItem(provider, UTType.url.identifier) as? URL {
            if url.isFileURL, let data = try? Data(contentsOf: url) {
                write(data, ext: url.pathExtension.isEmpty ? "img" : url.pathExtension)
            } else {
                write(Data(url.absoluteString.utf8), ext: "txt")
            }
        }
    }

    // MARK: - Loading

    private func loadData(_ provider: NSItemProvider, _ typeID: String) async -> Data? {
        await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: typeID) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }

    private func loadItem(_ provider: NSItemProvider, _ typeID: String) async -> NSSecureCoding? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeID) { item, _ in
                continuation.resume(returning: item)
            }
        }
    }

    // MARK: - Writing

    private func write(_ data: Data, ext: String) {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else { return }
        let folder = container.appendingPathComponent(folderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        // Receipts can carry PII — keep them encrypted at rest until the app
        // consumes them (it deletes on consume, and purges anything > 7 days).
        try? data.write(to: folder.appendingPathComponent("\(UUID().uuidString).\(ext)"),
                        options: [.atomic, .completeFileProtection])
    }
}
