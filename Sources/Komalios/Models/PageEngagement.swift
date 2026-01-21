//
//  PageEngagement.swift
//  Komalios
//
//  Digital Guardian Enhancement - Tracks detailed page engagement metrics
//

import Foundation

/// Tracks real-time engagement metrics for a single page view
struct PageEngagement: Codable, Identifiable {
    let id: UUID
    let url: URL
    let domain: String
    let pageTitle: String?
    let startTime: Date
    var endTime: Date?
    
    // MARK: - Scroll Engagement
    var scrollDepthPercent: Int
    var scrollEventCount: Int
    var maxScrollPosition: Int  // Furthest scroll position reached
    
    // MARK: - Image Filtering
    var imagesScanned: Int
    var imagesFiltered: Int
    var filteredImageCategories: [String: Int]  // category -> count
    
    // MARK: - Navigation Context
    let referrerURL: URL?
    var exitURL: URL?
    let navigationDepth: Int
    let wasBackNavigation: Bool
    let wasForwardNavigation: Bool
    
    // MARK: - Computed Properties
    
    /// Time spent on this page in seconds
    var dwellTime: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
    }
    
    /// Formatted dwell time for display
    var dwellTimeFormatted: String {
        let seconds = Int(dwellTime)
        if seconds < 60 {
            return "\(seconds)s"
        }
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return "\(minutes)m \(remainingSeconds)s"
    }
    
    /// Whether user engaged meaningfully (scrolled or spent time)
    var hadMeaningfulEngagement: Bool {
        dwellTime >= 5 || scrollDepthPercent >= 25
    }
    
    /// Engagement score (0-100) combining dwell time and scroll depth
    var engagementScore: Int {
        let timeScore = min(Int(dwellTime / 3), 50)  // Max 50 points for 2.5+ minutes
        let scrollScore = scrollDepthPercent / 2     // Max 50 points for 100% scroll
        return min(timeScore + scrollScore, 100)
    }
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        url: URL,
        pageTitle: String? = nil,
        startTime: Date = Date(),
        referrerURL: URL? = nil,
        navigationDepth: Int = 1,
        wasBackNavigation: Bool = false,
        wasForwardNavigation: Bool = false
    ) {
        self.id = id
        self.url = url
        self.domain = url.host ?? "unknown"
        self.pageTitle = pageTitle
        self.startTime = startTime
        self.endTime = nil
        self.scrollDepthPercent = 0
        self.scrollEventCount = 0
        self.maxScrollPosition = 0
        self.imagesScanned = 0
        self.imagesFiltered = 0
        self.filteredImageCategories = [:]
        self.referrerURL = referrerURL
        self.exitURL = nil
        self.navigationDepth = navigationDepth
        self.wasBackNavigation = wasBackNavigation
        self.wasForwardNavigation = wasForwardNavigation
    }
    
    // MARK: - Mutation Methods
    
    /// Update scroll engagement data
    mutating func updateScroll(depthPercent: Int, eventCount: Int) {
        self.scrollDepthPercent = max(self.scrollDepthPercent, depthPercent)
        self.scrollEventCount = eventCount
        self.maxScrollPosition = max(self.maxScrollPosition, depthPercent)
    }
    
    /// Record a filtered image
    mutating func recordFilteredImage(category: String) {
        imagesFiltered += 1
        filteredImageCategories[category, default: 0] += 1
    }
    
    /// Record scanned images count
    mutating func recordScannedImages(count: Int) {
        imagesScanned += count
    }
    
    /// End the page engagement and set exit URL
    mutating func end(exitURL: URL? = nil) {
        self.endTime = Date()
        self.exitURL = exitURL
    }
    
    /// Convert to BrowsingEvent for persistence
    func toBrowsingEvent(eventType: BrowsingEventType = .pageLoad, category: String? = nil, action: FilterAction? = nil) -> BrowsingEvent {
        BrowsingEvent(
            id: id,
            timestamp: startTime,
            url: url,
            eventType: eventType,
            category: category,
            action: action,
            pageTitle: pageTitle,
            dwellTimeSeconds: dwellTime,
            scrollDepthPercent: scrollDepthPercent,
            scrollEvents: scrollEventCount,
            referrerURL: referrerURL,
            exitURL: exitURL,
            imagesScanned: imagesScanned,
            imagesFiltered: imagesFiltered,
            filteredCategories: filteredImageCategories.isEmpty ? nil : Array(filteredImageCategories.keys),
            wasBackNavigation: wasBackNavigation,
            wasForwardNavigation: wasForwardNavigation,
            navigationDepth: navigationDepth
        )
    }
}

// MARK: - Engagement Aggregation Helpers

extension Array where Element == PageEngagement {
    
    /// Average dwell time across all engagements
    var averageDwellTime: TimeInterval {
        guard !isEmpty else { return 0 }
        return reduce(0) { $0 + $1.dwellTime } / Double(count)
    }
    
    /// Average scroll depth percentage
    var averageScrollDepth: Int {
        guard !isEmpty else { return 0 }
        return reduce(0) { $0 + $1.scrollDepthPercent } / count
    }
    
    /// Total images filtered
    var totalImagesFiltered: Int {
        reduce(0) { $0 + $1.imagesFiltered }
    }
    
    /// Total images scanned
    var totalImagesScanned: Int {
        reduce(0) { $0 + $1.imagesScanned }
    }
    
    /// Engagements with meaningful interaction
    var meaningfulEngagements: [PageEngagement] {
        filter { $0.hadMeaningfulEngagement }
    }
    
    /// Count by domain
    var countByDomain: [String: Int] {
        Dictionary(grouping: self, by: { $0.domain })
            .mapValues { $0.count }
    }
    
    /// Average dwell time by domain
    var averageDwellTimeByDomain: [String: TimeInterval] {
        Dictionary(grouping: self, by: { $0.domain })
            .mapValues { engagements in
                engagements.reduce(0) { $0 + $1.dwellTime } / Double(engagements.count)
            }
    }
    
    /// Rapid switching count (pages visited for less than 10 seconds)
    var rapidSwitchingCount: Int {
        filter { $0.dwellTime < 10 && $0.endTime != nil }.count
    }
}
