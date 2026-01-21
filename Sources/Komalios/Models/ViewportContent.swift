//
//  ViewportContent.swift
//  Komalios
//
//  Digital Guardian Enhancement - Tracks what content is visible on screen
//

import Foundation

/// Type of content element visible in viewport
enum VisibleContentType: String, Codable, CaseIterable {
    case heading = "heading"           // h1, h2, h3, etc.
    case paragraph = "paragraph"       // p, article text
    case image = "image"               // img elements
    case video = "video"               // video, iframe (youtube, etc)
    case link = "link"                 // a elements
    case button = "button"             // button, input[type=button]
    case form = "form"                 // form, input fields
    case advertisement = "ad"          // detected ad elements
    case socialEmbed = "social"        // embedded social media
    case comment = "comment"           // comment sections
    case unknown = "unknown"
    
    var icon: String {
        switch self {
        case .heading: return "text.alignleft"
        case .paragraph: return "doc.text"
        case .image: return "photo"
        case .video: return "play.rectangle"
        case .link: return "link"
        case .button: return "hand.tap"
        case .form: return "rectangle.and.pencil.and.ellipsis"
        case .advertisement: return "megaphone"
        case .socialEmbed: return "bubble.left.and.bubble.right"
        case .comment: return "text.bubble"
        case .unknown: return "questionmark.square"
        }
    }
    
    var displayName: String {
        switch self {
        case .heading: return "Heading"
        case .paragraph: return "Text"
        case .image: return "Image"
        case .video: return "Video"
        case .link: return "Link"
        case .button: return "Button"
        case .form: return "Form"
        case .advertisement: return "Advertisement"
        case .socialEmbed: return "Social Media"
        case .comment: return "Comment"
        case .unknown: return "Other"
        }
    }
}

/// A single piece of content visible in the viewport
struct VisibleContent: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let contentType: VisibleContentType
    let text: String?                    // Text content (truncated for privacy)
    let elementTag: String               // HTML tag (h1, p, img, etc)
    let viewportPosition: ViewportPosition // Where on screen
    var timeInViewSeconds: TimeInterval  // How long visible
    let isInteractive: Bool              // Can be clicked/tapped
    let hasMedia: Bool                   // Contains image/video
    let wordCount: Int                   // Number of words
    let detectedKeywords: [String]?      // Flagged keywords found
    let riskLevel: ContentRiskLevel      // Assessed risk
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        contentType: VisibleContentType,
        text: String?,
        elementTag: String,
        viewportPosition: ViewportPosition = .middle,
        timeInViewSeconds: TimeInterval = 0,
        isInteractive: Bool = false,
        hasMedia: Bool = false,
        detectedKeywords: [String]? = nil,
        riskLevel: ContentRiskLevel = .safe
    ) {
        self.id = id
        self.timestamp = timestamp
        self.contentType = contentType
        self.text = text
        self.elementTag = elementTag
        self.viewportPosition = viewportPosition
        self.timeInViewSeconds = timeInViewSeconds
        self.isInteractive = isInteractive
        self.hasMedia = hasMedia
        self.wordCount = text?.split(separator: " ").count ?? 0
        self.detectedKeywords = detectedKeywords
        self.riskLevel = riskLevel
    }
}

/// Position in the viewport
enum ViewportPosition: String, Codable {
    case top = "top"
    case middle = "middle"
    case bottom = "bottom"
    case fullScreen = "fullscreen"
}

/// Risk level for content
enum ContentRiskLevel: String, Codable, CaseIterable {
    case safe = "safe"
    case low = "low"
    case medium = "medium"
    case high = "high"
    case blocked = "blocked"
    
    var color: String {
        switch self {
        case .safe: return "green"
        case .low: return "blue"
        case .medium: return "orange"
        case .high: return "red"
        case .blocked: return "black"
        }
    }
    
    var displayName: String {
        switch self {
        case .safe: return "Safe"
        case .low: return "Mild"
        case .medium: return "Caution"
        case .high: return "Concerning"
        case .blocked: return "Blocked"
        }
    }
    
    /// Severity level for comparison (higher = more severe)
    var severity: Int {
        switch self {
        case .safe: return 0
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .blocked: return 4
        }
    }
}

/// A snapshot of what's visible on screen at a point in time
struct ViewportSnapshot: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let pageURL: URL
    let pageDomain: String
    let pageTitle: String?
    let scrollPosition: Int              // Scroll position in pixels
    let scrollDepthPercent: Int          // 0-100%
    let visibleContent: [VisibleContent] // What's on screen
    let primaryContent: String?          // Main visible text (summary)
    let visibleHeadings: [String]        // Headings in view
    let visibleImageCount: Int
    let visibleVideoCount: Int
    let hasVisibleAds: Bool
    let overallRiskLevel: ContentRiskLevel
    let flaggedKeywords: [String]        // Concerning words detected
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        pageURL: URL,
        pageTitle: String? = nil,
        scrollPosition: Int = 0,
        scrollDepthPercent: Int = 0,
        visibleContent: [VisibleContent] = [],
        primaryContent: String? = nil,
        visibleHeadings: [String] = [],
        visibleImageCount: Int = 0,
        visibleVideoCount: Int = 0,
        hasVisibleAds: Bool = false,
        flaggedKeywords: [String] = []
    ) {
        self.id = id
        self.timestamp = timestamp
        self.pageURL = pageURL
        self.pageDomain = pageURL.host ?? "unknown"
        self.pageTitle = pageTitle
        self.scrollPosition = scrollPosition
        self.scrollDepthPercent = scrollDepthPercent
        self.visibleContent = visibleContent
        self.primaryContent = primaryContent
        self.visibleHeadings = visibleHeadings
        self.visibleImageCount = visibleImageCount
        self.visibleVideoCount = visibleVideoCount
        self.hasVisibleAds = hasVisibleAds
        self.flaggedKeywords = flaggedKeywords
        
        // Calculate overall risk from content
        if !flaggedKeywords.isEmpty {
            self.overallRiskLevel = .medium
        } else if visibleContent.contains(where: { $0.riskLevel == .high }) {
            self.overallRiskLevel = .high
        } else if visibleContent.contains(where: { $0.riskLevel == .medium }) {
            self.overallRiskLevel = .medium
        } else {
            self.overallRiskLevel = .safe
        }
    }
}

