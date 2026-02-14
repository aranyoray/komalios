//
//  GoogleCloudService.swift
//  Komalios
//
//  Backup cloud-based content analysis using Google Cloud APIs
//  Only used when CoreML confidence is low or model unavailable
//

import Foundation
import UIKit

/// Google Cloud Platform service for content moderation (backup to CoreML)
actor GoogleCloudService {
    
    private let apiKey: String
    private let session: URLSession
    
    init(apiKey: String = Config.googleCloudAPIKey) {
        self.apiKey = apiKey
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
    }
    
    // MARK: - Vision API (Image Safety)
    
    /// Analyze image for explicit content using Vision API SafeSearch
    func analyzeImageSafety(imageData: Data) async throws -> VisionSafeSearchResult {
        let endpoint = "\(Config.googleCloudVisionURL)/images:annotate?key=\(apiKey)"
        
        guard let url = URL(string: endpoint) else {
            throw GCPError.invalidURL
        }
        
        // Encode image as base64
        let base64Image = imageData.base64EncodedString()
        
        let requestBody: [String: Any] = [
            "requests": [
                [
                    "image": ["content": base64Image],
                    "features": [
                        ["type": "SAFE_SEARCH_DETECTION"]
                    ]
                ]
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GCPError.invalidResponse
        }
        
        if Config.debugAPILogging {
            print("📡 Vision API Response: \(httpResponse.statusCode)")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw GCPError.apiError(httpResponse.statusCode)
        }
        
        let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let responses = jsonResponse?["responses"] as? [[String: Any]],
              let firstResponse = responses.first,
              let safeSearch = firstResponse["safeSearchAnnotation"] as? [String: String] else {
            throw GCPError.decodingError
        }
        
        return VisionSafeSearchResult(
            adult: Likelihood(rawValue: safeSearch["adult"] ?? "UNKNOWN") ?? .unknown,
            violence: Likelihood(rawValue: safeSearch["violence"] ?? "UNKNOWN") ?? .unknown,
            racy: Likelihood(rawValue: safeSearch["racy"] ?? "UNKNOWN") ?? .unknown,
            medical: Likelihood(rawValue: safeSearch["medical"] ?? "UNKNOWN") ?? .unknown,
            spoof: Likelihood(rawValue: safeSearch["spoof"] ?? "UNKNOWN") ?? .unknown
        )
    }
    
    /// Analyze image from URL
    func analyzeImageSafety(imageURL: URL) async throws -> VisionSafeSearchResult {
        let (data, _) = try await URLSession.shared.data(from: imageURL)
        return try await analyzeImageSafety(imageData: data)
    }
    
    // MARK: - Natural Language API (Text Safety)
    
    /// Analyze text for harmful content using Natural Language API
    func analyzeTextSafety(text: String) async throws -> NaturalLanguageResult {
        let endpoint = "\(Config.googleCloudNaturalLanguageURL)/documents:analyzeSentiment?key=\(apiKey)"
        
        guard let url = URL(string: endpoint) else {
            throw GCPError.invalidURL
        }
        
        let requestBody: [String: Any] = [
            "document": [
                "type": "PLAIN_TEXT",
                "content": text
            ],
            "encodingType": "UTF8"
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GCPError.invalidResponse
        }
        
        if Config.debugAPILogging {
            print("📡 Natural Language API Response: \(httpResponse.statusCode)")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw GCPError.apiError(httpResponse.statusCode)
        }
        
        let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let sentiment = jsonResponse?["documentSentiment"] as? [String: Any],
              let score = sentiment["score"] as? Double,
              let magnitude = sentiment["magnitude"] as? Double else {
            throw GCPError.decodingError
        }
        
        return NaturalLanguageResult(
            sentimentScore: score,
            sentimentMagnitude: magnitude
        )
    }
    
    // MARK: - Custom Search API (URL Reputation)
    
    /// Check URL reputation using Custom Search API
    func checkURLReputation(domain: String) async throws -> URLReputationResult {
        let searchQuery = domain
        let endpoint = "\(Config.googleCustomSearchURL)?key=\(Config.googleCustomSearchAPIKey)&cx=\(Config.googleCustomSearchEngineID)&q=\(searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchQuery)"
        
        guard let url = URL(string: endpoint) else {
            throw GCPError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GCPError.invalidResponse
        }
        
        if Config.debugAPILogging {
            print("📡 Custom Search API Response: \(httpResponse.statusCode)")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw GCPError.apiError(httpResponse.statusCode)
        }
        
        let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let searchInfo = jsonResponse?["searchInformation"] as? [String: Any]
        let totalResults = searchInfo?["totalResults"] as? String
        
        return URLReputationResult(
            domain: domain,
            hasSearchResults: totalResults != "0",
            totalResults: Int(totalResults ?? "0") ?? 0
        )
    }
    
    // MARK: - Video Intelligence API (Video Safety)
    
    /// Analyze video for explicit content (returns operation ID for async processing)
    func analyzeVideoSafety(videoURL: URL) async throws -> String {
        let endpoint = "\(Config.googleCloudVideoIntelligenceURL)/videos:annotate?key=\(apiKey)"
        
        guard let url = URL(string: endpoint) else {
            throw GCPError.invalidURL
        }
        
        let requestBody: [String: Any] = [
            "inputUri": videoURL.absoluteString,
            "features": ["EXPLICIT_CONTENT_DETECTION"]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GCPError.invalidResponse
        }
        
        if Config.debugAPILogging {
            print("📡 Video Intelligence API Response: \(httpResponse.statusCode)")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw GCPError.apiError(httpResponse.statusCode)
        }
        
        let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let operationName = jsonResponse?["name"] as? String else {
            throw GCPError.decodingError
        }
        
        return operationName
    }
}

// MARK: - Result Models

struct VisionSafeSearchResult {
    let adult: Likelihood
    let violence: Likelihood
    let racy: Likelihood
    let medical: Likelihood
    let spoof: Likelihood
    
    /// Overall safety score (0.0 = safe, 1.0 = unsafe)
    var overallRisk: Double {
        let scores = [adult, violence, racy].map { $0.riskScore }
        return scores.reduce(0, +) / Double(scores.count)
    }
    
    /// Is content safe for children?
    var isSafeForChildren: Bool {
        return adult.riskScore < 0.3 && violence.riskScore < 0.3 && racy.riskScore < 0.3
    }
}

struct NaturalLanguageResult {
    let sentimentScore: Double      // -1.0 (negative) to 1.0 (positive)
    let sentimentMagnitude: Double   // 0.0 to infinity (emotional strength)
    
    /// Is text hostile or extremely negative?
    var isHostile: Bool {
        return sentimentScore < -0.5 && sentimentMagnitude > 2.0
    }
}

struct URLReputationResult {
    let domain: String
    let hasSearchResults: Bool
    let totalResults: Int
    
    /// Is domain suspicious (not indexed by Google)?
    var isSuspicious: Bool {
        return !hasSearchResults || totalResults < 10
    }
}

enum Likelihood: String {
    case unknown = "UNKNOWN"
    case veryUnlikely = "VERY_UNLIKELY"
    case unlikely = "UNLIKELY"
    case possible = "POSSIBLE"
    case likely = "LIKELY"
    case veryLikely = "VERY_LIKELY"
    
    /// Convert to numeric risk score (0.0 = safe, 1.0 = unsafe)
    var riskScore: Double {
        switch self {
        case .unknown: return 0.5
        case .veryUnlikely: return 0.0
        case .unlikely: return 0.2
        case .possible: return 0.5
        case .likely: return 0.8
        case .veryLikely: return 1.0
        }
    }
}

// MARK: - Error Handling

enum GCPError: LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(Int)
    case decodingError
    case quotaExceeded
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Google Cloud API URL"
        case .invalidResponse:
            return "Invalid response from Google Cloud"
        case .apiError(let code):
            switch code {
            case 401:
                return "Invalid API key - check Config.googleCloudAPIKey"
            case 403:
                return "API access forbidden - check API is enabled in GCP Console"
            case 429:
                return "API quota exceeded - try again later"
            default:
                return "Google Cloud API error: \(code)"
            }
        case .decodingError:
            return "Failed to decode Google Cloud API response"
        case .quotaExceeded:
            return "Google Cloud API quota exceeded"
        case .unauthorized:
            return "Unauthorized - check your API key"
        }
    }
}
