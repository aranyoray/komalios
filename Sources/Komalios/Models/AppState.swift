import Foundation
import Combine
import FirebaseAuth

@MainActor
final class AppState: ObservableObject {
    @Published var activeProfile = ChildProfile.sample
    @Published var parentSettings = ParentSettings.sample
    @Published var accountMode: AccountMode = .child
    @Published var contentFilterPreferences = ContentFilterPreferences()
    @Published var retentionState: RetentionState = .default
    /// B29 fix: Allows child views (e.g. ReconnectionView presented as a sheet) to
    /// request a tab switch in the parent RootView. RootView observes this and resets it to nil.
    @Published var pendingNavigationTab: NavigationTab? = nil
    /// Allows browsing history (or other views) to request navigation to a URL in the browser.
    /// The browser view observes this, navigates, and resets it to nil.
    @Published var pendingBrowserURL: URL? = nil
    @Published var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: "komal.hasCompletedOnboarding")
        }
    }
    @Published var isGuestUser: Bool {
        didSet {
            UserDefaults.standard.set(isGuestUser, forKey: "komal.isGuestUser")
        }
    }
    @Published var hasSelectedPlan: Bool {
        didSet {
            UserDefaults.standard.set(hasSelectedPlan, forKey: "komal.hasSelectedPlan")
        }
    }
    @Published var subscriptionState: SubscriptionState {
        didSet {
            if let data = try? JSONEncoder().encode(subscriptionState) {
                UserDefaults.standard.set(data, forKey: "komal.subscriptionState")
            }
        }
    }

    var currentProfileName: String {
        if isGuestUser { return "Guest" }
        return accountMode == .guest ? "Parent" : activeProfile.name
    }

    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "komal.hasCompletedOnboarding")
        self.isGuestUser = UserDefaults.standard.bool(forKey: "komal.isGuestUser")
        self.hasSelectedPlan = UserDefaults.standard.bool(forKey: "komal.hasSelectedPlan")
        if let data = UserDefaults.standard.data(forKey: "komal.subscriptionState"),
           let state = try? JSONDecoder().decode(SubscriptionState.self, from: data) {
            self.subscriptionState = state
        } else {
            self.subscriptionState = SubscriptionState()
        }
        loadPreferences()
    }

    /// Save state to UserDefaults
    func savePreferences() {
        let encoder = JSONEncoder()
        
        // Save content filter preferences
        if let data = try? encoder.encode(contentFilterPreferences) {
            UserDefaults.standard.set(data, forKey: "komal.contentFilterPreferences")
        }
        
        // Save active profile
        if let profileData = try? encoder.encode(activeProfile) {
            UserDefaults.standard.set(profileData, forKey: "komal.activeProfile")
        }
        
        // Save account mode
        if let modeData = try? encoder.encode(accountMode) {
            UserDefaults.standard.set(modeData, forKey: "komal.accountMode")
        }
        
        // Save parent settings securely in Keychain (blocked keywords, hosts, etc.)
        if let parentData = try? encoder.encode(parentSettings) {
            KeychainService.saveSecureData(parentData, forKey: "komal.parentSettings")
        }

        // Save retention state
        if let retentionData = try? encoder.encode(retentionState) {
            UserDefaults.standard.set(retentionData, forKey: "komal.retentionState")
        }

        // Upload to Firestore (fire-and-forget)
        if let uid = Auth.auth().currentUser?.uid {
            Task {
                await FirestoreSyncService.shared.uploadSettings(
                    uid: uid,
                    filterPrefs: contentFilterPreferences,
                    profile: activeProfile,
                    retention: retentionState,
                    accountMode: accountMode,
                    parentSettings: parentSettings
                )
            }
        }
    }

    /// Load state from UserDefaults
    func loadPreferences() {
        let decoder = JSONDecoder()
        
        // Load content filter preferences
        if let data = UserDefaults.standard.data(forKey: "komal.contentFilterPreferences"),
           let prefs = try? decoder.decode(ContentFilterPreferences.self, from: data) {
            contentFilterPreferences = prefs
        }
        
        // Load active profile
        if let profileData = UserDefaults.standard.data(forKey: "komal.activeProfile"),
           let profile = try? decoder.decode(ChildProfile.self, from: profileData) {
            activeProfile = profile
        }
        
        // Load account mode
        if let modeData = UserDefaults.standard.data(forKey: "komal.accountMode"),
           let mode = try? decoder.decode(AccountMode.self, from: modeData) {
            accountMode = mode
        }
        
        // Load parent settings from Keychain (migrate from UserDefaults if needed)
        if let parentData = KeychainService.loadSecureData(forKey: "komal.parentSettings"),
           let settings = try? decoder.decode(ParentSettings.self, from: parentData) {
            parentSettings = settings
        } else if let parentData = UserDefaults.standard.data(forKey: "komal.parentSettings"),
                  let settings = try? decoder.decode(ParentSettings.self, from: parentData) {
            // One-time migration from UserDefaults to Keychain
            parentSettings = settings
            KeychainService.saveSecureData(parentData, forKey: "komal.parentSettings")
            UserDefaults.standard.removeObject(forKey: "komal.parentSettings")
        }

        // Load retention state
        if let retentionData = UserDefaults.standard.data(forKey: "komal.retentionState"),
           let state = try? decoder.decode(RetentionState.self, from: retentionData) {
            retentionState = state
        }

    }

    /// Apply settings downloaded from Firestore cloud sync.
    /// Only overwrites local data if cloud data is present.
    func applyCloudSettings(
        filterPrefs: ContentFilterPreferences,
        profile: ChildProfile,
        retention: RetentionState,
        accountMode: AccountMode,
        parentSettings: ParentSettings
    ) {
        self.contentFilterPreferences = filterPrefs
        self.activeProfile = profile
        self.retentionState = retention
        self.accountMode = accountMode
        self.parentSettings = parentSettings
        // Persist merged data locally
        savePreferencesLocally()
    }

    /// Save to local storage only (no cloud upload) — used by applyCloudSettings to avoid re-upload loop.
    private func savePreferencesLocally() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(contentFilterPreferences) {
            UserDefaults.standard.set(data, forKey: "komal.contentFilterPreferences")
        }
        if let profileData = try? encoder.encode(activeProfile) {
            UserDefaults.standard.set(profileData, forKey: "komal.activeProfile")
        }
        if let modeData = try? encoder.encode(accountMode) {
            UserDefaults.standard.set(modeData, forKey: "komal.accountMode")
        }
        if let parentData = try? encoder.encode(parentSettings) {
            KeychainService.saveSecureData(parentData, forKey: "komal.parentSettings")
        }
        if let retentionData = try? encoder.encode(retentionState) {
            UserDefaults.standard.set(retentionData, forKey: "komal.retentionState")
        }
    }
}
