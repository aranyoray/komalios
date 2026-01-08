//
//  NotificationHelper.swift
//  Komal - Push Notifications
//
//  Manages parent notification alerts
//

import Foundation
import UserNotifications

class NotificationHelper {
    static let shared = NotificationHelper()

    private init() {}

    // MARK: - Setup
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    // MARK: - Send Notifications
    func notifyContentBlocked(category: ContentCategory, url: String) {
        let content = UNMutableNotificationContent()
        content.title = "Content Blocked"
        content.body = "\(category.displayName) was blocked: \(url)"
        content.sound = .default
        content.badge = 1

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Immediate
        )

        UNUserNotificationCenter.current().add(request)
    }

    func notifyContentGated(category: ContentCategory, url: String) {
        let content = UNMutableNotificationContent()
        content.title = "Approval Needed"
        content.body = "Your child wants to access: \(category.displayName)"
        content.sound = .default
        content.categoryIdentifier = "CONTENT_APPROVAL"

        // Add actions
        let approveAction = UNNotificationAction(
            identifier: "APPROVE",
            title: "Approve",
            options: .foreground
        )
        let denyAction = UNNotificationAction(
            identifier: "DENY",
            title: "Deny",
            options: .destructive
        )

        let category = UNNotificationCategory(
            identifier: "CONTENT_APPROVAL",
            actions: [approveAction, denyAction],
            intentIdentifiers: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func notifyDailyReport(stats: FilteringStats) {
        let content = UNMutableNotificationContent()
        content.title = "Daily Content Report"
        content.body = "Today: \(stats.blocked) blocked, \(stats.gated) gated, \(stats.allowed) allowed"
        content.sound = .default

        // Schedule for 8 PM
        var dateComponents = DateComponents()
        dateComponents.hour = 20
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: "daily_report",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Badge Management
    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
}
