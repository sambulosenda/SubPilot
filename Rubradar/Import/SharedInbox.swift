//
//  SharedInbox.swift
//  Rubradar
//

import Foundation

/// Hand-off point between the Share Extension and the main app.
///
/// The extension can't (and shouldn't) parse receipts itself — it has a tight
/// memory budget and no CloudKit stack. Instead it drops the raw shared payload
/// (text / PDF / image) as a file into a shared App Group folder. The app drains
/// that folder on foreground and runs the normal on-device import pipeline so the
/// user reviews results before anything is saved.
///
/// Until the App Group entitlement is added to both targets,
/// `containerURL(forSecurityApplicationGroupIdentifier:)` returns nil and every
/// method here safely no-ops — the app builds and runs unchanged.
enum SharedInbox {
    /// Must match the App Group added to both the app and the extension.
    static let appGroupID = "group.com.sambulosenda.subradar"
    private static let folderName = "ShareInbox"

    private static var folderURL: URL? {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else { return nil }
        let url = container.appendingPathComponent(folderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Shared receipts can contain real PII (emails, card last-4). If the user
    /// never reopens the app they shouldn't sit in the group container forever —
    /// anything older than this is deleted on the next inbox access.
    private static let maxAge: TimeInterval = 7 * 24 * 60 * 60

    /// True if at least one shared capture is waiting to be imported.
    static var hasPending: Bool {
        guard let folder = folderURL else { return false }
        purgeStale(in: folder)
        let files = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return !files.isEmpty
    }

    private static func purgeStale(in folder: URL) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.creationDateKey]) else { return }
        let cutoff = Date().addingTimeInterval(-maxAge)
        for file in files {
            let created = (try? file.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            if created < cutoff { try? FileManager.default.removeItem(at: file) }
        }
    }

    /// Returns the oldest pending capture as a `ReceiptSource` and deletes it.
    /// Returns nil when the folder is empty or unavailable.
    static func consumeNext() -> ReceiptSource? {
        guard let folder = folderURL else { return nil }
        purgeStale(in: folder)
        guard let files = try? FileManager.default.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: [.creationDateKey]),
              !files.isEmpty else { return nil }

        let oldest = files.min { a, b in
            let da = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let db = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return da < db
        }
        guard let file = oldest, let data = try? Data(contentsOf: file) else { return nil }
        defer { try? FileManager.default.removeItem(at: file) }

        switch file.pathExtension.lowercased() {
        case "pdf": return .pdf(data)
        case "txt": return String(data: data, encoding: .utf8).map { .text($0) }
        default: return .image(data) // png / jpg / heic / unknown image data
        }
    }
}
