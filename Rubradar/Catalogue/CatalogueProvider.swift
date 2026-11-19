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
    /// Registrable domain used to fetch a real logo (e.g. "netflix.com").
    let domain: String?
    /// Direct link to the provider's account/cancel page for the cancel helper.
    /// Conservative account-page URLs (they outlive deep cancel links); nil
    /// falls back to the provider domain. Optional so entries without it decode.
    let cancelURL: String?

    /// Builds a draft subscription pre-filled from this provider for the add form.
    /// Prefills the typical price of `plan` (or the provider's default plan) when
    /// we have one in the device currency; otherwise the amount stays 0 for the
    /// user to enter.
    func makeDraft(plan: CataloguePlan? = nil, referenceDate: Date = Date()) -> Subscription {
        let currencyCode = Locale.current.currency?.identifier ?? "GBP"
        let plan = plan ?? CataloguePriceBook.defaultPlan(for: id, currencyCode: currencyCode)
        let cycle = plan?.cycle ?? defaultCycle
        return Subscription(
            name: name,
            amount: plan?.amount(in: currencyCode) ?? 0,
            currencyCode: currencyCode,
            billingCycle: cycle,
            nextRenewalDate: cycle.nextDate(after: referenceDate),
            category: category,
            catalogueID: id,
            symbolName: symbolName,
            logoAssetName: logoAssetName,
            brandColorHex: brandColorHex,
            brandDomain: domain
        )
    }
}
