//
//  ImageFilterService.swift
//  Komalios
//
//  Digital Guardian Enhancement - On-device image content classification
//

#if os(iOS)
import Foundation
import UIKit
@preconcurrency import Vision
import CoreML

/// Thread-safe guard to ensure a CheckedContinuation is only resumed once.
/// Uses NSLock instead of raw pointers to avoid use-after-free when
/// Vision's perform() both calls the completion handler AND throws.
private final class ContinuationResumeGuard: @unchecked Sendable {
    private var _resumed = false
    private let lock = NSLock()

    /// Atomically marks as resumed. Returns true if this is the first call, false if already resumed.
    func tryMarkResumed() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if _resumed { return false }
        _resumed = true
        return true
    }
}

/// Service for analyzing images and determining if they should be filtered
final class ImageFilterService: ObservableObject {
    static let shared = ImageFilterService()
    
    // MARK: - Published Properties
    @Published private(set) var isModelLoaded = false
    @Published private(set) var totalImagesAnalyzed = 0
    @Published private(set) var totalImagesFiltered = 0
    
    // MARK: - Private Properties
    private var visionModel: VNCoreMLModel?
    private let analysisQueue = DispatchQueue(label: "com.komalios.imagefilter", qos: .userInitiated)
    private let imageCache = NSCache<NSString, UIImage>()
    
    // Confidence threshold for filtering (0.0 - 1.0)
    private let filterConfidenceThreshold: Float = 0.6
    
    // MARK: - Initialization
    
    private init() {
        setupModel()
        configureCache()
    }
    
    private func configureCache() {
        imageCache.countLimit = 50
        imageCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    private func setupModel() {
        // Try to load CoreML model if available
        // The model would be added to the project as NSFWDetector.mlmodelc
        loadCoreMLModel()
    }
    
    private func loadCoreMLModel() {
        analysisQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Try to load the NSFW detection model
            // First try compiled model (.mlmodelc), then try source model (.mlmodel)
            var modelURL: URL?
            
            // Try compiled model first (faster) - check root bundle
            if let compiledURL = Bundle.main.url(forResource: "NSFW", withExtension: "mlmodelc") {
                modelURL = compiledURL
            }
            // Try compiled model in MLModels subdirectory
            else if let compiledURL = Bundle.main.url(forResource: "NSFW", withExtension: "mlmodelc", subdirectory: "MLModels") {
                modelURL = compiledURL
            }
            // Fallback to source model in root (will be compiled on first use)
            else if let sourceURL = Bundle.main.url(forResource: "NSFW", withExtension: "mlmodel") {
                modelURL = sourceURL
            }
            // Fallback to source model in MLModels subdirectory
            else if let sourceURL = Bundle.main.url(forResource: "NSFW", withExtension: "mlmodel", subdirectory: "MLModels") {
                modelURL = sourceURL
            }
            
            guard let url = modelURL else {
                print("🛡️ ImageFilterService: NSFW.mlmodel not found in bundle, using heuristic filtering")
                DispatchQueue.main.async {
                    self.isModelLoaded = false
                }
                return
            }
            
            do {
                let config = MLModelConfiguration()
                config.computeUnits = .cpuAndNeuralEngine
                
                let mlModel = try MLModel(contentsOf: url, configuration: config)
                self.visionModel = try VNCoreMLModel(for: mlModel)
                
                DispatchQueue.main.async {
                    self.isModelLoaded = true
                    print("🛡️ ImageFilterService: NSFW CoreML model loaded successfully from \(url.lastPathComponent)")
                }
            } catch {
                print("🛡️ ImageFilterService: Failed to load NSFW CoreML model: \(error)")
                DispatchQueue.main.async {
                    self.isModelLoaded = false
                }
            }
        }
    }
    
    // MARK: - Public API
    
    /// Analyze an image from URL and return classification result
    func analyzeImage(url: URL, preferences: ContentFilterPreferences) async -> ImageAnalysisResult {
        totalImagesAnalyzed += 1
        
        // Download image
        guard let imageData = await downloadImage(url: url),
              let image = UIImage(data: imageData) else {
            return ImageAnalysisResult(
                imageURL: url,
                category: .neutral,
                confidence: 0,
                shouldFilter: false,
                action: .failed
            )
        }
        
        // Analyze with CoreML if available, otherwise use heuristics
        if isModelLoaded, visionModel != nil {
            return await analyzeWithCoreML(image: image, url: url, preferences: preferences)
        } else {
            return analyzeWithHeuristics(image: image, url: url, preferences: preferences)
        }
    }