/// Aggregated content viewing statistics for a page
struct PageContentSummary: Codable, Identifiable {
    let id: UUID
    let pageURL: URL
    let pageDomain: String
    let pageTitle: String?
    let visitTimestamp: Date
    var totalViewTime: TimeInterval
    
    // Content type breakdown
    var textContentViewed: Int           // Paragraphs/text blocks seen
    var headingsViewed: [String]         // All headings seen
    var imagesViewed: Int
    var videosViewed: Int
    var videoWatchTime: TimeInterval     // Time videos were in viewport
    var adsViewed: Int
    var linksViewed: Int
    var formsViewed: Int
    
    // Reading metrics
    var estimatedWordsRead: Int          // Based on viewport time
    var avgReadingTimePerSection: TimeInterval
    var scrollThroughRate: Double        // % of page scrolled through quickly
    
    // Risk assessment
    var flaggedContent: [String]         // Concerning content found
    var riskLevel: ContentRiskLevel
    var contentSnapshots: [ViewportSnapshot]
    
    init(
        pageURL: URL,
        pageTitle: String? = nil,
        visitTimestamp: Date = Date()
    ) {
        self.id = UUID()
        self.pageURL = pageURL
        self.pageDomain = pageURL.host ?? "unknown"
        self.pageTitle = pageTitle
        self.visitTimestamp = visitTimestamp
        self.totalViewTime = 0
        self.textContentViewed = 0
        self.headingsViewed = []
        self.imagesViewed = 0
        self.videosViewed = 0
        self.videoWatchTime = 0
        self.adsViewed = 0
        self.linksViewed = 0
        self.formsViewed = 0
        self.estimatedWordsRead = 0
        self.avgReadingTimePerSection = 0
        self.scrollThroughRate = 0
        self.flaggedContent = []
        self.riskLevel = .safe
        self.contentSnapshots = []
    }
    
    /// Add a viewport snapshot
    mutating func addSnapshot(_ snapshot: ViewportSnapshot) {
        contentSnapshots.append(snapshot)
        
        // Update counts
        for content in snapshot.visibleContent {
            switch content.contentType {
            case .paragraph:
                textContentViewed += 1
                estimatedWordsRead += content.wordCount
            case .heading:
                if let text = content.text, !headingsViewed.contains(text) {
                    headingsViewed.append(text)
                }
            case .image:
                imagesViewed += 1
            case .video:
                videosViewed += 1
            case .advertisement:
                adsViewed += 1
            case .link:
                linksViewed += 1
            case .form:
                formsViewed += 1
            default:
                break
            }
        }
        
        // Update flagged content
        flaggedContent.append(contentsOf: snapshot.flaggedKeywords)
        flaggedContent = Array(Set(flaggedContent)) // Remove duplicates
        
        // Update risk level (use severity comparison)
        if snapshot.overallRiskLevel.severity > riskLevel.severity {
            riskLevel = snapshot.overallRiskLevel
        }
    }
    
    /// Finalize summary when leaving page
    mutating func finalize(totalTime: TimeInterval, scrollThroughRate: Double) {
        self.totalViewTime = totalTime
        self.scrollThroughRate = scrollThroughRate
        
        if contentSnapshots.count > 0 {
            avgReadingTimePerSection = totalTime / Double(contentSnapshots.count)
        }
    }
}

// MARK: - Aggregation Helpers

extension Array where Element == ViewportSnapshot {
    
    /// All unique headings seen
    var allHeadings: [String] {
        let allHeadingsList = self.flatMap { $0.visibleHeadings }
        return Array<String>(Set<String>(allHeadingsList))
    }
    
    /// Total flagged keywords
    var allFlaggedKeywords: [String] {
        let allKeywords = self.flatMap { $0.flaggedKeywords }
        return Array<String>(Set<String>(allKeywords))
    }
    
    /// Maximum risk level encountered
    var maxRiskLevel: ContentRiskLevel {
        let levels = self.map { $0.overallRiskLevel }
        if levels.contains(.high) { return .high }
        if levels.contains(.medium) { return .medium }
        if levels.contains(.low) { return .low }
        return .safe
    }
    
    /// Total images seen
    var totalImagesViewed: Int {
        self.reduce(0) { $0 + $1.visibleImageCount }
    }
    
    /// Total videos seen
    var totalVideosViewed: Int {
        self.reduce(0) { $0 + $1.visibleVideoCount }
    }
}

extension Array where Element == PageContentSummary {
    
    /// Total estimated words read
    var totalWordsRead: Int {
        self.reduce(0) { $0 + $1.estimatedWordsRead }
    }
    
    /// Total videos watched
    var totalVideosWatched: Int {
        self.reduce(0) { $0 + $1.videosViewed }
    }
    
    /// All flagged content across pages
    var allFlaggedContent: [String] {
        let allContent = self.flatMap { $0.flaggedContent }
        return Array<String>(Set<String>(allContent))
    }
    
    /// Pages with concerning content
    func getPagesWithConcerns() -> [PageContentSummary] {
        return self.filter { $0.riskLevel == .medium || $0.riskLevel == .high }
    }
}
