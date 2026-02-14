//
//  PillButtonStyle.swift
//  Komalios
//
//  Pill-shaped button style for the app
//

import SwiftUI

struct PillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                KomalColors.bubblegumPink,
                                KomalColors.bubblegumPink.opacity(0.8)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: 20) {
        Button("Continue") {}
            .buttonStyle(PillButtonStyle())
        
        Button("Try Again") {}
            .buttonStyle(PillButtonStyle())
    }
    .padding()
    .background(GradientBackground())
}
