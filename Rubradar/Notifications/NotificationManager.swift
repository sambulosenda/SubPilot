//
//  NotificationManager.swift
//  Rubradar
//

import Foundation
import SwiftData
import UserNotifications

/// The selectable "remind me N days before" options, shared by the add/edit
/// form's per-subscription picker and the Settings default picker so they
/// can't drift apart.
enum ReminderLead {
    /// `(label, days)` pairs in display order.
    static let options: [(label: String, days: Int)] = [
        (String(localized: "On the day"), 0),
        (String(localized: "1 day before"), 1),
        (String(localized: "2 days before"), 2),
        (String(localized: "3 days before"), 3),
        (String(localized: "1 week before"), 7),
    ]

    /// Default lead for a brand-new subscription when the user hasn't set one.
    static let defaultDays = 3

    /// UserDefaults key backing the global default (see Settings).
    static let defaultsKey = "defaultReminderLeadDays"

    /// The user's chosen global default, falling back to `defaultDays`.
    static var storedDefault: Int {
        UserDefaults.standard.object(forKey: defaultsKey) as? Int ?? defaultDays
    }
}

/// Settings + scheduling constants for the monthly spend recap — a low-frequency
/// re-engagement nudge summarising what the user is spending.
enum MonthlyRecap {
    /// UserDefaults key backing the Settings toggle (default on).
    static let enabledKey = "monthlyRecapEnabled"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    /// Pre-schedule this many future months so a user who stops opening the app
    /// still gets nudged; the figures refresh on every reschedule.
    static let monthsAhead = 6
}

/// Schedules local reminders for upcoming renewals and trial conversions.
/// No push server — everything is local (`UNUserNotificationCenter`).
@MainActor
final class NotificationManager: NSObject {
    static let shared = NotificationManager()

    static let renewalCategory = "RENEWAL"
    static let cancelAction = "MARK_CANCELLED"
    private let center = UNUserNotificationCenter.current()

    private override init() {
        super.init()
        center.delegate = self
        registerCategories()
    }

