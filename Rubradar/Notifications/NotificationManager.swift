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
        ("On the day", 0),
        ("1 day before", 1),
        ("2 days before", 2),
        ("3 days before", 3),
        ("1 week before", 7),
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
