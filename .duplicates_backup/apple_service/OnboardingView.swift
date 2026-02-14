//
//  OnboardingView.swift
//  Komalios
//
//  Onboarding flow for setting up child profile and preferences
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    let completion: () -> Void
    
    @State private var currentPage = 0
    @State private var childName = ""
    @State private var childAge = 5
    @State private var selectedCategories: Set<String> = []
    
    let totalPages = 4
    
    var body: some View {
        ZStack {
            GradientBackground()
            
            VStack(spacing: 0) {
                // Progress indicator
                HStack(spacing: 8) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Capsule()
                            .fill(index <= currentPage ? Color.white : Color.white.opacity(0.3))
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)
                
                TabView(selection: $currentPage) {
                    // Page 0: Welcome
                    welcomePage()
                        .tag(0)
                    
                    // Page 1: Child's name
                    childNamePage()
                        .tag(1)
                    
                    // Page 2: Child's age
                    childAgePage()
                        .tag(2)
                    
                    // Page 3: Safety preferences
                    safetyPreferencesPage()
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Navigation buttons
                HStack(spacing: 20) {
                    if currentPage > 0 {
                        Button("Back") {
                            withAnimation {
                                currentPage -= 1
                            }
                        }
                        .buttonStyle(PillButtonStyle())
                    }
                    
                    Button(currentPage < totalPages - 1 ? "Next" : "Get Started") {
                        if currentPage < totalPages - 1 {
                            withAnimation {
                                currentPage += 1
                            }
                        } else {
                            finishOnboarding()
                        }
                    }
                    .buttonStyle(PillButtonStyle())
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }
    
    private func welcomePage() -> some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "hand.wave.fill")
                .font(.system(size: 80))
                .foregroundColor(.white)
            
            Text("Welcome to Komal!")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Text("Let's set up a safe digital environment for your child")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    private func childNamePage() -> some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "person.fill")
                .font(.system(size: 80))
                .foregroundColor(.white)
            
            Text("What's your child's name?")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            TextField("Enter name", text: $childName)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .padding(.horizontal, 40)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
    }
    
    private func childAgePage() -> some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "birthday.cake.fill")
                .font(.system(size: 80))
                .foregroundColor(.white)
            
            Text("How old is \(childName.isEmpty ? "your child" : childName)?")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Picker("Age", selection: $childAge) {
                ForEach(3...17, id: \.self) { age in
                    Text("\(age) years old").tag(age)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 150)
            
            Spacer()
        }
    }
    
    private func safetyPreferencesPage() -> some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "shield.checkered")
                .font(.system(size: 80))
                .foregroundColor(.white)
            
            Text("Choose safety categories")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 12) {
                SafetyCategoryButton(
                    title: "Violence & Weapons",
                    icon: "exclamationmark.triangle.fill",
                    isSelected: selectedCategories.contains("violence"),
                    action: { toggleCategory("violence") }
                )
                
                SafetyCategoryButton(
                    title: "Adult Content",
                    icon: "hand.raised.fill",
                    isSelected: selectedCategories.contains("adult"),
                    action: { toggleCategory("adult") }
                )
                
                SafetyCategoryButton(
                    title: "Hate Speech",
                    icon: "exclamationmark.bubble.fill",
                    isSelected: selectedCategories.contains("hate"),
                    action: { toggleCategory("hate") }
                )
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    private func toggleCategory(_ category: String) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }
    
    private func finishOnboarding() {
        appState.childName = childName
        appState.childAge = childAge
        appState.selectedCategories = selectedCategories
        completion()
    }
}

struct SafetyCategoryButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 24))
                
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.green)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.white : Color.white.opacity(0.3))
            )
            .foregroundColor(isSelected ? KomalColors.textPrimary : .white)
        }
    }
}

#Preview {
    OnboardingView {
        print("Onboarding completed")
    }
    .environmentObject(AppState())
}
