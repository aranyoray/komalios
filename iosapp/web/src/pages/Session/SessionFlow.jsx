/**
 * Session Flow Page
 *
 * Complete 15-minute session with:
 * 1. Face detection setup
 * 2. Eye calibration
 * 3. Pre-task emoji check-in
 * 4. Activity levels with storytelling
 * 5. Biomarker tracking throughout
 * 6. Post-task check-ins
 * 7. Report generation
 */

import React, { useState, useEffect, useCallback, useRef, useMemo } from 'react';
import {
  Box,
  Container,
  Typography,
  Button,
  LinearProgress,
  Paper,
  IconButton,
  Chip,
  Fade,
  Stepper,
  Step,
  StepLabel,
  Alert,
  useMediaQuery,
  useTheme,
} from '@mui/material';
import { useNavigate, useParams, useSearchParams } from 'react-router-dom';
import CloseIcon from '@mui/icons-material/Close';
import TimerIcon from '@mui/icons-material/Timer';
import FaceIcon from '@mui/icons-material/Face';
import VisibilityIcon from '@mui/icons-material/Visibility';
import MicIcon from '@mui/icons-material/Mic';

// Components
import EyeCalibration from '../../components/tracking/EyeCalibration';
import FaceDetectionSetup from '../../components/tracking/FaceDetectionSetup';
import EmojiCheckIn, { EmojiCheckInSequence } from '../../components/tracking/EmojiCheckIn';
import Avatar from '../../components/avatar/Avatar';
import Animoji3D from '../../components/Avatar/Animoji3D';

// TTS Service
import { speak, stopCurrentAudio } from '../../services/elevenLabsTTS';

// Hooks
import { useSession } from '../../hooks/useSession';
import { useSubdomainTracking } from '../../hooks/useSubdomainTracking';
import { useAuth } from '../../contexts/AuthContext';
import { useLanguage } from '../../i18n/LanguageContext';

// Services
import { analytics } from '../../services/analytics';
import { supabase } from '../../services/supabase';
import { showInterstitialAds } from '../../services/admobService';

// Assessment
import {
  measureEyeTrackingAlignment,
  measureVoiceLatency,
  trackEngagementArc,
} from '../../assessment/subdomainMeasurementTools';

/**
 * Session phases
 */
const PHASES = {
  CALIBRATION: 'calibration',
  FACE_SETUP: 'face_setup',
  PRE_CHECK_IN: 'pre_check_in',
  ACTIVITY: 'activity',
  POST_CHECK_IN: 'post_check_in',
  REPORT: 'report',
};

/**
 * Session steps for stepper - will be translated in component
 */
const SESSION_STEP_KEYS = [
  'setup',
  'checkIn',
  'activity',
  'review',
];

/**
 * Placeholder story activities
 */
const STORY_ACTIVITIES = [
  {
    id: 1,
    title: 'The Friendly Forest',
    description: 'Help the animals find their way home',
    duration: 180, // seconds
    subdomains: ['joint_attention', 'emotion_identification'],
    tasks: [
      { id: 'task1', prompt: 'Look at the squirrel hiding in the tree', type: 'gaze' },
      { id: 'task2', prompt: 'How does the lost bunny feel?', type: 'emotion' },
      { id: 'task3', prompt: 'Point to where the bunny should go', type: 'touch' },
    ],
  },
  {
    id: 2,
    title: 'Ocean Adventure',
    description: 'Discover the underwater world',
    duration: 180,
    subdomains: ['turn_taking', 'working_memory'],
    tasks: [
      { id: 'task1', prompt: 'Remember the fish sequence', type: 'memory' },
      { id: 'task2', prompt: 'Take turns with the dolphin', type: 'turn_taking' },
      { id: 'task3', prompt: 'Find the hidden treasure', type: 'attention' },
    ],
  },
  {
    id: 3,
    title: 'Space Explorer',
    description: 'Journey through the stars',
    duration: 180,
    subdomains: ['conversation_initiation', 'problem_solving'],
    tasks: [
      { id: 'task1', prompt: 'Ask the alien a question', type: 'speech' },
      { id: 'task2', prompt: 'Solve the puzzle to unlock the ship', type: 'problem' },
      { id: 'task3', prompt: 'Navigate through the asteroid field', type: 'attention' },
    ],
  },
];

/**
 * Main Session Flow Component
 */
