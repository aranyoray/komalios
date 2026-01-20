//
//  ImageFilterEvent.swift
//  Komalios
//
//  Digital Guardian Enhancement - Tracks image filtering events
//

import Foundation

/// Action taken on a filtered image
enum ImageFilterAction: String, Codable, CaseIterable {
    case replaced   // Replaced with Komal logo
    case blurred    // Blurred (future option)
    case allowed    // Passed filter check
    case skipped    // Skipped (too small, icon, etc.)
    case failed     // Analysis failed
    
    var displayName: String {
        switch self {
        case .replaced: return "Protected"
        case .blurred: return "Blurred"
        case .allowed: return "Safe"
        case .skipped: return "Skipped"
        case .failed: return "Error"
        }
    }
    
    var icon: String {
        switch self {
        case .replaced: return "shield.checkered"
        case .blurred: return "eye.slash.fill"
        case .allowed: return "checkmark.circle.fill"
        case .skipped: return "arrow.right.circle"
        case .failed: return "exclamationmark.triangle"
        }
    }
}

/// Category detected by the image classifier
enum ImageContentCategory: String, Codable, CaseIterable {
    case explicit = "explicit"           // Adult/NSFW content
    case suggestive = "suggestive"       // Suggestive but not explicit
    case violence = "violence"           // Violent imagery
    case gore = "gore"                   // Graphic gore
    case drugs = "drugs"                 // Drug-related imagery
    case weapons = "weapons"             // Weapons/firearms
    case safe = "safe"                   // Safe content
    case neutral = "neutral"             // Neutral/unknown
    
    var displayName: String {
        switch self {
        case .explicit: return "Explicit Content"
        case .suggestive: return "Suggestive Content"
        case .violence: return "Violence"
        case .gore: return "Graphic Content"
        case .drugs: return "Drug Content"
        case .weapons: return "Weapons"
        case .safe: return "Safe"
        case .neutral: return "Neutral"
        }
    }
    
    var icon: String {
        switch self {
        case .explicit: return "eye.slash.fill"
        case .suggestive: return "exclamationmark.triangle.fill"
        case .violence: return "bolt.fill"
        case .gore: return "drop.fill"
        case .drugs: return "pills.fill"
        case .weapons: return "shield.slash.fill"
        case .safe: return "checkmark.shield.fill"
        case .neutral: return "questionmark.circle"
        }
    }
    
    /// Color for UI representation
    var colorName: String {
        switch self {
        case .explicit, .gore: return "red"
        case .suggestive: return "orange"
        case .violence, .weapons: return "red"
        case .drugs: return "purple"
        case .safe: return "green"
        case .neutral: return "gray"
        }
    }
    
    /// Maps to ContentFilterPreferences to determine action
    func shouldFilter(preferences: ContentFilterPreferences) -> FilterAction {
        switch self {
        case .explicit:
            return preferences.explicitSexual
        case .suggestive:
            return preferences.matureContent
        case .violence:
            return preferences.graphicViolence
        case .gore:
            return preferences.graphicViolence
        case .drugs:
            return preferences.alcoholContent
        case .weapons:
            return preferences.gunsWeapons
        case .safe, .neutral:
            return .allow
        }
    }
}

/// Records a single image filtering event
struct ImageFilterEvent: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let pageURL: URL
    let pageDomain: String
    let imageURL: URL
    let detectedCategory: ImageContentCategory
    let confidenceScore: Float          // ML confidence 0.0-1.0
    let action: ImageFilterAction
    let matchedPreference: String?      // Which ContentFilterPreference triggered this
    let imageWidth: Int?
    let imageHeight: Int?
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        pageURL: URL,
        imageURL: URL,
        detectedCategory: ImageContentCategory,
        confidenceScore: Float,
        action: ImageFilterAction,
        matchedPreference: String? = nil,
        imageWidth: Int? = nil,
        imageHeight: Int? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.pageURL = pageURL
        self.pageDomain = pageURL.host ?? "unknown"
        self.imageURL = imageURL
        self.detectedCategory = detectedCategory
        self.confidenceScore = confidenceScore
        self.action = action
        self.matchedPreference = matchedPreference
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
    }
    
    /// Whether this event represents a filtered (protected) image
    var wasFiltered: Bool {
        action == .replaced || action == .blurred
    }
    
    /// Confidence as percentage string
    var confidencePercentage: String {
        "\(Int(confidenceScore * 100))%"
    }
}

// MARK: - Aggregation Helpers

