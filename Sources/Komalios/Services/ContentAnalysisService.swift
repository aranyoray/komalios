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
import Speech
import CoreML
import UIKit

@MainActor
final class ContentAnalysisService {
    static let shared = ContentAnalysisService()
    
    private init() {
        setupNLP()
    }
    
    // MARK: - NLP Setup
    private var nlpSentimentAnalyzer: NLModel?
    private let nlpQueue = DispatchQueue(label: "com.komalios.nlp", qos: .userInitiated)
    
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
        filterPreferences: ContentFilterPreferences
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
        if shouldUseCloudFallback(
            nlp: nlpResult,
            vision: visionResult,
            audio: audioResult,
            links: linksResult
        ) {
            // Call cloud API as fallback
            let cloudResult = try await callCloudFallback(url: url, input: input)
            return mergeAllDecisions(
                nlp: nlpResult,
                vision: visionResult,
                audio: audioResult,
                links: linksResult,
                cloud: cloudResult,
                ageBand: ageBand,
                filterPreferences: filterPreferences
            )
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
            timestamp: ISO8601DateFormatter().string(from: Date()),
            historyCategory: "Custom Rules",
            historySubcategory: "Parent Blocked"
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
    
    private func detectMajorCategories(textBlocks: NLPTextBlocks) -> [MajorCategory] {
        // Use NaturalLanguage framework for improved detection
        let combinedText = "\(textBlocks.mainContent) \(textBlocks.creatorMetadata) \(textBlocks.sponsorMetadata)"
        
        // Try CoreML models first (if available)
        do {
            let mlResult = try detectWithCoreML(text: combinedText)
            if !mlResult.isEmpty {
                print("✅ Using CoreML model for category detection")
                return mlResult
            }
        } catch {
            print("⚠️ CoreML detection failed, using keyword fallback: \(error.localizedDescription)")
        }
        
        // Fallback to enhanced keyword-based detection with NaturalLanguage
        print("📝 Using enhanced keyword detection")
        return enhancedKeywordDetection(textBlocks: textBlocks, combinedText: combinedText)
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
            let input = try ContentSafetyTextClassifierInput(text: processedText)
            
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
                                 prediction.featureValue(for: "probability")?.doubleValue ?? 0.8
                
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
            if let tag = tag {
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
                    let keywordIndex = lowercased.range(of: keyword)!
                    let contextStart = max(lowercased.startIndex, lowercased.index(keywordIndex.lowerBound, offsetBy: -20))
                    let contextEnd = min(lowercased.endIndex, lowercased.index(keywordIndex.upperBound, offsetBy: 20))
                    let context = String(lowercased[contextStart..<contextEnd])
                    
                    // Strong indicators increase probability
                    if context.contains("warning") || context.contains("explicit") || context.contains("adult") {
                        strongMatches += 1
                    }
                }
            }
            
            if matchCount > 0 {
                // Calculate probability based on matches and context
                let matchRatio = Double(matchCount) / Double(keywords.count)
                let strongMatchBonus = Double(strongMatches) * 0.1
                let sentimentAdjustment = abs(sentimentScore) * 0.05 // Negative sentiment increases risk
                
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
        
        // Map major categories to their subcategories
        let subcategoryMap: [String: [(String, Double)]] = [
            MajorCategoryType.explicitBodyContent.rawValue: [
                ("Sexual content", 0.8),
                ("Nudity", 0.75),
                ("Adult themes", 0.70)
            ],
            MajorCategoryType.violence.rawValue: [
                ("Graphic violence", 0.85),
                ("Weapons", 0.75),
                ("Gore", 0.80),
                ("Physical harm", 0.70)
            ],
            MajorCategoryType.substances.rawValue: [
                ("Drug use", 0.80),
                ("Alcohol", 0.70),
                ("Substance abuse", 0.75)
            ],
            MajorCategoryType.gambling.rawValue: [
                ("Online gambling", 0.80),
                ("Casino games", 0.75),
                ("Betting", 0.70)
            ],
            MajorCategoryType.parasocialManipulation.rawValue: [
                ("FOMO tactics", 0.75),
                ("Manipulative language", 0.70),
                ("Pressure to subscribe", 0.65)
            ],
            MajorCategoryType.financialFraud.rawValue: [
                ("Investment scams", 0.80),
                ("Cryptocurrency risks", 0.75),
                ("MLM schemes", 0.70)
            ]
        ]
        
        // Generate subcategories based on detected major categories
        for majorCategory in majorCategories {
            if let subcats = subcategoryMap[majorCategory.name] {
                for (subcatName, baseProb) in subcats {
                    // Adjust probability based on major category confidence
                    let adjustedProb = majorCategory.probability * baseProb
                    
                    // Check for subcategory-specific keywords
                    let subcatKeywords: [String: [String]] = [
                        "Sexual content": ["sexual", "intimate", "romance"],
                        "Nudity": ["nude", "naked", "undressed"],
                        "Graphic violence": ["gore", "blood", "brutal"],
                        "Weapons": ["gun", "knife", "weapon"],
                        "Drug use": ["drug", "substance", "illegal"],
                        "FOMO tactics": ["limited", "exclusive", "now"],
                        "Investment scams": ["guaranteed", "risk-free", "get rich"]
                    ]
                    
                    var finalProb = adjustedProb
                    if let keywords = subcatKeywords[subcatName] {
                        let hasKeywords = keywords.contains { combinedText.contains($0) }
                        if hasKeywords {
                            finalProb = min(finalProb + 0.1, 0.95)
                        }
                    }
                    
                    if finalProb > 0.5 { // Only include if above threshold
                        subcategories.append(Subcategory(
                            name: subcatName,
                            source: .nlp,
                            probability: finalProb,
                            majorCategory: majorCategory.name
                        ))
                    }
                }
            }
        }
        
        return subcategories.sorted { $0.probability > $1.probability }
    }
    
    // MARK: - Step 4: Vision Analysis
    
    private func analyzeVision(input: ContentAnalysisInput, filterPreferences: ContentFilterPreferences) async -> VisionResult {
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
    
    /// Analyze image using Vision framework
    private func analyzeImageWithVision(image: UIImage) async -> (subcategories: [Subcategory], confidence: Double) {
        guard let cgImage = image.cgImage else {
            return ([], 0.0)
        }
        
        var subcategories: [Subcategory] = []
        var maxConfidence: Double = 0.0
        
        // Use Vision framework for object detection and classification
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        // Request 1: Object detection (detect people, weapons, etc.)
        let objectRequest = VNDetectHumanRectanglesRequest { request, error in
            if let error = error {
                print("⚠️ Human detection error: \(error.localizedDescription)")
                return
            }
            
            // VNDetectHumanRectanglesRequest returns VNHumanObservation results
            let observations = request.results as? [VNHumanObservation] ?? []
            
            // Detected human figures - could indicate explicit content if combined with other signals
            if observations.count > 0 {
                // This alone doesn't mean explicit, but we note it
                // In a full implementation, you might combine this with other signals
                // For now, we just log it
                print("📸 Detected \(observations.count) human figure(s) in image")
            }
        }
        
        // Request 2: Text recognition (check for inappropriate text in images)
        let textRequest = VNRecognizeTextRequest { request, error in
            if let observations = request.results as? [VNRecognizedTextObservation] {
                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                
                let combinedText = recognizedStrings.joined(separator: " ").lowercased()
                
                // Check for inappropriate text in images
                if combinedText.contains("nsfw") || combinedText.contains("adult") || combinedText.contains("explicit") {
                    subcategories.append(Subcategory(
                        name: "Inappropriate text in image",
                        source: .vision,
                        probability: 0.75,
                        majorCategory: MajorCategoryType.explicitBodyContent.rawValue
                    ))
                    maxConfidence = max(maxConfidence, 0.75)
                }
                
                // Check for violence-related text
                if combinedText.contains("violence") || combinedText.contains("weapon") || combinedText.contains("kill") {
                    subcategories.append(Subcategory(
                        name: "Violence-related text in image",
                        source: .vision,
                        probability: 0.70,
                        majorCategory: MajorCategoryType.violence.rawValue
                    ))
                    maxConfidence = max(maxConfidence, 0.70)
                }
            }
        }
        textRequest.recognitionLevel = .accurate
        
        // Request 3: Image classification (using built-in models)
        // Note: For NSFW detection, you would need a custom CoreML model
        // For now, we use heuristics based on detected objects
        
        // Perform requests
        do {
            try requestHandler.perform([objectRequest, textRequest])
        } catch {
            print("⚠️ Vision analysis error: \(error.localizedDescription)")
        }
        
        // Additional heuristic checks
        // Check image properties that might indicate inappropriate content
        let imageSize = image.size
        let aspectRatio = imageSize.width / imageSize.height
        
        // Very wide or very tall images might be banners/ads (less likely to be explicit)
        // Square or portrait images are more common for explicit content
        // This is a very weak signal, but we can use it as a minor factor
        
        // Color analysis - very dark or very bright images might indicate certain content types
        // This would require more sophisticated analysis
        
        return (subcategories, maxConfidence)
    }
    
    // MARK: - Step 5: Audio Analysis
    
    private func analyzeAudio(input: ContentAnalysisInput) async -> AudioResult {
        guard let media = input.media,
              let audio = media.audio.first(where: { $0.hasSpeech || $0.hasMusic }) else {
            return AudioResult(subcategories: [], confidence: 0.0, used: false)
        }
        
        // Transcribe audio using Speech framework
        let transcriptionResult = await transcribeAudio(audio: audio)
        
        guard !transcriptionResult.isEmpty else {
            return AudioResult(subcategories: [], confidence: 0.0, used: false)
        }
        
        // Analyze transcribed text using NLP
        let textBlocks = NLPTextBlocks(
            mainContent: transcriptionResult,
            creatorMetadata: "",
            sponsorMetadata: "",
            linkContext: ""
        )
        
        // Use the same NLP analysis as text content
        let majorCategories = detectMajorCategories(textBlocks: textBlocks)
        let subcategories = detectSubcategories(
            textBlocks: textBlocks,
            majorCategories: majorCategories
        )
        
        // Mark subcategories as coming from audio source
        let audioSubcategories = subcategories.map { subcat in
            Subcategory(
                name: subcat.name,
                source: .audio,
                probability: subcat.probability,
                majorCategory: subcat.majorCategory
            )
        }
        
        let confidence = audioSubcategories.isEmpty ? 0.0 : audioSubcategories.map { $0.probability }.max() ?? 0.0
        
        return AudioResult(
            subcategories: audioSubcategories,
            confidence: confidence,
            used: !audioSubcategories.isEmpty
        )
    }
    
    /// Transcribe audio using Speech framework
    private func transcribeAudio(audio: AudioInfo) async -> String {
        guard let urlString = audio.url,
              let audioURL = URL(string: urlString) else {
            return ""
        }
        
        // Request speech recognition authorization
        let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            print("⚠️ Speech recognition not available")
            return ""
        }
        
        // Check authorization
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        if authStatus != .authorized {
            // Request authorization (this should be done at app startup)
            print("⚠️ Speech recognition not authorized. Status: \(authStatus.rawValue)")
            return ""
        }
        
        // Create recognition request
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        request.taskHint = .dictation
        
        // Perform recognition
        return await withCheckedContinuation { continuation in
            var finalTranscription = ""
            
            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    print("⚠️ Speech recognition error: \(error.localizedDescription)")
                    continuation.resume(returning: finalTranscription)
                    return
                }
                
                if let result = result {
                    finalTranscription = result.bestTranscription.formattedString
                    
                    if result.isFinal {
                        continuation.resume(returning: finalTranscription)
                    }
                }
            }
            
            // Timeout after 30 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                if !finalTranscription.isEmpty {
                    continuation.resume(returning: finalTranscription)
                } else {
                    continuation.resume(returning: "")
                }
            }
        }
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
        let context = (link.context ?? "").lowercased()
        
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
        nlp: NLPResult,
        vision: VisionResult,
        audio: AudioResult,
        links: LinksResult,
        cloud: CloudResult?,
        ageBand: AgeBand,
        filterPreferences: ContentFilterPreferences
    ) -> UnifiedDecisionResponse {
        // Convert each source to age actions (using user's filter preferences)
        let nlpActions = convertToAgeActions(nlp.subcategories, source: .nlp, ageBand: ageBand, filterPreferences: filterPreferences)
        let visionActions = convertToAgeActions(vision.subcategories, source: .vision, ageBand: ageBand, filterPreferences: filterPreferences)
        let audioActions = convertToAgeActions(audio.subcategories, source: .audio, ageBand: ageBand, filterPreferences: filterPreferences)
        let linksActions = convertToAgeActions(links.subcategories, source: .links, ageBand: ageBand, filterPreferences: filterPreferences)
        let cloudActions = cloud != nil ? convertToAgeActions(cloud!.subcategories, source: .cloud, ageBand: ageBand, filterPreferences: filterPreferences) : nil
        
        // Merge using most restrictive rule
        let mergedAction = DecisionMerger.mergeDecisions(
            textDecision: nlpActions[ageBand.rawValue],
            visionDecision: visionActions[ageBand.rawValue],
            audioDecision: audioActions[ageBand.rawValue],
            linksDecision: linksActions[ageBand.rawValue],
            cloudDecision: cloudActions?[ageBand.rawValue],
            customDecision: nil // Already handled in step 1
        )
        
        // Build all age actions (for now, use same decision for all)
        var allAgeActions: [String: AgeAction] = [:]
        for band in AgeBand.allCases {
            allAgeActions[band.rawValue] = mergedAction
        }
        
        // Combine all subcategories
        let allSubcategories = nlp.subcategories + vision.subcategories + audio.subcategories + links.subcategories + (cloud?.subcategories ?? [])
        
        // Combine all major categories
        let allMajorCategories = nlp.majorCategories + (cloud?.majorCategories ?? [])
        
        return UnifiedDecisionResponse(
            url: "", // Will be set by caller
            overallSafetyScore: 1.0 - mergedAction.score,
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
            timestamp: ISO8601DateFormatter().string(from: Date()),
            historyCategory: allMajorCategories.first?.name,
            historySubcategory: allSubcategories.first?.name
        )
    }
    
    private func convertToAgeActions(
        _ subcategories: [Subcategory],
        source: DecisionSourceType,
        ageBand: AgeBand,
        filterPreferences: ContentFilterPreferences
    ) -> [String: AgeAction] {
        // Map subcategories to age-specific actions based on user's filter preferences
        var actions: [String: AgeAction] = [:]
        
        for band in AgeBand.allCases {
            let action: Action
            let score: Double
            var reason: String?
            
            if let topSubcat = subcategories.first {
                score = topSubcat.probability
                
                // Map detected category/subcategory to user's filter preference
                let userPreference = getFilterPreferenceForCategory(
                    category: topSubcat.majorCategory ?? "",
                    subcategory: topSubcat.name,
                    preferences: filterPreferences
                )
                
                // Use user's preference if available, otherwise use probability-based logic
                if let userAction = userPreference {
                    action = userAction.toAction()
                    reason = "Based on your content filter settings"
                } else {
                    // Fallback: use probability-based logic
                    if score > 0.7 {
                        action = band == .below10 || band == .age10_13 ? .block : .gate
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
            
            actions[band.rawValue] = AgeAction(
                action: action,
                score: score,
                reason: reason ?? subcategories.first?.name,
                risks: subcategories.map { $0.name }
            )
        }
        
        return actions
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
        var response = mergedDecision
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
            historySubcategory: mergedDecision.historySubcategory
        )
    }
    
    // MARK: - Step 8: Cloud Fallback
    
    private func shouldUseCloudFallback(
        nlp: NLPResult,
        vision: VisionResult,
        audio: AudioResult,
        links: LinksResult
    ) -> Bool {
        // Use cloud if:
        // 1. No major category reaches threshold (0.30)
        let maxNLPProb = nlp.majorCategories.map { $0.probability }.max() ?? 0.0
        if maxNLPProb < 0.30 {
            return true
        }
        
        // 2. All sources are low confidence
        if nlp.confidence < 0.3 && vision.confidence < 0.3 && audio.confidence < 0.3 && links.confidence < 0.3 {
            return true
        }
        
        // 3. Conflicting signals (many subcategories but unclear)
        let totalSubcats = nlp.subcategories.count + vision.subcategories.count + audio.subcategories.count
        if totalSubcats > 5 {
            return true
        }
        
        return false
    }
    
    private func callCloudFallback(url: String, input: ContentAnalysisInput) async throws -> CloudResult {
        // Call existing ScanNetworkService
        let networkService = ScanNetworkService()
        let scanResponse = try await networkService.scanURL(url)
        
        // Convert ScanResponse to CloudResult
        return convertScanResponseToCloudResult(scanResponse)
    }
    
    private func convertScanResponseToCloudResult(_ response: ScanResponse) -> CloudResult {
        // Convert existing ScanResponse format to new CloudResult
        let majorCategories = response.childSafetyAnalysis.riskCategories.map {
            MajorCategory(
                name: $0.category,
                probability: Double($0.matchCount) / 10.0, // Normalize
                source: .cloud
            )
        }
        
        let subcategories = response.childSafetyAnalysis.riskCategories.map {
            Subcategory(
                name: $0.category,
                source: .cloud,
                probability: Double($0.matchCount) / 10.0,
                majorCategory: $0.category
            )
        }
        
        return CloudResult(
            majorCategories: majorCategories,
            subcategories: subcategories,
            confidence: 0.8 // Cloud is generally high confidence
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
}

struct NLPTextBlocks {
    let mainContent: String
    let creatorMetadata: String
    let sponsorMetadata: String
    let linkContext: String
}
