//
//  ContentAnalysisService.swift
//  Komalios
//
//  On-device first content analysis service
//  Follows the specification: on-device first, cloud fallback
//

import Foundation
import NaturalLanguage
import Vision
import CoreML
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class ContentAnalysisService {
    static let shared = ContentAnalysisService()

    private static let iso8601Formatter = ISO8601DateFormatter()

    private init() {
        setupNLP()
    }
    
    // MARK: - NLP Setup

    // CoreML Model
    private var contentSafetyModel: ContentSafetyTextClassifier?
    
    private func setupNLP() {
        // Initialize NaturalLanguage framework components
        loadContentSafetyModel()
    }
    
    /// Load ContentSafetyTextClassifier CoreML model
    private func loadContentSafetyModel() {
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .cpuAndNeuralEngine // Use Neural Engine if available
            contentSafetyModel = try ContentSafetyTextClassifier(configuration: config)
            print("✅ ContentSafetyTextClassifier model loaded successfully")
        } catch {
            print("⚠️ Could not load ContentSafetyTextClassifier: \(error.localizedDescription)")
            print("   Falling back to keyword-based detection")
        }
    }
    
    // MARK: - Main Analysis Pipeline
    
    /// Analyze content following the specification pipeline
    func analyzeContent(
        url: String,
        input: ContentAnalysisInput,
        ageBand: AgeBand,
        customBlockedKeywords: [String],
        customBlockedHosts: [String],
        filterPreferences: ContentFilterPreferences,
        searchQuery: String? = nil
    ) async throws -> UnifiedDecisionResponse {
        
        // Step 1: Check custom blocked keywords/URLs FIRST (before any analysis)
        if let customDecision = checkCustomRules(
            url: url,
            keywords: customBlockedKeywords,
            hosts: customBlockedHosts
        ) {
            return createDecisionFromCustomRule(
                url: url,
                action: customDecision,
                reason: "Blocked by parent custom rules"
            )
        }
        
        // Step 2: Collect and normalize metadata (already done via ContentAnalysisInput)
        
        // Step 3: On-device NLP stage
        let nlpResult = await analyzeNLP(input: input)
        
        // Step 4: On-device Vision stage
        let visionResult = await analyzeVision(input: input, filterPreferences: filterPreferences)
        
        // Step 5: On-device Audio stage
        let audioResult = await analyzeAudio(input: input)
        
        // Step 6: Cross-content analysis (sponsors, links)
        let linksResult = await analyzeLinks(input: input)
        
        // Step 7: Merge all decisions (most restrictive rule)
        let mergedDecision = mergeAllDecisions(
            nlp: nlpResult,
            vision: visionResult,
            audio: audioResult,
            links: linksResult,
            cloud: nil, // Will be set if fallback needed
            ageBand: ageBand,
            filterPreferences: filterPreferences
        )
        
        // Step 8: Check if cloud fallback is needed
        let needsCloud = shouldUseCloudFallback(
            nlp: nlpResult,
            vision: visionResult,
            audio: audioResult,
            links: linksResult
        )
        debugLogLine("[DEBUG-ANALYSIS] Cloud fallback needed: \(needsCloud)")
        debugLogLine("[DEBUG-ANALYSIS] NLP confidence: \(nlpResult.confidence), categories: \(nlpResult.majorCategories.map { "\($0.name): \($0.probability)" })")
        debugLogLine("[DEBUG-ANALYSIS] Vision confidence: \(visionResult.confidence), Audio confidence: \(audioResult.confidence)")
        if needsCloud {
            debugLogLine("[DEBUG-ANALYSIS] Calling cloud fallback for: \(url)")
            do {
                let cloudResult = try await callCloudFallback(url: url, input: input, searchQuery: searchQuery)
                debugLogLine("[DEBUG-ANALYSIS] Cloud result received - confidence: \(cloudResult.confidence), categories: \(cloudResult.majorCategories.map { $0.name })")

                // When the cloud returned a full unified response, prefer it directly
                // (the server crawled the page and has richer data than on-device merge)
                if let serverResponse = cloudResult.unifiedResponse {
                    debugLogLine("[DEBUG-ANALYSIS] Using server's full UnifiedDecisionResponse")
                    return serverResponse
                }

                return mergeAllDecisions(
                    url: url,
                    nlp: nlpResult,
                    vision: visionResult,
                    audio: audioResult,
                    links: linksResult,
                    cloud: cloudResult,
                    ageBand: ageBand,
                    filterPreferences: filterPreferences
                )
            } catch {
                debugLogLine("[DEBUG-ANALYSIS] Cloud fallback FAILED: \(error.localizedDescription)")
                throw error
            }
        }
        
        // Step 9: Build unified response
        return buildUnifiedResponse(
            url: url,
            nlp: nlpResult,
            vision: visionResult,
            audio: audioResult,
            links: linksResult,
            cloud: nil,
            mergedDecision: mergedDecision,
            input: input
        )
    }
    
    // MARK: - Step 1: Custom Rules Check
    
    private func checkCustomRules(
        url: String,
        keywords: [String],
        hosts: [String]
    ) -> Action? {
        let lowercased = url.lowercased()
        
        // Check keywords in URL
        for keyword in keywords {
            if lowercased.contains(keyword.lowercased()) {
                return .block
            }
        }
        
        // Check hosts
        if let urlObj = URL(string: url), let host = urlObj.host?.lowercased() {
            for blockedHost in hosts {
                if host.contains(blockedHost.lowercased()) {
                    return .block
                }
            }
        }
        
        return nil
    }
    
    private func createDecisionFromCustomRule(
        url: String,
        action: Action,
        reason: String
    ) -> UnifiedDecisionResponse {
        var ageActions: [String: AgeAction] = [:]
        for ageBand in AgeBand.allCases {
            ageActions[ageBand.rawValue] = AgeAction(
                action: action,
                score: action == .block ? 0.95 : 0.5,
                reason: reason,
                risks: [reason]
            )
        }
        
        return UnifiedDecisionResponse(
            url: url,
            overallSafetyScore: action == .block ? 0.1 : 0.5,
            languageSafetyScore: 0.0,
            visualSafetyScore: 0.0,
            audioSafetyScore: 0.0,
            ageActions: ageActions,
            majorCategories: [],
            subcategories: [],
            contextType: nil,
            topicTags: ["custom_rule"],
            flags: SafetyFlags(
                bodyAnxiety: false,
                selfHarm: false,
                fraudOrScam: false,
                extremism: false,
                lgbtqFlagPresent: nil,
                gambling: false,
                parasocial: false,
                substanceAbuse: false
            ),
            decisionSource: DecisionSource(
                nlp: SourceInfo(used: false, confidence: 0.0),
                vision: SourceInfo(used: false, confidence: 0.0),
                audio: SourceInfo(used: false, confidence: 0.0),
                links: SourceInfo(used: false, confidence: 0.0),
                cloud: SourceInfo(used: false, confidence: 0.0)
            ),
            timestamp: ContentAnalysisService.iso8601Formatter.string(from: Date()),
            historyCategory: "Custom Rules",
            historySubcategory: "Parent Blocked",
            revealingLevel: nil
        )
    }
    
    // MARK: - Step 3: NLP Analysis
    
    private func analyzeNLP(input: ContentAnalysisInput) async -> NLPResult {
        // TODO: Implement on-device NLP analysis
        // For now, return placeholder that will be replaced by API or actual on-device model
        
        // Preprocessing: Build NLP text blocks
        let textBlocks = buildNLPTextBlocks(input: input)
        
        // Major category detection
        let majorCategories = detectMajorCategories(textBlocks: textBlocks)
        
        // Subcategory detection
        let subcategories = detectSubcategories(
            textBlocks: textBlocks,
            majorCategories: majorCategories
        )
        
        // Calculate confidence based on detected categories
        let confidence = majorCategories.isEmpty ? 0.0 : majorCategories.map { $0.probability }.max() ?? 0.0
        
        return NLPResult(
            majorCategories: majorCategories,
            subcategories: subcategories,
            confidence: confidence,
            used: !majorCategories.isEmpty || !subcategories.isEmpty
        )
    }
    
    private func buildNLPTextBlocks(input: ContentAnalysisInput) -> NLPTextBlocks {
        let html = input.htmlText
        let metadata = input.extraMetadata
        
        return NLPTextBlocks(
            mainContent: [
                html?.title,
                html?.metaDescription,
                html?.bodyText
            ].compactMap { $0 }.joined(separator: " "),
            creatorMetadata: metadata?.creator?.description ?? "",
            sponsorMetadata: metadata?.sponsors.map { $0.context ?? $0.name }.joined(separator: " ") ?? "",
            linkContext: metadata?.links.map { $0.context ?? $0.anchorText ?? "" }.joined(separator: " ") ?? ""
        )
    }
    
    // MARK: - NLP Classification Thresholds

    private struct NLPThresholds {
        static let majorCategoryThreshold: Double = 0.30
        static let banSensitiveThreshold: Double = 0.20
        static let subcategoryThreshold: Double = 0.30
        static let clusterTolerance: Double = 0.10 // ±10 percentage points
        static let ambiguousSubcatLimit = 5
        static let banSensitiveCategories: Set<MajorCategoryType> = [
            .explicitBodyContent, .selfHarm, .extremism, .violence
        ]
        static let standardSubcatLimit = 6
        static let banSensitiveSubcatLimit = 30
    }

    private func detectMajorCategories(textBlocks: NLPTextBlocks) -> [MajorCategory] {
        // Use NaturalLanguage framework for improved detection
        let combinedText = "\(textBlocks.mainContent) \(textBlocks.creatorMetadata) \(textBlocks.sponsorMetadata)"

        // Try CoreML models first (if available)
        var rawCategories: [MajorCategory] = []
        do {
            let mlResult = try detectWithCoreML(text: combinedText)
            if !mlResult.isEmpty {
                print("✅ Using CoreML model for category detection")
                rawCategories = mlResult
            }
        } catch {
            print("⚠️ CoreML detection failed, using keyword fallback: \(error.localizedDescription)")
        }

        // Fallback to enhanced keyword-based detection with NaturalLanguage
        if rawCategories.isEmpty {
            print("📝 Using enhanced keyword detection")
            rawCategories = enhancedKeywordDetection(textBlocks: textBlocks, combinedText: combinedText)
        }

        // Apply Rule A/B/C structured classification
        return classifyWithRules(rawCategories: rawCategories, textBlocks: textBlocks)
    }

    /// Structured Rule A/B/C classification logic
    private func classifyWithRules(
        rawCategories: [MajorCategory],
        textBlocks: NLPTextBlocks
    ) -> [MajorCategory] {
        let maxProb = rawCategories.map { $0.probability }.max() ?? 0.0

        // Rule C: Check ban-sensitive categories at lower threshold (0.20)
        let banSensitiveHits = rawCategories.filter { category in
            guard let categoryType = MajorCategoryType(rawValue: category.name) else { return false }
            return NLPThresholds.banSensitiveCategories.contains(categoryType) &&
                   category.probability >= NLPThresholds.banSensitiveThreshold
        }

        if !banSensitiveHits.isEmpty {
            debugLogLine("[NLP-RULE-C] Ban-sensitive categories detected: \(banSensitiveHits.map { "\($0.name): \($0.probability)" })")
            // Return ban-sensitive hits — subcategory exploration will use expanded limits
            return banSensitiveHits.sorted { $0.probability > $1.probability }
        }

        // Rule B: Exactly one (or more) major category ≥ 0.30
        let aboveThreshold = rawCategories.filter { $0.probability >= NLPThresholds.majorCategoryThreshold }
        if !aboveThreshold.isEmpty {
            debugLogLine("[NLP-RULE-B] Major categories above threshold: \(aboveThreshold.map { "\($0.name): \($0.probability)" })")
            return aboveThreshold.sorted { $0.probability > $1.probability }
        }

        // Rule A: Max probability < 0.30 — can't find strong category
        debugLogLine("[NLP-RULE-A] No strong category (max: \(maxProb)), attempting focused keyword re-scan")

        // Re-run with focused keyword search
        let combinedText = "\(textBlocks.mainContent) \(textBlocks.creatorMetadata) \(textBlocks.sponsorMetadata)"
        let keywordRetry = enhancedKeywordDetection(textBlocks: textBlocks, combinedText: combinedText)
        let retryAboveThreshold = keywordRetry.filter { $0.probability >= NLPThresholds.majorCategoryThreshold }

        if !retryAboveThreshold.isEmpty {
            debugLogLine("[NLP-RULE-A] Keyword re-scan found categories: \(retryAboveThreshold.map { "\($0.name): \($0.probability)" })")
            return retryAboveThreshold.sorted { $0.probability > $1.probability }
        }

        // Still nothing — mark as low-confidence / unclassified (defer to vision/audio/cloud)
        debugLogLine("[NLP-RULE-A] Low-confidence / unclassified — deferring to other analysis sources")
        return rawCategories // Return raw for cloud fallback to evaluate
    }
    
    /// Attempt to use CoreML models for classification (if available)
    private func detectWithCoreML(text: String) throws -> [MajorCategory] {
        guard let model = contentSafetyModel else {
            throw NSError(domain: "CoreML", code: 1, userInfo: [NSLocalizedDescriptionKey: "Model not loaded"])
        }
        
        // Preprocess text (limit length for model input)
        let processedText = String(text.prefix(500))
        
        do {
            // Create input for the model
            // Note: The exact input structure depends on how the model was trained
            // Common patterns: text input as String or as MLMultiArray
            let input = ContentSafetyTextClassifierInput(text: processedText)
            
            // Get prediction
            let prediction = try model.prediction(input: input)
            
            // Extract results
            // The output structure depends on the model - could be:
            // - Single label with probability
            // - Dictionary of labels with probabilities
            // - Multi-label output
            
            return processModelOutput(prediction: prediction)
            
        } catch {
            print("⚠️ CoreML prediction error: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Process CoreML model output and convert to MajorCategory array
    private func processModelOutput(prediction: MLFeatureProvider) -> [MajorCategory] {
        var categories: [MajorCategory] = []
        
        // Debug: Print all available output features
        print("🔍 CoreML model output features: \(prediction.featureNames)")
        
        // The output structure depends on how the model was trained
        // We'll try common output formats
        
        // Option 1: Single label output (most common for text classification)
        // Try "label" first
        if let labelFeature = prediction.featureValue(for: "label")?.stringValue {
            print("📋 Found label: \(labelFeature)")
            if let categoryType = mapLabelToCategoryType(label: labelFeature) {
                let probability = prediction.featureValue(for: "labelProbability")?.doubleValue ??
                                 prediction.featureValue(for: "probability")?.doubleValue ?? 0.3
                
                categories.append(MajorCategory(
                    name: categoryType.rawValue,
                    probability: probability,
                    source: .nlp
                ))
                print("✅ Mapped to category: \(categoryType.rawValue) (prob: \(probability))")
            }
        }
        
        // Option 2: Dictionary output with multiple labels and probabilities
        if let labelProbs = prediction.featureValue(for: "labelProbability")?.dictionaryValue as? [String: Double] {
            print("📋 Found labelProbability dictionary with \(labelProbs.count) labels")
            for (label, prob) in labelProbs {
                if let categoryType = mapLabelToCategoryType(label: label), prob > 0.3 {
                    categories.append(MajorCategory(
                        name: categoryType.rawValue,
                        probability: prob,
                        source: .nlp
                    ))
                    print("✅ Mapped \(label) to \(categoryType.rawValue) (prob: \(prob))")
                }
            }
        }
        
        // Option 3: Check for probability dictionary (common in Create ML text classifiers)
        if let probDict = prediction.featureValue(for: "probability")?.dictionaryValue as? [String: Double] {
            print("📋 Found probability dictionary with \(probDict.count) labels")
            for (label, prob) in probDict where prob > 0.3 {
                if let categoryType = mapLabelToCategoryType(label: label) {
                    categories.append(MajorCategory(
                        name: categoryType.rawValue,
                        probability: prob,
                        source: .nlp
                    ))
                    print("✅ Mapped \(label) to \(categoryType.rawValue) (prob: \(prob))")
                }
            }
        }
        
        // Option 4: Check for common output feature names
        let possibleOutputs = ["prediction", "classLabel", "category", "output", "text"]
        for outputName in possibleOutputs {
            if let value = prediction.featureValue(for: outputName) {
                if !value.stringValue.isEmpty {
                    print("📋 Found \(outputName): \(value.stringValue)")
                    if let categoryType = mapLabelToCategoryType(label: value.stringValue) {
                        let prob = prediction.featureValue(for: "\(outputName)Probability")?.doubleValue ??
                                   prediction.featureValue(for: "probability")?.doubleValue ?? 0.7
                        categories.append(MajorCategory(
                            name: categoryType.rawValue,
                            probability: prob,
                            source: .nlp
                        ))
                    }
                } else if let dictValue = value.dictionaryValue as? [String: Double] {
                    print("📋 Found \(outputName) dictionary with \(dictValue.count) entries")
                    for (label, prob) in dictValue where prob > 0.3 {
                        if let categoryType = mapLabelToCategoryType(label: label) {
                            categories.append(MajorCategory(
                                name: categoryType.rawValue,
                                probability: prob,
                                source: .nlp
                            ))
                        }
                    }
                }
            }
        }
        
        // If no categories found, print debug info
        if categories.isEmpty {
            print("⚠️ No categories found in model output. Available features:")
            for featureName in prediction.featureNames {
                if let value = prediction.featureValue(for: featureName) {
                    print("   \(featureName): \(value.type) = \(value)")
                }
            }
        } else {
            print("✅ CoreML model detected \(categories.count) categories")
        }
        
        return categories.sorted { $0.probability > $1.probability }
    }
    
    /// Map model label output to MajorCategoryType
    private func mapLabelToCategoryType(label: String) -> MajorCategoryType? {
        let lowercased = label.lowercased()
        
        // Map common label names to category types
        if lowercased.contains("horror") || lowercased.contains("scary") || lowercased.contains("paranormal") {
            return .violence // Horror content is often categorized under violence
        } else if lowercased.contains("cyberbullying") || lowercased.contains("bullying") || lowercased.contains("harassment") {
            return .platformRisks
        } else if lowercased.contains("parasocial") || lowercased.contains("manipulative") || lowercased.contains("fomo") {
            return .parasocialManipulation
        } else if lowercased.contains("financial") || lowercased.contains("fraud") || lowercased.contains("scam") || lowercased.contains("crypto") {
            return .financialFraud
        } else if lowercased.contains("mature") || lowercased.contains("explicit") || lowercased.contains("sexual") || lowercased.contains("adult") {
            return .explicitBodyContent
        } else if lowercased.contains("violence") || lowercased.contains("weapon") || lowercased.contains("gore") {
            return .violence
        } else if lowercased.contains("substance") || lowercased.contains("drug") || lowercased.contains("alcohol") {
            return .substances
        } else if lowercased.contains("gambling") || lowercased.contains("casino") || lowercased.contains("bet") {
            return .gambling
        } else if lowercased.contains("safe") || lowercased.contains("appropriate") {
            // Safe content - return nil to not add a category
            return nil
        }
        
        // Default: if label doesn't match, try to infer from label name
        // This handles custom label names
        for categoryType in MajorCategoryType.allCases {
            if lowercased.contains(categoryType.rawValue.lowercased()) {
                return categoryType
            }
        }
        
        return nil
    }
    
    /// Enhanced keyword detection using NaturalLanguage framework
    private func enhancedKeywordDetection(textBlocks: NLPTextBlocks, combinedText: String) -> [MajorCategory] {
        var categories: [MajorCategory] = []
        let lowercased = combinedText.lowercased()
        
        // Enhanced keyword lists with context awareness
        let categoryKeywords: [MajorCategoryType: ([String], Double)] = [
            .explicitBodyContent: (["porn", "xxx", "nude", "naked", "sex", "adult", "nsfw", "explicit", "erotic"], 0.85),
            .violence: (["violence", "kill", "murder", "weapon", "gun", "blood", "gore", "torture", "assault"], 0.80),
            .substances: (["weed", "marijuana", "drug", "cocaine", "alcohol", "substance abuse", "addiction"], 0.75),
            .gambling: (["gambling", "casino", "bet", "poker", "lottery", "wager", "odds", "jackpot"], 0.80),
            .parasocialManipulation: (["exclusive", "join now", "limited time", "you owe me", "subscribe now", "don't miss out", "fomo"], 0.70),
            .financialFraud: (["get rich quick", "investment tip", "crypto", "mlm", "pyramid", "guaranteed return", "risk-free"], 0.75)
        ]
        
        // Use NaturalLanguage for sentiment and entity recognition
        let tagger = NLTagger(tagSchemes: [.sentimentScore, .nameType])
        tagger.string = combinedText
        
        var sentimentScore: Double = 0.0
        if let sentiment = tagger.tag(at: combinedText.startIndex, unit: .paragraph, scheme: .sentimentScore).0,
           let score = Double(sentiment.rawValue) {
            sentimentScore = score
        }
        
        // Detect entities (person names, organizations, etc.)
        var detectedEntities: Set<String> = []
        tagger.enumerateTags(in: combinedText.startIndex..<combinedText.endIndex, unit: .word, scheme: .nameType) { tag, tokenRange in
            if tag != nil {
                detectedEntities.insert(String(combinedText[tokenRange]).lowercased())
            }
            return true
        }
        
        // Check each category
        for (category, (keywords, baseProbability)) in categoryKeywords {
            var matchCount = 0
            var strongMatches = 0
            
            for keyword in keywords {
                if lowercased.contains(keyword) {
                    matchCount += 1
                    // Check for strong context indicators
                    if let keywordIndex = lowercased.range(of: keyword) {
                        let contextStart = lowercased.index(keywordIndex.lowerBound, offsetBy: -20, limitedBy: lowercased.startIndex) ?? lowercased.startIndex
                        let contextEnd = lowercased.index(keywordIndex.upperBound, offsetBy: 20, limitedBy: lowercased.endIndex) ?? lowercased.endIndex
                        let context = String(lowercased[contextStart..<contextEnd])

                        // Strong indicators increase probability
                        if context.contains("warning") || context.contains("explicit") || context.contains("adult") {
                            strongMatches += 1
                        }
                    }
                }
            }
            
            if matchCount > 0 {
                // Calculate probability based on matches and context
                let matchRatio = Double(matchCount) / Double(keywords.count)
                let strongMatchBonus = Double(strongMatches) * 0.1
                let sentimentAdjustment = max(0, -sentimentScore) * 0.05 // Only negative sentiment increases risk
                
                let probability = min(baseProbability * matchRatio + strongMatchBonus + sentimentAdjustment, 0.95)
                
                categories.append(MajorCategory(
                    name: category.rawValue,
                    probability: probability,
                    source: .nlp
                ))
            }
        }
        
        return categories.sorted { $0.probability > $1.probability }
    }
    
    private func detectSubcategories(
        textBlocks: NLPTextBlocks,
        majorCategories: [MajorCategory]
    ) -> [Subcategory] {
        var subcategories: [Subcategory] = []
        let combinedText = "\(textBlocks.mainContent) \(textBlocks.creatorMetadata) \(textBlocks.sponsorMetadata)".lowercased()

        // Extended subcategory map with more granular options for ban-sensitive expansion
        let subcategoryMap: [String: [(String, Double)]] = [
            MajorCategoryType.explicitBodyContent.rawValue: [
                ("Sexual content", 0.8),
                ("Nudity", 0.75),
                ("Adult themes", 0.70),
                ("Indecent clothing or speech", 0.65),
                ("Suggestive content", 0.60),
                ("Sexual education", 0.55),
                ("Body modification", 0.50),
                ("Beauty filters / unrealistic standards", 0.45)
            ],
            MajorCategoryType.violence.rawValue: [
                ("Graphic violence", 0.85),
                ("Non-graphic cartoon violence", 0.60),
                ("Weapons", 0.75),
                ("Gore", 0.80),
                ("Physical harm", 0.70),
                ("Heavy fighting (WWE/MMA)", 0.65),
                ("Horror / Paranormal", 0.55),
                ("Crime news", 0.50)
            ],
            MajorCategoryType.selfHarm.rawValue: [
                ("Self-harm depiction", 0.90),
                ("Suicide ideation", 0.90),
                ("Self-harm recovery content", 0.60),
                ("Mental health crisis", 0.70)
            ],
            MajorCategoryType.extremism.rawValue: [
                ("Extremist content", 0.90),
                ("Radicalization", 0.85),
                ("Hate speech", 0.80),
                ("Discrimination", 0.75),
                ("Terrorist propaganda", 0.90)
            ],
            MajorCategoryType.substances.rawValue: [
                ("Drug use", 0.80),
                ("Alcohol", 0.70),
                ("Substance abuse", 0.75),
                ("Tobacco / vaping", 0.65)
            ],
            MajorCategoryType.gambling.rawValue: [
                ("Online gambling", 0.80),
                ("Casino games", 0.75),
                ("Betting", 0.70),
                ("Loot boxes / gacha", 0.65)
            ],
            MajorCategoryType.parasocialManipulation.rawValue: [
                ("FOMO tactics", 0.75),
                ("Manipulative language", 0.70),
                ("Pressure to subscribe", 0.65),
                ("Parasocial relationship exploitation", 0.60)
            ],
            MajorCategoryType.financialFraud.rawValue: [
                ("Investment scams", 0.80),
                ("Cryptocurrency risks", 0.75),
                ("MLM schemes", 0.70),
                ("Get-rich-quick", 0.75),
                ("Online financial advice", 0.60),
                ("Speculative finance", 0.65)
            ]
        ]

        // Subcategory-specific keyword lists
        let subcatKeywords: [String: [String]] = [
            "Sexual content": ["sexual", "intimate", "romance", "erotic"],
            "Nudity": ["nude", "naked", "undressed", "nsfw"],
            "Adult themes": ["adult", "mature", "18+"],
            "Indecent clothing or speech": ["revealing", "indecent", "provocative"],
            "Suggestive content": ["suggestive", "sexy", "sensual"],
            "Sexual education": ["sex ed", "reproductive", "puberty", "sexual health"],
            "Body modification": ["tattoo", "piercing", "modification"],
            "Beauty filters / unrealistic standards": ["filter", "beauty", "body image"],
            "Graphic violence": ["gore", "blood", "brutal", "graphic"],
            "Non-graphic cartoon violence": ["cartoon", "animated", "slapstick"],
            "Weapons": ["gun", "knife", "weapon", "firearm"],
            "Gore": ["gore", "dismember", "mutilat"],
            "Physical harm": ["assault", "attack", "beating"],
            "Heavy fighting (WWE/MMA)": ["wrestling", "wwe", "mma", "ufc", "fighting"],
            "Horror / Paranormal": ["horror", "ghost", "paranormal", "scary", "haunted"],
            "Crime news": ["crime", "murder", "robbery", "arrest"],
            "Self-harm depiction": ["self-harm", "cutting", "self harm"],
            "Suicide ideation": ["suicide", "kill myself", "end my life"],
            "Self-harm recovery content": ["recovery", "healing", "survived"],
            "Mental health crisis": ["crisis", "breakdown", "despair"],
            "Extremist content": ["extremist", "radical", "jihadist"],
            "Radicalization": ["radicalize", "indoctrinate", "recruit"],
            "Hate speech": ["hate speech", "slur", "bigot"],
            "Discrimination": ["discrimination", "racist", "sexist"],
            "Terrorist propaganda": ["terrorist", "bombing", "attack plan"],
            "Drug use": ["drug", "substance", "illegal", "cocaine", "heroin"],
            "Alcohol": ["alcohol", "beer", "wine", "drunk", "drinking"],
            "Substance abuse": ["abuse", "addiction", "overdose"],
            "Tobacco / vaping": ["tobacco", "vape", "vaping", "cigarette", "smoking"],
            "Online gambling": ["gambling", "casino", "slot"],
            "Casino games": ["casino", "blackjack", "roulette"],
            "Betting": ["bet", "wager", "odds", "sportsbook"],
            "Loot boxes / gacha": ["loot box", "gacha", "lootbox", "microtransaction"],
            "FOMO tactics": ["limited", "exclusive", "now or never", "don't miss"],
            "Manipulative language": ["you owe", "you need", "everyone is"],
            "Pressure to subscribe": ["subscribe now", "join now", "sign up"],
            "Parasocial relationship exploitation": ["personal connection", "just for you", "our relationship"],
            "Investment scams": ["guaranteed return", "risk-free", "get rich", "double your money"],
            "Cryptocurrency risks": ["crypto", "bitcoin", "token", "nft", "blockchain invest"],
            "MLM schemes": ["mlm", "pyramid", "downline", "network marketing"],
            "Get-rich-quick": ["get rich", "millionaire", "passive income", "financial freedom"],
            "Online financial advice": ["financial advice", "stock tip", "investment advice"],
            "Speculative finance": ["speculative", "high risk", "volatile"]
        ]

        // Generate subcategories based on detected major categories
        for majorCategory in majorCategories {
            // Determine subcategory limit based on ban-sensitive status
            let isBanSensitive: Bool
            if let categoryType = MajorCategoryType(rawValue: majorCategory.name) {
                isBanSensitive = NLPThresholds.banSensitiveCategories.contains(categoryType)
            } else {
                isBanSensitive = false
            }
            let subcatLimit = isBanSensitive ? NLPThresholds.banSensitiveSubcatLimit : NLPThresholds.standardSubcatLimit

            if let subcats = subcategoryMap[majorCategory.name] {
                var candidateSubcats: [Subcategory] = []

                for (subcatName, baseProb) in subcats.prefix(subcatLimit) {
                    // Adjust probability based on major category confidence
                    let adjustedProb = majorCategory.probability * baseProb

                    var finalProb = adjustedProb
                    if let keywords = subcatKeywords[subcatName] {
                        let hasKeywords = keywords.contains { combinedText.contains($0) }
                        if hasKeywords {
                            finalProb = min(finalProb + 0.1, 0.95)
                        }
                    }

                    // Use spec threshold of 0.30 (lowered from 0.5)
                    if finalProb >= NLPThresholds.subcategoryThreshold {
                        candidateSubcats.append(Subcategory(
                            name: subcatName,
                            source: .nlp,
                            probability: finalProb,
                            majorCategory: majorCategory.name
                        ))
                    }
                }

                // Apply cluster rule to select the right subcategory
                let (primary, isAmbiguous) = applyClusterRule(subcategories: candidateSubcats)

                if isAmbiguous {
                    // Case 3: Ambiguous — include all candidates and let cloud/vision resolve
                    debugLogLine("[CLUSTER] Ambiguous subcategories for \(majorCategory.name) — deferring to multi-source analysis")
                    subcategories.append(contentsOf: candidateSubcats)
                } else if let primary = primary {
                    // Case 1 or 2: Use primary (most restrictive in cluster, or single)
                    subcategories.append(primary)
                }
            }
        }

        return subcategories.sorted { $0.probability > $1.probability }
    }

    /// Apply cluster rule per spec:
    /// - Case 1: Multiple subcats in tight cluster (±10pp) → pick most restrictive
    /// - Case 2: Single subcat above threshold → use directly
    /// - Case 3: None above threshold OR > 5 above threshold → ambiguous
    private func applyClusterRule(
        subcategories: [Subcategory]
    ) -> (primary: Subcategory?, isAmbiguous: Bool) {
        guard !subcategories.isEmpty else {
            return (nil, false)
        }

        // Case 3: Too many above threshold → ambiguous
        if subcategories.count > NLPThresholds.ambiguousSubcatLimit {
            return (nil, true)
        }

        // Case 2: Single subcategory
        if subcategories.count == 1 {
            return (subcategories.first, false)
        }

        // Case 1: Multiple subcategories — detect tight cluster
        let sorted = subcategories.sorted { $0.probability > $1.probability }
        guard let topProb = sorted.first?.probability else {
            return (nil, false)
        }

        // Cluster: all subcats within ±10pp of top
        let cluster = sorted.filter { topProb - $0.probability <= NLPThresholds.clusterTolerance }

        if cluster.count > 1 {
            // Pick the most restrictive subcategory in the cluster
            // "Most restrictive" = the one whose name maps to the harshest filter action
            // We rank by how likely the name maps to BLOCK vs GATE vs ALLOW
            let ranked = cluster.sorted { a, b in
                restrictiveRank(subcatName: a.name) > restrictiveRank(subcatName: b.name)
            }
            debugLogLine("[CLUSTER] Tight cluster of \(cluster.count) subcats, selected most restrictive: \(ranked.first?.name ?? "none")")
            return (ranked.first, false)
        }

        // No tight cluster — just return top
        return (sorted.first, false)
    }

    /// Rank how restrictive a subcategory name is (higher = more restrictive)
    private func restrictiveRank(subcatName: String) -> Int {
        let lower = subcatName.lowercased()
        // Explicit/severe content → highest restriction rank
        if lower.contains("explicit") || lower.contains("sexual content") || lower.contains("nudity") ||
           lower.contains("graphic") || lower.contains("gore") || lower.contains("self-harm") ||
           lower.contains("suicide") || lower.contains("extremist") || lower.contains("terrorist") {
            return 3
        }
        // Moderate content
        if lower.contains("weapon") || lower.contains("drug") || lower.contains("gambling") ||
           lower.contains("scam") || lower.contains("violence") || lower.contains("hate") ||
           lower.contains("fighting") || lower.contains("alcohol") || lower.contains("crime") {
            return 2
        }
        // Mild content
        if lower.contains("suggestive") || lower.contains("mature") || lower.contains("fomo") ||
           lower.contains("beauty") || lower.contains("cartoon") || lower.contains("subscribe") {
            return 1
        }
        return 0
    }
    
    // MARK: - Step 4: Vision Analysis

    private func analyzeVision(input: ContentAnalysisInput, filterPreferences: ContentFilterPreferences) async -> VisionResult {
        #if os(iOS)
        return await _analyzeVisionIOS(input: input, filterPreferences: filterPreferences)
        #else
        return VisionResult(subcategories: [], confidence: 0.0, used: false)
        #endif
    }

    #if os(iOS)
    private func _analyzeVisionIOS(input: ContentAnalysisInput, filterPreferences: ContentFilterPreferences) async -> VisionResult {
        guard let media = input.media, !media.images.isEmpty else {
            return VisionResult(subcategories: [], confidence: 0.0, used: false)
        }
        
        var detectedSubcategories: [Subcategory] = []
        var maxConfidence: Double = 0.0
        
        // Use ImageFilterService for NSFW detection
        let imageFilterService = ImageFilterService.shared
        
        // Analyze each image using NSFW detection
        for imageInfo in media.images {
            if let urlString = imageInfo.url,
               let imageURL = URL(string: urlString) {
                
                // Skip data URLs and very small images (likely icons)
                if urlString.hasPrefix("data:") {
                    continue
                }
                
                // Skip ads and sponsor logos (lower priority for NSFW detection)
                if imageInfo.type == "ad" || imageInfo.type == "sponsor_logo" {
                    continue
                }
                
                // Use ImageFilterService to analyze the image with NSFW model
                let analysisResult = await imageFilterService.analyzeImage(
                    url: imageURL,
                    preferences: filterPreferences
                )
                
                // Map ImageContentCategory to Subcategory
                if analysisResult.shouldFilter || analysisResult.confidence > 0.3 {
                    let subcategoryName: String
                    let majorCategory: String
                    
                    switch analysisResult.category {
                    case .explicit:
                        subcategoryName = "Explicit image content detected"
                        majorCategory = MajorCategoryType.explicitBodyContent.rawValue
                    case .suggestive:
                        subcategoryName = "Suggestive image content detected"
                        majorCategory = MajorCategoryType.explicitBodyContent.rawValue
                    case .violence:
                        subcategoryName = "Violent image content detected"
                        majorCategory = MajorCategoryType.violence.rawValue
                    case .gore:
                        subcategoryName = "Graphic/gore image content detected"
                        majorCategory = MajorCategoryType.violence.rawValue
                    case .drugs:
                        subcategoryName = "Drug-related image content detected"
                        majorCategory = MajorCategoryType.substances.rawValue
                    case .weapons:
                        subcategoryName = "Weapon-related image content detected"
                        majorCategory = MajorCategoryType.violence.rawValue
                    default:
                        // Skip safe/neutral images
                        continue
                    }
                    
                    let probability = Double(analysisResult.confidence)
                    detectedSubcategories.append(Subcategory(
                        name: subcategoryName,
                        source: .vision,
                        probability: probability,
                        majorCategory: majorCategory
                    ))
                    maxConfidence = max(maxConfidence, probability)
                    
                    print("🛡️ Vision analysis: \(subcategoryName) (confidence: \(Int(probability * 100))%)")
                }
            }
        }
        
        return VisionResult(
            subcategories: detectedSubcategories,
            confidence: maxConfidence,
            used: !detectedSubcategories.isEmpty
        )
    }
    #endif

    // MARK: - Step 5: Audio Analysis
    //
    // Audio analysis via the JS bridge is not implemented: the JS bridge never
    // populates AudioInfo.hasSpeech, so this pipeline never executes. It returns
    // an empty result and is kept as a placeholder for future implementation.

    private func analyzeAudio(input: ContentAnalysisInput) async -> AudioResult {
        return AudioResult(subcategories: [], confidence: 0.0, used: false)
    }
    
    // MARK: - Step 6: Links Analysis
    
    private func analyzeLinks(input: ContentAnalysisInput) async -> LinksResult {
        guard let metadata = input.extraMetadata else {
            return LinksResult(subcategories: [], confidence: 0.0, used: false)
        }
        
        var riskSubcategories: [Subcategory] = []
        
        // Analyze sponsor links
        for sponsor in metadata.sponsors {
            if let sponsorRisk = analyzeSponsorLink(sponsor: sponsor) {
                riskSubcategories.append(sponsorRisk)
            }
        }
        
        // Analyze external links
        for link in metadata.links where link.linkType == "sponsor" || link.linkType == "affiliate" {
            if let linkRisk = analyzeExternalLink(link: link) {
                riskSubcategories.append(linkRisk)
            }
        }
        
        return LinksResult(
            subcategories: riskSubcategories,
            confidence: riskSubcategories.isEmpty ? 0.0 : 0.7,
            used: !riskSubcategories.isEmpty
        )
    }
    
    private func analyzeSponsorLink(sponsor: SponsorInfo) -> Subcategory? {
        let name = sponsor.name.lowercased()
        let context = (sponsor.context ?? "").lowercased()
        let combined = "\(name) \(context)"
        
        // Check for high-risk sponsor types
        if combined.contains("gambling") || combined.contains("casino") || combined.contains("bet") {
            return Subcategory(
                name: "Gambling sponsor link",
                source: .links,
                probability: 0.8,
                majorCategory: MajorCategoryType.gambling.rawValue
            )
        }
        
        if combined.contains("crypto") || combined.contains("investment") || combined.contains("trading") {
            return Subcategory(
                name: "Speculative finance sponsor",
                source: .links,
                probability: 0.7,
                majorCategory: MajorCategoryType.financialFraud.rawValue
            )
        }
        
        return nil
    }
    
    private func analyzeExternalLink(link: LinkInfo) -> Subcategory? {
        // Lightweight on-device classification
        let domain = link.domain.lowercased()
        
        // Check for known risky domains (could be expanded with a local database)
        if domain.contains("gambling") || domain.contains("casino") {
            return Subcategory(
                name: "Gambling external link",
                source: .links,
                probability: 0.75,
                majorCategory: MajorCategoryType.gambling.rawValue
            )
        }
        
        return nil
    }
    
    // MARK: - Step 7: Merge Decisions
    
    private func mergeAllDecisions(
        url: String = "",
        nlp: NLPResult,
        vision: VisionResult,
        audio: AudioResult,
        links: LinksResult,
        cloud: CloudResult?,
        ageBand: AgeBand,
        filterPreferences: ContentFilterPreferences
    ) -> UnifiedDecisionResponse {
        // Build per-band decisions: each age band gets its own filter preferences
        var allAgeActions: [String: AgeAction] = [:]
        var primaryMergedAction: AgeAction?

        for band in AgeBand.allCases {
            // Resolve the correct ContentFilterPreferences for THIS age band
            let bandPreferences = ContentFilterPreferences.defaults(for: band.toAgeGroup())

            // Convert each source to age actions using this band's preferences
            let nlpActions = convertToAgeActions(nlp.subcategories, source: .nlp, ageBand: band, filterPreferences: bandPreferences)
            let visionActions = convertToAgeActions(vision.subcategories, source: .vision, ageBand: band, filterPreferences: bandPreferences)
            let audioActions = convertToAgeActions(audio.subcategories, source: .audio, ageBand: band, filterPreferences: bandPreferences)
            let linksActions = convertToAgeActions(links.subcategories, source: .links, ageBand: band, filterPreferences: bandPreferences)
            let cloudActions = cloud != nil ? convertToAgeActions(cloud!.subcategories, source: .cloud, ageBand: band, filterPreferences: bandPreferences) : nil

            // Merge using most restrictive rule (BLOCK > GATE > ALLOW) for THIS band
            let candidates: [AgeAction] = [
                nlpActions[band.rawValue],
                visionActions[band.rawValue],
                audioActions[band.rawValue],
                linksActions[band.rawValue],
                cloudActions?[band.rawValue]
            ].compactMap { $0 }
            let mergedAction: AgeAction = candidates.first(where: { $0.action == .block })
                ?? candidates.first(where: { $0.action == .gate })
                ?? candidates.first
                ?? AgeAction(action: .allow, score: 0.0, reason: nil, risks: nil)

            allAgeActions[band.rawValue] = mergedAction

            // Track the primary (requesting) band's action for overall score
            if band == ageBand {
                primaryMergedAction = mergedAction
            }
        }

        let effectiveAction = primaryMergedAction ?? allAgeActions[ageBand.rawValue] ?? AgeAction(action: .gate, score: 0.5, reason: "Fallback", risks: nil)

        // Combine all subcategories
        let allSubcategories = nlp.subcategories + vision.subcategories + audio.subcategories + links.subcategories + (cloud?.subcategories ?? [])

        // Combine all major categories
        let allMajorCategories = nlp.majorCategories + (cloud?.majorCategories ?? [])

        return UnifiedDecisionResponse(
            url: url,
            overallSafetyScore: 1.0 - effectiveAction.score,
            languageSafetyScore: nlp.used ? (1.0 - (nlp.confidence * 0.3)) : 0.0,
            visualSafetyScore: vision.used ? (1.0 - (vision.confidence * 0.3)) : 0.0,
            audioSafetyScore: audio.used ? (1.0 - (audio.confidence * 0.3)) : 0.0,
            ageActions: allAgeActions,
            majorCategories: allMajorCategories,
            subcategories: allSubcategories,
            contextType: nil,
            topicTags: extractTopicTags(subcategories: allSubcategories),
            flags: extractSafetyFlags(subcategories: allSubcategories),
            decisionSource: DecisionSource(
                nlp: SourceInfo(used: nlp.used, confidence: nlp.confidence),
                vision: SourceInfo(used: vision.used, confidence: vision.confidence),
                audio: SourceInfo(used: audio.used, confidence: audio.confidence),
                links: SourceInfo(used: links.used, confidence: links.confidence),
                cloud: SourceInfo(used: cloud != nil, confidence: cloud?.confidence ?? 0.0)
            ),
            timestamp: ContentAnalysisService.iso8601Formatter.string(from: Date()),
            historyCategory: allMajorCategories.first?.name,
            historySubcategory: allSubcategories.first?.name,
            revealingLevel: nil
        )
    }

    private func convertToAgeActions(
        _ subcategories: [Subcategory],
        source: DecisionSourceType,
        ageBand: AgeBand,
        filterPreferences: ContentFilterPreferences
    ) -> [String: AgeAction] {
        // Map subcategories to age-specific actions using the provided band's filter preferences
        let action: Action
        let score: Double
        var reason: String?

        if let topSubcat = subcategories.first {
            score = topSubcat.probability

            // Map detected category/subcategory to this band's filter preference
            let userPreference = getFilterPreferenceForCategory(
                category: topSubcat.majorCategory ?? "",
                subcategory: topSubcat.name,
                preferences: filterPreferences
            )

            // Use preference if available, otherwise use probability-based logic
            if let userAction = userPreference {
                action = userAction.toAction()
                reason = "Based on content filter settings for \(ageBand.displayName)"
            } else {
                // Fallback: use probability-based logic with age sensitivity
                if score > 0.7 {
                    action = ageBand == .below10 || ageBand == .age10_13 ? .block : .gate
                } else if score > 0.5 {
                    action = .gate
                } else {
                    action = .allow
                }
                reason = topSubcat.name
            }
        } else {
            action = .allow
            score = 0.0
            reason = nil
        }

        // Return action keyed to THIS specific band only
        return [ageBand.rawValue: AgeAction(
            action: action,
            score: score,
            reason: reason ?? subcategories.first?.name,
            risks: subcategories.map { $0.name }
        )]
    }
    
    /// Map detected category/subcategory to user's ContentFilterPreferences
    private func getFilterPreferenceForCategory(
        category: String,
        subcategory: String,
        preferences: ContentFilterPreferences
    ) -> FilterAction? {
        let lowerCategory = category.lowercased()
        let lowerSubcat = subcategory.lowercased()
        
        // Map major categories to preferences
        if lowerCategory.contains("violence") || lowerCategory.contains("violent") {
            if lowerSubcat.contains("graphic") {
                return preferences.graphicViolence
            } else if lowerSubcat.contains("non-graphic") || lowerSubcat.contains("cartoon") {
                return preferences.nonGraphicViolence
            } else if lowerSubcat.contains("fighting") || lowerSubcat.contains("wwe") {
                return preferences.heavyFighting
            } else if lowerSubcat.contains("horror") || lowerSubcat.contains("paranormal") {
                return preferences.horrorParanormal
            } else if lowerSubcat.contains("crime") || lowerSubcat.contains("news") {
                return preferences.crimeNews
            }
            // Default violence preference
            return preferences.graphicViolence
        }
        
        if lowerCategory.contains("explicit") || lowerCategory.contains("sexual") || lowerCategory.contains("body") {
            if lowerSubcat.contains("explicit") || lowerSubcat.contains("sexual") {
                return preferences.explicitSexual
            } else if lowerSubcat.contains("education") || lowerSubcat.contains("medical") {
                return preferences.sexualEducation
            } else if lowerSubcat.contains("mature") {
                return preferences.matureContent
            } else if lowerSubcat.contains("indecent") || lowerSubcat.contains("revealing") {
                return preferences.indecentContent
            } else if lowerSubcat.contains("modification") || lowerSubcat.contains("tattoo") {
                return preferences.bodyModification
            } else if lowerSubcat.contains("filter") || lowerSubcat.contains("beauty") {
                return preferences.beautyFilters
            }
            // Default explicit content preference
            return preferences.explicitSexual
        }
        
        if lowerCategory.contains("substance") || lowerCategory.contains("drug") || lowerCategory.contains("alcohol") {
            if lowerSubcat.contains("alcohol") {
                return preferences.alcoholContent
            }
            // Default substance preference
            return preferences.alcoholContent
        }
        
        if lowerCategory.contains("gambling") || lowerCategory.contains("casino") || lowerCategory.contains("bet") {
            return preferences.gamblingLootboxes
        }
        
        if lowerCategory.contains("parasocial") || lowerCategory.contains("manipulative") {
            return preferences.parasocialContent
        }
        
        if lowerCategory.contains("financial") || lowerCategory.contains("fraud") || lowerCategory.contains("scam") {
            if lowerSubcat.contains("speculative") || lowerSubcat.contains("crypto") {
                return preferences.speculativeFinance
            } else if lowerSubcat.contains("get rich") || lowerSubcat.contains("quick") {
                return preferences.getRichQuick
            } else if lowerSubcat.contains("advice") {
                return preferences.onlineFinancialAdvice
            } else if lowerSubcat.contains("subscription") {
                return preferences.subscriptionPages
            }
            // Default financial preference
            return preferences.speculativeFinance
        }
        
        if lowerCategory.contains("platform") || lowerCategory.contains("media") {
            if lowerSubcat.contains("short") || lowerSubcat.contains("video") {
                return preferences.shortFormVideos
            } else if lowerSubcat.contains("live") || lowerSubcat.contains("stream") {
                return preferences.liveStreams
            } else if lowerSubcat.contains("gaming") || lowerSubcat.contains("game") {
                return preferences.gamingContent
            } else if lowerSubcat.contains("ai") || lowerSubcat.contains("generated") {
                return preferences.aiGeneratedContent
            }
        }
        
        if lowerCategory.contains("social") || lowerCategory.contains("cultural") {
            if lowerSubcat.contains("lgbtq") || lowerSubcat.contains("lgbt") {
                return preferences.lgbtqTopics
            } else if lowerSubcat.contains("religion") || lowerSubcat.contains("religious") {
                return preferences.religion
            } else if lowerSubcat.contains("immigration") {
                return preferences.immigration
            } else if lowerSubcat.contains("communism") || lowerSubcat.contains("political") {
                return preferences.communism
            } else if lowerSubcat.contains("discrimination") || lowerSubcat.contains("hate") {
                return preferences.discriminationHateSpeech
            } else if lowerSubcat.contains("gun") || lowerSubcat.contains("weapon") {
                return preferences.gunsWeapons
            } else if lowerSubcat.contains("extremist") || lowerSubcat.contains("extremism") {
                return preferences.extremistContent
            }
        }
        
        // No matching preference found
        return nil
    }
    
    private func extractTopicTags(subcategories: [Subcategory]) -> [String] {
        return Array(Set(subcategories.map { $0.name.lowercased() })).prefix(10).map { String($0) }
    }
    
    private func extractSafetyFlags(subcategories: [Subcategory]) -> SafetyFlags {
        let names = subcategories.map { $0.name.lowercased() }.joined(separator: " ")
        
        return SafetyFlags(
            bodyAnxiety: names.contains("body") || names.contains("anxiety"),
            selfHarm: names.contains("self-harm") || names.contains("suicide"),
            fraudOrScam: names.contains("fraud") || names.contains("scam"),
            extremism: names.contains("extremist") || names.contains("terror"),
            lgbtqFlagPresent: nil, // Would need specific detection
            gambling: names.contains("gambling") || names.contains("casino"),
            parasocial: names.contains("parasocial") || names.contains("manipulative"),
            substanceAbuse: names.contains("drug") || names.contains("substance")
        )
    }
    
    private func buildUnifiedResponse(
        url: String,
        nlp: NLPResult,
        vision: VisionResult,
        audio: AudioResult,
        links: LinksResult,
        cloud: CloudResult?,
        mergedDecision: UnifiedDecisionResponse,
        input: ContentAnalysisInput
    ) -> UnifiedDecisionResponse {
        // Update URL and context type
        // This is a workaround since Swift structs are value types
        return UnifiedDecisionResponse(
            url: url,
            overallSafetyScore: mergedDecision.overallSafetyScore,
            languageSafetyScore: mergedDecision.languageSafetyScore,
            visualSafetyScore: mergedDecision.visualSafetyScore,
            audioSafetyScore: mergedDecision.audioSafetyScore,
            ageActions: mergedDecision.ageActions,
            majorCategories: mergedDecision.majorCategories,
            subcategories: mergedDecision.subcategories,
            contextType: input.structuralMetadata?.pageType.rawValue,
            topicTags: mergedDecision.topicTags,
            flags: mergedDecision.flags,
            decisionSource: mergedDecision.decisionSource,
            timestamp: mergedDecision.timestamp,
            historyCategory: mergedDecision.historyCategory,
            historySubcategory: mergedDecision.historySubcategory,
            revealingLevel: mergedDecision.revealingLevel
        )
    }

    // MARK: - Step 8: Cloud Fallback
    
    private func shouldUseCloudFallback(
        nlp: NLPResult,
        vision: VisionResult,
        audio: AudioResult,
        links: LinksResult
    ) -> Bool {
        // 0. Always use cloud if NO on-device source produced results
        //    (e.g., search queries where htmlText is nil — CoreML on empty text is noise)
        if !nlp.used && !vision.used && !audio.used && !links.used {
            print("☁️ Cloud fallback: no on-device source produced results")
            return true
        }

        // Use cloud if:
        // 1. No major category reaches threshold (0.30)
        let maxNLPProb = nlp.majorCategories.map { $0.probability }.max() ?? 0.0
        if maxNLPProb < 0.15 {
            return true
        }
        
        // 2. All sources are low confidence
        if nlp.confidence < 0.3 && vision.confidence < 0.3 && audio.confidence < 0.3 && links.confidence < 0.3 {
            return true
        }
        
        // 3. Conflicting signals (many subcategories but unclear)
        let totalSubcats = nlp.subcategories.count + vision.subcategories.count + audio.subcategories.count
        if totalSubcats > 10 {
            return true
        }
        
        return false
    }
    
    private lazy var scanNetworkService = ScanNetworkService()

    private func callCloudFallback(url: String, input: ContentAnalysisInput, searchQuery: String? = nil) async throws -> CloudResult {
        let apiResult = try await scanNetworkService.scanURLWithFormat(url, searchQuery: searchQuery)

        switch apiResult {
        case .unified(let decision):
            return convertUnifiedToCloudResult(decision)
        case .legacy(let response):
            return convertScanResponseToCloudResult(response)
        }
    }

    private func convertUnifiedToCloudResult(_ decision: UnifiedDecisionResponse) -> CloudResult {
        return CloudResult(
            majorCategories: decision.majorCategories.map {
                MajorCategory(name: $0.name, probability: $0.probability, source: .cloud)
            },
            subcategories: decision.subcategories.map {
                Subcategory(name: $0.name, source: .cloud, probability: $0.probability, majorCategory: $0.majorCategory)
            },
            confidence: 0.85,
            unifiedResponse: decision
        )
    }

    private func convertScanResponseToCloudResult(_ response: ScanResponse) -> CloudResult {
        let majorCategories = response.childSafetyAnalysis.riskCategories.map {
            MajorCategory(
                name: $0.category,
                probability: min(Double($0.matchCount) / 10.0, 1.0), // Normalize, capped at 1.0
                source: .cloud
            )
        }

        let subcategories = response.childSafetyAnalysis.riskCategories.map {
            Subcategory(
                name: $0.category,
                source: .cloud,
                probability: min(Double($0.matchCount) / 10.0, 1.0),
                majorCategory: $0.category
            )
        }

        return CloudResult(
            majorCategories: majorCategories,
            subcategories: subcategories,
            confidence: 0.8
        )
    }
}

// MARK: - Intermediate Result Types

struct NLPResult {
    let majorCategories: [MajorCategory]
    let subcategories: [Subcategory]
    let confidence: Double
    let used: Bool
}

struct VisionResult {
    let subcategories: [Subcategory]
    let confidence: Double
    let used: Bool
}

struct AudioResult {
    let subcategories: [Subcategory]
    let confidence: Double
    let used: Bool
}

struct LinksResult {
    let subcategories: [Subcategory]
    let confidence: Double
    let used: Bool
}

struct CloudResult {
    let majorCategories: [MajorCategory]
    let subcategories: [Subcategory]
    let confidence: Double
    /// When the cloud returned a full UnifiedDecisionResponse, preserve it so the
    /// caller can use the server's pre-computed age actions directly.
    let unifiedResponse: UnifiedDecisionResponse?

    init(majorCategories: [MajorCategory], subcategories: [Subcategory], confidence: Double, unifiedResponse: UnifiedDecisionResponse? = nil) {
        self.majorCategories = majorCategories
        self.subcategories = subcategories
        self.confidence = confidence
        self.unifiedResponse = unifiedResponse
    }
}

struct NLPTextBlocks {
    let mainContent: String
    let creatorMetadata: String
    let sponsorMetadata: String
    let linkContext: String
}
