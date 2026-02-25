#if os(iOS)
import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    // MARK: - Permission

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("🔔 Notification permission granted")
            } else if let error = error {
                print("🔔 Notification permission error: \(error)")
            }
        }
    }

    // MARK: - Morning Anchor

    func scheduleMorningAnchor(hour: Int = 8, minute: Int = 0) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            self._scheduleMorningAnchor(hour: hour, minute: minute)
        }
    }

    private func _scheduleMorningAnchor(hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = LanguageManager.shared.localized("notification.morning.title")
        content.body = LanguageManager.shared.localized("notification.morning.body")
        content.sound = .default
        content.categoryIdentifier = "morningAnchor"

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "morningAnchor", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("🔔 Error scheduling morning anchor: \(error)")
            } else {
                print("🔔 Morning anchor scheduled at \(hour):\(String(format: "%02d", minute))")
            }
        }
    }

    // MARK: - Evening Anchor

    func scheduleEveningAnchor(hour: Int = 19, minute: Int = 0) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            self._scheduleEveningAnchor(hour: hour, minute: minute)
        }
    }

    private func _scheduleEveningAnchor(hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = LanguageManager.shared.localized("notification.evening.title")
        content.body = LanguageManager.shared.localized("notification.evening.body")
        content.sound = .default
        content.categoryIdentifier = "eveningAnchor"

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "eveningAnchor", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("🔔 Error scheduling evening anchor: \(error)")
            } else {
                print("🔔 Evening anchor scheduled at \(hour):\(String(format: "%02d", minute))")
            }
        }
    }

    // MARK: - Reconnection Reminder

    func scheduleReconnectionReminder(afterDays: Int = 3) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            self._scheduleReconnectionReminder(afterDays: afterDays)
        }
    }

    private func _scheduleReconnectionReminder(afterDays: Int) {
        let content = UNMutableNotificationContent()
        content.title = LanguageManager.shared.localized("notification.reconnect.title")
        content.body = LanguageManager.shared.localized("notification.reconnect.body")
        content.sound = .default
        content.categoryIdentifier = "reconnection"

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(afterDays * 24 * 60 * 60),
            repeats: false
        )
        let request = UNNotificationRequest(identifier: "reconnection", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("🔔 Error scheduling reconnection: \(error)")
            }
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
