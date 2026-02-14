//
//  RootView.swift
//  Komalios
//
//  Main home screen after login
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeTabView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            ScannerTabView()
                .tabItem {
                    Label("Scanner", systemImage: "camera.fill")
                }
                .tag(1)
            
            InsightsTabView()
                .tabItem {
                    Label("Insights", systemImage: "chart.bar.fill")
                }
                .tag(2)
            
            SettingsTabView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
        .accentColor(KomalColors.bubblegumPink)
    }
}

// MARK: - Home Tab

struct HomeTabView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationView {
            ZStack {
                GradientBackground()
                
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Hi, \(appState.childName.isEmpty ? "there" : appState.childName)!")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Your digital safety dashboard")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.top, 40)
                    
                    // Quick stats
                    VStack(spacing: 20) {
                        StatCard(
                            icon: "checkmark.shield.fill",
                            title: "Protected Today",
                            value: "0",
                            color: KomalColors.success
                        )
                        
                        StatCard(
                            icon: "eye.slash.fill",
                            title: "Items Blocked",
                            value: "0",
                            color: KomalColors.warning
                        )
                        
                        StatCard(
                            icon: "clock.fill",
                            title: "Screen Time",
                            value: "0h",
                            color: KomalColors.info
                        )
                    }
                    .padding(.horizontal, 30)
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
    }
}

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(color)
                .frame(width: 60, height: 60)
                .background(Circle().fill(Color.white))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.2))
        )
    }
}

// MARK: - Scanner Tab

struct ScannerTabView: View {
    var body: some View {
        NavigationView {
            ZStack {
                GradientBackground()
                
                VStack(spacing: 20) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 80))
                        .foregroundColor(.white)
                    
                    Text("Content Scanner")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Coming Soon")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Insights Tab

struct InsightsTabView: View {
    var body: some View {
        NavigationView {
            ZStack {
                GradientBackground()
                
                VStack(spacing: 20) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.white)
                    
                    Text("Insights & Analytics")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Coming Soon")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Settings Tab

struct SettingsTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationView {
            ZStack {
                GradientBackground()
                
                VStack(spacing: 20) {
                    Text("Settings")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.top, 40)
                    
                    VStack(spacing: 16) {
                        SettingsRow(icon: "person.fill", title: "Profile", subtitle: authViewModel.user?.email ?? "")
                        
                        SettingsRow(icon: "bell.fill", title: "Notifications", subtitle: "Configure alerts")
                        
                        SettingsRow(icon: "shield.fill", title: "Privacy", subtitle: "Manage privacy settings")
                        
                        Button(action: {
                            authViewModel.signOut()
                        }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 24))
                                
                                Text("Sign Out")
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                
                                Spacer()
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.red.opacity(0.8))
                            )
                            .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 30)
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(KomalColors.bubblegumPink)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.white.opacity(0.5))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.2))
        )
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
        .environmentObject(AuthViewModel())
}
