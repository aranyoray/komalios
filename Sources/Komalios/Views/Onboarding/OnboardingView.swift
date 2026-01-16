#if canImport(SwiftUI)
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentPage = 0
    @State private var childName: String = ""
    @State private var selectedAgeGroup: AgeGroup = .tenToThirteen
    @State private var preferences: ContentFilterPreferences = ContentFilterPreferences()

    var onComplete: () -> Void

    private let totalPages = 4

    var body: some View {
        ZStack {
            GradientBackground()

            VStack(spacing: 0) {
                // Progress indicator
                StepIndicator(currentStep: currentPage, totalSteps: totalPages)
                    .padding(.top, 20)

                // Page content
                TabView(selection: $currentPage) {
                    welcomeScreen
                        .tag(0)

                    childInfoScreen
                        .tag(1)

                    categorySettingsScreen
                        .tag(2)

                    completionScreen
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)
            }
        }
    }

    // MARK: - Welcome Screen

    private var welcomeScreen: some View {
        VStack(spacing: 30) {
            Spacer()

            // Logo
            ZStack {
                Circle()
                    .fill(KomalColors.white)
                    .frame(width: 140, height: 140)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)

                Image(systemName: "shield.checkered")
                    .font(.system(size: 70))
                    .foregroundColor(KomalColors.bubblegumPink)
            }

            VStack(spacing: 16) {
                Text("Welcome to Komal")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(KomalColors.textPrimary)

                Text("Your child's safe digital companion")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(KomalColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 16) {
                featureRow(icon: "shield.fill", color: KomalColors.pearlAqua, text: "Age-appropriate content filtering")
                featureRow(icon: "eye.fill", color: KomalColors.lavenderPurple, text: "Real-time content analysis")
                featureRow(icon: "hand.raised.fill", color: KomalColors.bubblegumPink, text: "Customizable protection levels")
                featureRow(icon: "chart.bar.fill", color: KomalColors.pearlAqua, text: "Activity monitoring for parents")
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)

            Spacer()

            Button(action: { withAnimation { currentPage = 1 } }) {
                Text("Get Started")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PillButtonStyle())
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    private func featureRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.3))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
            }

            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(KomalColors.textPrimary)

            Spacer()
        }
    }

    // MARK: - Child Info Screen

    private var childInfoScreen: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(KomalColors.white)
                    .frame(width: 100, height: 100)
                    .shadow(color: Color.black.opacity(0.1), radius: 8, y: 4)

                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 50))
                    .foregroundColor(KomalColors.lavenderPurple)
            }

            VStack(spacing: 8) {
                Text("About Your Child")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(KomalColors.textPrimary)

                Text("We'll customize settings based on their age")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(KomalColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 20) {
                // Child name input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Child's Name")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(KomalColors.textSecondary)
                        .padding(.leading, 16)

                    TextField("Enter name", text: $childName)
                        .roundedTextFieldStyle()
                }

                // Age group picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Age Group")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(KomalColors.textSecondary)
                        .padding(.leading, 16)

                    Picker("Age Group", selection: $selectedAgeGroup) {
                        ForEach(AgeGroup.allCases) { group in
                            Text(group.rawValue).tag(group)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 4)
                }

                // Age group info
                VStack(spacing: 8) {
                    Text("Selected: \(selectedAgeGroup.rawValue)")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(KomalColors.textPrimary)

                    Text("We'll suggest appropriate default settings")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(KomalColors.textSecondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(KomalColors.lavenderPurple.opacity(0.15))
                .cornerRadius(16)
            }
            .padding(.horizontal, 40)

            Spacer()

            HStack(spacing: 16) {
                Button(action: { withAnimation { currentPage = 0 } }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryPillButtonStyle())

                Button(action: {
                    preferences = ContentFilterPreferences.defaults(for: selectedAgeGroup)
                    withAnimation { currentPage = 2 }
                }) {
                    HStack {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PillButtonStyle())
                .disabled(childName.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(childName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Category Settings Screen

    private var categorySettingsScreen: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 8) {
                Text("Content Settings")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(KomalColors.textPrimary)

                Text("Customize what content is allowed")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(KomalColors.textSecondary)
            }
            .padding(.top, 10)

            // Legend
            HStack(spacing: 20) {
                legendItem(color: KomalColors.bubblegumPink, label: "Block")
                legendItem(color: Color.orange, label: "Gate")
                legendItem(color: KomalColors.pearlAqua, label: "Allow")
            }
            .padding(.horizontal)

            // Categories list
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(OnboardingCategory.allCategories) { category in
                        CategorySettingsCard(
                            category: category,
                            preferences: $preferences
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }

            // Navigation buttons
            HStack(spacing: 16) {
                Button(action: { withAnimation { currentPage = 1 } }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryPillButtonStyle())

                Button(action: { withAnimation { currentPage = 3 } }) {
                    HStack {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PillButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)

            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(KomalColors.textPrimary)
        }
    }

    // MARK: - Completion Screen

    private var completionScreen: some View {
        VStack(spacing: 30) {
            Spacer()

            ZStack {
                Circle()
                    .fill(KomalColors.pearlAqua.opacity(0.3))
                    .frame(width: 160, height: 160)

                Circle()
                    .fill(KomalColors.white)
                    .frame(width: 120, height: 120)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)

                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 60))
                    .foregroundColor(KomalColors.pearlAqua)
            }

            VStack(spacing: 12) {
                Text("All Set!")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(KomalColors.textPrimary)

                Text("\(childName) is now protected")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(KomalColors.textSecondary)
            }

            BubblyCard {
                VStack(alignment: .leading, spacing: 16) {
                    summaryRow(icon: "person.fill", text: "Profile: \(childName)")
                    summaryRow(icon: "calendar", text: "Age Group: \(selectedAgeGroup.rawValue)")
                    summaryRow(icon: "slider.horizontal.3", text: "Custom settings configured")
                    summaryRow(icon: "gear", text: "Edit anytime in Settings")
                }
            }
            .padding(.horizontal, 30)

            Spacer()

            VStack(spacing: 12) {
                Button(action: {
                    // Save settings
                    appState.activeProfile = ChildProfile(name: childName, ageGroup: selectedAgeGroup)
                    appState.contentFilterPreferences = preferences
                    appState.hasCompletedOnboarding = true
                    onComplete()
                }) {
                    Text("Start Using Komal")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PillButtonStyle())

                Button(action: { withAnimation { currentPage = 2 } }) {
                    Text("Edit Settings")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(KomalColors.textSecondary)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    private func summaryRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(KomalColors.bubblegumPink)
                .frame(width: 24)

            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(KomalColors.textPrimary)

            Spacer()
        }
    }
}

// MARK: - Category Settings Card

struct CategorySettingsCard: View {
    let category: OnboardingCategory
    @Binding var preferences: ContentFilterPreferences
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: category.icon)
                        .font(.system(size: 20))
                        .foregroundColor(KomalColors.lavenderPurple)
                        .frame(width: 32)

                    Text(category.title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(KomalColors.textPrimary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(KomalColors.textSecondary)
                }
                .padding()
                .background(Color.white)
                .cornerRadius(isExpanded ? 16 : 16)
            }
            .buttonStyle(.plain)

            // Items
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(category.items) { item in
                        CategoryItemRow(item: item, preferences: $preferences)

                        if item.id != category.items.last?.id {
                            Divider()
                                .padding(.horizontal)
                        }
                    }
                }
                .background(Color.white)
                .cornerRadius(16)
                .padding(.top, -8)
            }
        }
        .shadow(color: Color.black.opacity(0.06), radius: 8, y: 2)
    }
}

// MARK: - Category Item Row

struct CategoryItemRow: View {
    let item: OnboardingCategoryItem
    @Binding var preferences: ContentFilterPreferences

    private var currentAction: FilterAction {
        preferences[keyPath: item.keyPath]
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(KomalColors.textPrimary)

                Text(item.description)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(KomalColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Action selector
            HStack(spacing: 4) {
                actionButton(.block, icon: "xmark", color: KomalColors.bubblegumPink)
                actionButton(.gate, icon: "exclamationmark", color: Color.orange)
                actionButton(.allow, icon: "checkmark", color: KomalColors.pearlAqua)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private func actionButton(_ action: FilterAction, icon: String, color: Color) -> some View {
        Button(action: {
            preferences[keyPath: item.keyPath] = action
        }) {
            ZStack {
                Circle()
                    .fill(currentAction == action ? color : color.opacity(0.2))
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(currentAction == action ? .white : color)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingView(onComplete: {})
        .environmentObject(AppState())
}
#endif
