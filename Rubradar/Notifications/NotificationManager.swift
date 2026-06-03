//
//  NotificationManager.swift
//  Rubradar
//

import Foundation
import SwiftData
import UserNotifications

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
            schedule(
                id: "renewal-\(sub.id.uuidString)",
                title: "\(sub.name) renews soon",
                body: "\(sub.formattedAmount) will be charged on \(sub.nextRenewalDate.formatted(.dateTime.day().month())).",
                fireDate: reminderDate(before: sub.nextRenewalDate, leadDays: sub.reminderLeadDays),
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
