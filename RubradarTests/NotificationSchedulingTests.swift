//
//  NotificationSchedulingTests.swift
//  RubradarTests
//

import Testing
import Foundation
@testable import Rubradar

/// `reminderFireDate` picks 9am local on the lead day — and must clamp forward
/// (not silently drop) when the charge is already inside the lead window,
/// because that imminent charge is the reminder the user most needs.
struct NotificationSchedulingTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        DateComponents(calendar: calendar, year: y, month: m, day: d, hour: h, minute: min).date!
    }

    @Test func firesAt9amOnTheLeadDay() {
        let renewal = date(2026, 7, 20)
        let now = date(2026, 7, 1, 12, 0)
        let fire = NotificationManager.reminderFireDate(before: renewal, leadDays: 3, now: now, calendar: calendar)
        #expect(fire == date(2026, 7, 17, 9, 0))
    }

    @Test func clampsWhenRenewalIsInsideTheLeadWindow() {
        // Renews in 2 days with a 3-day lead: 9am-on-lead-day already passed.
        // Must fire shortly after now — never silently skip.
        let renewal = date(2026, 7, 3)
        let now = date(2026, 7, 1, 12, 0)
        let fire = NotificationManager.reminderFireDate(before: renewal, leadDays: 3, now: now, calendar: calendar)
        #expect(fire != nil)
        #expect(fire! > now)
        #expect(fire! < renewal)
    }

    @Test func clampsForARenewalLaterToday() {
        let renewal = date(2026, 7, 1, 0, 0)   // stored anchors are midnight-ish
        let now = date(2026, 7, 1, 15, 0)
        let fire = NotificationManager.reminderFireDate(before: renewal, leadDays: 0, now: now, calendar: calendar)
        #expect(fire != nil)
        #expect(fire! > now)
    }

    @Test func neverFiresForAPastCharge() {
        let renewal = date(2026, 6, 28)
        let now = date(2026, 7, 1, 12, 0)
        #expect(NotificationManager.reminderFireDate(before: renewal, leadDays: 3, now: now, calendar: calendar) == nil)
    }

    @Test func zeroLeadFiresAt9amOnTheRenewalDay() {
        let renewal = date(2026, 7, 20)
        let now = date(2026, 7, 1, 12, 0)
        let fire = NotificationManager.reminderFireDate(before: renewal, leadDays: 0, now: now, calendar: calendar)
        #expect(fire == date(2026, 7, 20, 9, 0))
    }
}
