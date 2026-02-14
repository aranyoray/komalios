// VisionStage.swift
// Vision analysis using quantized CoreML models

import Foundation
import CoreML
import Vision
import CoreImage

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@available(iOS 17.0, macOS 14.0, *)
actor VisionStage {
    
    // MARK: - Result
    
    struct Result: Sendable {
        let nsfwScore: Float
        let violenceScore: Float
        let categories: [SafetyCategory: Float]
        let framesAnalyzed: Int
    }
    
    // MARK: - Properties
    
    private let nsfwModel: VNCoreMLModel
    private let violenceModel: VNCoreMLModel?
    private let maxImagesPerPage: Int
    private let maxFramesPerVideo: Int
    
    // MARK: - Initialization
    
    init(computeUnits: MLComputeUnits, maxImagesPerPage: Int, maxFramesPerVideo: Int) async throws {
        self.maxImagesPerPage = maxImagesPerPage
        self.maxFramesPerVideo = maxFramesPerVideo
        
        // Load NSFW detector (tiny ~17kB model)
        let nsfwConfig = MLModelConfiguration()
        nsfwConfig.computeUnits = computeUnits
        
        guard let nsfwURL = Bundle.module.url(forResource: "NSFWDetector", withExtension: "mlmodelc") else {
            throw SafetyError.modelNotFound("NSFWDetector.mlmodelc")
        }
        
        let nsfwMLModel = try await MLModel.load(contentsOf: nsfwURL, configuration: nsfwConfig)
        self.nsfwModel = try VNCoreMLModel(for: nsfwMLModel)
        
        // Load optional violence/weapons detector
        if let violenceURL = Bundle.module.url(forResource: "ViolenceDetector", withExtension: "mlmodelc") {
            let violenceMLModel = try await MLModel.load(contentsOf: violenceURL, configuration: nsfwConfig)
            self.violenceModel = try VNCoreMLModel(for: violenceMLModel)
        } else {
            self.violenceModel = nil
        }
    }
    
    // MARK: - Analysis
    
    func analyze(_ media: MediaInput) async throws -> Result {
        switch media.type {
        case .image(let data), .thumbnail(let data):
            return try await analyzeImage(data)
            
        case .video(let url):
            return try await analyzeVideo(url)
        }
    }
    
    // MARK: - Private Methods
    
    private func analyzeImage(_ data: Data) async throws -> Result {
        guard let image = createCGImage(from: data) else {
            throw SafetyError.invalidInput("Cannot create image from data")
        }
        
        // Downscale to max 224px for efficiency
        let downscaled = downscale(image, maxDimension: 224)
        
        // Run NSFW detection
        let nsfwScore = try await runNSFWDetection(on: downscaled)
        
        // Run violence detection if available
        var violenceScore: Float = 0
        if violenceModel != nil {
            violenceScore = try await runViolenceDetection(on: downscaled)
        }
        
        // Map to categories
        var categories: [SafetyCategory: Float] = [:]
        if nsfwScore > 0.3 {
            categories[.explicit] = nsfwScore
        }
        if violenceScore > 0.3 {
            categories[.violence] = violenceScore
        }
        
        return Result(
            nsfwScore: nsfwScore,
            violenceScore: violenceScore,
            categories: categories,
            framesAnalyzed: 1
        )
    }
    
    private func analyzeVideo(_ url: URL) async throws -> Result {
        // Sample frames at start, middle, end
        let frames = try await sampleVideoFrames(url, count: maxFramesPerVideo)
        
        var maxNSFW: Float = 0
        var maxViolence: Float = 0
        var allCategories: [SafetyCategory: Float] = [:]
        
        for frame in frames {
            let result = try await analyzeImage(frame)
            maxNSFW = max(maxNSFW, result.nsfwScore)
            maxViolence = max(maxViolence, result.violenceScore)
            
            for (category, score) in result.categories {
                allCategories[category] = max(allCategories[category] ?? 0, score)
            }
        }
        
        return Result(
            nsfwScore: maxNSFW,
            violenceScore: maxViolence,
            categories: allCategories,
            framesAnalyzed: frames.count
        )
    }
    
    private func runNSFWDetection(on image: CGImage) async throws -> Float {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNCoreMLRequest(model: nsfwModel) { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let results = request.results as? [VNClassificationObservation],
                      let nsfwResult = results.first(where: { $0.identifier == "NSFW" }) else {
                    continuation.resume(returning: 0.0)
                    return
                }
                
                continuation.resume(returning: nsfwResult.confidence)
            }
            
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func runViolenceDetection(on image: CGImage) async throws -> Float {
        guard let model = violenceModel else { return 0.0 }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let results = request.results as? [VNClassificationObservation],
                      let violenceResult = results.first(where: { $0.identifier == "violence" }) else {
                    continuation.resume(returning: 0.0)
                    return
                }
                
                continuation.resume(returning: violenceResult.confidence)
            }
            
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func sampleVideoFrames(_ url: URL, count: Int) async throws -> [Data] {
        // Simplified frame sampling - in production use AVAssetImageGenerator
        var frames: [Data] = []
        
        // For now, just return empty - implement proper video frame extraction
        // using AVAssetImageGenerator with CMTime positions
        
        return frames
    }
    
    private func createCGImage(from data: Data) -> CGImage? {
        #if canImport(UIKit)
        guard let uiImage = UIImage(data: data) else { return nil }
        return uiImage.cgImage
        #elseif canImport(AppKit)
        guard let nsImage = NSImage(data: data) else { return nil }
        var rect = NSRect(origin: .zero, size: nsImage.size)
        return nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        #else
        return nil
        #endif
    }
    
    private func downscale(_ image: CGImage, maxDimension: Int) -> CGImage {
        let width = image.width
        let height = image.height
        
        // Already small enough
        if width <= maxDimension && height <= maxDimension {
            return image
        }
        
        // Calculate new dimensions
        let scale = CGFloat(maxDimension) / CGFloat(max(width, height))
        let newWidth = Int(CGFloat(width) * scale)
        let newHeight = Int(CGFloat(height) * scale)
        
        // Create context
        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return image
        }
        
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        
        return context.makeImage() ?? image
    }
}
