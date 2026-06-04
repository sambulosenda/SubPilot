//
//  RenewalCalendarView.swift
//  Rubradar
//

import SwiftUI
import SwiftData

/// A timeline of upcoming renewals, grouped by month with a per-month spend subtotal.
struct RenewalCalendarView: View {
    @Query(animation: .default) private var subscriptions: [Subscription]
    @Environment(CurrencyService.self) private var currency
    @AppStorage("preferredCurrencyCode") private var preferredCurrency =
        Locale.current.currency?.identifier ?? "GBP"
    /// Follows the profile chosen on Home ("" = All Profiles).
    @AppStorage("selectedProfileID") private var selectedProfileID = ""

    private var months: [RenewalMonth] {
        let scoped = subscriptions.filter { $0.belongsToProfile(id: selectedProfileID) }
        let events = RenewalProjector.events(for: scoped)
        return RenewalMonth.group(events, preferred: preferredCurrency, rates: currency.rates)
    }

    var body: some View {
        NavigationStack {
            Group {
                if months.isEmpty {
                    ContentUnavailableView(
                        "No upcoming renewals",
                        systemImage: "calendar",
                        description: Text("Add a subscription to see when it renews.")
                    )
                } else {
                    list
                }
            }
            .navigationTitle("Calendar")
            .navigationDestination(for: Subscription.self) { sub in
                SubscriptionDetailView(subscription: sub)
            }
        }
    }

    private var list: some View {
        List {
            ForEach(months) { month in
                Section {
                    ForEach(month.events) { event in
                        NavigationLink(value: event.subscription) {
                            RenewalEventRow(event: event)
                        }
                    }
                } header: {
                    MonthHeader(month: month)
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}

// MARK: - Rows

private struct MonthHeader: View {
    let month: RenewalMonth

    var body: some View {
        HStack {
            Text(month.title)
            Spacer()
            HStack(spacing: Spacing.xs) {
                if month.hasUnconvertible {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                Text(month.formattedTotal)
            }
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(month.title), \(month.formattedTotal)")
    }
}

private struct RenewalEventRow: View {
    let event: RenewalEvent

    private var sub: Subscription { event.subscription }

    var body: some View {
        HStack(spacing: Spacing.md) {
            DateBadge(date: event.date)

            BrandLogoView(subscription: sub, size: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(sub.name)
                    .font(.headline)
                    .lineLimit(1)
                if event.isTrialEnd {
                    Text("Trial ends")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                } else {
                    Text(sub.category.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: Spacing.sm)

            Text(sub.formattedAmount)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let action = event.isTrialEnd ? "trial ends" : "renews"
        let when = event.date.formatted(.dateTime.weekday(.wide).day().month(.wide))
        return "\(sub.name), \(action) \(when), \(sub.formattedAmount)"
    }
}

/// Compact weekday + day-of-month cell, e.g. "MON / 15".
private struct DateBadge: View {
    let date: Date

    var body: some View {
        VStack(spacing: 0) {
            Text(date.formatted(.dateTime.weekday(.abbreviated)))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(date.formatted(.dateTime.day()))
                .font(.title3.weight(.bold))
                .monospacedDigit()
        }
        .frame(width: 40)
        .accessibilityHidden(true)
    }
}

#Preview {
    RenewalCalendarView()
        .modelContainer(.preview)
        .environment(CurrencyService())
}
