//
//  PurchaseManager.swift
//  Rubradar
//

import Foundation
import StoreKit
import Observation

/// Owns the StoreKit 2 lifecycle and the app-wide Pro entitlement. Mirrors the
/// `CurrencyService` shape: a `@MainActor @Observable` singleton injected at the
/// app root and read via `@Environment(PurchaseManager.self)`.
///
/// `isPro` is cached in `UserDefaults` so feature gates are correct instantly at
/// launch — even offline — then reconciled against the live entitlement set.
@MainActor
@Observable
final class PurchaseManager {
    static let shared = PurchaseManager()

    /// Product identifiers — must match App Store Connect and `Products.storekit`.
    enum ProductID {
        static let monthly  = "com.sambulosenda.subradar.pro.monthly"
        static let annual   = "com.sambulosenda.subradar.pro.annual"
        static let lifetime = "com.sambulosenda.subradar.pro.lifetime"

        /// Display order: annual first (the default + best-value option the
        /// paywall steers toward), then monthly, then lifetime.
        static let all: [String] = [annual, monthly, lifetime]
    }

    private static let isProDefaultsKey = "isProEntitlement"

    /// Loaded products in display order. Empty until `loadProducts()` succeeds.
    private(set) var products: [Product] = []
    private(set) var isLoadingProducts = false
    /// Whether the user holds the Pro entitlement (cached; reconciled on launch).
    private(set) var isPro: Bool
    /// True while a purchase or restore is in flight (drives CTA spinner/disable).
    private(set) var purchaseInProgress = false

    /// Set by any feature gate to request the paywall. `RootView` hosts the one
    /// `.sheet(item:)` bound to this, so any view can trigger the upsell.
    var paywallContext: PaywallContext?

    /// User-visible outcome of the last explicit purchase/restore attempt.
    /// The paywall binds an alert to this; a silent outcome (user cancelled,
    /// success) never sets it. Cleared by the alert's dismiss.
    var feedback: PurchaseFeedback?

    private init() {
        isPro = UserDefaults.standard.bool(forKey: Self.isProDefaultsKey)
        // Listen for transactions signed outside an explicit purchase call:
        // renewals, Ask-to-Buy approvals, and purchases made on other devices.
        Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        // Reconcile the cached flag against the real entitlement set.
        Task { await refreshEntitlements() }
    }

    /// Preview/test manager with a fixed entitlement and no StoreKit observation —
    /// never touches the App Store, so previews stay self-contained. NOT gated to
    /// DEBUG: `#Preview` bodies compile into Release archives too, so the factory
    /// they call must exist in every configuration or `xcodebuild archive` fails.
    init(previewIsPro: Bool) {
        isPro = previewIsPro
    }

    static func preview(isPro: Bool = true) -> PurchaseManager {
        PurchaseManager(previewIsPro: isPro)
    }

#if DEBUG
    /// Pro-unlocked, StoreKit-free instance injected by `-DemoSeed` screenshot
    /// runs so Pro-only screens (Assistant) capture their real UI, not the gate.
    static let demo = PurchaseManager(previewIsPro: true)
#endif

    // MARK: - Products

