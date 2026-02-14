//
//  SettingsView.swift
//  Komalios
//
//  Detailed settings view
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var appState: AppState
    let selectedTab: Int?
    
    var body: some View {
        ZStack {
            GradientBackground()
            
            ScrollView {
                VStack(spacing: 24) {
                    Text("Settings")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.top, 20)
                    
                    // Profile Section
                    SettingsSection(title: "Profile") {
                        SettingsItem(
                            icon: "person.fill",
                            title: "Account",
                            value: authViewModel.user?.email ?? "Not signed in"
                        )
                        
                        SettingsItem(
                            icon: "person.2.fill",
                            title: "Child Name",
                            value: appState.childName
                        )
                        
                        SettingsItem(
                            icon: "calendar",
                            title: "Child Age",
                            value: "\(appState.childAge) years"
                        )
                    }
                    
                    // Safety Section
                    SettingsSection(title: "Safety & Privacy") {
                        SettingsItem(
                            icon: "shield.fill",
                            title: "Content Filters",
                            value: "\(appState.selectedCategories.count) active"
                        )
                        
                        SettingsItem(
                            icon: "lock.fill",
                            title: "Privacy Settings",
                            value: "Manage"
                        )
                    }
                    
                    // App Section
                    SettingsSection(title: "App") {
                        SettingsItem(
                            icon: "bell.fill",
                            title: "Notifications",
                            value: "Enabled"
                        )
                        
                        SettingsItem(
                            icon: "info.circle.fill",
                            title: "About",
                            value: "Version 1.0"
                        )
                    }
                    
                    // Sign Out Button
                    Button(action: {
                        authViewModel.signOut()
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    
                    Spacer(minLength: 40)
                }
            }
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.2))
            )
            .padding(.horizontal)
        }
    }
}

struct SettingsItem: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(KomalColors.bubblegumPink)
                .frame(width: 30)
            
            Text(title)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.white)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding()
    }
}

#Preview {
    SettingsView(selectedTab: nil)
        .environmentObject(AuthViewModel())
        .environmentObject(AppState())
}
