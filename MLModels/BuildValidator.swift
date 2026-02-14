//
//  BuildValidator.swift
//  Komalios
//
//  Compile-time validation to ensure all required types exist
//  This file will fail to compile if dependencies are missing
//

import Foundation

#if canImport(UIKit)
import UIKit
#else
#error("UIKit is required for iOS builds")
#endif

#if canImport(SwiftUI)
import SwiftUI
#else
#error("SwiftUI is required")
#endif

// Validate Firebase imports
#if canImport(FirebaseCore)
import FirebaseCore
#else
#error("FirebaseCore not found - check Package.swift dependencies")
#endif

#if canImport(FirebaseAuth)
import FirebaseAuth
#else
#error("FirebaseAuth not found - check Package.swift dependencies")
#endif

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#else
#error("FirebaseFirestore not found - check Package.swift dependencies")
#endif

// Validate Google Sign-In
#if canImport(GoogleSignIn)
import GoogleSignIn
#else
#error("GoogleSignIn not found - check Package.swift dependencies")
#endif

/// Build validator - ensures all dependencies are properly configured
enum BuildValidator {
    
    /// Validate at compile time that all required types exist
    static func validateTypes() {
        // Validate Firebase types
        let _: FirebaseApp.Type = FirebaseApp.self
        let _: Auth.Type = Auth.self
        let _: Firestore.Type = Firestore.self
        let _: User.Type = User.self
        
        // Validate Google Sign-In types
        let _: GIDSignIn.Type = GIDSignIn.self
        let _: GIDConfiguration.Type = GIDConfiguration.self
        
        // Validate UIKit types
        let _: UIApplication.Type = UIApplication.self
        let _: UIViewController.Type = UIViewController.self
        
        // Validate SwiftUI types
        let _: View.Type = (any View).self
        let _: ViewBuilder.Type = ViewBuilder.self
    }
    
    /// Validate configuration
    static func validateConfig() -> String {
        var report = "🔍 Build Validation Report\n"
        report += "==========================\n\n"
        
        // Check if Config exists
        #if DEBUG
        report += "✅ Build configuration: DEBUG\n"
        #else
        report += "✅ Build configuration: RELEASE\n"
        #endif
        
        report += "✅ UIKit available\n"
        report += "✅ SwiftUI available\n"
        report += "✅ FirebaseCore available\n"
        report += "✅ FirebaseAuth available\n"
        report += "✅ FirebaseFirestore available\n"
        report += "✅ GoogleSignIn available\n"
        
        report += "\n📦 All required frameworks imported successfully!\n"
        
        return report
    }
    
    /// Print validation report
    static func printValidation() {
        print(validateConfig())
    }
}

// Compile-time validation
fileprivate let _compileTimeValidation: Void = {
    BuildValidator.validateTypes()
}()
