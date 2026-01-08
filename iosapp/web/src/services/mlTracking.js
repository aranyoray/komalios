/**
 * ML Tracking Service
 * Eye tracking, face detection, and voice analysis
 */

import { FaceMesh } from '@mediapipe/face_mesh';
import { Camera } from '@mediapipe/camera_utils';

// Eye tracking landmarks indices
const LEFT_EYE = [33, 7, 163, 144, 145, 153, 154, 155, 133, 173, 157, 158, 159, 160, 161, 246];
const RIGHT_EYE = [362, 382, 381, 380, 374, 373, 390, 249, 263, 466, 388, 387, 386, 385, 384, 398];
const LEFT_IRIS = [468, 469, 470, 471, 472];
const RIGHT_IRIS = [473, 474, 475, 476, 477];

class MLTrackingService {
  constructor() {
    this.faceMesh = null;
    this.camera = null;
    this.isInitialized = false;
    this.callbacks = {
      onEyeGaze: null,
      onFaceEmotion: null,
      onAttention: null,
      onBlink: null,
    };

    // Tracking metrics
    this.metrics = {
      gazePoints: [],
      blinkCount: 0,
      attentionScore: 100,
      emotionHistory: [],
      fixationDuration: 0,
      saccadeCount: 0,
      lookAwayCount: 0,
      lastGazeTime: Date.now(),
    };

    // Calibration data
    this.calibration = {
      isCalibrated: false,
      centerPoint: { x: 0.5, y: 0.5 },
      scale: 1,
    };

    // Blink detection
    this.eyeAspectRatioHistory = [];
    this.blinkThreshold = 0.2;
    this.lastBlinkTime = 0;
  }

  async initialize(videoElement, onResults) {
    this.faceMesh = new FaceMesh({
      locateFile: (file) => `https://cdn.jsdelivr.net/npm/@mediapipe/face_mesh/${file}`,
    });

    this.faceMesh.setOptions({
      maxNumFaces: 1,
      refineLandmarks: true,
      minDetectionConfidence: 0.5,
      minTrackingConfidence: 0.5,
    });

    this.faceMesh.onResults((results) => {
      this.processResults(results);
      if (onResults) onResults(results);
    });

    this.camera = new Camera(videoElement, {
      onFrame: async () => {
        await this.faceMesh.send({ image: videoElement });
      },
      width: 640,
      height: 480,
    });

    await this.camera.start();
    this.isInitialized = true;
  }

  processResults(results) {
    if (!results.multiFaceLandmarks || results.multiFaceLandmarks.length === 0) {
      this.handleNoFaceDetected();
      return;
    }

    const landmarks = results.multiFaceLandmarks[0];

    // Process eye gaze
    const gazeData = this.calculateEyeGaze(landmarks);
    this.updateGazeMetrics(gazeData);

    // Process blink detection
    const blinkDetected = this.detectBlink(landmarks);
    if (blinkDetected) {
      this.metrics.blinkCount++;
      if (this.callbacks.onBlink) {
        this.callbacks.onBlink(this.metrics.blinkCount);
      }
    }

    // Process facial emotions
    const emotion = this.detectEmotion(landmarks);
    this.metrics.emotionHistory.push({
      emotion,
      timestamp: Date.now(),
    });

    // Calculate attention score
    this.updateAttentionScore(gazeData, emotion);

    // Callbacks
    if (this.callbacks.onEyeGaze) {
      this.callbacks.onEyeGaze(gazeData);
    }
    if (this.callbacks.onFaceEmotion) {
      this.callbacks.onFaceEmotion(emotion);
    }
    if (this.callbacks.onAttention) {
      this.callbacks.onAttention(this.metrics.attentionScore);
    }
  }

