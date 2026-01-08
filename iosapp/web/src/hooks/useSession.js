/**
 * Unified Session Tracker Hook for Komal
 * Combines eye tracking, micro-expressions, touch tracking, and voice tracking
 * Manages session lifecycle and data storage
 */

import { useState, useCallback, useRef, useEffect } from 'react';
import { db } from '../services/db';
import { eyeTracker } from '../tracking/eyeTracking';
import { touchTracker } from '../tracking/touchTracking';
import { voiceTracker } from '../tracking/voiceTracking';
import { useFaceDetection } from './useFaceDetection';
import CorrelationEngine from '../tracking/correlationEngine';
import { enhancedReportGenerator } from '../assessment/enhancedReportGenerator';
import { historicalDataService } from '../services/historicalData';

export const useSession = (learnerId, focusArea) => {
  const [sessionId, setSessionId] = useState(null);
  const [isActive, setIsActive] = useState(false);
  const [sessionData, setSessionData] = useState(null);
  const [metrics, setMetrics] = useState({});

  const sessionStartTime = useRef(null);
  const metricsIntervalRef = useRef(null);
  const videoRef = useRef(null);
  const correlationEngineRef = useRef(null);
  const lastFaceEmotionRef = useRef(null);

  const faceDetection = useFaceDetection();

  /**
   * Start a new session
   */
  const startSession = useCallback(async (config = {}) => {
    const {
      focusAreas = ['social-skills'],
      avatarMode = 'animal',
      avatarName = 'Friendly Bear'
    } = config;

    try {
      // Create session ID
      const newSessionId = crypto.randomUUID();
      sessionStartTime.current = Date.now();

      setSessionId(newSessionId);
      setIsActive(true);

      // Initialize session data
      const initialData = {
        id: newSessionId,
        learnerId,
        startTime: sessionStartTime.current,
        endTime: null,
        duration: 0,
        focusArea: focusAreas[0],
        avatarMode,
        avatarName,
        tasksCompleted: 0,
        tasksTotal: 0,
        activitiesLog: [],
        moodChecks: [],
        deviceInfo: {
          platform: navigator.platform,
          browserAgent: navigator.userAgent,
          screenSize: `${window.screen.width}x${window.screen.height}`
        },
        syncedToCloud: false
      };

      setSessionData(initialData);

      // Initialize correlation engine
      if (!correlationEngineRef.current) {
        correlationEngineRef.current = new CorrelationEngine({
          correlationWindow: 500, // 500ms window for correlating events
          enableRealTimeAnalysis: true
        });
      }
      correlationEngineRef.current.startSession();

      // Start tracking systems
      await startTracking();

      // Start metrics collection interval (every 5 seconds)
      metricsIntervalRef.current = setInterval(() => {
        collectMetrics();
      }, 5000);

      console.log('[Session] Started:', newSessionId);

      return newSessionId;
    } catch (error) {
      console.error('[Session] Start failed:', error);
      throw error;
    }
  }, [learnerId]);

  /**
   * Start all tracking systems
   */
  const startTracking = async () => {
    try {
      // Request webcam for face detection and eye tracking
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: 'user', width: 640, height: 480 },
        audio: false
      });

      if (!videoRef.current) {
        videoRef.current = document.createElement('video');
        videoRef.current.autoplay = true;
        videoRef.current.playsInline = true;
        videoRef.current.muted = true;
      }

      videoRef.current.srcObject = stream;
      await videoRef.current.play();

      // Start face detection (micro-expressions)
      if (faceDetection.isSupported) {
        faceDetection.startDetection(videoRef.current);
      }

      // Register correlation callbacks
      const correlationEngine = correlationEngineRef.current;
      if (correlationEngine) {
        // Register event callbacks for all tracking systems
        eyeTracker.onEvent((source, type, data) => {
          correlationEngine.addEvent(source, type, data);
        });

        touchTracker.onEvent((source, type, data) => {
          correlationEngine.addEvent(source, type, data);
        });

        voiceTracker.onEvent((source, type, data) => {
          correlationEngine.addEvent(source, type, data);
        });
      }

      // Start eye tracking
      await eyeTracker.init(videoRef.current);
      eyeTracker.start();

      // Start touch tracking
      touchTracker.start();

      // Start voice tracking
      const voiceInitialized = await voiceTracker.init();
      if (voiceInitialized) {
        voiceTracker.start();
      }

      console.log('[Session] All tracking systems started');
    } catch (error) {
      console.error('[Session] Tracking start failed:', error);
    }
  };

  /**
   * Collect metrics from all tracking systems
   */
  const collectMetrics = useCallback(() => {
    const currentMetrics = {
      eyeTracking: eyeTracker.getMetrics(),
      microExpressions: {
        faceDetected: faceDetection.faceDetected,
        faceConfidence: faceDetection.faceConfidence,
        engagementScore: faceDetection.engagementScore,
        // In production, add full emotion recognition here
      },
      touchTracking: touchTracker.getMetrics(),
      voiceTracking: voiceTracker.getMetrics()
    };

    // Emit face detection events to correlation engine
    if (correlationEngineRef.current) {
      // Simulate emotion detection from engagement score
      // In production, this would come from actual emotion recognition
      let emotion = 'neutral';
      let emotionConfidence = faceDetection.faceConfidence;

      if (faceDetection.engagementScore > 0.7) {
        emotion = 'happy';
      } else if (faceDetection.engagementScore < 0.3) {
        emotion = 'frustration';
      }

      // Only emit if emotion changed
      if (lastFaceEmotionRef.current !== emotion) {
        correlationEngineRef.current.addEvent('face', 'emotion', {
          emotion,
          confidence: emotionConfidence
        });
        lastFaceEmotionRef.current = emotion;
      }
    }

    setMetrics(currentMetrics);
  }, [faceDetection]);

  /**
   * End the current session
   */
  const endSession = useCallback(async () => {
    if (!isActive || !sessionId) return null;

    try {
      const endTime = Date.now();
      const duration = (endTime - sessionStartTime.current) / 1000; // seconds

      // Stop all tracking
      eyeTracker.stop(); // This calls calculateFinalMetrics() which averages attention scores
      touchTracker.stop();
      voiceTracker.stop();
      faceDetection.stopDetection();

      // Stop metrics collection
      if (metricsIntervalRef.current) {
        clearInterval(metricsIntervalRef.current);
      }

      // Stop webcam
      if (videoRef.current && videoRef.current.srcObject) {
        videoRef.current.srcObject.getTracks().forEach(track => track.stop());
      }

      // Collect correlation data
      const correlationData = correlationEngineRef.current
        ? correlationEngineRef.current.exportSessionData()
        : null;

      // Collect final metrics AFTER stop() has calculated final averaged attention score
      // Important: getMetrics() must be called after stop() to get the averaged final score
      // This averaged score is what will be displayed in session summary and saved to database
      const eyeTrackingData = eyeTracker.getSessionData();
      const eyeTrackingMetrics = eyeTracker.getMetrics();
      const attentionScore = eyeTrackingMetrics.attentionScore || 0; // FINAL AVERAGED SCORE
      
      // DEBUG: Verify final averaged attention score
      console.log('[useSession] 📊 FINAL AVERAGED attention score retrieved (for summary & reports):', {
        attentionScore,
        hasHistory: eyeTracker.attentionScoreHistory?.length > 0,
        historyLength: eyeTracker.attentionScoreHistory?.length || 0,
        source: 'eyeTracker.getMetrics().attentionScore (averaged from all session scores)',
        note: 'This averaged score will be displayed in session summary and saved to database for reports',
      });
      
      // DEBUG: Log attention score when ending session
      console.log('[useSession] 🛑 Ending session - attention score:', {
        attentionScore,
        eyeTrackingMetrics,
        eyeTrackingData,
        timestamp: new Date().toISOString(),
      });
      
      if (attentionScore === 0) {
        console.error('[useSession] ❌ WARNING: Attention score is 0 when ending session!', {
          eyeTrackingMetrics,
          eyeTrackingData,
          possibleIssues: {
            noMetrics: !eyeTrackingMetrics,
            noAttentionScore: eyeTrackingMetrics.attentionScore === undefined || eyeTrackingMetrics.attentionScore === null,
            eyeTrackerState: {
              isActive: eyeTracker.isActive,
              gazePointsCount: eyeTracker.gazePoints?.length || 0,
              fixationsCount: eyeTracker.fixations?.length || 0,
              screenDimensions: eyeTracker.screenDimensions,
            },
          },
        });
      }
      
      const finalMetrics = {
        eyeTracking: {
          ...eyeTrackingData,
          // Ensure attentionScore is available at the top level (this is the FINAL AVERAGED score)
          // This comes from calculateFinalMetrics() which averages all attention scores during the session
          attentionScore: attentionScore,
          attention_score: attentionScore, // Also include snake_case for compatibility
          metrics: {
            ...eyeTrackingMetrics, // Include all metrics
            // Ensure attentionScore is also in metrics for fallback access
            attentionScore: attentionScore,
          },
        },
        microExpressions: {
          faceDetected: faceDetection.faceDetected,
          faceConfidence: faceDetection.faceConfidence,
          engagementScore: faceDetection.engagementScore,
          stats: faceDetection.stats
        },
        touchTracking: touchTracker.getSessionData(),
        voiceTracking: voiceTracker.getSessionData(),
        correlations: correlationData
      };

      // Calculate engagement quality (0-10)
      const engagementQuality = calculateEngagementQuality(finalMetrics);

      // Complete session data
      // IMPORTANT: Merge finalMetrics properly to ensure attentionScore is accessible
      const completedSession = {
        ...sessionData,
        endTime,
        duration,
        // Merge metrics properly - finalMetrics has eyeTracking at top level
        metrics: {
          ...(sessionData.metrics || {}),
          // Overwrite with finalMetrics which has the FINAL AVERAGED attention score
          eyeTracking: finalMetrics.eyeTracking, // This contains the FINAL AVERAGED attentionScore
          microExpressions: finalMetrics.microExpressions,
          touchTracking: finalMetrics.touchTracking,
          voiceTracking: finalMetrics.voiceTracking,
          correlations: finalMetrics.correlations,
        },
        engagementQuality,
        updatedAt: Date.now()
      };
      
      // DEBUG: Verify attention score is in completedSession
      console.log('[useSession] ✅ Completed session structure:', {
        hasMetrics: !!completedSession.metrics,
        hasEyeTracking: !!completedSession.metrics?.eyeTracking,
        attentionScore: completedSession.metrics?.eyeTracking?.attentionScore,
        attentionScoreInMetrics: completedSession.metrics?.eyeTracking?.metrics?.attentionScore,
        structure: {
          'metrics.eyeTracking.attentionScore': completedSession.metrics?.eyeTracking?.attentionScore,
          'metrics.eyeTracking.metrics.attentionScore': completedSession.metrics?.eyeTracking?.metrics?.attentionScore,
        },
      });

      // Generate subdomain assessment report
      let conciseReport = null;
      try {
        // Get learner profile
        const learnerProfile = await db.get('learners', learnerId);

        if (learnerProfile) {
          // Generate concise daily report
          conciseReport = await enhancedReportGenerator.generateConciseReport(
            completedSession,
            learnerProfile
          );

          // Save report to session
          completedSession.conciseReport = conciseReport;

          console.log('[Session] Generated concise report');
        }
      } catch (reportError) {
        console.error('[Session] Report generation failed:', reportError);
      }

      // Save to IndexedDB
      await db.update('sessions', completedSession);

      setIsActive(false);
      setSessionData(completedSession);

      console.log('[Session] Ended:', sessionId);

      return completedSession;
    } catch (error) {
      console.error('[Session] End failed:', error);
      throw error;
    }
  }, [isActive, sessionId, sessionData, faceDetection]);

  /**
   * Calculate overall engagement quality score (0-10)
   * Uses calibrated eye tracking metrics for accurate calculation
   */
  const calculateEngagementQuality = (metrics) => {
    // Eye tracking: attention score (0-100) -> (0-10)
    const eyeScore = (metrics.eyeTracking?.attentionScore || 
                     metrics.eyeTracking?.metrics?.attentionScore || 0) / 10;
    
    // Face detection: engagement score (0-1) -> (0-10)
    const faceScore = (metrics.microExpressions?.engagementScore || 0) * 10;
    
    // Touch tracking: goal-directed accuracy (0-1) -> (0-10)
    const touchScore = (metrics.touchTracking?.goalDirectedAccuracy || 0) * 10;
    
    // Voice tracking: confidence (0-1) -> (0-10)
    const voiceScore = (metrics.voiceTracking?.confidence || 0) * 10;

    // Weighted average: Eye tracking and face detection are primary indicators
    const quality = (
      eyeScore * 0.35 +      // Eye tracking (calibrated) - most important
      faceScore * 0.35 +     // Face detection - engagement indicator
      touchScore * 0.15 +    // Touch accuracy - task engagement
      voiceScore * 0.15      // Voice confidence - participation
    );

    return Math.min(10, Math.max(0, Math.round(quality * 10) / 10));
  };

  /**
   * Add mood check
   */
  const addMoodCheck = useCallback((mood, emoji) => {
    if (!sessionData) return;

    const moodCheck = {
      timestamp: Date.now() - sessionStartTime.current,
      mood,
      emoji
    };

    const updatedData = {
      ...sessionData,
      moodChecks: [...sessionData.moodChecks, moodCheck]
    };

    setSessionData(updatedData);
  }, [sessionData]);

  /**
   * Log activity
   */
  const logActivity = useCallback((activity) => {
    if (!sessionData) return;

    const updatedData = {
      ...sessionData,
      activitiesLog: [...sessionData.activitiesLog, activity]
    };

    setSessionData(updatedData);
  }, [sessionData]);

  /**
   * Set ROI for eye tracking (e.g., avatar position)
   */
  const setTrackingROI = useCallback((name, x, y, width, height) => {
    eyeTracker.setROI(name, x, y, width, height);
  }, []);

  /**
   * Register touch target
   */
  const registerTouchTarget = useCallback((id, element) => {
    touchTracker.registerTarget(id, element);
  }, []);

  /**
   * Record response event (for correlation with other tracking data)
   */
  const recordResponse = useCallback((type, data) => {
    if (correlationEngineRef.current) {
      correlationEngineRef.current.addEvent('response', type, data);
    }
  }, []);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (isActive) {
        endSession();
      }
    };
  }, []);

  return {
    sessionId,
    isActive,
    sessionData,
    metrics,
    startSession,
    endSession,
    addMoodCheck,
    logActivity,
    setTrackingROI,
    registerTouchTarget,
    recordResponse,
    videoElement: videoRef.current
  };
};
