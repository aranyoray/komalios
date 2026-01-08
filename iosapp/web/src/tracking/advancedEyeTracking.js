/**
 * Advanced On-Device Eye Tracking Model
 * 
 * Based on research from:
 * - Mobile eye tracking devices and techniques
 * - MAC-Gaze: Motion-Aware Continual Calibration
 * - Open Gaze: Deep learning eye tracking for smartphones
 * - Eye tracking laboratory best practices
 * 
 * Features:
 * - Real-time gaze estimation using MediaPipe Face Mesh
 * - Head pose compensation for accurate gaze tracking
 * - Iris-based gaze calculation
 * - Motion-aware calibration
 * - Optimized for mobile performance
 */

import { FaceMesh } from '@mediapipe/face_mesh';
import { getCameraPosition, detectDeviceType, detectOrientation } from '../utils/deviceDetection';

// MediaPipe Face Mesh landmark indices
const FACE_LANDMARKS = {
  // Eye regions
  LEFT_EYE_OUTER: [33, 7, 163, 144, 145, 153, 154, 155, 133, 173, 157, 158, 159, 160, 161, 246],
  RIGHT_EYE_OUTER: [362, 382, 381, 380, 374, 373, 390, 249, 263, 466, 388, 387, 386, 385, 384, 398],
  
  // Iris landmarks (MediaPipe provides 5 iris landmarks per eye)
  LEFT_IRIS: [468, 469, 470, 471, 472],
  RIGHT_IRIS: [473, 474, 475, 476, 477],
  
  // Eye corners for reference
  LEFT_EYE_LEFT_CORNER: 33,
  LEFT_EYE_RIGHT_CORNER: 133,
  RIGHT_EYE_LEFT_CORNER: 362,
  RIGHT_EYE_RIGHT_CORNER: 263,
  
  // Face outline for head pose estimation
  FACE_OUTLINE: [10, 151, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 61, 146, 91, 181, 84, 17, 314, 405, 320, 307, 375, 321, 308, 324, 318],
  
  // Nose for head pose reference
  NOSE_TIP: 1,
  NOSE_BRIDGE: 6,
  
  // Mouth corners for emotion detection
  MOUTH_LEFT: 61,
  MOUTH_RIGHT: 291,
  MOUTH_TOP: 13,
  MOUTH_BOTTOM: 14,
};

class AdvancedEyeTracker {
  constructor() {
    this.faceMesh = null;
    this.videoElement = null;
    this.isInitialized = false;
    this.isTracking = false;
    
    // Debug mode
    this.debugMode = true; // Enable by default for debugging
    this.debugStats = {
      framesProcessed: 0,
      framesWithFace: 0,
      framesWithoutFace: 0,
      errors: [],
      lastError: null,
      lastProcessTime: 0,
      avgProcessTime: 0,
    };
    
    // Calibration data
    this.calibration = {
      isCalibrated: false,
      calibrationPoints: [], // Array of {target: {x, y}, gaze: {x, y}, timestamp}
      transformationMatrix: null, // 3x3 transformation matrix for gaze mapping
      headPoseBaseline: null, // Baseline head pose for calibration
    };
    
    // Head pose estimation
    this.headPose = {
      pitch: 0, // Rotation around X-axis (nodding)
      yaw: 0,   // Rotation around Y-axis (turning left/right)
      roll: 0,  // Rotation around Z-axis (tilting)
      translation: { x: 0, y: 0, z: 0 },
    };
    
    // Gaze tracking data
    this.gazeData = {
      current: { x: 0.5, y: 0.5, confidence: 0 },
      history: [], // Last 60 frames (2 seconds at 30fps)
      fixations: [],
      saccades: [],
    };
    
    // Eye metrics
    this.eyeMetrics = {
      leftEyeOpenness: 1.0,
      rightEyeOpenness: 1.0,
      blinkCount: 0,
      lastBlinkTime: 0,
      eyeAspectRatioHistory: [],
    };
    
    // Performance optimization
    this.frameSkip = 0; // Skip frames for performance
    this.targetFPS = 30;
    this.lastFrameTime = 0;
    this.frameInterval = 1000 / this.targetFPS;
    
    // Callbacks
    this.callbacks = {
      onGaze: null,
      onBlink: null,
      onFixation: null,
      onSaccade: null,
      onHeadPose: null,
    };
    
    // Smoothing filters
    this.gazeSmoothingFactor = 0.7; // Exponential moving average
    this.headPoseSmoothingFactor = 0.8;
    
    // Screen dimensions for coordinate conversion
    // Full screen (left, right, top, bottom) excluding header
    this.screenDimensions = null;
    
    // Device and camera information
    this.deviceInfo = null;
    this.cameraInfo = null;
    // Initialize asynchronously (won't block constructor)
    this.initializeDeviceInfo().catch(err => {
      console.warn('[AdvancedEyeTracker] Device info initialization failed:', err);
    });
    
    // Debug logging helper
    this.log = (level, message, data = null) => {
      if (!this.debugMode && level !== 'error') return;
      
      const prefix = `[AdvancedEyeTracker]`;
      const timestamp = new Date().toISOString().split('T')[1].slice(0, -1);
      
      switch (level) {
        case 'error':
          console.error(`${prefix} [ERROR] ${message}`, data || '');
          this.debugStats.errors.push({ message, data, timestamp });
          this.debugStats.lastError = { message, data, timestamp };
          break;
        case 'warn':
          console.warn(`${prefix} [WARN] ${message}`, data || '');
          break;
        case 'info':
          console.log(`${prefix} [INFO] ${message}`, data || '');
          break;
        case 'debug':
          console.log(`${prefix} [DEBUG] ${message}`, data || '');
          break;
      }
    };
  }

