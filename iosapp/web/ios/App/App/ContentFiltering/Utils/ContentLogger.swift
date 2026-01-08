//
//  ContentLogger.swift
//  Komal - Activity Logging
//
//  Manages activity logs with auto-cleanup
//

import Foundation

class ContentLogger {
    static let shared = ContentLogger()

    private let logsKey = "komal_activity_logs"
    private let userDefaults = UserDefaults.standard
    private var logs: [ActivityLog] = []
    private let queue = DispatchQueue(label: "com.komal.logger", attributes: .concurrent)

    private init() {
        loadLogs()
    }

    // MARK: - Logging
    func log(url: String, category: ContentCategory, action: FilterAction, wasBlocked: Bool, reason: String?) {
        let log = ActivityLog(
            url: url,
            category: category,
            action: action,
            wasBlocked: wasBlocked,
            reason: reason
        )

        queue.async(flags: .barrier) {
            self.logs.append(log)
            self.saveLogs()
        }

        // Send notification for blocked content
        if wasBlocked {
            sendBlockedNotification(category: category, url: url)
        }
    }

    // MARK: - Retrieval
    func getLogs(limit: Int? = nil) -> [ActivityLog] {
        var result: [ActivityLog] = []
        queue.sync {
            result = Array(logs.suffix(limit ?? logs.count))
        }
        return result
    }

    func getLogsForCategory(_ category: ContentCategory) -> [ActivityLog] {
        var result: [ActivityLog] = []
        queue.sync {
            result = logs.filter { $0.category == category }
        }
        return result
    }

    func getBlockedLogs() -> [ActivityLog] {
        var result: [ActivityLog] = []
        queue.sync {
            result = logs.filter { $0.wasBlocked }
        }
        return result
    }

    // MARK: - Cleanup
    func removeLogsOlderThan(days: Int) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()

        queue.async(flags: .barrier) {
            self.logs = self.logs.filter { $0.timestamp > cutoffDate }
            self.saveLogs()
        }
    }

    func trimToMaxEntries(_ max: Int) {
        guard max > 0 else { return }

        queue.async(flags: .barrier) {
            if self.logs.count > max {
                self.logs = Array(self.logs.suffix(max))
                self.saveLogs()
            }
        }
    }

    func clearLogs() {
        queue.async(flags: .barrier) {
            self.logs.removeAll()
            self.saveLogs()
        }
    }

    // MARK: - Persistence
    private func loadLogs() {
        queue.async(flags: .barrier) {
            if let data = self.userDefaults.data(forKey: self.logsKey),
               let decoded = try? JSONDecoder().decode([ActivityLog].self, from: data) {
                self.logs = decoded
            }
        }
    }

    private func saveLogs() {
        // Must be called from queue
        if let encoded = try? JSONEncoder().encode(logs) {
            userDefaults.set(encoded, forKey: logsKey)
        }
    }

    // MARK: - Notifications
    private func sendBlockedNotification(category: ContentCategory, url: String) {
        // Post local notification for parent app
        NotificationCenter.default.post(
            name: NSNotification.Name("KomalContentBlocked"),
            object: nil,
            userInfo: [
                "category": category.rawValue,
                "url": url,
                "timestamp": Date()
            ]
        )
    }

    // MARK: - Export
    func exportAsCSV() -> String {
        var csv = "Timestamp,URL,Category,Action,Blocked,Reason\n"

        queue.sync {
            for log in logs {
                let timestamp = ISO8601DateFormatter().string(from: log.timestamp)
                let url = log.url.replacingOccurrences(of: ",", with: " ")
                let reason = (log.reason ?? "").replacingOccurrences(of: ",", with: " ")

                csv += "\(timestamp),\(url),\(log.category.rawValue),\(log.action.rawValue),\(log.wasBlocked),\(reason)\n"
            }
        }

        return csv
    }
}
