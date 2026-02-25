//
//  ContentAnalyzerService.swift
//  Komalios
//
//  Digital Guardian Enhancement - Analyzes viewport content for concerning material
//

import Foundation
import Combine

/// Service for analyzing text content and detecting concerning material
final class ContentAnalyzerService: ObservableObject {
    static let shared = ContentAnalyzerService()
    
    // MARK: - Published Properties
    @Published private(set) var currentPageSummary: PageContentSummary?
    @Published private(set) var recentSnapshots: [ViewportSnapshot] = []
    @Published private(set) var flaggedContentCount: Int = 0
    @Published private(set) var totalContentAnalyzed: Int = 0
    
    // MARK: - Private Properties
    private var allPageSummaries: [PageContentSummary] = []
    private let analysisQueue = DispatchQueue(label: "com.komalios.contentanalyzer", qos: .userInitiated)
    /// Serial queue that serializes all mutations to `currentPageSummary`, preventing
    /// races between the analysisQueue callback (which posts back to main) and direct
    /// call sites such as startPageTracking / finalizeCurrentPage.
    private let summaryQueue = DispatchQueue(label: "com.komalios.contentanalyzer.summary", qos: .userInitiated)
    
    // Keyword categories for detection
    private let keywordCategories: [String: [String]] = [
        "violence": [
            "kill", "murder", "death", "blood", "gore", "violent", "attack", "weapon",
            "shoot", "stab", "fight", "assault", "torture", "abuse", "harm"
        ],
        "adult": [
            "xxx", "porn", "nude", "naked", "sex", "adult only", "nsfw", "18+",
            "explicit", "erotic", "sexy", "hentai", "onlyfans"
        ],
        "drugs": [
            "cocaine", "heroin", "meth", "drugs", "weed", "marijuana", "cannabis",
            "high", "stoned", "pills", "overdose", "dealer"
        ],
        "self_harm": [
            "suicide", "self-harm", "cutting", "kill myself", "end it all",
            "don't want to live", "hurt myself", "depression", "worthless"
        ],
        "gambling": [
            "bet now", "casino", "gambling", "poker", "slots", "jackpot",
            "win big", "odds", "wager", "betting"
        ],
        "scams": [
            "get rich quick", "make money fast", "crypto invest", "guaranteed returns",
            "free money", "no risk", "double your", "limited time offer", "act now"
        ],
        "hate": [
            "hate", "racist", "discrimination", "slur", "bigot"
        ],
        "cyberbullying": [
            "loser", "kill yourself", "nobody likes you", "ugly", "fat",
            "stupid", "worthless", "pathetic"
        ]
    ]
    
    // MARK: - Initialization
    
    private init() {
        loadSavedSummaries()
    }
    
    // MARK: - Public API
    
