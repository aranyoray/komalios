//
//  UnifiedDecisionModels.swift
//  Komalios
//
//  Unified decision model matching the specification
//

import Foundation

// MARK: - Unified Decision Response

struct UnifiedDecisionResponse: Codable {
    let url: String
    let overallSafetyScore: Double
    let languageSafetyScore: Double
    let visualSafetyScore: Double
    let audioSafetyScore: Double
    let ageActions: [String: AgeAction]
    let majorCategories: [MajorCategory]
    let subcategories: [Subcategory]
    let contextType: String?
    let topicTags: [String]
    let flags: SafetyFlags
    let decisionSource: DecisionSource
    let timestamp: String
    let historyCategory: String? // For parent viewing later
    let historySubcategory: String? // For grouping similar URLs
    let revealingLevel: Int? // 0-5 revealing level from body region analysis (nil if not applicable)
}

struct AgeAction: Codable {
    let action: Action
    let score: Double
    let reason: String?
    let risks: [String]?
}

struct MajorCategory: Codable {
    let name: String
    let probability: Double
    let source: DecisionSourceType?
}

struct Subcategory: Codable {
    let name: String
    let source: DecisionSourceType
    let probability: Double
    let majorCategory: String?
}

enum DecisionSourceType: String, Codable {
    case nlp = "nlp"
    case vision = "vision"
    case audio = "audio"
    case links = "links"
    case cloud = "cloud"
    case custom = "custom" // For parent-defined rules
}

struct SafetyFlags: Codable {
    let bodyAnxiety: Bool
    let selfHarm: Bool
    let fraudOrScam: Bool
    let extremism: Bool
    let lgbtqFlagPresent: Bool?
    let gambling: Bool
    let parasocial: Bool
    let substanceAbuse: Bool
}

struct DecisionSource: Codable {
    let nlp: SourceInfo
    let vision: SourceInfo
    let audio: SourceInfo
    let links: SourceInfo
    let cloud: SourceInfo
}

struct SourceInfo: Codable {
    let used: Bool
    let confidence: Double
}

// MARK: - Content Analysis Input

struct ContentAnalysisInput: Codable {
    let url: String
    let htmlText: HTMLText?
    let media: MediaContent?
    let structuralMetadata: StructuralMetadata?
    let extraMetadata: ExtraMetadata?
}

struct HTMLText: Codable {
    let title: String?
    let metaDescription: String?
    let headings: [String]
    let bodyText: String?
    let altText: [String]
    let comments: [String]?
}

struct MediaContent: Codable {
    let images: [ImageInfo]
    let videos: [VideoInfo]
    let audio: [AudioInfo]
}

struct ImageInfo: Codable {
    let url: String?
    let type: String // "inline", "thumbnail", "avatar", "ad", "sponsor_logo"
    let size: String? // "large", "medium", "small"
    let position: String? // "above_fold", "below_fold"
}

struct VideoInfo: Codable {
    let url: String?
    let thumbnailUrl: String?
    let duration: Int? // seconds
    let keyframes: [String]? // URLs to keyframe images
}

struct AudioInfo: Codable {
    let url: String?
    let duration: Int? // seconds
    let hasSpeech: Bool
    let hasMusic: Bool
}

struct StructuralMetadata: Codable {
    let pageType: PageType
    let platform: String?
}

enum PageType: String, Codable {
    case article
    case searchResults
    case productPage
    case socialFeedItem
    case commentsThread
    case liveStream
    case shortFormVideo
    case videoPlayer
    case generic
}

struct ExtraMetadata: Codable {
    let creator: CreatorInfo?
    let sponsors: [SponsorInfo]
    let links: [LinkInfo]
}

struct CreatorInfo: Codable {
    let name: String?
    let handle: String?
    let description: String?
    let channelId: String?
}

struct SponsorInfo: Codable {
    let name: String
    let url: String?
    let label: String? // "sponsor", "ad", "partner"
    let context: String? // Surrounding text
}

struct LinkInfo: Codable {
    let url: String
    let domain: String
    let anchorText: String?
    let context: String? // Surrounding text
    let isShortened: Bool // bit.ly, etc.
    let linkType: String? // "sponsor", "affiliate", "internal", "external"
}

// MARK: - Age Bands

enum AgeBand: String, Codable, CaseIterable {
    case below10 = "below10"
    case age10_13 = "10_13"
    case age13_16 = "13_16"
    case age16_18 = "16_18"
    
    var displayName: String {
        switch self {
        case .below10: return "Below 10"
        case .age10_13: return "10-13"
        case .age13_16: return "13-16"
        case .age16_18: return "16-18"
        }
    }
}

// MARK: - Major Categories (from specification)

enum MajorCategoryType: String, Codable, CaseIterable {
    case explicitBodyContent = "Explicit Body Content"
    case violence = "Violence"
    case substances = "Substances"
    case financialFraud = "Financial Fraud"
    case parasocialManipulation = "Parasocial / Manipulative"
    case gambling = "Gambling"
    case selfHarm = "Self-Harm"
    case extremism = "Extremism"
    case bodyAnxiety = "Body Anxiety"
    case platformRisks = "Platform Risks"
    case unknown = "Unknown"
}

