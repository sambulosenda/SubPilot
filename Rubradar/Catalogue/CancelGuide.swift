//
//  CancelGuide.swift
//  Rubradar
//

import Foundation

/// Everything the cancel-helper sheet needs for one subscription: where to
/// cancel on the provider's side, plus the Apple route. Pure (no SwiftData
/// queries) so it unit-tests like `TrialRadar`.
struct CancelGuide {
    let subscriptionName: String
    /// Provider-side cancellation page: the curated catalogue `cancelURL` when
    /// we have one, else the subscription's own link/domain. Nil when we know
    /// nothing about where this provider lives.
    let providerURL: URL?
    /// Whether `providerURL` is a curated account/cancel page (vs a bare domain).
    let isDirect: Bool

    /// iOS intercepts this and opens the native App Store subscription manager.
    static let appleSubscriptions = URL(string: "https://apps.apple.com/account/subscriptions")!

    /// True when the provider bills through Apple (Apple's own services), so the
    /// sheet shows a single Apple route instead of two identical buttons.
    var isAppleBilled: Bool { providerURL == Self.appleSubscriptions }

    static func make(for subscription: Subscription,
                     providers: [CatalogueProvider]? = nil) -> CancelGuide {
        let all = providers ?? CatalogueLoader.load()
        // Prefer the linked catalogue entry; fall back to a name match so a
        // manually-typed "Netflix" still gets the curated page.
        let provider = subscription.catalogueID.flatMap { id in all.first { $0.id == id } }
            ?? CatalogueLoader.match(in: subscription.name, providers: all)

        if let raw = provider?.cancelURL, let url = URL(string: raw) {
            return CancelGuide(subscriptionName: subscription.name, providerURL: url, isDirect: true)
        }
        return CancelGuide(subscriptionName: subscription.name,
                           providerURL: subscription.providerURL, isDirect: false)
    }
}
