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
                    ContentUnavailableView(
                        "No upcoming renewals",
                        systemImage: "calendar",
                        description: Text("Add a subscription to see when it renews.")
                    )
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
                    .frame(maxWidth: 220)
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
        VStack(spacing: 0) {
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
                    calendar: calendar,
                    pageForward: pageForward,
                    onSelect: select(_:)
                )
                .contentShape(.rect)
                .gesture(pagingGesture)
            }
            .padding(Spacing.md)
            .background(Color.cardBackground, in: .rect(cornerRadius: Radius.card))
            .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.md)

            dayAgenda(for: selectedDate, in: data)
        }
        .background(Color.appBackground)
    }

    @ViewBuilder
    private func dayAgenda(for date: Date, in data: CalendarData) -> some View {
        let dayEvents = data.eventsByDay[calendar.startOfDay(for: date)] ?? []
        List {
            Section {
                if dayEvents.isEmpty {
                    ContentUnavailableView {
                        Label("Nothing renews this day", systemImage: "checkmark.circle")
                    } description: {
                        Text("Pick a day with a marker to see what's due.")
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(dayEvents) { event in
                        NavigationLink(value: event.subscription) {
                            RenewalEventRow(event: event, showsDate: false)
                        }
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
        .listSectionSpacing(.compact)
        .tabBarMinimizeBehavior(.onScrollDown)
    }

    // MARK: Upcoming (timeline)

    private func timeline(_ months: [RenewalMonth]) -> some View {
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
    let months: [RenewalMonth]

    var isEmpty: Bool { months.isEmpty }

    init(events: [RenewalEvent], preferred: String, rates: ExchangeRates, calendar: Calendar) {
        eventsByDay = Dictionary(grouping: events) { calendar.startOfDay(for: $0.date) }
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
    /// The day agenda already groups by date, so it hides the leading date badge.
    var showsDate = true

    private var sub: Subscription { event.subscription }

    var body: some View {
        HStack(spacing: Spacing.md) {
            if showsDate {
                DateBadge(date: event.date)
            }

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
    let calendar: Calendar
    let pageForward: Bool
    let onSelect: (Date) -> Void

    @ScaledMetric(relativeTo: .body) private var cellSize = 36
    /// Lets the teal selection disc glide between days of the visible month.
    @Namespace private var selectionNamespace

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
        LazyVGrid(columns: columns, spacing: Spacing.sm) {
            ForEach(MonthLayout.days(in: month, calendar: calendar)) { day in
                DayCell(
                    day: day,
                    isSelected: calendar.isDate(day.date, inSameDayAs: selectedDate),
                    isToday: calendar.isDateInToday(day.date),
                    events: eventsByDay[day.date] ?? [],
                    cellSize: cellSize,
                    selectionNamespace: selectionNamespace,
                    selectionID: month,
                    onSelect: { onSelect(day.date) }
                )
            }
        }
    }
}

private struct DayCell: View {
    let day: CalendarDay
    let isSelected: Bool
    let isToday: Bool
    let events: [RenewalEvent]
    let cellSize: CGFloat
    /// Shared namespace + per-month id so the selection disc glides between days.
    let selectionNamespace: Namespace.ID
    let selectionID: Date
    let onSelect: () -> Void

    private var dayNumber: String {
        day.date.formatted(.dateTime.day())
    }

    /// Brand chips track the cell size so they stay proportional under Dynamic Type.
    private var markerSize: CGFloat { cellSize * 0.4 }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 3) {
                Text(dayNumber)
                    .font(.callout.weight(isSelected || isToday ? .bold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(numberColor)
                    .frame(width: cellSize, height: cellSize)
                    .background(numberBackground)
                markers
                    .frame(height: markerSize)
            }
            .frame(maxWidth: .infinity)
            .opacity(day.isInMonth ? 1 : 0.35)
            .contentShape(.rect)
        }
        .buttonStyle(DayButtonStyle())
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private var numberBackground: some View {
        if isSelected {
            Circle()
                .fill(Color.brand.gradient)
                .shadow(color: Color.brand.opacity(0.4), radius: 5, y: 2)
                .matchedGeometryEffect(id: selectionID, in: selectionNamespace)
        } else if isToday {
            Circle().strokeBorder(Color.brand, lineWidth: 1.5)
        }
    }

    private var numberColor: Color {
        if isSelected { return .white }
        if isToday { return .brand }
        return day.isInMonth ? .primary : .secondary
    }

    /// Up to two brand chips per day; a third-or-more renewal collapses into a
    /// "+N" pill so the row never outgrows the cell on compact devices.
    @ViewBuilder
    private var markers: some View {
        if events.isEmpty {
            Color.clear
        } else {
            HStack(spacing: 2) {
                BrandLogoView(subscription: events[0].subscription, size: markerSize)
                if events.count == 2 {
                    BrandLogoView(subscription: events[1].subscription, size: markerSize)
                } else if events.count > 2 {
                    Text("+\(events.count - 1)")
                        .font(.system(size: 9, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 3)
                        .frame(height: markerSize)
                        .background(Color(.tertiarySystemFill), in: .capsule)
                }
            }
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

/// Plain day cell with a springy press scale for a tactile feel.
private struct DayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.86 : 1)
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
