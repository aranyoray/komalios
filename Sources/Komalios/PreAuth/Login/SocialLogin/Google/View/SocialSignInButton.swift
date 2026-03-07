//
//  GoogleSignInButton.swift
//  Komalios
//
//  Created by Amit Kumar on 18/01/26.
//

import Foundation
import SwiftUI

struct SocialSignInButton: View {

    let logoImage: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {

                Image(logoImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)

                Spacer()

                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)

                Spacer()
            }
            .padding(.horizontal, 20)
            .frame(height: 54)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.black.opacity(0.08), radius: 8, y: 3)
        }
        .frame(maxWidth: .infinity)
    }
}
