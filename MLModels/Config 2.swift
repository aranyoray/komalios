//
//  Config.swift
//  Komalios
//
//  Centralized configuration for API keys and service URLs
//  ⚠️ SECURITY: Never commit real API keys to Git!
//

import Foundation

/// Central configuration for all API keys and service endpoints
enum Config {
    
    // MARK: - Google Cloud Platform
    
    /// Google Cloud API Key for Vision, NLP, and Video Intelligence APIs
    /// Get this from: https://console.cloud.google.com/apis/credentials
    static let googleCloudAPIKey: String = {
        // Try to load from environment first (for CI/CD or development)
        if let envKey = ProcessInfo.processInfo.environment["GOOGLE_CLOUD_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        
        // Otherwise, use hardcoded value (replace with your actual key)
        // ⚠️ WARNING: Replace this before production deployment!
        return "YOUR_GOOGLE_CLOUD_API_KEY_HERE"
    }()
    
    /// Google Custom Search API Key
    /// Get this from: https://console.cloud.google.com/apis/credentials
    static let googleCustomSearchAPIKey: String = {
        if let envKey = ProcessInfo.processInfo.environment["GOOGLE_CUSTOM_SEARCH_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        return "YOUR_GOOGLE_CUSTOM_SEARCH_API_KEY_HERE"
    }()
    
    /// Google Custom Search Engine ID
    /// Get this from: https://programmablesearchengine.google.com/
    static let googleCustomSearchEngineID: String = {
        if let envKey = ProcessInfo.processInfo.environment["GOOGLE_CUSTOM_SEARCH_ENGINE_ID"], !envKey.isEmpty {
            return envKey
        }
        return "YOUR_GOOGLE_CUSTOM_SEARCH_ENGINE_ID_HERE"
    }()
    
    // MARK: - Google Cloud Service URLs
    
    static let googleCloudVisionURL = "https://vision.googleapis.com/v1"
    static let googleCloudNaturalLanguageURL = "https://language.googleapis.com/v1"
    static let googleCloudVideoIntelligenceURL = "https://videointelligence.googleapis.com/v1"
    static let googleCustomSearchURL = "https://www.googleapis.com/customsearch/v1"
    
    // MARK: - Debug Settings
    
    #if DEBUG
    /// Enable detailed API logging in debug builds
    static let debugAPILogging = true
    #else
    /// Disable API logging in release builds
    static let debugAPILogging = false
    #endif
    
    // MARK: - Validation
    
    /// Check if all required API keys are configured
    static var isConfigured: Bool {
        return !googleCloudAPIKey.contains("YOUR_") &&
               !googleCustomSearchAPIKey.contains("YOUR_") &&
               !googleCustomSearchEngineID.contains("YOUR_")
    }
    
    /// Get configuration status report
    static var configurationStatus: String {
        var status = "🔐 API Configuration Status\n"
        status += "=========================\n\n"
        
        if googleCloudAPIKey.contains("YOUR_") {
            status += "❌ Google Cloud API Key: NOT SET\n"
        } else {
            status += "✅ Google Cloud API Key: Set (\(googleCloudAPIKey.prefix(10))...)\n"
        }
        
        if googleCustomSearchAPIKey.contains("YOUR_") {
            status += "❌ Custom Search API Key: NOT SET\n"
        } else {
            status += "✅ Custom Search API Key: Set (\(googleCustomSearchAPIKey.prefix(10))...)\n"
        }
        
        if googleCustomSearchEngineID.contains("YOUR_") {
            status += "❌ Custom Search Engine ID: NOT SET\n"
        } else {
            status += "✅ Custom Search Engine ID: Set (\(googleCustomSearchEngineID.prefix(10))...)\n"
        }
        
        status += "\n"
        
        if isConfigured {
            status += "✅ All API keys configured\n"
        } else {
            status += "⚠️  Some API keys need to be set\n"
            status += "\nTo configure:\n"
            status += "1. Get API keys from https://console.cloud.google.com/\n"
            status += "2. Replace 'YOUR_*' values in Config.swift\n"
            status += "3. OR set environment variables:\n"
            status += "   - GOOGLE_CLOUD_API_KEY\n"
            status += "   - GOOGLE_CUSTOM_SEARCH_API_KEY\n"
            status += "   - GOOGLE_CUSTOM_SEARCH_ENGINE_ID\n"
        }
        
        return status
    }
    
    /// Print configuration status to console
    static func printStatus() {
        print(configurationStatus)
    }
}

// MARK: - Security Notice

/*
 ⚠️ SECURITY BEST PRACTICES:
 
 1. Never commit real API keys to Git
 2. Add Config.swift to .gitignore if it contains real keys
 3. Use environment variables for production
 4. Consider using a secrets management service
 5. Rotate API keys regularly
 6. Set up API key restrictions in Google Cloud Console
 
 For production apps, consider:
 - Using a backend service to proxy API calls
 - Implementing rate limiting
 - Monitoring API usage and costs
 - Setting up billing alerts in Google Cloud
 
 API Key Setup:
 https://console.cloud.google.com/apis/credentials
 
 Custom Search Engine Setup:
 https://programmablesearchengine.google.com/
 */
