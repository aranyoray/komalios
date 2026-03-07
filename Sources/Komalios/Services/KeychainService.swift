import Foundation
import Security

enum KeychainService {
    private static let service = "com.komal.parentpin"
    private static let account = "parentPIN"

    @discardableResult
    static func savePin(_ pin: String) -> Bool {
        guard let data = pin.data(using: .utf8) else { return false }
        deletePin()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func getPin() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func hasPin() -> Bool { getPin() != nil }

    // MARK: - Secure Data Storage (for parent settings)

    @discardableResult
    static func saveSecureData(_ data: Data, forKey key: String) -> Bool {
        deleteSecureData(forKey: key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.komal.secure",
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func loadSecureData(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.komal.secure",
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return data
    }

    @discardableResult
    static func deleteSecureData(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.komal.secure",
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    @discardableResult
    static func deletePin() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Common PINs blocklist

    static let commonPINs: Set<String> = [
        "0000", "1111", "2222", "3333", "4444", "5555", "6666", "7777", "8888", "9999",
        "1234", "4321", "1212", "0123", "3210", "1010", "2580", "0852", "1357", "2468"
    ]

    static func isWeakPin(_ pin: String) -> Bool {
        commonPINs.contains(pin)
    }
}

// MARK: - PIN Lockout State (persists across view lifecycle)

final class PinLockoutState {
    static let shared = PinLockoutState()
    private init() {}

    private(set) var failedAttempts = 0
    private(set) var lockedUntil: Date?

    var isLockedOut: Bool {
        if let until = lockedUntil, Date() < until { return true }
        return false
    }

    var remainingSeconds: Int {
        guard let until = lockedUntil else { return 0 }
        return max(0, Int(until.timeIntervalSinceNow) + 1)
    }

    func recordFailure(maxAttempts: Int = 5, lockoutDurations: [Int: TimeInterval] = [3: 30, 4: 60, 5: 300]) {
        failedAttempts += 1
        // Progressive lockout
        if let duration = lockoutDurations[failedAttempts] ?? (failedAttempts >= 5 ? lockoutDurations[5] : nil) {
            lockedUntil = Date().addingTimeInterval(duration)
        }
    }

    func reset() {
        failedAttempts = 0
        lockedUntil = nil
    }
}
