#if canImport(SwiftUI)
import SwiftUI
import FirebaseAuth
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var newBlockedKeyword = ""
    @State private var newBlockedHost = ""
    @State private var showFilterPreferences = false
    @State private var isKeywordsExpanded = false
    @State private var isWebsitesExpanded = false
    @State private var showLoginView = false
    @State private var showLogoutAlert = false
    @State private var showInsights = false
    @State private var showPinEntry = false
    @State private var enteredPin = ""
    @State private var pinError = false
    
    private let correctPin = "1234" // Parent PIN
    
    private var isLoggedIn: Bool {
        Auth.auth().currentUser != nil || authViewModel.user != nil
    }

    var body: some View {
        ZStack {
            // Clean, slightly off-white background for clearer card separation
            KomalColors.warmGray
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    
                    // MARK: - Header
                    HStack {
                        Text("Settings")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(KomalColors.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // MARK: - Account Mode
                    SettingsCard {
                        VStack(alignment: .leading, spacing: 16) {
                            CardHeader(icon: "person.2.circle.fill", title: "Who's Using?", color: KomalColors.bubblegumPink)
                            
                            Text("Select who is currently using the device")
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundColor(KomalColors.textSecondary)

                            HStack(spacing: 12) {
                                // Child Mode Button
                                AccountModeButton(
                                    icon: "face.smiling.fill",
                                    title: "Child",
                                    subtitle: "Safe browsing",
                                    color: KomalColors.pearlAqua,
                                    isSelected: appState.accountMode == .child
                                ) {
                                    withAnimation(.spring(response: 0.3)) {
                                        appState.accountMode = .child
                                    }
                                }
                                
                                // Parent Mode Button - requires PIN
                                AccountModeButton(
                                    icon: "lock.shield.fill",
                                    title: "Parent",
                                    subtitle: "Full access",
                                    color: KomalColors.lavenderPurple,
                                    isSelected: appState.accountMode == .guest
                                ) {
                                    if appState.accountMode == .guest {
                                        // Already in parent mode, switch to child
                                        withAnimation(.spring(response: 0.3)) {
                                            appState.accountMode = .child
                                        }
                                    } else {
                                        // Show PIN entry to switch to parent mode
                                        showPinEntry = true
                                    }
                                }
                            }
                        }
                    }
                    
                    // Show different content based on mode
                    if appState.accountMode == .child {
                        childModeContent
                    } else {
                        parentModeContent
                    }

                    // Use space at bottom
                    Color.clear.frame(height: 40)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showFilterPreferences) {
            FilterPreferencesView(preferences: $appState.contentFilterPreferences)
                .onChange(of: appState.contentFilterPreferences) { _, _ in
                    // Auto-save when preferences change
                    appState.savePreferences()
                }
                .environmentObject(appState)
        }
        .sheet(isPresented: $showInsights) {
            InsightsView()
        }
        .sheet(isPresented: $showPinEntry) {
            PinEntryView(
                enteredPin: $enteredPin,
                pinError: $pinError,
                onSubmit: {
                    if enteredPin == correctPin {
                        pinError = false
                        showPinEntry = false
                        enteredPin = ""
                        withAnimation(.spring(response: 0.3)) {
                            appState.accountMode = .guest
                        }
                    } else {
                        pinError = true
                        enteredPin = ""
                    }
                },
                onCancel: {
                    showPinEntry = false
                    enteredPin = ""
                    pinError = false
                }
            )
            .presentationDetents([.height(280)])
        }
        .fullScreenCover(isPresented: $showLoginView) {
            LoginView(viewModel: authViewModel)
                .environmentObject(appState)
        }
        .alert("Logout", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) {
                // User cancelled, do nothing
            }
            Button("Yes", role: .destructive) {
                handleLogout()
            }
        } message: {
            Text("Do you want to logout?")
        }
    }
    
    // MARK: - Child Mode Content
    private var childModeContent: some View {
        VStack(spacing: 24) {
            // Friendly greeting card
            SettingsCard {
                VStack(spacing: 16) {
                    // Komal mascot or friendly icon
                    if let uiImage = UIImage(named: "komaliconnobg") {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                    } else {
                        Image(systemName: "face.smiling.fill")
                            .font(.system(size: 50))
                            .foregroundColor(KomalColors.pearlAqua)
                    }
                    
                    Text("Hi \(appState.activeProfile.name.isEmpty ? "there" : appState.activeProfile.name)! 👋")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(KomalColors.textPrimary)
                    
                    Text("Komal is here to keep you safe while you explore!")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(KomalColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            
            // Fun action cards
            SettingsCard {
                VStack(alignment: .leading, spacing: 16) {
                    CardHeader(icon: "bubble.left.and.bubble.right.fill", title: "Feeling Chatty?", color: KomalColors.bubblegumPink)
                    
                    Text("Talk to Riki! Your friendly companion is always here to chat and help you out.")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(KomalColors.textSecondary)
                    
                    NavigationLink(destination: RikiCheckInView()) {
                        HStack {
                            Image(systemName: "pawprint.fill")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Go to Talk")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(KomalColors.lavenderPurple)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(KomalColors.lavenderPurple.opacity(0.12))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(KomalColors.lavenderPurple.opacity(0.4), lineWidth: 1.5)
                        )
                    }
                }
            }
            
            // Your profile (limited)
            SettingsCard {
                VStack(alignment: .leading, spacing: 16) {
                    CardHeader(icon: "star.fill", title: "Your Profile", color: KomalColors.pearlAqua)
                    
                    HStack(spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(KomalColors.pearlAqua)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(appState.activeProfile.name.isEmpty ? "Explorer" : appState.activeProfile.name)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(KomalColors.textPrimary)
                            
                            Text("Age: \(appState.activeProfile.ageGroup.rawValue)")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(KomalColors.textSecondary)
                        }
                        
                        Spacer()
                    }
                }
            }
        }
    }
    
    // MARK: - Parent Mode Content
    private var parentModeContent: some View {
        VStack(spacing: 24) {
            // Child Profile (editable in parent mode)
            SettingsCard {
                VStack(alignment: .leading, spacing: 16) {
                    CardHeader(icon: "sparkles", title: "Child Profile", color: KomalColors.lavenderPurple)

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Name", systemImage: "pencil")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(KomalColors.textSecondary)
                            
                            TextField("Child's Name", text: $appState.activeProfile.name)
                                .cleanTextFieldStyle()
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Label("Age Group", systemImage: "chart.bar.fill")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(KomalColors.textSecondary)
                            
                            Menu {
                                ForEach(AgeGroup.allCases) { group in
                                    Button {
                                        // Update age group
                                        appState.activeProfile.ageGroup = group
                                        
                                        // Update filter preferences to match new age group defaults
                                        // This ensures settings stay in sync with age
                                        appState.contentFilterPreferences = ContentFilterPreferences.defaults(for: group)
                                        
                                        // Save immediately when age changes
                                        appState.savePreferences()
                                    } label: {
                                        HStack {
                                            Text(group.rawValue)
                                            if appState.activeProfile.ageGroup == group {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(appState.activeProfile.ageGroup.rawValue)
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                        .foregroundColor(KomalColors.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption)
                                        .foregroundColor(KomalColors.textSecondary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(KomalColors.background)
                                .cornerRadius(12)
                            }
                        }
                        .frame(width: 140)
                    }
                }
            }

            // Parent Controls
            SettingsCard {
                VStack(alignment: .leading, spacing: 20) {
                    CardHeader(icon: "lock.shield.fill", title: "Parent Controls", color: KomalColors.pearlAqua)

                    VStack(spacing: 16) {
                        ModernToggleRow(
                            icon: "bell.badge.fill",
                            iconColor: KomalColors.bubblegumPink,
                            title: "Notify on Block",
                            subtitle: "Get alerts when blocked content is accessed",
                            isOn: $appState.parentSettings.notifyOnBlock
                        )
                        
                        Divider()
                        
                        ModernToggleRow(
                            icon: "safari.fill",
                            iconColor: KomalColors.pearlAqua,
                            title: "Force Safe Search",
                            subtitle: "Enforce strict safety on search engines",
                            isOn: $appState.parentSettings.safeSearchEnabled
                        )
                        
                        Divider()
                        
                        // Insights Button
                        Button(action: {
                            showInsights = true
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "chart.bar.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(KomalColors.lavenderPurple)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("View Insights")
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundColor(KomalColors.textPrimary)
                                    Text("See browsing activity and blocked content")
                                        .font(.caption)
                                        .foregroundColor(KomalColors.textSecondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(KomalColors.textSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Modify Content
            SettingsCard {
                VStack(alignment: .leading, spacing: 16) {
                    CardHeader(icon: "hand.raised.fill", title: "Modify Content", color: KomalColors.bubblegumPink)

                    Button(action: {
                        showFilterPreferences = true
                    }) {
                        HStack {
                            Text("Modify Filters")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(KomalColors.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(KomalColors.textPrimary)
                        }
                    }
                    .padding(.vertical, 4)

                    Divider().padding(.vertical, 4)

                    // Keywords - Collapsible
                    VStack(alignment: .leading, spacing: 10) {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isKeywordsExpanded.toggle()
                            }
                        }) {
                            HStack {
                                Text("Custom Keywords")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(KomalColors.textPrimary)
                                Spacer()
                                Image(systemName: isKeywordsExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(KomalColors.textSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        if isKeywordsExpanded {
                            HStack(spacing: 12) {
                                TextField("Add keyword (e.g. 'weapons')", text: $newBlockedKeyword)
                                    .cleanTextFieldStyle()
                                    .submitLabel(.done)
                                    .onSubmit {
                                        addKeyword()
                                    }
                                
                                Button(action: addKeyword) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 44, height: 44)
                                        .background(KomalColors.bubblegumPink)
                                        .clipShape(Circle())
                                        .shadow(color: KomalColors.bubblegumPink.opacity(0.3), radius: 4, x: 0, y: 2)
                                }
                            }
                            
                            if !appState.parentSettings.blockedKeywords.isEmpty {
                                FlowLayout(spacing: 8) {
                                    ForEach(appState.parentSettings.blockedKeywords, id: \.self) { keyword in
                                        ChipView(text: keyword, color: KomalColors.bubblegumPink) {
                                            if let index = appState.parentSettings.blockedKeywords.firstIndex(of: keyword) {
                                                appState.parentSettings.blockedKeywords.remove(at: index)
                                                appState.savePreferences()
                                            }
                                        }
                                    }
                                }
                            } else {
                                Text("No custom keywords added yet.")
                                    .font(.caption)
                                    .italic()
                                    .foregroundColor(KomalColors.textSecondary)
                            }
                        }
                    }
                    
                    Divider().padding(.vertical, 4)
                    
                    // Sites - Collapsible
                    VStack(alignment: .leading, spacing: 10) {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isWebsitesExpanded.toggle()
                            }
                        }) {
                            HStack {
                                Text("Custom Websites")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(KomalColors.textPrimary)
                                Spacer()
                                Image(systemName: isWebsitesExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(KomalColors.textSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        if isWebsitesExpanded {
                            HStack(spacing: 12) {
                                TextField("Add website (e.g. 'badsite.com')", text: $newBlockedHost)
                                    .cleanTextFieldStyle()
                                    .keyboardType(.URL)
                                    .textInputAutocapitalization(.never)
                                    .submitLabel(.done)
                                    .onSubmit {
                                        addHost()
                                    }
                                
                                Button(action: addHost) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 44, height: 44)
                                        .background(KomalColors.pearlAqua)
                                        .clipShape(Circle())
                                        .shadow(color: KomalColors.pearlAqua.opacity(0.3), radius: 4, x: 0, y: 2)
                                }
                            }
                            
                            if !appState.parentSettings.blockedHosts.isEmpty {
                                FlowLayout(spacing: 8) {
                                    ForEach(appState.parentSettings.blockedHosts, id: \.self) { host in
                                        ChipView(text: host, color: KomalColors.pearlAqua) {
                                            if let index = appState.parentSettings.blockedHosts.firstIndex(of: host) {
                                                appState.parentSettings.blockedHosts.remove(at: index)
                                                appState.savePreferences()
                                            }
                                        }
                                    }
                                }
                            } else {
                                Text("No custom websites added yet.")
                                    .font(.caption)
                                    .italic()
                                    .foregroundColor(KomalColors.textSecondary)
                            }
                        }
                    }
                }
            }

            // Account (only in parent mode)
            SettingsCard {
                VStack(alignment: .leading, spacing: 16) {
                    CardHeader(icon: "person.circle.fill", title: "Account", color: KomalColors.lavenderPurple)
                    
                    if isLoggedIn {
                        Button(action: {
                            showLogoutAlert = true
                        }) {
                            HStack {
                                Image(systemName: "arrow.right.square.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.red)
                                
                                Text("Logout")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(.red)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.red.opacity(0.6))
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        
                        if let email = Auth.auth().currentUser?.email {
                            Text(email)
                                .font(.caption)
                                .foregroundColor(KomalColors.textSecondary)
                                .padding(.top, 4)
                        }
                    } else {
                        Button(action: {
                            appState.hasCompletedOnboarding = false
                            showLoginView = true
                        }) {
                            HStack {
                                Image(systemName: "person.badge.plus.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(KomalColors.pearlAqua)
                                
                                Text("Login")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(KomalColors.pearlAqua)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(KomalColors.pearlAqua.opacity(0.6))
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        
                        Text("Sign in to sync your preferences across devices")
                            .font(.caption)
                            .foregroundColor(KomalColors.textSecondary)
                            .padding(.top, 4)
                    }
                }
            }
        }
    }
    
    private func handleLogout() {
        print("🔄 Starting logout process...")
        
        // Sign out from Firebase Auth first
        do {
            try Auth.auth().signOut()
            print("✅ Firebase Auth signed out")
            // Also sign out from Google Sign-In if it was used
            GIDSignIn.sharedInstance.signOut()
            print("✅ Google Sign-In signed out")
            appState.hasCompletedOnboarding = false
        } catch {
            print("❌ Error signing out: \(error.localizedDescription)")
        }
        
        // Update the shared authViewModel state immediately using Task with @MainActor
        Task { @MainActor in
            print("🔄 Updating authViewModel state...")
            print("📊 Current user before logout: \(authViewModel.user?.uid ?? "nil")")
            
            // Directly update the state
            authViewModel.user = nil
            authViewModel.loginState = .notRunning
            
            print("✅ authViewModel.user is now: \(authViewModel.user?.uid ?? "nil")")
            print("✅ authViewModel.loginState is now: \(authViewModel.loginState)")
            
            // Post notification as additional backup
            NotificationCenter.default.post(name: NSNotification.Name("UserDidSignOut"), object: nil)
            print("✅ Notification posted")
        }
    }
    
    private func addKeyword() {
        let trimmed = newBlockedKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !appState.parentSettings.blockedKeywords.contains(trimmed) {
            withAnimation {
                appState.parentSettings.blockedKeywords.append(trimmed)
            }
            appState.savePreferences() // Persist to UserDefaults
        }
        newBlockedKeyword = ""
    }
    
    private func addHost() {
        let trimmed = newBlockedHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Normalize and validate the website URL
        let normalizedHost = normalizeWebsite(trimmed)
        
        guard !normalizedHost.isEmpty else { return }
        
        if !appState.parentSettings.blockedHosts.contains(normalizedHost) {
            withAnimation {
                appState.parentSettings.blockedHosts.append(normalizedHost)
            }
            appState.savePreferences() // Persist to UserDefaults
        }
        newBlockedHost = ""
    }
    
    /// Normalize website input: converts keywords like "google" to "google.com"
    private func normalizeWebsite(_ input: String) -> String {
        var normalized = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Remove protocol if present
        if normalized.hasPrefix("http://") {
            normalized = String(normalized.dropFirst(7))
        } else if normalized.hasPrefix("https://") {
            normalized = String(normalized.dropFirst(8))
        }
        
        // Remove trailing slashes and paths
        if let slashIndex = normalized.firstIndex(of: "/") {
            normalized = String(normalized[..<slashIndex])
        }
        
        // Remove www. prefix if present
        if normalized.hasPrefix("www.") {
            normalized = String(normalized.dropFirst(4))
        }
        
        // Check if it's already a valid domain (contains a dot and TLD)
        let hasValidDomainFormat = normalized.contains(".") && 
                                   normalized.split(separator: ".").count >= 2 &&
                                   normalized.last != "."
        
        if hasValidDomainFormat {
            // Already a valid domain, return as is
            return normalized
        } else {
            // It's just a keyword, add .com
            // Validate it's a reasonable keyword (alphanumeric and hyphens only)
            let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
            if normalized.rangeOfCharacter(from: allowedCharacters.inverted) == nil && !normalized.isEmpty {
                return normalized + ".com"
            }
        }
        
        return normalized
    }
}

// MARK: - Components

struct SettingsCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

struct CardHeader: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(KomalColors.textPrimary)
            
            Spacer()
        }
    }
}

struct ModernToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(KomalColors.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(KomalColors.textSecondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(KomalColors.bubblegumPink)
        }
    }
}

struct AccountModeButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? color : color.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(isSelected ? .white : color)
                }
                
                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(isSelected ? color : KomalColors.textPrimary)
                    
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(KomalColors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? color.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? color : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ChipView: View {
    let text: String
    let color: Color
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(KomalColors.textPrimary)
            
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(color)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

// Simple FlowLayout for chips
struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        return rows.last?.maxY ?? .zero
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        for row in rows {
            for item in row.items {
                item.view.place(at: CGPoint(x: bounds.minX + item.x, y: bounds.minY + item.y), proposal: .unspecified)
            }
        }
    }

    struct Row {
        var items: [Item] = []
        var maxY: CGSize = .zero
    }

    struct Item {
        var view: LayoutSubview
        var x: CGFloat
        var y: CGFloat
    }

    func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var currentRow = Row()
        var x: CGFloat = 0
        var y: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && !currentRow.items.isEmpty {
                y += (currentRow.items.map { $0.view.sizeThatFits(.unspecified).height }.max() ?? 0) + spacing
                rows.append(currentRow)
                currentRow = Row()
                x = 0
            }
            currentRow.items.append(Item(view: view, x: x, y: y))
            x += size.width + spacing
        }
        if !currentRow.items.isEmpty {
            let rowHeight = currentRow.items.map { $0.view.sizeThatFits(.unspecified).height }.max() ?? 0
            currentRow.maxY = CGSize(width: maxWidth, height: y + rowHeight)
            rows.append(currentRow)
        }
        return rows
    }
}

// Custom Modifiers

struct CleanTextFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(KomalColors.background)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
    }
}

extension View {
    func cleanTextFieldStyle() -> some View {
        modifier(CleanTextFieldStyle())
    }
}

// MARK: - PIN Entry View
struct PinEntryView: View {
    @Binding var enteredPin: String
    @Binding var pinError: Bool
    let onSubmit: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 40))
                    .foregroundColor(KomalColors.lavenderPurple)
                
                Text("Enter Parent PIN")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(KomalColors.textPrimary)
                
                Text("Enter your 4-digit PIN to access parent settings")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(KomalColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            // PIN Input
            VStack(spacing: 8) {
                SecureField("PIN", text: $enteredPin)
                    .keyboardType(.numberPad)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 150)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(KomalColors.background)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(pinError ? Color.red : Color.black.opacity(0.05), lineWidth: pinError ? 2 : 1)
                    )
                
                if pinError {
                    Text("Incorrect PIN. Try again.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.red)
                }
            }
            
            // Buttons
            HStack(spacing: 16) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(KomalColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(KomalColors.background)
                        .cornerRadius(12)
                }
                
                Button(action: onSubmit) {
                    Text("Enter")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(KomalColors.lavenderPurple)
                        .cornerRadius(12)
                }
            }
        }
        .padding(24)
        .background(Color.white)
    }
}

#endif
