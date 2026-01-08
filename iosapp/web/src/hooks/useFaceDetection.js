/**
 * Lightweight face detection for engagement tracking
 * Uses browser Face Detection API when available (battery-efficient)
 * Falls back to minimal ML model for other browsers
 */

import { useEffect, useRef, useState, useCallback } from 'react';
import { useMLWorker } from './useMLWorker';
import { ThrottledRAF } from '../utils/ml/throttle';
import { batteryManager } from '../utils/ml/batteryManager';

export const useFaceDetection = () => {
  const [isSupported, setIsSupported] = useState(false);
  const [isActive, setIsActive] = useState(false);
  const [faceDetected, setFaceDetected] = useState(false);
  const [faceConfidence, setFaceConfidence] = useState(0);
  const [facePosition, setFacePosition] = useState(null);
  const [engagementScore, setEngagementScore] = useState(0.5);

  const videoRef = useRef(null);
  const canvasRef = useRef(null);
  const rafRef = useRef(null);
  const faceDetectorRef = useRef(null);
  const statsRef = useRef({
    detections: 0,
    totalFrames: 0,
    lastDetectionTime: 0,
    consecutiveDetections: 0
  });

  const mlWorker = useMLWorker();

  // Check for browser Face Detection API support
  useEffect(() => {
    const checkSupport = async () => {
      // Check for Shape Detection API (experimental)
      if ('FaceDetector' in window) {
        try {
          const detector = new window.FaceDetector({
            fastMode: true, // Faster but less accurate
            maxDetectedFaces: 1 // Only need to detect one face
          });
          faceDetectorRef.current = detector;
          setIsSupported(true);
          console.log('[FaceDetection] Using browser Face Detection API');
          return;
        } catch (error) {
          console.warn('[FaceDetection] Face Detection API not supported:', error);
        }
      }

      // Fallback: Could use a lightweight ML model here
      // For now, we'll use a simple heuristic approach
      setIsSupported(true);
      console.log('[FaceDetection] Using heuristic face detection');
    };

    checkSupport();
    batteryManager.init();
  }, []);

  /**
   * Detect face in video frame using browser API
   */
  const detectFaceNative = useCallback(async (videoElement) => {
    if (!faceDetectorRef.current) return null;

    try {
      const faces = await faceDetectorRef.current.detect(videoElement);

      if (faces.length > 0) {
        const face = faces[0];
        return {
          detected: true,
          confidence: face.confidence || 0.9,
          boundingBox: face.boundingBox,
          landmarks: face.landmarks
        };
      }

      return { detected: false, confidence: 0 };
    } catch (error) {
      console.error('[FaceDetection] Detection error:', error);
      return { detected: false, confidence: 0 };
    }
  }, []);

  /**
   * Simple heuristic face detection based on motion and brightness
   * This is a fallback and not as accurate, but very battery-efficient
   */
  const detectFaceHeuristic = useCallback((videoElement, canvas) => {
    const ctx = canvas.getContext('2d');
    const width = 160; // Low res for efficiency
    const height = 120;

    canvas.width = width;
    canvas.height = height;

    ctx.drawImage(videoElement, 0, 0, width, height);
    const imageData = ctx.getImageData(0, 0, width, height);
    const data = imageData.data;

    let totalBrightness = 0;
    let pixelCount = 0;
    let skinTonePixels = 0;

    // Analyze center region (where face is likely to be)
    const centerX = Math.floor(width / 2);
    const centerY = Math.floor(height / 2);
    const regionSize = 60;

    for (let y = centerY - regionSize / 2; y < centerY + regionSize / 2; y++) {
      for (let x = centerX - regionSize / 2; x < centerX + regionSize / 2; x++) {
        if (x < 0 || x >= width || y < 0 || y >= height) continue;

        const i = (y * width + x) * 4;
        const r = data[i];
        const g = data[i + 1];
        const b = data[i + 2];

        const brightness = (r + g + b) / 3;
        totalBrightness += brightness;
        pixelCount++;

        // Very rough skin tone detection (not accurate but fast)
        if (r > 95 && g > 40 && b > 20 &&
            r > g && r > b &&
            Math.abs(r - g) > 15) {
          skinTonePixels++;
        }
      }
    }

    const avgBrightness = totalBrightness / pixelCount;
    const skinRatio = skinTonePixels / pixelCount;

    // Heuristic: face likely present if:
    // - Moderate brightness (not too dark/bright)
    // - Some skin-tone pixels in center
    const brightnessOk = avgBrightness > 50 && avgBrightness < 220;
    const skinToneOk = skinRatio > 0.15;

    const detected = brightnessOk && skinToneOk;
    const confidence = detected ? Math.min(0.7, skinRatio * 2) : 0;

    return {
      detected,
      confidence,
      avgBrightness,
      skinRatio
    };
  }, []);

  /**
   * Main detection loop
   */
  const detectionLoop = useCallback(async () => {
    if (!videoRef.current || !isActive) return;

    const stats = statsRef.current;
    stats.totalFrames++;

    let result;

    // Use native API if available
    if (faceDetectorRef.current) {
      result = await detectFaceNative(videoRef.current);
    } else {
      // Use heuristic fallback
      if (!canvasRef.current) {
        canvasRef.current = document.createElement('canvas');
      }
      result = detectFaceHeuristic(videoRef.current, canvasRef.current);
    }

    const now = performance.now();

    if (result.detected) {
      stats.detections++;
      stats.consecutiveDetections++;
      stats.lastDetectionTime = now;

      setFaceDetected(true);
      setFaceConfidence(result.confidence);

      if (result.boundingBox) {
        setFacePosition(result.boundingBox);
      }
    } else {
      stats.consecutiveDetections = 0;
      setFaceDetected(false);
      setFaceConfidence(0);
    }

    // Calculate engagement score
    // Factors: detection rate, consistency, recent activity
    const detectionRate = stats.detections / Math.max(1, stats.totalFrames);
    const recency = Math.max(0, 1 - (now - stats.lastDetectionTime) / 5000); // 5s decay
    const consistency = Math.min(1, stats.consecutiveDetections / 10); // 10 frames = max

    const engagement = 0.4 * detectionRate + 0.3 * recency + 0.3 * consistency;
    setEngagementScore(Number(Math.max(0, Math.min(1, engagement)).toFixed(2)));

  }, [isActive, detectFaceNative, detectFaceHeuristic]);

  /**
   * Start face detection
   */
  const startDetection = useCallback((videoElement) => {
    if (!isSupported || isActive) return;

    videoRef.current = videoElement;
    setIsActive(true);

    // Reset stats
    statsRef.current = {
      detections: 0,
      totalFrames: 0,
      lastDetectionTime: performance.now(),
      consecutiveDetections: 0
    };

    // Use throttled RAF based on battery
    const fps = batteryManager.isCharging ? 10 : 5;
    rafRef.current = new ThrottledRAF(fps);

    rafRef.current.start(() => {
      detectionLoop();
    });

    console.log(`[FaceDetection] Started at ${fps} FPS`);
  }, [isSupported, isActive, detectionLoop]);

  /**
   * Stop face detection
   */
  const stopDetection = useCallback(() => {
    if (!isActive) return;

    if (rafRef.current) {
      rafRef.current.stop();
      rafRef.current = null;
    }

    setIsActive(false);
    setFaceDetected(false);
    setFaceConfidence(0);
    setEngagementScore(0.5);

    console.log('[FaceDetection] Stopped');
  }, [isActive]);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      stopDetection();
    };
  }, [stopDetection]);

  return {
    isSupported,
    isActive,
    faceDetected,
    faceConfidence,
    facePosition,
    engagementScore,
    startDetection,
    stopDetection,
    stats: {
      detectionRate: statsRef.current.totalFrames > 0
        ? (statsRef.current.detections / statsRef.current.totalFrames).toFixed(2)
        : 0,
      totalFrames: statsRef.current.totalFrames
    }
  };
};
