//
//  ImageFilterService.swift
//  Komalios
//
//  Digital Guardian Enhancement - On-device image content classification
//

import Foundation
import UIKit
import Vision
import CoreML

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
            // Model should be named "NSFWDetector" and added to the Xcode project
            if let modelURL = Bundle.main.url(forResource: "NSFWDetector", withExtension: "mlmodelc") {
                do {
                    let config = MLModelConfiguration()
                    config.computeUnits = .cpuAndNeuralEngine
                    
                    let mlModel = try MLModel(contentsOf: modelURL, configuration: config)
                    self.visionModel = try VNCoreMLModel(for: mlModel)
                    
                    DispatchQueue.main.async {
                        self.isModelLoaded = true
                        print("🛡️ ImageFilterService: CoreML model loaded successfully")
                    }
                } catch {
                    print("🛡️ ImageFilterService: Failed to load CoreML model: \(error)")
                    DispatchQueue.main.async {
                        self.isModelLoaded = false
                    }
                }
            } else {
                print("🛡️ ImageFilterService: CoreML model not found, using heuristic filtering")
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
        if isModelLoaded, let visionModel = visionModel {
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
        
        if isModelLoaded, let visionModel = visionModel {
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
            
            let request = VNCoreMLRequest(model: visionModel) { [weak self] request, error in
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
                
                guard let results = request.results as? [VNClassificationObservation],
                      let topResult = results.first else {
                    continuation.resume(returning: ImageAnalysisResult(
                        imageURL: url,
                        category: .safe,
                        confidence: 1.0,
                        shouldFilter: false,
                        action: .allowed
                    ))
                    return
                }
                
                // Map model output to our categories
                let category = self.mapModelOutput(topResult.identifier)
                let confidence = topResult.confidence
                let shouldFilter = self.shouldFilter(category: category, preferences: preferences) && confidence >= self.filterConfidenceThreshold
                
                let action: ImageFilterAction = shouldFilter ? .replaced : .allowed
                
                if shouldFilter {
                    DispatchQueue.main.async {
                        self.totalImagesFiltered += 1
                    }
                }
                
                continuation.resume(returning: ImageAnalysisResult(
                    imageURL: url,
                    category: category,
                    confidence: confidence,
                    shouldFilter: shouldFilter,
                    action: action
                ))
            }
            
            request.imageCropAndScaleOption = .centerCrop
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            analysisQueue.async {
                do {
                    try handler.perform([request])
                } catch {
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