  /**
   * Initialize device and camera information
   * Detects device type and camera position for optimal tracking
   * Uses Capacitor Device API when available
   */
  async initializeDeviceInfo() {
    try {
      this.deviceInfo = await detectDeviceType();
      this.cameraInfo = await getCameraPosition();
      
      this.log('info', 'Device information detected', {
        deviceType: this.deviceInfo.type,
        platform: this.deviceInfo.platform || 'web',
        model: this.deviceInfo.model || 'unknown',
        screenSize: `${this.deviceInfo.screenWidth}x${this.deviceInfo.screenHeight}`,
        cameraPosition: this.cameraInfo.position,
        expectedCenterPitch: this.cameraInfo.expectedCenterPitch.toFixed(1) + '°',
        orientation: this.cameraInfo.orientation,
        isNative: this.deviceInfo.isNative || false,
      });
    } catch (error) {
      this.log('error', 'Failed to detect device info', error);
      // Fallback to default values
      this.deviceInfo = { type: 'unknown', isMobile: false, isTablet: false, isDesktop: true, isNative: false };
      this.cameraInfo = {
        position: 'top',
        expectedCenterPitch: -10,
        pitchRange: { min: -15, max: -5 },
      };
    }
  }

  /**
   * Initialize the eye tracker with a video element
   */
  async initialize(videoElement, options = {}) {
    if (this.isInitialized) {
      this.log('warn', 'Already initialized');
      return;
    }

    this.log('info', 'Initializing...', { 
      videoElement: !!videoElement,
      videoReady: videoElement?.readyState,
      videoWidth: videoElement?.videoWidth,
      videoHeight: videoElement?.videoHeight,
    });

    // Validate video element
    if (!videoElement) {
      this.log('error', 'Video element is required');
      throw new Error('Video element is required');
    }

    if (!(videoElement instanceof HTMLVideoElement)) {
      this.log('error', 'Invalid video element type', { type: typeof videoElement });
      throw new Error('Invalid video element type');
    }

    this.videoElement = videoElement;
    
    try {
      // Configure MediaPipe Face Mesh
      this.log('info', 'Creating FaceMesh instance...');
      this.faceMesh = new FaceMesh({
        locateFile: (file) => {
          const url = `https://cdn.jsdelivr.net/npm/@mediapipe/face_mesh/${file}`;
          this.log('debug', 'Loading MediaPipe file', { file, url });
          return url;
        },
      });

      this.log('info', 'Setting FaceMesh options...');
      this.faceMesh.setOptions({
        maxNumFaces: 1,
        refineLandmarks: true, // Enable iris landmarks
        minDetectionConfidence: 0.5,
        minTrackingConfidence: 0.5,
      });

      // Process results
      this.faceMesh.onResults((results) => {
        this.processFrame(results);
      });

      this.isInitialized = true;
      this.log('info', 'Initialized successfully', {
        faceMesh: !!this.faceMesh,
        videoElement: !!this.videoElement,
      });
    } catch (error) {
      this.log('error', 'Initialization failed', error);
      this.isInitialized = false;
      throw error;
    }
  }

  /**
   * Start tracking
   */
  start() {
    if (!this.isInitialized) {
      this.log('error', 'Not initialized. Call initialize() first.');
      return;
    }

    if (this.isTracking) {
      this.log('warn', 'Already tracking');
      return;
    }

    // Validate video element state
    if (!this.videoElement) {
      this.log('error', 'Video element is null');
      return;
    }

    if (this.videoElement.readyState < 2) {
      this.log('warn', 'Video element not ready', { readyState: this.videoElement.readyState });
    }

    this.isTracking = true;
    this.lastFrameTime = performance.now();
    this.debugStats.framesProcessed = 0;
    this.debugStats.framesWithFace = 0;
    this.debugStats.framesWithoutFace = 0;
    
    // Start processing frames
    this.processVideoFrame();
    
    this.log('info', 'Started tracking', {
      videoWidth: this.videoElement.videoWidth,
      videoHeight: this.videoElement.videoHeight,
      targetFPS: this.targetFPS,
    });
  }

  /**
   * Stop tracking
   */
  stop() {
    this.isTracking = false;
    console.log('[AdvancedEyeTracker] Stopped tracking');
  }

  /**
   * Process video frames
   */
  async processVideoFrame() {
    if (!this.isTracking || !this.videoElement) {
      if (!this.isTracking) {
        this.log('debug', 'Tracking stopped, exiting frame loop');
      }
      if (!this.videoElement) {
        this.log('error', 'Video element is null in processVideoFrame');
      }
      return;
    }

    const now = performance.now();
    const elapsed = now - this.lastFrameTime;

    // Frame rate limiting
    if (elapsed >= this.frameInterval) {
      const processStart = performance.now();
      try {
        // Check video element state
        if (this.videoElement.readyState < 2) {
          this.log('debug', 'Video not ready, skipping frame', { readyState: this.videoElement.readyState });
        } else {
          await this.faceMesh.send({ image: this.videoElement });
          this.lastFrameTime = now;
          
          const processTime = performance.now() - processStart;
          this.debugStats.lastProcessTime = processTime;
          this.debugStats.avgProcessTime = (this.debugStats.avgProcessTime * 0.9) + (processTime * 0.1);
          
          // Log every 30 frames (1 second at 30fps)
          if (this.debugStats.framesProcessed % 30 === 0) {
            this.log('debug', 'Frame processing stats', {
              framesProcessed: this.debugStats.framesProcessed,
              framesWithFace: this.debugStats.framesWithFace,
              framesWithoutFace: this.debugStats.framesWithoutFace,
              faceDetectionRate: ((this.debugStats.framesWithFace / this.debugStats.framesProcessed) * 100).toFixed(1) + '%',
              avgProcessTime: this.debugStats.avgProcessTime.toFixed(2) + 'ms',
              currentFPS: (1000 / elapsed).toFixed(1),
            });
          }
        }
      } catch (error) {
        this.log('error', 'Error processing frame', error);
        // Don't stop tracking on single frame error
      }
    }

    // Continue processing
    if (this.isTracking) {
      requestAnimationFrame(() => this.processVideoFrame());
    }
  }

