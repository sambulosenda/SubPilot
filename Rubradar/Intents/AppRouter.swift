//
//  AppRouter.swift
//  Rubradar
//

import Foundation
import Observation

/// Navigation request handed from an App Intent to the app shell. Intents with
/// `openAppWhenRun` execute inside the app's process, so they can set
/// `AppRouter.shared.pendingAction` directly and `RootView` picks it up —
/// no URL-scheme registration needed (mirrors how widget deep links route,
/// but in-process).
@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()

    enum Action: Equatable {
        /// Present the add-subscription flow (routed through the Pro gates).
        case addSubscription
        /// Show the renewals calendar tab.
        case showRenewals
        /// Show the Home (subscriptions) tab.
        case showHome
    }

    var pendingAction: Action?

    private init() {}

    /// Maps a widget deep link (subpilot://renewals | home | add) onto a
    /// pending action. Widget URLs are buffered here rather than handled in a
    /// view's `.onOpenURL` so a cold launch can't drop them — `RootView` (and
    /// its URL handler) mounts ~1.6s after the splash, after delivery.
    static func action(for url: URL) -> Action? {
        guard url.scheme == WidgetDeepLink.scheme else { return nil }
        switch url.host {
        case "renewals": return .showRenewals
        case "home": return .showHome
        case "add": return .addSubscription
        default: return nil
        }
    }
}
