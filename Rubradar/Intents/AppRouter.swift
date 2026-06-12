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
    }

    var pendingAction: Action?

    private init() {}
}
