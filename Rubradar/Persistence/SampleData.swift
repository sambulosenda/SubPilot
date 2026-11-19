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

        // `-DemoAttention` adds a recent price rise, a notice period and an
        // unused streak so Home's "Needs attention" rows and the monthly
        // check-in can be exercised. Opt-in, so the default
        // seed (and the App Store screenshots taken from it) stays as it was.
        if ProcessInfo.processInfo.arguments.contains("-DemoAttention") {
            if let netflix = samples.first(where: { $0.name == "Netflix" }) {
                let rise = PriceChange(oldAmount: 15.49, newAmount: netflix.amount,
                                       currencyCode: netflix.currencyCode, source: .bankImport,
                                       changedAt: Date(timeIntervalSinceNow: -4 * 86_400))
                rise.subscription = netflix
                context.insert(rise)
            }
            samples.first(where: { $0.name == "Spotify Premium" })?.noticePeriod = .twoWeeks
            samples.first(where: { $0.name == "YouTube Premium" })?.unusedMonths = 2
            // Old enough for the monthly usage check-in to ask about them.
            let twoMonthsAgo = Date(timeIntervalSinceNow: -60 * 86_400)
            samples.forEach { $0.createdAt = twoMonthsAgo }
        }
    }

    static func makeSamples(referenceDate: Date = Date()) -> [Subscription] {
        let cal = Calendar.current
        func days(_ n: Int) -> Date { cal.date(byAdding: .day, value: n, to: referenceDate) ?? referenceDate }

        // A renewal on the Nth of the *current* month, so the calendar grid always
        // shows dots regardless of what day the screenshots are captured. Clamped
        // to a valid day for the month.
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: referenceDate)) ?? referenceDate
        func dayOfMonth(_ n: Int) -> Date {
            cal.date(byAdding: .day, value: n - 1, to: monthStart) ?? referenceDate
        }

        return [
            Subscription(
                name: "Netflix",
                amount: 17.99,
                currencyCode: "USD",
                billingCycle: .monthly,
                nextRenewalDate: dayOfMonth(4),
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
                nextRenewalDate: dayOfMonth(9),
                category: .music,
                catalogueID: "spotify",
                symbolName: "music.note",
                brandColorHex: "#1DB954",
                brandDomain: "spotify.com"
            ),
            Subscription(
                name: "iCloud+",
                amount: 2.99,
                currencyCode: "USD",
                billingCycle: .monthly,
                nextRenewalDate: dayOfMonth(11),
                category: .software,
                catalogueID: "icloud",
                symbolName: "icloud.fill",
                brandColorHex: "#3693F3",
                brandDomain: "icloud.com"
            ),
            Subscription(
                name: "YouTube Premium",
                amount: 13.99,
                currencyCode: "USD",
                billingCycle: .monthly,
                nextRenewalDate: dayOfMonth(15),
                category: .streaming,
                catalogueID: "youtube-premium",
                symbolName: "play.rectangle.fill",
                brandColorHex: "#FF0000",
                brandDomain: "youtube.com"
            ),
            Subscription(
                name: "Adobe Creative Cloud",
                amount: 59.99,
                currencyCode: "USD",
                billingCycle: .monthly,
                nextRenewalDate: dayOfMonth(19),
                category: .software,
                catalogueID: "adobe-cc",
                symbolName: "app.badge.fill",
                brandColorHex: "#FF0000",
                brandDomain: "adobe.com"
            ),
            Subscription(
                name: "Notion",
                amount: 10.00,
                currencyCode: "USD",
                billingCycle: .monthly,
                nextRenewalDate: dayOfMonth(23),
                category: .software,
                catalogueID: "notion",
                symbolName: "doc.text.fill",
                brandColorHex: "#000000",
                brandDomain: "notion.so"
            ),
            Subscription(
                name: "iPhone Storage",
                amount: 0.99,
                currencyCode: "USD",
                billingCycle: .monthly,
                nextRenewalDate: dayOfMonth(27),
                category: .software,
                symbolName: "externaldrive.fill"
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
