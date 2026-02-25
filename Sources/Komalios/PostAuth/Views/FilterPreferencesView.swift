//
//  FilterPreferencesView.swift
//  Komalios
//
//  Created on 18/01/26.
//

#if os(iOS)
import SwiftUI

struct FilterPreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @Binding var preferences: ContentFilterPreferences
    
    var body: some View {
        NavigationView {
            ZStack {
                GradientBackground()
                
                VStack(spacing: 16) {
                    // Header
                    VStack(spacing: 8) {
                        Text(LanguageManager.shared.localized("filter.content_settings"))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(KomalColors.textPrimary)

                        Text(LanguageManager.shared.localized("filter.customize"))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(KomalColors.textSecondary)
                    }
                    .padding(.top, 10)
                    
                    // Legend — gradient bar with labels
                    HStack(spacing: 0) {
                        Text(LanguageManager.shared.localized("filter.block"))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .textCase(.uppercase)
                            .foregroundColor(Color(hex: "C0392B"))

                        Spacer()

                        Text(LanguageManager.shared.localized("filter.gate"))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .textCase(.uppercase)
                            .foregroundColor(Color(hex: "BF4800")) // Darkened for 4.94:1 AA contrast

                        Spacer()

                        Text(LanguageManager.shared.localized("filter.allow"))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .textCase(.uppercase)
                            .foregroundColor(Color(hex: "1E8449"))
                    }
                    .padding(.horizontal, 30)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.red, .orange, .green],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 6)
                        .padding(.horizontal, 30)
                        .padding(.top, -8)
                    
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
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LanguageManager.shared.localized("common.done")) {
                        appState.savePreferences()
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(KomalColors.bubblegumPink)
                }
            }
        }
    }
    
}
#endif
