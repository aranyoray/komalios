//
//  RevealingLevelClassifier.swift
//  Komalios
//
//  Body region / revealing level classification using Apple Vision APIs.
//  Protocol-based design allows future CoreML model swap-in.
//

#if os(iOS)
import Foundation
import UIKit
import Vision
import CoreML

// MARK: - Revealing Level

/// Revealing level 0-5 based on aggregate body region exposure scoring
enum RevealingLevel: Int, Codable, Comparable, CaseIterable {
    case fullyCovered    = 0  // score == 0
    case modestCasual    = 1  // score ≤ 1
    case partialExposure = 2  // score ≤ 2
    case revealing       = 3  // score ≤ 3.5
    case highlyRevealing = 4  // score ≤ 5
    case explicitExposure = 5 // score > 5

    static func from(score: Double) -> RevealingLevel {
        switch score {
        case ...0:     return .fullyCovered
        case ...0.8:   return .modestCasual
        case ...1.5:   return .partialExposure  // lowered from 2.0 to catch bikini earlier
        case ...3.0:   return .revealing         // lowered from 3.5
        case ...4.5:   return .highlyRevealing   // lowered from 5.0
        default:       return .explicitExposure
        }
    }

    var displayName: String {
        switch self {
        case .fullyCovered:     return "Fully Covered"
        case .modestCasual:     return "Modest Casual"
        case .partialExposure:  return "Partial Skin Exposure"
        case .revealing:        return "Revealing"
        case .highlyRevealing:  return "Highly Revealing"
        case .explicitExposure: return "Explicit Exposure"
        }
    }

