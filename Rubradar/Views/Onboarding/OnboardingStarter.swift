//
//  OnboardingStarter.swift
//  Rubradar
//

import Foundation

/// A popular subscription offered in the onboarding starter step, paired with a
/// typical monthly price. The bundled catalogue carries no prices, so these are
/// curated, editable estimates — the user adjusts exact amounts later. Backed by
/// a real `CatalogueProvider` so adding one reuses the catalogue's branding/logo.
struct OnboardingStarter: Identifiable {
    let provider: CatalogueProvider
    /// Typical price in the device-locale currency, exact (built from cents).
    let monthlyPrice: Decimal

    var id: String { provider.id }

    /// Curated catalogue IDs + typical monthly price in cents. All entries are
    /// monthly-billed providers, so the cents value *is* the monthly amount and a
    /// new sub's `monthlyEquivalent` equals it (no cycle conversion needed).
    private static let curated: [(id: String, cents: Int)] = [
        ("netflix", 1599),
        ("spotify", 1199),
        ("youtube-premium", 1399),
        ("disney-plus", 1399),
        ("apple-music", 1099),
        ("chatgpt-plus", 2000),
        ("icloud-plus", 299),
        ("hulu", 1799),
        ("adobe-cc", 5499),
        ("audible", 1495),
        ("xbox-game-pass", 1699),
        ("dropbox", 1199),
    ]

    /// Builds the starter list from the bundled catalogue, preserving curated
    /// order and silently dropping any id missing from the catalogue.
    static func load() -> [OnboardingStarter] {
        let byID = Dictionary(
            CatalogueLoader.load().map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return curated.compactMap { entry in
            guard let provider = byID[entry.id] else { return nil }
            return OnboardingStarter(provider: provider, monthlyPrice: Decimal(entry.cents) / 100)
        }
    }
}
