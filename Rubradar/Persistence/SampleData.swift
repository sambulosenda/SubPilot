//
//  SampleData.swift
//  Rubradar
//

import Foundation
import SwiftData

/// Seeds an in-memory context with varied subscriptions for previews and demos.
enum SampleData {
    @MainActor
    static func seed(into context: ModelContext) {
        let personal = Profile(name: "Personal", symbolName: "person.crop.circle.fill",
                               colorHex: "30B0A6", sortIndex: 0)
        let business = Profile(name: "Business", symbolName: "briefcase.fill",
                               colorHex: "0A84FF", sortIndex: 1)
        context.insert(personal)
        context.insert(business)

        let samples = makeSamples()
        for (index, sub) in samples.enumerated() {
            context.insert(sub)
            // Spread a few onto Business so the switcher has something to show.
            sub.profile = (index % 3 == 0) ? business : personal
        }
    }

    static func makeSamples(referenceDate: Date = Date()) -> [Subscription] {
        let cal = Calendar.current
        func days(_ n: Int) -> Date { cal.date(byAdding: .day, value: n, to: referenceDate) ?? referenceDate }

        return [
            Subscription(
                name: "Netflix",
                amount: 17.99,
                currencyCode: "USD",
                billingCycle: .monthly,
                nextRenewalDate: days(5),
                category: .streaming,
                catalogueID: "netflix",
                symbolName: "play.tv.fill",
                brandColorHex: "#E50914",
                brandDomain: "netflix.com"
            ),
            Subscription(
                name: "Spotify Premium",
                amount: 11.99,
                currencyCode: "USD",
                billingCycle: .monthly,
                nextRenewalDate: days(12),
                category: .music,
                catalogueID: "spotify",
                symbolName: "music.note",
                brandColorHex: "#1DB954",
                brandDomain: "spotify.com"
            ),
            Subscription(
                name: "Adobe Creative Cloud",
                amount: 59.99,
                currencyCode: "USD",
                billingCycle: .monthly,
                nextRenewalDate: days(20),
                category: .software,
                catalogueID: "adobe-cc",
                symbolName: "app.badge.fill",
                brandColorHex: "#FF0000",
                brandDomain: "adobe.com"
            ),
            Subscription(
                name: "ChatGPT Plus",
                amount: 20.00,
                currencyCode: "USD",
                billingCycle: .monthly,
                nextRenewalDate: days(2),
                category: .software,
                isFreeTrial: true,
                trialEndDate: days(2),
                catalogueID: "chatgpt-plus",
                symbolName: "bubble.left.and.text.bubble.right.fill",
                brandDomain: "openai.com"
            ),
            Subscription(
                name: "Old Gym Membership",
                amount: 39.99,
                currencyCode: "USD",
                billingCycle: .monthly,
                nextRenewalDate: days(-3),
                category: .fitness,
                isCancelled: true,
                symbolName: "figure.run"
            ),
            Subscription(
                name: "Disney+ Annual",
                amount: 109.90,
                currencyCode: "USD",
                billingCycle: .yearly,
                nextRenewalDate: days(120),
                category: .streaming,
                catalogueID: "disney-plus",
                symbolName: "sparkles.tv.fill",
                brandColorHex: "#113CCF",
                brandDomain: "disneyplus.com"
            ),
        ]
    }
}