    private func registerCategories() {
        let cancel = UNNotificationAction(
            identifier: Self.cancelAction,
            title: String(localized: "Mark as cancelled"),
            options: [.destructive]
        )
        let category = UNNotificationCategory(
            identifier: Self.renewalCategory,
            actions: [cancel],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    var authorizationStatus: UNAuthorizationStatus {
        get async { await center.notificationSettings().authorizationStatus }
    }

    /// Whether the user has reminders switched on (default on).
    var remindersEnabled: Bool {
        UserDefaults.standard.object(forKey: "remindersEnabled") as? Bool ?? true
    }

    /// Fetches all subscriptions and reschedules. Call after any add/edit/delete.
    func rescheduleAll(modelContext: ModelContext) async {
        let subs = (try? modelContext.fetch(FetchDescriptor<Subscription>())) ?? []
        await reschedule(for: subs, enabled: remindersEnabled)
        // Added after `reschedule` clears all pending requests, so it survives.
        await scheduleMonthlyRecap(for: subs)
    }

    /// How many upcoming renewal occurrences to pre-schedule per subscription,
    /// so a user who doesn't reopen the app still gets the next few reminders
    /// (nothing reschedules after a notification fires except an app launch).
    /// Kept small — iOS caps pending local notifications at 64 per app.
    private static let occurrencesPerSubscription = 2

    /// Clears all pending reminders and reschedules from the current data.
    func reschedule(for subscriptions: [Subscription], enabled: Bool) async {
        center.removeAllPendingNotificationRequests()
        guard enabled else { return }

        let status = await authorizationStatus
        guard status == .authorized || status == .provisional else { return }

        let now = Date()
        let calendar = Calendar.current
        for sub in subscriptions where !sub.isCancelled {
            var trialEndScheduled: Date?
            if sub.isFreeTrial, let trialEnd = sub.trialEndDate {
                // Missing a trial end costs real money, so it escalates: the
                // user's chosen lead reminder, then day-before, then day-of.
                // The extra two are skipped when the lead already lands on
                // that day (leadDays 0/1) so no day gets two banners.
                schedule(
                    id: "trial-\(sub.id.uuidString)",
                    title: String(localized: "\(sub.name) trial ending"),
                    body: String(localized: "Your free trial converts to \(sub.formattedAmount) soon."),
                    fireDate: Self.reminderFireDate(before: trialEnd, leadDays: sub.reminderLeadDays,
                                                    now: now, calendar: calendar),
                    subscriptionID: sub.id
                )
                if sub.reminderLeadDays != 1 {
                    schedule(
                        id: "trial-eve-\(sub.id.uuidString)",
                        title: String(localized: "\(sub.name) trial ends tomorrow"),
                        body: String(localized: "You'll be charged \(sub.formattedAmount) tomorrow unless you cancel."),
                        fireDate: Self.reminderFireDate(before: trialEnd, leadDays: 1,
                                                        now: now, calendar: calendar),
                        subscriptionID: sub.id
                    )
                }
                if sub.reminderLeadDays != 0 {
                    schedule(
                        id: "trial-day-\(sub.id.uuidString)",
                        title: String(localized: "\(sub.name) trial ends today"),
                        body: String(localized: "You'll be charged \(sub.formattedAmount) today unless you cancel."),
                        fireDate: Self.reminderFireDate(before: trialEnd, leadDays: 0,
                                                        now: now, calendar: calendar),
                        subscriptionID: sub.id
                    )
                }
                trialEndScheduled = trialEnd
            }
            // A notice period moves the real decision point ahead of the
            // renewal: remind before the last day to cancel, and again on it.
            if !sub.isFreeTrial, let deadline = sub.cancelDeadline(asOf: now, calendar: calendar) {
                let day = deadline.date.formatted(.dateTime.day().month())
                schedule(
                    id: "deadline-\(sub.id.uuidString)",
                    title: String(localized: "\(sub.name) cancel deadline"),
                    body: String(localized: "Cancel by \(day) or it renews at \(sub.formattedAmount)."),
                    fireDate: Self.reminderFireDate(before: deadline.date, leadDays: sub.reminderLeadDays,
                                                    now: now, calendar: calendar),
                    subscriptionID: sub.id
                )
                if sub.reminderLeadDays != 0 {
                    schedule(
                        id: "deadline-day-\(sub.id.uuidString)",
                        title: String(localized: "Last day to cancel \(sub.name)"),
                        body: String(localized: "After today it renews at \(sub.formattedAmount)."),
                        fireDate: Self.reminderFireDate(before: deadline.date, leadDays: 0,
                                                        now: now, calendar: calendar),
                        subscriptionID: sub.id
                    )
                }
            }
            // Project the stored anchor forward — it is never advanced once a
            // charge passes, so reading it raw would schedule in the past.
            // Occurrences are computed from the anchor by index (see
            // BillingCycle) so month-end renewals don't drift.
            let anchor = (sub.isFreeTrial && sub.trialEndDate != nil) ? sub.trialEndDate! : sub.nextRenewalDate
            let (firstIndex, _) = sub.billingCycle.firstOccurrence(
                onOrAfter: calendar.startOfDay(for: now), anchor: anchor,
                customDays: sub.customCycleDays, calendar: calendar
            )
            for slot in 0..<Self.occurrencesPerSubscription {
                let charge = sub.billingCycle.date(byAddingCycles: firstIndex + slot, to: anchor,
                                                   customDays: sub.customCycleDays, calendar: calendar)
                // An active trial's first "charge" IS the trial end — the trial
                // reminder above covers it; a second banner at the same minute
                // would be noise.
                if charge == trialEndScheduled { continue }
                schedule(
                    id: "renewal-\(sub.id.uuidString)-\(slot)",
                    title: String(localized: "\(sub.name) renews soon"),
                    body: String(localized: "\(sub.formattedAmount) will be charged on \(charge.formatted(.dateTime.day().month()))."),
                    fireDate: Self.reminderFireDate(before: charge, leadDays: sub.reminderLeadDays,
                                                    now: now, calendar: calendar),
                    subscriptionID: sub.id
                )
            }
        }
    }

    /// Schedules the monthly spend recap on the 1st of each month at 10 AM. Skips
    /// when disabled, unauthorized, or there's nothing to report. Pre-schedules
    /// several months ahead; figures refresh whenever subscriptions change.
    func scheduleMonthlyRecap(for subscriptions: [Subscription]) async {
        guard MonthlyRecap.isEnabled else { return }

        let status = await authorizationStatus
        guard status == .authorized || status == .provisional else { return }

        let active = subscriptions.filter { !$0.isCancelled }
        let preferred = UserDefaults.standard.string(forKey: "preferredCurrencyCode")
            ?? Locale.current.currency?.identifier ?? "GBP"
        let summary = SpendSummary.make(from: subscriptions, preferred: preferred, rates: CurrencyService.shared.rates)
        guard !active.isEmpty, summary.monthlyTotal > 0 else { return }

        let body = String(localized: "You're spending about \(summary.formattedMonthly) a month across \(active.count) subscriptions. Tap to see where it goes.")

        let cal = Calendar.current
        guard let firstRecap = cal.nextDate(
            after: Date(),
            matching: DateComponents(day: 1, hour: 10, minute: 0),
            matchingPolicy: .nextTime
        ) else { return }

        // Price rises that will still be recent when the *next* recap fires.
        // Only that first notification gets the extra sentence — later months'
        // figures refresh on every reschedule anyway, so a stale rise count
        // months out would be wrong more often than right.
        let risesAtFirstFire = MonthlyRecapData
            .recentPriceChanges(in: subscriptions, now: firstRecap)
            .filter(\.isRise).count

        for offset in 0..<MonthlyRecap.monthsAhead {
            guard let fire = cal.date(byAdding: .month, value: offset, to: firstRecap) else { continue }
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Your subscriptions this month")
            // Inflection markup isn't processed by plain String(localized:), so
            // the plural is spelled out (the catalog can vary it per locale).
            let riseSentence = risesAtFirstFire == 1
                ? String(localized: "1 subscription price went up recently.")
                : String(localized: "\(risesAtFirstFire) subscription prices went up recently.")
            content.body = (offset == 0 && risesAtFirstFire > 0) ? body + " " + riseSentence : body
            content.sound = .default
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: "recap-\(offset)", content: content, trigger: trigger))
        }
    }

