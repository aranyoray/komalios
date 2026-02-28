#if os(iOS)
import SwiftUI

struct RootView: View {
    enum ActiveAnchor: Identifiable {
        case morning, evening
        var id: Self { self }
    }

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var selectedTab: NavigationTab = .browser
    @State private var activeAnchor: ActiveAnchor? = nil
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
            checkDailyAnchors()
            checkReconnection()
            checkReturnFromAbsence()

            // Guided Access reminder
            if !UIAccessibility.isGuidedAccessEnabled,
               !UserDefaults.standard.bool(forKey: "komal.guidedAccessReminderDismissed") {
                showGuidedAccessReminder = true
            }

            // App open trigger
            evaluatePrompt(trigger: .appOpen)
        }
        .onChange(of: selectedTab) {
            // Feed tab switch into contextual prompt engine
            evaluatePrompt(trigger: .tabSwitch, currentTab: selectedTab)
        }
        .sheet(item: $activeAnchor) { anchor in
            switch anchor {
            case .morning:
                MorningAnchorView()
                    .environmentObject(appState)
            case .evening:
                EveningAnchorView()
                    .environmentObject(appState)
            }
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

    // MARK: - Daily Anchor Checks

    private static let anchorDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private func checkDailyAnchors() {
        let hour = Calendar.current.component(.hour, from: Date())
        let todayStr = RootView.anchorDateFormatter.string(from: Date())

        // Morning anchor: before noon, if not completed today
        if hour < 12 && appState.retentionState.morningAnchorEnabled {
            if appState.retentionState.lastMorningAnchor != todayStr {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    activeAnchor = .morning
                }
            }
        }

        // Evening anchor: after 5 PM, if not completed today (only if morning not also pending)
        if hour >= 17 && appState.retentionState.eveningAnchorEnabled {
            if appState.retentionState.lastEveningAnchor != todayStr && activeAnchor == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    activeAnchor = .evening
                }
            }
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

    var body: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 12)

            ZStack {
                Circle()
                    .fill(KomalColors.lavenderPurple.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 36))
                    .foregroundColor(KomalColors.lavenderPurple)
            }

            VStack(spacing: 8) {
                Text("guided_access.reminder.title".localized)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(KomalColors.textPrimary)

                Text("guided_access.reminder.explanation".localized)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(KomalColors.textSecondary)
                    .multilineTextAlignment(.center)
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
                    UserDefaults.standard.set(true, forKey: "komal.guidedAccessReminderDismissed")
                }
                isPresented = false
            }) {
                Text("guided_access.reminder.got_it".localized)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(KomalColors.lavenderPurple)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .presentationDetents([.medium])
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
