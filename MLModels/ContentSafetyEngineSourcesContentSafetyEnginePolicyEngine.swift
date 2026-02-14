// PolicyEngine.swift
// Manages policies, domain lists, and configuration

import Foundation

@available(iOS 17.0, macOS 14.0, *)
actor PolicyEngine {
    
    // MARK: - Properties
    
    private let labelsMajor: [String: SafetyCategory]
    private let labelsSub: [String: SubcategoryInfo]
    private let ageRules: [String: AgeRuleSet]
    private let thresholds: [String: ThresholdConfig]
    
    private var blockedDomains: Set<String>
    private var allowedDomains: Set<String>
    private var highRiskDomains: Set<String>
    private var customBlockedKeywords: [String]?
    
    // MARK: - Initialization
    
    init() async throws {
        // Load build-time generated policy bundles
        let bundle = Bundle.module
        
        // Load labels_major.json
        guard let majorURL = bundle.url(forResource: "labels_major", withExtension: "json") else {
            throw SafetyError.resourceNotFound("labels_major.json")
        }
        let majorData = try Data(contentsOf: majorURL)
        self.labelsMajor = try JSONDecoder().decode([String: SafetyCategory].self, from: majorData)
        
        // Load labels_sub.json
        guard let subURL = bundle.url(forResource: "labels_sub", withExtension: "json") else {
            throw SafetyError.resourceNotFound("labels_sub.json")
        }
        let subData = try Data(contentsOf: subURL)
        self.labelsSub = try JSONDecoder().decode([String: SubcategoryInfo].self, from: subData)
        
        // Load age_rules.json
        guard let rulesURL = bundle.url(forResource: "age_rules", withExtension: "json") else {
            throw SafetyError.resourceNotFound("age_rules.json")
        }
        let rulesData = try Data(contentsOf: rulesURL)
        self.ageRules = try JSONDecoder().decode([String: AgeRuleSet].self, from: rulesData)
        
        // Load thresholds.json
        guard let thresholdsURL = bundle.url(forResource: "thresholds", withExtension: "json") else {
            throw SafetyError.resourceNotFound("thresholds.json")
        }
        let thresholdsData = try Data(contentsOf: thresholdsURL)
        self.thresholds = try JSONDecoder().decode([String: ThresholdConfig].self, from: thresholdsData)
        
        // Initialize domain lists (these can be updated dynamically)
        self.blockedDomains = [
            "pornhub.com",
            "xvideos.com",
            "xnxx.com",
            // ... load from persistent storage or server
        ]
        
        self.allowedDomains = [
            "apple.com",
            "wikipedia.org",
            "khanacademy.org",
            // ... load from persistent storage
        ]
        
        self.highRiskDomains = [
            "omegle.com",
            "chatroulette.com",
            // ... load from persistent storage
        ]
    }
    
    // MARK: - Policy Lookup
    
    func policy(for category: SafetyCategory, ageGroup: AgeGroup) async -> Policy {
        let categoryKey = category.rawValue
        
        guard let ruleSet = ageRules[categoryKey] else {
            // Default conservative policy
            return Policy(
                category: category,
                ageGroup: ageGroup,
                defaultAction: .block,
                thresholds: Policy.Thresholds(blockThreshold: 0.7, gateThreshold: 0.4)
            )
        }
        
        let action = ruleSet.action(for: ageGroup)
        let thresholdConfig = thresholds[categoryKey] ?? ThresholdConfig.default
        
        return Policy(
            category: category,
            ageGroup: ageGroup,
            defaultAction: action,
            thresholds: Policy.Thresholds(
                blockThreshold: thresholdConfig.blockThreshold,
                gateThreshold: thresholdConfig.gateThreshold
            )
        )
    }
    
    // MARK: - Domain Management
    
    func isBlockedDomain(_ domain: String) async -> Bool {
        blockedDomains.contains(domain.lowercased())
    }
    
    func isAllowedDomain(_ domain: String) async -> Bool {
        allowedDomains.contains(domain.lowercased())
    }
    
    func isHighRiskDomain(_ domain: String) -> Bool {
        highRiskDomains.contains(domain.lowercased())
    }
    
    func addBlockedDomain(_ domain: String) {
        blockedDomains.insert(domain.lowercased())
    }
    
    func removeBlockedDomain(_ domain: String) {
        blockedDomains.remove(domain.lowercased())
    }
    
    func addAllowedDomain(_ domain: String) {
        allowedDomains.insert(domain.lowercased())
    }
    
    func removeAllowedDomain(_ domain: String) {
        allowedDomains.remove(domain.lowercased())
    }
    
    // MARK: - Custom Keywords
    
    func setCustomBlockedKeywords(_ keywords: [String]) {
        self.customBlockedKeywords = keywords.map { $0.lowercased() }
    }
    
    func customBlockedKeywords() async -> [String]? {
        return customBlockedKeywords
    }
}

// MARK: - Supporting Types

struct SubcategoryInfo: Codable {
    let id: String
    let parentMajor: String
    let name: String
}

struct AgeRuleSet: Codable {
    let below10: String
    let age10to13: String
    let age13to16: String
    let age16to18: String
    
    func action(for ageGroup: AgeGroup) -> SafetyVerdict.Action {
        let actionString: String
        switch ageGroup {
        case .below10:
            actionString = below10
        case .age10to13:
            actionString = age10to13
        case .age13to16:
            actionString = age13to16
        case .age16to18, .adult:
            actionString = age16to18
        }
        
        return SafetyVerdict.Action(rawValue: actionString.uppercased()) ?? .block
    }
}

struct ThresholdConfig: Codable {
    let blockThreshold: Float
    let gateThreshold: Float
    let banSensitive: Bool
    
    static let `default` = ThresholdConfig(
        blockThreshold: 0.7,
        gateThreshold: 0.4,
        banSensitive: false
    )
}
