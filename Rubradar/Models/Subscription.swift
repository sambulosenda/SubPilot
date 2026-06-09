//
//  Subscription.swift
//  Rubradar
//

import Foundation
import SwiftData
import SwiftUI

/// A recurring subscription tracked by the user. Stored on-device via SwiftData.
///
/// Enums are persisted as their raw `String` so the schema stays stable if cases
/// are reordered. A few forward-compatible fields (`trialEndDate`, `reminderLeadDays`,
/// `catalogueID`) carry sensible defaults so later milestones (reminders, remote
/// catalogue) don't force a schema migration.
@Model
final class Subscription {
    var id: UUID = UUID()
    var name: String = ""
    var amount: Decimal = 0
    var currencyCode: String = "GBP"

    var billingCycleRaw: String = BillingCycle.monthly.rawValue
    var customCycleDays: Int?
    var nextRenewalDate: Date = Date()

    var categoryRaw: String = SubscriptionCategory.other.rawValue
    var notes: String = ""

    // State
    var isCancelled: Bool = false
    var isFreeTrial: Bool = false
    var trialEndDate: Date?

    /// Owning profile (Personal / Business / custom). Optional for CloudKit and
    /// so existing data lightweight-migrates; the inverse lives on `Profile`.
    var profile: Profile?

    // Branding / catalogue linkage
    var catalogueID: String?
    var symbolName: String?
    var logoAssetName: String?
    var brandColorHex: String?
    /// Registrable domain (e.g. "netflix.com") used to fetch a real logo.
    var brandDomain: String?

    /// Days before the renewal/trial-end to remind. PRD default is 3.
    var reminderLeadDays: Int = 3

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        name: String = "",
        amount: Decimal = 0,
        currencyCode: String = "GBP",
        billingCycle: BillingCycle = .monthly,
        customCycleDays: Int? = nil,
        nextRenewalDate: Date = Date(),
        category: SubscriptionCategory = .other,
        notes: String = "",
        isCancelled: Bool = false,
        isFreeTrial: Bool = false,
        trialEndDate: Date? = nil,
        catalogueID: String? = nil,
        symbolName: String? = nil,
        logoAssetName: String? = nil,
        brandColorHex: String? = nil,
        brandDomain: String? = nil,
        reminderLeadDays: Int = 3,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.currencyCode = currencyCode
        self.billingCycleRaw = billingCycle.rawValue
        self.customCycleDays = customCycleDays
        self.nextRenewalDate = nextRenewalDate
        self.categoryRaw = category.rawValue
        self.notes = notes
        self.isCancelled = isCancelled
        self.isFreeTrial = isFreeTrial
        self.trialEndDate = trialEndDate
        self.catalogueID = catalogueID
        self.symbolName = symbolName
        self.logoAssetName = logoAssetName
        self.brandColorHex = brandColorHex
        self.brandDomain = brandDomain
        self.reminderLeadDays = reminderLeadDays
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}

// MARK: - Enum bridges & display helpers

extension Subscription {
    var billingCycle: BillingCycle {
        get { BillingCycle(rawValue: billingCycleRaw) ?? .monthly }
        set { billingCycleRaw = newValue.rawValue }
    }

    var category: SubscriptionCategory {
        get { SubscriptionCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    /// SF Symbol to show when no bundled logo asset is available.
    var brandSymbol: String { symbolName ?? category.defaultSymbol }

    /// Brand colour if set, otherwise the category tint.
    var displayTint: Color {
        if let hex = brandColorHex, let color = Color(hex: hex) { return color }
        return category.tint
    }

    /// Spend normalised to one month, in the subscription's own currency (no FX).
    var monthlyEquivalent: Decimal {
        let months = billingCycle.monthsPerCycle(customDays: customCycleDays)
        guard months > 0 else { return amount }
        return amount / months
    }

    /// The next renewal — or first post-trial charge — at or after `now`, rolling
    /// the stored `nextRenewalDate` anchor forward by the billing cycle. The anchor
    /// is never advanced once a charge passes, so every surface that shows "the next
    /// renewal" (Home row, detail, sort, reminders) must project from it rather than
    /// read it raw. Mirrors `RenewalProjector`; a free trial anchors on its end date.
    func projectedNextRenewal(asOf now: Date = Date(), calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: now)
        var date = (isFreeTrial && trialEndDate != nil) ? trialEndDate! : nextRenewalDate
        var steps = 0
        while date < start && steps < 600 {
            date = billingCycle.nextDate(after: date, customDays: customCycleDays, calendar: calendar)
            steps += 1
        }
        return date
    }

    /// Localised price like "£9.99".
    var formattedAmount: String {
        amount.formatted(.currency(code: currencyCode))
    }

    /// Compact price + cycle like "£9.99 / mo".
    var priceLabel: String {
        "\(formattedAmount) / \(billingCycle.shortLabel)"
    }
}

// MARK: - Hex colour parsing

extension Color {
    /// Parses "#RRGGBB" / "RRGGBB". Returns nil on malformed input.
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt64(s, radix: 16) else { return nil }
        let r = Double((value & 0xFF0000) >> 16) / 255
        let g = Double((value & 0x00FF00) >> 8) / 255
        let b = Double(value & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
