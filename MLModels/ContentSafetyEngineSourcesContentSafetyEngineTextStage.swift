// TextStage.swift
// Text analysis using quantized transformer model

import Foundation
import CoreML
import NaturalLanguage

@available(iOS 17.0, macOS 14.0, *)
actor TextStage {
    
    // MARK: - Result
    
    struct Result: Sendable {
        let categories: [SafetyCategory: Float]
        let subcategories: [String: Float]
        let confidence: Float
        let tokens: [String]
        let keywordsMatched: Set<String>
    }
    
    // MARK: - Properties
    
    private let model: MLModel
    private let preprocessor: TextPreprocessor
    private let tokenBudget: Int
    
    // MARK: - Initialization
    
    init(computeUnits: MLComputeUnits, tokenBudget: Int) async throws {
        self.tokenBudget = tokenBudget
        
        // Load quantized multi-label transformer
        let config = MLModelConfiguration()
        config.computeUnits = computeUnits
        
        // Prefer int8 quantization for ANE
        if #available(iOS 17.0, *) {
            config.optimizationHints = .fastInferenceWithLowMemory
        }
        
        // Load the W8A8-quantized BERT-lite model
        // This should be exported from your training pipeline as SafetyClassifier.mlpackage
        guard let modelURL = Bundle.module.url(forResource: "SafetyClassifier", withExtension: "mlmodelc") else {
            throw SafetyError.modelNotFound("SafetyClassifier.mlmodelc")
        }
        
        self.model = try await MLModel.load(contentsOf: modelURL, configuration: config)
        
        // Initialize preprocessor with keyword packs
        self.preprocessor = try await TextPreprocessor(tokenBudget: tokenBudget)
    }
    
    // MARK: - Analysis
    
    func analyze(_ text: String) async throws -> Result {
        // 1. Preprocess and tokenize
        let preprocessed = await preprocessor.process(text)
        
        // 2. Run model inference
        let prediction = try await runInference(preprocessed)
        
        // 3. Parse multi-label output
        let categories = parseCategories(from: prediction)
        let subcategories = parseSubcategories(from: prediction)
        
        // 4. Compute confidence
        let confidence = computeConfidence(categories: categories)
        
        return Result(
            categories: categories,
            subcategories: subcategories,
            confidence: confidence,
            tokens: preprocessed.tokens,
            keywordsMatched: preprocessed.keywordsMatched
        )
    }
    
    // MARK: - Private Methods
    
    private func runInference(_ input: PreprocessedText) async throws -> MLFeatureProvider {
        // Prepare input for BERT-style model
        // Expected input: input_ids, attention_mask
        let inputIDs = input.tokenIDs
        let attentionMask = input.attentionMask
        
        // Create multi-array inputs
        let inputShape = [1, NSNumber(value: tokenBudget)] as [NSNumber]
        let inputIDsArray = try MLMultiArray(shape: inputShape, dataType: .int32)
        let attentionMaskArray = try MLMultiArray(shape: inputShape, dataType: .int32)
        
        for i in 0..<min(inputIDs.count, tokenBudget) {
            inputIDsArray[i] = NSNumber(value: inputIDs[i])
            attentionMaskArray[i] = NSNumber(value: attentionMask[i])
        }
        
        // Create feature provider
        let inputFeatures: [String: Any] = [
            "input_ids": inputIDsArray,
            "attention_mask": attentionMaskArray
        ]
        
        let provider = try MLDictionaryFeatureProvider(dictionary: inputFeatures)
        
        // Run prediction (async on ANE if available)
        let prediction = try await model.prediction(from: provider)
        
        return prediction
    }
    
    private func parseCategories(from prediction: MLFeatureProvider) -> [SafetyCategory: Float] {
        // Parse multi-label sigmoid outputs for major categories
        // Expected output: "logits" MLMultiArray of shape [1, num_major_categories]
        guard let logits = prediction.featureValue(for: "major_logits")?.multiArrayValue else {
            return [:]
        }
        
        let categoryOrder: [SafetyCategory] = [
            .violence, .explicit, .substances, .financial, .media, .social
        ]
        
        var result: [SafetyCategory: Float] = [:]
        for (index, category) in categoryOrder.enumerated() {
            if index < logits.count {
                let rawScore = logits[index].floatValue
                let probability = sigmoid(rawScore)
                result[category] = probability
            }
        }
        
        return result
    }
    
    private func parseSubcategories(from prediction: MLFeatureProvider) -> [String: Float] {
        // Parse subcategory outputs (routed based on major category)
        guard let subLogits = prediction.featureValue(for: "sub_logits")?.multiArrayValue else {
            return [:]
        }
        
        var result: [String: Float] = [:]
        // Map indices to subcategory names based on your training
        // This would come from labels_sub.json
        for i in 0..<min(subLogits.count, 50) {
            let rawScore = subLogits[i].floatValue
            let probability = sigmoid(rawScore)
            if probability > 0.1 {
                result["subcat_\(i)"] = probability
            }
        }
        
        return result
    }
    
    private func computeConfidence(categories: [SafetyCategory: Float]) -> Float {
        // High confidence if any category is very high or very low
        let maxScore = categories.values.max() ?? 0.5
        
        if maxScore > 0.8 || maxScore < 0.2 {
            return 0.9
        } else if maxScore > 0.6 || maxScore < 0.4 {
            return 0.7
        } else {
            return 0.5
        }
    }
    
    private func sigmoid(_ x: Float) -> Float {
        1.0 / (1.0 + exp(-x))
    }
}

