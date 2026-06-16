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
            title: "Mark as cancelled",
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

    /// Clears all pending reminders and reschedules from the current data.
    func reschedule(for subscriptions: [Subscription], enabled: Bool) async {
        center.removeAllPendingNotificationRequests()
        guard enabled else { return }

        let status = await authorizationStatus
        guard status == .authorized || status == .provisional else { return }

        for sub in subscriptions where !sub.isCancelled {
            if sub.isFreeTrial, let trialEnd = sub.trialEndDate {
                schedule(
                    id: "trial-\(sub.id.uuidString)",
                    title: "\(sub.name) trial ending",
                    body: "Your free trial converts to \(sub.formattedAmount) soon.",
                    fireDate: reminderDate(before: trialEnd, leadDays: sub.reminderLeadDays),
                    subscriptionID: sub.id
                )
            }
            // Project the stored anchor to the next *future* charge; the anchor is
            // never advanced once a renewal passes, so reading it raw would schedule
            // in the past (skipped) and reminders would stop after the first cycle.
            let nextCharge = sub.projectedNextRenewal()
            schedule(
                id: "renewal-\(sub.id.uuidString)",
                title: "\(sub.name) renews soon",
                body: "\(sub.formattedAmount) will be charged on \(nextCharge.formatted(.dateTime.day().month())).",
                fireDate: reminderDate(before: nextCharge, leadDays: sub.reminderLeadDays),
                subscriptionID: sub.id
            )
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

        let countWord = active.count == 1 ? "subscription" : "subscriptions"
        let body = "You're spending about \(summary.formattedMonthly) a month across \(active.count) \(countWord). Tap to see where it goes."

        let cal = Calendar.current
        guard let firstRecap = cal.nextDate(
            after: Date(),
            matching: DateComponents(day: 1, hour: 10, minute: 0),
            matchingPolicy: .nextTime
        ) else { return }

        for offset in 0..<MonthlyRecap.monthsAhead {
            guard let fire = cal.date(byAdding: .month, value: offset, to: firstRecap) else { continue }
            let content = UNMutableNotificationContent()
            content.title = "Your subscriptions this month"
            content.body = body
            content.sound = .default
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: "recap-\(offset)", content: content, trigger: trigger))
        }
    }

    private func reminderDate(before date: Date, leadDays: Int) -> Date {
        let cal = Calendar.current
        let lead = cal.date(byAdding: .day, value: -max(0, leadDays), to: date) ?? date
        // Fire at 9am local time on the reminder day.
        return cal.date(bySettingHour: 9, minute: 0, second: 0, of: lead) ?? lead
    }

    private func schedule(id: String, title: String, body: String, fireDate: Date, subscriptionID: UUID) {
        guard fireDate > Date() else { return }   // don't schedule in the past

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
        }
    }
}