    /// Fetches the products once. Safe to call repeatedly (e.g. each paywall open).
    func loadProducts() async {
        guard products.isEmpty, !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let loaded = try await Product.products(for: ProductID.all)
            // Re-order to the canonical display order (annual → monthly → lifetime)
            // regardless of the order StoreKit returns them in.
            products = ProductID.all.compactMap { id in loaded.first { $0.id == id } }
        } catch {
            // Leave products empty; the paywall offers a retry.
        }
    }

    func product(for id: String) -> Product? { products.first { $0.id == id } }

    /// Stable, non-localized tier key for analytics (the paywall's display labels
    /// are localized, so they must not be used as event values).
    private static func tierKey(for productID: String) -> String {
        switch productID {
        case ProductID.monthly:  return "monthly"
        case ProductID.annual:   return "annual"
        case ProductID.lifetime: return "lifetime"
        default:                 return "other"
        }
    }

    // MARK: - Purchase / restore

    /// Attempts a purchase. Returns `true` if Pro is unlocked as a result.
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        guard !purchaseInProgress else { return false }
        purchaseInProgress = true
        defer { purchaseInProgress = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard let transaction = verified(verification) else {
                    feedback = .purchaseFailed(message: String(localized: "The App Store receipt couldn't be verified. You haven't been charged — please try again."))
                    return false
                }
                await transaction.finish()
                await refreshEntitlements()
                if isPro {
                    Analytics.purchaseCompleted(product: Self.tierKey(for: product.id), context: paywallContext)
                }
                return isPro
            case .userCancelled:
                return false
            case .pending:
                // Ask to Buy: the family organizer must approve. The
                // `Transaction.updates` listener unlocks Pro when they do.
                feedback = .purchasePending
                return false
            @unknown default:
                return false
            }
        } catch StoreKitError.userCancelled {
            return false
        } catch {
            // A user who tried to pay and got silence assumes the app is
            // broken — surface every non-cancellation failure.
            feedback = .purchaseFailed(message: error.localizedDescription)
            return false
        }
    }

    /// Restores past purchases: syncs with the App Store, then re-checks entitlements.
    func restore() async {
        guard !purchaseInProgress else { return }
        purchaseInProgress = true
        defer { purchaseInProgress = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if !isPro { feedback = .nothingToRestore }
        } catch StoreKitError.userCancelled {
            // Backed out of the App Store sign-in — silence is correct.
        } catch {
            feedback = .restoreFailed(message: error.localizedDescription)
        }
    }

    // MARK: - Entitlements

    /// Recomputes `isPro` from the live entitlement set and caches the result.
    func refreshEntitlements() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            guard let transaction = verified(result) else { continue }
            if ProductID.all.contains(transaction.productID), transaction.revocationDate == nil {
                entitled = true
            }
        }
        setPro(entitled)
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard let transaction = verified(result) else { return }
        await transaction.finish()
        await refreshEntitlements()
    }

    /// Unwraps a StoreKit verification result, dropping unverified transactions.
    private func verified(_ result: VerificationResult<Transaction>) -> Transaction? {
        guard case .verified(let transaction) = result else { return nil }
        return transaction
    }

    private func setPro(_ value: Bool) {
        if isPro != value { isPro = value }
        UserDefaults.standard.set(value, forKey: Self.isProDefaultsKey)
    }
}

/// A purchase/restore outcome the user must be told about. Success and
/// cancellation stay silent; everything else gets an alert on the paywall.
enum PurchaseFeedback: Identifiable, Equatable {
    /// The purchase failed after the user committed (network, payment issue).
    case purchaseFailed(message: String)
    /// Ask to Buy — waiting for the family organizer's approval.
    case purchasePending
    /// Restore ran but found no prior purchase on this Apple Account.
    case nothingToRestore
    /// The App Store sync behind Restore failed.
    case restoreFailed(message: String)

    var id: String {
        switch self {
        case .purchaseFailed: "purchaseFailed"
        case .purchasePending: "purchasePending"
        case .nothingToRestore: "nothingToRestore"
        case .restoreFailed: "restoreFailed"
        }
    }

    var title: String {
        switch self {
        case .purchaseFailed: String(localized: "Purchase Failed")
        case .purchasePending: String(localized: "Waiting for Approval")
        case .nothingToRestore: String(localized: "Nothing to Restore")
        case .restoreFailed: String(localized: "Restore Failed")
        }
    }

    var message: String {
        switch self {
        case .purchaseFailed(let message), .restoreFailed(let message):
            message
        case .purchasePending:
            String(localized: "Ask your family organizer to approve the purchase — Pro unlocks automatically once they do.")
        case .nothingToRestore:
            String(localized: "No previous purchases were found for this Apple Account.")
        }
    }
}
