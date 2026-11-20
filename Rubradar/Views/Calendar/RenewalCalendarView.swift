//
//  RenewalCalendarView.swift
//  Rubradar
//

import SwiftUI
import SwiftData

/// The renewal calendar: a real month grid with per-day renewal markers and a
/// selected-day agenda, plus an "Upcoming" timeline grouped by month. Both modes
/// read the same projected events; the projector walks each subscription's anchor
/// forward over a 12-month horizon.
struct RenewalCalendarView: View {
    @Query(animation: .default) private var subscriptions: [Subscription]
    @Environment(CurrencyService.self) private var currency
    @AppStorage("preferredCurrencyCode") private var preferredCurrency =
        Locale.current.currency?.identifier ?? "GBP"
    /// Follows the profile chosen on Home ("" = All Profiles).
    @AppStorage("selectedProfileID") private var selectedProfileID = ""

    /// Forward window the projector covers; bounds month navigation.
    private static let horizonMonths = 12

    private let calendar = Calendar.current

    enum Mode: String, CaseIterable, Identifiable {
        case month, list
        var id: String { rawValue }
        var label: LocalizedStringKey { self == .month ? "Month" : "Upcoming" }
    }

    /// Starts an add from the empty state (routed through the shell's gates).
    var onAdd: () -> Void = {}

    @State private var mode: Mode = .month
    @State private var displayedMonth = MonthLayout.startOfMonth(Date())
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    /// Drives the grid's slide direction when paging months.
    @State private var pageForward = true

