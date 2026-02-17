#if os(iOS)
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var selectedTab: NavigationTab = .browser
    @State private var showMorningAnchor = false
    @State private var showEveningAnchor = false
    @State private var showReconnectionFlow = false
    @State private var contextPrompt: ContextualPrompt? = nil
    @State private var showGrowthJourney = false

    var body: some View {
        ZStack {
            // Content based on selected tab
            Group {
                switch selectedTab {
                case .browser:
                    KomalSafetyScannerView()
                case .riki:
                    RikiCheckInView()
                case .reflect:
                    ReflectionTimeView()
                case .settings:
                    SettingsView(selectedTab: $selectedTab)
                        .environmentObject(authViewModel)
                }
            }

            // Floating menu overlay
            FloatingMenuView(selectedTab: $selectedTab)

            // Contextual prompt overlay
            if let prompt = contextPrompt {
                ContextualPromptOverlay(prompt: prompt) { action in
                    handlePromptAction(action)
                } onDismiss: {
                    withAnimation { contextPrompt = nil }
                }
            }
        }
        .modifier(SelectedTabChangeHandler(selectedTab: $selectedTab))
        .onAppear {
            checkDailyAnchors()
            checkReconnection()
            checkReturnFromAbsence()

            // App open trigger
            evaluatePrompt(trigger: .appOpen)
        }
        .onChange(of: selectedTab) { _ in
            // Feed tab switch into contextual prompt engine
            evaluatePrompt(trigger: .tabSwitch, currentTab: selectedTab)
        }
        .sheet(isPresented: $showMorningAnchor) {
            MorningAnchorView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showEveningAnchor) {
            EveningAnchorView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showGrowthJourney) {
            GrowthJourneyView()
        }
        .fullScreenCover(isPresented: $showReconnectionFlow) {
            ReconnectionView()
                .environmentObject(appState)
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

    private func checkDailyAnchors() {
        let hour = Calendar.current.component(.hour, from: Date())
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayStr = dateFormatter.string(from: Date())

        // Morning anchor: before noon, if not completed today
        if hour < 12 && appState.retentionState.morningAnchorEnabled {
            if appState.retentionState.lastMorningAnchor != todayStr {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    showMorningAnchor = true
                }
            }
        }

        // Evening anchor: after 5 PM, if not completed today
        if hour >= 17 && appState.retentionState.eveningAnchorEnabled {
            if appState.retentionState.lastEveningAnchor != todayStr {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    showEveningAnchor = true
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
                    .onChange(of: selectedTab) { _ in
                        if appState.accountMode == .guest {
                            appState.accountMode = .child
                        }
                    }
            }
        }
    }
}
#endif
