/**
 * Eye Calibration Component
 *
 * Guides the user through a 9-point eye calibration process.
 * Used at the start of each session for accurate eye tracking.
 */

import React, { useState, useEffect, useCallback, useRef } from 'react';
import {
  Box,
  Typography,
  Button,
  CircularProgress,
  Fade,
  Grow,
  LinearProgress,
  Alert,
  Chip,
  Paper,
} from '@mui/material';
import { keyframes, styled } from '@mui/material/styles';
import CheckCircleIcon from '@mui/icons-material/CheckCircle';
import WarningIcon from '@mui/icons-material/Warning';
import ErrorIcon from '@mui/icons-material/Error';
import RefreshIcon from '@mui/icons-material/Refresh';
import { eyeTracker } from '../../tracking/eyeTracking';
import { mlTracking } from '../../services/mlTracking';
import { useLanguage } from '../../i18n/LanguageContext';

/**
 * Pulse animation for calibration points
 */
const pulse = keyframes`
  0% {
    transform: scale(1);
    box-shadow: 0 0 0 0 rgba(99, 102, 241, 0.7);
  }
  70% {
    transform: scale(1.1);
    box-shadow: 0 0 0 15px rgba(99, 102, 241, 0);
  }
  100% {
    transform: scale(1);
    box-shadow: 0 0 0 0 rgba(99, 102, 241, 0);
  }
`;

/**
 * Pulse animation for warning/error icons
 */
const iconPulse = keyframes`
  0%, 100% {
    transform: scale(1);
    opacity: 1;
  }
  50% {
    transform: scale(1.1);
    opacity: 0.8;
  }
`;

/**
 * Subtle floating animation for dot grid - nothing.tech inspired
 */
const dotGridFloat = keyframes`
  0%, 100% {
    transform: translate(0, 0);
  }
  25% {
    transform: translate(2px, 2px);
  }
  50% {
    transform: translate(0, 4px);
  }
  75% {
    transform: translate(-2px, 2px);
  }
`;

/**
 * Rotating dotted border animation for calibration points
 */
const rotateBorder = keyframes`
  0% {
    transform: translate(-50%, -50%) rotate(0deg);
  }
  100% {
    transform: translate(-50%, -50%) rotate(360deg);
  }
`;

/**
 * Line drawing animation using stroke-dashoffset
 */
const drawLine = keyframes`
  0% {
    stroke-dashoffset: 100%;
  }
  100% {
    stroke-dashoffset: 0%;
  }
`;

/**
 * Styled calibration point
 * Using shouldForwardProp to prevent non-DOM props from being passed to the DOM
 */
/**
 * Rotating dotted border wrapper for calibration points
 */
const RotatingBorderWrapper = styled(Box, {
  shouldForwardProp: (prop) => prop !== 'active' && prop !== 'completed',
})(({ active }) => ({
  position: 'absolute',
  width: active ? '60px' : '50px',
  height: active ? '60px' : '50px',
  borderRadius: '50%',
  border: active ? '3px dashed #6366F1' : '2px dashed #9CA3AF',
  transform: 'translate(-50%, -50%)',
  animation: active ? `${rotateBorder} 3s linear infinite` : 'none',
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
  transition: 'all 0.3s ease',
}));

const CalibrationPoint = styled(Box, {
  shouldForwardProp: (prop) => prop !== 'active' && prop !== 'completed',
})(({ theme, active, completed }) => ({
  width: active ? '40px' : '30px',
  height: active ? '40px' : '30px',
  borderRadius: '50%',
  backgroundColor: completed
    ? theme.palette.success.main
    : active
      ? theme.palette.primary.main
      : theme.palette.grey[300],
  transition: 'all 0.3s ease',
  animation: active ? `${pulse} 1.5s infinite` : 'none',
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
  cursor: 'pointer',
}));

/**
 * Animated SVG line component for drawing effect
 */
const AnimatedLine = styled('line', {
  shouldForwardProp: (prop) => prop !== 'isAnimating' && prop !== 'lineLength',
})(({ isAnimating, lineLength }) => ({
  stroke: '#6366F1',
  strokeWidth: 3,
  strokeLinecap: 'round',
  strokeDasharray: `${lineLength}%`,
  strokeDashoffset: isAnimating ? `${lineLength}%` : '0%',
  animation: isAnimating ? `${drawLine} 1.5s ease-out forwards` : 'none',
}));

/**
 * 4-point calibration positions (as percentages)
 * Simplified pattern: 4 corners only for quick calibration
 * Positions are relative to the full calibration area (below header)
 * Order: top-left -> top-right -> bottom-left -> bottom-right
 */
const CALIBRATION_POINTS = [
  // Corners (4 points) in animation order
  { id: 1, x: 10, y: 10 },    // Top-left corner (first)
  { id: 2, x: 90, y: 10 },    // Top-right corner (second)
  { id: 3, x: 10, y: 90 },    // Bottom-left corner (third)
  { id: 4, x: 90, y: 90 },    // Bottom-right corner (fourth/last)
];

/**
 * Line paths connecting calibration points
 * Path sequence: top-left -> top-right -> bottom-left -> bottom-right
 */
const LINE_PATHS = [
  { id: 1, from: { x: 10, y: 10 }, to: { x: 90, y: 10 } },  // Top-left to Top-right (horizontal)
  { id: 2, from: { x: 90, y: 10 }, to: { x: 10, y: 90 } },  // Top-right to Bottom-left (diagonal)
  { id: 3, from: { x: 10, y: 90 }, to: { x: 90, y: 90 } },  // Bottom-left to Bottom-right (horizontal)
];

/**
 * Main Eye Calibration Component
 */
