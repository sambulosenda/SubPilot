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
    var isFreeTrial: Bool
    var trialEndDate: Date

    // Branding carried over from a catalogue draft, preserved on save.
    private let symbolName: String?
    private let logoAssetName: String?
    private let brandColorHex: String?
    private let catalogueID: String?

    init(source: Subscription) {
        name = source.name
        amount = source.amount
        currencyCode = source.currencyCode
        billingCycle = source.billingCycle
        customCycleDays = source.customCycleDays ?? 30
        nextRenewalDate = source.nextRenewalDate
        category = source.category
        notes = source.notes
        isFreeTrial = source.isFreeTrial
        trialEndDate = source.trialEndDate ?? source.nextRenewalDate
        symbolName = source.symbolName
        logoAssetName = source.logoAssetName
        brandColorHex = source.brandColorHex
        catalogueID = source.catalogueID
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var isValid: Bool { !trimmedName.isEmpty && amount >= 0 }

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
        subscription.isFreeTrial = isFreeTrial
        subscription.trialEndDate = isFreeTrial ? trialEndDate : nil
        subscription.symbolName = symbolName
        subscription.logoAssetName = logoAssetName
        subscription.brandColorHex = brandColorHex
        subscription.catalogueID = catalogueID
        subscription.updatedAt = Date()
    }
}
