//
//  WidgetSnapshot.swift
//  Rubradar
//
//  Shared by the app (writer) and the SubPilot widget extension (reader).
//  Keep this file free of SwiftData / UIKit so it compiles cleanly in the
//  widget target — it should only ever depend on Foundation.
//

import Foundation

/// A small, Codable projection of the user's dashboard that the app writes to the
/// shared App Group container and the widget reads back. This keeps the widget
/// process entirely off SwiftData/CloudKit — it only ever decodes this snapshot.
struct WidgetSnapshot: Codable, Hashable {
    /// One upcoming charge. We persist the next few so the widget can roll
    /// forward to the following event once a date passes, without the app having
    /// to re-write the snapshot.
    struct Event: Codable, Hashable, Identifiable {
        var id: String
        var name: String
        var date: Date
        /// Charge amount in the subscription's own currency (no FX applied).
        var amount: Decimal
        var currencyCode: String
        /// First charge after a free trial — rendered as "Trial".
        var isTrialEnd: Bool
        /// SF Symbol to show when no bundled logo is available.
        var symbolName: String
        /// Brand colour as "RRGGBB", or nil to fall back to the category tint.
        var brandColorHex: String?
        /// Raw `SubscriptionCategory` value, used for the fallback tint.
        var categoryRaw: String
        /// A small (≤96px) PNG of the real brand logo, baked in by the app so the
        /// widget process can draw it without a network fetch. `nil` falls back to
        /// the tinted SF-Symbol chip. Optional so old snapshots decode cleanly.
        var logoPNGData: Data? = nil

        /// Localised price like "£9.99".
        var formattedAmount: String {
            amount.formatted(.currency(code: currencyCode))
        }
    }

    /// Preferred currency the monthly total is expressed in.
    var currencyCode: String
    /// Total monthly-equivalent spend, already converted to `currencyCode`.
    var monthlyTotal: Decimal
    /// Count of non-cancelled subscriptions in scope.
    var activeCount: Int
    /// True if some active subscription couldn't be FX-converted (show a "~").
    var hasUnconvertible: Bool
    /// Active profile name, or nil for "All Profiles".
    var profileName: String?
    /// Soonest-first upcoming events (capped — see `WidgetSync.upcomingLimit`).
    var upcoming: [Event]
    /// When the app last wrote this snapshot.
    var generatedAt: Date

    /// Monthly total formatted for display, prefixed with "~" when some spend
    /// couldn't be converted.
    var formattedMonthlyTotal: String {
        let value = monthlyTotal.formatted(.currency(code: currencyCode))
        return hasUnconvertible ? "~\(value)" : value
    }
}

extension WidgetSnapshot {
    /// Sample shown in the widget gallery and while data is loading.
    static var placeholder: WidgetSnapshot {
        let now = Date()
        func day(_ n: Int) -> Date { Calendar.current.date(byAdding: .day, value: n, to: now) ?? now }
        return WidgetSnapshot(
            currencyCode: "GBP",
            monthlyTotal: Decimal(42.97),
            activeCount: 6,
            hasUnconvertible: false,
            profileName: nil,
            upcoming: [
                .init(id: "1", name: "Netflix", date: day(2), amount: Decimal(17.99),
                      currencyCode: "GBP", isTrialEnd: false, symbolName: "play.tv.fill",
                      brandColorHex: "E50914", categoryRaw: "streaming"),
                .init(id: "2", name: "Spotify", date: day(6), amount: Decimal(11.99),
                      currencyCode: "GBP", isTrialEnd: false, symbolName: "music.note",
                      brandColorHex: "1DB954", categoryRaw: "music"),
                .init(id: "3", name: "iCloud+", date: day(11), amount: Decimal(2.99),
                      currencyCode: "GBP", isTrialEnd: false, symbolName: "icloud.fill",
                      brandColorHex: nil, categoryRaw: "cloud")
            ],
            generatedAt: now
        )
    }

    /// Empty state — no subscriptions yet, or the App Group isn't readable.
    static var empty: WidgetSnapshot {
        WidgetSnapshot(
            currencyCode: Locale.current.currency?.identifier ?? "GBP",
            monthlyTotal: 0,
            activeCount: 0,
            hasUnconvertible: false,
            profileName: nil,
            upcoming: [],
            generatedAt: Date()
        )
    }
}

/// All profiles' snapshots, so the widget can switch profile in place without
/// touching SwiftData. The first slice is always "All Profiles" (id "").
struct WidgetSnapshotSet: Codable {
    struct Slice: Codable, Identifiable {
        /// Profile UUID string, or "" for All Profiles.
        var id: String
        /// Display name; nil for All Profiles.
        var name: String?
        var snapshot: WidgetSnapshot
    }

    var slices: [Slice]
    /// The profile selected in the app — what Siri answers and what the widget
    /// shows unless the user has cycled it locally.
    var appSelectedID: String

    /// Slice for `id`, falling back to the app's selection, then the first.
    func slice(for id: String?) -> Slice? {
        if let id, let match = slices.first(where: { $0.id == id }) { return match }
        return slices.first { $0.id == appSelectedID } ?? slices.first
    }
}

/// Deep links the widget hands to the app via `widgetURL`/`Link`. The widget
/// owns the containing app, so the system delivers these straight to the app's
/// `onOpenURL` — no `CFBundleURLTypes` registration needed.
enum WidgetDeepLink {
    static let scheme = "subpilot"
    /// Opens the renewals calendar.
    static let renewals = URL(string: "\(scheme)://renewals")!
    /// Opens the subscriptions home.
    static let home = URL(string: "\(scheme)://home")!
    /// Opens the add-subscription flow.
    static let add = URL(string: "\(scheme)://add")!
}