export default function EyeCalibration({
  onComplete,
  onSkip,
  autoAdvance = true,
  pointDuration = 2000, // ms per point
  videoStream = null, // Video stream from FaceDetectionSetup
}) {
  const { t } = useLanguage();
  const [currentPoint, setCurrentPoint] = useState(0);
  const [completedPoints, setCompletedPoints] = useState([]);
  const [isCalibrating, setIsCalibrating] = useState(false);
  const [showInstructions, setShowInstructions] = useState(true);
  const [calibrationData, setCalibrationData] = useState([]);
  const [showValidation, setShowValidation] = useState(false);
  const [validationResults, setValidationResults] = useState(null);
  const [calibrationQuality, setCalibrationQuality] = useState(null);
  // Track which lines are animating (0 = not started, 1 = animating, 2 = complete)
  const [lineAnimations, setLineAnimations] = useState([0, 0, 0]);

  const containerRef = useRef(null);
  const timerRef = useRef(null);
  const videoRef = useRef(null);
  const gazeSamplesRef = useRef([]);
  const gazeCollectionIntervalRef = useRef(null);
  const [headerHeight, setHeaderHeight] = useState(0);
  const [screenDimensions, setScreenDimensions] = useState({ width: 0, height: 0 });

  /**
   * Complete calibration and call onComplete
   */
  const completeCalibration = useCallback(async () => {
    console.log('[EyeCalibration] 🎉 Calibration complete!');

    setIsCalibrating(false);

    // Prepare calibration data for advanced tracker
    // Format: {target: {x, y}, samples: Array} for advanced calibration engine
    // All coordinates are normalized (0-1) relative to full screen
    const calibrationPoints = calibrationData
      .filter(d => d.gazeSamples && d.gazeSamples.length > 0)
      .map(d => {
        // Samples are already in screen coordinates, convert to normalized (0-1) relative to full screen
        const normalizedSamples = d.gazeSamples.map(s => ({
          normalizedX: s.normalizedX || (s.x / (s.screenWidth || window.innerWidth)), // Normalized relative to full screen
          normalizedY: s.normalizedY || (s.y / (s.screenHeight || window.innerHeight)), // Normalized relative to full screen
          confidence: s.confidence,
          timestamp: s.timestamp,
        }));

        return {
          target: { x: d.targetX / 100, y: d.targetY / 100 }, // Convert percentage to 0-1 (full screen)
          samples: normalizedSamples, // Normalized relative to full screen
          screenDimensions: d.screenDimensions || {
            width: window.innerWidth,
            height: window.innerHeight,
            headerHeight: headerHeight,
          }, // Store for reference
        };
      });

    // Apply calibration to advanced tracker if we have enough points
    let calibrationQuality = null;
    if (calibrationPoints.length >= 3) {
      try {
        // Import advanced tracker
        const { advancedEyeTracker } = await import('../../tracking/advancedEyeTracking');
        const calibrated = await advancedEyeTracker.calibrate(calibrationPoints);

        if (calibrated) {
          console.log('[EyeCalibration] ✅ Advanced tracker calibrated with', calibrationPoints.length, 'points');

          // Get calibration quality from engine
          // Try multiple ways to get quality
          if (advancedEyeTracker.calibrationEngine) {
            const result = advancedEyeTracker.calibrationEngine.getResult();
            calibrationQuality = result.quality;
          } else if (advancedEyeTracker.calibration?.quality) {
            calibrationQuality = advancedEyeTracker.calibration.quality;
          } else {
            // Get from metrics
            const metrics = advancedEyeTracker.getMetrics();
            if (metrics?.calibration?.quality) {
              calibrationQuality = metrics.calibration.quality;
            }
          }
        }
      } catch (error) {
        console.warn('[EyeCalibration] Could not calibrate advanced tracker:', error);
      }
    }

    // Calculate calibration quality (use advanced metrics if available)
    let quality;
    if (calibrationQuality) {
      // Use advanced calibration engine quality metrics
      // Ensure all values are in percentage format (0-100)
      quality = {
        accuracy: Math.max(0, Math.min(100, calibrationQuality.accuracy || 0)),
        precision: Math.max(0, Math.min(100, calibrationQuality.precision || 0)), // Already in percentage
        reliability: Math.max(0, Math.min(100, calibrationQuality.reliability || 0)),
        meanError: calibrationQuality.meanError || 0, // Already in percentage
        maxError: calibrationQuality.maxError || 0, // Already in percentage
        rmsError: calibrationQuality.rmsError || 0, // Already in percentage
        coverage: (completedPoints.length / CALIBRATION_POINTS.length) * 100,
        timestamp: Date.now(),
      };

      console.log('[EyeCalibration] ✅ Using advanced calibration quality metrics:', {
        accuracy: quality.accuracy.toFixed(1) + '%',
        precision: quality.precision.toFixed(1) + '%',
        reliability: quality.reliability.toFixed(1) + '%',
        meanError: quality.meanError.toFixed(2) + '%',
        maxError: quality.maxError.toFixed(2) + '%',
        rmsError: quality.rmsError.toFixed(2) + '%',
      });
    } else {
      // Fallback to simple quality calculation
      let accuracy = 85;
      if (calibrationPoints.length >= 3) {
        const errors = calibrationData
          .filter(d => d.gazeSamples && d.gazeSamples.length > 0)
          .map(d => {
            const target = { x: d.targetX / 100, y: d.targetY / 100 };
            const avgGaze = {
              x: d.gazeSamples.reduce((sum, s) => sum + s.normalizedX, 0) / d.gazeSamples.length,
              y: d.gazeSamples.reduce((sum, s) => sum + s.normalizedY, 0) / d.gazeSamples.length,
            };
            return Math.sqrt(
              Math.pow(target.x - avgGaze.x, 2) + Math.pow(target.y - avgGaze.y, 2)
            );
          });

        if (errors.length > 0) {
          const avgError = errors.reduce((sum, e) => sum + e, 0) / errors.length;
          accuracy = Math.max(70, Math.min(100, 100 - (avgError * 200)));
        }
      }

      quality = {
        accuracy,
        precision: accuracy * 0.9, // Estimate
        reliability: accuracy * 0.85, // Estimate
        meanError: 0,
        maxError: 0,
        rmsError: 0,
        coverage: (completedPoints.length / CALIBRATION_POINTS.length) * 100,
        timestamp: Date.now(),
      };
    }

    console.log('[EyeCalibration] 📊 Calibration results:', {
      pointsCalibrated: completedPoints.length,
      totalPoints: CALIBRATION_POINTS.length,
      coverage: quality.coverage.toFixed(1) + '%',
      accuracy: quality.accuracy.toFixed(1) + '%',
      precision: quality.precision?.toFixed(1) + '%',
      reliability: quality.reliability?.toFixed(1) + '%',
      timestamp: new Date().toISOString()
    });

    // Store quality for UI display (this will trigger the quality screen to show)
    setCalibrationQuality(quality);

    // Check if quality is good enough, otherwise suggest validation
    // For mobile eye tracking, accuracy is more important than precision
    if (quality.accuracy < 70 || quality.meanError > 20) {
      console.warn('[EyeCalibration] ⚠️ Calibration quality may be low. Consider recalibration.');
    }

    // DO NOT automatically call onComplete - wait for user to click Continue button
    // The user will see the quality screen and decide whether to recalibrate or continue
    console.log('[EyeCalibration] 📊 Calibration complete. Waiting for user to continue...');
  }, [calibrationData, completedPoints]);

  /**
   * Get screen dimensions excluding header
   * Calibrates to full screen (left, right, top, bottom) minus header area
   */
  const getScreenDimensions = useCallback(() => {
    const width = window.innerWidth;
    const height = window.innerHeight - headerHeight; // Exclude header
    const topOffset = headerHeight; // Y offset for header

    return {
      width,
      height,
      topOffset, // Y coordinate offset (header height)
      left: 0,
      right: width,
      top: topOffset,
      bottom: window.innerHeight,
    };
  }, [headerHeight]);

  /**
   * Measure header height and screen dimensions
   * Header is excluded from calibration area
   */
  useEffect(() => {
    const measureHeaderAndScreen = () => {
      // Find the header element (sticky header in SessionFlow)
      // Look for the header by checking parent elements or using a data attribute
      let headerElement = null;

      // Try to find header by checking parent containers
      let parent = containerRef.current?.parentElement;
      while (parent && !headerElement) {
        // Check if this element has the sticky header styling
        const styles = window.getComputedStyle(parent);
        if (styles.position === 'sticky' && styles.top === '0px') {
          headerElement = parent;
        } else {
          // Check siblings for header
          const siblings = Array.from(parent.parentElement?.children || []);
          const stickySibling = siblings.find(el => {
            const s = window.getComputedStyle(el);
            return s.position === 'sticky' && s.top === '0px';
          });
          if (stickySibling) {
            headerElement = stickySibling;
          }
        }
        parent = parent.parentElement;
      }

      // If header found, measure its height
      let measuredHeaderHeight = 0;
      if (headerElement) {
        const headerRect = headerElement.getBoundingClientRect();
        measuredHeaderHeight = headerRect.height;
      } else {
        // Fallback: estimate header height (typically 100-120px with stepper)
        // SessionFlow header has: py: 1 (8px top + 8px bottom) + content + stepper
        measuredHeaderHeight = 120; // Conservative estimate
      }

      // Add 10px extra space to account for progress stepper and spacing
      // This ensures calibration points appear fully below the header/stepper
      measuredHeaderHeight += 10;

      setHeaderHeight(measuredHeaderHeight);

      console.log('[EyeCalibration] Header height (including 10px extra for stepper):', measuredHeaderHeight);

      // Measure screen dimensions
      const screenDims = {
        width: window.innerWidth,
        height: window.innerHeight,
      };
      setScreenDimensions(screenDims);

      console.log('[EyeCalibration] Screen dimensions (full screen):', screenDims);
      console.log('[EyeCalibration] Header height (excluded from calibration):', measuredHeaderHeight);
      console.log('[EyeCalibration] Calibration area:', {
        width: screenDims.width,
        height: screenDims.height - measuredHeaderHeight,
        topOffset: measuredHeaderHeight,
      });
    };

    // Measure immediately and after layout
    measureHeaderAndScreen();
    const timeoutId = setTimeout(measureHeaderAndScreen, 100);
    const timeoutId2 = setTimeout(measureHeaderAndScreen, 500);

    // Also measure on window resize
    window.addEventListener('resize', measureHeaderAndScreen);

    // Use ResizeObserver for accurate measurements
    let resizeObserver = null;
    if (containerRef.current && window.ResizeObserver) {
      resizeObserver = new ResizeObserver(measureHeaderAndScreen);
      resizeObserver.observe(containerRef.current);
    }

    return () => {
      clearTimeout(timeoutId);
      clearTimeout(timeoutId2);
      window.removeEventListener('resize', measureHeaderAndScreen);
      if (resizeObserver) {
        resizeObserver.disconnect();
      }
    };
  }, [isCalibrating, showInstructions]);

  /**
   * Start collecting gaze samples for current calibration point
   */
  const startGazeCollection = useCallback(() => {
    // Clear previous samples
    gazeSamplesRef.current = [];

    // Check if MediaPipe is initialized
    if (!mlTracking.isInitialized) {
      console.warn('[EyeCalibration] ⚠️ MediaPipe not initialized yet. Cannot collect gaze samples.');
      return;
    }

    console.log('[EyeCalibration] 📊 Starting gaze collection for point', currentPoint + 1);
    console.log('[EyeCalibration] MediaPipe initialized:', mlTracking.isInitialized);

    // Get screen dimensions (full screen minus header)
    const screenDims = getScreenDimensions();
    console.log('[EyeCalibration] Using screen dimensions (full screen minus header):', screenDims);

    // Set up callback to receive real-time gaze data from MediaPipe
    let lastGazeTime = 0;
    mlTracking.setCallback('onEyeGaze', (gaze) => {
      if (gaze && gaze.x !== undefined && gaze.y !== undefined) {
        const now = Date.now();
        // Only collect samples every 100ms to avoid too many samples
        if (now - lastGazeTime >= 100) {
          // Convert normalized coordinates (0-1) to screen coordinates
          // Full screen: left=0, right=window.innerWidth, top=headerHeight, bottom=window.innerHeight
          const screenX = gaze.x * window.innerWidth;
          const screenY = gaze.y * window.innerHeight;

          // Adjust Y coordinate to account for header offset
          // Normalized Y (0-1) maps to full screen, but we want coordinates relative to content area
          const adjustedY = screenY; // Keep full screen Y for now, header offset handled separately

          gazeSamplesRef.current.push({
            x: screenX, // Screen X coordinate (0 to window.innerWidth)
            y: adjustedY, // Screen Y coordinate (0 to window.innerHeight, header included in normalized)
            normalizedX: gaze.x, // Normalized 0-1 (relative to full screen)
            normalizedY: gaze.y, // Normalized 0-1 (relative to full screen)
            screenWidth: window.innerWidth,
            screenHeight: window.innerHeight,
            headerHeight: screenDims.topOffset, // Store header height for reference
            confidence: gaze.confidence || 0.5,
            timestamp: Date.now(),
          });
          lastGazeTime = now;

          // Log first few samples for debugging
          if (gazeSamplesRef.current.length <= 3) {
            console.log('[EyeCalibration] 📊 Gaze sample collected:', {
              normalized: `(${(gaze.x * 100).toFixed(1)}%, ${(gaze.y * 100).toFixed(1)}%)`,
              screen: `(${screenX.toFixed(0)}, ${adjustedY.toFixed(0)}) [${window.innerWidth}x${window.innerHeight}]`,
              headerOffset: `${screenDims.topOffset}px`,
              confidence: gaze.confidence?.toFixed(2) || 'N/A'
            });
          }
        }
      }
    });

    // Also collect from metrics as fallback (in case callback doesn't fire)
    gazeCollectionIntervalRef.current = setInterval(() => {
      try {
        const metrics = mlTracking.getMetrics();
        if (metrics && metrics.gazePoints && metrics.gazePoints.length > 0) {
          // Get the most recent gaze point
          const latestGaze = metrics.gazePoints[metrics.gazePoints.length - 1];
          if (latestGaze && latestGaze.x !== undefined && latestGaze.y !== undefined) {
            // Check if we already have this sample (avoid duplicates)
            const exists = gazeSamplesRef.current.some(s =>
              Math.abs(s.normalizedX - latestGaze.x) < 0.001 &&
              Math.abs(s.normalizedY - latestGaze.y) < 0.001 &&
              Math.abs(s.timestamp - (latestGaze.timestamp || Date.now())) < 200
            );

            if (!exists) {
              // Convert normalized coordinates (0-1) to screen coordinates
              const screenDims = getScreenDimensions();
              const screenX = latestGaze.x * window.innerWidth;
              const screenY = latestGaze.y * window.innerHeight;

              gazeSamplesRef.current.push({
                x: screenX, // Screen X coordinate
                y: screenY, // Screen Y coordinate
                normalizedX: latestGaze.x,
                normalizedY: latestGaze.y,
                screenWidth: window.innerWidth,
                screenHeight: window.innerHeight,
                headerHeight: screenDims.topOffset,
                timestamp: Date.now(),
              });
            }
          }
        }
      } catch (error) {
        console.error('[EyeCalibration] Error collecting gaze from metrics:', error);
      }
    }, 100); // Collect every 100ms

    console.log('[EyeCalibration] 📊 Gaze collection started for point', currentPoint + 1);
  }, [currentPoint, getScreenDimensions]);

  /**
   * Stop collecting gaze samples
   */
  const stopGazeCollection = useCallback(() => {
    if (gazeCollectionIntervalRef.current) {
      clearInterval(gazeCollectionIntervalRef.current);
      gazeCollectionIntervalRef.current = null;
      console.log('[EyeCalibration] 📊 Stopped collecting gaze samples. Collected', gazeSamplesRef.current.length, 'samples');
    }
  }, []);

  /**
   * Initialize MediaPipe tracking with video stream
   */
  useEffect(() => {
    const initializeTracking = async () => {
      // Check if MediaPipe is already initialized
      if (mlTracking.isInitialized) {
        console.log('[EyeCalibration] ✅ MediaPipe already initialized, reusing...');
        return;
      }

      // Try to get video element from DOM first
      let video = document.querySelector('video');

      // If no video element found but we have a stream, create one
      if (!video && videoStream) {
        console.log('[EyeCalibration] 📹 Creating video element for stream...');
        video = document.createElement('video');
        video.autoplay = true;
        video.playsInline = true;
        video.muted = true;
        video.style.position = 'fixed';
        video.style.top = '-9999px'; // Hide but keep in DOM
        video.style.width = '1px';
        video.style.height = '1px';
        video.srcObject = videoStream;
        document.body.appendChild(video);
        videoRef.current = video;

        // Wait for video to be ready
        await new Promise((resolve) => {
          video.onloadedmetadata = () => {
            video.play().then(() => {
              console.log('[EyeCalibration] ✅ Video element created and playing');
              resolve();
            }).catch(err => {
              console.error('[EyeCalibration] ⚠️ Video play error:', err);
              resolve(); // Continue anyway
            });
          };
        });
      } else if (video && video.srcObject) {
        videoRef.current = video;
        console.log('[EyeCalibration] 📹 Using existing video element');
      } else if (videoStream) {
        // Use provided stream
        if (!video) {
          video = document.createElement('video');
          video.autoplay = true;
          video.playsInline = true;
          video.muted = true;
          video.style.position = 'fixed';
          video.style.top = '-9999px';
          video.style.width = '1px';
          video.style.height = '1px';
          document.body.appendChild(video);
        }
        video.srcObject = videoStream;
        videoRef.current = video;

        await new Promise((resolve) => {
          video.onloadedmetadata = () => {
            video.play().then(() => resolve()).catch(() => resolve());
          };
        });
      }

      if (videoRef.current && (videoRef.current.srcObject || videoStream)) {
        try {
          console.log('[EyeCalibration] 🔧 Initializing MediaPipe eye tracking...');
          await mlTracking.initialize(videoRef.current, (results) => {
            // Results callback - MediaPipe processes frames here
            if (results && results.multiFaceLandmarks && results.multiFaceLandmarks.length > 0) {
              // MediaPipe is working
            }
          });
          console.log('[EyeCalibration] ✅ MediaPipe initialized successfully');
        } catch (error) {
          console.error('[EyeCalibration] ❌ Failed to initialize MediaPipe:', error);
          console.error('[EyeCalibration] Error details:', error.message, error.stack);
        }
      } else {
        console.warn('[EyeCalibration] ⚠️ No video element or stream available. Eye tracking will not work.');
        console.warn('[EyeCalibration] Video element:', videoRef.current);
        console.warn('[EyeCalibration] Video stream:', videoStream);
      }
    };

    // Initialize immediately when component mounts
    initializeTracking();

    return () => {
      stopGazeCollection();
    };
  }, [videoStream, stopGazeCollection]);

  /**
   * Start calibration process
   */
  const startCalibration = useCallback(() => {
    console.log('[EyeCalibration] 🎬 Starting calibration process...');
    console.log('[EyeCalibration] 📋 Total points:', CALIBRATION_POINTS.length);
    console.log('[EyeCalibration] ⏱️ Point duration:', pointDuration + 'ms');

    setShowInstructions(false);
    setIsCalibrating(true);
    setCurrentPoint(0);
    setCompletedPoints([]);
    setCalibrationData([]);
    setLineAnimations([0, 0, 0]); // Reset line animations
    gazeSamplesRef.current = [];

    // Start eye tracker if not already running
    if (eyeTracker && typeof eyeTracker.start === 'function') {
      console.log('[EyeCalibration] 👁️ Starting eye tracker...');
      eyeTracker.start();
    } else {
      console.warn('[EyeCalibration] ⚠️ Eye tracker not available');
    }
  }, []);

  /**
   * Advance to next calibration point
   */
  const advancePoint = useCallback(() => {
    // Stop collecting gaze samples for current point
    stopGazeCollection();

    const point = CALIBRATION_POINTS[currentPoint];
    const collectedSamples = [...gazeSamplesRef.current];

    console.log('[EyeCalibration] ✅ Point completed:', {
      pointId: point.id,
      targetPosition: `(${point.x}%, ${point.y}%)`,
      progress: `${currentPoint + 1}/${CALIBRATION_POINTS.length}`,
      gazeSamplesCollected: collectedSamples.length,
      timestamp: new Date().toISOString()
    });

    // Log sample statistics if we have samples
    if (collectedSamples.length > 0) {
      const avgX = collectedSamples.reduce((sum, s) => sum + s.normalizedX, 0) / collectedSamples.length;
      const avgY = collectedSamples.reduce((sum, s) => sum + s.normalizedY, 0) / collectedSamples.length;
      const targetX = point.x / 100; // Convert percentage to 0-1
      const targetY = point.y / 100;

      const errorX = Math.abs(avgX - targetX) * 100;
      const errorY = Math.abs(avgY - targetY) * 100;

      console.log('[EyeCalibration] 📊 Gaze statistics:', {
        averageGaze: `(${(avgX * 100).toFixed(1)}%, ${(avgY * 100).toFixed(1)}%)`,
        targetPosition: `(${point.x}%, ${point.y}%)`,
        errorX: errorX.toFixed(1) + '%',
        errorY: errorY.toFixed(1) + '%',
        totalError: Math.sqrt(errorX * errorX + errorY * errorY).toFixed(1) + '%'
      });
    } else {
      console.warn('[EyeCalibration] ⚠️ No gaze samples collected for this point! Eye tracking may not be working.');
    }

    // Filter out low-quality samples before averaging
    // Remove samples with very low confidence or extreme outliers
    const filteredSamples = collectedSamples.filter(sample => {
      // Keep samples with reasonable confidence
      if (sample.confidence !== undefined && sample.confidence < 0.3) {
        return false;
      }
      // Keep samples within reasonable bounds (0-1 range)
      if (sample.normalizedX < 0 || sample.normalizedX > 1 ||
        sample.normalizedY < 0 || sample.normalizedY > 1) {
        return false;
      }
      return true;
    });

    // If we have filtered samples, use them; otherwise use all samples
    const validSamples = filteredSamples.length >= 3 ? filteredSamples : collectedSamples;

    // Calculate average gaze with outlier removal
    // Use full screen coordinates for calibration
    let avgX, avgY;
    if (validSamples.length > 0) {
      // Samples are already in screen coordinates (x, y) and normalized (normalizedX, normalizedY)
      // Use normalized coordinates (0-1 relative to full screen) for calibration
      const normalizedSamples = validSamples.map(s => ({
        normalizedX: s.normalizedX || (s.x / window.innerWidth), // Normalized relative to full screen
        normalizedY: s.normalizedY || (s.y / window.innerHeight),
        original: s,
      }));

      // Calculate median for robustness
      const sortedX = [...normalizedSamples].sort((a, b) => a.normalizedX - b.normalizedX);
      const sortedY = [...normalizedSamples].sort((a, b) => a.normalizedY - b.normalizedY);

      const medianX = sortedX[Math.floor(sortedX.length / 2)].normalizedX;
      const medianY = sortedY[Math.floor(sortedY.length / 2)].normalizedY;

      // Use median as center, then calculate mean of samples near median (within 10%)
      const threshold = 0.1;
      const nearMedianSamples = normalizedSamples.filter(s =>
        Math.abs(s.normalizedX - medianX) < threshold &&
        Math.abs(s.normalizedY - medianY) < threshold
      );

      if (nearMedianSamples.length > 0) {
        avgX = nearMedianSamples.reduce((sum, s) => sum + s.normalizedX, 0) / nearMedianSamples.length;
        avgY = nearMedianSamples.reduce((sum, s) => sum + s.normalizedY, 0) / nearMedianSamples.length;
      } else {
        // Fallback to median if no samples near median
        avgX = medianX;
        avgY = medianY;
      }

      // avgX and avgY are now normalized (0-1) relative to full screen
      // This matches how calibration points are positioned (percentages of full screen)
    } else {
      // Fallback if no valid samples - use target point position
      avgX = point.x / 100; // Already in percentage, convert to 0-1
      avgY = point.y / 100;
    }

    // Record calibration data for this point with filtered samples
    const data = {
      pointId: point.id,
      targetX: point.x,
      targetY: point.y,
      timestamp: Date.now(),
      gazeSamples: validSamples, // Filtered gaze data
      sampleCount: validSamples.length,
      filteredCount: collectedSamples.length - validSamples.length,
    };

    setCalibrationData(prev => [...prev, data]);
    setCompletedPoints(prev => [...prev, point.id]);

    // Store calibration point for advanced tracker
    // Both target and gaze are normalized (0-1) relative to full screen
    const screenDims = getScreenDimensions();
    const calibrationPoint = {
      target: { x: point.x / 100, y: point.y / 100 }, // Convert percentage to 0-1 (full screen)
      gaze: { x: avgX, y: avgY }, // Normalized relative to full screen
      samples: validSamples, // Include samples for advanced calibration
      screenDimensions: {
        width: window.innerWidth,
        height: window.innerHeight,
        headerHeight: screenDims.topOffset,
      }, // Store screen dimensions for reference
    };

    // Store in data for later use
    data.calibrationPoint = calibrationPoint;
    data.screenDimensions = {
      width: window.innerWidth,
      height: window.innerHeight,
      headerHeight: screenDims.topOffset,
    }; // Also store in data

    // Move to next point or complete
    if (currentPoint < CALIBRATION_POINTS.length - 1) {
      const nextPoint = CALIBRATION_POINTS[currentPoint + 1];
      const nextPointIndex = currentPoint + 1;
      console.log('[EyeCalibration] ➡️ Moving to next point:', {
        pointId: nextPoint.id,
        position: `(${nextPoint.x}%, ${nextPoint.y}%)`
      });

      // Start line animation to the next point
      // Line index is currentPoint (0-indexed) matching: 0->1 (line 0), 1->2 (line 1), 2->3 (line 2)
      const lineIndex = currentPoint;
      if (lineIndex >= 0 && lineIndex < LINE_PATHS.length) {
        console.log('[EyeCalibration] 📏 Starting line animation:', lineIndex + 1);
        setLineAnimations(prev => {
          const newState = [...prev];
          newState[lineIndex] = 1; // Set to animating
          return newState;
        });

        // After line animation completes (1.5s), mark it complete and advance to next point
        // Use closure-safe reference to nextPointIndex
        setTimeout(() => {
          setLineAnimations(prev => {
            const newState = [...prev];
            newState[lineIndex] = 2; // Set to complete
            return newState;
          });
          setCurrentPoint(nextPointIndex); // Use captured value, not currentPoint
          // Start collecting gaze samples for the next point
          setTimeout(() => startGazeCollection(), 200);
        }, 1500); // Line animation duration
      } else {
        setCurrentPoint(nextPointIndex);
        setTimeout(() => startGazeCollection(), 200);
      }
    } else {
      // Calibration complete
      console.log('[EyeCalibration] 🎉 All points completed!');
      completeCalibration();
    }
  }, [currentPoint, completeCalibration, stopGazeCollection, startGazeCollection]);

  /**
   * Handle point click (manual mode)
   */
  const handlePointClick = (pointId) => {
    if (!autoAdvance && CALIBRATION_POINTS[currentPoint].id === pointId) {
      advancePoint();
    }
  };

  /**
   * Auto-advance timer and gaze collection
   */
  useEffect(() => {
    if (isCalibrating && autoAdvance) {
      // Start collecting gaze samples when point becomes active
      startGazeCollection();

      timerRef.current = setTimeout(() => {
        advancePoint();
      }, pointDuration);

      return () => {
        if (timerRef.current) {
          clearTimeout(timerRef.current);
        }
        stopGazeCollection();
      };
    }
  }, [isCalibrating, currentPoint, autoAdvance, pointDuration, advancePoint, startGazeCollection, stopGazeCollection]);

  /**
   * Render instructions screen
   */
  if (showInstructions) {
    return (
      <Fade in>
        <Box
          sx={{
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            flex: 1, // Fill available space
            width: '100%',
            p: { xs: 2, sm: 4 }, // Reduced padding on mobile
            textAlign: 'center',
            overflow: 'hidden', // Prevent content overflow
            position: 'relative',
            bgcolor: '#FFFFFF',
            // Animated dot grid background - nothing.tech inspired
            '&::before': {
              content: '""',
              position: 'absolute',
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              backgroundImage: `radial-gradient(circle, rgba(0, 0, 0, 0.08) 1px, transparent 1px)`,
              backgroundSize: '24px 24px',
              animation: `${dotGridFloat} 8s ease-in-out infinite`,
              pointerEvents: 'none',
              zIndex: 0,
            },
          }}
        >
          {/* Content wrapper to ensure it's above the dot grid */}
          <Box sx={{ position: 'relative', zIndex: 1 }}>
            <Typography variant="h4" gutterBottom sx={{ fontWeight: 600, color: '#1a1a2e' }}>
              {t.session.calibration.title}
            </Typography>

            <Typography variant="body1" sx={{ mb: 4, maxWidth: 500, color: '#6B7280' }}>
              {t.session.calibration.instructions}
            </Typography>

            <Box sx={{ mb: 3 }}>
              <Typography variant="body2" sx={{ color: '#6B7280' }}>
                {t.session.calibration.calibrating}
              </Typography>
            </Box>

            <Box sx={{ display: 'flex', gap: 2, justifyContent: 'center' }}>
              <Button
                variant="contained"
                size="large"
                onClick={startCalibration}
                sx={{ px: 4, py: 1.5 }}
              >
                {t.buttons.start}
              </Button>

              {onSkip && (
                <Button
                  variant="text"
                  onClick={onSkip}
                >
                  {t.session.calibration.skip}
                </Button>
              )}
            </Box>
          </Box>
        </Box>
      </Fade>
    );
  }

  /**
   * Get quality level and color
   * Accuracy is the primary factor, precision is secondary
   * Mobile eye tracking typically has lower precision than lab equipment
   */
  const getQualityLevel = (quality) => {
    if (!quality) return { level: 'unknown', color: 'grey', label: 'Unknown' };

    const accuracy = quality.accuracy || 0;
    const precision = quality.precision || 0;
    const meanError = quality.meanError || 0;

    // Primary factor: Accuracy (how close to targets)
    // Secondary factor: Precision (consistency) - more lenient for mobile
    // Also consider mean error as a tie-breaker
    // Updated thresholds to be more realistic for mobile devices

    if (accuracy >= 80 && meanError < 10) {
      // Excellent: High accuracy with low error (lowered from 90/5)
      return { level: 'excellent', color: 'success', label: 'Excellent', icon: CheckCircleIcon };
    } else if (accuracy >= 70 && meanError < 15) {
      // Good: Good accuracy, acceptable for mobile eye tracking
      return { level: 'good', color: 'success', label: 'Good', icon: CheckCircleIcon };
    } else if (accuracy >= 70 && meanError < 20) {
      // Acceptable: Usable accuracy, may have some inconsistency
      return { level: 'acceptable', color: 'warning', label: 'Acceptable', icon: WarningIcon };
    } else if (accuracy >= 60) {
      // Fair: Below ideal but might still work
      return { level: 'acceptable', color: 'warning', label: 'Fair', icon: WarningIcon };
    } else {
      // Poor: Low accuracy, recommend recalibration
      return { level: 'poor', color: 'error', label: 'Poor', icon: ErrorIcon };
    }
  };

  /**
   * Handle recalibration
   */
  const handleRecalibrate = () => {
    setCalibrationQuality(null);
    setCalibrationData([]);
    setCompletedPoints([]);
    setCurrentPoint(0);
    setIsCalibrating(false);
    setShowInstructions(true);
  };

  /**
   * Render calibration complete screen
   */
  if (!isCalibrating && completedPoints.length === CALIBRATION_POINTS.length) {
    const qualityInfo = getQualityLevel(calibrationQuality);
    const QualityIcon = qualityInfo.icon || CheckCircleIcon;
    const needsRecalibration = qualityInfo.level === 'poor' || qualityInfo.level === 'acceptable';

    return (
      <Fade in>
        <Box
          sx={{
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            flex: 1, // Fill available space
            width: '100%',
            p: { xs: 1, sm: 3 }, // Reduced padding on mobile for better fit
            textAlign: 'center',
            overflow: 'auto', // Allow scroll only if content exceeds
          }}
        >
          {/* Quality Icon */}
          <QualityIcon
            sx={{
              fontSize: { xs: 48, sm: 80 },
              color: `${qualityInfo.color}.main`,
              mb: { xs: 1, sm: 2 },
              ...(needsRecalibration && {
                animation: `${iconPulse} 2s infinite`,
              }),
            }}
          />

          <Typography variant="h4" gutterBottom sx={{ fontWeight: 600 }}>
            {t.session.calibration.complete}
          </Typography>

          {/* Quality Display */}
          {calibrationQuality && (
            <Paper
              elevation={2}
              sx={{
                p: { xs: 2, sm: 3 },
                mt: { xs: 1, sm: 2 },
                mb: { xs: 1.5, sm: 3 },
                maxWidth: 500,
                width: '100%',
                bgcolor: 'background.paper',
              }}
            >
              <Typography variant="h6" gutterBottom>
                {t.session.calibration.quality.title}
              </Typography>

              {/* Accuracy Level */}
              <Box sx={{ mb: 3 }}>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
                  <Typography variant="body2" sx={{ color: '#6B7280' }}>
                    {t.session.calibration.quality.accuracy}
                  </Typography>
                  <Chip
                    label={qualityInfo.label}
                    color={qualityInfo.color}
                    size="small"
                    icon={<QualityIcon />}
                  />
                </Box>
                <LinearProgress
                  variant="determinate"
                  value={calibrationQuality.accuracy}
                  sx={{
                    height: 8,
                    borderRadius: 4,
                    bgcolor: 'grey.200',
                    '& .MuiLinearProgress-bar': {
                      bgcolor: `${qualityInfo.color}.main`,
                    },
                  }}
                />
                <Typography variant="caption" sx={{ mt: 0.5, display: 'block', color: '#9CA3AF' }}>
                  {calibrationQuality.accuracy.toFixed(1)}%
                </Typography>
              </Box>

              {/* Quality Metrics Grid */}
              <Box sx={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 2, mb: 2 }}>
                <Box>
                  <Typography variant="caption" color="text.secondary">
                    {t.session.calibration.quality.precision}
                  </Typography>
                  <Typography variant="h6" color={`${qualityInfo.color}.main`}>
                    {calibrationQuality.precision?.toFixed(1) || 'N/A'}%
                  </Typography>
                </Box>
                <Box>
                  <Typography variant="caption" color="text.secondary">
                    {t.session.calibration.quality.reliability}
                  </Typography>
                  <Typography variant="h6" color={`${qualityInfo.color}.main`}>
                    {calibrationQuality.reliability?.toFixed(1) || 'N/A'}%
                  </Typography>
                </Box>
                <Box>
                  <Typography variant="caption" color="text.secondary">
                    Mean Error
                  </Typography>
                  <Typography variant="body2">
                    {calibrationQuality.meanError?.toFixed(2) || 'N/A'}%
                  </Typography>
                </Box>
                <Box>
                  <Typography variant="caption" color="text.secondary">
                    Max Error
                  </Typography>
                  <Typography variant="body2">
                    {calibrationQuality.maxError?.toFixed(2) || 'N/A'}%
                  </Typography>
                </Box>
              </Box>

              {/* Recommendation Alert */}
              {needsRecalibration && (
                <Alert
                  severity={qualityInfo.level === 'poor' ? 'error' : 'warning'}
                  icon={<WarningIcon />}
                  sx={{ mt: 2 }}
                >
                  <Typography variant="body2" gutterBottom>
                    <strong>Recalibration Recommended</strong>
                  </Typography>
                  <Typography variant="caption">
                    {qualityInfo.level === 'poor'
                      ? 'Calibration accuracy is below 60% or mean error is above 20%. For best results, please recalibrate with better lighting and stable head position.'
                      : 'Calibration quality is acceptable but could be improved. Consider recalibrating for better accuracy if you experience tracking issues.'}
                  </Typography>
                </Alert>
              )}

              {!needsRecalibration && (
                <Alert severity="success" sx={{ mt: 2 }}>
                  <Typography variant="body2">
                    Calibration quality is good! Eye tracking should work accurately.
                  </Typography>
                </Alert>
              )}
            </Paper>
          )}

          {/* Action Buttons */}
          <Box sx={{ display: 'flex', gap: { xs: 1.5, sm: 2 }, mt: { xs: 1, sm: 2 } }}>
            {needsRecalibration ? (
              <>
                <Button
                  variant="contained"
                  color="primary"
                  size="large"
                  startIcon={<RefreshIcon />}
                  onClick={handleRecalibrate}
                  sx={{ px: 4, py: 1.5 }}
                >
                  {t.session.calibration.quality.recalibrate}
                </Button>
                <Button
                  variant="outlined"
                  size="large"
                  onClick={() => {
                    // Prepare result data
                    const screenDims = getScreenDimensions();
                    const result = {
                      calibrationData,
                      quality: calibrationQuality,
                      pointsCalibrated: completedPoints.length,
                      calibrationPoints: calibrationData
                        .filter(d => d.calibrationPoint)
                        .map(d => d.calibrationPoint),
                      screenDimensions: {
                        width: window.innerWidth,
                        height: window.innerHeight,
                        headerHeight: screenDims.topOffset,
                      }, // Include screen dimensions for full-screen gaze tracking
                    };
                    console.log('[EyeCalibration] 📤 User chose to continue. Calling onComplete:', result);
                    console.log('[EyeCalibration] Screen dimensions for full-screen gaze tracking:', result.screenDimensions);
                    if (onComplete) {
                      onComplete(result);
                    }
                  }}
                  sx={{ px: 4, py: 1.5 }}
                >
                  {t.session.calibration.quality.continue}
                </Button>
              </>
            ) : (
              <Button
                variant="contained"
                color="primary"
                size="large"
                onClick={() => {
                  // Prepare result data
                  const screenDims = getScreenDimensions();
                  const result = {
                    calibrationData,
                    quality: calibrationQuality,
                    pointsCalibrated: completedPoints.length,
                    calibrationPoints: calibrationData
                      .filter(d => d.calibrationPoint)
                      .map(d => d.calibrationPoint),
                    screenDimensions: {
                      width: window.innerWidth,
                      height: window.innerHeight,
                      headerHeight: screenDims.topOffset,
                    }, // Include screen dimensions for full-screen gaze tracking
                  };
                  console.log('[EyeCalibration] 📤 User chose to continue. Calling onComplete:', result);
                  console.log('[EyeCalibration] Screen dimensions for full-screen gaze tracking:', result.screenDimensions);
                  if (onComplete) {
                    onComplete(result);
                  }
                }}
                sx={{ px: 4, py: 1.5 }}
              >
                {t.session.calibration.quality.continue}
              </Button>
            )}
          </Box>
        </Box>
      </Fade>
    );
  }

  /**
   * Render calibration points
   * Full screen calibration (left, right, top, bottom) excluding header
   */
  return (
    <Box
      ref={containerRef}
      sx={{
        position: 'fixed',
        top: headerHeight, // Start below header
        left: 0,
        right: 0,
        bottom: 0,
        width: '100%',
        height: `calc(100% - ${headerHeight}px)`, // Full screen minus header
        minHeight: '500px',
        // Checkered grid pattern background
        bgcolor: '#FFFFFF',
        backgroundImage: `
          linear-gradient(45deg, #f0f0f0 25%, transparent 25%),
          linear-gradient(-45deg, #f0f0f0 25%, transparent 25%),
          linear-gradient(45deg, transparent 75%, #f0f0f0 75%),
          linear-gradient(-45deg, transparent 75%, #f0f0f0 75%)
        `,
        backgroundSize: '40px 40px',
        backgroundPosition: '0 0, 0 20px, 20px -20px, -20px 0px',
        overflow: 'hidden',
        zIndex: 1,
      }}
    >
      {/* Progress indicator */}
      <Box sx={{ position: 'absolute', top: 16, left: '50%', transform: 'translateX(-50%)', zIndex: 10 }}>
        <Typography variant="body2" sx={{ color: '#4B5563', fontWeight: 500, bgcolor: 'rgba(255,255,255,0.9)', px: 2, py: 0.5, borderRadius: 1 }}>
          {t.session.calibration.pointOf.replace('{current}', currentPoint + 1).replace('{total}', CALIBRATION_POINTS.length)}
        </Typography>
      </Box>

      {/* Animated connecting lines SVG - behind circles */}
      <svg
        style={{
          position: 'absolute',
          top: 0,
          left: 0,
          width: '100%',
          height: '100%',
          pointerEvents: 'none',
          zIndex: 1, // Below circles
        }}
      >
        {LINE_PATHS.map((line, index) => {
          const animationState = lineAnimations[index];
          // Only render lines that are animating (1) or complete (2)
          if (animationState === 0) return null;

          // Calculate line length for dash animation
          const dx = line.to.x - line.from.x;
          const dy = line.to.y - line.from.y;
          const length = Math.sqrt(dx * dx + dy * dy);

          return (
            <AnimatedLine
              key={line.id}
              x1={`${line.from.x}%`}
              y1={`${line.from.y}%`}
              x2={`${line.to.x}%`}
              y2={`${line.to.y}%`}
              isAnimating={animationState === 1}
              lineLength={length}
            />
          );
        })}
      </svg>
      {CALIBRATION_POINTS.map((point) => {
        const isActive = CALIBRATION_POINTS[currentPoint]?.id === point.id;
        const isCompleted = completedPoints.includes(point.id);

        return (
          <RotatingBorderWrapper
            key={point.id}
            active={isActive}
            sx={{
              left: `${point.x}%`,
              top: `${point.y}%`,
              zIndex: 3, // Above lines
            }}
          >
            <Grow
              in={true}
              timeout={300 + (point.id * 100)}
            >
              <CalibrationPoint
                active={isActive}
                completed={isCompleted}
                onClick={() => handlePointClick(point.id)}
              >
                {isCompleted && (
                  <CheckCircleIcon sx={{ fontSize: 20, color: 'white' }} />
                )}
              </CalibrationPoint>
            </Grow>
          </RotatingBorderWrapper>
        );
      })}
    </Box>
  );
}

/**
 * Compact calibration for quick recalibration
 */
export function QuickCalibration({ onComplete }) {
  const [isCalibrating, setIsCalibrating] = useState(false);

  const handleCalibrate = () => {
    setIsCalibrating(true);

    // Quick 5-point calibration
    setTimeout(() => {
      setIsCalibrating(false);
      if (onComplete) {
        onComplete({ quick: true, timestamp: Date.now() });
      }
    }, 3000);
  };

  return (
    <Button
      variant="outlined"
      size="small"
      onClick={handleCalibrate}
      disabled={isCalibrating}
      startIcon={isCalibrating && <CircularProgress size={16} />}
    >
      {isCalibrating ? 'Calibrating...' : 'Recalibrate'}
    </Button>
  );
}