    /// Process a viewport snapshot from JavaScript
    func processViewportSnapshot(_ data: [String: Any], pageURL: URL) {
        analysisQueue.async { [weak self] in
            guard let self = self else { return }

            let snapshot = self.parseSnapshot(data, pageURL: pageURL)

            // Use summaryQueue → main to serialize with startPageTracking / finalizeCurrentPage
            self.summaryQueue.async { [weak self] in
                guard let self = self else { return }
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.recentSnapshots.insert(snapshot, at: 0)
                    if self.recentSnapshots.count > 50 {
                        self.recentSnapshots = Array(self.recentSnapshots.prefix(50))
                    }

                    self.totalContentAnalyzed += snapshot.visibleContent.count
                    self.flaggedContentCount += snapshot.flaggedKeywords.count

                    // Update current page summary
                    self.updatePageSummary(with: snapshot)
                }
            }
        }
    }

    /// Start tracking a new page
    func startPageTracking(url: URL, title: String?) {
        // Serialize through summaryQueue to prevent races with processViewportSnapshot callbacks
        summaryQueue.async { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                // Finalize previous page summary
                self.finalizeCurrentPageInternal()
                // Start new summary
                self.currentPageSummary = PageContentSummary(
                    pageURL: url,
                    pageTitle: title
                )
            }
        }
    }

    /// Finalize current page tracking
    func finalizeCurrentPage() {
        summaryQueue.async { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.finalizeCurrentPageInternal()
            }
        }
    }

    /// Internal (must be called on the main thread, within summaryQueue serialization)
    private func finalizeCurrentPageInternal() {
        guard var summary = currentPageSummary else { return }

        let scrollThroughRate = calculateScrollThroughRate()
        summary.finalize(
            totalTime: Date().timeIntervalSince(summary.visitTimestamp),
            scrollThroughRate: scrollThroughRate
        )

        // Save if has meaningful content
        if summary.contentSnapshots.count > 0 {
            allPageSummaries.insert(summary, at: 0)
            if allPageSummaries.count > 100 {
                allPageSummaries = Array(allPageSummaries.prefix(100))
            }
            saveSummaries()
        }
        
        currentPageSummary = nil
    }
    
    /// Analyze text for concerning content
    func analyzeText(_ text: String) -> (flaggedKeywords: [String], categories: [String], riskLevel: ContentRiskLevel) {
        let lowerText = text.lowercased()
        var flaggedKeywords: [String] = []
        var categories: Set<String> = []
        
        for (category, keywords) in keywordCategories {
            for keyword in keywords {
                if lowerText.contains(keyword.lowercased()) {
                    flaggedKeywords.append(keyword)
                    categories.insert(category)
                }
            }
        }
        
        // Determine risk level
        let riskLevel: ContentRiskLevel
        if categories.contains("adult") || categories.contains("self_harm") {
            riskLevel = .high
        } else if categories.contains("violence") || categories.contains("drugs") {
            riskLevel = flaggedKeywords.count > 2 ? .high : .medium
        } else if flaggedKeywords.count > 0 {
            riskLevel = .low
        } else {
            riskLevel = .safe
        }
        
        return (Array(Set(flaggedKeywords)), Array(categories), riskLevel)
    }
    
    /// Get all page summaries
    func getAllPageSummaries() -> [PageContentSummary] {
        return allPageSummaries
    }
    
    /// Get content insights
    func getContentInsights() -> ContentViewingInsights {
        var allSnapshots: [ViewportSnapshot] = []
        var allSummaries = allPageSummaries
        
        if let current = currentPageSummary {
            allSummaries.insert(current, at: 0)
        }
        
        for summary in allSummaries {
            allSnapshots.append(contentsOf: summary.contentSnapshots)
        }
        
        // Calculate metrics
        let totalWordsRead = allSummaries.reduce(0) { $0 + $1.estimatedWordsRead }
        let totalVideos = allSummaries.reduce(0) { $0 + $1.videosViewed }
        let totalImages = allSummaries.reduce(0) { $0 + $1.imagesViewed }
        let totalAds = allSummaries.reduce(0) { $0 + $1.adsViewed }
        let allHeadings = allSummaries.flatMap { $0.headingsViewed }
        let flaggedPages = allSummaries.filter { $0.riskLevel == .medium || $0.riskLevel == .high }
        
        // Content type breakdown
        var contentTypeBreakdown: [String: Int] = [:]
        for snapshot in allSnapshots {
            for content in snapshot.visibleContent {
                contentTypeBreakdown[content.contentType.rawValue, default: 0] += 1
            }
        }
        
        return ContentViewingInsights(
            totalPagesViewed: allSummaries.count,
            totalContentElements: totalContentAnalyzed,
            estimatedWordsRead: totalWordsRead,
            totalImagesViewed: totalImages,
            totalVideosViewed: totalVideos,
            totalAdsViewed: totalAds,
            uniqueHeadingsViewed: Array(Set(allHeadings)).count,
            flaggedContentCount: flaggedContentCount,
            pagesWithConcerns: flaggedPages.count,
            contentTypeBreakdown: contentTypeBreakdown,
            topFlaggedKeywords: getTopFlaggedKeywords(limit: 10),
            avgReadingTimePerPage: calculateAvgReadingTime()
        )
    }
    
    /// Clear all data
    func clearData() {
        recentSnapshots = []
        allPageSummaries = []
        currentPageSummary = nil
        flaggedContentCount = 0
        totalContentAnalyzed = 0
        clearSavedSummaries()
    }
    
    // MARK: - Private Methods
    
    private func parseSnapshot(_ data: [String: Any], pageURL: URL) -> ViewportSnapshot {
        let visibleContentData = data["visibleContent"] as? [[String: Any]] ?? []
        
        var visibleContent: [VisibleContent] = []
        for contentData in visibleContentData {
            let content = parseVisibleContent(contentData)
            visibleContent.append(content)
        }
        
        let visibleHeadings = data["visibleHeadings"] as? [String] ?? []
        let flaggedKeywords = data["flaggedKeywords"] as? [String] ?? []
        
        return ViewportSnapshot(
            pageURL: pageURL,
            pageTitle: data["pageTitle"] as? String,
            scrollPosition: data["scrollPosition"] as? Int ?? 0,
            scrollDepthPercent: data["scrollDepthPercent"] as? Int ?? 0,
            visibleContent: visibleContent,
            primaryContent: data["primaryContent"] as? String,
            visibleHeadings: visibleHeadings,
            visibleImageCount: data["visibleImageCount"] as? Int ?? 0,
            visibleVideoCount: data["visibleVideoCount"] as? Int ?? 0,
            hasVisibleAds: data["hasVisibleAds"] as? Bool ?? false,
            flaggedKeywords: flaggedKeywords
        )
    }
    
    private func parseVisibleContent(_ data: [String: Any]) -> VisibleContent {
        let typeString = data["contentType"] as? String ?? "unknown"
        let contentType = VisibleContentType(rawValue: typeString) ?? .unknown
        
        let riskString = data["riskLevel"] as? String ?? "safe"
        let riskLevel = ContentRiskLevel(rawValue: riskString) ?? .safe
        
        let positionString = data["viewportPosition"] as? String ?? "middle"
        let position = ViewportPosition(rawValue: positionString) ?? .middle
        
        return VisibleContent(
            contentType: contentType,
            text: data["text"] as? String,
            elementTag: data["elementTag"] as? String ?? "unknown",
            viewportPosition: position,
            timeInViewSeconds: data["timeInViewSeconds"] as? TimeInterval ?? 0,
            isInteractive: data["isInteractive"] as? Bool ?? false,
            hasMedia: data["hasMedia"] as? Bool ?? false,
            detectedKeywords: data["flaggedKeywords"] as? [String],
            riskLevel: riskLevel
        )
    }
    
    private func updatePageSummary(with snapshot: ViewportSnapshot) {
        currentPageSummary?.addSnapshot(snapshot)
    }
    
    private func calculateScrollThroughRate() -> Double {
        guard let summary = currentPageSummary, summary.contentSnapshots.count > 0 else {
            return 0
        }
        
        // Calculate percentage of snapshots with < 3 seconds viewing time
        let quickScrolls = summary.contentSnapshots.filter { snapshot in
            let avgTime = snapshot.visibleContent.reduce(0) { $0 + $1.timeInViewSeconds } /
                          max(Double(snapshot.visibleContent.count), 1)
            return avgTime < 3
        }.count
        
        return Double(quickScrolls) / Double(summary.contentSnapshots.count)
    }
    
    private func getTopFlaggedKeywords(limit: Int) -> [String] {
        var keywordCounts: [String: Int] = [:]
        
        for summary in allPageSummaries {
            for keyword in summary.flaggedContent {
                keywordCounts[keyword, default: 0] += 1
            }
        }
        
        return keywordCounts.sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0.key }
    }
    
    private func calculateAvgReadingTime() -> TimeInterval {
        guard !allPageSummaries.isEmpty else { return 0 }
        let total = allPageSummaries.reduce(0) { $0 + $1.totalViewTime }
        return total / Double(allPageSummaries.count)
    }
    
    // MARK: - Persistence
    
    private var summariesFileURL: URL {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("content_summaries.json")
        }
        return documentsPath.appendingPathComponent("content_summaries.json")
    }
    
    private func saveSummaries() {
        do {
            let data = try JSONEncoder().encode(allPageSummaries)
            try data.write(to: summariesFileURL)
        } catch {
            print("🔍 Error saving content summaries: \(error)")
        }
    }
    
    private func loadSavedSummaries() {
        guard FileManager.default.fileExists(atPath: summariesFileURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: summariesFileURL)
            allPageSummaries = try JSONDecoder().decode([PageContentSummary].self, from: data)
            print("🔍 Loaded \(allPageSummaries.count) content summaries")
        } catch {
            print("🔍 Error loading content summaries: \(error)")
        }
    }
    
    private func clearSavedSummaries() {
        try? FileManager.default.removeItem(at: summariesFileURL)
    }
}