    /// Analyze image data directly
    func analyzeImageData(_ data: Data, url: URL, preferences: ContentFilterPreferences) async -> ImageAnalysisResult {
        totalImagesAnalyzed += 1

        guard let image = UIImage(data: data) else {
            return ImageAnalysisResult(
                imageURL: url,
                category: .neutral,
                confidence: 0,
                shouldFilter: false,
                action: .failed
            )
        }

        if isModelLoaded, visionModel != nil {
            return await analyzeWithCoreML(image: image, url: url, preferences: preferences)
        } else {
            return analyzeWithHeuristics(image: image, url: url, preferences: preferences)
        }
    }
    
    /// Determine if a category should be filtered based on preferences
    func shouldFilter(category: ImageContentCategory, preferences: ContentFilterPreferences) -> Bool {
        let action = category.shouldFilter(preferences: preferences)
        return action == .block
    }
    
    /// Get the Komal logo as base64 for JavaScript injection
    func getKomalLogoBase64() -> String? {
        // Try to load the Komal logo/mascot image
        guard let logoImage = UIImage(named: "komaliconnobg") ?? UIImage(named: "komalicon") ?? createDefaultLogo() else {
            return nil
        }
        
        guard let imageData = logoImage.pngData() else {
            return nil
        }
        
        return "data:image/png;base64," + imageData.base64EncodedString()
    }
    
    // MARK: - Private Analysis Methods
    
    private func analyzeWithCoreML(image: UIImage, url: URL, preferences: ContentFilterPreferences) async -> ImageAnalysisResult {
        return await withCheckedContinuation { continuation in
            guard let cgImage = image.cgImage, let visionModel = visionModel else {
                continuation.resume(returning: ImageAnalysisResult(
                    imageURL: url,
                    category: .neutral,
                    confidence: 0,
                    shouldFilter: false,
                    action: .failed
                ))
                return
            }

            // Thread-safe guard to prevent double-resume.
            // Vision's perform() can both call the completion handler AND throw,
            // which would otherwise resume the continuation twice and crash.
            // Using a class with NSLock avoids the use-after-free bug that raw pointers cause.
            let resumeGuard = ContinuationResumeGuard()

            let request = VNCoreMLRequest(model: visionModel) { [weak self] request, error in
                guard resumeGuard.tryMarkResumed() else { return }

                guard let self = self else {
                    continuation.resume(returning: ImageAnalysisResult(
                        imageURL: url,
                        category: .neutral,
                        confidence: 0,
                        shouldFilter: false,
                        action: .failed
                    ))
                    return
                }

                if let error = error {
                    print("🛡️ CoreML analysis error: \(error)")
                    continuation.resume(returning: ImageAnalysisResult(
                        imageURL: url,
                        category: .neutral,
                        confidence: 0,
                        shouldFilter: false,
                        action: .failed
                    ))
                    return
                }

                // NSFW models typically output classification observations
                // Try to get classification results first
                if let classificationResults = request.results as? [VNClassificationObservation],
                   let topResult = classificationResults.first {
                    // Handle classification-based output
                    let nsfwScore = self.extractNSFWScore(from: topResult)
                    let category = self.determineCategory(from: nsfwScore)
                    let confidence = Float(nsfwScore)
                    let shouldFilter = self.shouldFilter(category: category, preferences: preferences) && confidence >= self.filterConfidenceThreshold

                    let action: ImageFilterAction = shouldFilter ? .replaced : .allowed

                    if shouldFilter {
                        DispatchQueue.main.async {
                            self.totalImagesFiltered += 1
                        }
                        print("🛡️ NSFW detected: \(category.displayName) (confidence: \(Int(confidence * 100))%)")
                    }

                    continuation.resume(returning: ImageAnalysisResult(
                        imageURL: url,
                        category: category,
                        confidence: confidence,
                        shouldFilter: shouldFilter,
                        action: action
                    ))
                    return
                }

                // Fallback: If no classification results, assume safe
                print("🛡️ NSFW model returned unexpected results, defaulting to safe")
                continuation.resume(returning: ImageAnalysisResult(
                    imageURL: url,
                    category: .safe,
                    confidence: 0.0,
                    shouldFilter: false,
                    action: .allowed
                ))
            }

            // Configure request for optimal NSFW detection
            request.imageCropAndScaleOption = .scaleFill  // Better for NSFW detection

            nonisolated(unsafe) let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            nonisolated(unsafe) let visionRequest = request

            analysisQueue.async {
                do {
                    try handler.perform([visionRequest])
                } catch {
                    guard resumeGuard.tryMarkResumed() else { return }
                    print("🛡️ Vision request failed: \(error)")
                    continuation.resume(returning: ImageAnalysisResult(
                        imageURL: url,
                        category: .neutral,
                        confidence: 0,
                        shouldFilter: false,
                        action: .failed
                    ))
                }
            }
        }
    }
    
