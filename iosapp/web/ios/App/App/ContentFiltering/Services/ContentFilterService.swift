//
//  ContentFilterService.swift
//  Komal - Content Filtering Engine
//
//  Core filtering logic with age-based rules
//

import Foundation

class ContentFilterService {
    static let shared = ContentFilterService()

    private let parentControl = ParentControlService.shared
    private let mlAnalyzer = MLContentAnalyzer.shared
    private let logger = ContentLogger.shared
    private let ruleEngine = AgeRuleEngine()

    // Cache for performance
    private var urlCache: [String: DetectionResult] = [:]
    private let cacheQueue = DispatchQueue(label: "com.komal.cache", attributes: .concurrent)

    private init() {}

    // MARK: - Main Filtering Method
    func shouldAllowURL(_ urlString: String, completion: @escaping (FilterDecision) -> Void) {
        // Check cache first
        if let cached = getCachedResult(for: urlString) {
            completion(FilterDecision(
                shouldAllow: cached.action == .allow,
                action: cached.action,
                category: cached.category,
                reason: cached.reason
            ))
            return
        }

        // Analyze URL
        mlAnalyzer.analyzeURL(urlString) { [weak self] result in
            guard let self = self else { return }

            let childAge = self.parentControl.childAge
            let ageGroup = AgeGroup.from(age: childAge)

            // Check for custom parent rules first
            let action: FilterAction
            if let customRule = self.parentControl.getCustomRule(for: result.category) {
                action = customRule
            } else {
                // Use age-based rule
                action = self.ruleEngine.getAction(for: result.category, ageGroup: ageGroup, isEducational: result.isEducational)
            }

            // Cache result
            self.cacheResult(urlString, result: result, action: action)

            // Log activity
            self.logger.log(
                url: urlString,
                category: result.category,
                action: action,
                wasBlocked: action == .block,
                reason: result.reason
            )

            // Return decision
            let decision = FilterDecision(
                shouldAllow: action == .allow,
                action: action,
                category: result.category,
                reason: result.reason,
                confidence: result.confidence
            )

            completion(decision)
        }
    }

    // MARK: - Batch Analysis
    func analyzeBatch(_ urls: [String], completion: @escaping ([String: FilterDecision]) -> Void) {
        var results: [String: FilterDecision] = [:]
        let group = DispatchGroup()

        for url in urls {
            group.enter()
            shouldAllowURL(url) { decision in
                results[url] = decision
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion(results)
        }
    }

    // MARK: - Cache Management
    private func getCachedResult(for url: String) -> (category: ContentCategory, action: FilterAction, reason: String?)? {
        var result: (ContentCategory, FilterAction, String?)?
        cacheQueue.sync {
            if let cached = urlCache[url] {
                let action = getActionForResult(cached)
                result = (cached.category, action, cached.reason)
            }
        }
        return result
    }

    private func cacheResult(_ url: String, result: DetectionResult, action: FilterAction) {
        cacheQueue.async(flags: .barrier) {
            self.urlCache[url] = result

            // Limit cache size
            if self.urlCache.count > 1000 {
                // Remove oldest entries
                let sorted = self.urlCache.sorted { $0.value.timestamp < $1.value.timestamp }
                let toRemove = sorted.prefix(100)
                toRemove.forEach { self.urlCache.removeValue(forKey: $0.key) }
            }
        }
    }

    func clearCache() {
        cacheQueue.async(flags: .barrier) {
            self.urlCache.removeAll()
        }
    }

    private func getActionForResult(_ result: DetectionResult) -> FilterAction {
        let childAge = parentControl.childAge
        let ageGroup = AgeGroup.from(age: childAge)

        if let customRule = parentControl.getCustomRule(for: result.category) {
            return customRule
        }

        return ruleEngine.getAction(for: result.category, ageGroup: ageGroup, isEducational: result.isEducational)
    }

    // MARK: - Statistics
    func getFilteringStats() -> FilteringStats {
        let logs = parentControl.getActivityLogs()
        let blocked = logs.filter { $0.wasBlocked }.count
        let gated = logs.filter { $0.action == .gate }.count
        let allowed = logs.filter { $0.action == .allow }.count

        var categoryBreakdown: [ContentCategory: Int] = [:]
        for log in logs {
            categoryBreakdown[log.category, default: 0] += 1
        }

        return FilteringStats(
            totalRequests: logs.count,
            blocked: blocked,
            gated: gated,
            allowed: allowed,
            categoryBreakdown: categoryBreakdown,
            cacheSize: urlCache.count
        )
    }
}

// MARK: - Filter Decision
struct FilterDecision {
    let shouldAllow: Bool
    let action: FilterAction
    let category: ContentCategory
    let reason: String?
    let confidence: Double?

    init(shouldAllow: Bool, action: FilterAction, category: ContentCategory, reason: String?, confidence: Double? = nil) {
        self.shouldAllow = shouldAllow
        self.action = action
        self.category = category
        self.reason = reason
        self.confidence = confidence
    }
}

// MARK: - Filtering Statistics
struct FilteringStats {
    let totalRequests: Int
    let blocked: Int
    let gated: Int
    let allowed: Int
    let categoryBreakdown: [ContentCategory: Int]
    let cacheSize: Int

