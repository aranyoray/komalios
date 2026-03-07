//
//  AuthViewModel.swift
//  Komalios
//
//  Created by Amit Kumar on 18/01/26.
//

import Combine
import FirebaseAuth
enum LoginState {
    case notRunning
    case loading
    case success
    case failure(String)
}

@MainActor
final class AuthViewModel: ObservableObject {

    @Published var user: User?
    @Published var loginState: LoginState = .notRunning

    private let authService: AuthServiceProtocol
    private let firestoreService = FirestoreService.shared

    init(authService: AuthServiceProtocol = FirebaseAuthService()) {
        self.authService = authService
        checkExistingSession()
    }
    
    /// Check if user is already logged in and revalidate with Firestore
    func checkExistingSession() {
        if let currentUser = Auth.auth().currentUser {
            // User is already authenticated, validate with Firestore
            Task {
                loginState = .loading
                do {
                    // Validate user exists and is active in Firestore
                    let isValid = try await firestoreService.validateUser(uid: currentUser.uid)
                    if isValid {
                        // Update last login timestamp
                        try await firestoreService.updateLastLogin(uid: currentUser.uid)
                        self.user = currentUser
                        loginState = .success
                    } else {
                        // User not found or inactive in Firestore, sign out
                        try authService.signOut()
                        loginState = .notRunning
                    }
                } catch let error as NSError where error.domain == NSURLErrorDomain {
                    // Network error — keep session alive, don't sign out
                    // Child safety protections remain active offline
                    self.user = currentUser
                    loginState = .success
                } catch {
                    // Genuine auth/validation failure — sign out for security
                    try? authService.signOut()
                    loginState = .notRunning
                }
            }
        }
    }

    func signInWithGoogle() {
        loginState = .loading

        Task {
            do {
                let firebaseUser = try await authService.signInWithGoogle()
                self.user = firebaseUser
                
                // User info is automatically saved to Firestore in the service
                // and validated on each login
                loginState = .success
            } catch {
                loginState = .failure(error.localizedDescription)
            }
        }
    }
    
    func signInWithApple() {
        loginState = .loading

        Task {
            do {
                let firebaseUser = try await authService.signInWithApple()
                self.user = firebaseUser
                
                // User info is automatically saved to Firestore in the service
                // and validated on each login
                loginState = .success
            } catch {
                loginState = .failure(error.localizedDescription)
                #if DEBUG
                print("ERROR: \(error.localizedDescription)")
                #endif
            }
        }
    }

    func signOut() {
        Task { @MainActor in
            do {
                try authService.signOut()
                self.user = nil
                self.loginState = .notRunning
            } catch {
                self.loginState = .failure(error.localizedDescription)
            }
        }
    }
}
