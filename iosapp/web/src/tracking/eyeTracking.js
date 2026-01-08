/**
 * Eye Tracking System for Komal
 * Measures attention, concentration, social gaze, exploration patterns
 * Uses advanced on-device eye tracking model with MediaPipe
 */

import { batteryManager } from '../utils/ml/batteryManager';
import { ThrottledRAF } from '../utils/ml/throttle';
import AdvancedEyeTracker from './advancedEyeTracking';

class EyeTracker {
  constructor() {
    this.isActive = false;
    this.videoElement = null;
    this.canvas = null;
    this.ctx = null;
    this.raf = null;

    // Use advanced eye tracker
    this.advancedTracker = new AdvancedEyeTracker();

    // Tracking data
    this.gazePoints = [];
    this.fixations = [];
    this.saccades = [];
    this.blinkCount = 0;
    this.lastGazePoint = null;
    this.lastFixationTime = 0;

    // ROI (Regions of Interest) - e.g., avatar face
    this.rois = [];
    this.currentROI = null;
    this.lastROI = null;

    // Metrics
    this.metrics = {
      attentionScore: 0,
      concentrationStability: 0,
      socialGazeIndex: 0,
      explorationAvoidanceRatio: 0,
      avgFixationDuration: 0,
      totalFixations: 0,
      avgSaccadeSpeed: 0,
      blinkRate: 0
    };

    this.sessionStartTime = 0;

    // Event callbacks for correlation engine
    this.eventCallbacks = [];

    // Track attention state
    this.lastAttentionScore = 0;
    
    // Track attention score history for averaging at session end
    this.attentionScoreHistory = []; // Array of { score, timestamp }

    // Setup advanced tracker callbacks
    this.setupAdvancedTrackerCallbacks();
  }

  /**
   * Screen dimensions for coordinate conversion
   * Full screen (left, right, top, bottom) excluding header
   */
  screenDimensions = null;

  /**
   * Set screen dimensions (full screen excluding header)
   */
  setScreenDimensions(width, height, headerHeight = 0) {
    this.screenDimensions = { width, height, headerHeight };
    console.log('[EyeTracker] Screen dimensions set (full screen minus header):', { width, height, headerHeight });
  }

  /**
   * Setup callbacks from advanced tracker
   */
  setupAdvancedTrackerCallbacks() {
    let gazeCallbackCount = 0;
    this.advancedTracker.setCallback('onGaze', (gaze) => {
      gazeCallbackCount++;
      
      // DEBUG: Log first few gaze callbacks to verify they're working
      if (gazeCallbackCount <= 5 || gazeCallbackCount % 50 === 0) {
        console.log('[EyeTracker] 👁️ Gaze callback received:', {
          count: gazeCallbackCount,
          gaze: { x: gaze.x.toFixed(3), y: gaze.y.toFixed(3), confidence: gaze.confidence?.toFixed(2) },
          timestamp: gaze.timestamp,
        });
      }
      
      // Convert normalized gaze (0-1) to screen coordinates
      // Full screen: left=0, right=window.innerWidth, top=headerHeight, bottom=window.innerHeight
      const screenX = gaze.x * window.innerWidth;
      const screenY = gaze.y * window.innerHeight;
      
      // Check if gaze is outside valid area (distracted)
      const headerHeight = this.screenDimensions?.headerHeight || 0;
      const isDistracted = screenY < headerHeight || 
                          screenX < 0 || 
                          screenX > window.innerWidth || 
                          screenY > window.innerHeight;

      this.gazePoints.push({
        x: screenX, // Screen X coordinate (0 to window.innerWidth)
        y: screenY, // Screen Y coordinate (0 to window.innerHeight)
        normalizedX: gaze.x, // Normalized 0-1 (relative to full screen)
        normalizedY: gaze.y,
        confidence: gaze.confidence,
        timestamp: gaze.timestamp,
        isDistracted, // Flag for distraction detection
        screenDimensions: this.screenDimensions,
      });

      // Keep last 1000 points
      if (this.gazePoints.length > 1000) {
        this.gazePoints.shift();
      }

      this.lastGazePoint = { x: screenX, y: screenY, timestamp: gaze.timestamp, isDistracted };
      this.processGazePoint(screenX, screenY, gaze.timestamp);
      
      // Emit distraction event if gaze is outside valid area
      if (isDistracted) {
        this.emitEvent('distraction', {
          location: { x: screenX, y: screenY },
          reason: screenY < headerHeight ? 'header' : 'outside_screen',
        });
      }
    });

    this.advancedTracker.setCallback('onBlink', (blinkData) => {
      this.blinkCount = blinkData.count;
    });

    this.advancedTracker.setCallback('onFixation', (fixation) => {
      this.fixations.push({
        x: fixation.x * window.innerWidth,
        y: fixation.y * window.innerHeight,
        duration: fixation.duration,
        timestamp: Date.now()
      });
    });

    this.advancedTracker.setCallback('onSaccade', (saccade) => {
      this.saccades.push({
        fromX: saccade.from.x * window.innerWidth,
        fromY: saccade.from.y * window.innerHeight,
        toX: saccade.to.x * window.innerWidth,
        toY: saccade.to.y * window.innerHeight,
        distance: saccade.distance,
        speed: saccade.speed,
        timestamp: Date.now()
      });
    });
  }

  async init(videoElement) {
    this.videoElement = videoElement;
    this.canvas = document.createElement('canvas');
    this.ctx = this.canvas.getContext('2d');
    this.sessionStartTime = Date.now();

    await batteryManager.init();

    // Initialize advanced tracker
    try {
      await this.advancedTracker.initialize(videoElement);
      console.log('[EyeTracker] Advanced eye tracker initialized');
    } catch (error) {
      console.error('[EyeTracker] Failed to initialize advanced tracker:', error);
    }

    console.log('[EyeTracker] Initialized');
  }

