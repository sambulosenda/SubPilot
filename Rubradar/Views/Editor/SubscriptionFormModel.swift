//
//  SubscriptionFormModel.swift
//  Rubradar
//

import Foundation
import Observation

enum FormMode {
    case create(Subscription)   // draft (blank or catalogue-prefilled)
    case edit(Subscription)     // existing stored model

    var isEditing: Bool {
        if case .edit = self { return true }
        return false
    }
}

/// Editable working copy of a subscription's fields. Kept separate from the
/// `@Model` so "Cancel" discards changes cleanly — values are only written back
/// to SwiftData on Save.
@Observable
final class SubscriptionFormModel {
    var name: String
    var amount: Decimal
    var currencyCode: String
    var billingCycle: BillingCycle
    var customCycleDays: Int
    var nextRenewalDate: Date
    var category: SubscriptionCategory
    var notes: String
    var linkURL: String
    var reminderLeadDays: Int
    var isFreeTrial: Bool
    var trialEndDate: Date

    // Branding carried over from a catalogue draft, preserved on save.
    // `var` so a catalogue pick or receipt scan can fill the open form in place.
    private var symbolName: String?
    private var logoAssetName: String?
    private var brandColorHex: String?
    private var brandDomain: String?
    private var catalogueID: String?

    init(source: Subscription) {
        name = source.name
        amount = source.amount
        currencyCode = source.currencyCode
        billingCycle = source.billingCycle
        customCycleDays = source.customCycleDays ?? 30
        nextRenewalDate = source.nextRenewalDate
        category = source.category
        notes = source.notes
        linkURL = source.linkURL ?? ""
        reminderLeadDays = source.reminderLeadDays
        isFreeTrial = source.isFreeTrial
        trialEndDate = source.trialEndDate ?? source.nextRenewalDate
        symbolName = source.symbolName
        logoAssetName = source.logoAssetName
        brandColorHex = source.brandColorHex
        brandDomain = source.brandDomain
        catalogueID = source.catalogueID
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var isValid: Bool { !trimmedName.isEmpty && amount >= 0 }

    /// Overwrites the working copy from a freshly-built draft (catalogue pick or
    /// parsed receipt) so the open form fills in place — no second form sheet.
    /// The user can still edit anything afterwards before saving.
    func fill(from source: Subscription) {
        name = source.name
        amount = source.amount
        currencyCode = source.currencyCode
        billingCycle = source.billingCycle
        customCycleDays = source.customCycleDays ?? customCycleDays
        nextRenewalDate = source.nextRenewalDate
        category = source.category
        isFreeTrial = source.isFreeTrial
        trialEndDate = source.trialEndDate ?? source.nextRenewalDate
        symbolName = source.symbolName
        logoAssetName = source.logoAssetName
        brandColorHex = source.brandColorHex
        brandDomain = source.brandDomain
        catalogueID = source.catalogueID
    }

    /// Applies just the category + branding of a recognised provider. Used by the
    /// name auto-detect, which must not clobber the amount/cycle the user is typing.
    func applyBrand(_ provider: CatalogueProvider) {
        // Idempotent: the name auto-detect calls this on every keystroke once a
        // provider matches. Re-applying the same brand would write identical
        // values to the observable model and trigger redundant view updates.
        guard catalogueID != provider.id else { return }
        category = provider.category
        catalogueID = provider.id
        symbolName = provider.symbolName
        logoAssetName = provider.logoAssetName
        brandColorHex = provider.brandColorHex
        brandDomain = provider.domain
    }

    /// Writes the working values onto a stored `Subscription`.
    func apply(to subscription: Subscription) {
        subscription.name = trimmedName
        subscription.amount = amount
        subscription.currencyCode = currencyCode
        subscription.billingCycle = billingCycle
        subscription.customCycleDays = billingCycle == .custom ? customCycleDays : nil
        subscription.nextRenewalDate = nextRenewalDate
        subscription.category = category
        subscription.notes = notes
        let trimmedLink = linkURL.trimmingCharacters(in: .whitespacesAndNewlines)
        subscription.linkURL = trimmedLink.isEmpty ? nil : trimmedLink
        subscription.reminderLeadDays = reminderLeadDays
        subscription.isFreeTrial = isFreeTrial
        subscription.trialEndDate = isFreeTrial ? trialEndDate : nil
        subscription.symbolName = symbolName
        subscription.logoAssetName = logoAssetName
        subscription.brandColorHex = brandColorHex
        subscription.brandDomain = brandDomain
        subscription.catalogueID = catalogueID
        subscription.updatedAt = Date()
    }
}
