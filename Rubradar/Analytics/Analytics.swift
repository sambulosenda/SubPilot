//
//  Analytics.swift
//  Rubradar
//

import Foundation
#if canImport(TelemetryDeck)
import TelemetryDeck
#endif

/// Single chokepoint for product analytics. The rest of the app fires typed,
/// intention-revealing events through here and never imports the SDK directly —
/// so swapping or disabling analytics is a one-file change.
///
/// Privacy: TelemetryDeck is anonymous by design (no account, no IDFA, a salted
/// per-vendor id). We deliberately send only non-identifying signals — add
/// methods, paywall gate names, counts, and product tiers — never subscription
/// names, amounts, notes, or any user content. Keeps the "private by default"
/// promise (and the "Data Not Collected" privacy label) honest.
///
/// All calls are no-ops until the TelemetryDeck package is linked (the
/// `canImport` guards), so the app builds and runs unchanged without it.
enum Analytics {
    /// TelemetryDeck app id (a public client identifier — safe to commit).
    private static let appID = "C9101599-ED3E-42DB-AAF5-C351A3412047"

    /// UserDefaults key backing the Settings opt-out. Shared with the
    /// `@AppStorage(Analytics.optInDefaultsKey)` toggle so the two stay in sync.
    static let optInDefaultsKey = "analyticsOptIn"

    /// Whether the user permits anonymous analytics. Defaults to on; the Settings
    /// toggle persists the choice here.
    static var isOptedIn: Bool {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: optInDefaultsKey) == nil
            ? true
            : defaults.bool(forKey: optInDefaultsKey)
    }

    /// Prevents re-initializing the SDK if the user opts out then back in within a
    /// single launch. Only ever touched on the main thread (app init + the
    /// Settings toggle), so the unchecked access is safe.
    nonisolated(unsafe) private static var didInitialize = false

    /// Screenshot/demo runs seed fake data; never let that reach the dashboard.
    private static var isDemoSeed: Bool {
        ProcessInfo.processInfo.arguments.contains("-DemoSeed")
    }

    /// Call once, as early as possible (app init). No-ops if the user has opted
    /// out, on demo runs, or if already started this launch.
    static func start() {
        guard isOptedIn, !isDemoSeed, !didInitialize else { return }
        #if canImport(TelemetryDeck)
        let config = TelemetryDeck.Config(appID: appID)
        #if DEBUG
        // Dev signals land under the dashboard's "Test mode" toggle, kept
        // separate from production metrics.
        config.testMode = true
        #endif
        TelemetryDeck.initialize(config: config)
        didInitialize = true
        #endif
    }

    /// Persists the user's analytics choice. Opting in starts the SDK right away;
    /// opting out stops all further events (and fully takes effect next launch,
    /// when the SDK simply isn't initialized — so nothing is sent at all).
    static func setOptedIn(_ optedIn: Bool) {
        UserDefaults.standard.set(optedIn, forKey: optInDefaultsKey)
        if optedIn { start() }
    }

    // MARK: - Funnel events

    /// First-run flow finished (or was skipped through).
    static func onboardingCompleted() {
        send("onboardingCompleted")
    }

    /// A subscription was added. `method` is the activation question we care about
    /// most: does a fast bulk path (scan/bank) beat one-at-a-time manual entry?
    /// `totalActive` is the user's active subscription count after the add.
    static func subscriptionAdded(method: AddMethod, totalActive: Int) {
        send("subscriptionAdded",
             parameters: ["method": method.rawValue],
             floatValue: Double(totalActive))
    }

    /// The paywall was presented. `context` is the gate that triggered it (which
    /// feature drives upsells); `activeCount` is how many subs the user had.
    static func paywallShown(context: PaywallContext, activeCount: Int) {
        send("paywallShown",
             parameters: ["context": context.rawValue],
             floatValue: Double(activeCount))
    }

    /// A purchase unlocked Pro. `product` is the tier (monthly/annual/lifetime);
    /// `context` attributes the conversion to the gate that opened the paywall.
    static func purchaseCompleted(product: String, context: PaywallContext?) {
        send("purchaseCompleted",
             parameters: ["product": product,
                          "context": context?.rawValue ?? "unknown"])
    }

    // MARK: - Plumbing

    private static func send(_ name: String,
                             parameters: [String: String] = [:],
                             floatValue: Double? = nil) {
        guard isOptedIn, !isDemoSeed else { return }
        #if canImport(TelemetryDeck)
        TelemetryDeck.signal(name, parameters: parameters, floatValue: floatValue)
        #endif
    }
}

/// How a subscription entered the app. Raw values are stable analytics keys —
/// don't localize or rename them without updating the dashboard.
enum AddMethod: String {
    case manual
    case catalogue
    case scan
    case bankImport
    case share
}
