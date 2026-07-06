//
//  PurchaseGate.swift
//  Rubradar
//

import Foundation

/// Pure, StoreKit-free gating rules for the free tier. Kept separate from
/// `PurchaseManager` so the limits are trivially unit-testable.
enum PurchaseGate {
    /// Free tier may track up to this many active (non-cancelled) subscriptions.
    static let freeSubscriptionLimit = 5

    /// Free tier keeps a single profile; more requires Pro.
    static let freeProfileLimit = 1

    /// Whether a user may add another subscription. Pro is always allowed; free
    /// users are capped at `freeSubscriptionLimit` active subscriptions.
    static func canAddSubscription(activeCount: Int, isPro: Bool) -> Bool {
        isPro || activeCount < freeSubscriptionLimit
    }

    /// Whether a user may add another profile. Pro is always allowed; free users
    /// keep `freeProfileLimit` profile(s).
    static func canAddProfile(currentCount: Int, isPro: Bool) -> Bool {
        isPro || currentCount < freeProfileLimit
    }
}

/// Why the paywall is being shown. Drives the headline/subtitle so the upsell
/// speaks to the action the user just attempted. `Identifiable` so it can drive
/// a single `.sheet(item:)` host.
enum PaywallContext: String, Identifiable, CaseIterable {
    case subscriptionLimit
    case receiptScan
    case bankImport
    case assistant
    case profiles
    /// Shown once right after first-run onboarding — a soft upsell at peak
    /// intent. Always skippable into the free tier (see PaywallView).
    case onboarding
    case generic

    var id: String { rawValue }

    var headline: String {
        switch self {
        case .subscriptionLimit: String(localized: "Track every subscription")
        case .receiptScan:       String(localized: "Scan receipts with Pro")
        case .bankImport:        String(localized: "Import your bank statement")
        case .assistant:         String(localized: "Unlock the assistant")
        case .profiles:          String(localized: "Separate work & personal")
        case .onboarding:        String(localized: "Never pay for a subscription you forget")
        case .generic:           String(localized: "Unlock SubHelm Pro")
        }
    }

    var subtitle: String {
        switch self {
        case .subscriptionLimit:
            String(localized: "You've reached the free limit of \(PurchaseGate.freeSubscriptionLimit) subscriptions. Go unlimited with Pro.")
        case .receiptScan:
            String(localized: "Read subscription details straight from a receipt — on device — with Pro.")
        case .bankImport:
            String(localized: "Spot recurring charges in your bank statement automatically, with Pro.")
        case .assistant:
            String(localized: "Ask about your spending and renewals, answered privately on device, with Pro.")
        case .profiles:
            String(localized: "Keep personal and work subscriptions in separate profiles, with Pro.")
        case .onboarding:
            String(localized: "Unlock every Pro feature — cancel anytime in the App Store.")
        case .generic:
            String(localized: "Everything in SubHelm, unlocked.")
        }
    }
}