    static func < (lhs: RevealingLevel, rhs: RevealingLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Body Regions (20 zones per specification)

enum BodyRegion: String, CaseIterable {
    case face, chest, cleavage, nipple, breast, underBreast
    case abdomenCenter, abdomenSide, umbilical, abdomenLow
    case genitals, anus, butt, sacral
    case backLow, backMid, backHigh
    case femurHigh, femurMid, femurLow

    /// Whether this region is a "core" region for scoring
    var isCoreRegion: Bool {
        switch self {
        case .breast, .nipple, .chest, .cleavage, .underBreast,
             .genitals, .anus,
             .butt:
            return true
        default:
            return false
        }
    }

    /// Scoring weight for full exposure of this region
    var fullExposureWeight: Double {
        switch self {
        case .genitals, .anus:       return 2.0
        case .nipple, .breast:       return 1.5
        case .butt:                  return 1.0
        case .cleavage, .underBreast, .chest: return 0.8
        case .abdomenLow:            return 0.5
        case .femurHigh:             return 0.4
        case .abdomenCenter, .umbilical, .abdomenSide: return 0.3
        case .backLow, .sacral:      return 0.3
        case .backMid, .backHigh:    return 0.2
        case .femurMid:              return 0.2
        case .femurLow:              return 0.1
        case .face:                  return 0.0
        }
    }
}

/// Exposure level for a single body region
enum RegionExposure: Double {
    case covered  = 0.0
    case partial  = 0.5
    case full     = 1.0
}

// MARK: - Result

struct RevealingLevelResult {
    let level: RevealingLevel
    let aggregateScore: Double
    let regionExposures: [BodyRegion: RegionExposure]
    let personDetected: Bool
    let minorDetected: Bool

    static let notApplicable = RevealingLevelResult(
        level: .fullyCovered,
        aggregateScore: 0,
        regionExposures: [:],
        personDetected: false,
        minorDetected: false
    )
}

// MARK: - Protocol (for future CoreML swap-in)

protocol BodyRegionClassifier {
    func classify(image: UIImage) async -> RevealingLevelResult
}

// MARK: - Heuristic Implementation using Apple Vision APIs

final class VisionBodyRegionClassifier: BodyRegionClassifier {

    // Safety constraints from spec
    private let rejectIfMinorDetected = true

    func classify(image: UIImage) async -> RevealingLevelResult {
        #if targetEnvironment(simulator)
        // Vision body-pose and CoreML inference require Neural Engine / real GPU.
        // The simulator has neither, so skip and return notApplicable to avoid log spam.
        return .notApplicable
        #else
        guard let cgImage = image.cgImage else {
            return .notApplicable
        }

        // Step 1: Detect human body pose (joint positions)
        let poseResult = await Task.detached { self.detectBodyPose(cgImage: cgImage) }.value
        guard poseResult.personDetected else {
            return .notApplicable
        }

        // Safety: reject if minor detected
        if rejectIfMinorDetected && poseResult.appearsMinor {
            return RevealingLevelResult(
                level: .fullyCovered,
                aggregateScore: 0,
                regionExposures: [:],
                personDetected: true,
                minorDetected: true
            )
        }

        // Steps 2+3: Generate segmentation mask and analyze regions in one detached task
        // so CVPixelBuffer (non-Sendable) never crosses a task/actor boundary
        let joints = poseResult.joints
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let regionExposures = await Task.detached {
            let segmentationMask = self.generatePersonSegmentation(cgImage: cgImage)
            return self.analyzeRegionExposure(
                cgImage: cgImage,
                joints: joints,
                segmentationMask: segmentationMask,
                imageSize: imageSize
            )
        }.value

        // Step 4: Score core regions with weights
        var aggregateScore: Double = 0.0
        for (region, exposure) in regionExposures {
            aggregateScore += region.fullExposureWeight * exposure.rawValue
        }

        // Step 5: Map to revealing level
        let level = RevealingLevel.from(score: aggregateScore)

        return RevealingLevelResult(
            level: level,
            aggregateScore: aggregateScore,
            regionExposures: regionExposures,
            personDetected: true,
            minorDetected: false
        )
        #endif // !targetEnvironment(simulator)
    }

    // MARK: - Step 1: Body Pose Detection (~10-20ms on Neural Engine)

    private struct PoseResult {
        let personDetected: Bool
        let joints: [VNHumanBodyPoseObservation.JointName: CGPoint]
        let appearsMinor: Bool
    }

    nonisolated private func detectBodyPose(cgImage: CGImage) -> PoseResult {
        // Try with Neural Engine first, fall back to CPU-only if inference context fails
        if let result = performBodyPoseRequest(cgImage: cgImage, cpuOnly: false) {
            return result
        }
        // Neural Engine unavailable (common on-device under memory pressure) — retry CPU-only
        if let result = performBodyPoseRequest(cgImage: cgImage, cpuOnly: true) {
            return result
        }
        return PoseResult(personDetected: false, joints: [:], appearsMinor: false)
    }

    /// Synchronous body pose detection. Returns nil if the Vision request fails.
    private func performBodyPoseRequest(cgImage: CGImage, cpuOnly: Bool) -> PoseResult? {
        let request = VNDetectHumanBodyPoseRequest()
        if cpuOnly {
            Self.forceCPU(request)
        }
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            #if DEBUG
            print("🛡️ Body pose detection failed (cpuOnly=\(cpuOnly)): \(error.localizedDescription)")
            #endif
            return nil
        }

        guard let observations = request.results,
              let observation = observations.first else {
            return PoseResult(personDetected: false, joints: [:], appearsMinor: false)
        }

        var joints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        let allJoints: [VNHumanBodyPoseObservation.JointName] = [
            .nose, .neck,
            .leftShoulder, .rightShoulder,
            .leftElbow, .rightElbow,
            .leftWrist, .rightWrist,
            .leftHip, .rightHip,
            .leftKnee, .rightKnee,
            .leftAnkle, .rightAnkle,
            .root // center of hips
        ]

        for jointName in allJoints {
            if let point = try? observation.recognizedPoint(jointName),
               point.confidence > 0.3 {
                // Vision coordinates: origin at bottom-left, normalized 0-1
                joints[jointName] = CGPoint(x: point.location.x, y: point.location.y)
            }
        }

        let appearsMinor = self.estimateMinorFromPose(joints: joints)

        return PoseResult(
            personDetected: !joints.isEmpty,
            joints: joints,
            appearsMinor: appearsMinor
        )
    }

    /// Force a VNRequest to run on CPU, bypassing the Neural Engine.
    private static func forceCPU(_ request: VNRequest) {
        if #available(iOS 17, *) {
            let cpuDevice = MLComputeDevice.allComputeDevices.first {
                if case .cpu = $0 { return true }
                return false
            }
            request.setComputeDevice(cpuDevice, for: .main)
        } else {
            request.usesCPUOnly = true
        }
    }

