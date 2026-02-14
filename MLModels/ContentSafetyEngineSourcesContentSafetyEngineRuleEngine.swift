// RuleEngine.swift
// Applies age-based rules and computes final verdict

import Foundation

@available(iOS 17.0, macOS 14.0, *)
actor RuleEngine {
    
    private let policyEngine: PolicyEngine
    
    init(policyEngine: PolicyEngine) {
        self.policyEngine = policyEngine
    }
    
    // MARK: - Verdict Computation
    
    func computeVerdict(
        textResult: TextStage.Result,
        visionResult: VisionStage.Result?,
        ageGroup: AgeGroup,
        content: ContentInput
    ) async -> SafetyVerdict {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // 1. Combine text and vision scores
        let combinedScores = combineScores(text: textResult, vision: visionResult)
        
        // 2. Determine dominant categories
        let dominantCategories = findDominantCategories(combinedScores)
        
        // 3. Look up age rules for each category
        var actions: [SafetyVerdict.Action] = []
        var confidences: [Float] = []
        
        for category in dominantCategories {
            if let categoryScore = combinedScores[category] {
                let policy = await policyEngine.policy(for: category, ageGroup: ageGroup)
                let action = determineAction(policy: policy, score: categoryScore, ageGroup: ageGroup)
                actions.append(action)
                confidences.append(categoryScore)
            }
        }
        
        // 4. Apply most-restrictive merge
        let finalAction = mostRestrictive(actions)
        let finalConfidence = confidences.max() ?? 0.5
        
        // 5. Build reason
        let reason = buildReason(
            action: finalAction,
            categories: dominantCategories,
            scores: combinedScores
        )
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let processingTimeMs = (endTime - startTime) * 1000
        
        // 6. Create details
        let details = VerdictDetails(
            majorCategories: Dictionary(uniqueKeysWithValues: combinedScores.map { ($0.key.rawValue, $0.value) }),
            subcategories: Dictionary(uniqueKeysWithValues: textResult.subcategories.map { ($0.key, $0.value) }),
            textScore: textResult.confidence,
            visionScore: visionResult.map { ($0.nsfwScore + $0.violenceScore) / 2 },
            needsVision: visionResult != nil,
            processingTimeMs: processingTimeMs
        )
        
        return SafetyVerdict(
            action: finalAction,
            confidence: finalConfidence,
            categories: dominantCategories,
            reason: reason,
            details: details
        )
    }
    
    // MARK: - Private Methods
    
    private func combineScores(
        text: TextStage.Result,
        vision: VisionStage.Result?
    ) -> [SafetyCategory: Float] {
        var combined = text.categories
        
        if let vision = vision {
            // Weight: 0.6 vision, 0.4 text for ban-sensitive categories
            for (category, visionScore) in vision.categories {
                let textScore = combined[category] ?? 0
                
                // Higher vision weight for explicit/violence
                let weight: Float = (category == .explicit || category == .violence) ? 0.6 : 0.4
                combined[category] = weight * visionScore + (1 - weight) * textScore
            }
        }
        
        return combined
    }
    
    private func findDominantCategories(_ scores: [SafetyCategory: Float]) -> Set<SafetyCategory> {
        var result = Set<SafetyCategory>()
        
        for (category, score) in scores {
            // Include categories above threshold
            if score > 0.3 {
                result.insert(category)
            }
        }
        
        // If nothing is dominant, mark as safe
        if result.isEmpty {
            // Return empty set for "no concerns"
        }
        
        return result
    }
    
    private func determineAction(
        policy: Policy,
        score: Float,
        ageGroup: AgeGroup
    ) -> SafetyVerdict.Action {
        // Apply threshold-based decision
        switch ageGroup {
        case .below10, .age10to13:
            if score > 0.7 {
                return .block
            } else if score > 0.4 {
                return .gate
            } else {
                return .allow
            }
            
        case .age13to16:
            if score > 0.8 {
                return .block
            } else if score > 0.5 {
                return .gate
            } else {
                return .allow
            }
            
        case .age16to18, .adult:
            if score > 0.9 {
                return .block
            } else if score > 0.7 {
                return .gate
            } else {
                return .allow
            }
        }
    }
    
    private func mostRestrictive(_ actions: [SafetyVerdict.Action]) -> SafetyVerdict.Action {
        if actions.contains(.block) {
            return .block
        } else if actions.contains(.gate) {
            return .gate
        } else {
            return .allow
        }
    }
    
    private func buildReason(
        action: SafetyVerdict.Action,
        categories: Set<SafetyCategory>,
        scores: [SafetyCategory: Float]
    ) -> String {
        if categories.isEmpty {
            return "Content appears safe for this age group"
        }
        
        let categoryNames = categories.map { $0.rawValue }.sorted().joined(separator: ", ")
        let maxScore = scores.values.max() ?? 0
        
        switch action {
        case .block:
            return "Content blocked: contains \(categoryNames) (confidence: \(Int(maxScore * 100))%)"
        case .gate:
            return "Supervision recommended: may contain \(categoryNames) (confidence: \(Int(maxScore * 100))%)"
        case .allow:
            return "Content allowed with minor concerns: \(categoryNames)"
        }
    }
}

// MARK: - Policy

struct Policy: Sendable {
    let category: SafetyCategory
    let ageGroup: AgeGroup
    let defaultAction: SafetyVerdict.Action
    let thresholds: Thresholds
    
    struct Thresholds: Sendable {
        let blockThreshold: Float
        let gateThreshold: Float
    }
}