  /**
   * Process MediaPipe results
   */
  processFrame(results) {
    this.debugStats.framesProcessed++;
    
    if (!results || !results.multiFaceLandmarks || results.multiFaceLandmarks.length === 0) {
      this.debugStats.framesWithoutFace++;
      this.handleNoFace();
      
      // Log every 30 frames without face
      if (this.debugStats.framesWithoutFace % 30 === 0) {
        this.log('warn', 'No face detected', {
          consecutiveFrames: this.debugStats.framesWithoutFace,
          totalFrames: this.debugStats.framesProcessed,
        });
      }
      return;
    }

    this.debugStats.framesWithFace++;
    const landmarks = results.multiFaceLandmarks[0];

    // Validate landmarks
    if (!landmarks || landmarks.length < 468) {
      this.log('warn', 'Invalid landmarks', { 
        count: landmarks?.length,
        expected: 468,
      });
      return;
    }

    try {
      // 1. Estimate head pose
      this.estimateHeadPose(landmarks);

      // 2. Calculate eye openness (for blink detection)
      this.updateEyeOpenness(landmarks);

      // 3. Detect blinks
      const blinkDetected = this.detectBlink();

      // 4. Calculate gaze direction
      const gaze = this.calculateGaze(landmarks);

      // 5. Update gaze history and detect fixations/saccades
      this.updateGazeTracking(gaze);

      // 6. Trigger callbacks
      this.triggerCallbacks(gaze, blinkDetected);

      // Debug logging every 60 frames (2 seconds at 30fps)
      if (this.debugMode && this.debugStats.framesProcessed % 60 === 0) {
        this.log('debug', 'Gaze tracking status', {
          gaze: { x: gaze.x.toFixed(3), y: gaze.y.toFixed(3), confidence: gaze.confidence.toFixed(2) },
          headPose: {
            yaw: this.headPose.yaw.toFixed(1),
            pitch: this.headPose.pitch.toFixed(1),
            roll: this.headPose.roll.toFixed(1),
          },
          eyeOpenness: {
            left: this.eyeMetrics.leftEyeOpenness.toFixed(3),
            right: this.eyeMetrics.rightEyeOpenness.toFixed(3),
          },
          blinkCount: this.eyeMetrics.blinkCount,
          fixations: this.gazeData.fixations.length,
          saccades: this.gazeData.saccades.length,
        });
      }
    } catch (error) {
      this.log('error', 'Error in processFrame', error);
    }
  }

  /**
   * Estimate head pose using facial landmarks
   * Based on PnP (Perspective-n-Point) algorithm
   * Accounts for device-specific camera positions (mobile, tablet, laptop)
   */
  estimateHeadPose(landmarks) {
    // Key facial points for head pose estimation
    const noseTip = landmarks[FACE_LANDMARKS.NOSE_TIP];
    const noseBridge = landmarks[FACE_LANDMARKS.NOSE_BRIDGE];
    const leftEyeCorner = landmarks[FACE_LANDMARKS.LEFT_EYE_LEFT_CORNER];
    const rightEyeCorner = landmarks[FACE_LANDMARKS.RIGHT_EYE_RIGHT_CORNER];
    const mouthLeft = landmarks[FACE_LANDMARKS.MOUTH_LEFT];
    const mouthRight = landmarks[FACE_LANDMARKS.MOUTH_RIGHT];

    // Calculate face center
    const faceCenter = {
      x: (leftEyeCorner.x + rightEyeCorner.x) / 2,
      y: (noseTip.y + (leftEyeCorner.y + rightEyeCorner.y) / 2) / 2,
      z: (noseTip.z || 0),
    };

    // Calculate yaw (left-right rotation)
    const eyeDistance = Math.abs(rightEyeCorner.x - leftEyeCorner.x);
    const faceWidth = Math.abs(mouthRight.x - mouthLeft.x);
    const yaw = Math.atan2(
      (rightEyeCorner.x + leftEyeCorner.x) / 2 - 0.5,
      eyeDistance
    ) * (180 / Math.PI);

    // Calculate pitch (up-down rotation)
    const noseLength = Math.sqrt(
      Math.pow(noseTip.x - noseBridge.x, 2) +
      Math.pow(noseTip.y - noseBridge.y, 2)
    );
    let pitch = Math.atan2(
      noseTip.y - noseBridge.y,
      noseLength
    ) * (180 / Math.PI);

    // Device-aware pitch adjustment
    // Cameras are at the top of devices, so users naturally look down
    // Adjust pitch to account for expected viewing angle
    if (this.cameraInfo && this.cameraInfo.expectedCenterPitch) {
      // Normalize pitch relative to expected center pitch
      // This accounts for the natural downward viewing angle
      const expectedPitch = this.cameraInfo.expectedCenterPitch;
      // If pitch is close to expected, it means user is looking at screen center
      // We adjust to make this the "neutral" position (0°)
      pitch = pitch - expectedPitch;
    }

    // Calculate roll (tilt rotation)
    const eyeLineAngle = Math.atan2(
      rightEyeCorner.y - leftEyeCorner.y,
      rightEyeCorner.x - leftEyeCorner.x
    ) * (180 / Math.PI);
    const roll = eyeLineAngle;

    // Apply smoothing
    this.headPose.yaw = this.headPose.yaw * this.headPoseSmoothingFactor + 
                       yaw * (1 - this.headPoseSmoothingFactor);
    this.headPose.pitch = this.headPose.pitch * this.headPoseSmoothingFactor + 
                         pitch * (1 - this.headPoseSmoothingFactor);
    this.headPose.roll = this.headPose.roll * this.headPoseSmoothingFactor + 
                        roll * (1 - this.headPoseSmoothingFactor);
    this.headPose.translation = faceCenter;

    // Trigger callback
    if (this.callbacks.onHeadPose) {
      this.callbacks.onHeadPose({ ...this.headPose });
    }
  }

  /**
   * Calculate eye openness (Eye Aspect Ratio)
   */
  updateEyeOpenness(landmarks) {
    const leftEAR = this.calculateEAR(landmarks, FACE_LANDMARKS.LEFT_EYE_OUTER);
    const rightEAR = this.calculateEAR(landmarks, FACE_LANDMARKS.RIGHT_EYE_OUTER);

    this.eyeMetrics.leftEyeOpenness = leftEAR;
    this.eyeMetrics.rightEyeOpenness = rightEAR;
    this.eyeMetrics.eyeAspectRatioHistory.push((leftEAR + rightEAR) / 2);

    // Keep last 10 frames
    if (this.eyeMetrics.eyeAspectRatioHistory.length > 10) {
      this.eyeMetrics.eyeAspectRatioHistory.shift();
    }
  }

