#if os(iOS)
import LocalAuthentication

enum BiometricType { case faceID, touchID, none }

enum BiometricAuthService {
    static var availableBiometricType: BiometricType {
        let ctx = LAContext()
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else { return .none }
        return ctx.biometryType == .faceID ? .faceID : ctx.biometryType == .touchID ? .touchID : .none
    }

    static var isBiometricEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "komal.biometricAuthEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "komal.biometricAuthEnabled") }
    }

    static func authenticate() async -> Bool {
        let ctx = LAContext()
        ctx.localizedFallbackTitle = "Enter PIN"
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else { return false }
        return (try? await ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Authenticate to access parent settings")) ?? false
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
