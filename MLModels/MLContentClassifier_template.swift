import Foundation
import CoreML
import NaturalLanguage

// MARK: - Content Categories
enum ContentCategory: String, CaseIterable {
    case horror = "Horror/Paranormal"
    case cyberbullying = "Cyberbullying"
    case parasocial = "Parasocial/Manipulative"
    case financialAdvice = "Financial Advice"
    case matureContent = "Mature Content"
}

// MARK: - Classification Result
struct ClassificationResult {
    let isHarmful: Bool
    let categories: [String]
    let confidence: Double
    let detailedScores: [ContentCategory: Double]
}

// MARK: - ML Content Classifier
@available(iOS 16.0, *)
class MLContentClassifier: ObservableObject {

    // MARK: - Models
    private var horrorModel: HorrorClassifier?
    private var cyberbullyingModel: CyberbullyingClassifier?
    private var parasocialModel: ParasocialClassifier?
    private var financialModel: FinancialAdviceClassifier?
    private var matureContentModel: MatureContentClassifier?

    // MARK: - Cache
    private var classificationCache = NSCache<NSString, ClassificationResult>()
    private let cacheLimit = 100

    // MARK: - Configuration
    private let confidenceThreshold: Double = 0.7
    private let maxTextLength = 500

    // MARK: - Initialization
    init() {
        setupCache()
        loadModels()
    }

    private func setupCache() {
        classificationCache.countLimit = cacheLimit
    }

    private func loadModels() {
        do {
            let config = MLModelConfiguration()

            // Load all 5 CoreML models
            horrorModel = try? HorrorClassifier(configuration: config)
            cyberbullyingModel = try? CyberbullyingClassifier(configuration: config)
            parasocialModel = try? ParasocialClassifier(configuration: config)
            financialModel = try? FinancialAdviceClassifier(configuration: config)
            matureContentModel = try? MatureContentClassifier(configuration: config)

            print("✅ All ML models loaded successfully")

        } catch {
            print("❌ Error loading ML models: \(error.localizedDescription)")
        }
    }

    // MARK: - Public Classification Method
    func classifyText(_ text: String) async throws -> ClassificationResult {
        guard !text.isEmpty else {
            return ClassificationResult(
                isHarmful: false,
                categories: [],
                confidence: 0.0,
                detailedScores: [:]
            )
        }

        // Check cache first
        let cacheKey = text.prefix(200) as NSString
        if let cached = classificationCache.object(forKey: cacheKey) {
            return cached
        }

        // Preprocess text
        let cleanText = preprocessText(text)

        // Run all 5 models in parallel
        async let horrorResult = classifyHorror(cleanText)
        async let bullyingResult = classifyCyberbullying(cleanText)
        async let parasocialResult = classifyParasocial(cleanText)
        async let financialResult = classifyFinancial(cleanText)
        async let matureResult = classifyMature(cleanText)

        let results = try await [
            (ContentCategory.horror, horrorResult),
            (ContentCategory.cyberbullying, bullyingResult),
            (ContentCategory.parasocial, parasocialResult),
            (ContentCategory.financialAdvice, financialResult),
            (ContentCategory.matureContent, matureResult)
        ]

        // Aggregate results
        var detectedCategories: [String] = []
        var maxConfidence: Double = 0.0
        var detailedScores: [ContentCategory: Double] = [:]

        for (category, (isHarmful, confidence)) in results {
            detailedScores[category] = confidence

            if isHarmful {
                detectedCategories.append(category.rawValue)
                maxConfidence = max(maxConfidence, confidence)
            }
        }

        let result = ClassificationResult(
            isHarmful: !detectedCategories.isEmpty,
            categories: detectedCategories,
            confidence: maxConfidence,
            detailedScores: detailedScores
        )

        // Cache result
        classificationCache.setObject(result as AnyObject as! ClassificationResult, forKey: cacheKey)

        return result
    }

    // MARK: - Individual Model Classification
    private func classifyHorror(_ text: String) async throws -> (isHarmful: Bool, confidence: Double) {
        guard let model = horrorModel else {
            print("⚠️ Horror model not loaded")
            return (false, 0.0)
        }

        // TODO: Adjust based on actual model input/output structure
        // This is a template - replace with actual CoreML model interface
        /*
        let input = HorrorClassifierInput(text: text)
        let output = try model.prediction(input: input)

        // Assuming model outputs probability for "horror" class
        let probability = output.horrorProbability
        return (isHarmful: probability > confidenceThreshold, confidence: probability)
        */

        // Placeholder - replace with actual implementation
        return (false, 0.0)
    }

    private func classifyCyberbullying(_ text: String) async throws -> (isHarmful: Bool, confidence: Double) {
        guard let model = cyberbullyingModel else {
            print("⚠️ Cyberbullying model not loaded")
            return (false, 0.0)
        }

        // TODO: Implement based on actual model structure
        return (false, 0.0)
    }

    private func classifyParasocial(_ text: String) async throws -> (isHarmful: Bool, confidence: Double) {
        guard let model = parasocialModel else {
            print("⚠️ Parasocial model not loaded")
            return (false, 0.0)
        }

        // TODO: Implement based on actual model structure
        return (false, 0.0)
    }

    private func classifyFinancial(_ text: String) async throws -> (isHarmful: Bool, confidence: Double) {
        guard let model = financialModel else {
            print("⚠️ Financial model not loaded")
            return (false, 0.0)
        }

        // TODO: Implement based on actual model structure
        return (false, 0.0)
    }

    private func classifyMature(_ text: String) async throws -> (isHarmful: Bool, confidence: Double) {
        guard let model = matureContentModel else {
            print("⚠️ Mature content model not loaded")
            return (false, 0.0)
        }

        // TODO: Implement multi-label classification
        // This model may return multiple labels (sexual, lgbtq, religious)
        return (false, 0.0)
    }

    // MARK: - Text Preprocessing
    private func preprocessText(_ text: String) -> String {
        var processed = text.lowercased()

        // Limit length
        if processed.count > maxTextLength {
            processed = String(processed.prefix(maxTextLength))
        }

        // Remove URLs
        let urlPattern = "https?://[^\\s]+"
        processed = processed.replacingOccurrences(
            of: urlPattern,
            with: "",
            options: .regularExpression
        )

        // Remove extra whitespace
        processed = processed.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return processed
    }

    // MARK: - Cache Management
    func clearCache() {
        classificationCache.removeAllObjects()
        print("🗑️ Classification cache cleared")
    }
}

// MARK: - ML Error
enum MLError: Error {
    case modelNotLoaded
    case invalidInput
    case predictionFailed

    var localizedDescription: String {
        switch self {
        case .modelNotLoaded:
            return "ML model not loaded"
        case .invalidInput:
            return "Invalid input text"
        case .predictionFailed:
            return "Model prediction failed"
        }
    }
}

// MARK: - Usage Example
/*
 Usage in SwiftUI View:

 @StateObject private var mlClassifier = MLContentClassifier()

 func analyzeURL(_ url: URL) {
     Task {
         let textToAnalyze = "\(url.host ?? "") \(url.path)"

         do {
             let result = try await mlClassifier.classifyText(textToAnalyze)

             if result.isHarmful {
                 print("⚠️ Harmful content detected!")
                 print("Categories: \(result.categories)")
                 print("Confidence: \(result.confidence)")

                 // Show BlockedView or GateView
                 showBlockedOverlay = true
                 blockedCategories = result.categories
             } else {
                 print("✅ Content is safe")
             }
         } catch {
             print("Classification error: \(error)")
         }
     }
 }
 */
