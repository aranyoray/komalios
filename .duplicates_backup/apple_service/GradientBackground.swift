//
//  GradientBackground.swift
//  Komalios
//
//  Reusable gradient background view
//

import SwiftUI

struct GradientBackground: View {
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                KomalColors.gradientStart,
                KomalColors.gradientEnd
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

#Preview {
    GradientBackground()
}
