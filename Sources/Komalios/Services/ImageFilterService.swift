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
@MainActor
final class ImageFilterService: ObservableObject {
    static let shared = ImageFilterService()
    
    // MARK: - Published Properties
    @Published private(set) var isModelLoaded = false
    @Published private(set) var totalImagesAnalyzed = 0
    @Published private(set) var totalImagesFiltered = 0
    
    // MARK: - Private Properties
    private var visionModel: VNCoreMLModel?
    private let analysisQueue = DispatchQueue(label: "com.komalios.imagefilter", qos: .userInitiated)

    // URL result cache: avoids re-analyzing the same image URL
    // Key = URL string, Value = cached result
    private var urlResultCache: [String: ImageAnalysisResult] = [:]
    private var urlResultCacheInsertionOrder: [String] = []  // tracks FIFO order for eviction
    private let urlResultCacheLimit = 200

    // Confidence threshold for filtering (0.0 - 1.0)
    // Only block images with meaningful confidence of inappropriate content
    private let filterConfidenceThreshold: Float = 0.50
    
    // MARK: - Initialization
    
    private init() {
        setupModel()
    }
    
    private func setupModel() {
        // Try to load CoreML model if available
        // The model would be added to the project as NSFWDetector.mlmodelc
        loadCoreMLModel()
    }
    
