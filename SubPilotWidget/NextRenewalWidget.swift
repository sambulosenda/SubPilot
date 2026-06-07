//
//  NextRenewalWidget.swift
//  SubPilotWidget
//
//  Glanceable "next renewal" + monthly total for Home and Lock Screen. Reads the
//  `WidgetSnapshot` the app writes to the shared App Group — no SwiftData here.
//
//  Target membership note: this file plus `SubPilotWidgetMain.swift` belong to the
//  SubPilotWidget target. The shared files `WidgetSnapshot.swift`,
//  `WidgetSnapshotStore.swift` and `Category.swift` (all under Rubradar/) must
//  also have this target ticked in their File Inspector.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline

struct NextRenewalEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct NextRenewalProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextRenewalEntry {
        NextRenewalEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (NextRenewalEntry) -> Void) {
        let snapshot = context.isPreview ? .placeholder : (WidgetSnapshotStore.read() ?? .empty)
        completion(NextRenewalEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextRenewalEntry>) -> Void) {
        let snapshot = WidgetSnapshotStore.read() ?? .empty
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())

        // One entry per midnight for two weeks, so the "in N days" countdown ticks
        // down on its own. The app reloads timelines whenever data actually changes.
        var entries: [NextRenewalEntry] = []
        for offset in 0..<14 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday) else { continue }
            entries.append(NextRenewalEntry(date: day, snapshot: snapshot))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Widget

struct NextRenewalWidget: Widget {
    let kind = "NextRenewalWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextRenewalProvider()) { entry in
            NextRenewalView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Next Renewal")
        .description("Your next subscription charge and total monthly spend.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryRectangular, .accessoryInline, .accessoryCircular
        ])
    }
}

// MARK: - View

struct NextRenewalView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NextRenewalEntry

    var body: some View {
        switch family {
        case .systemSmall: smallView
        case .systemMedium: mediumView
        case .accessoryRectangular: rectangularView
        case .accessoryInline: inlineView
        case .accessoryCircular: circularView
        default: smallView
        }
    }

    // MARK: Home Screen

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Monthly")
            Text(entry.snapshot.formattedMonthlyTotal)
                .font(.title2.weight(.bold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Spacer(minLength: 8)

            if let event = next {
                Label {
                    Text(event.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                } icon: {
                    Image(systemName: event.symbolName)
                        .foregroundStyle(tint(event))
                }
                .labelStyle(.titleAndIcon)

                HStack {
                    Text(timingLabel(event))
                    Spacer()
                    Text(event.formattedAmount)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            } else {
                emptyLine
            }
        }
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    sectionLabel("Monthly total")
                    Text(entry.snapshot.formattedMonthlyTotal)
                        .font(.title2.weight(.bold))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
                Spacer()
                if let profile = entry.snapshot.profileName {
                    Text(profile)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.quaternary, in: Capsule())
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            if upcoming.isEmpty {
                Spacer(minLength: 0)
                emptyLine
                Spacer(minLength: 0)
            } else {
                ForEach(upcoming) { row($0) }
                Spacer(minLength: 0)
            }
        }
    }

    private func row(_ event: WidgetSnapshot.Event) -> some View {
        HStack(spacing: 8) {
            Image(systemName: event.symbolName)
                .font(.callout)
                .foregroundStyle(tint(event))
                .frame(width: 20)
            Text(event.name)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 0) {
                Text(event.formattedAmount)
                    .font(.subheadline.weight(.semibold))
                Text(timingLabel(event))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Lock Screen

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let event = next {
                Text(event.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(timingLabel(event))
                    .font(.caption)
                Text("\(event.formattedAmount) • \(entry.snapshot.formattedMonthlyTotal)/mo")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("SubPilot").font(.headline)
                Text("No upcoming renewals").font(.caption)
            }
        }
        .widgetAccentable()
    }

    @ViewBuilder
    private var inlineView: some View {
        if let event = next {
            Label("\(event.name) \(timingLabel(event))", systemImage: "calendar")
        } else {
            Label("No renewals", systemImage: "calendar")
        }
    }

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let event = next {
                VStack(spacing: -1) {
                    Text("\(max(daysUntil(event.date), 0))")
                        .font(.title2.weight(.bold))
                    Text("days")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            } else {
                Image(systemName: "checkmark")
            }
        }
        .widgetAccentable()
    }

    // MARK: Shared bits

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
    }

    private var emptyLine: some View {
        Text("No upcoming renewals")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Derived values

private extension NextRenewalView {
    /// Start of the day this timeline entry represents — drives the countdown.
    var referenceDay: Date { Calendar.current.startOfDay(for: entry.date) }

    /// Upcoming events that haven't passed as of this entry's day.
    var upcoming: [WidgetSnapshot.Event] {
        Array(entry.snapshot.upcoming
            .filter { Calendar.current.startOfDay(for: $0.date) >= referenceDay }
            .prefix(3))
    }

    var next: WidgetSnapshot.Event? { upcoming.first }

    func daysUntil(_ date: Date) -> Int {
        Calendar.current.dateComponents(
            [.day], from: referenceDay, to: Calendar.current.startOfDay(for: date)
        ).day ?? 0
    }

    func timingLabel(_ event: WidgetSnapshot.Event) -> String {
        let relative: String
        switch daysUntil(event.date) {
        case ..<0: relative = "Due"
        case 0: relative = "Today"
        case 1: relative = "Tomorrow"
        case let days: relative = "in \(days) days"
        }
        return event.isTrialEnd ? "Trial • \(relative)" : relative
    }

    func tint(_ event: WidgetSnapshot.Event) -> Color {
        if let hex = event.brandColorHex, let color = Color(hex: hex) { return color }
        return SubscriptionCategory(rawValue: event.categoryRaw)?.tint ?? .accentColor
    }
}

// MARK: - Hex colour (widget-local; the app defines its own in Subscription.swift)

private extension Color {
    init?(hex: String) {
        var string = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if string.hasPrefix("#") { string.removeFirst() }
        guard string.count == 6, let value = UInt64(string, radix: 16) else { return nil }
        let r = Double((value & 0xFF0000) >> 16) / 255
        let g = Double((value & 0x00FF00) >> 8) / 255
        let b = Double(value & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    NextRenewalWidget()
} timeline: {
    NextRenewalEntry(date: .now, snapshot: .placeholder)
    NextRenewalEntry(date: .now, snapshot: .empty)
}
