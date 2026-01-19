//
//  FirestoreService.swift
//  Komalios
//
//  Created on 18/01/26.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - User Model

struct UserProfile: Codable {
    let uid: String
    let email: String?
    let displayName: String?
    let photoURL: String?
    let provider: String // "google", "apple", etc.
    let createdAt: Timestamp?
    let lastLoginAt: Timestamp?
    let isActive: Bool
    
    init(uid: String, email: String?, displayName: String?, photoURL: String?, provider: String, createdAt: Timestamp? = nil, lastLoginAt: Timestamp? = nil, isActive: Bool = true) {
        self.uid = uid
        self.email = email
        self.displayName = displayName
        self.photoURL = photoURL
        self.provider = provider
        self.createdAt = createdAt
        self.lastLoginAt = lastLoginAt
        self.isActive = isActive
    }
    
    init?(from dictionary: [String: Any]) {
        guard let uid = dictionary["uid"] as? String else {
            return nil
        }
        
        self.uid = uid
        self.email = dictionary["email"] as? String
        self.displayName = dictionary["displayName"] as? String
        self.photoURL = dictionary["photoURL"] as? String
        self.provider = dictionary["provider"] as? String ?? "unknown"
        self.createdAt = dictionary["createdAt"] as? Timestamp
        self.lastLoginAt = dictionary["lastLoginAt"] as? Timestamp
        self.isActive = dictionary["isActive"] as? Bool ?? true
    }
}

// MARK: - Firestore Service

class FirestoreService {
    static let shared = FirestoreService()
    private let db = Firestore.firestore()
    
    private init() {}
    
    /// Store or update user info in Firestore
    func saveUserProfile(_ user: User, provider: String = "google") async throws {
        let userRef = db.collection("users").document(user.uid)
        
        // Check if user already exists
        let document = try await userRef.getDocument()
        
        let userProfile: [String: Any]
        
        if document.exists {
            // Update existing user
            userProfile = [
                "email": user.email ?? NSNull(),
                "displayName": user.displayName ?? NSNull(),
                "photoURL": user.photoURL?.absoluteString ?? NSNull(),
                "provider": provider,
                "lastLoginAt": Timestamp(),
                "isActive": true
            ]
        } else {
            // Create new user
            userProfile = [
                "uid": user.uid,
                "email": user.email ?? NSNull(),
                "displayName": user.displayName ?? NSNull(),
                "photoURL": user.photoURL?.absoluteString ?? NSNull(),
                "provider": provider,
                "createdAt": Timestamp(),
                "lastLoginAt": Timestamp(),
                "isActive": true
            ]
        }
        
        try await userRef.setData(userProfile, merge: true)
    }
    
    /// Get user profile from Firestore
    func getUserProfile(uid: String) async throws -> UserProfile? {
        let userRef = db.collection("users").document(uid)
        let document = try await userRef.getDocument()
        
        guard document.exists,
              let data = document.data() else {
            return nil
        }
        
        return UserProfile(from: data)
    }
    
    /// Validate user exists and is active
    func validateUser(uid: String) async throws -> Bool {
        let userRef = db.collection("users").document(uid)
        let document = try await userRef.getDocument()
        
        guard document.exists,
              let data = document.data(),
              let isActive = data["isActive"] as? Bool else {
            return false
        }
        
        return isActive
    }
    
    /// Update last login timestamp
    func updateLastLogin(uid: String) async throws {
        let userRef = db.collection("users").document(uid)
        try await userRef.updateData([
            "lastLoginAt": Timestamp()
        ])
    }
}