    /// Extract NSFW probability score from classification observation
    private func extractNSFWScore(from observation: VNClassificationObservation) -> Double {
        let identifier = observation.identifier.lowercased()
        let confidence = Double(observation.confidence)
        
        // Check if the identifier indicates NSFW/explicit content
        if identifier.contains("nsfw") || identifier.contains("explicit") || 
           identifier.contains("porn") || identifier.contains("adult") ||
           identifier.contains("nude") || identifier.contains("naked") {
            // This is an NSFW classification, return the confidence as the score
            return confidence
        }
        
        // Check if the identifier indicates safe content
        if identifier.contains("safe") || identifier.contains("sfw") || 
           identifier.contains("neutral") || identifier.contains("normal") {
            // This is a safe classification, return inverse confidence
            return 1.0 - confidence
        }
        
        // If identifier is a probability-like value (e.g., "0.85" or "85%")
        if let numericValue = Double(identifier) {
            // If it's between 0 and 1, use it directly
            if numericValue >= 0.0 && numericValue <= 1.0 {
                return numericValue
            }
            // If it's a percentage (0-100), convert to 0-1
            if numericValue >= 0.0 && numericValue <= 100.0 {
                return numericValue / 100.0
            }
        }
        
        // Default: use confidence as NSFW score
        // Higher confidence in any classification might indicate NSFW
        return confidence
    }
    
    /// Determine category based on NSFW score
    private func determineCategory(from nsfwScore: Double) -> ImageContentCategory {
        // NSFW score ranges:
        // 0.0 - 0.3: Safe
        // 0.3 - 0.6: Suggestive
        // 0.6 - 0.8: Explicit (moderate)
        // 0.8 - 1.0: Explicit (high)
        
        if nsfwScore >= 0.8 {
            return .explicit
        } else if nsfwScore >= 0.6 {
            return .explicit  // Still explicit, just lower confidence
        } else if nsfwScore >= 0.3 {
            return .suggestive
        } else {
            return .safe
        }
    }
    
    private func analyzeWithHeuristics(image: UIImage, url: URL, preferences: ContentFilterPreferences) -> ImageAnalysisResult {
        // Basic heuristic analysis when CoreML model is not available
        // This provides basic protection based on:
        // 1. URL patterns
        // 2. Image characteristics
        
        let urlString = url.absoluteString.lowercased()
        
        // Check URL for suspicious patterns
        let suspiciousPatterns = [
            "nsfw", "xxx", "porn", "adult", "nude", "naked", "sexy",
            "explicit", "18+", "mature", "gore", "violence", "blood"
        ]
        
        for pattern in suspiciousPatterns {
            if urlString.contains(pattern) {
                let category = categorizeByURLPattern(pattern)
                let shouldFilter = self.shouldFilter(category: category, preferences: preferences)
                
                if shouldFilter {
                    DispatchQueue.main.async {
                        self.totalImagesFiltered += 1
                    }
                }
                
                return ImageAnalysisResult(
                    imageURL: url,
                    category: category,
                    confidence: 0.7, // Medium confidence for URL-based detection
                    shouldFilter: shouldFilter,
                    action: shouldFilter ? .replaced : .allowed
                )
            }
        }
        
        // Analyze image characteristics (basic skin tone detection)
        let skinToneRatio = analyzeSkinToneRatio(image: image)
        
        if skinToneRatio > 0.6 {
            // High skin tone ratio - flag as potentially suggestive
            let category: ImageContentCategory = skinToneRatio > 0.8 ? .explicit : .suggestive
            let confidence = Float(skinToneRatio)
            let shouldFilter = self.shouldFilter(category: category, preferences: preferences) && confidence >= filterConfidenceThreshold
            
            if shouldFilter {
                DispatchQueue.main.async {
                    self.totalImagesFiltered += 1
                }
            }
            
            return ImageAnalysisResult(
                imageURL: url,
                category: category,
                confidence: confidence,
                shouldFilter: shouldFilter,
                action: shouldFilter ? .replaced : .allowed
            )
        }
        
        // Default: safe
        return ImageAnalysisResult(
            imageURL: url,
            category: .safe,
            confidence: 0.8,
            shouldFilter: false,
            action: .allowed
        )
    }
    
    // MARK: - Helper Methods
    
