//
//  CataloguePlan.swift
//  Rubradar
//

import Foundation

/// A named price tier for a catalogue provider ("Standard", "Family", …).
///
/// Prices are *typical* list prices, not live data — they prefill the add flow
/// so most users only confirm rather than type, and stay fully editable. A plan
/// only carries the currencies we have a price for; there is deliberately no
/// FX conversion, because a converted price is wrong in a way that looks right.
struct CataloguePlan: Codable, Hashable, Identifiable {
    let name: String
    let cycle: BillingCycle
    /// Price in minor units (cents/pence) keyed by ISO currency code. Integers,
    /// not decimals: JSON floats decode to `Decimal` through `Double` and come
    /// out as 17.989999….
    let amounts: [String: Int]
    /// Marks the tier to preselect when it isn't the first one listed.
    let isDefault: Bool?

    var id: String { "\(name)-\(cycle.rawValue)" }

    func amount(in currencyCode: String) -> Decimal? {
        amounts[currencyCode].map { Decimal($0) / 100 }
    }
}

/// The bundled table of typical plan prices, keyed by catalogue provider id.
/// Kept apart from `catalogue.json` so prices can be refreshed without touching
/// the provider list.
enum CataloguePriceBook {
    private struct PriceFile: Codable {
        let version: Int
        let plans: [String: [CataloguePlan]]
    }

    /// Decoded once; the file is small and read on every catalogue pick.
    private static let bundled: [String: [CataloguePlan]] = load()

    static func load(bundle: Bundle = .main) -> [String: [CataloguePlan]] {
        guard let url = bundle.url(forResource: "catalogue-prices", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(PriceFile.self, from: data)
        else {
            return [:]
        }
        return file.plans
    }

    /// The provider's plans that have a price in `currencyCode`, in listed order.
    static func plans(
        for providerID: String,
        currencyCode: String,
        in book: [String: [CataloguePlan]]? = nil
    ) -> [CataloguePlan] {
        ((book ?? bundled)[providerID] ?? []).filter { $0.amounts[currencyCode] != nil }
    }

    /// The plan to preselect: the flagged default, else the first listed.
    static func defaultPlan(
        for providerID: String,
        currencyCode: String,
        in book: [String: [CataloguePlan]]? = nil
    ) -> CataloguePlan? {
        let available = plans(for: providerID, currencyCode: currencyCode, in: book)
        return available.first { $0.isDefault == true } ?? available.first
    }
}
