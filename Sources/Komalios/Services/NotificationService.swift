#if os(iOS)
import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    // MARK: - Permission

    func requestPermission() {
        Task {
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                if granted {
                    print("🔔 Notification permission granted")
                }
            } catch {
                print("🔔 Notification permission error: \(error)")
            }
        }
    }

    // MARK: - Morning Anchor

    func scheduleMorningAnchor(hour: Int = 8, minute: Int = 0) {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            guard settings.authorizationStatus == .authorized else { return }
            let title = LanguageManager.localized("notification.morning.title")
            let body = LanguageManager.localized("notification.morning.body")
            await _scheduleMorningAnchor(hour: hour, minute: minute, title: title, body: body)
        }
    }

    private func _scheduleMorningAnchor(hour: Int, minute: Int, title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "morningAnchor"

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "morningAnchor", content: content, trigger: trigger)

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("🔔 Morning anchor scheduled at \(hour):\(String(format: "%02d", minute))")
        } catch {
            print("🔔 Error scheduling morning anchor: \(error)")
        }
    }

    // MARK: - Evening Anchor

    func scheduleEveningAnchor(hour: Int = 19, minute: Int = 0) {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            guard settings.authorizationStatus == .authorized else { return }
            let title = LanguageManager.localized("notification.evening.title")
            let body = LanguageManager.localized("notification.evening.body")
            await _scheduleEveningAnchor(hour: hour, minute: minute, title: title, body: body)
        }
    }

    private func _scheduleEveningAnchor(hour: Int, minute: Int, title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "eveningAnchor"

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "eveningAnchor", content: content, trigger: trigger)

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("🔔 Evening anchor scheduled at \(hour):\(String(format: "%02d", minute))")
        } catch {
            print("🔔 Error scheduling evening anchor: \(error)")
        }
    }

    // MARK: - Reconnection Reminder

    func scheduleReconnectionReminder(afterDays: Int = 3) {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            guard settings.authorizationStatus == .authorized else { return }
            let title = LanguageManager.localized("notification.reconnect.title")
            let body = LanguageManager.localized("notification.reconnect.body")
            await _scheduleReconnectionReminder(afterDays: afterDays, title: title, body: body)
        }
    }

    private func _scheduleReconnectionReminder(afterDays: Int, title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "reconnection"

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(afterDays * 24 * 60 * 60),
            repeats: false
        )
        let request = UNNotificationRequest(identifier: "reconnection", content: content, trigger: trigger)

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("🔔 Error scheduling reconnection: \(error)")
        }
    }

    // MARK: - Cancel

    func cancelMorningAnchor() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["morningAnchor"])
    }

    func cancelEveningAnchor() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["eveningAnchor"])
    }

    func cancelReconnection() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["reconnection"])
    }

    // MARK: - Notification Tap Tracking

    private var lastNotificationTapDate: Date?

    /// Record that a notification was tapped (call from notification delegate)
    func recordNotificationTap() {
        lastNotificationTapDate = Date()
    }

    /// Check if a notification was tapped within the last 60 seconds
    func wasRecentNotificationTapped() -> Bool {
        guard let tapDate = lastNotificationTapDate else { return false }
        return Date().timeIntervalSince(tapDate) < 60
    }

    /// Update notification schedules based on retention state
    func updateSchedules(retentionState: RetentionState) {
        if retentionState.morningAnchorEnabled {
            scheduleMorningAnchor()
        } else {
            cancelMorningAnchor()
        }

        if retentionState.eveningAnchorEnabled {
            scheduleEveningAnchor()
        } else {
            cancelEveningAnchor()
        }
    }
}
#endif