    var blockRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(blocked) / Double(totalRequests)
    }

    var topCategories: [(ContentCategory, Int)] {
        categoryBreakdown.sorted { $0.value > $1.value }.prefix(5).map { ($0.key, $0.value) }
    }
}

// MARK: - Age Rule Engine
class AgeRuleEngine {
    // Age-based rules for all 40+ categories
    func getAction(for category: ContentCategory, ageGroup: AgeGroup, isEducational: Bool) -> FilterAction {
        // Educational content gets lenient treatment
        if isEducational {
            return getEducationalAction(for: category, ageGroup: ageGroup)
        }

        // Apply standard rules
        switch category {
        // 1. Violence & Disturbing Content
        case .graphicViolence:
            return ageGroup.rawValue >= 16 ? .gate : .block
        case .nonGraphicViolence:
            return ageGroup.rawValue >= 13 ? .allow : .gate
        case .heavyFighting:
            return ageGroup.rawValue >= 13 ? .gate : .block
        case .horror:
            return ageGroup.rawValue >= 13 ? .gate : .block
        case .crimeNews:
            return ageGroup.rawValue >= 13 ? .allow : .gate

        // 2. Explicit & Body-Related Content
        case .explicitSexual:
            return .block
        case .sexualEducation:
            return ageGroup.rawValue >= 13 ? .gate : .block
        case .erotica:
            return .block
        case .indecentClothing:
            return ageGroup.rawValue >= 13 ? .gate : .block
        case .bodyModification:
            return ageGroup.rawValue >= 16 ? .allow : .gate
        case .beautyFilters:
            return ageGroup.rawValue >= 10 ? .allow : .gate

        // 3. Substances & Addictive Behavior
        case .alcohol:
            return ageGroup.rawValue >= 16 ? .allow : .gate
        case .drugs:
            return ageGroup.rawValue >= 16 ? .gate : .block
        case .cigarettes:
            return ageGroup.rawValue >= 16 ? .gate : .block
        case .gambling:
            return ageGroup.rawValue >= 18 ? .gate : .block
        case .lootBoxes:
            return ageGroup.rawValue >= 13 ? .gate : .block

        // 4. Parasocial & Manipulative Content
        case .parasocialDependency:
            return ageGroup.rawValue >= 16 ? .allow : .gate
        case .creatorPressure:
            return ageGroup.rawValue >= 13 ? .gate : .block
        case .donationFarming:
            return ageGroup.rawValue >= 16 ? .allow : .gate
        case .aiFriends:
            return ageGroup.rawValue >= 13 ? .gate : .block

        // 5. Self-Optimization & Body Anxiety
        case .looksmaxxing:
            return ageGroup.rawValue >= 16 ? .gate : .block
        case .dietCulture:
            return ageGroup.rawValue >= 16 ? .gate : .block
        case .steroids:
            return .block
        case .glowUpPressure:
            return ageGroup.rawValue >= 16 ? .allow : .gate

        // 6. Financial & Commercial Content
        case .crypto:
            return ageGroup.rawValue >= 18 ? .allow : .block
        case .getRichQuick:
            return ageGroup.rawValue >= 16 ? .gate : .block
        case .influencerFinance:
            return ageGroup.rawValue >= 16 ? .allow : .gate
        case .subscriptionPages:
            return .block
        case .mlmScams:
            return .block
        case .sponsoredGambling:
            return .block

        // 7. Media & Platform-Native Risks
        case .fastCutEditing:
            return ageGroup.rawValue >= 10 ? .allow : .gate
        case .hypnoticPatterns:
            return ageGroup.rawValue >= 13 ? .gate : .block
        case .autoplay:
            return ageGroup.rawValue >= 10 ? .allow : .gate
        case .clickbaitThumbs:
            return ageGroup.rawValue >= 13 ? .allow : .gate
        case .liveStreaming:
            return ageGroup.rawValue >= 13 ? .gate : .block
        case .userGeneratedComments:
            return ageGroup.rawValue >= 13 ? .gate : .block

        // 8. Social & Cultural Topics
        case .lgbtqContent:
            return ageGroup.rawValue >= 13 ? .allow : .gate
        case .religion:
            return ageGroup.rawValue >= 10 ? .allow : .gate
        case .immigration:
            return ageGroup.rawValue >= 13 ? .allow : .gate
        case .communism:
            return ageGroup.rawValue >= 13 ? .allow : .gate
        case .discriminationHate:
            return .block
        case .gunsWeapons:
            return ageGroup.rawValue >= 16 ? .gate : .block
        case .extremistOrgs:
            return .block
        }
    }

    private func getEducationalAction(for category: ContentCategory, ageGroup: AgeGroup) -> FilterAction {
        // More lenient rules for educational content
        switch category {
        case .explicitSexual, .erotica, .steroids, .subscriptionPages, .mlmScams, .sponsoredGambling, .discriminationHate, .extremistOrgs:
            return .block // Always block harmful content
        case .sexualEducation:
            return ageGroup.rawValue >= 10 ? .allow : .gate
        case .graphicViolence, .horror:
            return ageGroup.rawValue >= 13 ? .allow : .gate
        default:
            return .allow // Allow most educational content
        }
    }
}
