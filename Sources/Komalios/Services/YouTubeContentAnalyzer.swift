#if os(iOS)
import Foundation
import os.log

/// Analyzes YouTube video metadata + comments to determine if a video is safe.
/// Mirrors the same content analysis logic used for Google search filtering.
@MainActor
final class YouTubeContentAnalyzer {
    static let shared = YouTubeContentAnalyzer()

    private let log = Logger(subsystem: "com.komalkids.komal", category: "YouTubeAnalyzer")
    private let session: URLSession
    private var analysisCache: [String: VideoDecision] = [:]
    private var cacheOrder: [String] = []
    private let maxCacheSize = 200

    struct VideoMetadata {
        let videoId: String
        let title: String
        let description: String
        let channelName: String
        let thumbnailUrl: String
    }

    enum VideoDecision {
        case allow
        case block(reason: String, category: String)
    }

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8.0
        config.timeoutIntervalForResource = 15.0
        self.session = URLSession(configuration: config)
    }

    /// Analyze a YouTube video for child safety.
    /// Returns .allow or .block with reason.
    func analyzeVideo(
        _ metadata: VideoMetadata,
        ageGroup: AgeGroup,
        parentSettings: ParentSettings,
        filterPreferences: ContentFilterPreferences
    ) async -> VideoDecision {
        // Only check cache for blocks — allowed videos are always re-analyzed
        let cacheKey = "\(metadata.videoId)_\(ageGroup.rawValue)"
        if let cached = analysisCache[cacheKey], case .block = cached {
            return cached
        }

        log.info("Analyzing YouTube video: \(metadata.videoId) - \(metadata.title)")

        // Step 1: Keyword check on title + description + channel
        let textToCheck = "\(metadata.title) \(metadata.description) \(metadata.channelName)"
        if let flagged = BrowserState.checkForInappropriateContent(textToCheck, isSearchQuery: false) {
            log.info("Video \(metadata.videoId) blocked by keyword: \(flagged)")
            let decision = VideoDecision.block(reason: "Contains inappropriate content: \(flagged)", category: "Content Filter")
            cacheDecision(decision, forKey: cacheKey)
            return decision
        }

        // Step 2: Check parent custom blocked keywords
        let lowerText = textToCheck.lowercased()
        for keyword in parentSettings.blockedKeywords {
            if lowerText.contains(keyword.lowercased()) {
                log.info("Video \(metadata.videoId) blocked by parent keyword: \(keyword)")
                let decision = VideoDecision.block(reason: "Blocked by parent settings", category: "Parent Rule")
                cacheDecision(decision, forKey: cacheKey)
                return decision
            }
        }

        // Step 3: Fetch top comments via YouTube Data API
        let comments = await fetchComments(videoId: metadata.videoId, maxResults: 70)

        // Step 4: Check comments for inappropriate content
        if !comments.isEmpty {
            let commentText = comments.joined(separator: " ")
            if let flagged = BrowserState.checkForInappropriateContent(commentText, isSearchQuery: false) {
                log.info("Video \(metadata.videoId) blocked by comment keyword: \(flagged)")
                let decision = VideoDecision.block(reason: "Comments contain inappropriate content", category: "Content Filter")
                cacheDecision(decision, forKey: cacheKey)
                return decision
            }
        }

        // Step 5: Run full NLP analysis on combined text
        let allText = ([metadata.title, metadata.description] + comments)
            .joined(separator: "\n")
        let nlpDecision = await analyzeTextWithNLP(
            text: allText,
            url: "https://www.youtube.com/watch?v=\(metadata.videoId)",
            ageGroup: ageGroup,
            parentSettings: parentSettings,
            filterPreferences: filterPreferences
        )
        if case .block = nlpDecision {
            cacheDecision(nlpDecision, forKey: cacheKey)
            return nlpDecision
        }

        // Step 6: Analyze thumbnail image
        let thumbnailDecision = await analyzeThumbnail(
            url: metadata.thumbnailUrl,
            filterPreferences: filterPreferences
        )
        if case .block = thumbnailDecision {
            cacheDecision(thumbnailDecision, forKey: cacheKey)
            return thumbnailDecision
        }

        // All checks passed — not cached so video is re-analyzed on each visit
        log.info("Video \(metadata.videoId) allowed")
        return .allow
    }

    // MARK: - YouTube Data API: Fetch Comments

    private func fetchComments(videoId: String, maxResults: Int) async -> [String] {
        let apiKey = Config.googleCloudAPIKey
        guard !apiKey.isEmpty else {
            log.warning("No Google Cloud API key — skipping comment fetch")
            return []
        }

        // Validate videoId format to prevent parameter injection
        guard videoId.range(of: "^[a-zA-Z0-9_-]{6,20}$", options: .regularExpression) != nil else {
            log.warning("Invalid videoId format: \(videoId)")
            return []
        }

        let urlString = "https://www.googleapis.com/youtube/v3/commentThreads"
            + "?part=snippet&videoId=\(videoId)"
            + "&maxResults=\(maxResults)"
            + "&order=relevance"
            + "&textFormat=plainText"

        guard let url = URL(string: urlString) else { return [] }

        // Send API key via header instead of URL parameter to avoid credential leakage in logs
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-goog-api-key")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                log.warning("YouTube API returned non-200 for comments")
                return []
            }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let items = json?["items"] as? [[String: Any]] else { return [] }

            var comments: [String] = []
            for item in items {
                if let snippet = item["snippet"] as? [String: Any],
                   let topLevel = snippet["topLevelComment"] as? [String: Any],
                   let commentSnippet = topLevel["snippet"] as? [String: Any],
                   let text = commentSnippet["textDisplay"] as? String {
                    comments.append(String(text.prefix(500)))
                }
            }
            log.info("Fetched \(comments.count) comments for video \(videoId)")
            return comments
        } catch {
            log.warning("Failed to fetch comments: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - NLP Analysis (reuses ContentAnalysisService pipeline)

    private func analyzeTextWithNLP(
        text: String,
        url: String,
        ageGroup: AgeGroup,
        parentSettings: ParentSettings,
        filterPreferences: ContentFilterPreferences
    ) async -> VideoDecision {
        let truncatedText = String(text.prefix(5000))

        let input = ContentAnalysisInput(
            url: url,
            htmlText: HTMLText(
                title: nil,
                metaDescription: nil,
                headings: [],
                bodyText: truncatedText,
                altText: [],
                comments: nil
            ),
            media: nil,
            structuralMetadata: nil,
            extraMetadata: nil
        )

        do {
            let decision = try await ContentAnalysisService.shared.analyzeContent(
                url: url,
                input: input,
                ageBand: ageGroup.toAgeBand(),
                customBlockedKeywords: parentSettings.blockedKeywords,
                customBlockedHosts: parentSettings.blockedHosts,
                filterPreferences: filterPreferences
            )

            // Check the decision for this age band
            let ageBandKey = ageGroup.toAgeBand().rawValue
            if let ageAction = decision.ageActions[ageBandKey] {
                switch ageAction.action {
                case .block:
                    let reason = ageAction.reason ?? "Content not appropriate"
                    log.info("NLP blocked video: \(reason)")
                    return .block(reason: reason, category: "Content Analysis")
                case .gate:
                    // Treat gate as block for YouTube videos (no gate UI for videos)
                    let reason = ageAction.reason ?? "Content may not be appropriate"
                    log.info("NLP gated video (treating as block): \(reason)")
                    return .block(reason: reason, category: "Content Analysis")
                case .allow:
                    return .allow
                }
            }
        } catch {
            log.warning("NLP analysis failed: \(error.localizedDescription)")
            // Fail-closed for NLP errors — child safety takes priority
            return .block(reason: "Content could not be verified", category: "Safety Check Failed")
        }

        return .allow
    }

    // MARK: - Thumbnail Analysis

    /// YouTube CDN domains that are valid sources for video thumbnails
    private static let allowedThumbnailHosts: Set<String> = [
        "i.ytimg.com", "i1.ytimg.com", "i2.ytimg.com", "i3.ytimg.com",
        "i4.ytimg.com", "i9.ytimg.com", "img.youtube.com",
        "yt3.ggpht.com", "yt3.googleusercontent.com"
    ]

    private func analyzeThumbnail(
        url thumbnailUrlString: String,
        filterPreferences: ContentFilterPreferences
    ) async -> VideoDecision {
        guard let thumbnailUrl = URL(string: thumbnailUrlString),
              thumbnailUrl.scheme == "https",
              let host = thumbnailUrl.host?.lowercased(),
              Self.allowedThumbnailHosts.contains(host) else {
            log.warning("Thumbnail URL rejected (invalid scheme or host): \(thumbnailUrlString.prefix(200))")
            return .allow
        }

        let result = await ImageFilterService.shared.analyzeImage(
            url: thumbnailUrl,
            preferences: filterPreferences
        )

        if result.shouldFilter {
            let category = result.category.rawValue
            log.info("Thumbnail blocked: \(category)")
            return .block(reason: "Video thumbnail flagged: \(category)", category: "Image Filter")
        }

        return .allow
    }

    /// Insert into cache with LRU eviction at maxCacheSize
    private func cacheDecision(_ decision: VideoDecision, forKey key: String) {
        if analysisCache[key] == nil {
            cacheOrder.append(key)
        }
        analysisCache[key] = decision
        while cacheOrder.count > maxCacheSize {
            let oldest = cacheOrder.removeFirst()
            analysisCache.removeValue(forKey: oldest)
        }
    }

    /// Clear analysis cache (e.g., when age group changes)
    func clearCache() {
        analysisCache.removeAll()
        cacheOrder.removeAll()
    }
}
#endif
