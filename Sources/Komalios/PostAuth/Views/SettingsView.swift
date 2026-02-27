#if os(iOS)
import SwiftUI
import StoreKit
import os.log
import FirebaseAuth
import FirebaseFirestore
import UIKit
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject var pathManager: PathManager
    @EnvironmentObject var lang: LanguageManager

    var selectedTab: Binding<NavigationTab>?
    @State private var newBlockedKeyword = ""
    @State private var newBlockedHost = ""
    @State private var showFilterPreferences = false
    @State private var isKeywordsExpanded = false
    @State private var isWebsitesExpanded = false
    @State private var showLogoutAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var showInsights = false
    @State private var showPinEntry = false
    @State private var enteredPin = ""
    @State private var pinError = false
    @State private var isDeletingAccount = false
    
    init(selectedTab: Binding<NavigationTab>? = nil) {
        self.selectedTab = selectedTab
    }
    
    @State private var showDigitalJourney = false
    @State private var showParentInsights = false
    @State private var showGrowthJourney = false
    @State private var showSELJourney = false
    @State private var showPlanSelection = false
    @State private var showEyeTrackingReport = false
    @State private var showBillingHistory = false
    @State private var showPinReset = false
    @State private var newPin = ""
    @State private var confirmNewPin = ""
    @State private var pinResetMismatch = false
    @State private var pinResetSuccess = false
    
    private var isLoggedIn: Bool {
        Auth.auth().currentUser != nil || authViewModel.user != nil
    }

    private var isGuestMode: Bool {
        appState.isGuestUser && !isLoggedIn
    }

    private var subscriptionAccentColor: Color {
        switch appState.subscriptionState.currentPlan {
        case .essentials: return KomalColors.pearlAqua
        case .grow: return KomalColors.lavenderPurple
        case .thrive: return KomalColors.bubblegumPink
        }
    }

    private var subscriptionPlanIcon: String {
        switch appState.subscriptionState.currentPlan {
        case .essentials: return "shield.fill"
        case .grow: return "leaf.fill"
        case .thrive: return "star.fill"
        }
    }

    var body: some View {
        ZStack {
            // Clean, slightly off-white background for clearer card separation
            KomalColors.warmGray
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {

                    // MARK: - Header
                    HStack {
                        Text(lang.localized("settings.title"))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(KomalColors.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    // MARK: - Child Mode Button
                    AccountModeButton(
                        icon: "face.smiling.fill",
                        title: lang.localized("settings.child"),
                        color: KomalColors.pearlAqua,
                        isSelected: appState.accountMode == .child
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            appState.accountMode = .child
                        }
                    }
                    
                    // Show different content based on mode
                    if appState.accountMode == .child {
                        childModeContent
                    } else {
                        parentModeContent
                    }

                    // MARK: - Parent Mode Button (bottom of page)
                    AccountModeButton(
                        icon: "lock.shield.fill",
                        title: lang.localized("settings.parent"),
                        color: KomalColors.lavenderPurple,
                        isSelected: appState.accountMode == .guest
                    ) {
                        if appState.accountMode == .guest {
                            // Already in parent mode, switch to child
                            withAnimation(.spring(response: 0.3)) {
                                appState.accountMode = .child
                            }
                        } else {
                            // Try biometric first if enabled
                            if BiometricAuthService.isBiometricEnabled {
                                Task {
                                    let success = await BiometricAuthService.authenticate()
                                    await MainActor.run {
                                        if success {
                                            withAnimation(.spring(response: 0.3)) {
                                                appState.accountMode = .guest
                                            }
                                        } else {
                                            showPinEntry = true
                                        }
                                    }
                                }
                            } else {
                                showPinEntry = true
                            }
                        }
                    }

                    // Use space at bottom
                    Color.clear.frame(height: 20)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .sheet(isPresented: $showFilterPreferences) {
            FilterPreferencesView(preferences: $appState.contentFilterPreferences)
                .onChange(of: appState.contentFilterPreferences) {
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
                    if let savedPin = KeychainService.getPin(), enteredPin == savedPin {
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
                },
                onBiometricSuccess: {
                    showPinEntry = false
                    enteredPin = ""
                    pinError = false
                    withAnimation(.spring(response: 0.3)) {
                        appState.accountMode = .guest
                    }
                },
                onForgotPin: {
                    showPinEntry = false
                    enteredPin = ""
                    pinError = false
                    showPinReset = true
                }
            )
            .presentationDetents([.height(400)])
        }
        .sheet(isPresented: $showPinReset) {
            PinResetView(
                newPin: $newPin,
                confirmNewPin: $confirmNewPin,
                mismatchError: $pinResetMismatch,
                showSuccess: $pinResetSuccess,
                onSave: {
                    guard newPin.count == 4, newPin == confirmNewPin else {
                        pinResetMismatch = true
                        return
                    }
                    KeychainService.savePin(newPin)
                    pinResetMismatch = false
                    pinResetSuccess = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showPinReset = false
                        newPin = ""
                        confirmNewPin = ""
                        pinResetSuccess = false
                    }
                },
                onCancel: {
                    showPinReset = false
                    newPin = ""
                    confirmNewPin = ""
                    pinResetMismatch = false
                    pinResetSuccess = false
                }
            )
            .presentationDetents([.height(420)])
        }
        .alert(LanguageManager.shared.localized("settings.alert.logout.title"), isPresented: $showLogoutAlert) {
            Button(LanguageManager.shared.localized("common.cancel"), role: .cancel) {
                // User cancelled, do nothing
            }
            Button(LanguageManager.shared.localized("common.yes"), role: .destructive) {
                handleLogout()
            }
        } message: {
            Text(LanguageManager.shared.localized("settings.logout_confirm"))
        }
        .fullScreenCover(isPresented: $showDigitalJourney) {
            DigitalJourneyView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showParentInsights) {
            ParentInsightsDashboardView()
        }
        .sheet(isPresented: $showGrowthJourney) {
            GrowthJourneyView()
        }
        .sheet(isPresented: $showSELJourney) {
            SELJourneyView()
        }
        .sheet(isPresented: $showEyeTrackingReport) {
            EyeTrackingReportView()
        }
        .fullScreenCover(isPresented: $showPlanSelection) {
            PlanSelectionView(allowDismiss: true) { plan in
                appState.subscriptionState.currentPlan = plan
                if let productID = plan.productID {
                    appState.subscriptionState.purchasedProductID = productID
                }
                appState.hasSelectedPlan = true
                showPlanSelection = false
            }
        }
        .sheet(isPresented: $showBillingHistory) {
            BillingHistoryView()
                .environmentObject(appState)
        }
        .alert(LanguageManager.shared.localized("settings.alert.delete.title"), isPresented: $showDeleteAccountAlert) {
            Button(LanguageManager.shared.localized("common.cancel"), role: .cancel) {
                // User cancelled, do nothing
            }
            Button(LanguageManager.shared.localized("common.delete"), role: .destructive) {
                handleDeleteAccount()
            }
        } message: {
            Text(LanguageManager.shared.localized("settings.delete_confirm"))
        }
    }
    
    // MARK: - Child Mode Content
    private var childModeContent: some View {
        VStack(spacing: 16) {
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
                    
                    Text(appState.activeProfile.name.isEmpty
                         ? lang.localized("settings.child.greeting_default")
                         : lang.localized("settings.child.greeting", appState.activeProfile.name))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(KomalColors.textPrimary)

                    Text(lang.localized("settings.child.safe_msg"))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(KomalColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            
            // Fun action cards
            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    CardHeader(icon: "bubble.left.and.bubble.right.fill", title: lang.localized("settings.child.chatty"), color: KomalColors.bubblegumPink)

                    Text(lang.localized("settings.child.chatty.desc"))
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(KomalColors.textSecondary)
                    
                    Button(action: {
                        // Switch to Talk tab (riki)
                        if let binding = selectedTab {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                binding.wrappedValue = .riki
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: "pawprint.fill")
                                .font(.system(size: 18, weight: .semibold))
                            Text(lang.localized("settings.child.go_talk"))
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(KomalColors.lavenderPurple)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(KomalColors.lavenderPurple.opacity(0.12))
                        .contentShape(Capsule())
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(KomalColors.lavenderPurple.opacity(0.4), lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Your profile (limited)
            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    CardHeader(icon: "star.fill", title: lang.localized("settings.child.profile"), color: KomalColors.pearlAqua)

                    HStack(spacing: 12) {
                        if let uiImage = UIImage(named: "animal\(appState.activeProfile.selectedAvatarIndex)") {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 44, height: 44)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(KomalColors.pearlAqua, lineWidth: 2))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(appState.activeProfile.name.isEmpty ? lang.localized("settings.child.explorer") : appState.activeProfile.name)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(KomalColors.textPrimary)

                            Text(lang.localized("settings.child.age", appState.activeProfile.ageGroup.rawValue))
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(KomalColors.textSecondary)
                        }

                        Spacer()
                    }

                    // Avatar picker
                    VStack(alignment: .leading, spacing: 10) {
                        Text(lang.localized("settings.avatar.title"))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(KomalColors.textPrimary)

                        Text(lang.localized("settings.avatar.change"))
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(KomalColors.textSecondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(RikiCharacter.allCharacters) { character in
                                    Button {
                                        withAnimation(.spring(response: 0.3)) {
                                            appState.activeProfile.selectedAvatarIndex = character.id
                                            appState.savePreferences()
                                        }
                                    } label: {
                                        VStack(spacing: 4) {
                                            if let uiImage = UIImage(named: character.imageName) {
                                                Image(uiImage: uiImage)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .frame(width: 48, height: 48)
                                                    .clipShape(Circle())
                                                    .overlay(
                                                        Circle()
                                                            .stroke(
                                                                appState.activeProfile.selectedAvatarIndex == character.id ? KomalColors.lavenderPurple : Color.clear,
                                                                lineWidth: 3
                                                            )
                                                    )
                                            }

                                            Text(character.name)
                                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                                .foregroundColor(
                                                    appState.activeProfile.selectedAvatarIndex == character.id ? KomalColors.lavenderPurple : KomalColors.textSecondary
                                                )
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }

            // Growth Journey card
            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    CardHeader(icon: "sparkles", title: lang.localized("settings.child.journey"), color: KomalColors.bubblegumPink)

                    HStack(spacing: 16) {
                        VStack(spacing: 4) {
                            Text("\(GrowthTrackingService.shared.getEarnedMilestones().count)")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(KomalColors.bubblegumPink)
                            Text(lang.localized("settings.child.milestones"))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(KomalColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    Button(action: { showGrowthJourney = true }) {
                        HStack {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 18, weight: .semibold))
                            Text(lang.localized("settings.child.view_journey"))
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(KomalColors.bubblegumPink)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(KomalColors.bubblegumPink.opacity(0.12))
                        .contentShape(Capsule())
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(KomalColors.bubblegumPink.opacity(0.4), lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Parent Mode Content
    private var parentModeContent: some View {
        VStack(spacing: 16) {
            // Digital Journey
            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    CardHeader(icon: "book.fill", title: lang.localized("settings.parent.digital_journey"), color: KomalColors.lavenderPurple)

                    Button(action: {
                        showDigitalJourney = true
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 20))
                                .foregroundColor(KomalColors.lavenderPurple)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(lang.localized("settings.parent.view_journey"))
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(KomalColors.textPrimary)
                                Text(lang.localized("settings.parent.journey_desc"))
                                    .font(.caption)
                                    .foregroundColor(KomalColors.textSecondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(KomalColors.textSecondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            // SEL Journey
            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    CardHeader(icon: "brain.head.profile", title: LanguageManager.shared.localized("settings.sel_journey"), color: KomalColors.pearlAqua)

                    Button(action: {
                        #if targetEnvironment(simulator)
                        SELAssessmentService.shared.seedMockData()
                        #endif
                        showSELJourney = true
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "pentagon")
                                .font(.system(size: 20))
                                .foregroundColor(KomalColors.pearlAqua)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(LanguageManager.shared.localized("settings.view_sel_report"))
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(KomalColors.textPrimary)
                                Text(LanguageManager.shared.localized("settings.sel_progress_desc"))
                                    .font(.caption)
                                    .foregroundColor(KomalColors.textSecondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(KomalColors.textSecondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            // Eye Tracking
            if EyeTrackingService.isSupported {
                SettingsCard {
                    VStack(alignment: .leading, spacing: 12) {
                        CardHeader(icon: "eye.circle.fill", title: LanguageManager.shared.localized("eye.settings_title"), color: KomalColors.lavenderPurple)

                        ModernToggleRow(
                            icon: "eye.fill",
                            iconColor: KomalColors.lavenderPurple,
                            title: LanguageManager.shared.localized("eye.enable_toggle"),
                            subtitle: LanguageManager.shared.localized("eye.enable_subtitle"),
                            isOn: Binding(
                                get: { appState.parentSettings.eyeTrackingEnabled },
                                set: { newValue in
                                    appState.parentSettings.eyeTrackingEnabled = newValue
                                    appState.savePreferences()
                                    // Defer tracking lifecycle to avoid I/O in Binding.set during view update
                                    Task { @MainActor in
                                        if newValue {
                                            EyeTrackingService.shared.startTracking()
                                            #if targetEnvironment(simulator)
                                            EyeTrackingService.shared.seedMockData()
                                            #endif
                                        } else {
                                            if EyeTrackingService.shared.isTracking {
                                                EyeTrackingService.shared.commitDailySummary()
                                                EyeTrackingService.shared.stopTracking()
                                            }
                                        }
                                    }
                                }
                            )
                        )

                        if appState.parentSettings.eyeTrackingEnabled {
                            Divider()

                            Button(action: { showEyeTrackingReport = true }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "chart.bar.doc.horizontal")
                                        .font(.system(size: 20))
                                        .foregroundColor(KomalColors.lavenderPurple)
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(LanguageManager.shared.localized("eye.view_report"))
                                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                                            .foregroundColor(KomalColors.textPrimary)
                                        Text(LanguageManager.shared.localized("eye.view_report_desc"))
                                            .font(.caption)
                                            .foregroundColor(KomalColors.textSecondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(KomalColors.textSecondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // Child Wellness
            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    CardHeader(icon: "heart.text.square.fill", title: "Child Wellness", color: KomalColors.bubblegumPink)

                    Button(action: { showParentInsights = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 20))
                                .foregroundColor(KomalColors.bubblegumPink)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(LanguageManager.shared.localized("settings.wellness_dashboard"))
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(KomalColors.textPrimary)
                                Text(LanguageManager.shared.localized("settings.wellness_desc"))
                                    .font(.caption)
                                    .foregroundColor(KomalColors.textSecondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(KomalColors.textSecondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Divider()

                    ModernToggleRow(
                        icon: "sunrise.fill",
                        iconColor: .orange,
                        title: "Morning Check-in",
                        subtitle: "Daily morning mood anchor",
                        isOn: Binding(
                            get: { appState.retentionState.morningAnchorEnabled },
                            set: {
                                appState.retentionState.morningAnchorEnabled = $0
                                appState.savePreferences()
                                NotificationService.shared.updateSchedules(retentionState: appState.retentionState)
                            }
                        )
                    )

                    Divider()

                    ModernToggleRow(
                        icon: "moon.fill",
                        iconColor: KomalColors.lavenderPurple,
                        title: "Evening Wind-down",
                        subtitle: "Daily evening reflection anchor",
                        isOn: Binding(
                            get: { appState.retentionState.eveningAnchorEnabled },
                            set: {
                                appState.retentionState.eveningAnchorEnabled = $0
                                appState.savePreferences()
                                NotificationService.shared.updateSchedules(retentionState: appState.retentionState)
                            }
                        )
                    )
                }
            }

            // Subscription & Billing
            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    CardHeader(icon: "crown.fill", title: "Subscription & Billing", color: KomalColors.lavenderPurple)

                    // Current plan badge
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(subscriptionAccentColor.opacity(0.15))
                                .frame(width: 48, height: 48)
                            Image(systemName: subscriptionPlanIcon)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(subscriptionAccentColor)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(appState.subscriptionState.currentPlan.displayName)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(KomalColors.textPrimary)
                            Text(appState.subscriptionState.currentPlan == .essentials ? "Free plan" : "Active subscription")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(KomalColors.textSecondary)
                        }

                        Spacer()

                        Text(appState.subscriptionState.currentPlan == .essentials ? "FREE" : "ACTIVE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(subscriptionAccentColor)
                            .cornerRadius(8)
                    }

                    // Plan features summary
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(appState.subscriptionState.currentPlan.features.prefix(3), id: \.self) { feature in
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(subscriptionAccentColor)
                                Text(feature)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(KomalColors.textSecondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    Divider()

                    // Change Plan
                    Button(action: { showPlanSelection = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(KomalColors.lavenderPurple)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(appState.subscriptionState.currentPlan == .essentials ? "Upgrade Plan" : "Change Plan")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(KomalColors.textPrimary)
                                Text("View all plans and pricing")
                                    .font(.caption)
                                    .foregroundColor(KomalColors.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(KomalColors.textSecondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Divider()

                    // Billing History
                    Button(action: { showBillingHistory = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 20))
                                .foregroundColor(KomalColors.pearlAqua)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Billing & Invoices")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(KomalColors.textPrimary)
                                Text("View transaction history and receipts")
                                    .font(.caption)
                                    .foregroundColor(KomalColors.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(KomalColors.textSecondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Divider()

                    // Manage via App Store
                    Button(action: {
                        Task {
                            let subLog = Logger(subsystem: "com.komalkids.komal", category: "Subscription")
                            subLog.info("Opening App Store manage subscriptions sheet")
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                                try? await AppStore.showManageSubscriptions(in: windowScene)
                            } else {
                                subLog.error("No UIWindowScene found — cannot show manage subscriptions")
                            }
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "gear")
                                .font(.system(size: 20))
                                .foregroundColor(KomalColors.bubblegumPink)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Manage in App Store")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(KomalColors.textPrimary)
                                Text("Cancel, renew, or update payment method")
                                    .font(.caption)
                                    .foregroundColor(KomalColors.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.forward.square")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(KomalColors.textSecondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // Restore Purchases
                    Button(action: {
                        Task {
                            let subLog = Logger(subsystem: "com.komalkids.komal", category: "Subscription")
                            subLog.info("Settings: user tapped Restore Purchases")
                            await SubscriptionService.shared.restorePurchases()
                            let plan = SubscriptionService.shared.currentPlan()
                            subLog.info("Settings: restore complete — plan is now \(plan.displayName)")
                            appState.subscriptionState.currentPlan = plan
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(KomalColors.textSecondary)
                                .frame(width: 24)
                            Text("Restore Purchases")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(KomalColors.textSecondary)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            // Child Profile (editable in parent mode)
            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
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
                VStack(alignment: .leading, spacing: 14) {
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
                                    Text(LanguageManager.shared.localized("settings.view_insights"))
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundColor(KomalColors.textPrimary)
                                    Text(LanguageManager.shared.localized("settings.insights_desc"))
                                        .font(.caption)
                                        .foregroundColor(KomalColors.textSecondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(KomalColors.textSecondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Security & PIN
            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    CardHeader(icon: "lock.circle.fill", title: "Security", color: KomalColors.lavenderPurple)

                    // Face ID / Touch ID toggle
                    if BiometricAuthService.availableBiometricType != .none {
                        ModernToggleRow(
                            icon: BiometricAuthService.biometricIcon,
                            iconColor: KomalColors.lavenderPurple,
                            title: BiometricAuthService.biometricName,
                            subtitle: "Use \(BiometricAuthService.biometricName) to access parent settings",
                            isOn: Binding(
                                get: { BiometricAuthService.isBiometricEnabled },
                                set: { newValue in
                                    BiometricAuthService.isBiometricEnabled = newValue
                                    appState.parentSettings.biometricEnabled = newValue
                                    appState.savePreferences()
                                }
                            )
                        )

                        Divider()
                    }

                    // Change PIN
                    Button(action: {
                        newPin = ""
                        confirmNewPin = ""
                        pinResetMismatch = false
                        pinResetSuccess = false
                        showPinReset = true
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "key.fill")
                                .font(.system(size: 20))
                                .foregroundColor(KomalColors.pearlAqua)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Change PIN")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(KomalColors.textPrimary)
                                Text("Set a new 4-digit parent PIN")
                                    .font(.caption)
                                    .foregroundColor(KomalColors.textSecondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(KomalColors.textSecondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            // Modify Content
            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    CardHeader(icon: "hand.raised.fill", title: "Modify Content", color: KomalColors.bubblegumPink)

                    Button(action: {
                        showFilterPreferences = true
                    }) {
                        HStack {
                            Text(LanguageManager.shared.localized("settings.modify_filters"))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(KomalColors.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(KomalColors.textPrimary)
                        }
                        .contentShape(Rectangle())
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
                                Text(LanguageManager.shared.localized("settings.custom_keywords"))
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(KomalColors.textPrimary)
                                Spacer()
                                Image(systemName: isKeywordsExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(KomalColors.textSecondary)
                            }
                            .contentShape(Rectangle())
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
                                Text(LanguageManager.shared.localized("settings.no_keywords"))
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
                                Text(LanguageManager.shared.localized("settings.custom_websites"))
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(KomalColors.textPrimary)
                                Spacer()
                                Image(systemName: isWebsitesExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(KomalColors.textSecondary)
                            }
                            .contentShape(Rectangle())
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
                                Text(LanguageManager.shared.localized("settings.no_websites"))
                                    .font(.caption)
                                    .italic()
                                    .foregroundColor(KomalColors.textSecondary)
                            }
                        }
                    }
                }
            }

            // Language
            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    CardHeader(icon: "globe", title: lang.localized("settings.language"), color: KomalColors.pearlAqua)

                    ForEach(AppLanguage.allCases) { language in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                lang.currentLanguage = language
                            }
                        }) {
                            HStack(spacing: 12) {
                                Text(language.flag)
                                    .font(.system(size: 24))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(language.nativeName)
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundColor(KomalColors.textPrimary)
                                    Text(language.displayName)
                                        .font(.caption)
                                        .foregroundColor(KomalColors.textSecondary)
                                }

                                Spacer()

                                if lang.currentLanguage == language {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(KomalColors.pearlAqua)
                                }
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)

                        if language != AppLanguage.allCases.last {
                            Divider()
                        }
                    }
                }
            }

            // Account (only in parent mode)
            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    CardHeader(icon: "person.circle.fill", title: "Account", color: KomalColors.lavenderPurple)

                    if isGuestMode {
                        // Guest mode: show sign-in option and guest exit
                        HStack(spacing: 8) {
                            Image(systemName: "person.crop.circle.badge.questionmark")
                                .font(.system(size: 20))
                                .foregroundColor(KomalColors.lavenderPurple)
                            Text(LanguageManager.shared.localized("settings.using_guest"))
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundColor(KomalColors.textPrimary)
                            Spacer()
                        }

                        Text(LanguageManager.shared.localized("settings.guest_data_info"))
                            .font(.caption)
                            .foregroundColor(KomalColors.textSecondary)

                        Button(action: {
                            // Sign in: clear guest flag and go to login
                            appState.isGuestUser = false
                            appState.hasCompletedOnboarding = false
                            pathManager.popToRoot()
                            pathManager.push(Routes.loginView)
                        }) {
                            HStack {
                                Image(systemName: "person.badge.plus.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(KomalColors.pearlAqua)

                                Text(LanguageManager.shared.localized("settings.sign_in"))
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(KomalColors.pearlAqua)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(KomalColors.pearlAqua.opacity(0.6))
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)

                        Divider().padding(.vertical, 4)

                        Button(action: {
                            showLogoutAlert = true
                        }) {
                            HStack {
                                Image(systemName: "arrow.right.square.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.red)

                                Text(LanguageManager.shared.localized("settings.exit_guest"))
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(.red)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.red.opacity(0.6))
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    } else if isLoggedIn {
                        // Delete Account Button
                        Button(action: {
                            showDeleteAccountAlert = true
                        }) {
                            HStack {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.red)

                                Text(LanguageManager.shared.localized("settings.delete_account"))
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(.red)

                                Spacer()

                                if isDeletingAccount {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.red.opacity(0.6))
                                }
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .disabled(isDeletingAccount)

                        Divider().padding(.vertical, 4)

                        // Logout Button
                        Button(action: {
                            showLogoutAlert = true
                        }) {
                            HStack {
                                Image(systemName: "arrow.right.square.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.red)

                                Text(LanguageManager.shared.localized("settings.logout"))
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(.red)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.red.opacity(0.6))
                            }
                            .contentShape(Rectangle())
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
                            // Clear navigation stack and navigate to LoginView
                            pathManager.popToRoot()
                            pathManager.push(Routes.loginView)
                        }) {
                            HStack {
                                Image(systemName: "person.badge.plus.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(KomalColors.pearlAqua)

                                Text(LanguageManager.shared.localized("settings.login"))
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(KomalColors.pearlAqua)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(KomalColors.pearlAqua.opacity(0.6))
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)

                        Text(LanguageManager.shared.localized("settings.sync_desc"))
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

        let wasGuest = appState.isGuestUser

        // Reset guest and onboarding flags
        appState.isGuestUser = false
        appState.hasCompletedOnboarding = false

        if !wasGuest {
            // Sign out from Firebase Auth first
            do {
                try Auth.auth().signOut()
                print("✅ Firebase Auth signed out")
#if canImport(GoogleSignIn)
                GIDSignIn.sharedInstance.signOut()
                print("✅ Google Sign-In signed out")
#else
                // GoogleSignIn not available in this build configuration
#endif
            } catch {
                print("❌ Error signing out: \(error.localizedDescription)")
            }
        }

        // Update the shared authViewModel state immediately using Task with @MainActor
        Task { @MainActor in
            print("🔄 Updating authViewModel state...")

            // Directly update the state
            authViewModel.user = nil
            authViewModel.loginState = .notRunning

            // Clear navigation stack and navigate to LoginView
            pathManager.popToRoot()
            pathManager.push(Routes.loginView)

            // Post notification as additional backup
            NotificationCenter.default.post(name: NSNotification.Name("UserDidSignOut"), object: nil)
            print("✅ Logout completed (wasGuest: \(wasGuest))")
        }
    }
    
    private func handleDeleteAccount() {
        guard let user = Auth.auth().currentUser else {
            print("❌ No user to delete")
            return
        }
        
        isDeletingAccount = true
        print("🗑️ Starting account deletion process...")
        
        Task {
            do {
                // 1. Delete user data from Firestore (including all subcollections — COPPA requirement)
                let db = Firestore.firestore()

                // Delete app-history events subcollection
                let eventsRef = db.collection("app-history").document(user.uid).collection("events")
                let eventDocs = try await eventsRef.getDocuments()
                for doc in eventDocs.documents {
                    try await doc.reference.delete()
                }
                try? await db.collection("app-history").document(user.uid).delete()

                // Delete synced data (sync docs + subcollections)
                await FirestoreSyncService.shared.deleteAllUserData(uid: user.uid)
                print("✅ Synced data deleted from Firestore")

                // Delete top-level user document
                let userRef = db.collection("users").document(user.uid)
                try await userRef.delete()
                print("✅ User data deleted from Firestore")
                
                // 2. Delete Firebase Auth account
                try await user.delete()
                print("✅ Firebase Auth account deleted")
                
                // 3. Sign out from Google Sign-In if it was used
                await MainActor.run {
#if canImport(GoogleSignIn)
                    GIDSignIn.sharedInstance.signOut()
                    print("✅ Google Sign-In signed out")
#else
                    // GoogleSignIn not available in this build configuration
#endif
                    
                    // 4. Clear local app state
                    appState.hasCompletedOnboarding = false
                    appState.isGuestUser = false

                    // Clear UserDefaults
                    UserDefaults.standard.removeObject(forKey: "komal.hasCompletedOnboarding")
                    UserDefaults.standard.removeObject(forKey: "komal.isGuestUser")
                    UserDefaults.standard.removeObject(forKey: "komal.contentFilterPreferences")
                    UserDefaults.standard.removeObject(forKey: "komal.activeProfile")
                    UserDefaults.standard.removeObject(forKey: "komal.accountMode")
                    UserDefaults.standard.removeObject(forKey: "komal.parentSettings")
                    UserDefaults.standard.removeObject(forKey: "komal.subscriptionState")
                    UserDefaults.standard.removeObject(forKey: "komal.hasSelectedPlan")

                    print("✅ Local data cleared")
                    
                    // 5. Update authViewModel state
                    authViewModel.user = nil
                    authViewModel.loginState = .notRunning
                    
                    print("✅ Account deletion completed")
                    
                    // Clear navigation stack and navigate to LoginView
                    pathManager.popToRoot()
                    pathManager.push(Routes.loginView)
                    
                    // Post notification
                    NotificationCenter.default.post(name: NSNotification.Name("UserDidSignOut"), object: nil)
                    
                    isDeletingAccount = false
                }
            } catch {
                await MainActor.run {
                    print("❌ Error deleting account: \(error.localizedDescription)")
                    isDeletingAccount = false
                    
                    // Show error alert
                    // You might want to add an error alert here
                }
            }
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
            .padding(16)
            .background(Color.white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }
}

struct CardHeader: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
            }

            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
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
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? color : color.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isSelected ? .white : color)
                }

                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? color : KomalColors.textPrimary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(color)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? color.opacity(0.1) : Color.white)
            )
            .contentShape(Rectangle())
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? color : Color.black.opacity(0.08), lineWidth: isSelected ? 2 : 0.5)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
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
                    .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
            )
    }
}

extension View {
    func cleanTextFieldStyle() -> some View {
        modifier(CleanTextFieldStyle())
    }
}

// MARK: - Billing History View

struct BillingHistoryView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var transactions: [SubscriptionService.TransactionInfo] = []
    @State private var renewalDate: Date?
    @State private var isLoading = true

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                KomalColors.warmGray.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Current plan summary card
                        VStack(spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Current Plan")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(KomalColors.textSecondary)
                                    Text(appState.subscriptionState.currentPlan.displayName)
                                        .font(.system(size: 24, weight: .bold, design: .rounded))
                                        .foregroundColor(KomalColors.textPrimary)
                                }
                                Spacer()
                                if appState.subscriptionState.currentPlan != .essentials {
                                    VStack(alignment: .trailing, spacing: 4) {
                                        if let price = SubscriptionService.shared.priceString(for: appState.subscriptionState.currentPlan) {
                                            Text(price)
                                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                                .foregroundColor(KomalColors.textPrimary)
                                            Text("per month")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(KomalColors.textSecondary)
                                        }
                                    }
                                }
                            }

                            if let renewal = renewalDate, appState.subscriptionState.currentPlan != .essentials {
                                Divider()
                                HStack {
                                    Image(systemName: "calendar.badge.clock")
                                        .font(.system(size: 16))
                                        .foregroundColor(KomalColors.lavenderPurple)
                                    Text("Next renewal: \(Self.shortDateFormatter.string(from: renewal))")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(KomalColors.textSecondary)
                                    Spacer()
                                }
                            }
                        }
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)

                        // Transaction history
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Transaction History")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(KomalColors.textPrimary)

                            if isLoading {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                    Spacer()
                                }
                                .padding(.vertical, 40)
                            } else if transactions.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 36))
                                        .foregroundColor(KomalColors.textSecondary.opacity(0.5))
                                    Text("No transactions yet")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(KomalColors.textSecondary)
                                    Text("Your purchase history will appear here")
                                        .font(.system(size: 13))
                                        .foregroundColor(KomalColors.textSecondary.opacity(0.7))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                            } else {
                                ForEach(transactions) { transaction in
                                    TransactionRow(transaction: transaction)
                                }
                            }
                        }
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)

                        // Info footer
                        VStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 13))
                                Text("Subscriptions are managed through your Apple ID. To request a refund, visit reportaproblem.apple.com")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(KomalColors.textSecondary)
                            .padding(.horizontal, 4)
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Billing & Invoices")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(KomalColors.lavenderPurple)
                }
            }
            .task {
                let billingLog = Logger(subsystem: "com.komalkids.komal", category: "Billing")
                billingLog.info("BillingHistoryView loading — fetching products and history...")
                await SubscriptionService.shared.fetchProducts()
                await SubscriptionService.shared.fetchTransactionHistory()
                transactions = SubscriptionService.shared.transactionHistory
                billingLog.info("Loaded \(transactions.count) transactions")
                renewalDate = await SubscriptionService.shared.currentRenewalDate()
                billingLog.info("Renewal date: \(renewalDate?.description ?? "none")")
                isLoading = false
            }
        }
    }
}

private struct TransactionRow: View {
    let transaction: SubscriptionService.TransactionInfo

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private var statusColor: Color {
        if transaction.isRevoked { return .red }
        if let exp = transaction.expirationDate, exp < Date() { return KomalColors.textSecondary }
        return KomalColors.pearlAqua
    }

    private var statusText: String {
        if transaction.isRevoked { return "Refunded" }
        if let exp = transaction.expirationDate, exp < Date() { return "Expired" }
        return "Completed"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: transaction.isRevoked ? "arrow.uturn.backward" : "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(statusColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(transaction.planName) Monthly")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(KomalColors.textPrimary)
                    Text(Self.dateFormatter.string(from: transaction.purchaseDate))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(KomalColors.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    if let price = transaction.displayPrice {
                        Text(price)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(KomalColors.textPrimary)
                    }
                    Text(statusText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(statusColor)
                }
            }
            .padding(.vertical, 12)

            Divider()
        }
    }
}

// MARK: - PIN Entry View
struct PinEntryView: View {
    @Binding var enteredPin: String
    @Binding var pinError: Bool
    let onSubmit: () -> Void
    let onCancel: () -> Void
    var onBiometricSuccess: (() -> Void)? = nil
    var onForgotPin: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 40))
                    .foregroundColor(KomalColors.lavenderPurple)

                Text(LanguageManager.shared.localized("settings.enter_pin"))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(KomalColors.textPrimary)

                Text(LanguageManager.shared.localized("settings.pin_desc"))
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
                            .stroke(pinError ? Color.red : Color.black.opacity(0.1), lineWidth: pinError ? 2 : 0.5)
                    )
                    .onChange(of: enteredPin) {
                        if enteredPin.count > 4 { enteredPin = String(enteredPin.prefix(4)) }
                    }

                if pinError {
                    Text(LanguageManager.shared.localized("settings.incorrect_pin"))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.red)
                }
            }

            // Biometric button
            if BiometricAuthService.isBiometricEnabled && BiometricAuthService.availableBiometricType != .none {
                Button(action: {
                    Task {
                        let success = await BiometricAuthService.authenticate()
                        if success {
                            await MainActor.run {
                                onBiometricSuccess?()
                            }
                        }
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: BiometricAuthService.biometricIcon)
                            .font(.system(size: 20))
                        Text(LanguageManager.shared.localized("settings.use_biometric", BiometricAuthService.biometricName))
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(KomalColors.lavenderPurple)
                }
            }

            // Buttons
            HStack(spacing: 16) {
                Button(action: onCancel) {
                    Text(LanguageManager.shared.localized("common.cancel"))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(KomalColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(KomalColors.background)
                        .cornerRadius(12)
                }

                Button(action: onSubmit) {
                    Text(LanguageManager.shared.localized("settings.enter"))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(enteredPin.count == 4 ? KomalColors.lavenderPurple : KomalColors.lavenderPurple.opacity(0.4))
                        .cornerRadius(12)
                }
                .disabled(enteredPin.count != 4)
            }

            // Forgot PIN - uses Face ID to reset
            if BiometricAuthService.availableBiometricType != .none, onForgotPin != nil {
                Button(action: {
                    Task {
                        let success = await BiometricAuthService.authenticate()
                        if success {
                            await MainActor.run {
                                onForgotPin?()
                            }
                        }
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: BiometricAuthService.biometricIcon)
                            .font(.system(size: 14))
                        Text("Forgot PIN? Reset with \(BiometricAuthService.biometricName)")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(KomalColors.textSecondary)
                }
            }
        }
        .padding(24)
        .background(Color.white)
    }
}

// MARK: - PIN Reset View
struct PinResetView: View {
    @Binding var newPin: String
    @Binding var confirmNewPin: String
    @Binding var mismatchError: Bool
    @Binding var showSuccess: Bool
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            if showSuccess {
                // Success state
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(KomalColors.pearlAqua)

                    Text("PIN Updated")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(KomalColors.textPrimary)

                    Text("Your new parent PIN has been saved.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(KomalColors.textSecondary)
                }
            } else {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 40))
                        .foregroundColor(KomalColors.lavenderPurple)

                    Text("Set New PIN")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(KomalColors.textPrimary)

                    Text("Enter a new 4-digit parent PIN")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(KomalColors.textSecondary)
                }

                // New PIN fields
                VStack(spacing: 12) {
                    SecureField("New PIN", text: $newPin)
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
                                .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
                        )
                        .onChange(of: newPin) {
                            if newPin.count > 4 { newPin = String(newPin.prefix(4)) }
                            mismatchError = false
                        }

                    SecureField("Confirm PIN", text: $confirmNewPin)
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
                                .stroke(mismatchError ? Color.red : Color.black.opacity(0.1), lineWidth: mismatchError ? 2 : 0.5)
                        )
                        .onChange(of: confirmNewPin) {
                            if confirmNewPin.count > 4 { confirmNewPin = String(confirmNewPin.prefix(4)) }
                            mismatchError = false
                        }

                    if mismatchError {
                        Text("PINs don't match or are incomplete")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.red)
                    }
                }

                // Buttons
                HStack(spacing: 16) {
                    Button(action: onCancel) {
                        Text(LanguageManager.shared.localized("common.cancel"))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(KomalColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(KomalColors.background)
                            .cornerRadius(12)
                    }

                    Button(action: onSave) {
                        Text("Save PIN")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(newPin.count == 4 && confirmNewPin.count == 4 ? KomalColors.lavenderPurple : KomalColors.lavenderPurple.opacity(0.4))
                            .cornerRadius(12)
                    }
                    .disabled(newPin.count != 4 || confirmNewPin.count != 4)
                }
            }
        }
        .padding(24)
        .background(Color.white)
    }
}

#endif


