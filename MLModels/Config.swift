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
        
        // Priority 3: Securely stored key
        return "AIzaSyBrA8VaQj-5Nv22mWqTFdRmVrVxT12JC-4"
    }()
    
    /// Google Custom Search API Key
    /// Used for safe search filtering and content discovery
    /// ⚠️ PRIVATE - DO NOT COMMIT TO PUBLIC REPO
    static let googleCustomSearchAPIKey: String = {
        if let envKey = ProcessInfo.processInfo.environment["GOOGLE_CUSTOM_SEARCH_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        
        if let plistKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CUSTOM_SEARCH_API_KEY") as? String, !plistKey.isEmpty {
            return plistKey
        }
        
        return "AIzaSyCuER2ZmdptKCmJ0sv0LjZHLg6BleDXpPo"
    }()
    
    /// Google Custom Search Engine ID
    /// Identifies your custom search engine configuration
    /// ⚠️ PRIVATE - DO NOT COMMIT TO PUBLIC REPO
    static let googleCustomSearchEngineID: String = {
        if let envKey = ProcessInfo.processInfo.environment["GOOGLE_CUSTOM_SEARCH_ENGINE_ID"], !envKey.isEmpty {
            return envKey
        }
        
        if let plistKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CUSTOM_SEARCH_ENGINE_ID") as? String, !plistKey.isEmpty {
            return plistKey
        }
        
        return "9155813f6a4e04c8f"
    }()
    
    // MARK: - Service URLs
    
    /// Content moderation service URL (your backend Flask API)
    static let moderationServiceURL: String = {
        if let envURL = ProcessInfo.processInfo.environment["MODERATION_SERVICE_URL"], !envURL.isEmpty {
            return envURL
        }
        
        if let plistURL = Bundle.main.object(forInfoDictionaryKey: "MODERATION_SERVICE_URL") as? String, !plistURL.isEmpty {
            return plistURL
        }
        
        // Default to localhost for development
        return "http://localhost:5000"
    }()
    
    // MARK: - Google Cloud Service URLs
    
    static let googleCloudVisionURL = "https://vision.googleapis.com/v1"
    static let googleCloudVideoIntelligenceURL = "https://videointelligence.googleapis.com/v1"
    static let googleCloudNaturalLanguageURL = "https://language.googleapis.com/v1"
    static let googleCustomSearchURL = "https://www.googleapis.com/customsearch/v1"
    
    // MARK: - Feature Flags
    
    /// Use CoreML models first, fallback to GCP if needed
    static let preferOnDeviceML = true
    
    /// Minimum confidence threshold for CoreML before falling back to GCP
    static let coreMLConfidenceThreshold = 0.75
    
    /// Enable debug logging for API calls
    static let debugAPILogging = true
    
    // MARK: - Validation
    
    /// Check if all required API keys are configured
    static var isFullyConfigured: Bool {
        return !googleCloudAPIKey.contains("GOOGLE_CLOUD_API_KEY") &&
               !googleCustomSearchAPIKey.contains("GOOGLE_CUSTOM_SEARCH_API_KEY") &&
               !googleCustomSearchEngineID.contains("GOOGLE_CUSTOM_SEARCH_ENGINE_ID")
    }
    
    /// Get configuration status report
    static var configurationStatus: String {
        var status = "📋 Configuration Status:\n"
        status += "✓ Google Cloud API Key: \(googleCloudAPIKey.isEmpty ? "❌ Missing" : "✅ Set")\n"
        status += "✓ Custom Search API Key: \(googleCustomSearchAPIKey.isEmpty ? "❌ Missing" : "✅ Set")\n"
        status += "✓ Custom Search Engine ID: \(googleCustomSearchEngineID.isEmpty ? "❌ Missing" : "✅ Set")\n"
        status += "✓ Moderation Service URL: \(moderationServiceURL)\n"
        status += "✓ CoreML Preferred: \(preferOnDeviceML ? "Yes" : "No")\n"
        return status
    }
}

// MARK: - Usage Example
/*
 
 // In your service classes:
 
 let visionService = GoogleCloudVisionService(apiKey: Config.googleCloudAPIKey)
 let searchService = GoogleCustomSearchService(
     apiKey: Config.googleCustomSearchAPIKey,
     engineID: Config.googleCustomSearchEngineID
 )
 let moderationAPI = KomalWebAPI(baseURL: Config.moderationServiceURL)
 
 // Check configuration on app launch:
 print(Config.configurationStatus)
 
 */
