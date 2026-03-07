#if os(iOS)
import SwiftUI
import FirebaseCore
import FirebaseAuth
import os.log

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
        .onChange(of: authViewModel.user) {
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

            // Trigger Firestore sync after login
            if let uid = authViewModel.user?.uid {
                Task {
                    await FirestoreSyncService.shared.syncOnLogin(uid: uid, appState: appState)
                }
            }
        }
        .onChange(of: appState.hasCompletedOnboarding) {
            if appState.hasCompletedOnboarding && (authViewModel.user != nil || appState.isGuestUser) {
                pathManager.popToRoot()
                pathManager.push(Routes.rootView)
            }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .background {
                if appState.accountMode == .guest {
                    appState.accountMode = .child
                }
                // Save last active date for streak tracking
                appState.retentionState.lastActiveDate = Date()
                appState.retentionState.promptsShownThisSession = 0
                appState.savePreferences()

                // Commit eye tracking data and stop session
                Task {
                    if EyeTrackingService.shared.isTracking {
                        EyeTrackingService.shared.commitDailySummary()
                        EyeTrackingService.shared.stopTracking()
                    }
                }
            }
            if scenePhase == .active {
                // Resume eye tracking if enabled, supported, and user is authenticated
                Task {
                    if appState.parentSettings.eyeTrackingEnabled
                        && EyeTrackingService.isSupported
                        && (authViewModel.user != nil || appState.isGuestUser) {
                        EyeTrackingService.shared.startTracking()
                    }
                }
                // Record foreground time for session duration estimation
                IntentInferenceService.shared.recordForegroundDate()
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
            #if DEBUG
            print("📱 ContentView appeared - hasCompletedOnboarding: \(appState.hasCompletedOnboarding)")
            #endif
            // Request notification permission
            NotificationService.shared.requestPermission()
            // Schedule anchor notifications
            NotificationService.shared.updateSchedules(retentionState: appState.retentionState)
        }
        .task {
            // Sync subscription state with StoreKit on launch
            let subLog = Logger(subsystem: "com.komalkids.komal", category: "Subscription")
            subLog.info("App launch: syncing subscription state (stored=\(appState.subscriptionState.currentPlan.displayName), hasSelectedPlan=\(appState.hasSelectedPlan))")
            await SubscriptionService.shared.updatePurchasedProducts()
            let currentPlan = SubscriptionService.shared.currentPlan()
            subLog.info("App launch: StoreKit plan=\(currentPlan.displayName), stored plan=\(appState.subscriptionState.currentPlan.displayName)")
            if currentPlan != appState.subscriptionState.currentPlan {
                subLog.info("App launch: updating stored plan \(appState.subscriptionState.currentPlan.displayName) → \(currentPlan.displayName)")
                appState.subscriptionState.currentPlan = currentPlan
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserDidSignOut"))) { _ in
            // Backup: Force update authViewModel state if notification is received
            #if DEBUG
            print("📢 Received UserDidSignOut notification")
            #endif
            Task { @MainActor in
                appState.isGuestUser = false
                authViewModel.user = nil
                authViewModel.loginState = .notRunning
                pathManager.popToRoot()
                pathManager.push(Routes.loginView)
                #if DEBUG
                print("✅ Updated authViewModel from notification")
                #endif
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



