//
//  CatalogueProvider.swift
//  Rubradar
//

import Foundation

/// A known provider from the bundled catalogue.
struct CatalogueProvider: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let category: SubscriptionCategory
    let symbolName: String
    let logoAssetName: String?
    let defaultCycle: BillingCycle
    let brandColorHex: String?

    /// Builds a draft subscription pre-filled from this provider for the add form.
    func makeDraft(referenceDate: Date = Date()) -> Subscription {
        Subscription(
            name: name,
            amount: 0,
            currencyCode: Locale.current.currency?.identifier ?? "GBP",
            billingCycle: defaultCycle,
            nextRenewalDate: defaultCycle.nextDate(after: referenceDate),
            category: category,
            catalogueID: id,
            symbolName: symbolName,
            logoAssetName: logoAssetName,
            brandColorHex: brandColorHex
        )
    }
}
