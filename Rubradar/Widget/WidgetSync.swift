//
//  WidgetSync.swift
//  Rubradar
//
//  App-only. Builds a `WidgetSnapshot` from the live store + user prefs and hands
//  it to the widget via the App Group, then asks WidgetKit to reload. Reuses the
//  exact `SpendSummary`/`RenewalProjector` the Home screen renders, so the widget
//  can never disagree with the app.
//

import Foundation
import SwiftData
import WidgetKit
#if canImport(UIKit)
import UIKit
#endif

@MainActor
enum WidgetSync {
    /// How many upcoming events to persist so the widget can roll forward on its
    /// own (counting down day by day) before the app next writes a snapshot.
    private static let upcomingLimit = 5

    /// Recomputes one snapshot per profile (plus All Profiles) and reloads the
    /// widget timelines. The per-profile set is what lets the widget's profile
    /// button switch scope in place. Cheap; safe to call on launch, on
    /// background, and on CloudKit imports.
    ///
    /// Two-pass: an immediate synchronous write (tinted SF-Symbol chips) so the
    /// widget never blocks, then a background pass that bakes in real brand logos
    /// and rewrites once they're resolved from the cache (or network on a miss).
    static func refresh(modelContext: ModelContext) {
        let subscriptions = (try? modelContext.fetch(FetchDescriptor<Subscription>())) ?? []
        let profiles = (try? modelContext.fetch(
            FetchDescriptor<Profile>(sortBy: [SortDescriptor(\.sortIndex)])
        )) ?? []

        // Same defaults keys the views read via @AppStorage.
        let selectedProfileID = UserDefaults.standard.string(forKey: "selectedProfileID") ?? ""
        let preferred = UserDefaults.standard.string(forKey: "preferredCurrencyCode")
            ?? Locale.current.currency?.identifier ?? "GBP"
        let rates = CurrencyService.shared.rates

        write(subscriptions: subscriptions, profiles: profiles,
              selectedProfileID: selectedProfileID, preferred: preferred,
              rates: rates, logos: [:])

        // Enrich with real brand logos, then rewrite. The models stay on the main
        // actor (this Task is @MainActor); only the logo.dev fetch suspends.
        #if canImport(UIKit)
        Task { @MainActor in
            let logos = await resolveLogos(for: subscriptions)
            guard !logos.isEmpty else { return }
            write(subscriptions: subscriptions, profiles: profiles,
                  selectedProfileID: selectedProfileID, preferred: preferred,
                  rates: rates, logos: logos)
        }
        #endif
    }

    /// Builds the per-profile slice set with the given baked logos and hands it to
    /// the widget, then reloads timelines.
    private static func write(
        subscriptions: [Subscription],
        profiles: [Profile],
        selectedProfileID: String,
        preferred: String,
        rates: ExchangeRates,
        logos: [String: Data]
    ) {
        var slices = [WidgetSnapshotSet.Slice(
            id: "",
            name: nil,
            snapshot: snapshot(for: "", from: subscriptions, profileName: nil,
                               preferred: preferred, rates: rates, logos: logos)
        )]
        // A lone profile renders identically to All Profiles — skip the slices
        // so the widget doesn't offer a no-op cycle button.
        if profiles.count > 1 {
            slices += profiles.map { profile in
                let id = profile.id.uuidString
                return WidgetSnapshotSet.Slice(
                    id: id,
                    name: profile.name,
                    snapshot: snapshot(for: id, from: subscriptions, profileName: profile.name,
                                       preferred: preferred, rates: rates, logos: logos)
                )
            }
        }

        WidgetSnapshotStore.write(WidgetSnapshotSet(slices: slices, appSelectedID: selectedProfileID))
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// One profile's snapshot, via the exact summary/projection the app renders.
    private static func snapshot(
        for profileID: String,
        from subscriptions: [Subscription],
        profileName: String?,
        preferred: String,
        rates: ExchangeRates,
        logos: [String: Data]
    ) -> WidgetSnapshot {
        let scoped = subscriptions.filter { $0.belongsToProfile(id: profileID) }
        let summary = SpendSummary.make(from: scoped, preferred: preferred, rates: rates)
        let events = RenewalProjector.events(for: scoped).prefix(upcomingLimit)

        return WidgetSnapshot(
            currencyCode: preferred,
            monthlyTotal: summary.monthlyTotal,
            activeCount: scoped.filter { !$0.isCancelled }.count,
            hasUnconvertible: summary.hasUnconvertible,
            profileName: profileName,
            upcoming: events.map { event in
                let sub = event.subscription
                return WidgetSnapshot.Event(
                    id: event.id,
                    name: sub.name,
                    date: event.date,
                    amount: sub.amount,
                    currencyCode: sub.currencyCode,
                    isTrialEnd: event.isTrialEnd,
                    symbolName: sub.brandSymbol,
                    brandColorHex: sub.brandColorHex,
                    categoryRaw: sub.categoryRaw,
                    logoPNGData: logoKey(for: sub).flatMap { logos[$0] }
                )
            },
            generatedAt: Date()
        )
    }

    // MARK: - Logo baking

    /// A stable cache/lookup key for a subscription's logo source.
    private static func logoKey(for sub: Subscription) -> String? {
        if let name = sub.logoAssetName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return "asset:\(name)"
        }
        if let domain = sub.brandDomain?.trimmingCharacters(in: .whitespacesAndNewlines), !domain.isEmpty {
            return "domain:\(domain.lowercased())"
        }
        return nil
    }

    #if canImport(UIKit)
    /// Resolves one small PNG per distinct logo across the user's subscriptions,
    /// keyed by `logoKey`. De-duplicated so each brand is fetched at most once.
    private static func resolveLogos(for subscriptions: [Subscription]) async -> [String: Data] {
        var result: [String: Data] = [:]
        var seen = Set<String>()
        for sub in subscriptions {
            guard let key = logoKey(for: sub), !seen.contains(key) else { continue }
            seen.insert(key)
            if let data = await logoData(for: sub) { result[key] = data }
        }
        return result
    }

    /// Bundled asset first (instant), then logo.dev by domain (cached/offlineable).
    private static func logoData(for sub: Subscription) async -> Data? {
        if let name = sub.logoAssetName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty, let image = UIImage(named: name) {
            return pngData(from: image)
        }
        if let domain = sub.brandDomain?.trimmingCharacters(in: .whitespacesAndNewlines),
           !domain.isEmpty, let image = await BrandLogoStore.shared.image(for: domain) {
            return pngData(from: image)
        }
        return nil
    }

    /// Downscales to ≤`maxDimension`px and returns PNG bytes — small enough to keep
    /// the App Group payload light across 5 events × several profiles.
    private static func pngData(from image: UIImage, maxDimension: CGFloat = 96) -> Data? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1)
        let target = CGSize(width: (size.width * scale).rounded(),
                            height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1          // target is already in pixels
        format.opaque = false     // preserve logo transparency
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.pngData()
    }
    #endif
}