    var body: some View {
        let data = CalendarData(
            events: RenewalProjector.events(for: scopedSubscriptions),
            preferred: preferredCurrency,
            rates: currency.rates,
            calendar: calendar
        )
        NavigationStack {
            Group {
                if data.isEmpty {
                    // With a way forward: the copy said "add a subscription"
                    // and the screen offered nothing to add one with.
                    ContentUnavailableView {
                        Label("No upcoming renewals", systemImage: "calendar")
                    } description: {
                        Text("Add a subscription to see when it renews.")
                    } actions: {
                        Button("Add a subscription", action: onAdd)
                            .buttonStyle(.glassProminent)
                            .controlSize(.large)
                    }
                } else if mode == .month {
                    monthMode(data)
                } else {
                    timeline(data.months)
                }
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("View", selection: $mode.animation(.snappy)) {
                        ForEach(Mode.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
            }
            .navigationDestination(for: Subscription.self) { sub in
                SubscriptionDetailView(subscription: sub)
            }
        }
        .sensoryFeedback(.selection, trigger: selectedDate)
    }

    private var scopedSubscriptions: [Subscription] {
        subscriptions.filter { $0.belongsToProfile(id: selectedProfileID) }
    }

    // MARK: Month mode

    @ViewBuilder
    private func monthMode(_ data: CalendarData) -> some View {
        let bounds = monthBounds
        let monthTotal = data.months.first {
            calendar.isDate($0.id, equalTo: displayedMonth, toGranularity: .month)
        }
        ScrollViewReader { proxy in
            List {
                // The calendar (nav + grid) is the first row: full-bleed, no chrome,
                // so it floats on the grouped background while the agenda below sits
                // on inset cards — one scroll surface, no fixed-block/list seam.
                Section {
                    VStack(spacing: Spacing.md) {
                        MonthNavBar(
                            title: displayedMonth.formatted(.dateTime.month(.wide).year()),
                            total: monthTotal,
                            renewalCount: monthTotal?.events.count ?? 0,
                            canGoBack: displayedMonth > bounds.earliest,
                            canGoForward: displayedMonth < bounds.latest,
                            showsToday: !calendar.isDate(displayedMonth, equalTo: bounds.earliest, toGranularity: .month),
                            onPrevious: { page(by: -1) },
                            onNext: { page(by: 1) },
                            onToday: goToToday
                        )
                        MonthGridView(
                            month: displayedMonth,
                            selectedDate: selectedDate,
                            eventsByDay: data.eventsByDay,
                            spendByDay: data.spendByDay,
                            calendar: calendar,
                            pageForward: pageForward,
                            onSelect: select(_:)
                        )
                        .contentShape(.rect)
                        .gesture(pagingGesture)
                    }
                    .padding(.top, Spacing.sm)
                    .listRowInsets(EdgeInsets(top: 0, leading: Spacing.md, bottom: 0, trailing: Spacing.md))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    // Stable id (not the month) so paging swaps the grid in place via
                    // its own transition instead of a List row insert/remove; also the
                    // scroll-to-top anchor when the month changes.
                    .id("calendar")
                }

                agendaSections(for: selectedDate, in: data)
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(Spacing.lg)
            .scrollIndicators(.hidden)
            .tabBarMinimizeBehavior(.onScrollDown)
            .background(Color.appBackground)
            .onChange(of: displayedMonth) {
                withAnimation(.snappy) { proxy.scrollTo("calendar", anchor: .top) }
            }
        }
    }

    /// Agenda sections folded into the parent month `List`. A day with renewals
    /// shows its priced agenda; an empty day leads straight with "Next up" so the
    /// real upcoming charges — not a second "nothing" message — fill the space.
    @ViewBuilder
    private func agendaSections(for date: Date, in data: CalendarData) -> some View {
        let dayStart = calendar.startOfDay(for: date)
        let dayEvents = data.eventsByDay[dayStart] ?? []
        if dayEvents.isEmpty {
            let nextUp = upcomingEvents(after: dayStart, in: data)
            if nextUp.isEmpty {
                // Genuinely nothing ahead (horizon end): one quiet line, nothing else.
                Section {
                    EmptyDayNote(date: date)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            } else {
                Section {
                    ForEach(nextUp) { event in
                        NavigationLink(value: event.subscription) {
                            // These span months, so the badge shows the month
                            // (not weekday) — otherwise two different "6"s read
                            // as a duplicate.
                            RenewalEventRow(event: event,
                                            preferred: preferredCurrency,
                                            rates: currency.rates,
                                            showsMonth: true)
                        }
                    }
                } header: {
                    // "Nothing today" demoted to a caption here, so the empty day
                    // carries one message instead of two stacked grey negatives.
                    NextUpHeader(date: date)
                }
            }
        } else {
            Section {
                ForEach(dayEvents) { event in
                    NavigationLink(value: event.subscription) {
                        RenewalEventRow(event: event,
                                        preferred: preferredCurrency,
                                        rates: currency.rates,
                                        showsDate: false)
                    }
                }
            } header: {
                AgendaHeader(
                    date: date,
                    events: dayEvents,
                    preferred: preferredCurrency,
                    rates: currency.rates,
                    calendar: calendar
                )
            }
        }
    }

    /// The soonest renewals strictly after `dayStart`. Events arrive pre-sorted by
    /// date from the projector, so this is just a forward filter capped at three.
    private func upcomingEvents(after dayStart: Date, in data: CalendarData) -> [RenewalEvent] {
        data.months
            .flatMap(\.events)
            .filter { calendar.startOfDay(for: $0.date) > dayStart }
            .prefix(3)
            .map { $0 }
    }

    // MARK: Upcoming (timeline)

    private func timeline(_ months: [RenewalMonth]) -> some View {
        List {
            ForEach(months) { month in
                Section {
                    ForEach(month.events) { event in
                        NavigationLink(value: event.subscription) {
                            RenewalEventRow(event: event,
                                            preferred: preferredCurrency,
                                            rates: currency.rates)
                        }
                    }
                } header: {
                    MonthHeader(month: month)
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }

    // MARK: Navigation

    /// First-of-month bounds: nothing renews before today, and the projector
    /// only looks `horizonMonths` ahead, so paging outside that range is inert.
    private var monthBounds: (earliest: Date, latest: Date) {
        let now = Date()
        let earliest = MonthLayout.startOfMonth(now, calendar: calendar)
        let horizon = calendar.date(byAdding: .month, value: Self.horizonMonths, to: now) ?? now
        return (earliest, MonthLayout.startOfMonth(horizon, calendar: calendar))
    }

    private func page(by delta: Int) {
        guard let next = calendar.date(byAdding: .month, value: delta, to: displayedMonth) else { return }
        let bounds = monthBounds
        let clamped = min(max(next, bounds.earliest), bounds.latest)
        guard clamped != displayedMonth else { return }
        withAnimation(.snappy) {
            pageForward = delta > 0
            displayedMonth = clamped
            selectedDate = defaultSelection(in: clamped)
        }
    }

    private func goToToday() {
        let today = calendar.startOfDay(for: Date())
        withAnimation(.snappy) {
            pageForward = false
            displayedMonth = MonthLayout.startOfMonth(today, calendar: calendar)
            selectedDate = today
        }
    }

    /// Selecting a day in an adjacent month pages the grid to that month.
    private func select(_ date: Date) {
        let day = calendar.startOfDay(for: date)
        let targetMonth = MonthLayout.startOfMonth(day, calendar: calendar)
        withAnimation(.snappy) {
            if targetMonth != displayedMonth {
                pageForward = targetMonth > displayedMonth
                displayedMonth = targetMonth
            }
            selectedDate = day
        }
    }

    /// When paging, prefer today if it lands in the new month, else its first day.
    private func defaultSelection(in month: Date) -> Date {
        let today = calendar.startOfDay(for: Date())
        return calendar.isDate(today, equalTo: month, toGranularity: .month) ? today : month
    }

    private var pagingGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                page(by: value.translation.width < 0 ? 1 : -1)
            }
    }
}

// MARK: - Derived data

/// Pre-grouped renewal data shared by both calendar modes — built once per body.
private struct CalendarData {
    let eventsByDay: [Date: [RenewalEvent]]
    /// Converted spend per day in the preferred currency — drives the grid's
    /// spend-magnitude heatmap. Charges in an unconvertible currency contribute 0.
    let spendByDay: [Date: Double]
    let months: [RenewalMonth]

    var isEmpty: Bool { months.isEmpty }

    init(events: [RenewalEvent], preferred: String, rates: ExchangeRates, calendar: Calendar) {
        let byDay = Dictionary(grouping: events) { calendar.startOfDay(for: $0.date) }
        eventsByDay = byDay
        spendByDay = byDay.mapValues { dayEvents in
            dayEvents.reduce(0.0) { sum, event in
                guard let converted = rates.convert(event.subscription.amount,
                                                    from: event.subscription.currencyCode,
                                                    to: preferred) else { return sum }
                return sum + NSDecimalNumber(decimal: converted).doubleValue
            }
        }
        months = RenewalMonth.group(events, preferred: preferred, rates: rates, calendar: calendar)
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
        // Voice the warning triangle's meaning, not the glyph.
        .accessibilityLabel("\(month.title), \(month.hasUnconvertible ? "approximately " : "")\(month.formattedTotal)")
    }
}

private struct RenewalEventRow: View {
    let event: RenewalEvent
    /// Preferred display currency + live rates, so the trailing amount matches the
    /// converted totals in the headers instead of showing a stray native currency.
    let preferred: String
    let rates: ExchangeRates
    /// The day agenda already groups by date, so it hides the leading date badge.
    var showsDate = true
    /// Cross-month lists ("Next up") show the month on the badge instead of the
    /// weekday, so same-numbered days in different months don't look duplicated.
    var showsMonth = false

    private var sub: Subscription { event.subscription }

    /// The charge converted to the preferred currency — nil when the native currency
    /// already is the preferred one, or no rate is available.
    private var converted: Decimal? {
        guard sub.currencyCode != preferred else { return nil }
        return rates.convert(sub.amount, from: sub.currencyCode, to: preferred)
    }

    /// Primary amount: the preferred-currency value when convertible, else native.
    private var primaryAmount: String {
        converted?.formatted(.currency(code: preferred)) ?? sub.formattedAmount
    }

    /// Native charge, shown as a quiet subtitle only when we converted away from it.
    private var nativeSubtitle: String? {
        converted == nil ? nil : sub.formattedAmount
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            if showsDate {
                DateBadge(date: event.date, showsMonth: showsMonth)
            }

            BrandLogoView(subscription: sub, size: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(sub.name)
                    .font(.headline)
                    // Shrinks a little before truncating, as on Home's rows:
                    // at full size "Adobe Creative Cloud" lost its last word.
                    // With the date badge there is less room still, so the
                    // timeline lets a long name take a second line.
                    .lineLimit(showsDate ? 2 : 1)
                    .minimumScaleFactor(0.8)
                if event.isTrialEnd {
                    Text("Trial ends")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.attention)
                } else {
                    Text(sub.category.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: Spacing.sm)

            VStack(alignment: .trailing, spacing: 1) {
                Text(primaryAmount)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
                if let nativeSubtitle {
                    Text(nativeSubtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let action = event.isTrialEnd ? "trial ends" : "renews"
        let when = event.date.formatted(.dateTime.weekday(.wide).day().month(.wide))
        let amount = nativeSubtitle.map { "\(primaryAmount), \($0)" } ?? primaryAmount
        return "\(sub.name), \(action) \(when), \(amount)"
    }
}

/// Compact weekday/month + day-of-month cell, e.g. "MON / 15" or "AUG / 6".
private struct DateBadge: View {
    let date: Date
    /// Top line shows the month (vs the weekday) for cross-month lists.
    var showsMonth = false

    var body: some View {
        VStack(spacing: 0) {
            Text(date.formatted(showsMonth ? .dateTime.month(.abbreviated)
                                           : .dateTime.weekday(.abbreviated)))
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

// MARK: - Month navigation bar

private struct MonthNavBar: View {
    let title: String
    let total: RenewalMonth?
    let renewalCount: Int
    let canGoBack: Bool
    let canGoForward: Bool
    let showsToday: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onToday: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title2.weight(.bold))
                subtitle
            }
            .accessibilityElement(children: .combine)

            Spacer()

            HStack(spacing: Spacing.sm) {
                if showsToday {
                    Button("Today", action: onToday)
                        .font(.footnote.weight(.semibold))
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .controlSize(.small)
                        .tint(.brand)
                }
                StepperButton(systemName: "chevron.left", enabled: canGoBack, action: onPrevious)
                    .accessibilityLabel("Previous month")
                StepperButton(systemName: "chevron.right", enabled: canGoForward, action: onNext)
                    .accessibilityLabel("Next month")
            }
        }
    }

    @ViewBuilder
    private var subtitle: some View {
        if let total {
            HStack(spacing: Spacing.xs) {
                if total.hasUnconvertible {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption2)
                }
                Text("^[\(renewalCount) renewal](inflect: true)") + Text(verbatim: " · ") + Text(total.formattedTotal)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .accessibilityLabel("^[\(renewalCount) renewal](inflect: true), \(total.hasUnconvertible ? "approximately " : "")\(total.formattedTotal)")
        } else {
            Text("No renewals")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

/// Circular month-stepper control: brand-tinted when enabled, dimmed when not.
private struct StepperButton: View {
    let systemName: String
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.subheadline.weight(.bold))
                .frame(width: 32, height: 32)
                .background(Color(.tertiarySystemFill), in: .circle)
                .foregroundStyle(enabled ? Color.brand : Color.secondary)
                // Drawn at 32pt, tappable at 44. The negative padding keeps
                // the two arrows the same distance apart as before.
                .padding(6)
                .contentShape(.rect)
                .padding(-6)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// MARK: - Month grid

private struct MonthGridView: View {
    let month: Date
    let selectedDate: Date
    let eventsByDay: [Date: [RenewalEvent]]
    let spendByDay: [Date: Double]
    let calendar: Calendar
    let pageForward: Bool
    let onSelect: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: Spacing.xs), count: 7)

    var body: some View {
        VStack(spacing: Spacing.sm) {
            weekdayHeader
            grid
                .id(month)
                .transition(.push(from: pageForward ? .trailing : .leading))
        }
        .clipped()
    }

    private var weekdayHeader: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(Array(MonthLayout.orderedWeekdaySymbols(calendar).enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    private var grid: some View {
        let days = MonthLayout.days(in: month, calendar: calendar)
        // Self-scale the heatmap to this month's heaviest day, so every month
        // reads on its own terms rather than against a global maximum.
        let monthMax = days.filter(\.isInMonth)
            .compactMap { spendByDay[$0.date] }
            .max() ?? 0
        return LazyVGrid(columns: columns, spacing: Spacing.xs) {
            ForEach(days) { day in
                DayCell(
                    day: day,
                    isSelected: calendar.isDate(day.date, inSameDayAs: selectedDate),
                    isToday: calendar.isDateInToday(day.date),
                    events: eventsByDay[day.date] ?? [],
                    spend: spendByDay[day.date] ?? 0,
                    monthMaxSpend: monthMax,
                    onSelect: { onSelect(day.date) }
                )
            }
        }
    }
}

/// A flat day cell with a spend-aware marker. Selection and "today" both live on a
/// filled circle behind the day number — the native iOS Calendar idiom — so the two
/// never compete with a third shape: today is a brand circle, any other selected day
/// a neutral one. A renewal day carries a single calm brand-teal wash that deepens
/// with the day's converted spend (self-scaled to the month's heaviest day), reading
/// as one quiet heatmap rather than a patchwork of per-brand colours; the colourful
/// brand-logo chip below the number is what carries each service's identity.
private struct DayCell: View {
    let day: CalendarDay
    let isSelected: Bool
    let isToday: Bool
    let events: [RenewalEvent]
    let spend: Double
    let monthMaxSpend: Double
    let onSelect: () -> Void

    /// Tuned so number + chip clear the square cell on the narrowest iPhone.
    private static let markerSize: CGFloat = 18
    private static let numberSize: CGFloat = 24

    private var dayNumber: String {
        day.date.formatted(.dateTime.day())
    }

    private var hasEvents: Bool { !events.isEmpty }

    /// This day's spend as a 0…1 weight against the month's heaviest day.
    private var intensity: Double {
        guard monthMaxSpend > 0 else { return 0 }
        return min(1, spend / monthMaxSpend)
    }

    /// Heat backing: a single brand-teal hue that deepens with the day's spend.
    /// One hue keeps the month reading as a coherent heatmap; selection no longer
    /// touches the backing (it lives on the number circle). The floor sits above
    /// the neutral day tile so any renewal day reads as a distinct teal tile.
    private var backingOpacity: Double {
        guard hasEvents else { return 0 }
        return 0.14 + 0.16 * intensity
    }

    /// Only renewal days get a tile. A neutral fill on *every* in-month day was
    /// meant to read as structure, but a typical month is ~33 empty days to 2
    /// renewals — so the loudest thing on the screen became a field of grey
    /// boxes representing nothing. Empty days now fall back to the background
    /// (the weekday header and the numbers carry the structure), which leaves
    /// the teal heat tiles as the only marks in the grid.
    private var tileFill: Color {
        hasEvents ? Color.brand.opacity(backingOpacity) : .clear
    }

    var body: some View {
        Button(action: onSelect) {
            cell
                // Fixed height (not a width-driven square) keeps rows compact and
                // stops big-screen columns from stretching into tall sparse cells.
                .frame(maxWidth: .infinity, minHeight: 48, maxHeight: 48)
                .opacity(day.isInMonth ? 1 : 0.4)
                .contentShape(.rect(cornerRadius: Radius.chip))
        }
        .buttonStyle(DayButtonStyle())
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var cell: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                .fill(tileFill)
                .overlay {
                    // With the neutral tiles gone, the lightest heat wash (0.14)
                    // has no grey neighbour to read against — a hairline keeps a
                    // cheap renewal day as legible an object as an expensive one.
                    if hasEvents {
                        RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                            .strokeBorder(Color.brand.opacity(0.28), lineWidth: 1)
                    }
                }

            // Centered in the fixed-height cell — the empty marker still reserves
            // its height, so day numbers stay aligned across rows.
            VStack(spacing: 2) {
                dateLabel
                marker
            }
        }
    }

    /// The date sits on a filled circle when it's today (brand) or selected
    /// (neutral) — one shape for both, so the grid never stacks competing tokens.
    private var dateLabel: some View {
        Text(dayNumber)
            .font(.footnote.weight(isToday || isSelected ? .semibold : .regular))
            .monospacedDigit()
            .foregroundStyle(numberColor)
            .frame(width: Self.numberSize, height: Self.numberSize)
            .background {
                if isToday {
                    Circle().fill(Color.brand)
                } else if isSelected {
                    // Outline, not a solid fill. A filled neutral circle was
                    // fine among the old grey tiles; on the cleared-out grid it
                    // became the single heaviest mark on screen — louder than
                    // today's brand circle and every renewal tile.
                    Circle().strokeBorder(Color.primary.opacity(0.4), lineWidth: 1.5)
                }
            }
    }

    private var numberColor: Color {
        if isToday { return .white }
        return .primary
    }

    /// A single small brand chip marks a renewal; extra renewals collapse into "+N".
    /// Empty days reserve the chip's height so day numbers stay aligned across rows.
    @ViewBuilder
    private var marker: some View {
        if let first = events.first {
            HStack(spacing: 2) {
                BrandLogoView(subscription: first.subscription, size: Self.markerSize)
                    // At 18pt the logo's own hairline is too faint to hold a
                    // black mark (ChatGPT, Netflix) against a dark tile.
                    .overlay {
                        RoundedRectangle(cornerRadius: Self.markerSize * 0.24, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.4), lineWidth: 0.75)
                    }
                if events.count > 1 {
                    Text("+\(events.count - 1)")
                        .font(.system(size: 10, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            Color.clear.frame(height: Self.markerSize)
        }
    }

    private var accessibilityLabel: String {
        let when = day.date.formatted(.dateTime.weekday(.wide).day().month(.wide))
        let count = events.count
        let renewals = count == 0 ? "no renewals"
            : (count == 1 ? "1 renewal" : "\(count) renewals")
        return "\(isToday ? "Today, " : "")\(when), \(renewals)"
    }
}

/// Plain day cell with a subtle springy press scale for a tactile feel.
private struct DayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Agenda header

/// Selected-day header: the full date, a brand-tinted relative chip ("Today",
/// "in 3 days"), and the day's converted spend.
private struct AgendaHeader: View {
    let date: Date
    let events: [RenewalEvent]
    let preferred: String
    let rates: ExchangeRates
    let calendar: Calendar

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                if let relativeText {
                    Text(relativeText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.brand)
                }
            }
            Spacer()
            if let totalText {
                Text(totalText)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .textCase(nil)
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var relativeText: String? {
        let today = calendar.startOfDay(for: Date())
        let days = calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: date)).day ?? 0
        switch days {
        case 0: return String(localized: "Today")
        case 1: return String(localized: "Tomorrow")
        case let d where d > 1: return String(localized: "in \(d) days")
        default: return nil
        }
    }

    private var totalText: String? {
        guard !events.isEmpty else { return nil }
        var total: Decimal = 0
        var unconvertible = false
        for event in events {
            if let converted = rates.convert(event.subscription.amount,
                                             from: event.subscription.currencyCode, to: preferred) {
                total += converted
            } else {
                unconvertible = true
            }
        }
        return (unconvertible ? "~" : "") + total.formatted(.currency(code: preferred))
    }
}

// MARK: - Next up header

/// Header for the empty-day "Next up" section: a quiet note that the *selected*
/// day is clear, then the title for the renewals listed underneath.
///
/// The two lines were the other way round, which made the section read as
/// "Next up: nothing" directly above three upcoming charges — the caption looked
/// like it qualified the list rather than the selection. Leading with the date
/// scopes the "nothing" to the day the user tapped, and leaves "Next up"
/// adjacent to the rows it actually labels.
private struct NextUpHeader: View {
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Nothing on \(date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Next up")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .textCase(nil)
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Empty day note

/// Compact stand-in for a barren empty-day state: the selected date plus a quiet
/// "nothing due" line, leaving the room beneath for the "Next up" section.
private struct EmptyDayNote: View {
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.subheadline.weight(.semibold))
            Text("Nothing renews this day")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Month layout math

/// One slot in the month grid. Out-of-month slots fill the leading/trailing
/// weeks so every row is a complete week, mirroring the system calendar.
struct CalendarDay: Identifiable {
    /// Start of day — stable identity and lookup key into `eventsByDay`.
    let date: Date
    let isInMonth: Bool
    var id: Date { date }
}

/// Pure month-grid arithmetic, kept off the view so it stays testable.
enum MonthLayout {
    static func startOfMonth(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    /// Full weeks covering `month`, padded with adjacent-month days so the first
    /// column always lands on the locale's `firstWeekday`.
    static func days(in month: Date, calendar: Calendar = .current) -> [CalendarDay] {
        let first = startOfMonth(month, calendar: calendar)
        guard let range = calendar.range(of: .day, in: .month, for: first) else { return [] }
        let daysInMonth = range.count
        let firstWeekday = calendar.component(.weekday, from: first)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        guard let start = calendar.date(byAdding: .day, value: -leading, to: first) else { return [] }

        let totalCells = Int((Double(leading + daysInMonth) / 7).rounded(.up)) * 7
        return (0..<totalCells).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return CalendarDay(
                date: calendar.startOfDay(for: date),
                isInMonth: calendar.isDate(date, equalTo: first, toGranularity: .month)
            )
        }
    }

    /// Very-short weekday symbols rotated to begin at the locale's `firstWeekday`.
    static func orderedWeekdaySymbols(_ calendar: Calendar = .current) -> [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        guard symbols.count == 7 else { return symbols }
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }
}

#Preview {
    RenewalCalendarView()
        .modelContainer(.preview)
        .environment(CurrencyService())
}