  /**
   * Calculate Eye Aspect Ratio (EAR)
   * EAR = (vertical distance) / (horizontal distance)
   */
  calculateEAR(landmarks, eyeIndices) {
    // Vertical distances
    const vertical1 = this.euclideanDistance(
      landmarks[eyeIndices[1]],
      landmarks[eyeIndices[7]]
    );
    const vertical2 = this.euclideanDistance(
      landmarks[eyeIndices[2]],
      landmarks[eyeIndices[6]]
    );
    const vertical3 = this.euclideanDistance(
      landmarks[eyeIndices[3]],
      landmarks[eyeIndices[5]]
    );

    // Horizontal distance
    const horizontal = this.euclideanDistance(
      landmarks[eyeIndices[0]],
      landmarks[eyeIndices[4]]
    );

    // Average vertical / horizontal
    const ear = (vertical1 + vertical2 + vertical3) / (3 * horizontal);
    return ear;
  }

  /**
   * Euclidean distance between two points
   */
  euclideanDistance(p1, p2) {
    return Math.sqrt(
      Math.pow(p1.x - p2.x, 2) +
      Math.pow(p1.y - p2.y, 2) +
      Math.pow((p1.z || 0) - (p2.z || 0), 2)
    );
  }

  /**
   * Detect blinks using Eye Aspect Ratio
   */
  detectBlink() {
    const avgEAR = (this.eyeMetrics.leftEyeOpenness + this.eyeMetrics.rightEyeOpenness) / 2;
    const blinkThreshold = 0.25; // Threshold for blink detection
    const now = Date.now();

    // Blink detected if EAR drops below threshold
    if (avgEAR < blinkThreshold && now - this.eyeMetrics.lastBlinkTime > 200) {
      this.eyeMetrics.blinkCount++;
      this.eyeMetrics.lastBlinkTime = now;
      return true;
    }

    return false;
  }

  /**
   * Calculate gaze direction from iris position
   * This is the core gaze estimation algorithm
   */
  calculateGaze(landmarks) {
    try {
      // Validate iris landmarks exist (MediaPipe with refineLandmarks: true)
      const leftIrisIndices = FACE_LANDMARKS.LEFT_IRIS;
      const rightIrisIndices = FACE_LANDMARKS.RIGHT_IRIS;
      
      // Check if iris landmarks are available (indices 468-477)
      const hasLeftIris = leftIrisIndices.every(idx => landmarks[idx] !== undefined);
      const hasRightIris = rightIrisIndices.every(idx => landmarks[idx] !== undefined);
      
      if (!hasLeftIris || !hasRightIris) {
        this.log('warn', 'Iris landmarks not available', {
          hasLeftIris,
          hasRightIris,
          landmarkCount: landmarks.length,
        });
        // Fallback to eye center if iris not available
        return this.calculateGazeFallback(landmarks);
      }

      // Get iris centers
      const leftIrisCenter = this.getLandmarkCenter(landmarks, FACE_LANDMARKS.LEFT_IRIS);
      const rightIrisCenter = this.getLandmarkCenter(landmarks, FACE_LANDMARKS.RIGHT_IRIS);

      // Validate iris centers
      if (!leftIrisCenter || !rightIrisCenter || 
          isNaN(leftIrisCenter.x) || isNaN(rightIrisCenter.x)) {
        this.log('warn', 'Invalid iris centers', { leftIrisCenter, rightIrisCenter });
        return this.calculateGazeFallback(landmarks);
      }

      // Get eye corners for normalization
      const leftEyeLeft = landmarks[FACE_LANDMARKS.LEFT_EYE_LEFT_CORNER];
      const leftEyeRight = landmarks[FACE_LANDMARKS.LEFT_EYE_RIGHT_CORNER];
      const rightEyeLeft = landmarks[FACE_LANDMARKS.RIGHT_EYE_LEFT_CORNER];
      const rightEyeRight = landmarks[FACE_LANDMARKS.RIGHT_EYE_RIGHT_CORNER];

      // Validate eye corners
      if (!leftEyeLeft || !leftEyeRight || !rightEyeLeft || !rightEyeRight) {
        this.log('warn', 'Eye corners not available');
        return { x: 0.5, y: 0.5, confidence: 0.1, timestamp: Date.now() };
      }

    // Calculate iris position relative to eye corners (normalized 0-1)
    const leftGazeX = this.normalize(
      leftIrisCenter.x,
      leftEyeLeft.x,
      leftEyeRight.x
    );
    const leftGazeY = this.normalize(
      leftIrisCenter.y,
      Math.min(leftEyeLeft.y, leftEyeRight.y),
      Math.max(leftEyeLeft.y, leftEyeRight.y)
    );

    const rightGazeX = this.normalize(
      rightIrisCenter.x,
      rightEyeLeft.x,
      rightEyeRight.x
    );
    const rightGazeY = this.normalize(
      rightIrisCenter.y,
      Math.min(rightEyeLeft.y, rightEyeRight.y),
      Math.max(rightEyeLeft.y, rightEyeRight.y)
    );

    // Average both eyes
    let gazeX = (leftGazeX + rightGazeX) / 2;
    let gazeY = (leftGazeY + rightGazeY) / 2;

    // Compensate for head pose
    const compensatedGaze = this.compensateHeadPose(gazeX, gazeY);

    // Apply calibration transformation if calibrated
    let finalGaze = compensatedGaze;
    // Check for calibration engine (polynomial) or transformation matrix (linear)
    if (this.calibration.isCalibrated && (this.calibrationEngine || this.calibration.transformationMatrix)) {
      finalGaze = this.applyCalibration(compensatedGaze);
    }

      // Calculate confidence based on eye visibility and head pose
      const confidence = this.calculateConfidence(landmarks);

      const gaze = {
        x: Math.max(0, Math.min(1, finalGaze.x)),
        y: Math.max(0, Math.min(1, finalGaze.y)),
        confidence,
        timestamp: Date.now(),
        raw: {
          leftIris: leftIrisCenter,
          rightIris: rightIrisCenter,
          headPose: { ...this.headPose },
        },
      };

      return gaze;
    } catch (error) {
      this.log('error', 'Error calculating gaze', error);
      return { x: 0.5, y: 0.5, confidence: 0, timestamp: Date.now() };
    }
  }

