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
                    .frame(width: 20, height: 20)

                Spacer()

                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)

                Spacer()
            }
            .padding(.horizontal)
            .frame(height: 50)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity)
    }
}