  /**
   * Register callback for events (for correlation engine)
   */
  onEvent(callback) {
    this.eventCallbacks.push(callback);
  }

  /**
   * Emit event to correlation engine
   */
  emitEvent(eventType, data) {
    this.eventCallbacks.forEach(callback => {
      callback('eye', eventType, data);
    });
  }

  /**
   * Start eye tracking
   */
  start() {
    if (this.isActive) {
      console.warn('[EyeTracker] ⚠️ Already started');
      return;
    }

    this.isActive = true;
    this.sessionStartTime = Date.now();
    this.gazePoints = [];
    this.fixations = [];
    this.saccades = [];
    this.blinkCount = 0;
    this.attentionScoreHistory = []; // Reset history for new session
    
    // DEBUG: Log start
    console.log('[EyeTracker] 🚀 Starting eye tracking:', {
      sessionStartTime: this.sessionStartTime,
      screenDimensions: this.screenDimensions,
      videoElement: !!this.videoElement,
      advancedTrackerInitialized: this.advancedTracker.isInitialized,
    });

    // Start advanced tracker
    this.advancedTracker.start();
    
    // DEBUG: Verify advanced tracker is running
    setTimeout(() => {
      console.log('[EyeTracker] 🔍 Advanced tracker status check:', {
        isInitialized: this.advancedTracker.isInitialized,
        isTracking: this.advancedTracker.isTracking,
        gazePointsReceived: this.gazePoints.length,
        videoElement: !!this.videoElement,
        videoReady: this.videoElement?.readyState,
        screenDimensions: this.screenDimensions,
      });
      
      if (this.gazePoints.length === 0) {
        console.warn('[EyeTracker] ⚠️ No gaze points collected after 2 seconds!', {
          possibleIssues: {
            advancedTrackerNotRunning: !this.advancedTracker.isTracking,
            videoNotReady: this.videoElement?.readyState !== 4,
            noVideoElement: !this.videoElement,
            callbacksNotSet: !this.advancedTracker.callbacks?.onGaze,
          },
        });
      }
    }, 2000);

    // Use battery-aware FPS for metrics calculation
    const fps = batteryManager.isCharging ? 10 : 5;
    this.raf = new ThrottledRAF(fps);
    
    console.log(`[EyeTracker] ✅ Started at ${fps} FPS (advanced tracking active)`);
    
    // Log initial state after a short delay
    setTimeout(() => {
      console.log('[EyeTracker] 📊 Initial state check:', {
        isActive: this.isActive,
        gazePointsCount: this.gazePoints.length,
        advancedTrackerTracking: this.advancedTracker.isTracking,
        screenDimensions: this.screenDimensions,
      });
    }, 1000);

    this.raf.start(() => {
      this.processFrame();
    });

    console.log(`[EyeTracker] Started at ${fps} FPS (advanced tracking active)`);
  }

  /**
   * Stop eye tracking
   */
  stop() {
    if (!this.isActive) return;

    // Stop advanced tracker
    this.advancedTracker.stop();

    if (this.raf) {
      this.raf.stop();
      this.raf = null;
    }

    this.isActive = false;
    
    // IMPORTANT: Calculate final metrics BEFORE stopping advanced tracker
    // This ensures we have all the data before it's cleared
    // But actually, we want to stop tracking first, then calculate from history
    // The history should already be populated from during the session
    this.calculateFinalMetrics();

    console.log('[EyeTracker] Stopped');
  }

  /**
   * Process each frame for metrics calculation
   * Gaze estimation is now handled by AdvancedEyeTracker
   */
  processFrame() {
    if (!this.videoElement) {
      // Only log warning occasionally to avoid spam
      if (Math.random() < 0.01) {
        console.warn('[EyeTracker] ⚠️ processFrame called but no video element');
      }
      return;
    }

    const timestamp = Date.now();

    // Get current gaze from advanced tracker
    const gazeData = this.advancedTracker.getGaze();
    
    if (gazeData && gazeData.confidence > 0.3) {
      const screenX = gazeData.x * window.innerWidth;
      const screenY = gazeData.y * window.innerHeight;
      const gazePoint = { x: screenX, y: screenY, timestamp };

      // Check if gazing at ROI (e.g., avatar face)
      this.checkROI(gazePoint);
    }

    // Calculate real-time metrics
    // DEBUG: Log when calculateMetrics is called (occasionally to avoid spam)
    const metricsBefore = this.metrics.attentionScore;
    this.calculateMetrics();
    const metricsAfter = this.metrics.attentionScore;
    
    // Log if attention score changed significantly, is 0, or every 50th call
    const shouldLog = metricsAfter === 0 || 
                     Math.abs(metricsAfter - metricsBefore) > 10 ||
                     (this.processFrameCallCount = (this.processFrameCallCount || 0) + 1) % 50 === 0;
    
    if (shouldLog) {
      console.log('[EyeTracker] 📊 Metrics calculated:', {
        attentionScore: metricsAfter,
        previousScore: metricsBefore,
        gazePointsCount: this.gazePoints.length,
        fixationsCount: this.fixations.length,
        timestamp,
        frameCount: this.processFrameCallCount,
      });
    }
  }

  /**
   * Process gaze point (called from advanced tracker callback)
   */
  processGazePoint(x, y, timestamp) {
    const gazePoint = { x, y, timestamp };

      // Detect fixations (staying in one area)
      this.detectFixation(gazePoint, timestamp);

      // Detect saccades (quick eye movements)
      if (this.lastGazePoint) {
        this.detectSaccade(this.lastGazePoint, gazePoint, timestamp);
      }

      // Check if gazing at ROI (e.g., avatar face)
      this.checkROI(gazePoint);
  }