  /**
   * Fallback gaze calculation when iris landmarks are not available
   */
  calculateGazeFallback(landmarks) {
    try {
      // Use eye center instead of iris
      const leftEyeCenter = this.getLandmarkCenter(landmarks, FACE_LANDMARKS.LEFT_EYE_OUTER);
      const rightEyeCenter = this.getLandmarkCenter(landmarks, FACE_LANDMARKS.RIGHT_EYE_OUTER);
      
      const leftEyeLeft = landmarks[FACE_LANDMARKS.LEFT_EYE_LEFT_CORNER];
      const leftEyeRight = landmarks[FACE_LANDMARKS.LEFT_EYE_RIGHT_CORNER];
      const rightEyeLeft = landmarks[FACE_LANDMARKS.RIGHT_EYE_LEFT_CORNER];
      const rightEyeRight = landmarks[FACE_LANDMARKS.RIGHT_EYE_RIGHT_CORNER];

      if (!leftEyeCenter || !rightEyeCenter || !leftEyeLeft || !leftEyeRight || 
          !rightEyeLeft || !rightEyeRight) {
        return { x: 0.5, y: 0.5, confidence: 0.1, timestamp: Date.now() };
      }

      const leftGazeX = this.normalize(leftEyeCenter.x, leftEyeLeft.x, leftEyeRight.x);
      const rightGazeX = this.normalize(rightEyeCenter.x, rightEyeLeft.x, rightEyeRight.x);
      const gazeX = (leftGazeX + rightGazeX) / 2;
      const gazeY = (leftEyeCenter.y + rightEyeCenter.y) / 2;

      const compensatedGaze = this.compensateHeadPose(gazeX, gazeY);
      
      return {
        x: Math.max(0, Math.min(1, compensatedGaze.x)),
        y: Math.max(0, Math.min(1, compensatedGaze.y)),
        confidence: 0.5, // Lower confidence for fallback
        timestamp: Date.now(),
      };
    } catch (error) {
      this.log('error', 'Error in fallback gaze calculation', error);
      return { x: 0.5, y: 0.5, confidence: 0, timestamp: Date.now() };
    }
  }

  /**
   * Normalize value to 0-1 range
   */
  normalize(value, min, max) {
    if (max === min) return 0.5;
    return (value - min) / (max - min);
  }