  calculateEyeGaze(landmarks) {
    // Get iris centers
    const leftIrisCenter = this.getCenter(landmarks, LEFT_IRIS);
    const rightIrisCenter = this.getCenter(landmarks, RIGHT_IRIS);

    // Get eye corners for reference
    const leftEyeLeft = landmarks[33];
    const leftEyeRight = landmarks[133];
    const rightEyeLeft = landmarks[362];
    const rightEyeRight = landmarks[263];

    // Calculate normalized gaze position
    const leftGazeX = (leftIrisCenter.x - leftEyeLeft.x) / (leftEyeRight.x - leftEyeLeft.x);
    const rightGazeX = (rightIrisCenter.x - rightEyeLeft.x) / (rightEyeRight.x - rightEyeLeft.x);

    const gazeX = (leftGazeX + rightGazeX) / 2;
    const gazeY = (leftIrisCenter.y + rightIrisCenter.y) / 2;

    // Apply calibration
    const calibratedX = (gazeX - this.calibration.centerPoint.x) * this.calibration.scale + 0.5;
    const calibratedY = (gazeY - this.calibration.centerPoint.y) * this.calibration.scale + 0.5;

    return {
      x: Math.max(0, Math.min(1, calibratedX)),
      y: Math.max(0, Math.min(1, calibratedY)),
      confidence: 0.85,
      timestamp: Date.now(),
    };
  }

  getCenter(landmarks, indices) {
    let sumX = 0, sumY = 0, sumZ = 0;
    for (const idx of indices) {
      sumX += landmarks[idx].x;
      sumY += landmarks[idx].y;
      sumZ += landmarks[idx].z || 0;
    }
    return {
      x: sumX / indices.length,
      y: sumY / indices.length,
      z: sumZ / indices.length,
    };
  }

  detectBlink(landmarks) {
    // Calculate Eye Aspect Ratio (EAR)
    const leftEAR = this.calculateEAR(landmarks, LEFT_EYE);
    const rightEAR = this.calculateEAR(landmarks, RIGHT_EYE);
    const avgEAR = (leftEAR + rightEAR) / 2;

    this.eyeAspectRatioHistory.push(avgEAR);
    if (this.eyeAspectRatioHistory.length > 10) {
      this.eyeAspectRatioHistory.shift();
    }

    const now = Date.now();
    if (avgEAR < this.blinkThreshold && now - this.lastBlinkTime > 150) {
      this.lastBlinkTime = now;
      return true;
    }
    return false;
  }

  calculateEAR(landmarks, eyeIndices) {
    // Simplified EAR calculation
    const top = landmarks[eyeIndices[1]];
    const bottom = landmarks[eyeIndices[5]];
    const left = landmarks[eyeIndices[0]];
    const right = landmarks[eyeIndices[3]];

    const verticalDist = Math.sqrt(
      Math.pow(top.x - bottom.x, 2) + Math.pow(top.y - bottom.y, 2)
    );
    const horizontalDist = Math.sqrt(
      Math.pow(left.x - right.x, 2) + Math.pow(left.y - right.y, 2)
    );

    return verticalDist / horizontalDist;
  }

  detectEmotion(landmarks) {
    // Simplified emotion detection based on facial landmarks
    const mouth = this.getCenter(landmarks, [61, 291, 0, 17]);
    const leftEyebrow = this.getCenter(landmarks, [70, 63, 105, 66]);
    const rightEyebrow = this.getCenter(landmarks, [300, 293, 334, 296]);
    const nose = landmarks[1];

    // Calculate facial action units
    const mouthOpenness = Math.abs(landmarks[13].y - landmarks[14].y);
    const eyebrowHeight = (leftEyebrow.y + rightEyebrow.y) / 2;
    const mouthCorners = (landmarks[61].y + landmarks[291].y) / 2;

    // Simple emotion classification
    let emotion = 'neutral';
    let confidence = 0.7;

    if (mouthOpenness > 0.03 && mouthCorners < nose.y) {
      emotion = 'happy';
      confidence = 0.8;
    } else if (eyebrowHeight < nose.y - 0.05) {
      emotion = 'surprised';
      confidence = 0.75;
    } else if (mouthCorners > nose.y + 0.01) {
      emotion = 'sad';
      confidence = 0.65;
    } else if (eyebrowHeight > nose.y - 0.02) {
      emotion = 'focused';
      confidence = 0.7;
    }

    return { emotion, confidence, timestamp: Date.now() };
  }