    /// Conservative heuristic: if head-to-torso ratio suggests a child, flag as minor
    private func estimateMinorFromPose(joints: [VNHumanBodyPoseObservation.JointName: CGPoint]) -> Bool {
        guard let nose = joints[.nose],
              let neck = joints[.neck],
              let leftHip = joints[.leftHip],
              let rightHip = joints[.rightHip] else {
            return false // Can't determine — default to not-minor (safer to classify)
        }

        let headHeight = abs(nose.y - neck.y)
        let hipCenter = CGPoint(x: (leftHip.x + rightHip.x) / 2, y: (leftHip.y + rightHip.y) / 2)
        let torsoHeight = abs(neck.y - hipCenter.y)

        guard torsoHeight > 0 else { return false }

        // Children typically have head:torso ratio > 0.5
        // Adults are typically < 0.4
        let ratio = headHeight / torsoHeight
        return ratio > 0.5
    }

    // MARK: - Step 2: Person Segmentation (~20-40ms on Neural Engine)

    nonisolated private func generatePersonSegmentation(cgImage: CGImage) -> CVPixelBuffer? {
        // Try Neural Engine first, fall back to CPU-only
        if let mask = performSegmentationRequest(cgImage: cgImage, cpuOnly: false) {
            return mask
        }
        return performSegmentationRequest(cgImage: cgImage, cpuOnly: true)
    }