    private func loadCoreMLModel() {
        #if !targetEnvironment(simulator)
        // Simulator has no Neural Engine / ANE; VNCoreMLRequest inference always fails
        // with Code=9 "Could not create inference context". Skip model loading there.
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
                config.computeUnits = .all
                
                let mlModel = try MLModel(contentsOf: url, configuration: config)
                let vnModel = try VNCoreMLModel(for: mlModel)
                DispatchQueue.main.async {
                    self.visionModel = vnModel
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
        #endif
    }

    // MARK: - Public API
    
    /// Analyze an image from URL and return classification result
    func analyzeImage(url: URL, preferences: ContentFilterPreferences) async -> ImageAnalysisResult {
        totalImagesAnalyzed += 1

        // Check URL result cache first — instant result for previously-seen URLs
        let cacheKey = url.absoluteString
        if let cached = urlResultCache[cacheKey] {
            return cached
        }

        // Handle data: URLs by decoding base64 inline
        if url.scheme == "data" {
            let result = await analyzeDataURL(url: url, preferences: preferences)
            cacheResult(result, forKey: cacheKey)
            return result
        }

        // Download image — if download fails, allow it (don't block unverifiable images)
        guard let imageData = await downloadImage(url: url),
              let image = UIImage(data: imageData) else {
            // Can't download/parse image — allow it rather than blocking all failed downloads
            let failResult = ImageAnalysisResult(
                imageURL: url,
                category: .neutral,
                confidence: 0,
                shouldFilter: false,
                action: .allowed
            )
            cacheResult(failResult, forKey: cacheKey)
            return failResult
        }

        // Analyze with CoreML if available, otherwise use heuristics
        var result: ImageAnalysisResult
        if isModelLoaded, visionModel != nil {
            result = await analyzeWithCoreML(image: image, url: url, preferences: preferences)
        } else {
            result = await analyzeWithHeuristics(image: image, url: url, preferences: preferences)
        }

        // Run RevealingLevelClassifier on safe, neutral, AND suggestive results
        // so that suggestive content with explicit body exposure gets upgraded to explicit
        if result.category == .safe || result.category == .neutral || result.category == .suggestive {
            result = await applyRevealingLevelUpgrade(baseResult: result, image: image, url: url, preferences: preferences)
        }

        cacheResult(result, forKey: cacheKey)
        return result
    }

    private func cacheResult(_ result: ImageAnalysisResult, forKey key: String) {
        // If the key is already cached, don't duplicate it in the insertion order
        if urlResultCache[key] != nil {
            urlResultCache[key] = result
            return
        }

        // Evict oldest entries (FIFO) if cache is full
        if urlResultCache.count >= urlResultCacheLimit {
            let evictCount = urlResultCacheLimit / 4  // Remove ~25% of entries
            let keysToRemove = Array(urlResultCacheInsertionOrder.prefix(evictCount))
            for k in keysToRemove { urlResultCache.removeValue(forKey: k) }
            urlResultCacheInsertionOrder.removeFirst(min(evictCount, urlResultCacheInsertionOrder.count))
        }

        urlResultCache[key] = result
        urlResultCacheInsertionOrder.append(key)
    }

    /// Run RevealingLevelClassifier on safe/neutral images and upgrade if revealing
    private func applyRevealingLevelUpgrade(
        baseResult: ImageAnalysisResult,
        image: UIImage,
        url: URL,
        preferences: ContentFilterPreferences
    ) async -> ImageAnalysisResult {
        let revealingResult = await RevealingLevelClassifier.shared.classify(image: image)

        // No person detected — return as-is
        guard revealingResult.personDetected else {
            return baseResult
        }

        // Minor detected — err on side of safety: block the image
        // Do NOT return unfiltered base result when a minor is in the image
        if revealingResult.minorDetected {
            print("🛡️ Minor detected in image — blocking for safety")
            return ImageAnalysisResult(
                imageURL: url,
                category: .suggestive,
                confidence: 0.8,
                shouldFilter: true,
                action: .replaced
            )
        }

        // Level ≥ 5: upgrade to explicit with block action
        if revealingResult.level >= RevealingLevel.explicitExposure {
            let shouldFilter = self.shouldFilter(category: .explicit, preferences: preferences)
            if shouldFilter {
                DispatchQueue.main.async { self.totalImagesFiltered += 1 }
            }
            print("🛡️ Revealing level \(revealingResult.level.rawValue) → upgraded to explicit (score: \(revealingResult.aggregateScore))")
            return ImageAnalysisResult(
                imageURL: url,
                category: .explicit,
                confidence: min(Float(revealingResult.aggregateScore / 5.0), 0.95),
                shouldFilter: shouldFilter,
                action: shouldFilter ? .replaced : .allowed
            )
        }

        // Level ≥ 2: upgrade to suggestive — block at 30% threshold
        if revealingResult.level >= RevealingLevel.partialExposure {
            let shouldFilter = self.shouldFilter(category: .suggestive, preferences: preferences)
            if shouldFilter {
                DispatchQueue.main.async { self.totalImagesFiltered += 1 }
            }
            print("🛡️ Revealing level \(revealingResult.level.rawValue) → upgraded to suggestive (score: \(revealingResult.aggregateScore))")
            return ImageAnalysisResult(
                imageURL: url,
                category: .suggestive,
                confidence: min(Float(revealingResult.aggregateScore / 3.5), 0.85),
                shouldFilter: shouldFilter,
                action: shouldFilter ? .replaced : .allowed
            )
        }

        // Level < 3: no upgrade needed
        return baseResult
    }

    /// Decode and analyze a data: URL (base64-encoded image)
    private func analyzeDataURL(url: URL, preferences: ContentFilterPreferences) async -> ImageAnalysisResult {
        let urlString = url.absoluteString
        // data:image/png;base64,iVBOR... → extract after the comma
        guard let commaIndex = urlString.firstIndex(of: ",") else {
            return ImageAnalysisResult(imageURL: url, category: .neutral, confidence: 0, shouldFilter: false, action: .allowed)
        }
        let base64String = String(urlString[urlString.index(after: commaIndex)...])
        guard let data = Data(base64Encoded: base64String, options: .ignoreUnknownCharacters),
              let image = UIImage(data: data) else {
            return ImageAnalysisResult(imageURL: url, category: .neutral, confidence: 0, shouldFilter: false, action: .allowed)
        }

        // Run analysis pipeline (CoreML or heuristic + RevealingLevel)
        var result: ImageAnalysisResult
        if isModelLoaded, visionModel != nil {
            result = await analyzeWithCoreML(image: image, url: url, preferences: preferences)
        } else {
            result = await analyzeWithHeuristics(image: image, url: url, preferences: preferences)
        }
        if result.category == .safe || result.category == .neutral || result.category == .suggestive {
            result = await applyRevealingLevelUpgrade(baseResult: result, image: image, url: url, preferences: preferences)
        }
        return result
    }

    /// Analyze image data directly
    func analyzeImageData(_ data: Data, url: URL, preferences: ContentFilterPreferences) async -> ImageAnalysisResult {
        totalImagesAnalyzed += 1

        guard let image = UIImage(data: data) else {
            // Can't parse image — allow it
            return ImageAnalysisResult(
                imageURL: url,
                category: .neutral,
                confidence: 0,
                shouldFilter: false,
                action: .allowed
            )
        }

        var result: ImageAnalysisResult
        if isModelLoaded, visionModel != nil {
            result = await analyzeWithCoreML(image: image, url: url, preferences: preferences)
        } else {
            result = await analyzeWithHeuristics(image: image, url: url, preferences: preferences)
        }

        // Run RevealingLevelClassifier on safe/neutral/suggestive results (same as analyzeImage)
        if result.category == .safe || result.category == .neutral || result.category == .suggestive {
            result = await applyRevealingLevelUpgrade(baseResult: result, image: image, url: url, preferences: preferences)
        }

        return result
    }
    
    /// Determine if a category should be filtered based on preferences.
    /// For images, both `.block` and `.gate` mean the image should be replaced —
    /// only `.allow` passes the image through.
    func shouldFilter(category: ImageContentCategory, preferences: ContentFilterPreferences) -> Bool {
        let action = category.shouldFilter(preferences: preferences)
        return action == .block || action == .gate
    }
    
    /// Get the Komal logo as base64 for JavaScript injection
    /// nonisolated because this is called from EngagementTracker init (non-actor context)
    nonisolated func getKomalLogoBase64() -> String? {
        // Try to load the Komal logo/mascot image
        guard let logoImage = UIImage(named: "komaliconnobg") ?? UIImage(named: "komalicon") ?? Self.createDefaultLogo() else {
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
                // Can't process image — allow it rather than blocking
                continuation.resume(returning: ImageAnalysisResult(
                    imageURL: url,
                    category: .neutral,
                    confidence: 0,
                    shouldFilter: false,
                    action: .allowed
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
                    // Can't process — allow it
                    continuation.resume(returning: ImageAnalysisResult(
                        imageURL: url,
                        category: .neutral,
                        confidence: 0,
                        shouldFilter: false,
                        action: .allowed
                    ))
                    return
                }

                if let error = error {
                    print("🛡️ CoreML analysis error: \(error)")
                    // Analysis error — allow the image
                    continuation.resume(returning: ImageAnalysisResult(
                        imageURL: url,
                        category: .neutral,
                        confidence: 0,
                        shouldFilter: false,
                        action: .allowed
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
                    // Check preferences first, then apply confidence threshold
                    // For child safety, use lower threshold for dangerous categories
                    let prefShouldFilter = self.shouldFilter(category: category, preferences: preferences)
                    let effectiveThreshold: Float = (category == .explicit || category == .violence || category == .gore)
                        ? self.filterConfidenceThreshold * 0.7 // Even lower bar for dangerous content
                        : self.filterConfidenceThreshold
                    let shouldFilter = prefShouldFilter && confidence >= effectiveThreshold

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

                // Fallback: If no classification results, allow the image
                print("🛡️ NSFW model returned unexpected results, allowing image")
                continuation.resume(returning: ImageAnalysisResult(
                    imageURL: url,
                    category: .neutral,
                    confidence: 0.0,
                    shouldFilter: false,
                    action: .allowed
                ))
            }

            // Configure request for optimal NSFW detection
            request.imageCropAndScaleOption = .scaleFill  // Better for NSFW detection

            // CONCURRENCY WARNING: nonisolated(unsafe) is used here because
            // VNImageRequestHandler and VNCoreMLRequest are not Sendable, but we
            // must pass them to analysisQueue.async (a different isolation domain).
            // This is safe in practice because:
            //   1. `handler` and `visionRequest` are created on the MainActor,
            //   2. they are only used inside `analysisQueue.async` after creation,
            //   3. no further reads/writes happen on the MainActor after dispatch.
            // However, the compiler cannot verify this, so a data race is
            // theoretically possible if future edits break these invariants.
            // A proper fix would require rewriting the Vision pipeline using
            // async/await VNImageRequestHandler APIs (iOS 17+) or actor isolation.
            nonisolated(unsafe) let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            nonisolated(unsafe) let visionRequest = request

            analysisQueue.async {
                do {
                    try handler.perform([visionRequest])
                } catch {
                    guard resumeGuard.tryMarkResumed() else { return }
                    print("🛡️ Vision request failed: \(error)")
                    // Vision failed — allow the image
                    continuation.resume(returning: ImageAnalysisResult(
                        imageURL: url,
                        category: .neutral,
                        confidence: 0,
                        shouldFilter: false,
                        action: .allowed
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
            // The top label IS "safe" — the image is safe.
            // Only flag as NSFW if the model is very uncertain about safety
            // (confidence < 0.3 means model barely thinks it's safe).
            // Previously: `1.0 - confidence` caused a "safe" label at 0.3 confidence
            // to return 0.7, incorrectly flagging it as explicit.
            if confidence >= 0.5 {
                return 0.0  // Model is confident it's safe
            }
            // Model is very uncertain — return a low suggestive-range score, not explicit
            return max(0.0, (0.5 - confidence) * 0.6)  // max possible: 0.3
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

        // Default: unrecognized label (e.g. "cat", "dog", "car") — treat as safe.
        // Returning the model's classification confidence here would be wrong:
        // an image classified as "cat" with 0.95 confidence would score 0.95,
        // falsely flagging it as explicit content.
        return 0.0
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
    
    private func analyzeWithHeuristics(image: UIImage, url: URL, preferences: ContentFilterPreferences) async -> ImageAnalysisResult {
        // Basic heuristic analysis when CoreML model is not available
        // This provides basic protection based on:
        // 1. URL patterns
        // 2. Image characteristics

        let urlString = url.absoluteString.lowercased()

        // Check URL for suspicious patterns (also check URL path components and query params)
        let suspiciousPatterns = [
            "nsfw", "xxx", "porn", "adult", "nude", "naked", "sexy",
            "explicit", "18+", "mature", "gore", "violence", "blood",
            "hentai", "onlyfans", "playboy", "brazzers", "xnxx", "xvideos",
            "redtube", "youporn", "pornhub", "xhamster", "spankbang"
        ]

        for pattern in suspiciousPatterns {
            if urlString.contains(pattern) {
                let category = categorizeByURLPattern(pattern)
                let shouldFilter = self.shouldFilter(category: category, preferences: preferences)

                if shouldFilter {
                    DispatchQueue.main.async { self.totalImagesFiltered += 1 }
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

        // Run pixel analysis off the main actor to avoid blocking UI
        let skinToneRatio = await Task.detached(priority: .userInitiated) {
            return self.analyzeSkinToneRatio(image: image)
        }.value

        if skinToneRatio > 0.6 {
            // Skin tone ratio above 60% — likely inappropriate content
            let category: ImageContentCategory = skinToneRatio > 0.65 ? .explicit : .suggestive
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
        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return nil
            }

            // Accept image if Content-Type says image OR if no Content-Type header
            // (many CDNs omit Content-Type or use application/octet-stream for images)
            let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
            if !contentType.isEmpty &&
               !contentType.contains("image") &&
               !contentType.contains("octet-stream") &&
               !contentType.contains("binary") {
                return nil
            }

            // Sanity check: must have enough data to be an image
            guard data.count > 100 else { return nil }

            return data
        } catch {
            print("🛡️ Failed to download image: \(error)")
            return nil
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
    
    private nonisolated func analyzeSkinToneRatio(image: UIImage) -> Double {
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

            // Skin tone detection covering diverse skin tones
            // Tightened rules to reduce false positives on warm surfaces (wood, sand, terracotta)

            // Rule 1: light to medium skin — require sufficient color variance
            // and exclude uniform warm tones (wood/sand have r≈g≈b in warm range)
            let rule1 = r > 95 && g > 40 && b > 20 &&
                        r > g && r > b &&
                        abs(r - g) > 15 && r - b > 20 &&
                        b < g  // skin has b < g; wood/sand often have b ≈ g

            // Rule 2: darker skin tones — tighter channel spread to exclude brown surfaces
            let rule2 = r > 60 && g > 35 && b > 15 &&
                        r > g && g > b &&
                        (r - g) > 5 && (r - g) < 60 && (g - b) > 5 && (g - b) < 50

            if rule1 || rule2 {
                skinPixels += 1
            }
        }

        return Double(skinPixels) / Double(totalPixels)
    }
    
    private nonisolated static func createDefaultLogo() -> UIImage? {
        // Create a simple placeholder logo if no image is available
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { rendererContext in
            let context = rendererContext.cgContext

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
        }
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

