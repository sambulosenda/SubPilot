//
//  HomeDashboard.swift
//  Rubradar
//

import SwiftUI

/// The Home screen's header: the monthly total and, once something has been
/// cancelled, what that saved. The one headline on the screen.
struct DashboardHeader: View {
    let metrics: HomeMetrics
    /// Opens the list of cancelled subscriptions behind the savings pill.
    var onOpenCut: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HeroSpend(metrics: metrics)
            if metrics.cut.yearlyTotal > 0 {
                CutPill(summary: metrics.cut, action: onOpenCut)
                    .padding(.horizontal, heroInset)
                    .transition(.scale(scale: 0.9, anchor: .leading).combined(with: .opacity))
            }
        }
        .appearEntrance(0)
        .padding(.top, Spacing.sm)
    }
}

/// The next 30 days of charges on a strip. Sits below anything that needs a
/// decision: it is a preview of the Calendar, not something to act on.
struct DashboardStrip: View {
    let metrics: HomeMetrics
    /// Switches to the Calendar tab (the strip is its preview).
    var onOpenCalendar: () -> Void

    var body: some View {
        RenewalStripCard(metrics: metrics, onOpen: onOpenCalendar)
            .appearEntrance(1)
    }
}

/// Lines hero content up with the inset section headers below ("Up next").
private let heroInset: CGFloat = 20

// MARK: - Hero

/// The monthly total, set large on the bare background — no card, so it reads
/// as the screen's headline rather than one tile among several.
private struct HeroSpend: View {
    let metrics: HomeMetrics

    @ScaledMetric(relativeTo: .largeTitle) private var amountSize: CGFloat = 54

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Total monthly")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            Text(metrics.summary.formattedMonthly)
                .font(.system(size: amountSize, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .contentTransition(.numericText())

            HStack(spacing: Spacing.xs) {
                // Same compact unit as every row ("/ mo", "/ yr"); this was
                // the one place that spelled it "/ year".
                Text(verbatim: "\(metrics.summary.formattedYearly) / \(BillingCycle.yearly.shortLabel)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if metrics.summary.hasUnconvertible {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, heroInset)
        .accessibilityElement(children: .combine)
        // "approximately" voices what the warning triangle shows sighted users.
        .accessibilityLabel("Total monthly \(metrics.summary.hasUnconvertible ? "approximately " : "")\(metrics.summary.formattedMonthly), \(metrics.summary.formattedYearly) per year, from \(metrics.activeCount) subscriptions")
    }
}

/// The running total of what the user has stopped paying for. Brand teal, the
/// app's one "good news" colour; tapping it lists what was cut.
private struct CutPill: View {
    let summary: CutSummary
    var action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// `brand` on its own 15% tint is ~3.3:1 in light mode — under the 4.5:1
    /// body text needs. The deeper shade clears it; dark mode is fine as is.
    private var tint: Color { colorScheme == .dark ? .brand : .brandDeep }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                // The icons are decoration; at accessibility sizes the text
                // needs their width, or the amount breaks mid-number.
                if !dynamicTypeSize.isAccessibilitySize {
                    Image(systemName: "scissors")
                        .accessibilityHidden(true)
                }
                Text("You've cut \(summary.formattedYearly) a year")
                    .contentTransition(.numericText())
                if !dynamicTypeSize.isAccessibilitySize {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .opacity(0.6)
                        .accessibilityHidden(true)
                }
            }
            .font(.subheadline.weight(.semibold))
            // One line normally; at accessibility sizes it wraps instead of
            // truncating to "You've c…".
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            .minimumScaleFactor(0.8)
            .multilineTextAlignment(.leading)
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, Spacing.sm)
            // Reads as a capsule at one line and stays tidy when wrapped.
            .background(Color.brand.opacity(0.15), in: .rect(cornerRadius: 17, style: .continuous))
            // The pill is ~34pt tall; pad the tappable area out to 44.
            .padding(.vertical, 5)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        // The padding above is for touch only; don't let it push the layout.
        .padding(.vertical, -5)
    }
}

