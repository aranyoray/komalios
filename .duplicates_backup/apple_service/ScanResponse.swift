//
//  ScanResponse.swift
//  Komalios
//
//  Data models for content scanning API responses
//

import Foundation

// MARK: - Main Scan Response

struct ScanResponse: Codable {
    let url: String
    let contentSummary: ContentSummary
    let childSafetyAnalysis: ChildSafetyAnalysis
    let ageAppropriatenessAnalysis: AgeAppropriatenessAnalysis
    let scrapedContent: ScrapedContent?
    let timestamp: String
}

// MARK: - Content Summary

struct ContentSummary: Codable {
    let title: String?
    let description: String?
    let contentType: String
    let language: String?
}

// MARK: - Child Safety Analysis

struct ChildSafetyAnalysis: Codable {
    let overallRisk: RiskLevel
    let riskCategories: [RiskCategory]
    let explanation: String
}

enum RiskLevel: String, Codable {
    case safe = "safe"
    case caution = "caution"
    case warning = "warning"
    case dangerous = "dangerous"
}

struct RiskCategory: Codable {
    let category: String
    let severity: String
    let confidence: Double
    let evidence: [String]?
}

// MARK: - Age Appropriateness

struct AgeAppropriatenessAnalysis: Codable {
    let minimumAge: Int
    let recommendedAge: Int
    let reasoning: String
    let ageBasedRecommendations: [String: AgeRecommendation]
}

struct AgeRecommendation: Codable {
    let appropriate: Bool
    let concerns: [String]?
    let supervisionLevel: String?
}

// MARK: - Scraped Content

struct ScrapedContent: Codable {
    let text: String?
    let images: [ImageAnalysis]?
    let videos: [VideoAnalysis]?
}

struct ImageAnalysis: Codable {
    let url: String
    let altText: String?
    let safetyScore: Double?
    let categories: [String]?
}

struct VideoAnalysis: Codable {
    let url: String
    let title: String?
    let safetyScore: Double?
    let categories: [String]?
}

// MARK: - Helper Extensions

extension ScanResponse {
    var isBlocked: Bool {
        return childSafetyAnalysis.overallRisk == .dangerous
    }
    
    var requiresWarning: Bool {
        return childSafetyAnalysis.overallRisk == .warning
    }
    
    var isSafe: Bool {
        return childSafetyAnalysis.overallRisk == .safe
    }
}