  updateGazeMetrics(gazeData) {
    const now = Date.now();
    this.metrics.gazePoints.push(gazeData);

    // Keep last 100 gaze points
    if (this.metrics.gazePoints.length > 100) {
      this.metrics.gazePoints.shift();
    }

    // Detect saccades (rapid eye movements)
    if (this.metrics.gazePoints.length > 1) {
      const prev = this.metrics.gazePoints[this.metrics.gazePoints.length - 2];
      const dist = Math.sqrt(
        Math.pow(gazeData.x - prev.x, 2) + Math.pow(gazeData.y - prev.y, 2)
      );

      if (dist > 0.1) {
        this.metrics.saccadeCount++;
        this.metrics.fixationDuration = 0;
      } else {
        this.metrics.fixationDuration += now - this.metrics.lastGazeTime;
      }
    }

    // Detect look away
    if (gazeData.x < 0.1 || gazeData.x > 0.9 || gazeData.y < 0.1 || gazeData.y > 0.9) {
      this.metrics.lookAwayCount++;
    }

    this.metrics.lastGazeTime = now;
  }

  updateAttentionScore(gazeData, emotion) {
    let score = this.metrics.attentionScore;

    // Gaze centered = good attention
    const gazeCenteredness = 1 - Math.sqrt(
      Math.pow(gazeData.x - 0.5, 2) + Math.pow(gazeData.y - 0.5, 2)
    );

    // Emotion impact
    const emotionBonus = {
      'focused': 5,
      'happy': 3,
      'neutral': 0,
      'surprised': -2,
      'sad': -5,
    };

    // Update score
    score = score * 0.95 + gazeCenteredness * 100 * 0.05;
    score += (emotionBonus[emotion.emotion] || 0) * 0.1;

    // Clamp
    this.metrics.attentionScore = Math.max(0, Math.min(100, score));
  }

  handleNoFaceDetected() {
    this.metrics.attentionScore = Math.max(0, this.metrics.attentionScore - 2);
    this.metrics.lookAwayCount++;
  }

  calibrate(point) {
    this.calibration.centerPoint = point;
    this.calibration.isCalibrated = true;
  }

  getMetrics() {
    return {
      ...this.metrics,
      avgAttention: this.metrics.attentionScore,
      blinkRate: this.calculateBlinkRate(),
      focusTime: this.metrics.fixationDuration,
      distractionCount: this.metrics.lookAwayCount,
      dominantEmotion: this.getDominantEmotion(),
    };
  }

  calculateBlinkRate() {
    // Blinks per minute
    const duration = (Date.now() - (this.metrics.gazePoints[0]?.timestamp || Date.now())) / 60000;
    return duration > 0 ? Math.round(this.metrics.blinkCount / duration) : 0;
  }

  getDominantEmotion() {
    if (this.metrics.emotionHistory.length === 0) return 'neutral';

    const emotionCounts = {};
    this.metrics.emotionHistory.forEach(({ emotion }) => {
      emotionCounts[emotion] = (emotionCounts[emotion] || 0) + 1;
    });

    return Object.entries(emotionCounts).sort((a, b) => b[1] - a[1])[0][0];
  }

  setCallback(type, callback) {
    if (this.callbacks.hasOwnProperty(type)) {
      this.callbacks[type] = callback;
    }
  }

  reset() {
    this.metrics = {
      gazePoints: [],
      blinkCount: 0,
      attentionScore: 100,
      emotionHistory: [],
      fixationDuration: 0,
      saccadeCount: 0,
      lookAwayCount: 0,
      lastGazeTime: Date.now(),
    };
  }

  stop() {
    if (this.camera) {
      this.camera.stop();
    }
    this.isInitialized = false;
  }
}

export const mlTracking = new MLTrackingService();
export default mlTracking;