// MARK: - 30-day strip

/// The next 30 days as a strip: each upcoming charge's logo sits on its day,
/// today at the leading edge. Replaces the "days until" / "next charge" tiles
/// with one picture of when the money leaves.
private struct RenewalStripCard: View {
    let metrics: HomeMetrics
    /// Tap: open the Calendar tab, which this strip previews.
    var onOpen: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The charge under the finger while scrubbing; nil at rest.
    @State private var scrubbedID: String?
    @State private var stripWidth: CGFloat = 0

    /// Past this the logos stop being individually readable; the header's
    /// count and total still cover every charge.
    private static let maxLogos = 12

    private var shown: [UpcomingCharge] { Array(metrics.upcoming.prefix(Self.maxLogos)) }
    private var scrubbed: UpcomingCharge? { shown.first { $0.id == scrubbedID } }

    private var windowEnd: Date {
        Calendar.current.date(byAdding: .day, value: HomeMetrics.upcomingWindowDays, to: Date()) ?? Date()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            header

            if shown.isEmpty {
                Text("Nothing due in the next 30 days")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                strip
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(Color.cardBackground, in: .rect(cornerRadius: Radius.card))
        .contentShape(.rect(cornerRadius: Radius.card))
        .onTapGesture(perform: onOpen)
        // Horizontal drags scrub through the charges; vertical ones are left
        // to the list, so the card never traps a scroll.
        .gesture(HorizontalScrub(
            onChanged: { x in scrub(toCardX: x) },
            onEnded: { scrubbedID = nil }
        ))
        .sensoryFeedback(.selection, trigger: scrubbedID) { _, new in new != nil }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(shown.isEmpty ? "Nothing due in the next 30 days" : "Next 30 days")
        .accessibilityValue(accessibilityValue)
        .accessibilityAction { onOpen() }
        // VoiceOver's version of the scrub: swipe up/down to step through
        // the charges one at a time.
        .accessibilityAdjustableAction { direction in step(direction) }
    }

    private func step(_ direction: AccessibilityAdjustmentDirection) {
        guard !shown.isEmpty else { return }
        let current: Int? = shown.firstIndex { $0.id == scrubbedID }
        var next: Int?
        switch direction {
        case .increment: next = (current ?? -1) + 1
        case .decrement: next = current.map { $0 - 1 }
        @unknown default: next = nil
        }
        scrubbedID = next.flatMap { shown.indices.contains($0) ? shown[$0].id : nil }
    }

    private var strip: some View {
        VStack(spacing: Spacing.sm) {
            StripLayout(packs: true) {
                ForEach(Array(shown.enumerated()), id: \.element.id) { index, charge in
                    logo(charge, index: index)
                }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { stripWidth = $0 }
            StripAxis()
            HStack {
                Text("Today")
                Spacer()
                Text(windowEnd, format: .dateTime.day().month(.abbreviated))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        // A cancelled charge shrinks away and its neighbours close up.
        .animation(.snappy, value: shown.map(\.id))
        .animation(AppMotion.select, value: scrubbedID)
    }

    private func logo(_ charge: UpcomingCharge, index: Int) -> some View {
        let isScrubbed = charge.id == scrubbedID
        let dimmed = scrubbedID != nil && !isScrubbed
        // Sooner charges sit on top where logos overlap; the scrubbed one
        // always wins.
        let z: Double = isScrubbed ? 1_000 : Double(shown.count - index)
        return StripLogo(charge: charge)
            .scaleEffect(isScrubbed ? 1.3 : 1, anchor: .bottom)
            .opacity(dimmed ? 0.35 : 1)
            .stripFraction(fraction(forDay: charge.daysAway))
            .zIndex(z)
            .transition(.scale.combined(with: .opacity))
    }

    /// Titles beside the amount; at accessibility text sizes the amount drops
    /// underneath, where side by side both truncated to "Next…" / "£10…".
    @ViewBuilder
    private var header: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                headerTitles
                headerAmount
            }
        } else {
            HStack(alignment: .firstTextBaseline) {
                headerTitles
                Spacer(minLength: Spacing.sm)
                headerAmount
            }
        }
    }

    private var headerTitles: some View {
        VStack(alignment: .leading, spacing: 2) {
            Group {
                if let scrubbed {
                    Text(verbatim: scrubbed.event.subscription.name)
                } else {
                    Text("Next 30 days")
                }
            }
            .font(.headline)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
            Group {
                if let scrubbed {
                    Text(scrubbed.event.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                } else if !metrics.upcoming.isEmpty, let next = metrics.nextChargeRelativeLabel {
                    // Only while something lands inside the window. The next
                    // charge can sit exactly 30 days out, just past the
                    // half-open window, and then "Next: in 30 days" sat right
                    // above "Nothing due in the next 30 days".
                    Text("Next: \(next)")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var headerAmount: some View {
        if !metrics.upcoming.isEmpty {
            Text(scrubbed?.event.subscription.formattedAmount ?? metrics.formattedUpcomingTotal)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private var accessibilityValue: Text {
        if let scrubbed {
            let date = scrubbed.event.date.formatted(.dateTime.weekday(.wide).day().month(.wide))
            return Text(verbatim: "\(scrubbed.event.subscription.name), \(scrubbed.event.subscription.formattedAmount), \(date)")
        }
        return shown.isEmpty ? Text(verbatim: "") : renewalsSummary
    }

    /// Same wording (and catalog entry) as the Calendar's month header.
    private var renewalsSummary: Text {
        Text("^[\(metrics.upcoming.count) renewal](inflect: true), \("")\(metrics.formattedUpcomingTotal)")
    }

    private func fraction(forDay day: Int) -> Double {
        Double(day) / Double(HomeMetrics.upcomingWindowDays)
    }

    /// Picks the logo nearest the finger. Uses the same placement maths as
    /// `StripLayout`, so it tracks where logos are drawn, nudges included.
    private func scrub(toCardX x: CGFloat) {
        guard !shown.isEmpty, stripWidth > 0 else { return }
        let stripX = x - Spacing.lg   // the strip sits inside the card's padding
        let origins = StripLayout.origins(
            fractions: shown.map { fraction(forDay: $0.daysAway) },
            itemWidth: StripLogo.outerSize, width: stripWidth, packs: true
        )
        let half = StripLogo.outerSize / 2
        let distances: [CGFloat] = origins.map { abs($0 + half - stripX) }
        let nearest = distances.indices.min { distances[$0] < distances[$1] }
        scrubbedID = nearest.map { shown[$0].id }
    }
}

/// A pan that only begins when it is more horizontal than vertical, reporting
/// the finger's x in the attached view's space. SwiftUI's `DragGesture` can't
/// decline a vertical drag, and would stop the Home list scrolling whenever a
/// scroll started on the card.
private struct HorizontalScrub: UIGestureRecognizerRepresentable {
    var onChanged: (CGFloat) -> Void
    var onEnded: () -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        return pan
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        switch recognizer.state {
        case .began, .changed: onChanged(context.converter.localLocation.x)
        case .ended, .cancelled, .failed: onEnded()
        default: break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y)
        }
    }
}

/// A logo on the strip. The ring separates overlapping neighbours and turns
/// orange for a trial about to convert — the one charge that needs a decision.
private struct StripLogo: View {
    let charge: UpcomingCharge

    static let logoSize: CGFloat = 30
    static let ring: CGFloat = 2
    static var outerSize: CGFloat { logoSize + ring * 2 }

    var body: some View {
        BrandLogoView(subscription: charge.event.subscription, size: Self.logoSize)
            .padding(Self.ring)
            .background(
                charge.event.isTrialEnd ? AnyShapeStyle(.orange) : AnyShapeStyle(Color.cardBackground),
                in: .rect(cornerRadius: Self.outerSize * 0.28, style: .continuous)
            )
    }
}

/// The day axis under the logos: a hairline with a brand dot for today and a
/// tick per week. Ticks are laid out by the same `StripLayout` (at the logo's
/// width) so they line up with logo centres exactly.
private struct StripAxis: View {
    private static let weekTicks = Array(stride(from: 7, through: HomeMetrics.upcomingWindowDays, by: 7))

    var body: some View {
        ZStack {
            Capsule()
                .fill(.quaternary)
                .frame(height: 2)
                .padding(.horizontal, StripLogo.outerSize / 2)

            StripLayout(packs: false) {
                Circle()
                    .fill(Color.brand)
                    .frame(width: 8, height: 8)
                    .frame(width: StripLogo.outerSize)
                    .stripFraction(0)
                ForEach(Self.weekTicks, id: \.self) { day in
                    Capsule()
                        .fill(.tertiary)
                        .frame(width: 2, height: 6)
                        .frame(width: StripLogo.outerSize)
                        .stripFraction(Double(day) / Double(HomeMetrics.upcomingWindowDays))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Strip layout

nonisolated private struct StripFractionKey: LayoutValueKey {
    static let defaultValue: Double = 0
}

private extension View {
    /// Position along the strip, 0 (today) ... 1 (end of the window).
    func stripFraction(_ value: Double) -> some View {
        layoutValue(key: StripFractionKey.self, value: min(max(value, 0), 1))
    }
}

/// Places equally sized subviews along the width by their `stripFraction`.
/// With `packs`, neighbours that would land on top of each other (several
/// charges on one day) are nudged apart just enough to keep each one
/// recognisable. They may still overlap: staying near the true day matters
/// more than a tidy row.
private struct StripLayout: Layout {
    var packs: Bool

    /// Share of a logo that must stay clear of the next one.
    private static let minVisible: CGFloat = 0.78

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let height = subviews.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let itemWidth = subviews.first?.sizeThatFits(.unspecified).width else { return }
        let xs = Self.origins(fractions: subviews.map { $0[StripFractionKey.self] },
                              itemWidth: itemWidth, width: bounds.width, packs: packs)
        for (subview, x) in zip(subviews, xs) {
            subview.place(
                at: CGPoint(x: bounds.minX + x, y: bounds.midY),
                anchor: .leading,
                proposal: .unspecified
            )
        }
    }

    /// Leading x of each item for the given strip width. Shared with the
    /// scrub gesture so hit-testing matches what is drawn.
    static func origins(fractions: [Double], itemWidth: CGFloat, width: CGFloat, packs: Bool) -> [CGFloat] {
        let span = max(0, width - itemWidth)
        var xs: [CGFloat] = fractions.map { span * CGFloat($0) }
        guard packs, xs.count > 1 else { return xs }

        let step = min(itemWidth * minVisible, span / CGFloat(xs.count - 1))
        for i in xs.indices.dropFirst() {
            xs[i] = max(xs[i], xs[i - 1] + step)
        }
        // The forward pass can run off the end; pull back from the right.
        xs[xs.count - 1] = min(xs[xs.count - 1], span)
        for i in xs.indices.dropLast().reversed() {
            xs[i] = min(xs[i], xs[i + 1] - step)
        }
        return xs
    }
}

#Preview {
    let subs = SampleData.makeSamples()
    let metrics = HomeMetrics.make(from: subs, preferred: "GBP", rates: .fallback)
    return ScrollView {
        DashboardHeader(metrics: metrics, onOpenCut: {})
        DashboardStrip(metrics: metrics, onOpenCalendar: {})
            .padding(.horizontal, Spacing.md)
    }
}
