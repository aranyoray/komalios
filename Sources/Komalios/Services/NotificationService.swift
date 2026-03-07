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
                    #if DEBUG
                    print("🔔 Notification permission granted")
                    #endif
                }
            } catch {
                #if DEBUG
                print("🔔 Notification permission error: \(error)")
                #endif
            }
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
            #if DEBUG
            print("🔔 Error scheduling reconnection: \(error)")
            #endif
        }
    }

    // MARK: - Cancel

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
        // Anchor notifications removed (v2 spec §13)
    }
}
#endif
