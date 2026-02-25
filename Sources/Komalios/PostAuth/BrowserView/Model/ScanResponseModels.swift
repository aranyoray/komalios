//
//  ScanResponseModels.swift
//  Komalios
//
//  Created on 18/01/26.
//

import Foundation

// MARK: - Scan Response Models

struct ScanResponse: Codable {
    let url: String
    let overallScore: Int
    let ageGroupScores: [String: AgeGroupScore]
    let contentAnalysis: ContentAnalysis
    let childSafetyAnalysis: ChildSafetyAnalysis
    let timestamp: String
    let analysisMethod: String? // "live" or "demo"
    let usedSearchFallback: Bool? 
    let performanceMetrics: PerformanceMetrics?
    let pythonDebug: PythonDebug?
}

struct PythonDebug: Codable {
    let status: String?
    let url: String?
}

struct AgeGroupScore: Codable {
    let score: Int
    let action: Action
    let reason: String
    let risks: [String]
}

enum Action: String, Codable {
    case block = "BLOCK"
    case gate = "GATE"
    case allow = "ALLOW"
}

struct ContentAnalysis: Codable {
    let textAnalysis: TextAnalysis
    let visualAnalysis: VisualAnalysis
    let multimediaAnalysis: MultimediaAnalysis?
    let metadata: Metadata?
}

struct TextAnalysis: Codable {
    let sentiment: String
    let keyTopics: [String]
    let languageScore: Int
    let entities: [String]?
    let unsafeKeywordsFound: [String]
    let safeKeywordsFound: [String]
}

struct VisualAnalysis: Codable {
    let detectedObjects: [String]
    let safetyScore: Int
    let concerns: [String]
    let labels: [String]?
}

struct MultimediaAnalysis: Codable {
    let videoDetected: Bool
    let audioDetected: Bool
    let mediaTypes: [String]
    let mediaSafetyScore: Int
    let mediaConcerns: [String]
}

struct Metadata: Codable {
    let title: String?
    let description: String?
    let keywords: [String]?
    let imageCount: Int
    let linkCount: Int
    let videoCount: Int
    let audioCount: Int
}

struct ChildSafetyAnalysis: Codable {
    let overallRisk: RiskLevel
    let riskCategories: [RiskCategory]
    let depthAnalysis: DepthAnalysis
}

enum RiskLevel: String, Codable {
    case safe
    case caution
    case unsafe
    case dangerous
}

struct RiskCategory: Codable {
    let category: String
    let severity: String
    let matchCount: Int
    let matchedKeywords: [String]
    let contextSnippets: [String]
}

struct DepthAnalysis: Codable {
    let titleSafe: Bool
    let metadataSafe: Bool
    let contentSafe: Bool
    let mediaSafe: Bool
}

struct PerformanceMetrics: Codable {
    let totalTimeMs: Int
    let steps: [PerformanceStep]
}

struct PerformanceStep: Codable {
    let name: String
    let durationMs: Int
    let details: String?
}