  /**
   * Get center point of landmarks
   */
  getLandmarkCenter(landmarks, indices) {
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

  /**
   * Compensate gaze for head pose rotation
   * This is critical for accurate gaze tracking when user moves head
   * Device-aware compensation based on camera position
   */
  compensateHeadPose(gazeX, gazeY) {
    // Convert normalized gaze (0-1) to screen coordinates (-1 to 1)
    const screenX = (gazeX - 0.5) * 2;
    const screenY = (gazeY - 0.5) * 2;

    // Device-specific compensation factors
    // Mobile devices: More sensitive to head movement (closer to screen)
    // Desktop devices: Less sensitive (further from screen)
    let yawSensitivity = 0.3; // Default
    let pitchSensitivity = 0.3; // Default
    
    if (this.deviceInfo) {
      if (this.deviceInfo.isMobile) {
        yawSensitivity = 0.35; // More sensitive on mobile
        pitchSensitivity = 0.35;
      } else if (this.deviceInfo.isTablet) {
        yawSensitivity = 0.32;
        pitchSensitivity = 0.32;
      } else {
        yawSensitivity = 0.28; // Less sensitive on desktop
        pitchSensitivity = 0.28;
      }
    }

    // Compensate for yaw (left-right head rotation)
    // When head turns left, gaze appears to move right (and vice versa)
    const yawCompensation = this.headPose.yaw / 45; // Normalize to reasonable range
    const compensatedX = screenX - yawCompensation * yawSensitivity;

    // Compensate for pitch (up-down head rotation)
    // Device-aware: Account for natural viewing angle
    const pitchCompensation = this.headPose.pitch / 30;
    const compensatedY = screenY - pitchCompensation * pitchSensitivity;

    // Convert back to normalized coordinates (0-1)
    return {
      x: (compensatedX / 2) + 0.5,
      y: (compensatedY / 2) + 0.5,
    };
  }

  /**
   * Apply calibration transformation
   */
  applyCalibration(gaze) {
    if (!this.calibration.isCalibrated) return gaze;

    // Use calibration engine if available (polynomial)
    if (this.calibrationEngine) {
      return this.calibrationEngine.applyTransformation(gaze);
    }

    // Fallback to simple linear transformation
    if (this.calibration.transformationMatrix) {
      const matrix = this.calibration.transformationMatrix;
      return {
        x: matrix[0] * gaze.x + matrix[1] * gaze.y + matrix[2],
        y: matrix[3] * gaze.x + matrix[4] * gaze.y + matrix[5],
      };
    }

    return gaze;
  }

  /**
   * Calculate gaze confidence
   */
  calculateConfidence(landmarks) {
    let confidence = 1.0;

    // Reduce confidence if eyes are closed
    const avgEAR = (this.eyeMetrics.leftEyeOpenness + this.eyeMetrics.rightEyeOpenness) / 2;
    if (avgEAR < 0.3) {
      confidence *= 0.3;
    }

    // Reduce confidence if head is turned too much
    // Device-aware thresholds: Mobile devices allow more head movement
    let yawThreshold = 30; // Default
    let pitchThreshold = 30; // Default
    
    if (this.deviceInfo) {
      if (this.deviceInfo.isMobile) {
        yawThreshold = 35; // More tolerance on mobile
        pitchThreshold = 35;
      } else if (this.deviceInfo.isTablet) {
        yawThreshold = 32;
        pitchThreshold = 32;
      } else {
        yawThreshold = 25; // Less tolerance on desktop (more precise)
        pitchThreshold = 25;
      }
    }
    
    if (Math.abs(this.headPose.yaw) > yawThreshold) {
      confidence *= 0.5;
    }
    if (Math.abs(this.headPose.pitch) > pitchThreshold) {
      confidence *= 0.5;
    }

    // Reduce confidence if eyes are not well detected
    const leftIris = this.getLandmarkCenter(landmarks, FACE_LANDMARKS.LEFT_IRIS);
    const rightIris = this.getLandmarkCenter(landmarks, FACE_LANDMARKS.RIGHT_IRIS);
    const irisDistance = this.euclideanDistance(leftIris, rightIris);
    if (irisDistance < 0.1 || irisDistance > 0.5) {
      confidence *= 0.7;
    }

    return Math.max(0, Math.min(1, confidence));
  }

  /**
   * Update gaze tracking history and detect fixations/saccades
   */
  updateGazeTracking(gaze) {
    // Apply smoothing
    if (this.gazeData.history.length > 0) {
      const lastGaze = this.gazeData.history[this.gazeData.history.length - 1];
      gaze.x = gaze.x * (1 - this.gazeSmoothingFactor) + lastGaze.x * this.gazeSmoothingFactor;
      gaze.y = gaze.y * (1 - this.gazeSmoothingFactor) + lastGaze.y * this.gazeSmoothingFactor;
    }

    this.gazeData.current = gaze;
    this.gazeData.history.push(gaze);

    // Keep last 60 frames (2 seconds at 30fps)
    if (this.gazeData.history.length > 60) {
      this.gazeData.history.shift();
    }

    // Detect fixations (gaze staying in one area)
    this.detectFixation(gaze);

    // Detect saccades (rapid eye movements)
    if (this.gazeData.history.length > 1) {
      this.detectSaccade(gaze);
    }
  }

  /**
   * Detect fixations (gaze staying in one area for >80ms)
   * More lenient thresholds for mobile eye tracking
   */
  detectFixation(gaze) {
    const FIXATION_THRESHOLD = 0.08; // 8% of screen (more lenient for mobile)
    const FIXATION_DURATION = 80; // milliseconds (reduced for better detection)

    // Need at least 2 gaze points to detect fixation
    if (this.gazeData.history.length < 2) return;

    // Check if gaze has been stable
    const recentGazes = this.gazeData.history.slice(-10);
    // Safety check: prevent division by zero
    if (recentGazes.length === 0) return;
    const avgX = recentGazes.reduce((sum, g) => sum + g.x, 0) / recentGazes.length;
    const avgY = recentGazes.reduce((sum, g) => sum + g.y, 0) / recentGazes.length;

    const variance = recentGazes.reduce((sum, g) => {
      return sum + Math.pow(g.x - avgX, 2) + Math.pow(g.y - avgY, 2);
    }, 0) / recentGazes.length;

    if (variance < FIXATION_THRESHOLD * FIXATION_THRESHOLD) {
      const duration = recentGazes.length * (1000 / this.targetFPS);
      if (duration >= FIXATION_DURATION) {
        // Check if this is a new fixation or continuation
        const lastFixation = this.gazeData.fixations[this.gazeData.fixations.length - 1];
        if (!lastFixation || 
            Math.abs(lastFixation.x - avgX) > FIXATION_THRESHOLD ||
            Math.abs(lastFixation.y - avgY) > FIXATION_THRESHOLD) {
          // New fixation
          this.gazeData.fixations.push({
            x: avgX,
            y: avgY,
            duration,
            startTime: gaze.timestamp - duration,
            endTime: gaze.timestamp,
          });

          if (this.callbacks.onFixation) {
            this.callbacks.onFixation({
              x: avgX,
              y: avgY,
              duration,
            });
          }
        } else {
          // Update existing fixation
          lastFixation.duration = duration;
          lastFixation.endTime = gaze.timestamp;
        }
      }
    }
  }

  /**
   * Detect saccades (rapid eye movements)
   */
  detectSaccade(gaze) {
    if (this.gazeData.history.length < 2) return;

    const prevGaze = this.gazeData.history[this.gazeData.history.length - 2];
    const distance = Math.sqrt(
      Math.pow(gaze.x - prevGaze.x, 2) + Math.pow(gaze.y - prevGaze.y, 2)
    );
    const timeDelta = gaze.timestamp - prevGaze.timestamp;
    const speed = distance / (timeDelta / 1000); // normalized units per second

    const SACCADE_THRESHOLD = 0.1; // 10% of screen per second
    if (speed > SACCADE_THRESHOLD && distance > 0.05) {
      this.gazeData.saccades.push({
        from: { x: prevGaze.x, y: prevGaze.y },
        to: { x: gaze.x, y: gaze.y },
        distance,
        speed,
        timestamp: gaze.timestamp,
      });

      if (this.callbacks.onSaccade) {
        this.callbacks.onSaccade({
          from: { x: prevGaze.x, y: prevGaze.y },
          to: { x: gaze.x, y: gaze.y },
          distance,
          speed,
        });
      }
    }
  }

  /**
   * Calibrate the eye tracker using calibration points
   * Uses advanced calibration engine with polynomial regression
   */
  async calibrate(calibrationData) {
    // calibrationData: Array of {target: {x, y}, gaze: {x, y}} or {target: {x, y}, samples: Array}
    if (!calibrationData || calibrationData.length < 3) {
      this.log('error', 'Need at least 3 calibration points', { count: calibrationData?.length || 0 });
      return false;
    }

    try {
      // Import calibration engine dynamically
      const { CalibrationEngine } = await import('./calibrationEngine');
      const engine = new CalibrationEngine();

      // Add all calibration points
      calibrationData.forEach(point => {
        engine.addCalibrationPoint(point);
      });

      // Calibrate (with outlier removal)
      const success = engine.calibrate(true);
      
      if (!success) {
        this.log('error', 'Calibration failed');
        return false;
      }

      // Get result
      const result = engine.getResult();
      
      // Store calibration
      this.calibration.calibrationPoints = calibrationData;
      this.calibration.transformationModel = result.model;
      this.calibration.quality = result.quality;
      this.calibration.isCalibrated = true;

      // Store engine for transformation and quality access
      this.calibrationEngine = engine;
      
      // Also store quality in calibration object for easy access
      this.calibration.quality = result.quality;

      this.log('info', 'Calibration complete', {
        points: result.points,
        model: result.model.type,
        quality: result.quality,
      });

      return true;
    } catch (error) {
      this.log('error', 'Calibration error', error);
      // Fallback to simple linear calibration
      return this.calibrateSimple(calibrationData);
    }
  }

  /**
   * Simple linear calibration (fallback)
   */
  calibrateSimple(calibrationData) {
    // Extract gaze values (handle both formats)
    const points = calibrationData.map(point => {
      if (point.samples && point.samples.length > 0) {
        return {
          target: point.target,
          gaze: {
            x: point.samples.reduce((sum, s) => sum + s.normalizedX, 0) / point.samples.length,
            y: point.samples.reduce((sum, s) => sum + s.normalizedY, 0) / point.samples.length,
          },
        };
      }
      return { target: point.target, gaze: point.gaze };
    });

    // Build matrices for least squares
    let A = [];
    let b = [];

    points.forEach(({ target, gaze }) => {
      A.push([gaze.x, gaze.y, 1, 0, 0, 0]);
      A.push([0, 0, 0, gaze.x, gaze.y, 1]);
      b.push(target.x);
      b.push(target.y);
    });

    // Solve using normal equations
    const matrix = this.solveLeastSquares(A, b);

    this.calibration.transformationMatrix = matrix;
    this.calibration.isCalibrated = true;

    this.log('info', 'Simple calibration complete', {
      points: points.length,
    });

    return true;
  }

  /**
   * Solve least squares problem (simplified)
   */
  solveLeastSquares(A, b) {
    // For simplicity, we'll use a basic approach
    // In production, use a proper matrix library or numerical method
    
    // Simple linear regression for each dimension
    const n = A.length / 2;
    let sumX = 0, sumY = 0, sumX2 = 0, sumY2 = 0, sumXY = 0;
    let sumTargetX = 0, sumTargetY = 0, sumXTargetX = 0, sumYTargetX = 0;
    let sumXTargetY = 0, sumYTargetY = 0;

    for (let i = 0; i < n; i++) {
      const gaze = { x: A[i * 2][0], y: A[i * 2][1] };
      const targetX = b[i * 2];
      const targetY = b[i * 2 + 1];

      sumX += gaze.x;
      sumY += gaze.y;
      sumX2 += gaze.x * gaze.x;
      sumY2 += gaze.y * gaze.y;
      sumXY += gaze.x * gaze.y;
      sumTargetX += targetX;
      sumTargetY += targetY;
      sumXTargetX += gaze.x * targetX;
      sumYTargetX += gaze.y * targetX;
      sumXTargetY += gaze.x * targetY;
      sumYTargetY += gaze.y * targetY;
    }

    // Solve for transformation matrix
    const denom = (sumX2 * sumY2 - sumXY * sumXY);
    if (Math.abs(denom) < 1e-10) {
      // Fallback to identity
      return [1, 0, 0, 0, 1, 0];
    }

    const m00 = (sumY2 * sumXTargetX - sumXY * sumYTargetX) / denom;
    const m01 = (sumX2 * sumYTargetX - sumXY * sumXTargetX) / denom;
    const m02 = (sumTargetX - m00 * sumX - m01 * sumY) / n;

    const m10 = (sumY2 * sumXTargetY - sumXY * sumYTargetY) / denom;
    const m11 = (sumX2 * sumYTargetY - sumXY * sumXTargetY) / denom;
    const m12 = (sumTargetY - m10 * sumX - m11 * sumY) / n;

    return [m00, m01, m02, m10, m11, m12];
  }

  /**
   * Handle case when no face is detected
   */
  handleNoFace() {
    // Reduce confidence but keep last known gaze
    if (this.gazeData.current) {
      this.gazeData.current.confidence *= 0.9;
    }
  }

  /**
   * Trigger callbacks
   */
  triggerCallbacks(gaze, blinkDetected) {
    if (this.callbacks.onGaze) {
      this.callbacks.onGaze(gaze);
    }

    if (blinkDetected && this.callbacks.onBlink) {
      this.callbacks.onBlink({
        count: this.eyeMetrics.blinkCount,
        timestamp: Date.now(),
      });
    }
  }

  /**
   * Set callback
   */
  setCallback(type, callback) {
    if (this.callbacks.hasOwnProperty(type)) {
      this.callbacks[type] = callback;
    } else {
      console.warn(`[AdvancedEyeTracker] Unknown callback type: ${type}`);
    }
  }

  /**
   * Set screen dimensions (full screen excluding header)
   */
  setScreenDimensions(width, height, headerHeight = 0) {
    this.screenDimensions = { width, height, headerHeight };
    this.log('info', 'Screen dimensions set (full screen minus header)', { width, height, headerHeight });
  }

  /**
   * Get current gaze data
   * Returns gaze in normalized coordinates (0-1) relative to full screen
   * Can be converted to screen coordinates using screenDimensions
   */
  getGaze() {
    const gaze = { ...this.gazeData.current };
    
    // Add screen coordinates if screen dimensions are set
    if (this.screenDimensions && this.screenDimensions.width > 0) {
      gaze.screenX = gaze.x * this.screenDimensions.width;
      gaze.screenY = gaze.y * this.screenDimensions.height;
      gaze.screenDimensions = { ...this.screenDimensions };
      
      // Check if gaze is outside valid area (distracted)
      const headerHeight = this.screenDimensions.headerHeight || 0;
      gaze.isDistracted = gaze.screenY < headerHeight || 
                         gaze.screenX < 0 || 
                         gaze.screenX > this.screenDimensions.width || 
                         gaze.screenY > this.screenDimensions.height;
    }
    
    return gaze;
  }

  /**
   * Get metrics
   */
  getMetrics() {
    return {
      gaze: this.gazeData.current,
      headPose: { ...this.headPose },
      eyeMetrics: {
        leftEyeOpenness: this.eyeMetrics.leftEyeOpenness,
        rightEyeOpenness: this.eyeMetrics.rightEyeOpenness,
        blinkCount: this.eyeMetrics.blinkCount,
      },
      fixations: this.gazeData.fixations.length,
      saccades: this.gazeData.saccades.length,
      isCalibrated: this.calibration.isCalibrated,
      calibration: {
        isCalibrated: this.calibration.isCalibrated,
        quality: this.calibration.quality,
        pointsCount: this.calibration.calibrationPoints?.length || 0,
      },
    };
  }

  /**
   * Get session data for storage
   * Returns comprehensive eye tracking data including fixations and saccades
   */
  getSessionData() {
    return {
      fixations: this.gazeData.fixations.map(f => ({
        x: f.x,
        y: f.y,
        duration: f.duration,
        startTime: f.startTime,
        endTime: f.endTime,
        // Convert normalized coordinates to screen coordinates if screen dimensions are set
        screenX: this.screenDimensions ? f.x * this.screenDimensions.width : null,
        screenY: this.screenDimensions ? f.y * this.screenDimensions.height : null,
      })),
      saccades: this.gazeData.saccades.map(s => ({
        from: { x: s.from.x, y: s.from.y },
        to: { x: s.to.x, y: s.to.y },
        distance: s.distance,
        speed: s.speed,
        timestamp: s.timestamp,
        // Convert normalized coordinates to screen coordinates if screen dimensions are set
        fromScreen: this.screenDimensions ? {
          x: s.from.x * this.screenDimensions.width,
          y: s.from.y * this.screenDimensions.height,
        } : null,
        toScreen: this.screenDimensions ? {
          x: s.to.x * this.screenDimensions.width,
          y: s.to.y * this.screenDimensions.height,
        } : null,
      })),
      calibration: {
        isCalibrated: this.calibration.isCalibrated,
        quality: this.calibration.quality,
        pointsCount: this.calibration.calibrationPoints?.length || 0,
      },
      headPoseHistory: this.headPose, // Current head pose
      eyeMetrics: {
        avgEyeOpenness: (this.eyeMetrics.leftEyeOpenness + this.eyeMetrics.rightEyeOpenness) / 2,
        blinkCount: this.eyeMetrics.blinkCount,
      },
    };
  }

  /**
   * Get debug statistics
   */
  getDebugStats() {
    return {
      ...this.debugStats,
      isInitialized: this.isInitialized,
      isTracking: this.isTracking,
      videoElement: {
        exists: !!this.videoElement,
        readyState: this.videoElement?.readyState,
        videoWidth: this.videoElement?.videoWidth,
        videoHeight: this.videoElement?.videoHeight,
        playing: !this.videoElement?.paused,
      },
      faceMesh: {
        exists: !!this.faceMesh,
      },
      calibration: {
        isCalibrated: this.calibration.isCalibrated,
        pointsCount: this.calibration.calibrationPoints.length,
      },
      performance: {
        targetFPS: this.targetFPS,
        frameInterval: this.frameInterval,
        avgProcessTime: this.debugStats.avgProcessTime,
        lastProcessTime: this.debugStats.lastProcessTime,
      },
    };
  }

  /**
   * Enable/disable debug mode
   */
  setDebugMode(enabled) {
    this.debugMode = enabled;
    this.log('info', `Debug mode ${enabled ? 'enabled' : 'disabled'}`);
  }

  /**
   * Health check - returns true if tracker is working properly
   */
  healthCheck() {
    const issues = [];

    if (!this.isInitialized) {
      issues.push('Not initialized');
    }

    if (!this.videoElement) {
      issues.push('Video element missing');
    } else {
      if (this.videoElement.readyState < 2) {
        issues.push(`Video not ready (readyState: ${this.videoElement.readyState})`);
      }
      if (this.videoElement.videoWidth === 0 || this.videoElement.videoHeight === 0) {
        issues.push('Video dimensions are zero');
      }
    }

    if (!this.faceMesh) {
      issues.push('FaceMesh not created');
    }

    if (this.isTracking) {
      const faceDetectionRate = this.debugStats.framesProcessed > 0
        ? (this.debugStats.framesWithFace / this.debugStats.framesProcessed) * 100
        : 0;
      
      if (faceDetectionRate < 10 && this.debugStats.framesProcessed > 30) {
        issues.push(`Low face detection rate: ${faceDetectionRate.toFixed(1)}%`);
      }

      if (this.debugStats.errors.length > 10) {
        issues.push(`Too many errors: ${this.debugStats.errors.length}`);
      }
    }

    return {
      healthy: issues.length === 0,
      issues,
      stats: this.getDebugStats(),
    };
  }

  /**
   * Reset tracking data
   */
  reset() {
    this.gazeData = {
      current: { x: 0.5, y: 0.5, confidence: 0 },
      history: [],
      fixations: [],
      saccades: [],
    };
    this.eyeMetrics = {
      leftEyeOpenness: 1.0,
      rightEyeOpenness: 1.0,
      blinkCount: 0,
      lastBlinkTime: 0,
      eyeAspectRatioHistory: [],
    };
  }

  /**
   * Cleanup
   */
  destroy() {
    this.stop();
    this.faceMesh = null;
    this.videoElement = null;
    this.isInitialized = false;
  }
}

export default AdvancedEyeTracker;
export const advancedEyeTracker = new AdvancedEyeTracker();

// Expose debug functions to window for easy console access
if (typeof window !== 'undefined') {
  window.debugEyeTracker = {
    getStats: () => advancedEyeTracker.getDebugStats(),
    healthCheck: () => advancedEyeTracker.healthCheck(),
    getMetrics: () => advancedEyeTracker.getMetrics(),
    getGaze: () => advancedEyeTracker.getGaze(),
    setDebugMode: (enabled) => advancedEyeTracker.setDebugMode(enabled),
    log: (message) => console.log('[EyeTracker Debug]', message),
  };
  
  console.log(
    '%c[AdvancedEyeTracker] Debug tools available!',
    'color: #4CAF50; font-weight: bold; font-size: 14px;'
  );
  console.log(
    '%cUse window.debugEyeTracker to access debug functions:',
    'color: #2196F3; font-weight: bold;'
  );
  console.log('  - window.debugEyeTracker.getStats() - Get debug statistics');
  console.log('  - window.debugEyeTracker.healthCheck() - Run health check');
  console.log('  - window.debugEyeTracker.getMetrics() - Get current metrics');
  console.log('  - window.debugEyeTracker.getGaze() - Get current gaze');
  console.log('  - window.debugEyeTracker.setDebugMode(true/false) - Toggle debug mode');
}