  /**
   * Detect fixations (gaze staying in one area > 100ms)
   */
  detectFixation(gazePoint, timestamp) {
    if (!this.lastGazePoint) {
      this.lastFixationTime = timestamp;
      return;
    }

    const distance = Math.sqrt(
      Math.pow(gazePoint.x - this.lastGazePoint.x, 2) +
      Math.pow(gazePoint.y - this.lastGazePoint.y, 2)
    );

    const FIXATION_THRESHOLD = 50; // pixels

    if (distance < FIXATION_THRESHOLD) {
      const duration = timestamp - this.lastFixationTime;

      if (duration > 100) {
        // Fixation detected
        this.fixations.push({
          x: gazePoint.x,
          y: gazePoint.y,
          startTime: this.lastFixationTime,
          endTime: timestamp,
          duration
        });
      }
    } else {
      // Gaze moved, reset fixation timer
      this.lastFixationTime = timestamp;
    }
  }

  /**
   * Detect saccades (quick eye movements)
   */
  detectSaccade(prevPoint, currPoint, timestamp) {
    const distance = Math.sqrt(
      Math.pow(currPoint.x - prevPoint.x, 2) +
      Math.pow(currPoint.y - prevPoint.y, 2)
    );

    const timeDelta = timestamp - (this.lastGazePoint.timestamp || timestamp);
    const speed = distance / Math.max(1, timeDelta / 1000); // px/sec

    if (speed > 100) {
      // Saccade detected
      const saccadeData = {
        fromX: prevPoint.x,
        fromY: prevPoint.y,
        toX: currPoint.x,
        toY: currPoint.y,
        distance,
        speed,
        timestamp
      };

      this.saccades.push(saccadeData);

      // Emit event for correlation
      this.emitEvent('saccade', {
        from: { x: prevPoint.x, y: prevPoint.y },
        to: { x: currPoint.x, y: currPoint.y },
        distance,
        speed
      });
    }
  }

  /**
   * Calibrate eye tracker using calibration data
   */
  calibrate(calibrationData) {
    // calibrationData: Array of {target: {x, y}, gaze: {x, y}}
    return this.advancedTracker.calibrate(calibrationData);
  }

  /**
   * Check if gaze is on ROI (e.g., avatar face)
   */
  checkROI(gazePoint) {
    let foundROI = null;

    for (const roi of this.rois) {
      if (
        gazePoint.x >= roi.x &&
        gazePoint.x <= roi.x + roi.width &&
        gazePoint.y >= roi.y &&
        gazePoint.y <= roi.y + roi.height
      ) {
        foundROI = roi;
        break;
      }
    }

    // Detect ROI entry
    if (foundROI && (!this.lastROI || this.lastROI.name !== foundROI.name)) {
      this.emitEvent('roiEnter', {
        roi: foundROI.name,
        location: { x: gazePoint.x, y: gazePoint.y }
      });

      // Special event for social gaze (looking at avatar)
      if (foundROI.name === 'avatar-face' || foundROI.name === 'avatar') {
        this.emitEvent('socialGaze', {
          target: foundROI.name,
          duration: 0 // Will be calculated on exit
        });
      }
    }

    // Detect ROI exit
    if (!foundROI && this.lastROI) {
      this.emitEvent('roiExit', {
        roi: this.lastROI.name
      });

      // Emit aversion event if left important area
      if (this.lastROI.name === 'avatar-face' || this.lastROI.name === 'avatar') {
        this.emitEvent('aversion', {
          type: 'social',
          duration: 0
        });
      }
    }

    this.lastROI = foundROI;
    this.currentROI = foundROI;
  }

  /**
   * Set ROI for tracking (e.g., avatar face position)
   */
  setROI(name, x, y, width, height) {
    this.rois.push({ name, x, y, width, height });
  }

