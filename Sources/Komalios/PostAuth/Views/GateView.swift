#if os(iOS)
import SwiftUI

struct GateView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let category: ContentCategory
    var onApproved: (() -> Void)? = nil
    @State private var pin = ""
    @State private var showMindfulBreak = false
    @State private var showPinError = false

    private let lockout = PinLockoutState.shared

    private var isLockedOut: Bool { lockout.isLockedOut }

    var body: some View {
        NavigationStack {
            ZStack {
                GradientBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        RikiAssistantCard(
                            title: LanguageManager.localized("gate.riki_pause"),
                            message: LanguageManager.localized("gate.touches_on", category.label),
                            buttonTitle: LanguageManager.localized("gate.start_break")
                        ) {
                            showMindfulBreak = true
                        }
                        .padding(.horizontal, 16)

                        BubblyCard(tintColor: KomalColors.yellow) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "lock.shield.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(KomalColors.pearlAqua)

                                    Text(LanguageManager.localized("gate.parent_approval"))
                                        .font(.system(size: 22, weight: .bold, design: .rounded))
                                        .foregroundColor(KomalColors.textPrimary)

                                    Spacer()
                                }

                                // Face ID / Touch ID quick-approve button
                                if BiometricAuthService.isBiometricEnabled && BiometricAuthService.availableBiometricType != .none {
                                    Button {
                                        Task {
                                            let success = await BiometricAuthService.authenticate()
                                            if success {
                                                await MainActor.run {
                                                    lockout.reset()
                                                    onApproved?()
                                                    dismiss()
                                                }
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Image(systemName: BiometricAuthService.biometricIcon)
                                            Text(LanguageManager.localized("gate.approve_biometric", BiometricAuthService.biometricName))
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(PillButtonStyle(backgroundColor: KomalColors.lavenderPurple, foregroundColor: .white))

                                    HStack {
                                        VStack { Divider() }
                                        Text(LanguageManager.localized("gate.or_enter_pin"))
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundColor(KomalColors.textSecondary)
                                        VStack { Divider() }
                                    }
                                }

                                SecureField(LanguageManager.localized("gate.enter_pin"), text: $pin)
                                    .roundedTextFieldStyle()
                                    .keyboardType(.numberPad)
                                    .onChange(of: pin) {
                                        let filtered = String(pin.filter(\.isNumber).prefix(4))
                                        if filtered != pin { pin = filtered }
                                        showPinError = false
                                    }

                                if showPinError {
                                    if !KeychainService.hasPin() {
                                        Text(LanguageManager.localized("gate.no_pin_set"))
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.orange)
                                    } else if isLockedOut {
                                        let remaining = lockout.remainingSeconds
                                        Text(LanguageManager.localized("gate.locked_out", remaining))
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.red)
                                    } else {
                                        Text(LanguageManager.localized("gate.wrong_pin"))
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.red)
                                    }
                                }

                                Button {
                                    guard !isLockedOut else { return }
                                    guard KeychainService.hasPin() else {
                                        showPinError = true
                                        return
                                    }
                                    if let savedPin = KeychainService.getPin(), pin == savedPin {
                                        lockout.reset()
                                        onApproved?()
                                        dismiss()
                                    } else {
                                        pin = ""
                                        lockout.recordFailure(maxAttempts: 5, lockoutDurations: [3: 30, 4: 60, 5: 300])
                                        showPinError = true
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text(LanguageManager.localized("gate.approve_continue"))
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(PillButtonStyle(backgroundColor: KomalColors.pearlAqua, foregroundColor: KomalColors.textPrimary))
                                .disabled(isLockedOut)
                            }
                        }
                        .padding(.horizontal, 16)

                        Text(LanguageManager.localized("gate.access_gated", appState.currentProfileName, appState.activeProfile.ageGroup.rawValue))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(KomalColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle(LanguageManager.localized("gate.title"))
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showMindfulBreak) {
                MindfulBreakView()
            }
        }
    }
}
#endif
