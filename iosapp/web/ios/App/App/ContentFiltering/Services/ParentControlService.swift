//
//  ParentControlService.swift
//  Komal - Parent Control Management
//
//  Manages parent authentication, settings, and activity logs
//

import Foundation
import LocalAuthentication

class ParentControlService {
    static let shared = ParentControlService()

    // MARK: - Properties
    private let userDefaults = UserDefaults.standard
    private let keychain = KeychainHelper.shared
    private let logger = ContentLogger.shared

    // Settings keys
    private let pinKey = "komal_parent_pin"
    private let biometricsKey = "komal_use_biometrics"
    private let childAgeKey = "komal_child_age"
    private let maxLogEntriesKey = "komal_max_log_entries"
    private let logRetentionDaysKey = "komal_log_retention_days"
    private let onboardingCompletedKey = "komal_onboarding_completed"

    // Pro Tips: Configurable settings
    var useBiometrics: Bool {
        get { userDefaults.bool(forKey: biometricsKey) }
        set { userDefaults.set(newValue, forKey: biometricsKey) }
    }

    var maxLogEntries: Int {
        get { userDefaults.integer(forKey: maxLogEntriesKey) }
        set { userDefaults.set(newValue, forKey: maxLogEntriesKey) }
    }

    var logRetentionDays: Int {
        get { userDefaults.integer(forKey: logRetentionDaysKey) }
        set { userDefaults.set(newValue, forKey: logRetentionDaysKey) }
    }

    var childAge: Int {
        get { userDefaults.integer(forKey: childAgeKey) }
        set { userDefaults.set(newValue, forKey: childAgeKey) }
    }

    var isOnboardingCompleted: Bool {
        get { userDefaults.bool(forKey: onboardingCompletedKey) }
        set { userDefaults.set(newValue, forKey: onboardingCompletedKey) }
    }

    // MARK: - Initialization
    private init() {
        // Set defaults
        if maxLogEntries == 0 {
            maxLogEntries = 100
        }
        if logRetentionDays == 0 {
            logRetentionDays = 30
        }
    }

    // MARK: - PIN Management
    func setPIN(_ pin: String) throws {
        guard pin.count == 4, pin.allSatisfy({ $0.isNumber }) else {
            throw ParentControlError.invalidPIN
        }
        try keychain.save(pin, forKey: pinKey)
    }

    func validatePIN(_ pin: String) -> Bool {
        guard let storedPin = try? keychain.get(pinKey) else {
            return false
        }
        return pin == storedPin
    }

    func hasPINSet() -> Bool {
        return (try? keychain.get(pinKey)) != nil
    }

    // MARK: - Biometric Authentication
    func authenticateWithBiometrics(completion: @escaping (Bool, Error?) -> Void) {
        guard useBiometrics else {
            completion(false, ParentControlError.biometricsNotEnabled)
            return
        }

        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Authenticate to access parent controls"

            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authError in
                DispatchQueue.main.async {
                    completion(success, authError)
                }
            }
        } else {
            completion(false, error)
        }
    }

    func isBiometricsAvailable() -> Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    // MARK: - Category Rules Management
    func setCustomRule(for category: ContentCategory, action: FilterAction) {
        let key = "komal_rule_\(category.rawValue)"
        userDefaults.set(action.rawValue, forKey: key)
    }

    func getCustomRule(for category: ContentCategory) -> FilterAction? {
        let key = "komal_rule_\(category.rawValue)"
        guard let rawValue = userDefaults.string(forKey: key) else { return nil }
        return FilterAction(rawValue: rawValue)
    }

    func clearCustomRules() {
        for category in ContentCategory.allCases {
            let key = "komal_rule_\(category.rawValue)"
            userDefaults.removeObject(forKey: key)
        }
    }

    // MARK: - Activity Logs
    func getActivityLogs(limit: Int? = nil) -> [ActivityLog] {
        return logger.getLogs(limit: limit)
    }

    func clearActivityLogs() {
        logger.clearLogs()
    }

    // MARK: - Pro Tips: Auto-cleanup
    func enableAutoCleanup() {
        // Run cleanup on app launch
        cleanupOldLogs()
        cleanupOldSettings()

        // Schedule periodic cleanup
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.cleanupOldLogs()
        }
    }

    private func cleanupOldLogs() {
        logger.removeLogsOlderThan(days: logRetentionDays)
        logger.trimToMaxEntries(maxLogEntries)
    }

    private func cleanupOldSettings() {
        // Remove any obsolete settings from older versions
        let obsoleteKeys = [
            "komal_legacy_setting_1",
            "komal_old_cache",
            "komal_deprecated_flag"
        ]
        obsoleteKeys.forEach { userDefaults.removeObject(forKey: $0) }
    }

    // MARK: - Pro Tips: Export Settings
    func getSettingsSummary() -> [String: Any] {
        return [
            "version": "1.0.0",
            "child_age": childAge,
            "use_biometrics": useBiometrics,
            "max_log_entries": maxLogEntries,
            "log_retention_days": logRetentionDays,
            "onboarding_completed": isOnboardingCompleted,
            "custom_rules": getCustomRulesExport(),
            "logs_count": getActivityLogs().count,
            "exported_at": ISO8601DateFormatter().string(from: Date())
        ]
    }

    func exportSettingsAsJSON() -> String? {
        let settings = getSettingsSummary()
        guard let jsonData = try? JSONSerialization.data(withJSONObject: settings, options: .prettyPrinted),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return nil
        }
        return jsonString
    }

    private func getCustomRulesExport() -> [[String: String]] {
        var rules: [[String: String]] = []
        for category in ContentCategory.allCases {
            if let action = getCustomRule(for: category) {
                rules.append([
                    "category": category.rawValue,
                    "action": action.rawValue
                ])
            }
        }
        return rules
    }

    // MARK: - Reset
    func resetAllSettings() {
        clearCustomRules()
        clearActivityLogs()
        try? keychain.delete(pinKey)

        userDefaults.removeObject(forKey: biometricsKey)
        userDefaults.removeObject(forKey: childAgeKey)
        userDefaults.removeObject(forKey: maxLogEntriesKey)
        userDefaults.removeObject(forKey: logRetentionDaysKey)
        userDefaults.removeObject(forKey: onboardingCompletedKey)
    }
}

// MARK: - Error Types
enum ParentControlError: LocalizedError {
    case invalidPIN
    case biometricsNotEnabled
    case authenticationFailed

    var errorDescription: String? {
        switch self {
        case .invalidPIN:
            return "PIN must be 4 digits"
        case .biometricsNotEnabled:
            return "Biometrics not enabled"
        case .authenticationFailed:
            return "Authentication failed"
        }
    }
}

// MARK: - Activity Log Model
struct ActivityLog: Codable {
    let id: UUID
    let timestamp: Date
    let url: String
    let category: ContentCategory
    let action: FilterAction
    let wasBlocked: Bool
    let reason: String?

    init(url: String, category: ContentCategory, action: FilterAction, wasBlocked: Bool, reason: String? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.url = url
        self.category = category
        self.action = action
        self.wasBlocked = wasBlocked
        self.reason = reason
    }
}
