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

import AppIntents
import WidgetKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Timeline

struct NextRenewalEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    /// More than one profile snapshot is available, so the medium widget offers
    /// the in-place profile switch button.
    var canCycleProfiles: Bool = false
}

struct NextRenewalProvider: TimelineProvider {
    /// Snapshot for the widget's own profile choice (falls back to the app's).
    private func resolved() -> (snapshot: WidgetSnapshot, canCycle: Bool) {
        guard let set = WidgetSnapshotStore.readSet(),
              let slice = set.slice(for: WidgetSnapshotStore.widgetProfileID) else {
            return (.empty, false)
        }
        return (slice.snapshot, set.slices.count > 1)
    }

    func placeholder(in context: Context) -> NextRenewalEntry {
        NextRenewalEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (NextRenewalEntry) -> Void) {
        if context.isPreview {
            completion(NextRenewalEntry(date: Date(), snapshot: .placeholder))
        } else {
            let (snapshot, canCycle) = resolved()
            completion(NextRenewalEntry(date: Date(), snapshot: snapshot, canCycleProfiles: canCycle))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextRenewalEntry>) -> Void) {
        let (snapshot, canCycle) = resolved()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())

        // One entry per midnight for two weeks, so the "in N days" countdown ticks
        // down on its own. The app reloads timelines whenever data actually changes.
        var entries: [NextRenewalEntry] = []
        for offset in 0..<14 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday) else { continue }
            entries.append(NextRenewalEntry(date: day, snapshot: snapshot, canCycleProfiles: canCycle))
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
                .widgetURL(entry.snapshot.upcoming.isEmpty ? WidgetDeepLink.home : WidgetDeepLink.renewals)
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
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Spacer(minLength: 8)

            if let event = next {
                HStack(spacing: 8) {
                    brandChip(for: event, size: 26)
                    Text(event.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }

                HStack {
                    Text(timingLabel(event))
                        .foregroundStyle(timingTint(event))
                    Spacer()
                    Text(event.formattedAmount)
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                }
                .font(.caption.weight(.medium))
                .padding(.top, 4)
            } else {
                emptyLine
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Controls centre against the two-line total block; baseline
            // alignment would hoist the icons into the corner.
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    sectionLabel("Monthly total")
                    Text(entry.snapshot.formattedMonthlyTotal)
                        .font(.title2.weight(.bold))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: 8)
                if entry.canCycleProfiles {
                    // In-place profile switch — runs in the widget process.
                    Button(intent: CycleWidgetProfileIntent()) {
                        profileChip(entry.snapshot.profileName ?? "All", showsSwitch: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Profile: \(entry.snapshot.profileName ?? "All Profiles"). Switches profile.")
                } else if let profile = entry.snapshot.profileName {
                    profileChip(profile, showsSwitch: false)
                }
                Link(destination: WidgetDeepLink.add) {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(brand)
                        .frame(width: 28, height: 28)
                        .background(brand.opacity(0.14), in: Circle())
                }
                .accessibilityLabel("Add subscription")
            }

            Divider().opacity(0.6)

            if upcoming.isEmpty {
                Spacer(minLength: 0)
                emptyLine
                Spacer(minLength: 0)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(upcoming.enumerated()), id: \.element.id) { index, event in
                        row(event, isNext: index == 0)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    /// Single line per event — a stacked amount/date trailing block makes three
    /// rows taller than the medium widget and they collide. The soonest charge
    /// (`isNext`) carries the timing accent so the eye lands there first.
    private func row(_ event: WidgetSnapshot.Event, isNext: Bool) -> some View {
        HStack(spacing: 10) {
            brandChip(for: event, size: 24)
            Text(event.name)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(timingLabel(event, compact: true))
                .font(.caption.weight(isNext ? .semibold : .regular))
                .foregroundStyle(isNext ? timingTint(event) : .secondary)
                .lineLimit(1)
                .layoutPriority(1)
            Text(event.formattedAmount)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .layoutPriority(1)
        }
        .accessibilityElement(children: .combine)
    }

    /// Brand logo tile — the same chip the app uses, so the widget reads as part
    /// of the product. Prefers the real brand mark baked into the snapshot; falls
    /// back to a brand-tinted SF Symbol so every icon carries equal weight
    /// regardless of how chunky or thin its symbol is.
    @ViewBuilder
    private func brandChip(for event: WidgetSnapshot.Event, size: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
        Group {
            if let data = event.logoPNGData, let uiImage = UIImage(data: data) {
                // Edge-to-edge real logo, clipped so marks with a baked-in
                // background round cleanly — mirrors the app's BrandLogoView.
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .clipShape(shape)
            } else {
                shape
                    .fill(tint(event).gradient)
                    .frame(width: size, height: size)
                    .overlay {
                        Image(systemName: event.symbolName)
                            .font(.system(size: size * 0.48, weight: .semibold))
                            .foregroundStyle(.white)
                    }
            }
        }
        .accessibilityHidden(true)
    }

    private func profileChip(_ name: String, showsSwitch: Bool) -> some View {
        HStack(spacing: 3) {
            Text(name).lineLimit(1)
            if showsSwitch {
                Image(systemName: "arrow.2.squarepath")
                    .imageScale(.small)
                    .accessibilityHidden(true)
            }
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary, in: Capsule())
        .foregroundStyle(.secondary)
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
                Text("SubHelm").font(.headline)
                Text("No upcoming renewals").font(.caption)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(next.map { "\(max(daysUntil($0.date), 0)) days until \($0.name) renews" } ?? "No upcoming renewals")
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

    /// One spoken sentence for the compact (small / Lock Screen) layouts, where
    /// the terse visual reads poorly field-by-field under VoiceOver.
    var accessibilitySummary: String {
        let total = "Monthly total \(entry.snapshot.formattedMonthlyTotal)"
        guard let event = next else { return "\(total). No upcoming renewals." }
        let when = timingLabel(event).replacingOccurrences(of: " • ", with: ", ")
        return "\(total). Next renewal \(event.name), \(when), \(event.formattedAmount)."
    }

    /// `compact` trims the relative text ("in 12 days" → "12d") so the brand name
    /// gets the width back on the medium widget's tight rows.
    func timingLabel(_ event: WidgetSnapshot.Event, compact: Bool = false) -> String {
        let relative: String
        switch daysUntil(event.date) {
        case ..<0: relative = "Due"
        case 0: relative = "Today"
        case 1: relative = compact ? "1d" : "Tomorrow"
        case let days: relative = compact ? "\(days)d" : "in \(days) days"
        }
        guard event.isTrialEnd else { return relative }
        return compact ? "Trial · \(relative)" : "Trial • \(relative)"
    }

    func tint(_ event: WidgetSnapshot.Event) -> Color {
        if let hex = event.brandColorHex, let color = Color(hex: hex) { return color }
        return SubscriptionCategory(rawValue: event.categoryRaw)?.tint ?? .accentColor
    }

    /// SubHelm brand teal — keeps the widget on-brand without importing the app's
    /// Theme (which isn't a member of the widget target).
    var brand: Color { Color(hex: "0D9488") ?? .accentColor }

    /// Accent for the timing label: orange when already due, brand teal when
    /// imminent (today/tomorrow), otherwise it stays secondary.
    func timingTint(_ event: WidgetSnapshot.Event) -> Color {
        switch daysUntil(event.date) {
        case ..<0: return .orange
        case 0, 1: return brand
        default: return .secondary
        }
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

#Preview(as: .systemMedium) {
    NextRenewalWidget()
} timeline: {
    NextRenewalEntry(date: .now, snapshot: .placeholder, canCycleProfiles: true)
    NextRenewalEntry(date: .now, snapshot: .placeholder)
}
