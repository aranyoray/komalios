#if os(iOS)
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var selectedTab: NavigationTab = .browser
    @State private var showReconnectionFlow = false
    @State private var contextPrompt: ContextualPrompt? = nil
    @State private var showGrowthJourney = false
    @State private var showGuidedAccessReminder = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content based on selected tab
            Group {
                switch selectedTab {
                case .browser:
                    KomalSafetyScannerView(appState: appState)
                case .riki:
                    RikiCheckInView()
                case .reflect:
                    ReflectionTimeView()
                case .settings:
                    SettingsView(selectedTab: $selectedTab)
                        .environmentObject(authViewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(.none, value: selectedTab)

            // Floating menu — only occupies tab bar area at the bottom
            FloatingMenuView(selectedTab: $selectedTab)

            // Contextual prompt overlay
            if let prompt = contextPrompt {
                ContextualPromptOverlay(prompt: prompt) { action in
                    // Edge Case E: Record acceptance when child engages with prompt
                    ContextualPromptEngine.shared.recordAcceptance()
                    handlePromptAction(action)
                } onDismiss: {
                    // Edge Case E: Record dismissal when child ignores prompt
                    ContextualPromptEngine.shared.recordDismissal()
                    withAnimation { contextPrompt = nil }
                }
            }
        }
        .modifier(SelectedTabChangeHandler(selectedTab: $selectedTab))
        .onAppear {
            checkReconnection()
            checkReturnFromAbsence()

            // Guided Access reminder — show every launch when in child mode unless dismissed
            // iOS doesn't allow apps to programmatically start Guided Access
            // (requires restricted entitlement), so we persistently guide parents
            if !UIAccessibility.isGuidedAccessEnabled,
               appState.accountMode == .child,
               KeychainService.loadSecureData(forKey: "komal.guidedAccessDismissed") == nil {
                showGuidedAccessReminder = true
            }

            // Update intent vector on app open
            IntentInferenceService.shared.updateIntent()

            // App open trigger
            evaluatePrompt(trigger: .appOpen)
        }
        .onChange(of: selectedTab) {
            // Feed tab switch into contextual prompt engine
            evaluatePrompt(trigger: .tabSwitch, currentTab: selectedTab)
        }
        .sheet(isPresented: $showGrowthJourney) {
            GrowthJourneyView()
        }
        .fullScreenCover(isPresented: $showReconnectionFlow) {
            ReconnectionView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showGuidedAccessReminder) {
            GuidedAccessReminderSheet(isPresented: $showGuidedAccessReminder)
                .interactiveDismissDisabled()
        }
        // B29 fix: When ReconnectionView (or any sheet) requests a tab switch via appState,
        // apply it here where selectedTab is owned.
        .onChange(of: appState.pendingNavigationTab) {
            if let tab = appState.pendingNavigationTab {
                withAnimation(KomalAnimations.spring) { selectedTab = tab }
                appState.pendingNavigationTab = nil
            }
        }
    }

    // MARK: - Prompt Evaluation Helper

    private func evaluatePrompt(trigger: ContextualPromptTrigger, currentTab: NavigationTab? = nil) {
        let recentMood = MoodTrackingService.shared.recentEntries.last?.emotion
        if let prompt = ContextualPromptEngine.shared.evaluateTrigger(
            trigger,
            retentionState: appState.retentionState,
            currentTab: currentTab ?? selectedTab,
            ageGroup: appState.activeProfile.ageGroup,
            recentMood: recentMood
        ) {
            appState.retentionState.promptsShownThisSession += 1
            withAnimation { contextPrompt = prompt }
        }
    }

    // MARK: - Return From Absence Check

    private func checkReturnFromAbsence() {
        guard let lastActive = appState.retentionState.lastActiveDate else { return }
        let hoursSinceActive = Date().timeIntervalSince(lastActive) / 3600.0

        if hoursSinceActive >= 12 {
            evaluatePrompt(trigger: .returnFromAbsence)
        }
    }

    // MARK: - Reconnection Check

    private func checkReconnection() {
        guard let lastActive = appState.retentionState.lastActiveDate else { return }
        let daysSinceActive = Calendar.current.dateComponents([.day], from: lastActive, to: Date()).day ?? 0

        if daysSinceActive >= 3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showReconnectionFlow = true
            }
        }
    }

    // MARK: - Prompt Actions

    private func handlePromptAction(_ action: ContextualPromptAction) {
        withAnimation { contextPrompt = nil }
        switch action {
        case .navigateToTab(let tab):
            withAnimation(KomalAnimations.spring) { selectedTab = tab }
        case .startMoodCheckIn:
            withAnimation(KomalAnimations.spring) { selectedTab = .reflect }
        case .showMilestone:
            showGrowthJourney = true
        case .showGrowthJourney:
            showGrowthJourney = true
        case .dismiss:
            break
        }
    }
}