    /// Synchronous person segmentation. Returns nil if the Vision request fails.
    private func performSegmentationRequest(cgImage: CGImage, cpuOnly: Bool) -> CVPixelBuffer? {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .balanced
        if cpuOnly {
            Self.forceCPU(request)
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            return request.results?.first?.pixelBuffer
        } catch {
            #if DEBUG
            print("🛡️ Person segmentation failed (cpuOnly=\(cpuOnly)): \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    // MARK: - Step 3: Region Exposure Analysis

    private func analyzeRegionExposure(
        cgImage: CGImage,
        joints: [VNHumanBodyPoseObservation.JointName: CGPoint],
        segmentationMask: CVPixelBuffer?,
        imageSize: CGSize
    ) -> [BodyRegion: RegionExposure] {
        var exposures: [BodyRegion: RegionExposure] = [:]

        // Map body joints to approximate body regions (primary + right-leg alternates)
        let (regionRects, rightLegRects) = mapJointsToRegions(joints: joints, imageSize: imageSize)

        // For each region, sample skin-tone pixels within the person mask
        for (region, rect) in regionRects {
            let skinRatio = sampleSkinToneInRegion(
                cgImage: cgImage,
                rect: rect,
                segmentationMask: segmentationMask,
                imageSize: imageSize
            )

            // If there's a right-leg alternate for this region, take the max ratio
            var effectiveRatio = skinRatio
            if let altRect = rightLegRects[region] {
                let altRatio = sampleSkinToneInRegion(
                    cgImage: cgImage,
                    rect: altRect,
                    segmentationMask: segmentationMask,
                    imageSize: imageSize
                )
                effectiveRatio = max(skinRatio, altRatio)
            }

            // Map skin ratio to exposure level
            // Lowered thresholds to catch bikini/swimwear (was 0.6/0.3)
            if effectiveRatio > 0.50 {
                exposures[region] = .full
            } else if effectiveRatio > 0.22 {
                exposures[region] = .partial
            } else {
                exposures[region] = .covered
            }
        }

        return exposures
    }

    /// Approximate body regions from joint positions.
    /// Returns (primary regions, right-leg alternate rects for dual-leg max analysis).
    private func mapJointsToRegions(
        joints: [VNHumanBodyPoseObservation.JointName: CGPoint],
        imageSize: CGSize
    ) -> (primary: [BodyRegion: CGRect], rightLeg: [BodyRegion: CGRect]) {
        var regions: [BodyRegion: CGRect] = [:]
        var rightLegRects: [BodyRegion: CGRect] = [:]
        let w = imageSize.width
        let h = imageSize.height
        let regionSize: CGFloat = 0.08 // ~8% of image per region sample

        // Helper to create a rect centered on a normalized point.
        // Vision coordinates have Y=0 at bottom-left, but CGImage has Y=0 at
        // top-left. Flip Y before converting to pixel coordinates.
        func rect(center: CGPoint, scale: CGFloat = 1.0) -> CGRect {
            let size = regionSize * scale
            let pixelX = (center.x - size / 2) * w
            let pixelY = ((1.0 - center.y) - size / 2) * h
            return CGRect(
                x: pixelX,
                y: pixelY,
                width: size * w,
                height: size * h
            )
        }

        // Helper to get midpoint
        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        }

        // Face region
        if let nose = joints[.nose] {
            regions[.face] = rect(center: nose, scale: 1.5)
        }

        // Chest / breast region (between neck and mid-torso)
        if let neck = joints[.neck],
           let leftShoulder = joints[.leftShoulder],
           let rightShoulder = joints[.rightShoulder] {
            let shoulderCenter = mid(leftShoulder, rightShoulder)
            let chestCenter = CGPoint(x: shoulderCenter.x, y: neck.y - (neck.y - shoulderCenter.y) * 0.5)
            regions[.chest] = rect(center: chestCenter, scale: 1.5)

            // Cleavage: midpoint between shoulders, at neck-to-shoulder center depth
            let cleavageCenter = CGPoint(x: shoulderCenter.x, y: (neck.y + shoulderCenter.y) / 2)
            regions[.cleavage] = rect(center: cleavageCenter)

            // Breast area: slightly below shoulder center
            if let root = joints[.root] {
                let breastY = shoulderCenter.y + (root.y - shoulderCenter.y) * 0.2
                regions[.breast] = rect(center: CGPoint(x: shoulderCenter.x, y: breastY), scale: 1.2)
                regions[.underBreast] = rect(center: CGPoint(x: shoulderCenter.x, y: breastY - 0.03))

                // Nipples: offset left and right from chest center at breast height
                let shoulderHalfWidth = abs(leftShoulder.x - rightShoulder.x) / 2
                let nippleOffsetX = shoulderHalfWidth * 0.45
                regions[.nipple] = rect(center: CGPoint(x: shoulderCenter.x - nippleOffsetX, y: breastY))
                // Note: single .nipple region — uses left side; right side covered by breast rect overlap
            }
        }

        // Abdomen regions (between chest and hips)
        if let root = joints[.root], let neck = joints[.neck] {
            let midTorso = mid(neck, root)
            regions[.abdomenCenter] = rect(center: midTorso)
            regions[.umbilical] = rect(center: CGPoint(x: midTorso.x, y: midTorso.y - 0.03))
            regions[.abdomenLow] = rect(center: CGPoint(x: root.x, y: root.y + 0.02))

            // Abdomen sides: offset left and right from abdomen center
            if let leftHip = joints[.leftHip], let rightHip = joints[.rightHip] {
                let hipHalfWidth = abs(leftHip.x - rightHip.x) / 2
                let sideOffsetX = hipHalfWidth * 0.8
                // Use left side as primary (right side largely symmetric)
                regions[.abdomenSide] = rect(center: CGPoint(x: midTorso.x - sideOffsetX, y: midTorso.y))
            }
        }

        // Pelvis / genitals region (at hip center)
        if let leftHip = joints[.leftHip], let rightHip = joints[.rightHip] {
            let hipCenter = mid(leftHip, rightHip)
            regions[.genitals] = rect(center: CGPoint(x: hipCenter.x, y: hipCenter.y - 0.03))
        }

        // Buttocks (behind hip center, approximated at same level)
        if let root = joints[.root] {
            regions[.butt] = rect(center: CGPoint(x: root.x, y: root.y - 0.02), scale: 1.2)
            // Anus: slightly below butt center, between hips
            regions[.anus] = rect(center: CGPoint(x: root.x, y: root.y - 0.04))
        }

        // Upper leg / femur regions — sample both legs, keep both rects
        // (analyzeRegionExposure will take max exposure across left/right)
        if let leftHip = joints[.leftHip], let leftKnee = joints[.leftKnee] {
            let femurHigh = CGPoint(x: leftHip.x, y: leftHip.y - (leftHip.y - leftKnee.y) * 0.2)
            let femurMid = mid(leftHip, leftKnee)
            let femurLow = CGPoint(x: leftKnee.x, y: leftKnee.y + (leftHip.y - leftKnee.y) * 0.2)
            regions[.femurHigh] = rect(center: femurHigh)
            regions[.femurMid] = rect(center: femurMid)
            regions[.femurLow] = rect(center: femurLow)
        }
        // Right leg: override with right-leg rect if it yields higher exposure
        // Store right-leg rects separately so we can compare in analyzeRegionExposure
        if let rightHip = joints[.rightHip], let rightKnee = joints[.rightKnee] {
            let rFemurHigh = CGPoint(x: rightHip.x, y: rightHip.y - (rightHip.y - rightKnee.y) * 0.2)
            let rFemurMid = mid(rightHip, rightKnee)
            let rFemurLow = CGPoint(x: rightKnee.x, y: rightKnee.y + (rightHip.y - rightKnee.y) * 0.2)
            // If left leg wasn't detected, use right leg directly
            if regions[.femurHigh] == nil {
                regions[.femurHigh] = rect(center: rFemurHigh)
                regions[.femurMid] = rect(center: rFemurMid)
                regions[.femurLow] = rect(center: rFemurLow)
            } else {
                // Both legs detected — store right-leg rects for dual-leg analysis
                rightLegRects[.femurHigh] = rect(center: rFemurHigh)
                rightLegRects[.femurMid] = rect(center: rFemurMid)
                rightLegRects[.femurLow] = rect(center: rFemurLow)
            }
        }

        // Back regions (approximate from shoulder/hip positions, slightly offset)
        if let neck = joints[.neck], let root = joints[.root] {
            let backHigh = CGPoint(x: neck.x + 0.02, y: neck.y)
            let backMid = CGPoint(x: mid(neck, root).x + 0.02, y: mid(neck, root).y)
            let backLow = CGPoint(x: root.x + 0.02, y: root.y)
            regions[.backHigh] = rect(center: backHigh)
            regions[.backMid] = rect(center: backMid)
            regions[.backLow] = rect(center: backLow)
            regions[.sacral] = rect(center: CGPoint(x: root.x + 0.02, y: root.y - 0.02))
        }

        return (regions, rightLegRects)
    }

    /// Sample skin-tone pixels in a given region, masked by person segmentation
    private func sampleSkinToneInRegion(
        cgImage: CGImage,
        rect: CGRect,
        segmentationMask: CVPixelBuffer?,
        imageSize: CGSize
    ) -> Double {
        // Clamp rect to image bounds
        let clampedRect = rect.intersection(CGRect(origin: .zero, size: imageSize))
        guard !clampedRect.isEmpty else { return 0.0 }

        // Sample at reduced resolution for performance
        let sampleWidth = min(Int(clampedRect.width), 30)
        let sampleHeight = min(Int(clampedRect.height), 30)
        guard sampleWidth > 0, sampleHeight > 0 else { return 0.0 }

        guard let context = CGContext(
            data: nil,
            width: sampleWidth,
            height: sampleHeight,
            bitsPerComponent: 8,
            bytesPerRow: sampleWidth * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return 0.0 }

        // Draw the region of the original image
        context.draw(cgImage, in: CGRect(
            x: -clampedRect.origin.x * CGFloat(sampleWidth) / clampedRect.width,
            y: -clampedRect.origin.y * CGFloat(sampleHeight) / clampedRect.height,
            width: imageSize.width * CGFloat(sampleWidth) / clampedRect.width,
            height: imageSize.height * CGFloat(sampleHeight) / clampedRect.height
        ))

        guard let data = context.data else { return 0.0 }
        let pointer = data.bindMemory(to: UInt8.self, capacity: sampleWidth * sampleHeight * 4)

        // Lock the segmentation mask if available so we can read per-pixel person/background
        var maskBaseAddress: UnsafeMutableRawPointer?
        var maskBytesPerRow = 0
        var maskWidth = 0
        var maskHeight = 0
        if let mask = segmentationMask {
            let lockStatus = CVPixelBufferLockBaseAddress(mask, .readOnly)
            guard lockStatus == kCVReturnSuccess else {
                // Lock failed — skip mask-based analysis, return safe default
                return 0.0
            }
            maskBaseAddress = CVPixelBufferGetBaseAddress(mask)
            maskBytesPerRow = CVPixelBufferGetBytesPerRow(mask)
            maskWidth = CVPixelBufferGetWidth(mask)
            maskHeight = CVPixelBufferGetHeight(mask)
        }

        var skinPixels = 0
        var personPixels = 0
        let totalPixels = sampleWidth * sampleHeight

        for i in 0..<totalPixels {
            let col = i % sampleWidth
            let row = i / sampleWidth

            // If we have a segmentation mask, check whether this pixel is on the person
            if let baseAddr = maskBaseAddress, maskWidth > 0, maskHeight > 0 {
                // Map sample-space (col, row) back to original image coordinates
                let origX = clampedRect.origin.x + CGFloat(col) * clampedRect.width / CGFloat(sampleWidth)
                let origY = clampedRect.origin.y + CGFloat(row) * clampedRect.height / CGFloat(sampleHeight)

                // Map original image coordinates to mask coordinates
                // Note: segmentation mask may have different dimensions than the source image
                let maskX = Int(origX * CGFloat(maskWidth) / imageSize.width)
                // Vision segmentation mask has origin at top-left (unlike pose joints)
                // CGImage also has origin at top-left, so no flip needed
                let maskY = Int(origY * CGFloat(maskHeight) / imageSize.height)

                if maskX >= 0, maskX < maskWidth, maskY >= 0, maskY < maskHeight {
                    let maskPtr = baseAddr.assumingMemoryBound(to: UInt8.self)
                    let maskValue = maskPtr[maskY * maskBytesPerRow + maskX]
                    // Mask value 0 = background, >0 = person
                    if maskValue == 0 {
                        continue // Skip background pixels entirely
                    }
                }
                personPixels += 1
            } else {
                // No mask available — count all pixels (fallback behavior)
                personPixels += 1
            }

            let offset = i * 4
            let r = Int(pointer[offset])
            let g = Int(pointer[offset + 1])
            let b = Int(pointer[offset + 2])

            // Skin tone detection (diverse skin tone ranges in RGB)
            if isSkinTone(r: r, g: g, b: b) {
                skinPixels += 1
            }
        }

        // Unlock the mask
        if let mask = segmentationMask {
            CVPixelBufferUnlockBaseAddress(mask, .readOnly)
        }

        // Ratio is skin pixels over person pixels (not total pixels)
        // This eliminates background noise from the score
        return personPixels > 0 ? Double(skinPixels) / Double(personPixels) : 0.0
    }

    /// Gender-neutral, diverse skin tone detection
    private func isSkinTone(r: Int, g: Int, b: Int) -> Bool {
        // RGB-based skin detection covering diverse skin tones
        // Rule 1: RGB range check (covers light to medium skin)
        let rule1 = r > 80 && g > 30 && b > 15 &&
                    r > g && r > b &&
                    abs(r - g) > 10 &&
                    r - b > 10

        // Rule 2: Additional check for darker skin tones
        let rule2 = r > 50 && g > 30 && b > 15 &&
                    r > g && g > b &&
                    (r - g) < 80 && (g - b) < 80

        return rule1 || rule2
    }
}

// MARK: - RevealingLevelClassifier Singleton

final class RevealingLevelClassifier {
    static let shared = RevealingLevelClassifier()

    private let classifier: BodyRegionClassifier

    private init() {
        // Use Vision-based heuristic classifier
        // Future: swap in CoreML model here
        self.classifier = VisionBodyRegionClassifier()
    }

    /// Classify revealing level of an image
    func classify(image: UIImage) async -> RevealingLevelResult {
        await classifier.classify(image: image)
    }
}
#endif