  /**
   * Calculate real-time metrics
   */
  calculateMetrics() {
    const now = Date.now();
    const sessionDuration = (now - this.sessionStartTime) / 1000; // seconds

    // Get advanced tracker fixations (more accurate, calibrated)
    const advancedFixations = this.advancedTracker.gazeData?.fixations || [];
    const allFixations = [...this.fixations, ...advancedFixations.map(f => ({
      x: this.screenDimensions ? f.x * this.screenDimensions.width : f.x * window.innerWidth,
      y: this.screenDimensions ? f.y * this.screenDimensions.height : f.y * window.innerHeight,
      duration: f.duration,
      startTime: f.startTime,
      endTime: f.endTime,
    }))];

    /**
     * Research-Based Attention Score Calculation
     * 
     * Based on eye tracking research (MAC-Gaze, Open Gaze, eye tracking lab best practices):
     * 1. Center-focused attention (40%): Main content is in center, last calibration point is center
     * 2. Calibrated area coverage (30%): Time spent within calibrated screen boundaries
     * 3. Gaze stability (20%): Low variance = focused attention, high variance = distracted
     * 4. Fixation quality (10%): Longer fixations = sustained attention
     * 
     * This multi-factor approach provides more accurate attention measurement for therapy/learning apps
     */
    
    // DEBUG: Log initial state
    console.log('[AttentionScore] 🔍 Starting attention score calculation:', {
      totalGazePoints: this.gazePoints.length,
      totalFixations: allFixations.length,
      screenDimensions: this.screenDimensions,
      sessionDuration: sessionDuration,
      blinkCount: this.blinkCount,
    });
    
    const gazePoints = this.gazePoints.filter(p => p.confidence > 0.3); // Filter low confidence
    
    console.log('[AttentionScore] 📊 After filtering:', {
      filteredGazePoints: gazePoints.length,
      confidenceFiltered: this.gazePoints.length - gazePoints.length,
    });
    
    // Get calibrated screen area dimensions
    const screenWidth = this.screenDimensions?.width || window.innerWidth;
    const screenHeight = this.screenDimensions?.height || window.innerHeight;
    const headerHeight = this.screenDimensions?.headerHeight || 0;
    
    // Safety check: prevent division by zero
    if (screenWidth <= 0 || screenHeight <= headerHeight) {
      console.warn('[AttentionScore] ⚠️ Invalid screen dimensions, using defaults:', {
        screenWidth,
        screenHeight,
        headerHeight,
      });
      // Use fallback dimensions
      const fallbackWidth = window.innerWidth || 1920;
      const fallbackHeight = window.innerHeight || 1080;
      const fallbackHeader = headerHeight || 120;
      
      // Early return with default score if dimensions are invalid
      this.metrics.attentionScore = 50; // Default moderate score
      return;
    }
    
    // DEBUG: Log screen dimensions
    console.log('[AttentionScore] 📐 Screen dimensions:', {
      screenWidth,
      screenHeight,
      headerHeight,
      hasScreenDimensions: !!this.screenDimensions,
      windowSize: { width: window.innerWidth, height: window.innerHeight },
    });
    
    // Calibrated area: full screen excluding header
    const calibratedArea = {
      left: 0,
      right: screenWidth,
      top: headerHeight,
      bottom: screenHeight,
      centerX: screenWidth / 2,
      centerY: headerHeight + (screenHeight - headerHeight) / 2, // Center of calibrated area
    };
    
    console.log('[AttentionScore] 🎯 Calibrated area:', calibratedArea);
    
    // Factor 1: Center-Focused Attention (40% weight)
    // Research: Main content in therapy/learning apps is typically centered
    // Last calibration point (id: 13) is at center (50%, 50%)
    // Higher weight for gaze near center, decreasing with distance
    let centerAttentionScore = 0;
    let centerAttentionTime = 0;
    let totalTrackingTime = 0;
    
    if (gazePoints.length > 0) {
      gazePoints.forEach((point, i) => {
        const timeDelta = i > 0 
          ? Math.max(16, Math.min(100, point.timestamp - gazePoints[i - 1].timestamp))
          : 33;
        
        totalTrackingTime += timeDelta;
        
        // Check if within calibrated area
        const isInArea = 
          point.x >= calibratedArea.left &&
          point.x <= calibratedArea.right &&
          point.y >= calibratedArea.top &&
          point.y <= calibratedArea.bottom &&
          !point.isDistracted;
        
        if (isInArea) {
          // Calculate distance from center (normalized 0-1)
          // Safety check: prevent division by zero
          const halfWidth = screenWidth / 2;
          const halfHeight = (screenHeight - headerHeight) / 2;
          const dx = halfWidth > 0 ? Math.abs(point.x - calibratedArea.centerX) / halfWidth : 0;
          const dy = halfHeight > 0 ? Math.abs(point.y - calibratedArea.centerY) / halfHeight : 0;
          const distanceFromCenter = Math.sqrt(dx * dx + dy * dy);
          
          // Weight function: closer to center = higher score
          // Uses exponential decay: weight = exp(-distance / 0.5)
          // This gives: center (0) = 100%, 25% away = ~60%, 50% away = ~37%, edge = ~14%
          const centerWeight = Math.exp(-distanceFromCenter / 0.5);
          centerAttentionTime += timeDelta * centerWeight;
        }
      });
      
      if (totalTrackingTime > 0) {
        centerAttentionScore = (centerAttentionTime / totalTrackingTime) * 100;
        console.log('[AttentionScore] 🎯 Factor 1 - Center Attention:', {
          centerAttentionTime,
          totalTrackingTime,
          centerAttentionScore: centerAttentionScore.toFixed(2) + '%',
          weight: '40%',
        });
      } else {
        console.warn('[AttentionScore] ⚠️ Factor 1 - No tracking time available for center attention');
      }
    } else {
      console.warn('[AttentionScore] ⚠️ Factor 1 - No gaze points available for center attention');
    }
    
    // Factor 2: Calibrated Area Coverage (30% weight)
    // Research: Time spent within calibrated boundaries indicates screen attention
    let areaCoverageScore = 0;
    let timeInCalibratedArea = 0;
    
    if (gazePoints.length > 0) {
      gazePoints.forEach((point, i) => {
        const timeDelta = i > 0 
          ? Math.max(16, Math.min(100, point.timestamp - gazePoints[i - 1].timestamp))
          : 33;
        
        const isInArea = 
          point.x >= calibratedArea.left &&
          point.x <= calibratedArea.right &&
          point.y >= calibratedArea.top &&
          point.y <= calibratedArea.bottom &&
          !point.isDistracted;
        
        if (isInArea) {
          timeInCalibratedArea += timeDelta;
        }
      });
      
      if (totalTrackingTime > 0) {
        areaCoverageScore = (timeInCalibratedArea / totalTrackingTime) * 100;
        console.log('[AttentionScore] 📍 Factor 2 - Area Coverage:', {
          timeInCalibratedArea,
          totalTrackingTime,
          areaCoverageScore: areaCoverageScore.toFixed(2) + '%',
          weight: '30%',
          pointsInArea: gazePoints.filter(p => 
            p.x >= calibratedArea.left && p.x <= calibratedArea.right &&
            p.y >= calibratedArea.top && p.y <= calibratedArea.bottom &&
            !p.isDistracted
          ).length,
          totalPoints: gazePoints.length,
        });
      } else {
        console.warn('[AttentionScore] ⚠️ Factor 2 - No tracking time available for area coverage');
      }
    } else {
      console.warn('[AttentionScore] ⚠️ Factor 2 - No gaze points available for area coverage');
    }
    
    // Factor 3: Gaze Stability (20% weight)
    // Research: Low variance = focused attention, high variance = distracted/frequent saccades
    // Calculate gaze variance over recent samples (last 30 points or 1 second)
    let stabilityScore = 50; // Default moderate stability
    if (gazePoints.length >= 10) {
      const recentPoints = gazePoints.slice(-30).filter(p => 
        p.x >= calibratedArea.left && p.x <= calibratedArea.right &&
        p.y >= calibratedArea.top && p.y <= calibratedArea.bottom &&
        !p.isDistracted
      );
      
      if (recentPoints.length >= 5) {
        const avgX = recentPoints.reduce((sum, p) => sum + p.x, 0) / recentPoints.length;
        const avgY = recentPoints.reduce((sum, p) => sum + p.y, 0) / recentPoints.length;
        
        const variance = recentPoints.reduce((sum, p) => {
          const dx = p.x - avgX;
          const dy = p.y - avgY;
          return sum + (dx * dx + dy * dy);
        }, 0) / recentPoints.length;
        
        // Normalize variance to screen size (as percentage)
        // Safety check: prevent division by zero
        const screenSizeSquared = (screenWidth * screenWidth + screenHeight * screenHeight) / 2;
        const normalizedVariance = screenSizeSquared > 0 ? variance / screenSizeSquared : 0;
        
        // Stability score: lower variance = higher score
        // Research threshold: variance < 0.01 (1%) = very stable, > 0.05 (5%) = unstable
        // Formula: stability = 100 * (1 - min(variance / 0.05, 1))
        stabilityScore = Math.max(0, Math.min(100, 100 * (1 - Math.min(normalizedVariance / 0.05, 1))));
        console.log('[AttentionScore] 📊 Factor 3 - Gaze Stability:', {
          variance: variance.toFixed(4),
          normalizedVariance: normalizedVariance.toFixed(4),
          stabilityScore: stabilityScore.toFixed(2) + '%',
          weight: '20%',
          recentPointsCount: recentPoints.length,
        });
      } else {
        console.warn('[AttentionScore] ⚠️ Factor 3 - Not enough recent points for stability calculation:', {
          recentPointsCount: recentPoints.length,
          required: 5,
        });
      }
    } else {
      console.warn('[AttentionScore] ⚠️ Factor 3 - Not enough gaze points for stability:', {
        gazePointsCount: gazePoints.length,
        required: 10,
      });
    }
    
    // Factor 4: Fixation Quality (10% weight)
    // Research: Longer fixations indicate sustained attention
    // Average fixation duration: >300ms = good, <150ms = poor
    let fixationQualityScore = 50; // Default moderate
    if (allFixations.length > 0) {
      const fixationDurations = allFixations.map(f => f.duration || 0).filter(d => d > 0);
      if (fixationDurations.length > 0) {
        const avgFixationDuration = fixationDurations.reduce((sum, d) => sum + d, 0) / fixationDurations.length;
        
        // Research-based thresholds: 300ms = optimal, 150ms = minimum
        // Score: duration < 150ms = 0%, 150-300ms = linear, >300ms = 100%
        if (avgFixationDuration >= 300) {
          fixationQualityScore = 100;
        } else if (avgFixationDuration >= 150) {
          fixationQualityScore = ((avgFixationDuration - 150) / 150) * 100;
        } else {
          fixationQualityScore = 0;
        }
        console.log('[AttentionScore] 👁️ Factor 4 - Fixation Quality:', {
          avgFixationDuration: avgFixationDuration.toFixed(2) + 'ms',
          fixationQualityScore: fixationQualityScore.toFixed(2) + '%',
          weight: '10%',
          totalFixations: allFixations.length,
          validFixations: fixationDurations.length,
        });
      } else {
        console.warn('[AttentionScore] ⚠️ Factor 4 - No valid fixation durations');
      }
    } else {
      console.warn('[AttentionScore] ⚠️ Factor 4 - No fixations available');
    }
    
    // Factor 5: Head Pose Stability (10% weight) - NEW
    // Research: Stable head position indicates focused attention
    // Excessive head movement (yaw/pitch > 30°) reduces attention
    // Head position relative to optimal viewing angle affects attention
    let headPoseScore = 50; // Default moderate
    const advancedMetrics = this.advancedTracker.getMetrics();
    const headPose = advancedMetrics?.headPose || this.advancedTracker.headPose;
    
    if (headPose) {
      const yaw = Math.abs(headPose.yaw || 0);
      const pitch = Math.abs(headPose.pitch || 0);
      const roll = Math.abs(headPose.roll || 0);
      
      // Research thresholds for optimal head position:
      // - Yaw/Pitch < 15°: Optimal (100% score)
      // - Yaw/Pitch 15-30°: Acceptable (50-100% score)
      // - Yaw/Pitch > 30°: Poor (0-50% score)
      // - Roll < 10°: Optimal, > 20°: Poor
      
      // Calculate head position score (0-100)
      // Penalize excessive rotation in any axis
      const yawScore = yaw < 15 ? 100 : yaw < 30 ? 100 - ((yaw - 15) / 15) * 50 : Math.max(0, 50 - ((yaw - 30) / 30) * 50);
      const pitchScore = pitch < 15 ? 100 : pitch < 30 ? 100 - ((pitch - 15) / 15) * 50 : Math.max(0, 50 - ((pitch - 30) / 30) * 50);
      const rollScore = roll < 10 ? 100 : roll < 20 ? 100 - ((roll - 10) / 10) * 50 : Math.max(0, 50 - ((roll - 20) / 20) * 50);
      
      // Average head pose scores (weighted: yaw/pitch more important than roll)
      headPoseScore = (yawScore * 0.4 + pitchScore * 0.4 + rollScore * 0.2);
      
      console.log('[AttentionScore] 🎯 Factor 5 - Head Pose Stability:', {
        yaw: yaw.toFixed(1) + '°',
        pitch: pitch.toFixed(1) + '°',
        roll: roll.toFixed(1) + '°',
        yawScore: yawScore.toFixed(1) + '%',
        pitchScore: pitchScore.toFixed(1) + '%',
        rollScore: rollScore.toFixed(1) + '%',
        headPoseScore: headPoseScore.toFixed(1) + '%',
        weight: '10%',
      });
    } else {
      console.warn('[AttentionScore] ⚠️ Factor 5 - Head pose data not available');
    }
    
    // Factor 6: Head Movement Stability (5% weight) - NEW
    // Research: Frequent head movements indicate distraction or discomfort
    // Track head pose variance over recent samples
    let headMovementScore = 50; // Default moderate
    if (headPose && this.advancedTracker.gazeData?.history?.length >= 10) {
      // Get recent head pose samples from gaze history
      const recentGazes = this.advancedTracker.gazeData.history.slice(-30);
      const headPoseSamples = recentGazes
        .filter(g => g.raw?.headPose)
        .map(g => g.raw.headPose);
      
      if (headPoseSamples.length >= 5) {
        // Calculate variance in head pose
        const yawValues = headPoseSamples.map(p => p.yaw || 0);
        const pitchValues = headPoseSamples.map(p => p.pitch || 0);
        
        const avgYaw = yawValues.reduce((sum, y) => sum + y, 0) / yawValues.length;
        const avgPitch = pitchValues.reduce((sum, p) => sum + p, 0) / pitchValues.length;
        
        const yawVariance = yawValues.reduce((sum, y) => sum + Math.pow(y - avgYaw, 2), 0) / yawValues.length;
        const pitchVariance = pitchValues.reduce((sum, p) => sum + Math.pow(p - avgPitch, 2), 0) / pitchValues.length;
        
        const avgVariance = (yawVariance + pitchVariance) / 2;
        
        // Head movement score: lower variance = higher score
        // Variance < 5° = very stable (100%), > 20° = unstable (0%)
        headMovementScore = Math.max(0, Math.min(100, 100 * (1 - Math.min(avgVariance / 20, 1))));
        
        console.log('[AttentionScore] 📊 Factor 6 - Head Movement Stability:', {
          yawVariance: yawVariance.toFixed(2) + '°',
          pitchVariance: pitchVariance.toFixed(2) + '°',
          avgVariance: avgVariance.toFixed(2) + '°',
          headMovementScore: headMovementScore.toFixed(1) + '%',
          weight: '5%',
          samples: headPoseSamples.length,
        });
      } else {
        console.warn('[AttentionScore] ⚠️ Factor 6 - Not enough head pose samples:', {
          samples: headPoseSamples.length,
          required: 5,
        });
      }
    } else {
      console.warn('[AttentionScore] ⚠️ Factor 6 - Not enough gaze history for head movement analysis');
    }
    
    // Combine factors with research-based weights
    // Updated weights: Center attention (35%) + Area coverage (25%) + Stability (15%) + 
    //                  Fixation quality (10%) + Head pose (10%) + Head movement (5%)
    const combinedScore = 
      (centerAttentionScore * 0.35) +
      (areaCoverageScore * 0.25) +
      (stabilityScore * 0.15) +
      (fixationQualityScore * 0.10) +
      (headPoseScore * 0.10) +
      (headMovementScore * 0.05);
    
    console.log('[AttentionScore] 🧮 Combined score calculation:', {
      centerAttention: centerAttentionScore.toFixed(2) + '% × 0.35 = ' + (centerAttentionScore * 0.35).toFixed(2),
      areaCoverage: areaCoverageScore.toFixed(2) + '% × 0.25 = ' + (areaCoverageScore * 0.25).toFixed(2),
      stability: stabilityScore.toFixed(2) + '% × 0.15 = ' + (stabilityScore * 0.15).toFixed(2),
      fixationQuality: fixationQualityScore.toFixed(2) + '% × 0.10 = ' + (fixationQualityScore * 0.10).toFixed(2),
      headPose: headPoseScore.toFixed(2) + '% × 0.10 = ' + (headPoseScore * 0.10).toFixed(2),
      headMovement: headMovementScore.toFixed(2) + '% × 0.05 = ' + (headMovementScore * 0.05).toFixed(2),
      combinedScore: combinedScore.toFixed(2),
    });
    
    // Account for blink rate (penalty for excessive blinking)
    // Research: Normal blink rate ~15-20/min, >30/min = fatigue/distraction
    const blinkRate = this.metrics.blinkRate || 0;
    let blinkPenalty = 0;
    if (blinkRate > 30) {
      // Penalty: reduce score by up to 10% for excessive blinking
      blinkPenalty = Math.min(10, ((blinkRate - 30) / 30) * 10);
      console.log('[AttentionScore] 👁️ Blink penalty:', {
        blinkRate,
        blinkPenalty: blinkPenalty.toFixed(2) + '%',
      });
    }
    
    // Final attention score
    const scoreBeforeMin = Math.max(0, Math.min(100, Math.round(combinedScore - blinkPenalty)));
    this.metrics.attentionScore = scoreBeforeMin;
    
    // Ensure minimum score if user is looking at screen (not completely distracted)
    // If area coverage > 50%, ensure score is at least 30% (user is somewhat attentive)
    if (areaCoverageScore > 50 && this.metrics.attentionScore < 30) {
      console.log('[AttentionScore] ✅ Applying minimum score guarantee:', {
        areaCoverageScore: areaCoverageScore.toFixed(2) + '%',
        scoreBefore: this.metrics.attentionScore,
        scoreAfter: 30,
      });
      this.metrics.attentionScore = 30;
    }
    
    // Track attention score in history for averaging at session end
    // Only track if we have meaningful data (not just default fallbacks)
    if (this.metrics.attentionScore > 0 || gazePoints.length > 0) {
      this.attentionScoreHistory.push({
        score: this.metrics.attentionScore,
        timestamp: Date.now(),
        gazePointsCount: gazePoints.length,
        hasData: gazePoints.length > 0,
      });
      
      // Keep last 1000 scores (to prevent memory issues)
      if (this.attentionScoreHistory.length > 1000) {
        this.attentionScoreHistory.shift();
      }
    }
    
    // Final debug log
    console.log('[AttentionScore] ✅ Final attention score:', {
      score: this.metrics.attentionScore + '%',
      breakdown: {
        centerAttention: centerAttentionScore.toFixed(1) + '%',
        areaCoverage: areaCoverageScore.toFixed(1) + '%',
        stability: stabilityScore.toFixed(1) + '%',
        fixationQuality: fixationQualityScore.toFixed(1) + '%',
        headPose: headPoseScore.toFixed(1) + '%',
        headMovement: headMovementScore.toFixed(1) + '%',
        blinkPenalty: blinkPenalty.toFixed(1) + '%',
      },
      combinedScore: combinedScore.toFixed(1),
      finalScore: this.metrics.attentionScore,
    });
    
    // Warn if score is 0
    if (this.metrics.attentionScore === 0) {
      console.error('[AttentionScore] ❌ ATTENTION SCORE IS 0!', {
        possibleReasons: {
          noGazePoints: gazePoints.length === 0,
          noTrackingTime: totalTrackingTime === 0,
          noAreaCoverage: areaCoverageScore === 0,
          allFactorsZero: centerAttentionScore === 0 && areaCoverageScore === 0 && stabilityScore === 0 && fixationQualityScore === 0 && headPoseScore === 0 && headMovementScore === 0,
        },
        dataAvailable: {
          gazePoints: gazePoints.length,
          fixations: allFixations.length,
          screenDimensions: !!this.screenDimensions,
          totalTrackingTime,
        },
      });
    }

    // Detect attention drop
    if (this.lastAttentionScore > 0 &&
        this.metrics.attentionScore < this.lastAttentionScore - 20) {
      this.emitEvent('attentionDrop', {
        score: this.metrics.attentionScore,
        previousScore: this.lastAttentionScore,
        drop: this.lastAttentionScore - this.metrics.attentionScore
      });
    }

    this.lastAttentionScore = this.metrics.attentionScore;

    // Concentration Stability: inverse of saccade frequency
    // Get advanced tracker saccades for more accurate calculation
    const advancedSaccades = this.advancedTracker.gazeData?.saccades || [];
    const allSaccades = [...this.saccades, ...advancedSaccades];
    const saccadeFrequency = allSaccades.length / Math.max(1, sessionDuration);
    this.metrics.concentrationStability = Math.max(0, Math.min(1, 1 - saccadeFrequency / 10));

    // Social Gaze Index: % of time looking at avatar face
    const avatarROI = this.rois.find(r => r.name === 'avatar-face' || r.name === 'avatar');
    if (avatarROI) {
      const avatarFixations = allFixations.filter(f =>
        f.x >= avatarROI.x && f.x <= avatarROI.x + avatarROI.width &&
        f.y >= avatarROI.y && f.y <= avatarROI.y + avatarROI.height
      );
      const avatarFixationTime = avatarFixations.reduce((sum, f) => sum + (f.duration || 0), 0);
      const totalFixationTime = allFixations.reduce((sum, f) => sum + (f.duration || 0), 0);
      this.metrics.socialGazeIndex = totalFixationTime > 0
        ? avatarFixationTime / totalFixationTime
        : 0;
    } else {
      this.metrics.socialGazeIndex = 0;
    }

    // Exploration vs Avoidance Ratio (use all fixations)
    const uniqueAreas = new Set(allFixations.map(f => `${Math.floor(f.x / 100)}-${Math.floor(f.y / 100)}`));
    this.metrics.explorationAvoidanceRatio = uniqueAreas.size / Math.max(1, allFixations.length);

    // Average fixation duration (use all fixations including advanced tracker)
    const allFixationDurations = allFixations.map(f => f.duration || 0).filter(d => d > 0);
    this.metrics.avgFixationDuration = allFixationDurations.length > 0
      ? allFixationDurations.reduce((sum, d) => sum + d, 0) / allFixationDurations.length / 1000
      : 0;

    // Total fixations (use all fixations)
    this.metrics.totalFixations = allFixations.length;

    // Average saccade speed (use all saccades)
    const allSaccadeSpeeds = allSaccades.map(s => s.speed || 0).filter(s => s > 0);
    this.metrics.avgSaccadeSpeed = allSaccadeSpeeds.length > 0
      ? allSaccadeSpeeds.reduce((sum, s) => sum + s, 0) / allSaccadeSpeeds.length
      : 0;

    // Blink rate (per minute)
    this.metrics.blinkRate = Math.round((this.blinkCount / sessionDuration) * 60);
  }

