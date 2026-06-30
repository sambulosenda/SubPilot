//
//  WidgetSnapshotStore.swift
//  Rubradar
//
//  Shared by the app (writer) and the SubHelm widget extension (reader).
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

    /// Persists the full per-profile set atomically. No-ops if the App Group
    /// isn't readable (e.g. capability not provisioned) so callers never crash.
    static func write(_ set: WidgetSnapshotSet) {
        guard let url = fileURL, let data = try? encoder.encode(set) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Returns the last set the app wrote. Falls back to decoding the pre-1.2
    /// single-snapshot format (widget may run before the updated app does) by
    /// wrapping it as a lone "All Profiles" slice.
    static func readSet() -> WidgetSnapshotSet? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        if let set = try? decoder.decode(WidgetSnapshotSet.self, from: data) { return set }
        guard let legacy = try? decoder.decode(WidgetSnapshot.self, from: data) else { return nil }
        return WidgetSnapshotSet(
            slices: [.init(id: "", name: legacy.profileName, snapshot: legacy)],
            appSelectedID: ""
        )
    }

    /// Snapshot for the profile selected in the app — what Siri/Shortcuts answer.
    static func read() -> WidgetSnapshot? {
        readSet()?.slice(for: nil)?.snapshot
    }

    /// Widget-local profile override set by the cycle button. nil = follow the
    /// app's selection. Lives in App Group defaults, not the snapshot file, so
    /// the app rewriting snapshots never resets the user's widget choice.
    static var widgetProfileID: String? {
        get { UserDefaults(suiteName: appGroupID)?.string(forKey: "widgetProfileID") }
        set { UserDefaults(suiteName: appGroupID)?.set(newValue, forKey: "widgetProfileID") }
    }

    /// Raised by the Control Center button (which runs in the widget process and
    /// can only open the app, not navigate it); the app consumes it on foreground
    /// and presents the add flow. Same handoff idiom as `SharedInbox`.
    static func requestAdd() {
        UserDefaults(suiteName: appGroupID)?.set(true, forKey: "pendingAddRequest")
    }

    /// Returns whether an add was requested, clearing the flag.
    static func consumeAddRequest() -> Bool {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              defaults.bool(forKey: "pendingAddRequest") else { return false }
        defaults.removeObject(forKey: "pendingAddRequest")
        return true
    }
}
