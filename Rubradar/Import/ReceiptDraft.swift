//
//  ReceiptDraft.swift
//  Rubradar
//

import Foundation

/// The fields parsed out of a receipt (image / PDF / pasted text). Every field
/// is optional — the user confirms and corrects them on the form before saving.
struct ReceiptDraft: Equatable {
    var providerName: String?
    var amount: Decimal?
    var currencyCode: String?
    var billingCycle: BillingCycle?
    var nextRenewalDate: Date?
    var isFreeTrial: Bool = false

    /// True when nothing useful was parsed — the form opens essentially blank.
    var isEmpty: Bool {
        providerName == nil && amount == nil && nextRenewalDate == nil
    }

    /// Builds a pre-filled (but not yet saved) `Subscription` for the confirmation form.
    /// Branding is borrowed from the catalogue when the provider is recognised.
    func makeSubscription(referenceDate: Date = Date()) -> Subscription {
        let matched = providerName.flatMap { CatalogueLoader.match(in: $0) }
        let category = matched?.category ?? .other
        let cycle = billingCycle ?? matched?.defaultCycle ?? .monthly
        let currency = currencyCode ?? Locale.current.currency?.identifier ?? "GBP"
        let renewal = nextRenewalDate ?? cycle.nextDate(after: referenceDate)

        return Subscription(
            name: providerName ?? matched?.name ?? "",
            amount: amount ?? 0,
            currencyCode: currency,
            billingCycle: cycle,
            nextRenewalDate: renewal,
            category: category,
            isFreeTrial: isFreeTrial,
            trialEndDate: isFreeTrial ? renewal : nil,
            catalogueID: matched?.id,
            symbolName: matched?.symbolName,
            logoAssetName: matched?.logoAssetName,
            brandColorHex: matched?.brandColorHex
        )
    }
}