// MARK: - Content Viewing Insights

struct ContentViewingInsights: Codable {
    let totalPagesViewed: Int
    let totalContentElements: Int
    let estimatedWordsRead: Int
    let totalImagesViewed: Int
    let totalVideosViewed: Int
    let totalAdsViewed: Int
    let uniqueHeadingsViewed: Int
    let flaggedContentCount: Int
    let pagesWithConcerns: Int
    let contentTypeBreakdown: [String: Int]
    let topFlaggedKeywords: [String]
    let avgReadingTimePerPage: TimeInterval
    
    static var empty: ContentViewingInsights {
        ContentViewingInsights(
            totalPagesViewed: 0,
            totalContentElements: 0,
            estimatedWordsRead: 0,
            totalImagesViewed: 0,
            totalVideosViewed: 0,
            totalAdsViewed: 0,
            uniqueHeadingsViewed: 0,
            flaggedContentCount: 0,
            pagesWithConcerns: 0,
            contentTypeBreakdown: [:],
            topFlaggedKeywords: [],
            avgReadingTimePerPage: 0
        )
    }
    
    var avgReadingTimeFormatted: String {
        let seconds = Int(avgReadingTimePerPage)
        if seconds < 60 {
            return "\(seconds)s"
        }
        return "\(seconds / 60)m \(seconds % 60)s"
    }
    
    var estimatedReadingLevel: String {
        // Rough estimate based on words read per minute
        let wordsPerMinute = avgReadingTimePerPage > 0 ?
            Double(estimatedWordsRead) / (avgReadingTimePerPage / 60) : 0
        
        if wordsPerMinute > 250 { return "Skimming" }
        if wordsPerMinute > 150 { return "Fast Reading" }
        if wordsPerMinute > 100 { return "Normal Reading" }
        return "Careful Reading"
    }
}