    /// When a reminder for a charge on `renewal` should fire: 9am local on the
    /// lead day. If that moment already passed but the charge is today or later
    /// (a subscription added inside its own lead window — the charge the user
    /// most needs to hear about), it clamps to a couple of minutes from `now`
    /// instead of silently never firing. Charges before today return nil.
    /// Pure and injectable for tests.
    nonisolated static func reminderFireDate(
        before renewal: Date,
        leadDays: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date? {
        let lead = calendar.date(byAdding: .day, value: -max(0, leadDays), to: renewal) ?? renewal
        let preferred = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: lead) ?? lead
        if preferred > now { return preferred }
        guard calendar.startOfDay(for: renewal) >= calendar.startOfDay(for: now) else { return nil }
        return now.addingTimeInterval(2 * 60)
    }

    #if DEBUG
    /// Fires a real renewal-style local notification a few seconds out, so App
    /// Store screenshot sessions can capture an authentic banner (the simulator's
    /// `simctl push` path is unreliable on some runtimes). Uses the same copy and
    /// `RENEWAL` category as production, so the captured banner is genuine.
    func scheduleDemoRenewalBanner() async {
        guard await requestAuthorization() else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Netflix renews soon")
        content.body = String(localized: "$17.99 will be charged on 8 Jul.")
        content.sound = .default
        content.categoryIdentifier = Self.renewalCategory
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 6, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: "demo-renewal-banner", content: content, trigger: trigger))
    }
    #endif

    private func schedule(id: String, title: String, body: String, fireDate: Date?, subscriptionID: UUID) {
        guard let fireDate, fireDate > Date() else { return }   // don't schedule in the past

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = Self.renewalCategory
        content.userInfo = ["subscriptionID": subscriptionID.uuidString]

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}

// MARK: - Delegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    // Show banners while the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    // Handle the "Mark as cancelled" action.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == Self.cancelAction,
              let idString = response.notification.request.content.userInfo["subscriptionID"] as? String,
              let id = UUID(uuidString: idString) else { return }

        let context = ModelContainer.app.mainContext
        let descriptor = FetchDescriptor<Subscription>(predicate: #Predicate { $0.id == id })
        if let sub = try? context.fetch(descriptor).first {
            sub.isCancelled = true
            sub.updatedAt = Date()
            try? context.save()
            // Drop the cancelled sub's other pending reminders and get the
            // widget off the stale data — the app may not open for days.
            await rescheduleAll(modelContext: context)
            WidgetSync.refresh(modelContext: context)
        }
    }
}
