//
//  Config.swift
//  Komalios
//
//  Centralized configuration for API keys and service URLs
//  Created: January 27, 2026
//

import Foundation

/// Configuration for all external services and API keys
enum Config {
    
    // MARK: - API Keys
    
    /// Google Cloud API Key for Vision, Video Intelligence, and Natural Language APIs
    /// Used as fallback when CoreML models have low confidence
    /// ⚠️ PRIVATE - DO NOT COMMIT TO PUBLIC REPO
    static let googleCloudAPIKey: String = {
        // Priority 1: Environment variable (for CI/CD)
        if let envKey = ProcessInfo.processInfo.environment["GOOGLE_CLOUD_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        
        // Priority 2: Plist configuration
        if let plistKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLOUD_API_KEY") as? String, !plistKey.isEmpty {
            return plistKey
        }
        
        #if DEBUG
        print("Config: GOOGLE_CLOUD_API_KEY not configured in environment or Info.plist")
        #endif
        return ""
    }()

    /// Google Custom Search API Key
    /// Configure via GOOGLE_CUSTOM_SEARCH_API_KEY in environment or Info.plist
    static let googleCustomSearchAPIKey: String = {
        if let envKey = ProcessInfo.processInfo.environment["GOOGLE_CUSTOM_SEARCH_API_KEY"], !envKey.isEmpty {
            return envKey
        }

        if let plistKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CUSTOM_SEARCH_API_KEY") as? String, !plistKey.isEmpty {
            return plistKey
        }

        #if DEBUG
        print("Config: GOOGLE_CUSTOM_SEARCH_API_KEY not configured in environment or Info.plist")
        #endif
        return ""
    }()

    /// Google Custom Search Engine ID
    /// Configure via GOOGLE_CUSTOM_SEARCH_ENGINE_ID in environment or Info.plist
    static let googleCustomSearchEngineID: String = {
        if let envKey = ProcessInfo.processInfo.environment["GOOGLE_CUSTOM_SEARCH_ENGINE_ID"], !envKey.isEmpty {
            return envKey
        }

        if let plistKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CUSTOM_SEARCH_ENGINE_ID") as? String, !plistKey.isEmpty {
            return plistKey
        }

        #if DEBUG
        print("Config: GOOGLE_CUSTOM_SEARCH_ENGINE_ID not configured in environment or Info.plist")
        #endif
        return ""
    }()

    /// Google Gemini API Key for conversational AI (Riki chat feature)
    /// Configure via GEMINI_API_KEY in environment or Info.plist
    static let geminiAPIKey: String = {
        if let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !envKey.isEmpty {
            return envKey
        }

        if let plistKey = Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String, !plistKey.isEmpty {
            return plistKey
        }

        #if DEBUG
        print("Config: GEMINI_API_KEY not configured in environment or Info.plist")
        #endif
        return ""
    }()

    /// Google Cloud Project ID
    /// Configure via GOOGLE_CLOUD_PROJECT_ID in environment or Info.plist
    static let googleCloudProjectID: String = {
        if let envKey = ProcessInfo.processInfo.environment["GOOGLE_CLOUD_PROJECT_ID"], !envKey.isEmpty {
            return envKey
        }

        if let plistKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLOUD_PROJECT_ID") as? String, !plistKey.isEmpty {
            return plistKey
        }

        #if DEBUG
        print("Config: GOOGLE_CLOUD_PROJECT_ID not configured in environment or Info.plist")
        #endif
        return ""
    }()

    // MARK: - Feature Flags
    
    /// Use CoreML models first, fallback to GCP if needed
    static let preferOnDeviceML = true
    
    /// Minimum confidence threshold for CoreML before falling back to GCP
    static let coreMLConfidenceThreshold = 0.75
    
    /// Enable debug logging for API calls (only in DEBUG builds)
    #if DEBUG
    static let debugAPILogging = true
    #else
    static let debugAPILogging = false
    #endif
    
}