export default function SessionFlow() {
  const navigate = useNavigate();
  const { learnerId } = useParams();
  const [searchParams] = useSearchParams();
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
  const { currentProfile, profiles } = useAuth();
  const { t } = useLanguage();

  // Get the learner profile
  const profile = useMemo(() => {
    return currentProfile || profiles?.find(p => p.id === learnerId);
  }, [currentProfile, profiles, learnerId]);

  // Get focus area from URL params, profile, or default
  // Priority: URL param > Profile's first focus area > 'social-skills'
  const selectedFocusArea = useMemo(() => {
    // 1. Check URL param (?focus=...)
    const urlFocus = searchParams.get('focus');
    if (urlFocus) {
      console.log('[SessionFlow] Using focus area from URL:', urlFocus);
      return urlFocus;
    }

    // 2. Check current profile's focus_areas (use first one as default)
    if (profile?.focus_areas && Array.isArray(profile.focus_areas) && profile.focus_areas.length > 0) {
      const firstFocusArea = profile.focus_areas[0];
      console.log('[SessionFlow] Using first focus area from profile as default:', firstFocusArea);
      return firstFocusArea;
    }

    // 3. Fallback to hardcoded default (only if no profile available)
    console.log('[SessionFlow] No profile found, using default focus area: social-skills');
    return 'social-skills';
  }, [searchParams, profile]);

  // Get all focus areas for the session (use profile's focus_areas or selected one)
  const profileFocusAreas = useMemo(() => {
    if (profile?.focus_areas && Array.isArray(profile.focus_areas) && profile.focus_areas.length > 0) {
      return profile.focus_areas;
    }
    return [selectedFocusArea];
  }, [profile, selectedFocusArea]);

  // Log focus area selection for debugging
  useEffect(() => {
    console.log('[SessionFlow] Focus area selection:', {
      urlFocus: searchParams.get('focus'),
      profileFocusAreas: profile?.focus_areas,
      selectedFocusArea,
      finalProfileFocusAreas: profileFocusAreas,
      learnerId,
    });
  }, [searchParams, profile, selectedFocusArea, profileFocusAreas, learnerId]);

  // Session state
  const [currentPhase, setCurrentPhase] = useState(PHASES.FACE_SETUP);
  const [activeStep, setActiveStep] = useState(0);
  const [sessionTime, setSessionTime] = useState(0);
  const [isPaused, setIsPaused] = useState(false);

  // Activity state
  const [currentActivity, setCurrentActivity] = useState(0);
  const [currentTask, setCurrentTask] = useState(0);
  const [activityStartTime, setActivityStartTime] = useState(null);

  // Tracking state
  const [calibrationData, setCalibrationData] = useState(null);
  const [faceSetupData, setFaceSetupData] = useState(null);
  const [videoStream, setVideoStream] = useState(null);
  const [preCheckInResults, setPreCheckInResults] = useState([]);
  const [postCheckInResults, setPostCheckInResults] = useState([]);
  const [engagementSamples, setEngagementSamples] = useState([]);

  // Metrics display
  const [currentMetrics, setCurrentMetrics] = useState({
    attention: 0,
    engagement: 0,
    emotion: 'neutral',
  });

  // Refs
  const timerRef = useRef(null);
  const metricsRef = useRef(null);

  // Hooks - use the determined focus area
  const session = useSession(learnerId, selectedFocusArea);
  const subdomainTracking = useSubdomainTracking(learnerId);

  // Session duration (15 minutes)
  const SESSION_DURATION = 15 * 60; // seconds

  /**
   * Initialize session and subdomain tracking
   */
  useEffect(() => {
    subdomainTracking.initialize('6-10'); // Default age band
  }, []);

  /**
   * Session timer
   */
  useEffect(() => {
    if (currentPhase === PHASES.ACTIVITY && !isPaused) {
      timerRef.current = setInterval(() => {
        setSessionTime(prev => {
          if (prev >= SESSION_DURATION) {
            // Session complete
            setCurrentPhase(PHASES.POST_CHECK_IN);
            return prev;
          }
          return prev + 1;
        });
      }, 1000);

      return () => clearInterval(timerRef.current);
    }
  }, [currentPhase, isPaused]);

  /**
   * Collect metrics periodically during activity
   * TEMPORARILY DISABLED for Animoji development
   */
  useEffect(() => {
    // DISABLED: Skip metrics collection for now
    if (false && currentPhase === PHASES.ACTIVITY && session.isActive) {
      metricsRef.current = setInterval(() => {
        const metrics = session.metrics;

        // Get attention score from eye tracking (0-100)
        const attentionScore = metrics.eyeTracking?.attentionScore ||
          metrics.eyeTracking?.metrics?.attentionScore || 0;

        // DEBUG: Log attention score during session
        console.log('[SessionFlow] 📊 Attention score update:', {
          attentionScore,
          source: metrics.eyeTracking?.attentionScore ? 'eyeTracking.attentionScore' :
            metrics.eyeTracking?.metrics?.attentionScore ? 'eyeTracking.metrics.attentionScore' : 'default (0)',
          eyeTrackingMetrics: metrics.eyeTracking,
          timestamp: new Date().toISOString(),
        });

        // Get engagement score from micro expressions (0-1, convert to 0-100)
        const engagementScoreRaw = metrics.microExpressions?.engagementScore || 0;
        const engagementScore = engagementScoreRaw * 100; // Convert to 0-100 scale

        // Update display metrics
        setCurrentMetrics({
          attention: attentionScore,
          engagement: engagementScore,
          emotion: metrics.microExpressions?.emotion || 'neutral',
        });

        // Record engagement sample (use calculated engagement quality if available)
        // Otherwise use micro expressions engagement score
        const engagementQuality = session.sessionData?.engagementQuality || (engagementScoreRaw * 10);
        setEngagementSamples(prev => [
          ...prev,
          {
            timestamp: Date.now(),
            score: engagementQuality * 10, // Convert 0-10 to 0-100
            attentionScore: attentionScore, // Also track attention separately
          },
        ]);

        // Add measurements to subdomain tracking
        if (attentionScore > 0) {
          subdomainTracking.addMeasurement({
            tool: 'gaze_stability_score',
            subdomain: 'attention_control',
            score: attentionScore,
            rawData: metrics.eyeTracking,
            timestamp: Date.now(),
            confidence: 0.8,
          });
        }
      }, 5000);

      return () => clearInterval(metricsRef.current);
    }
  }, [currentPhase, session.isActive, session.metrics, session.sessionData]);

  /**
   * Handle face setup complete
   */
  const handleFaceSetupComplete = useCallback((data) => {
    console.log('[SessionFlow] ✅ Face detection setup complete:', data);
    setFaceSetupData(data);
    // Store video stream for eye calibration
    if (data.stream) {
      console.log('[SessionFlow] 📹 Storing video stream for eye calibration');
      setVideoStream(data.stream);
    }
    console.log('[SessionFlow] ➡️ Moving to Eye Calibration phase');
    setCurrentPhase(PHASES.CALIBRATION);
  }, []);

  /**
   * Handle calibration complete
   */
  const handleCalibrationComplete = useCallback(async (data) => {
    console.log('[SessionFlow] ✅ Eye calibration complete:', data);
    setCalibrationData(data);

    // TEMPORARILY DISABLED: Skip all eye tracking for Animoji development
    /*
    // Set screen dimensions in eye tracker for full-screen gaze tracking
    // Full screen (left, right, top, bottom) excluding header
    if (data.screenDimensions) {
      console.log('[SessionFlow] 📐 Setting screen dimensions for full-screen gaze tracking:', data.screenDimensions);
      const { eyeTracker } = await import('../../tracking/eyeTracking');
      eyeTracker.setScreenDimensions(
        data.screenDimensions.width,
        data.screenDimensions.height,
        data.screenDimensions.headerHeight || 0
      );
    } else {
      // Fallback: use current screen dimensions
      const headerHeight = 120; // Estimate header height
      const { eyeTracker } = await import('../../tracking/eyeTracking');
      eyeTracker.setScreenDimensions(window.innerWidth, window.innerHeight, headerHeight);
      console.log('[SessionFlow] 📐 Using estimated screen dimensions:', {
        width: window.innerWidth,
        height: window.innerHeight,
        headerHeight,
      });
    }
    */

    // TEMPORARILY DISABLED: Skip session tracking for Animoji development
    console.log('[SessionFlow] ⏸️ Session tracking DISABLED for development');

    console.log('[SessionFlow] ➡️ Moving to Pre-check-in phase');
    setCurrentPhase(PHASES.PRE_CHECK_IN);
    setActiveStep(1);
  }, [session, profileFocusAreas]);

  /**
   * Handle pre-check-in complete
   */
  const handlePreCheckInComplete = useCallback((results) => {
    console.log('[SessionFlow] ✅ Pre-check-in complete:', results);
    setPreCheckInResults(results);

    // Add to subdomain tracking
    results.forEach(result => {
      console.log('[SessionFlow] 📊 Adding measurement:', result);
      subdomainTracking.addMeasurement(result);
    });

    console.log('[SessionFlow] ➡️ Moving to Activity phase');
    setCurrentPhase(PHASES.ACTIVITY);
    setActiveStep(2);
    setActivityStartTime(Date.now());
    console.log('[SessionFlow] ⏱️ Activity start time:', new Date().toISOString());
  }, [subdomainTracking]);

  /**
   * Handle activity task complete
   */
  const handleTaskComplete = useCallback((taskResult) => {
    const activity = STORY_ACTIVITIES[currentActivity];
    const task = activity.tasks[currentTask];

    console.log('[SessionFlow] ✅ Task completed:', {
      activityId: activity.id,
      activityTitle: activity.title,
      taskId: task.id,
      taskPrompt: task.prompt,
      result: taskResult,
      progress: `Activity ${currentActivity + 1}/${STORY_ACTIVITIES.length}, Task ${currentTask + 1}/${activity.tasks.length}`
    });

    // Log activity
    session.logActivity({
      type: 'task_completed',
      activityId: activity.id,
      taskId: task.id,
      result: taskResult,
      timestamp: Date.now(),
    });

    // Record response for correlation
    session.recordResponse('task_complete', taskResult);

    // Move to next task or activity
    if (currentTask < activity.tasks.length - 1) {
      const nextTask = activity.tasks[currentTask + 1];
      console.log('[SessionFlow] ➡️ Moving to next task:', {
        taskId: nextTask.id,
        prompt: nextTask.prompt
      });
      setCurrentTask(currentTask + 1);
    } else if (currentActivity < STORY_ACTIVITIES.length - 1) {
      const nextActivity = STORY_ACTIVITIES[currentActivity + 1];
      console.log('[SessionFlow] ➡️ Activity complete! Moving to next activity:', {
        activityId: nextActivity.id,
        title: nextActivity.title
      });
      setCurrentActivity(currentActivity + 1);
      setCurrentTask(0);
    } else {
      // All activities complete
      console.log('[SessionFlow] 🎉 All activities complete!');
      console.log('[SessionFlow] ➡️ Moving to Post-check-in phase');
      setCurrentPhase(PHASES.POST_CHECK_IN);
      setActiveStep(3);
    }
  }, [currentActivity, currentTask, session]);

  /**
   * Save session results to database
   */
  const saveSessionToDatabase = useCallback(async (sessionData) => {
    try {
      console.log('[SessionFlow] 💾 Saving session to database...');

      if (!learnerId) {
        console.error('[SessionFlow] ❌ No learner ID available');
        return;
      }

      // Calculate metrics from session data
      // Ensure all values are integers for database
      const rawDuration = sessionData.duration || sessionTime;
      const durationSeconds = Math.round(Number(rawDuration)); // Round to integer seconds
      const durationMinutes = Math.round(durationSeconds / 60);

      // Calculate attention score from eye tracking metrics
      // IMPORTANT: Use the FINAL AVERAGED attention score from calculateFinalMetrics()
      // This is the averaged score from all attention scores collected during the session
      // Priority: eyeTracking.attentionScore (final averaged) > eyeTracking.metrics.attentionScore > currentMetrics
      const eyeTrackingAttention = sessionData.metrics?.eyeTracking?.attentionScore ||
        sessionData.metrics?.eyeTracking?.metrics?.attentionScore ||
        currentMetrics.attention;
      const attentionScore = Math.round(eyeTrackingAttention);

      // DEBUG: Log final averaged attention score being saved
      console.log('[SessionFlow] 💾 Saving FINAL AVERAGED attention score to database:', {
        attentionScore,
        source: sessionData.metrics?.eyeTracking?.attentionScore ? 'eyeTracking.attentionScore (FINAL AVERAGED)' :
          sessionData.metrics?.eyeTracking?.metrics?.attentionScore ? 'eyeTracking.metrics.attentionScore' :
            'currentMetrics.attention (fallback)',
        isAveraged: !!sessionData.metrics?.eyeTracking?.attentionScore, // Should be true - this is the averaged final score
        note: 'This is the averaged score from all attention scores during the session, calculated by calculateFinalMetrics()',
      });

      // Calculate engagement score from engagement quality (0-10 scale) or engagement samples
      // engagementQuality is 0-10, convert to 0-100 for database
      let engagementScore = 0;
      if (sessionData.engagementQuality !== undefined && sessionData.engagementQuality !== null) {
        engagementScore = Math.round(sessionData.engagementQuality * 10);
      } else if (engagementSamples.length > 0) {
        // Use average of engagement samples (already in 0-100 scale)
        // Safety check: prevent division by zero
        const totalScore = engagementSamples.reduce((sum, s) => sum + (s.score || 0), 0);
        engagementScore = Math.round(totalScore / engagementSamples.length);
      } else {
        // Fallback to current metrics (already in 0-100 scale)
        engagementScore = Math.round(currentMetrics.engagement);
      }
      const completionRate = Math.round(
        ((currentActivity + 1) / STORY_ACTIVITIES.length) * 100
      );

      // Prepare session analytics data
      const analyticsData = {
        learner_id: learnerId,
        session_date: new Date().toISOString(),
        duration_minutes: durationMinutes,
        attention_score: attentionScore,
        engagement_score: engagementScore,
        completion_rate: completionRate,
        blink_rate: sessionData.metrics?.eyeTracking?.blinkRate || null,
        emotion_data: sessionData.metrics?.microExpressions?.emotionData || {},
        emotion_timeline: sessionData.metrics?.microExpressions?.emotionTimeline || [],
        gaze_heatmap: sessionData.metrics?.eyeTracking?.gazeHeatmap || [],
        gaze_metrics: {
          ...(sessionData.metrics?.eyeTracking?.gazeMetrics || {}),
          // Include attention score in gaze_metrics for reports
          attentionScore: attentionScore,
          socialGazeIndex: sessionData.metrics?.eyeTracking?.metrics?.socialGazeIndex ||
            sessionData.metrics?.eyeTracking?.socialGazeIndex || 0,
          concentrationStability: sessionData.metrics?.eyeTracking?.metrics?.concentrationStability ||
            sessionData.metrics?.eyeTracking?.concentrationStability || 0,
          totalFixations: sessionData.metrics?.eyeTracking?.metrics?.totalFixations ||
            sessionData.metrics?.eyeTracking?.totalFixations || 0,
          avgFixationDuration: sessionData.metrics?.eyeTracking?.metrics?.avgFixationDuration ||
            sessionData.metrics?.eyeTracking?.avgFixationDuration || 0,
        },
        activities_completed: currentActivity + 1,
        focus_areas: sessionData.focusAreas || profileFocusAreas,
        difficulty_level: 'adaptive',
        responses: sessionData.responses || [],
        biomarker_summary: {
          eyeTracking: sessionData.metrics?.eyeTracking || {},
          facialExpression: sessionData.metrics?.microExpressions || {},
          gestureTouch: sessionData.metrics?.touchTracking || {},
          responsePattern: sessionData.metrics?.correlations || {},
        },
        clinical_flags: [],
      };

      // Save full session to sessions table first
      const sessionRecord = {
        learner_id: learnerId,
        start_time: new Date(sessionData.startTime || Date.now() - (sessionTime * 1000)).toISOString(),
        end_time: new Date().toISOString(),
        duration: durationSeconds, // Use rounded integer value
        focus_area: sessionData.focusAreas?.[0] || selectedFocusArea,
        avatar_mode: sessionData.avatarMode || 'animal',
        avatar_name: sessionData.avatarName || 'Komal',
        tasks_completed: currentActivity + 1,
        tasks_total: STORY_ACTIVITIES.length,
        activities_log: STORY_ACTIVITIES.slice(0, currentActivity + 1).map((activity, idx) => ({
          activityId: activity.id,
          title: activity.title,
          completed: idx <= currentActivity,
          timestamp: Date.now(),
        })),
        eye_tracking: {
          ...(sessionData.metrics?.eyeTracking || {}),
          // Ensure fixations and saccades arrays are included
          fixations: sessionData.metrics?.eyeTracking?.fixations || [],
          saccades: sessionData.metrics?.eyeTracking?.saccades || [],
          advancedFixations: sessionData.metrics?.eyeTracking?.advancedFixations || [],
          advancedSaccades: sessionData.metrics?.eyeTracking?.advancedSaccades || [],
          calibrationStatus: sessionData.metrics?.eyeTracking?.calibrationStatus || {},
          // Ensure FINAL AVERAGED attention score is included in eye_tracking for reports
          // This is the averaged score from all attention scores during the session (from calculateFinalMetrics)
          attentionScore: attentionScore, // FINAL AVERAGED SCORE - used in reports
          attention_score: attentionScore, // Also include snake_case for compatibility (FINAL AVERAGED SCORE)
          metrics: {
            ...(sessionData.metrics?.eyeTracking?.metrics || {}),
            attentionScore: attentionScore, // FINAL AVERAGED SCORE
          },
        },
        micro_expressions: sessionData.metrics?.microExpressions || {},
        touch_tracking: sessionData.metrics?.touchTracking || {},
        voice_tracking: sessionData.metrics?.voiceTracking || {},
        response_patterns: sessionData.responses || {},
        engagement_quality: sessionData.engagementQuality || engagementScore / 10,
        mood_checks: [
          ...preCheckInResults.map(r => ({
            type: r.type,
            emoji: r.rawData?.emoji,
            timestamp: Date.now() - (sessionTime * 1000),
          })),
          ...postCheckInResults.map(r => ({
            type: r.type,
            emoji: r.rawData?.emoji,
            timestamp: Date.now(),
          })),
        ],
        concise_report: sessionData.conciseReport || null,
        extended_report: sessionData.extendedReport || null,
      };

      const { data: savedSession, error: sessionError } = await supabase
        .from('sessions')
        .insert(sessionRecord)
        .select()
        .single();

      if (sessionError) {
        console.error('[SessionFlow] ❌ Failed to save session:', sessionError);
        throw sessionError;
      }

      console.log('[SessionFlow] ✅ Session saved to database:', savedSession.id);

      // Link session_analytics to the session
      analyticsData.session_id = savedSession.id;

      // Save to session_analytics table
      await analytics.saveSessionMetrics(learnerId, analyticsData);
      console.log('[SessionFlow] ✅ Session analytics saved');

      return savedSession;
    } catch (error) {
      console.error('[SessionFlow] ❌ Error saving session to database:', error);
      // Don't throw - allow session to complete even if save fails
      return null;
    }
  }, [learnerId, sessionTime, currentActivity, engagementSamples, currentMetrics, preCheckInResults, postCheckInResults]);

  /**
   * Handle post-check-in complete
   */
  const handlePostCheckInComplete = useCallback(async (results) => {
    console.log('[SessionFlow] ✅ Post-check-in complete:', results);
    setPostCheckInResults(results);

    // Add to subdomain tracking
    results.forEach(result => {
      console.log('[SessionFlow] 📊 Adding measurement:', result);
      subdomainTracking.addMeasurement(result);
    });

    // Complete session assessments
    // TEMPORARILY DISABLED for Animoji development
    console.log('[SessionFlow] ⏸️ Session assessments DISABLED for development');
    // await subdomainTracking.completeSessionAssessments();

    // End session and generate report
    // TEMPORARILY DISABLED for Animoji development  
    console.log('[SessionFlow] ⏸️ Session end DISABLED for development');
    // const completedSession = await session.endSession();
    const completedSession = null;

    // DEBUG: Verify final averaged attention score is in session data
    /*
    if (completedSession) {
      const finalAttentionScore = completedSession.metrics?.eyeTracking?.attentionScore ||
        completedSession.metrics?.eyeTracking?.metrics?.attentionScore;
      console.log('[SessionFlow] 📊 Final averaged attention score in session data:', {
        attentionScore: finalAttentionScore,
        source: completedSession.metrics?.eyeTracking?.attentionScore ? 'eyeTracking.attentionScore' :
          completedSession.metrics?.eyeTracking?.metrics?.attentionScore ? 'eyeTracking.metrics.attentionScore' :
            'not found',
        willBeDisplayed: !!finalAttentionScore,
        willBeSaved: !!finalAttentionScore,
      });
    }
    */

    // Save session results to database
    // TEMPORARILY DISABLED
    /*
    if (completedSession) {
      await saveSessionToDatabase(completedSession);
    }
    */

    console.log('[SessionFlow] ➡️ Moving to Report phase');
    setCurrentPhase(PHASES.REPORT);
  }, [session, subdomainTracking, saveSessionToDatabase]);

  /**
   * Handle session end/exit
   */
  const handleExit = useCallback(() => {
    // TEMPORARILY DISABLED
    // if (session.isActive) {
    //   session.endSession();
    // }
    navigate('/learner');
  }, [navigate]);

  /**
   * Handle Done button click - show interstitial ad then navigate
   */
  const handleDone = useCallback(async () => {
    try {
      // Show interstitial ad (only on native platforms)
      await showInterstitialAds();
    } catch (error) {
      console.error('[SessionFlow] Error showing interstitial ad:', error);
      // Continue navigation even if ad fails
    } finally {
      // Navigate to learner home after ad (or if ad failed)
      navigate('/learner');
    }
  }, [navigate]);

  /**
   * Handle View Full Report button click - show interstitial ad then navigate
   */
  const handleViewFullReport = useCallback(async () => {
    try {
      // Show interstitial ad (only on native platforms)
      await showInterstitialAds();
    } catch (error) {
      console.error('[SessionFlow] Error showing interstitial ad:', error);
      // Continue navigation even if ad fails
    } finally {
      // Navigate to parent dashboard after ad (or if ad failed)
      navigate('/parent/dashboard');
    }
  }, [navigate]);

  /**
   * Format time display
   */
  const formatTime = (seconds) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  /**
   * Log phase changes
   */
  useEffect(() => {
    console.log('[SessionFlow] 🔄 Current phase:', currentPhase);
    console.log('[SessionFlow] 📍 Active step:', activeStep, '/', SESSION_STEP_KEYS.length - 1);
  }, [currentPhase, activeStep]);

  /**
   * Render current phase content
   */
  const renderPhaseContent = () => {
    switch (currentPhase) {
      case PHASES.FACE_SETUP:
        return (
          <FaceDetectionSetup
            onComplete={handleFaceSetupComplete}
            onSkip={handleFaceSetupComplete}
          />
        );

      case PHASES.CALIBRATION:
        return (
          <EyeCalibration
            onComplete={handleCalibrationComplete}
            onSkip={handleCalibrationComplete}
            pointDuration={3000}
            videoStream={videoStream}
          />
        );

      case PHASES.PRE_CHECK_IN:
        return (
          <Box sx={{ maxWidth: 600, mx: 'auto', py: 4 }}>
            <Typography variant="h5" gutterBottom textAlign="center">
              {t.session.flow.preCheckIn.title}
            </Typography>
            <EmojiCheckInSequence
              checkIns={['feeling_pre_task', 'motivation_check']}
              onComplete={handlePreCheckInComplete}
              ageBand="6-10"
            />
          </Box>
        );

      case PHASES.ACTIVITY:
        return renderActivityContent();

      case PHASES.POST_CHECK_IN:
        return (
          <Box sx={{ maxWidth: 600, mx: 'auto', py: 4 }}>
            <Typography variant="h5" gutterBottom textAlign="center">
              {t.session.flow.postCheckIn.title}
            </Typography>
            <EmojiCheckInSequence
              checkIns={['difficulty_post_task', 'feeling_pre_task', 'understanding_check']}
              onComplete={handlePostCheckInComplete}
              ageBand="6-10"
            />
          </Box>
        );

      case PHASES.REPORT:
        return renderReportContent();

      default:
        return null;
    }
  };

  /**
   * Log activity changes
   */
  useEffect(() => {
    if (currentPhase === PHASES.ACTIVITY) {
      const activity = STORY_ACTIVITIES[currentActivity];
      const task = activity.tasks[currentTask];
      console.log('[SessionFlow] 🎮 Activity started:', {
        activityId: activity.id,
        title: activity.title,
        description: activity.description,
        totalTasks: activity.tasks.length,
        currentTask: currentTask + 1,
        taskId: task.id,
        taskPrompt: task.prompt,
        taskType: task.type
      });
    }
  }, [currentPhase, currentActivity, currentTask]);

  // State for animoji talking
  const [isAnimojiTalking, setIsAnimojiTalking] = useState(false);
  const [currentMessage, setCurrentMessage] = useState('');
  const [messageIndex, setMessageIndex] = useState(0);

  // Riki's conversation messages
  const komalMessages = useMemo(() => [
    "Hi there! I'm Riki the Raccoon, your friendly buddy! I'm so happy to see you today!",
    "Let's have some fun together! I love learning about feelings and making new friends.",
    "You're doing amazing! Take your time - I'll be right here with you.",
    "I really like hanging out with you! You make my whiskers wiggle with joy!",
  ], []);

  // Function to make Komal speak
  const makeKomalSpeak = useCallback(async (message) => {
    setCurrentMessage(message);
    setIsAnimojiTalking(true);
    
    try {
      await speak(message, {
        onStart: () => setIsAnimojiTalking(true),
        onEnd: () => setIsAnimojiTalking(false),
      });
    } catch (error) {
      console.error('[SessionFlow] TTS error:', error);
      // Fallback: simulate talking duration based on message length
      const duration = Math.max(2000, message.length * 50);
      setTimeout(() => setIsAnimojiTalking(false), duration);
    }
  }, []);

  // Auto-speak when entering activity phase
  useEffect(() => {
    if (currentPhase === PHASES.ACTIVITY) {
      const timer = setTimeout(() => {
        makeKomalSpeak(komalMessages[0]);
      }, 500);
      return () => clearTimeout(timer);
    }
  }, [currentPhase, makeKomalSpeak, komalMessages]);

  // Handle next message
  const handleNextMessage = useCallback(() => {
    const nextIndex = (messageIndex + 1) % komalMessages.length;
    setMessageIndex(nextIndex);
    makeKomalSpeak(komalMessages[nextIndex]);
  }, [messageIndex, komalMessages, makeKomalSpeak]);

  // Cleanup audio on unmount
  useEffect(() => {
    return () => {
      stopCurrentAudio();
    };
  }, []);

  /**
   * Render activity/storytelling content - Now featuring 3D Animoji Komal!
   */
  const renderActivityContent = () => {
    return (
      <Fade in key="animoji-activity">
        <Box sx={{ 
          py: { xs: 2, sm: 3 },
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          minHeight: '60vh',
          justifyContent: 'center',
        }}>
          {/* Riki's name */}
          <Typography 
            variant="h5" 
            sx={{ 
              fontWeight: 700, 
              fontSize: { xs: '1.4rem', sm: '1.6rem' }, 
              color: '#2E7D32',
              mb: 2,
              textShadow: '0 2px 4px rgba(46, 125, 50, 0.1)',
            }}
          >
            🦝 Riki the Raccoon
          </Typography>

          {/* 3D Animoji Avatar */}
          <Box sx={{ 
            display: 'flex', 
            justifyContent: 'center', 
            mb: 3,
            filter: isAnimojiTalking ? 'drop-shadow(0 0 24px rgba(76, 175, 80, 0.5))' : 'none',
            transition: 'filter 0.3s ease',
          }}>
            <Animoji3D
              isTalking={isAnimojiTalking}
              emotion={currentMetrics.emotion || 'neutral'}
              size={isMobile ? 220 : 280}
            />
          </Box>

          {/* Speech bubble with current message */}
          {currentMessage && (
            <Paper
              elevation={3}
              sx={{
                p: { xs: 2.5, sm: 3 },
                maxWidth: 400,
                mx: 'auto',
                textAlign: 'center',
                borderRadius: 4,
                background: 'linear-gradient(135deg, #E8F5E9 0%, #C8E6C9 100%)',
                border: '2px solid #81C784',
                position: 'relative',
                '&::before': {
                  content: '""',
                  position: 'absolute',
                  top: -12,
                  left: '50%',
                  transform: 'translateX(-50%)',
                  width: 0,
                  height: 0,
                  borderLeft: '12px solid transparent',
                  borderRight: '12px solid transparent',
                  borderBottom: '12px solid #81C784',
                },
                '&::after': {
                  content: '""',
                  position: 'absolute',
                  top: -9,
                  left: '50%',
                  transform: 'translateX(-50%)',
                  width: 0,
                  height: 0,
                  borderLeft: '10px solid transparent',
                  borderRight: '10px solid transparent',
                  borderBottom: '10px solid #E8F5E9',
                },
              }}
            >
              <Typography 
                variant="body1" 
                sx={{ 
                  fontSize: { xs: '1rem', sm: '1.1rem' }, 
                  color: '#1B5E20',
                  fontWeight: 500,
                  lineHeight: 1.6,
                }}
              >
                {currentMessage}
              </Typography>
            </Paper>
          )}

          {/* Action buttons */}
          <Box sx={{ mt: 4, display: 'flex', gap: 2, flexWrap: 'wrap', justifyContent: 'center' }}>
            <Button
              variant="contained"
              size="large"
              onClick={handleNextMessage}
              disabled={isAnimojiTalking}
              sx={{ 
                px: 4,
                py: 1.5,
                borderRadius: 3,
                background: 'linear-gradient(135deg, #66BB6A 0%, #43A047 100%)',
                '&:hover': {
                  background: 'linear-gradient(135deg, #4CAF50 0%, #2E7D32 100%)',
                },
                '&:disabled': {
                  background: 'linear-gradient(135deg, #A5D6A7 0%, #81C784 100%)',
                  color: '#fff',
                },
              }}
            >
              {isAnimojiTalking ? 'Riki is talking...' : 'Talk to me!'}
            </Button>
            
            <Button
              variant="outlined"
              size="large"
              onClick={() => handleTaskComplete({ success: true, score: 100 })}
              sx={{ 
                px: 4,
                py: 1.5,
                borderRadius: 3,
                borderColor: '#43A047',
                color: '#2E7D32',
                '&:hover': {
                  borderColor: '#2E7D32',
                  backgroundColor: 'rgba(76, 175, 80, 0.08)',
                },
              }}
            >
              Continue
            </Button>
          </Box>
        </Box>
      </Fade>
    );
  };

  /**
   * Render session report
   */
  const renderReportContent = () => {
    const sessionData = session.sessionData;

    return (
      <Fade in>
        <Box sx={{ py: 4, maxWidth: 600, mx: 'auto' }}>
          <Typography variant="h4" gutterBottom textAlign="center" sx={{ fontWeight: 600 }}>
            {t.session.flow.report.sessionComplete}
          </Typography>

          {/* Summary stats */}
          <Paper sx={{ p: 3, mb: 3, borderRadius: 2 }}>
            <Typography variant="h6" gutterBottom>
              {t.session.flow.report.sessionSummary}
            </Typography>

            <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr 1fr', sm: 'repeat(2, 1fr)' }, gap: 2 }}>
              {/* Attention Score - FINAL AVERAGED SCORE */}
              <Box>
                <Typography variant="caption" sx={{ color: '#6B7280' }}>
                  {t.session.flow.report.attentionScore}
                  <Typography component="span" variant="caption" sx={{ ml: 0.5, fontSize: '0.65rem', opacity: 0.7 }}>
                    {t.session.flow.report.sessionAverage}
                  </Typography>
                </Typography>
                <Typography
                  variant="h4"
                  sx={{
                    color: (sessionData?.metrics?.eyeTracking?.attentionScore ||
                      sessionData?.metrics?.eyeTracking?.metrics?.attentionScore ||
                      currentMetrics.attention || 0) >= 70
                      ? 'success.main'
                      : (sessionData?.metrics?.eyeTracking?.attentionScore ||
                        sessionData?.metrics?.eyeTracking?.metrics?.attentionScore ||
                        currentMetrics.attention || 0) >= 50
                        ? 'warning.main'
                        : 'error.main',
                    fontWeight: 600
                  }}
                >
                  {sessionData?.metrics?.eyeTracking?.attentionScore ||
                    sessionData?.metrics?.eyeTracking?.metrics?.attentionScore ||
                    currentMetrics.attention || 0}%
                </Typography>
                {/* Debug info in development */}
                {process.env.NODE_ENV === 'development' && (
                  <Typography variant="caption" color="text.secondary" sx={{ fontSize: '0.7rem', mt: 0.5, display: 'block' }}>
                    {sessionData?.metrics?.eyeTracking?.attentionScore
                      ? '✓ Final Averaged Score'
                      : sessionData?.metrics?.eyeTracking?.metrics?.attentionScore
                        ? '✓ From Metrics'
                        : '⚠ Fallback'}
                  </Typography>
                )}
              </Box>

              <Box>
                <Typography variant="body2" sx={{ color: '#6B7280' }}>
                  {t.session.flow.report.duration}
                </Typography>
                <Typography variant="h6" sx={{ color: '#111827' }}>
                  {formatTime(sessionTime)}
                </Typography>
              </Box>

              <Box>
                <Typography variant="body2" sx={{ color: '#6B7280' }}>
                  {t.session.flow.report.activities}
                </Typography>
                <Typography variant="h6" sx={{ color: '#111827' }}>
                  {currentActivity + 1} / {STORY_ACTIVITIES.length}
                </Typography>
              </Box>

              <Box>
                <Typography variant="body2" sx={{ color: '#6B7280' }}>
                  {t.session.flow.report.engagement}
                </Typography>
                <Typography variant="h6" sx={{ color: '#111827' }}>
                  {sessionData?.engagementQuality?.toFixed(1) || '8.5'}/10
                </Typography>
              </Box>
            </Box>
          </Paper>

          {/* Mood comparison */}
          <Paper sx={{ p: 3, mb: 3, borderRadius: 2 }}>
            <Typography variant="h6" gutterBottom>
              {t.session.flow.report.moodCheck}
            </Typography>

            <Box sx={{ display: 'flex', justifyContent: 'space-around' }}>
              <Box textAlign="center">
                <Typography variant="body2" sx={{ color: '#6B7280' }}>
                  {t.session.flow.report.before}
                </Typography>
                <Typography variant="h4" sx={{ color: '#111827' }}>
                  {preCheckInResults[0]?.rawData?.emoji || '🙂'}
                </Typography>
              </Box>

              <Box textAlign="center">
                <Typography variant="body2" sx={{ color: '#6B7280' }}>
                  {t.session.flow.report.after}
                </Typography>
                <Typography variant="h4" sx={{ color: '#111827' }}>
                  {postCheckInResults[1]?.rawData?.emoji || '😊'}
                </Typography>
              </Box>
            </Box>
          </Paper>

          {/* AI-generated insights placeholder */}
          {sessionData?.conciseReport && (
            <Paper sx={{ p: 3, mb: 3, borderRadius: 2, bgcolor: 'primary.light' }}>
              <Typography variant="h6" gutterBottom>
                {t.session.flow.report.insights}
              </Typography>
              <Typography variant="body2">
                {sessionData.conciseReport.summary ||
                  'Great session! You showed strong attention during the storytelling activities and engaged well with the emotional recognition tasks.'}
              </Typography>
            </Paper>
          )}

          {/* Actions */}
          <Box sx={{ display: 'flex', gap: 2, justifyContent: 'center' }}>
            <Button
              variant="contained"
              size="large"
              onClick={handleViewFullReport}
            >
              {t.session.flow.report.viewFullReport}
            </Button>
            <Button
              variant="outlined"
              size="large"
              onClick={handleDone}
            >
              {t.session.flow.report.done}
            </Button>
          </Box>
        </Box>
      </Fade>
    );
  };

  return (
    <Box sx={{
      height: '100dvh', // Use dynamic viewport height for mobile
      minHeight: '-webkit-fill-available', // iOS Safari fallback
      bgcolor: '#FFFFFF',
      display: 'flex',
      flexDirection: 'column',
      overflow: 'hidden', // Prevent scrolling
      color: '#000000', // Default text color
    }}>
      {/* Header */}
      <Box
        sx={{
          flexShrink: 0, // Don't shrink the header
          zIndex: 100,
          bgcolor: '#FFFFFF',
          borderBottom: 1,
          borderColor: 'rgba(0,0,0,0.1)',
          px: 2,
          py: 1,
        }}
      >
        <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          {/* Close button */}
          <IconButton onClick={handleExit} size="small">
            <CloseIcon />
          </IconButton>

          {/* Timer */}
          {currentPhase === PHASES.ACTIVITY && (
            <Chip
              icon={<TimerIcon />}
              label={formatTime(sessionTime)}
              variant="outlined"
            />
          )}

          {/* Tracking indicators - hidden but still tracking underneath */}
          {session.isActive && false && (
            <Box sx={{ display: 'flex', gap: 1 }}>
              <Chip
                size="small"
                icon={<VisibilityIcon />}
                label={`${Math.round(currentMetrics.attention)}%`}
                color={currentMetrics.attention > 70 ? 'success' : 'warning'}
              />
              <Chip
                size="small"
                icon={<FaceIcon />}
                label={currentMetrics.emotion}
                color="primary"
              />
            </Box>
          )}
        </Box>

        {/* Progress stepper */}
        <Stepper activeStep={activeStep} alternativeLabel sx={{ mt: 1 }}>
          {SESSION_STEP_KEYS.map((key) => (
            <Step key={key}>
              <StepLabel>{t.session.flow.steps[key]}</StepLabel>
            </Step>
          ))}
        </Stepper>

        {/* Overall progress */}
        {currentPhase === PHASES.ACTIVITY && (
          <LinearProgress
            variant="determinate"
            value={(sessionTime / SESSION_DURATION) * 100}
            sx={{ mt: 1 }}
          />
        )}
      </Box>

      {/* Main content */}
      <Container
        maxWidth="md"
        sx={{
          flex: 1, // Fill remaining space
          display: 'flex',
          flexDirection: 'column',
          py: 2,
          overflow: 'hidden', // Prevent scrolling
        }}
      >
        {renderPhaseContent()}
      </Container>
    </Box>
  );
}
