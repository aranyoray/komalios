//
//  SocialSignInButton.swift
//  Komalios
//
//  Custom button for social sign-in (Google, Apple)
//

import SwiftUI

struct SocialSignInButton: View {
    let logoImage: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(KomalColors.textPrimary)
                
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(KomalColors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(KomalColors.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 8, y: 4)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        SocialSignInButton(logoImage: "google_logo", title: "Sign in with Google") {
            print("Google sign in")
        }
        
        SocialSignInButton(logoImage: "apple_logo", title: "Sign in with Apple") {
            print("Apple sign in")
        }
    }
    .padding()
    .background(GradientBackground())
}
