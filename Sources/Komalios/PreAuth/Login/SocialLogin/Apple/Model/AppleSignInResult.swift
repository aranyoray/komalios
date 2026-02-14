//
//  AppleSignInResult.swift
//  Komalios
//
//  Created by Amit Kumar on 18/01/26.
//  Data model for Apple Sign In authentication result
//

import Foundation

/// State of Apple authentication flow
enum AppleAuthState: Equatable {
    case idle
    case loading
    case signedIn(userId: String, email: String?, fullName: String?)
    case failed(String)
}

/// Result data from a successful Apple Sign In authentication
struct AppleSignInResult {
    /// Unique user identifier from Apple
    let userId: String

    /// User's email address (may be nil if user chose to hide it)
    let email: String?

    /// User's full name (may be nil after first sign-in)
    let fullName: String?

    /// JWT identity token for Firebase authentication
    let identityToken: String?

    /// Authorization code (one-time use)
    let authorizationCode: String?

    /// The nonce used for this authentication request
    let nonce: String?

    /// Check if all required data for Firebase auth is present
    var isValidForFirebaseAuth: Bool {
        return identityToken != nil && nonce != nil
    }
}

// MARK: - CustomStringConvertible
extension AppleSignInResult: CustomStringConvertible {
    var description: String {
        """
        AppleSignInResult(
            userId: \(userId),
            email: \(email ?? "hidden"),
            fullName: \(fullName ?? "nil"),
            hasIdentityToken: \(identityToken != nil),
            hasAuthCode: \(authorizationCode != nil),
            hasNonce: \(nonce != nil)
        )
        """
    }
}
