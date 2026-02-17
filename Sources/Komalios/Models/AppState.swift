import Foundation

#if canImport(Combine)
import Combine

final class AppState: ObservableObject {
    @Published var activeProfile = ChildProfile.sample
    @Published var parentSettings = ParentSettings.sample
    @Published var accountMode: AccountMode = .child
    @Published var contentFilterPreferences = ContentFilterPreferences()
    @Published var retentionState: RetentionState = .default
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

    var currentProfileName: String {
        if isGuestUser { return "Guest" }
        return accountMode == .guest ? "Guest" : activeProfile.name
    }

    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "komal.hasCompletedOnboarding")
        self.isGuestUser = UserDefaults.standard.bool(forKey: "komal.isGuestUser")
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
        
        // Save parent settings (custom keywords, blocked sites, etc.)
        if let parentData = try? encoder.encode(parentSettings) {
            UserDefaults.standard.set(parentData, forKey: "komal.parentSettings")
        }

        // Save retention state
        if let retentionData = try? encoder.encode(retentionState) {
            UserDefaults.standard.set(retentionData, forKey: "komal.retentionState")
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
        
        // Load parent settings
        if let parentData = UserDefaults.standard.data(forKey: "komal.parentSettings"),
           let settings = try? decoder.decode(ParentSettings.self, from: parentData) {
            parentSettings = settings
        }

        // Load retention state
        if let retentionData = UserDefaults.standard.data(forKey: "komal.retentionState"),
           let state = try? decoder.decode(RetentionState.self, from: retentionData) {
            retentionState = state
        }
    }
}
#else
final class AppState {
    var activeProfile = ChildProfile.sample
    var parentSettings = ParentSettings.sample
    var accountMode: AccountMode = .child
    var contentFilterPreferences = ContentFilterPreferences()
    var retentionState: RetentionState = .default
    var hasCompletedOnboarding: Bool = false
    var isGuestUser: Bool = false

    var currentProfileName: String {
        if isGuestUser { return "Guest" }
        return accountMode == .guest ? "Guest" : activeProfile.name
    }
}
#endif
