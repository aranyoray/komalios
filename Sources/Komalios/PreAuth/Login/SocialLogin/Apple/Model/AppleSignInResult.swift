//
//  AppleSignInResult.swift
//  Komalios
//
//  Created by Amit Kumar on 18/01/26.
//

import Foundation

enum AppleAuthState: Equatable {
    case idle
    case loading
    case signedIn(userId: String, email: String?, fullName: String?)
    case failed(String)
}

struct AppleSignInResult {
    let userId: String
    let email: String?
    let fullName: String?
    let identityToken: String?        // JWT
    let authorizationCode: String?    // optional, sometimes useful for server exchange
    let nonce: String?               // the original nonce used (if you generated one)
}