  /**
   * Calculate final metrics at session end
   * IMPORTANT: Calculate average from history FIRST, before any other calculations
   * This prevents recalculating with empty data after tracking has stopped
   */
  calculateFinalMetrics() {
    // STEP 1: Calculate average attention score from history FIRST
    // This must happen before any other calculations to preserve the averaged score
    // Do NOT call calculateMetrics() here as tracking has stopped and data might be empty
    if (this.attentionScoreHistory.length > 0) {
      // Filter out scores with no data (default fallbacks)
      const scoresWithData = this.attentionScoreHistory.filter(h => h.hasData);
      
      if (scoresWithData.length > 0) {
        // Use average of scores with actual gaze data
        const avgScore = scoresWithData.reduce((sum, h) => sum + h.score, 0) / scoresWithData.length;
        this.metrics.attentionScore = Math.round(avgScore);
        
        console.log('[EyeTracker] 📊 Final attention score (averaged from history):', {
          averageScore: this.metrics.attentionScore + '%',
          totalSamples: this.attentionScoreHistory.length,
          samplesWithData: scoresWithData.length,
          lastCalculatedScore: this.attentionScoreHistory[this.attentionScoreHistory.length - 1]?.score || 0,
          note: 'Averaged from all scores collected during session (before tracking stopped)',
        });
      } else {
        // If no scores with data, use average of all scores (including fallbacks)
        const avgScore = this.attentionScoreHistory.reduce((sum, h) => sum + h.score, 0) / this.attentionScoreHistory.length;
        this.metrics.attentionScore = Math.round(avgScore);
        
        console.log('[EyeTracker] ⚠️ Final attention score (averaged, no gaze data):', {
          averageScore: this.metrics.attentionScore + '%',
          totalSamples: this.attentionScoreHistory.length,
          warning: 'No gaze data collected during session',
        });
      }
    } else {
      // No history available - use last calculated score if available
      console.warn('[EyeTracker] ⚠️ No attention score history available, using last calculated score:', {
        lastScore: this.metrics.attentionScore,
        note: 'This should not happen if session ran properly',
      });
    }

    // STEP 2: Detect gaze aversions (times when gaze left important areas)
    // Use existing gaze points (collected during session, before stop)
    const gazeAversions = [];
    let lastAversion = null;

    this.gazePoints.forEach((point, i) => {
      const inROI = this.rois.some(roi =>
        point.x >= roi.x && point.x <= roi.x + roi.width &&
        point.y >= roi.y && point.y <= roi.y + roi.height
      );

      if (!inROI && !lastAversion) {
        lastAversion = { startTime: point.timestamp, startIndex: i };
      } else if (inROI && lastAversion) {
        gazeAversions.push({
          timestamp: lastAversion.startTime,
          duration: (point.timestamp - lastAversion.startTime) / 1000
        });
        lastAversion = null;
      }
    });

    this.metrics.gazeAversions = gazeAversions;
    
    // STEP 3: Update other metrics (but preserve the averaged attention score)
    // Only update metrics that don't depend on real-time tracking
    // Do NOT recalculate attention score here as it's already averaged above

    return this.metrics;
  }