extension Array where Element == ImageFilterEvent {
    
    /// Total filtered images
    var filteredCount: Int {
        filter { $0.wasFiltered }.count
    }
    
    /// Total allowed images
    var allowedCount: Int {
        filter { $0.action == .allowed }.count
    }
    
    /// Count by category
    var countByCategory: [ImageContentCategory: Int] {
        Dictionary(grouping: self, by: { $0.detectedCategory })
            .mapValues { $0.count }
    }
    
    /// Count by action
    var countByAction: [ImageFilterAction: Int] {
        Dictionary(grouping: self, by: { $0.action })
            .mapValues { $0.count }
    }
    
    /// Filtered images by category
    var filteredByCategory: [String: Int] {
        let filtered = filter { $0.wasFiltered }
        return Dictionary(grouping: filtered, by: { $0.detectedCategory.rawValue })
            .mapValues { $0.count }
    }
    
    /// Count by domain
    var countByDomain: [String: Int] {
        Dictionary(grouping: self, by: { $0.pageDomain })
            .mapValues { $0.count }
    }
    
    /// Average confidence score for filtered images
    var averageFilteredConfidence: Float {
        let filtered = filter { $0.wasFiltered }
        guard !filtered.isEmpty else { return 0 }
        return filtered.reduce(0) { $0 + $1.confidenceScore } / Float(filtered.count)
    }
    
    /// Most common filtered category
    var mostFilteredCategory: ImageContentCategory? {
        let filtered = filter { $0.wasFiltered }
        return Dictionary(grouping: filtered, by: { $0.detectedCategory })
            .max(by: { $0.value.count < $1.value.count })?
            .key
    }
}

// MARK: - Engagement Insights Model

/// Aggregated engagement insights for reporting
struct EngagementInsights: Codable {
    let averageDwellTimeSeconds: TimeInterval
    let averageScrollDepthPercent: Int
    let totalImagesScanned: Int
    let totalImagesFiltered: Int
    let filteredByCategory: [String: Int]
    let mostEngagedDomains: [DomainEngagement]
    let navigationPatterns: NavigationPatterns
    let totalPageViews: Int
    let meaningfulEngagementRate: Double  // % of pages with meaningful engagement
    
    static var empty: EngagementInsights {
        EngagementInsights(
            averageDwellTimeSeconds: 0,
            averageScrollDepthPercent: 0,
            totalImagesScanned: 0,
            totalImagesFiltered: 0,
            filteredByCategory: [:],
            mostEngagedDomains: [],
            navigationPatterns: .empty,
            totalPageViews: 0,
            meaningfulEngagementRate: 0
        )
    }
}

/// Domain engagement data for charts
struct DomainEngagement: Codable, Identifiable {
    let id: UUID
    let domain: String
    let avgDwellTimeSeconds: TimeInterval
    let visitCount: Int
    let avgScrollDepth: Int
    let imagesFiltered: Int
    
    init(domain: String, avgDwellTimeSeconds: TimeInterval, visitCount: Int, avgScrollDepth: Int = 0, imagesFiltered: Int = 0) {
        self.id = UUID()
        self.domain = domain
        self.avgDwellTimeSeconds = avgDwellTimeSeconds
        self.visitCount = visitCount
        self.avgScrollDepth = avgScrollDepth
        self.imagesFiltered = imagesFiltered
    }
    
    var avgDwellTimeFormatted: String {
        let seconds = Int(avgDwellTimeSeconds)
        if seconds < 60 {
            return "\(seconds)s"
        }
        return "\(seconds / 60)m \(seconds % 60)s"
    }
}

/// Navigation behavior patterns
struct NavigationPatterns: Codable {
    let averageSessionDepth: Int           // How many pages deep on average
    let backNavigationRate: Double         // % of navigations that were "back"
    let forwardNavigationRate: Double      // % of navigations that were "forward"
    let rapidSwitchingCount: Int           // Sites visited < 10s (distraction indicator)
    let averageNavigationsPerSession: Double
    
    static var empty: NavigationPatterns {
        NavigationPatterns(
            averageSessionDepth: 0,
            backNavigationRate: 0,
            forwardNavigationRate: 0,
            rapidSwitchingCount: 0,
            averageNavigationsPerSession: 0
        )
    }
    
    /// Whether browsing shows distraction patterns
    var showsDistractionPattern: Bool {
        rapidSwitchingCount > 5 || backNavigationRate > 0.3
    }
}
