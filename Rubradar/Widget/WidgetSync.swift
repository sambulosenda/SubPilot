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

    /// Recomputes the snapshot for the currently selected profile and reloads the
    /// widget timelines. Cheap; safe to call on launch, on background, and on
    /// CloudKit imports.
    static func refresh(modelContext: ModelContext) {
        let subscriptions = (try? modelContext.fetch(FetchDescriptor<Subscription>())) ?? []

        // Same defaults keys the views read via @AppStorage.
        let selectedProfileID = UserDefaults.standard.string(forKey: "selectedProfileID") ?? ""
        let preferred = UserDefaults.standard.string(forKey: "preferredCurrencyCode")
            ?? Locale.current.currency?.identifier ?? "GBP"

        let scoped = subscriptions.filter { $0.belongsToProfile(id: selectedProfileID) }
        let rates = CurrencyService.shared.rates
        let summary = SpendSummary.make(from: scoped, preferred: preferred, rates: rates)
        let events = RenewalProjector.events(for: scoped).prefix(upcomingLimit)

        let profileName: String? = {
            guard !selectedProfileID.isEmpty else { return nil }
            let profiles = (try? modelContext.fetch(FetchDescriptor<Profile>())) ?? []
            return profiles.first { $0.id.uuidString == selectedProfileID }?.name
        }()

        let snapshot = WidgetSnapshot(
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

        WidgetSnapshotStore.write(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
