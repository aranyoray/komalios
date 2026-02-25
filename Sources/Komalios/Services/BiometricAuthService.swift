#if os(iOS)
import LocalAuthentication

enum BiometricType { case faceID, touchID, none }

enum BiometricAuthService {
    static var availableBiometricType: BiometricType {
        let ctx = LAContext()
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else { return .none }
        return ctx.biometryType == .faceID ? .faceID : ctx.biometryType == .touchID ? .touchID : .none
    }

    private static let biometricKeychainKey = "komal.biometricAuthEnabled"

    static var isBiometricEnabled: Bool {
        get {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "com.komal.biometric",
                kSecAttrAccount as String: biometricKeychainKey,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            var result: AnyObject?
            guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
                  let data = result as? Data,
                  let value = String(data: data, encoding: .utf8) else { return false }
            return value == "1"
        }
        set {
            let deleteQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "com.komal.biometric",
                kSecAttrAccount as String: biometricKeychainKey
            ]
            SecItemDelete(deleteQuery as CFDictionary)
            guard let data = (newValue ? "1" : "0").data(using: .utf8) else { return }
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "com.komal.biometric",
                kSecAttrAccount as String: biometricKeychainKey,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    static func authenticate() async -> Bool {
        let ctx = LAContext()
        ctx.localizedFallbackTitle = "Enter PIN"
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else { return false }
        return (try? await ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Authenticate to access parent settings")) ?? false
    }

    static var biometricName: String {
        switch availableBiometricType {
        case .faceID: "Face ID"; case .touchID: "Touch ID"; case .none: "Biometrics"
        }
    }

    static var biometricIcon: String {
        switch availableBiometricType {
        case .faceID: "faceid"; case .touchID: "touchid"; case .none: "lock.fill"
        }
    }
}
#endif