    private func downloadImage(url: URL) async -> Data? {
        // Check if it's a data URL
        if url.scheme == "data" {
            return nil // Skip data URLs for now
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }
            
            // Verify it's an image
            let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? ""
            guard contentType.contains("image") else {
                return nil
            }
            
            return data
        } catch {
            print("🛡️ Failed to download image: \(error)")
            return nil
        }
    }
    
    /// Legacy method - kept for backward compatibility
    /// Now uses extractNSFWScore and determineCategory instead
    private func mapModelOutput(_ identifier: String) -> ImageContentCategory {
        // Map common NSFW model output labels to our categories
        let lowercased = identifier.lowercased()
        
        if lowercased.contains("porn") || lowercased.contains("explicit") || lowercased.contains("nsfw") {
            return .explicit
        } else if lowercased.contains("sexy") || lowercased.contains("suggestive") || lowercased.contains("hentai") {
            return .suggestive
        } else if lowercased.contains("violence") || lowercased.contains("gore") {
            return .violence
        } else if lowercased.contains("drug") {
            return .drugs
        } else if lowercased.contains("weapon") || lowercased.contains("gun") {
            return .weapons
        } else if lowercased.contains("neutral") || lowercased.contains("drawing") {
            return .neutral
        } else {
            return .safe
        }
    }
    
    private func categorizeByURLPattern(_ pattern: String) -> ImageContentCategory {
        switch pattern {
        case "nsfw", "xxx", "porn", "adult", "nude", "naked":
            return .explicit
        case "sexy", "mature", "18+":
            return .suggestive
        case "gore", "violence", "blood":
            return .violence
        default:
            return .neutral
        }
    }
    
    private func analyzeSkinToneRatio(image: UIImage) -> Double {
        // Basic skin tone detection using average color analysis
        guard let cgImage = image.cgImage else { return 0 }
        
        let width = min(cgImage.width, 100)  // Sample at lower resolution
        let height = min(cgImage.height, 100)
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return 0 }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let data = context.data else { return 0 }
        
        let pointer = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        
        var skinPixels = 0
        let totalPixels = width * height
        
        for i in 0..<totalPixels {
            let offset = i * 4
            let r = Int(pointer[offset])
            let g = Int(pointer[offset + 1])
            let b = Int(pointer[offset + 2])
            
            // Simple skin tone detection (RGB ranges)
            if r > 95 && g > 40 && b > 20 &&
               r > g && r > b &&
               abs(r - g) > 15 &&
               r - b > 15 && r - g < 100 {
                skinPixels += 1
            }
        }
        
        return Double(skinPixels) / Double(totalPixels)
    }
    
    private func createDefaultLogo() -> UIImage? {
        // Create a simple placeholder logo if no image is available
        let size = CGSize(width: 200, height: 200)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return nil
        }
        
        // Pink gradient background
        let colors = [
            UIColor(red: 1.0, green: 0.96, blue: 0.97, alpha: 1.0).cgColor,
            UIColor(red: 1.0, green: 0.89, blue: 0.93, alpha: 1.0).cgColor
        ]
        
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: nil) {
            context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
        }
        
        // Draw shield emoji
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let shieldAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 60),
            .paragraphStyle: paragraphStyle
        ]
        
        let shieldText = "🛡️"
        let shieldRect = CGRect(x: 0, y: 50, width: size.width, height: 80)
        shieldText.draw(in: shieldRect, withAttributes: shieldAttributes)
        
        // Draw text
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: UIColor(red: 0.83, green: 0.65, blue: 0.65, alpha: 1.0),
            .paragraphStyle: paragraphStyle
        ]
        
        let text = "Protected by Komal"
        let textRect = CGRect(x: 0, y: 140, width: size.width, height: 30)
        text.draw(in: textRect, withAttributes: textAttributes)
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image
    }
}

// MARK: - Image Analysis Result

struct ImageAnalysisResult {
    let imageURL: URL
    let category: ImageContentCategory
    let confidence: Float
    let shouldFilter: Bool
    let action: ImageFilterAction
    
    /// Confidence as percentage string
    var confidencePercentage: String {
        "\(Int(confidence * 100))%"
    }
    
    /// Convert to ImageFilterEvent for persistence
    func toFilterEvent(pageURL: URL, matchedPreference: String? = nil) -> ImageFilterEvent {
        ImageFilterEvent(
            pageURL: pageURL,
            imageURL: imageURL,
            detectedCategory: category,
            confidenceScore: confidence,
            action: action,
            matchedPreference: matchedPreference
        )
    }
}
#endif
