//
//  FilterPreferencesView.swift
//  Komalios
//
//  Created on 18/01/26.
//

#if canImport(SwiftUI)
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
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        appState.savePreferences()
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(KomalColors.bubblegumPink)
                }
            }
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
}
#endif