struct GuidedAccessReminderSheet: View {
    @Binding var isPresented: Bool
    @State private var dontRemindAgain = false
    @State private var guidedAccessEnabled = UIAccessibility.isGuidedAccessEnabled

    var body: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 12)

            ZStack {
                Circle()
                    .fill(guidedAccessEnabled ? Color.green.opacity(0.15) : KomalColors.lavenderPurple.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: guidedAccessEnabled ? "checkmark.shield.fill" : "lock.shield.fill")
                    .font(.system(size: 36))
                    .foregroundColor(guidedAccessEnabled ? .green : KomalColors.lavenderPurple)
            }

            VStack(spacing: 8) {
                Text((guidedAccessEnabled ? "guided_access.reminder.enabled_title" : "guided_access.reminder.title").localized)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(KomalColors.textPrimary)

                Text((guidedAccessEnabled ? "guided_access.reminder.enabled_explanation" : "guided_access.reminder.explanation").localized)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(KomalColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            if !guidedAccessEnabled {
                // Detailed steps
                VStack(alignment: .leading, spacing: 10) {
                    guidedAccessStep(number: 1, text: "guided_access.reminder.step1".localized)
                    guidedAccessStep(number: 2, text: "guided_access.reminder.step2".localized)
                    guidedAccessStep(number: 3, text: "guided_access.reminder.step3".localized)
                }
                .padding(.horizontal, 24)

                // Open Accessibility Settings
                Button(action: {
                    openAccessibilitySettings()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "accessibility")
                            .font(.system(size: 18, weight: .semibold))
                        Text("guided_access.reminder.open_accessibility".localized)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(KomalColors.lavenderPurple)
                    .cornerRadius(14)
                }
                .padding(.horizontal, 24)
            }

            Toggle(isOn: $dontRemindAgain) {
                Text("guided_access.reminder.dont_remind".localized)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(KomalColors.textSecondary)
            }
            .tint(KomalColors.lavenderPurple)
            .padding(.horizontal, 32)

            Button(action: {
                if dontRemindAgain {
                    KeychainService.saveSecureData(Data([1]), forKey: "komal.guidedAccessDismissed")
                }
                isPresented = false
            }) {
                Text((guidedAccessEnabled ? "guided_access.reminder.done" : "guided_access.reminder.got_it").localized)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(guidedAccessEnabled ? .white : KomalColors.lavenderPurple)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(guidedAccessEnabled ? Color.green : KomalColors.lavenderPurple.opacity(0.1))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(guidedAccessEnabled ? Color.clear : KomalColors.lavenderPurple, lineWidth: 1)
                    )
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .presentationDetents([.large])
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            guidedAccessEnabled = UIAccessibility.isGuidedAccessEnabled
        }
    }

    private func openAccessibilitySettings() {
        // Try direct Accessibility deep link first, fall back to general Settings
        if let accessibilityURL = URL(string: "App-Prefs:root=ACCESSIBILITY") {
            UIApplication.shared.open(accessibilityURL, options: [:]) { success in
                if !success {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
            }
        } else if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }

    private func guidedAccessStep(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(KomalColors.lavenderPurple)
                .clipShape(Circle())

            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(KomalColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct SelectedTabChangeHandler: ViewModifier {
    @EnvironmentObject private var appState: AppState
    @Binding var selectedTab: NavigationTab

    func body(content: Content) -> some View {
        Group {
            if #available(iOS 17.0, *) {
                content
                    .onChange(of: selectedTab, initial: true) { _, _ in
                        if appState.accountMode == .guest {
                            appState.accountMode = .child
                        }
                    }
            } else {
                // iOS 16 fallback: perform initial check and respond to changes
                content
                    .task {
                        if appState.accountMode == .guest {
                            appState.accountMode = .child
                        }
                    }
                    .onChange(of: selectedTab) {
                        if appState.accountMode == .guest {
                            appState.accountMode = .child
                        }
                    }
            }
        }
    }
}
#endif
