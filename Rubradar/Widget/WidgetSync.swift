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

@MainActor
enum WidgetSync {
    /// How many upcoming events to persist so the widget can roll forward on its
    /// own (counting down day by day) before the app next writes a snapshot.
    private static let upcomingLimit = 5

    /// Recomputes one snapshot per profile (plus All Profiles) and reloads the
    /// widget timelines. The per-profile set is what lets the widget's profile
    /// button switch scope in place. Cheap; safe to call on launch, on
    /// background, and on CloudKit imports.
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

        var slices = [WidgetSnapshotSet.Slice(
            id: "",
            name: nil,
            snapshot: snapshot(for: "", from: subscriptions, profileName: nil,
                               preferred: preferred, rates: rates)
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
                                       preferred: preferred, rates: rates)
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
        rates: ExchangeRates
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
                    categoryRaw: sub.categoryRaw
                )
            },
            generatedAt: Date()
        )
    }
}
