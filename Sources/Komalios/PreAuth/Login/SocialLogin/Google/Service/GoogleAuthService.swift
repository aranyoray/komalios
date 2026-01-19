//
//  GoogleAuthService.swift
//  Komalios
//
//  Created by Amit Kumar on 18/01/26.
//

import FirebaseAuth
import GoogleSignIn
import FirebaseCore
import FirebaseFirestore
import AuthenticationServices
import CryptoKit
import UIKit
import Foundation

protocol AuthServiceProtocol {
    func signInWithGoogle() async throws -> User
    func signInWithApple() async throws -> User
    func signOut() throws
}

final class FirebaseAuthService: AuthServiceProtocol {
    private let firestoreService = FirestoreService.shared

    func signInWithGoogle() async throws -> User {

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw NSError(domain: "ClientID missing", code: 0)
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        let rootVC = await UIApplication.shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .windows
            .first?
            .rootViewController

        let result = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: rootVC!
        )

        let credential = GoogleAuthProvider.credential(
            withIDToken: result.user.idToken!.tokenString,
            accessToken: result.user.accessToken.tokenString
        )

        let authResult = try await Auth.auth().signIn(with: credential)
        let user = authResult.user
        
        // Store/update user info in Firestore
        try await firestoreService.saveUserProfile(user, provider: "google")
        
        // Validate user exists and is active
        let isValid = try await firestoreService.validateUser(uid: user.uid)
        guard isValid else {
            throw NSError(domain: "User validation failed", code: 0)
        }
        
        // Update last login timestamp
        try await firestoreService.updateLastLogin(uid: user.uid)

        return user   // ✅ SUCCESS DATA
    }

    func signInWithApple() async throws -> User {
        // Generate a random nonce for security
        let nonce = randomNonceString()
        let hashedNonce = sha256(nonce)
        
        // Request Apple ID authorization
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = hashedNonce
        
        // Perform the authorization request
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        
        // Use async/await with continuation
        return try await withCheckedThrowingContinuation { continuation in
            let delegate = AppleSignInDelegate(
                nonce: nonce,
                continuation: continuation,
                firestoreService: firestoreService
            )
            authorizationController.delegate = delegate
            authorizationController.presentationContextProvider = delegate
            
            // Retain delegate
            objc_setAssociatedObject(authorizationController, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            
            authorizationController.performRequests()
        }
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
    }
    
    // MARK: - Apple Sign-In Helpers
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}

// MARK: - Apple Sign-In Delegate

private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let nonce: String
    private let continuation: CheckedContinuation<User, Error>
    private let firestoreService: FirestoreService
    
    init(nonce: String, continuation: CheckedContinuation<User, Error>, firestoreService: FirestoreService) {
        self.nonce = nonce
        self.continuation = continuation
        self.firestoreService = firestoreService
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation.resume(throwing: NSError(domain: "AppleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Apple credential"]))
            return
        }
        
        guard let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            continuation.resume(throwing: NSError(domain: "AppleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to fetch identity token"]))
            return
        }
        
        // Create Firebase credential using the static Apple credential method
        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )
        
        // Sign in with Firebase
        Task {
            do {
                let authResult = try await Auth.auth().signIn(with: credential)
                let user = authResult.user
                
                // Store/update user info in Firestore
                try await firestoreService.saveUserProfile(user, provider: "apple")
                
                // Validate user exists and is active
                let isValid = try await firestoreService.validateUser(uid: user.uid)
                guard isValid else {
                    continuation.resume(throwing: NSError(domain: "User validation failed", code: 0))
                    return
                }
                
                // Update last login timestamp
                try await firestoreService.updateLastLogin(uid: user.uid)
                
                continuation.resume(returning: user)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation.resume(throwing: error)
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}
