// ContentSafetyEngine.swift
// Main orchestrator for content safety analysis

import Foundation
import CoreML

/// Main content safety analysis engine
@available(iOS 17.0, macOS 14.0, *)
public actor ContentSafetyEngine {
    
    // MARK: - Configuration
    
    public struct Configuration {
        /// Compute units preference for ML models
        public var computeUnits: MLComputeUnits = .cpuAndNeuralEngine
        
        /// Maximum number of images to analyze per page
        public var maxImagesPerPage: Int = 3
        
        /// Maximum number of frames to analyze for video
        public var maxFramesPerVideo: Int = 6
        
        /// Token budget for text analysis
        public var tokenBudget: Int = 384
        
        /// Enable aggressive ANE optimization
        public var preferANE: Bool = true
        
        /// Cache size limit (in MB)
        public var cacheSizeLimitMB: Int = 50
        
        public init() {}
    }
    
    // MARK: - Properties
    
    private let configuration: Configuration
    private let policyEngine: PolicyEngine
    private let textStage: TextStage
    private let visionStage: VisionStage
    private let ruleEngine: RuleEngine
    private let cache: VerdictCache
    
    // MARK: - Initialization
    
    public init(configuration: Configuration = Configuration()) async throws {
        self.configuration = configuration
        
        // Initialize policy engine with build-time generated artifacts
        self.policyEngine = try await PolicyEngine()
        
        // Initialize text stage
        self.textStage = try await TextStage(
            computeUnits: configuration.computeUnits,
            tokenBudget: configuration.tokenBudget
        )
        
        // Initialize vision stage
        self.visionStage = try await VisionStage(
            computeUnits: configuration.computeUnits,
            maxImagesPerPage: configuration.maxImagesPerPage,
            maxFramesPerVideo: configuration.maxFramesPerVideo
        )
        
        // Initialize rule engine
        self.ruleEngine = RuleEngine(policyEngine: policyEngine)
        
        // Initialize cache
        self.cache = VerdictCache(limitMB: configuration.cacheSizeLimitMB)
    }
    
    // MARK: - Public API
    
    /// Analyze content for safety
    public func analyze(_ content: ContentInput, for ageGroup: AgeGroup) async throws -> SafetyVerdict {
        // 1. Check hard overrides first
        if let override = try await checkHardOverrides(content) {
            return override
        }
        
        // 2. Check cache
        if let cachedVerdict = await cache.verdict(for: content, ageGroup: ageGroup) {
            return cachedVerdict
        }
        
        // 3. Text stage (always run)
        let textResult = try await textStage.analyze(content.text)
        
        // 4. Determine if vision is needed
        let needsVision = shouldRunVision(textResult: textResult, content: content)
        
        var visionResult: VisionStage.Result?
        if needsVision, let media = content.media {
            // 5. Vision stage (conditional)
            visionResult = try await visionStage.analyze(media)
        }
        
        // 6. Merge results and apply age rules
        let verdict = await ruleEngine.computeVerdict(
            textResult: textResult,
            visionResult: visionResult,
            ageGroup: ageGroup,
            content: content
        )
        
        // 7. Cache result
        await cache.store(verdict, for: content, ageGroup: ageGroup)
        
        return verdict
    }
    
    /// Batch analyze multiple content items
    public func analyze(_ contents: [ContentInput], for ageGroup: AgeGroup) async throws -> [SafetyVerdict] {
        // Process in parallel but with concurrency limit
        return try await withThrowingTaskGroup(of: (Int, SafetyVerdict).self) { group in
            for (index, content) in contents.enumerated() {
                group.addTask {
                    let verdict = try await self.analyze(content, for: ageGroup)
                    return (index, verdict)
                }
            }
            
            var results: [(Int, SafetyVerdict)] = []
            for try await result in group {
                results.append(result)
            }
            
            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }
    
    // MARK: - Private Methods
    
    private func checkHardOverrides(_ content: ContentInput) async throws -> SafetyVerdict? {
        // Check domain allowlist/blocklist
        if let domain = content.domain {
            if await policyEngine.isBlockedDomain(domain) {
                return SafetyVerdict(
                    action: .block,
                    confidence: 1.0,
                    categories: [.explicit],
                    reason: "Domain is in blocklist"
                )
            }
            
            if await policyEngine.isAllowedDomain(domain) {
                return SafetyVerdict(
                    action: .allow,
                    confidence: 1.0,
                    categories: [],
                    reason: "Domain is in allowlist"
                )
            }
        }
        
        // Check custom blocked keywords (parent-defined)
        if let blockedKeywords = await policyEngine.customBlockedKeywords,
           content.text.containsAny(of: blockedKeywords) {
            return SafetyVerdict(
                action: .block,
                confidence: 1.0,
                categories: [.custom],
                reason: "Contains parent-blocked keyword"
            )
        }
        
        return nil
    }
    
    private func shouldRunVision(textResult: TextStage.Result, content: ContentInput) -> Bool {
        // Run vision if:
        // 1. Any ban-sensitive category above threshold
        let banSensitive: Set<SafetyCategory> = [.explicit, .violence, .selfHarm, .extremism]
        for category in textResult.categories {
            if banSensitive.contains(category.key),
               category.value > 0.3 {
                return true
            }
        }
        
        // 2. Low confidence on text
        if textResult.confidence < 0.6 {
            return true
        }
        
        // 3. Domain is high-risk
        if let domain = content.domain,
           policyEngine.isHighRiskDomain(domain) {
            return true
        }
        
        // 4. Has media and no strong text signal
        if content.media != nil,
           textResult.categories.values.max() ?? 0 < 0.5 {
            return true
        }
        
        return false
    }
}

// MARK: - Supporting Types

public struct ContentInput: Hashable, Sendable {
    public let id: String
    public let text: String
    public let media: MediaInput?
    public let domain: String?
    public let url: URL?
    public let metadata: [String: String]
    
    public init(
        id: String = UUID().uuidString,
        text: String,
        media: MediaInput? = nil,
        domain: String? = nil,
        url: URL? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.text = text
        self.media = media
        self.domain = domain
        self.url = url
        self.metadata = metadata
    }
}

public struct MediaInput: Hashable, Sendable {
    public enum MediaType: Hashable, Sendable {
        case image(Data)
        case video(URL)
        case thumbnail(Data)
    }
    
    public let type: MediaType
    
    public init(type: MediaType) {
        self.type = type
    }
}

public enum AgeGroup: String, Codable, Sendable {
    case below10 = "<10"
    case age10to13 = "10-13"
    case age13to16 = "13-16"
    case age16to18 = "16-18"
    case adult = "18+"
}

public struct SafetyVerdict: Codable, Sendable {
    public enum Action: String, Codable, Sendable {
        case allow = "ALLOW"
        case gate = "GATE"
        case block = "BLOCK"
    }
    
    public let action: Action
    public let confidence: Float
    public let categories: Set<SafetyCategory>
    public let reason: String
    public let details: VerdictDetails?
    
    public init(
        action: Action,
        confidence: Float,
        categories: Set<SafetyCategory>,
        reason: String,
        details: VerdictDetails? = nil
    ) {
        self.action = action
        self.confidence = confidence
        self.categories = categories
        self.reason = reason
        self.details = details
    }
}

public struct VerdictDetails: Codable, Sendable {
    public let majorCategories: [String: Float]
    public let subcategories: [String: Float]
    public let textScore: Float
    public let visionScore: Float?
    public let needsVision: Bool
    public let processingTimeMs: Double
}

public enum SafetyCategory: String, Codable, Hashable, Sendable {
    case violence
    case explicit
    case substances
    case financial
    case media
    case social
    case selfHarm = "self_harm"
    case extremism
    case hate
    case custom
}

// String extension for keyword matching
extension String {
    func containsAny(of keywords: [String]) -> Bool {
        let lowercased = self.lowercased()
        return keywords.contains { lowercased.contains($0.lowercased()) }
    }
}