  /**
   * Get gaze heatmap data
   */
  getHeatmap() {
    const heatmapData = {};

    this.gazePoints.forEach(point => {
      const key = `${Math.floor(point.x / 20)}-${Math.floor(point.y / 20)}`;
      heatmapData[key] = (heatmapData[key] || 0) + 1;
    });

    return Object.entries(heatmapData).map(([key, count]) => {
      const [x, y] = key.split('-').map(Number);
      return { x: x * 20, y: y * 20, count };
    });
  }

  /**
   * Get current metrics
   */
  getMetrics() {
    return { ...this.metrics };
  }

  /**
   * Get session data for storage
   */
  getSessionData() {
    // Get advanced tracker data for comprehensive metrics
    const advancedMetrics = this.advancedTracker.getMetrics();
    const advancedSessionData = this.advancedTracker.getSessionData();
    
    return {
      metrics: this.getMetrics(),
      gazeHeatmap: this.getHeatmap(),
      gazeAversions: this.metrics.gazeAversions || [],
      fixations: this.fixations.map(f => ({
        x: f.x,
        y: f.y,
        duration: f.duration || (f.endTime - f.startTime),
        startTime: f.startTime,
        endTime: f.endTime || (f.startTime + (f.duration || 0)),
        region: this.getRegionForPoint(f.x, f.y), // Add region info
      })),
      saccades: this.saccades.map(s => ({
        fromX: s.fromX,
        fromY: s.fromY,
        toX: s.toX,
        toY: s.toY,
        distance: s.distance,
        speed: s.speed,
        timestamp: s.timestamp,
      })),
      // Include advanced tracker data
      advancedFixations: advancedSessionData?.fixations || [],
      advancedSaccades: advancedSessionData?.saccades || [],
      calibrationStatus: {
        isCalibrated: advancedMetrics?.isCalibrated || false,
        quality: advancedMetrics?.calibration?.quality || null,
      },
      // Gaze points for heatmap (sample every 10th point to reduce size)
      gazePoints: this.gazePoints.filter((_, i) => i % 10 === 0).map(p => ({
        x: p.x,
        y: p.y,
        timestamp: p.timestamp,
        confidence: p.confidence,
        isDistracted: p.isDistracted,
      })),
    };
  }

  /**
   * Get region name for a gaze point (ROI detection)
   */
  getRegionForPoint(x, y) {
    for (const roi of this.rois) {
      if (x >= roi.x && x <= roi.x + roi.width &&
          y >= roi.y && y <= roi.y + roi.height) {
        return roi.name;
      }
    }
    return 'screen'; // Default region
  }
}

export const eyeTracker = new EyeTracker();
