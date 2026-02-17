#if os(iOS)
import SwiftUI
import FirebaseCore
import FirebaseAuth

@main
struct KomaliosApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var pathManager = PathManager()
    @StateObject private var languageManager = LanguageManager.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self)
    var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(authViewModel)
                .environmentObject(pathManager)
                .environmentObject(languageManager)
                .preferredColorScheme(.light)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var pathManager: PathManager
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        NavigationStack(path: $pathManager.path) {
            // Start with SplashScreen - it will navigate after 3 seconds
            SplashScreenView()
                .navigationDestination(for: Routes.self) { route in
                    destinationView(for: route)
                }
        }
        .onChange(of: authViewModel.user) { _ in
            guard !appState.isGuestUser else { return }
            if authViewModel.user == nil {
                pathManager.popToRoot()
                pathManager.push(Routes.loginView)
            } else if appState.hasCompletedOnboarding {
                pathManager.popToRoot()
                pathManager.push(Routes.rootView)
            } else {
                pathManager.popToRoot()
                pathManager.push(Routes.onboardingView)
            }
        }
        .onChange(of: appState.hasCompletedOnboarding) { newValue in
            if newValue && (authViewModel.user != nil || appState.isGuestUser) {
                pathManager.popToRoot()
                pathManager.push(Routes.rootView)
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background || newPhase == .inactive {
                if appState.accountMode == .guest {
                    appState.accountMode = .child
                }
                // Save last active date for streak tracking
                appState.retentionState.lastActiveDate = Date()
                appState.retentionState.promptsShownThisSession = 0
                appState.savePreferences()
            }
            if newPhase == .active {
                // Update streak on app open
                GrowthTrackingService.shared.updateStreakOnAppOpen(retentionState: &appState.retentionState)

                // Track voluntary vs notification-driven return
                trackReturnType()

                appState.savePreferences()

                // Schedule reconnection reminder
                NotificationService.shared.scheduleReconnectionReminder()

                // Run tiered memory maintenance (fire-and-forget)
                Task {
                    ConversationMemoryService.shared.performTieredMaintenanceAsync()
                }
            }
        }
        .onAppear {
            print("📱 ContentView appeared - user: \(authViewModel.user?.uid ?? "nil"), hasCompletedOnboarding: \(appState.hasCompletedOnboarding)")
            // Request notification permission
            NotificationService.shared.requestPermission()
            // Schedule anchor notifications
            NotificationService.shared.updateSchedules(retentionState: appState.retentionState)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserDidSignOut"))) { _ in
            // Backup: Force update authViewModel state if notification is received
            print("📢 Received UserDidSignOut notification")
            Task { @MainActor in
                appState.isGuestUser = false
                authViewModel.user = nil
                authViewModel.loginState = .notRunning
                pathManager.popToRoot()
                pathManager.push(Routes.loginView)
                print("✅ Updated authViewModel from notification")
            }
        }
    }
    
    /// Track whether the return was voluntary or notification-driven
    private func trackReturnType() {
        // Simple heuristic: if app opens within 60 seconds of a notification being delivered,
        // count as push-driven. Otherwise voluntary.
        let isPushDriven = NotificationService.shared.wasRecentNotificationTapped()
        if isPushDriven {
            appState.retentionState.pushNotificationReturnCount += 1
        } else {
            appState.retentionState.voluntaryReturnCount += 1
        }
        appState.retentionState.childInitiatedSessionCount += 1
    }

    @ViewBuilder
    private func destinationView(for route: Routes) -> some View {
        switch route {
        case .loginView:
            LoginView(viewModel: authViewModel)
                .navigationBarBackButtonHidden(true)
        case .rootView:
            RootView()
                .navigationBarBackButtonHidden(true)
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserDidSignOut"))) { _ in
                    pathManager.popToRoot()
                    pathManager.push(Routes.loginView)
                }
        case .onboardingView:
            PostAuthOnboardingView {
                appState.savePreferences()
            }
            .navigationBarBackButtonHidden(true)
        case .settingView:
            SettingsView(selectedTab: nil)
        }
    }
}
#endif