// MARK: - Text Preprocessor

@available(iOS 17.0, macOS 14.0, *)
actor TextPreprocessor {
    
    struct PreprocessedText {
        let tokens: [String]
        let tokenIDs: [Int32]
        let attentionMask: [Int32]
        let keywordsMatched: Set<String>
    }
    
    private let tokenBudget: Int
    private let keywordPacks: KeywordPacks
    private let tokenizer: NLTokenizer
    
    init(tokenBudget: Int) async throws {
        self.tokenBudget = tokenBudget
        self.keywordPacks = try await KeywordPacks.load()
        self.tokenizer = NLTokenizer(unit: .word)
    }
    
    func process(_ text: String) async -> PreprocessedText {
        // 1. Extract relevant snippets using keywords
        let snippets = extractRelevantSnippets(from: text)
        
        // 2. Tokenize
        tokenizer.string = snippets
        var tokens: [String] = []
        tokenizer.enumerateTokens(in: snippets.startIndex..<snippets.endIndex) { range, _ in
            tokens.append(String(snippets[range]))
            return tokens.count < tokenBudget
        }
        
        // 3. Truncate to budget
        tokens = Array(tokens.prefix(tokenBudget))
        
        // 4. Convert to IDs (simplified - use proper BPE tokenizer in production)
        let tokenIDs = tokens.map { token -> Int32 in
            Int32(token.hash & 0xFFFF) // Placeholder; use real vocab
        }
        
        // 5. Create attention mask
        let attentionMask = Array(repeating: Int32(1), count: tokenIDs.count) +
                           Array(repeating: Int32(0), count: tokenBudget - tokenIDs.count)
        
        // 6. Pad token IDs
        let paddedIDs = tokenIDs + Array(repeating: Int32(0), count: tokenBudget - tokenIDs.count)
        
        // 7. Find matched keywords
        let keywordsMatched = keywordPacks.findMatches(in: text.lowercased())
        
        return PreprocessedText(
            tokens: tokens,
            tokenIDs: paddedIDs,
            attentionMask: attentionMask,
            keywordsMatched: keywordsMatched
        )
    }
    
    private func extractRelevantSnippets(from text: String) -> String {
        // Use keyword-based extraction to select best 256-384 tokens
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
        
        // Score sentences by keyword presence
        var scored: [(String, Float)] = []
        for sentence in sentences {
            let score = keywordPacks.score(sentence)
            if score > 0 {
                scored.append((sentence, score))
            }
        }
        
        // Take top sentences up to budget
        scored.sort { $0.1 > $1.1 }
        var result = ""
        var tokenCount = 0
        
        for (sentence, _) in scored {
            let sentenceTokens = sentence.split(separator: " ").count
            if tokenCount + sentenceTokens <= tokenBudget {
                result += sentence + ". "
                tokenCount += sentenceTokens
            } else {
                break
            }
        }
        
        return result.isEmpty ? String(text.prefix(tokenBudget * 5)) : result
    }
}

// MARK: - Keyword Packs

struct KeywordPacks: Sendable {
    let majorKeywords: [SafetyCategory: [String: Float]]
    let subKeywords: [String: [String: Float]]
    
    static func load() async throws -> KeywordPacks {
        // Load from keywords_major.json and keywords_sub.json
        // These are generated offline from Models_Masterlist.csv
        
        guard let majorURL = Bundle.module.url(forResource: "keywords_major", withExtension: "json"),
              let subURL = Bundle.module.url(forResource: "keywords_sub", withExtension: "json") else {
            throw SafetyError.resourceNotFound("keywords JSON")
        }
        
        let majorData = try Data(contentsOf: majorURL)
        let subData = try Data(contentsOf: subURL)
        
        let decoder = JSONDecoder()
        
        // Simplified structure - in production, use proper keyword weights
        let majorKeywords: [SafetyCategory: [String: Float]] = [
            .violence: ["violence": 1.0, "fight": 0.8, "blood": 0.9, "weapon": 0.85],
            .explicit: ["porn": 1.0, "sex": 0.7, "nude": 0.9, "explicit": 0.95],
            .substances: ["alcohol": 0.8, "drug": 0.9, "gambling": 0.85],
            .financial: ["scam": 1.0, "fraud": 0.95, "pyramid": 0.9],
            .media: ["TikTok": 0.6, "viral": 0.5, "challenge": 0.7],
            .social: ["LGBTQ": 0.3, "hate": 1.0, "slur": 0.95]
        ]
        
        let subKeywords: [String: [String: Float]] = [:]
        
        return KeywordPacks(majorKeywords: majorKeywords, subKeywords: subKeywords)
    }
    
    func findMatches(in text: String) -> Set<String> {
        var matched = Set<String>()
        
        for (_, keywords) in majorKeywords {
            for (keyword, _) in keywords {
                if text.contains(keyword.lowercased()) {
                    matched.insert(keyword)
                }
            }
        }
        
        return matched
    }
    
    func score(_ text: String) -> Float {
        let lower = text.lowercased()
        var score: Float = 0
        
        for (_, keywords) in majorKeywords {
            for (keyword, weight) in keywords {
                if lower.contains(keyword.lowercased()) {
                    score += weight
                }
            }
        }
        
        return score
    }
}

// MARK: - Error

enum SafetyError: Error {
    case modelNotFound(String)
    case resourceNotFound(String)
    case invalidInput(String)
}
