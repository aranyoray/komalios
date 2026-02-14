//
//  ContentSafetyTextClassifier.swift
//  Komalios
//
//  Stub for ContentSafetyTextClassifier CoreML model
//  This provides a fallback when the actual .mlmodel file is not available
//

import Foundation
import CoreML

/// Input for ContentSafetyTextClassifier model
final class ContentSafetyTextClassifierInput: NSObject, MLFeatureProvider {
    let text: String

    init(text: String) {
        self.text = text
    }

    var featureNames: Set<String> {
        return ["text"]
    }

    func featureValue(for featureName: String) -> MLFeatureValue? {
        if featureName == "text" {
            return MLFeatureValue(string: text)
        }
        return nil
    }
}

/// Stub ContentSafetyTextClassifier when CoreML model is not available
/// This uses keyword-based detection as a fallback
final class ContentSafetyTextClassifier {

    init(configuration: MLModelConfiguration = MLModelConfiguration()) throws {
        // In production, this would load the actual .mlmodel file
        // For now, we use keyword-based fallback
        print("⚠️ ContentSafetyTextClassifier: Using keyword-based fallback (no CoreML model)")
    }

    func prediction(input: ContentSafetyTextClassifierInput) throws -> ContentSafetyTextClassifierOutput {
        // Perform keyword-based classification
        let text = input.text.lowercased()

        var labelProbabilities: [String: Double] = [
            "safe": 0.5,
            "explicit": 0.0,
            "violence": 0.0,
            "substances": 0.0,
            "gambling": 0.0,
            "cyberbullying": 0.0,
            "parasocial": 0.0,
            "financial": 0.0
        ]

        // Check for explicit content
        let explicitKeywords = ["porn", "xxx", "nude", "naked", "sex", "adult", "nsfw", "explicit", "erotic"]
        if explicitKeywords.contains(where: { text.contains($0) }) {
            labelProbabilities["explicit"] = 0.85
            labelProbabilities["safe"] = 0.15
        }

        // Check for violence
        let violenceKeywords = ["violence", "kill", "murder", "weapon", "gun", "blood", "gore", "torture", "assault", "horror"]
        if violenceKeywords.contains(where: { text.contains($0) }) {
            labelProbabilities["violence"] = 0.80
            labelProbabilities["safe"] = 0.20
        }

        // Check for substances
        let substanceKeywords = ["weed", "marijuana", "drug", "cocaine", "alcohol", "substance abuse", "addiction"]
        if substanceKeywords.contains(where: { text.contains($0) }) {
            labelProbabilities["substances"] = 0.75
            labelProbabilities["safe"] = 0.25
        }

        // Check for gambling
        let gamblingKeywords = ["gambling", "casino", "bet", "poker", "lottery", "wager", "odds", "jackpot"]
        if gamblingKeywords.contains(where: { text.contains($0) }) {
            labelProbabilities["gambling"] = 0.80
            labelProbabilities["safe"] = 0.20
        }

        // Check for parasocial/manipulative content
        let parasocialKeywords = ["exclusive", "join now", "limited time", "you owe me", "subscribe now", "don't miss out", "fomo"]
        if parasocialKeywords.contains(where: { text.contains($0) }) {
            labelProbabilities["parasocial"] = 0.70
            labelProbabilities["safe"] = 0.30
        }

        // Check for financial fraud
        let financialKeywords = ["get rich quick", "investment tip", "crypto", "mlm", "pyramid", "guaranteed return", "risk-free"]
        if financialKeywords.contains(where: { text.contains($0) }) {
            labelProbabilities["financial"] = 0.75
            labelProbabilities["safe"] = 0.25
        }

        // Find the highest probability label
        let topLabel = labelProbabilities.max(by: { $0.value < $1.value })?.key ?? "safe"

        return ContentSafetyTextClassifierOutput(
            label: topLabel,
            labelProbability: labelProbabilities
        )
    }
}

/// Output from ContentSafetyTextClassifier model
final class ContentSafetyTextClassifierOutput: NSObject, MLFeatureProvider {
    let label: String
    let labelProbability: [String: Double]

    init(label: String, labelProbability: [String: Double]) {
        self.label = label
        self.labelProbability = labelProbability
    }

    var featureNames: Set<String> {
        return ["label", "labelProbability"]
    }

    func featureValue(for featureName: String) -> MLFeatureValue? {
        switch featureName {
        case "label":
            return MLFeatureValue(string: label)
        case "labelProbability":
            return try? MLFeatureValue(dictionary: labelProbability as [NSObject: NSNumber])
        default:
            return nil
        }
    }
}
