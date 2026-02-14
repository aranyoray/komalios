//
//  AuthViewModel.swift
//  Komalios
//
//  Authentication view model managing user sign-in state
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import AuthenticationServices

enum LoginState {
    case notRunning
    case loading
    case success
    case failure(String)
}

@MainActor
class AuthViewModel: ObservableObject {
    @Published var user: User?
    @Published var loginState: LoginState = .notRunning
    
    private let appleSignInService = AppleSignInService()
    
    init() {
        self.user = Auth.auth().currentUser
        
        // Listen for auth state changes
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.user = user
            }
        }
    }
    
    // MARK: - Google Sign In
    
    func signInWithGoogle() {
        loginState = .loading
        
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            loginState = .failure("Missing Firebase client ID")
            return
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        #if canImport(UIKit)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            loginState = .failure("No root view controller")
            return
        }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] result, error in
            Task { @MainActor in
                if let error = error {
                    self?.loginState = .failure(error.localizedDescription)
                    return
                }
                
                guard let user = result?.user,
                      let idToken = user.idToken?.tokenString else {
                    self?.loginState = .failure("Failed to get user token")
                    return
                }
                
                let credential = GoogleAuthProvider.credential(
                    withIDToken: idToken,
                    accessToken: user.accessToken.tokenString
                )
                
                self?.signInWithCredential(credential)
            }
        }
        #else
        loginState = .failure("Google Sign-In only available on iOS")
        #endif
    }
    
    // MARK: - Apple Sign In
    
    func signInWithApple() {
        loginState = .loading
        
        appleSignInService.startSignIn { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let appleSignInResult):
                    guard let identityToken = appleSignInResult.identityToken,
                          let nonce = appleSignInResult.nonce else {
                        self?.loginState = .failure("Missing Apple Sign In data")
                        return
                    }
                    
                    let credential = OAuthProvider.credential(
                        withProviderID: "apple.com",
                        idToken: identityToken,
                        rawNonce: nonce
                    )
                    
                    self?.signInWithCredential(credential)
                    
                case .failure(let error):
                    self?.loginState = .failure(error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Firebase Auth
    
    private func signInWithCredential(_ credential: AuthCredential) {
        Auth.auth().signIn(with: credential) { [weak self] result, error in
            Task { @MainActor in
                if let error = error {
                    self?.loginState = .failure(error.localizedDescription)
                    return
                }
                
                guard let user = result?.user else {
                    self?.loginState = .failure("Failed to get user")
                    return
                }
                
                self?.user = user
                self?.loginState = .success
                
                // Create/update user profile in Firestore
                self?.createUserProfile(user: user)
            }
        }
    }
    
    private func createUserProfile(user: User) {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(user.uid)
        
        let userData: [String: Any] = [
            "uid": user.uid,
            "email": user.email ?? "",
            "displayName": user.displayName ?? "",
            "lastSignIn": FieldValue.serverTimestamp()
        ]
        
        userRef.setData(userData, merge: true) { error in
            if let error = error {
                print("❌ Error creating user profile: \(error.localizedDescription)")
            } else {
                print("✅ User profile created/updated")
            }
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            user = nil
            loginState = .notRunning
            NotificationCenter.default.post(name: NSNotification.Name("UserDidSignOut"), object: nil)
        } catch {
            print("❌ Error signing out: \(error.localizedDescription)")
        }
    }
}
