//
//  WidgetSnapshotStore.swift
//  Rubradar
//
//  Shared by the app (writer) and the SubPilot widget extension (reader).
//

import Foundation

/// Reads/writes the `WidgetSnapshot` JSON in the shared App Group container.
/// Mirrors the file-handoff idiom already used by `SharedInbox`, so the widget
/// never needs to open the SwiftData store.
enum WidgetSnapshotStore {
    /// Must match the App Groups capability on both the app and widget targets.
    static let appGroupID = "group.com.sambulosenda.subradar"
    private static let fileName = "widget-snapshot.json"

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(fileName)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Persists the snapshot atomically. No-ops if the App Group isn't readable
    /// (e.g. the capability hasn't been provisioned yet) so callers never crash.
    static func write(_ snapshot: WidgetSnapshot) {
        guard let url = fileURL, let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Returns the last snapshot the app wrote, or nil if none/unreadable.
    static func read() -> WidgetSnapshot? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }
}
