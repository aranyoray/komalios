/**
 * Session Tracker Component
 * Real-time ML tracking during sessions
 */

import React, { useEffect, useRef, useState } from 'react';
import { Box, Typography, LinearProgress, Chip, Paper } from '@mui/material';
import { Visibility, Psychology, Timer } from '@mui/icons-material';
import { mlTracking } from '../../services/mlTracking';
import { useLanguage } from '../../i18n/LanguageContext';

const SessionTracker = ({ onMetricsUpdate, showOverlay = true }) => {
  const { t } = useLanguage();
  const videoRef = useRef(null);
  const [isTracking, setIsTracking] = useState(false);
  const [metrics, setMetrics] = useState({
    attention: 0,
    emotion: 'neutral',
    gazePoint: { x: 0.5, y: 0.5 },
    blinkCount: 0,
    sessionTime: 0,
  });
  const [error, setError] = useState(null);
  const startTimeRef = useRef(Date.now());

  useEffect(() => {
    initializeTracking();

    return () => {
      mlTracking.stop();
    };
  }, []);

  useEffect(() => {
    // Update session time every second
    const interval = setInterval(() => {
      const elapsed = Math.floor((Date.now() - startTimeRef.current) / 1000);
      setMetrics(prev => ({ ...prev, sessionTime: elapsed }));
    }, 1000);

    return () => clearInterval(interval);
  }, []);

  const initializeTracking = async () => {
    try {
      // Request camera permission
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { width: 640, height: 480, facingMode: 'user' },
      });

      if (videoRef.current) {
        videoRef.current.srcObject = stream;
        await videoRef.current.play();

        // Initialize ML tracking
        await mlTracking.initialize(videoRef.current, onResults);

        // Set up callbacks
        mlTracking.setCallback('onAttention', (score) => {
          setMetrics(prev => ({ ...prev, attention: Math.round(score) }));
        });

        mlTracking.setCallback('onFaceEmotion', (emotion) => {
          setMetrics(prev => ({ ...prev, emotion: emotion.emotion }));
        });

        mlTracking.setCallback('onEyeGaze', (gaze) => {
          setMetrics(prev => ({ ...prev, gazePoint: { x: gaze.x, y: gaze.y } }));
        });

        mlTracking.setCallback('onBlink', (count) => {
          setMetrics(prev => ({ ...prev, blinkCount: count }));
        });

        setIsTracking(true);
      }
    } catch (err) {
      console.error('Failed to initialize tracking:', err);
      setError(err.message);
    }
  };

  const onResults = (results) => {
    // Get aggregated metrics
    const allMetrics = mlTracking.getMetrics();

    // Send to parent component
    if (onMetricsUpdate) {
      onMetricsUpdate({
        attention: allMetrics.avgAttention,
        engagement: calculateEngagement(allMetrics),
        emotion: allMetrics.dominantEmotion,
        blinkRate: allMetrics.blinkRate,
        gazeHeatmap: allMetrics.gazePoints,
        distractions: allMetrics.distractionCount,
      });
    }
  };

  const calculateEngagement = (metrics) => {
    // Engagement = weighted average of attention, emotion positivity, and focus duration
    const emotionScore = {
      'happy': 100,
      'focused': 90,
      'neutral': 70,
      'surprised': 60,
      'sad': 40,
    };

    const emotionWeight = emotionScore[metrics.dominantEmotion] || 70;
    const focusWeight = Math.min(100, (metrics.fixationDuration / 1000) * 2);

    return Math.round(
      metrics.avgAttention * 0.4 +
      emotionWeight * 0.3 +
      focusWeight * 0.3
    );
  };

  const formatTime = (seconds) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  const getEmotionEmoji = (emotion) => {
    const emojis = {
      'happy': '😊',
      'focused': '🎯',
      'neutral': '😐',
      'surprised': '😮',
      'sad': '😢',
    };
    return emojis[emotion] || '😐';
  };

  const getAttentionColor = (score) => {
    if (score >= 75) return 'success.main';
    if (score >= 50) return 'warning.main';
    return 'error.main';
  };

  if (!showOverlay) {
    return (
      <Box sx={{ position: 'absolute', opacity: 0, pointerEvents: 'none' }}>
        <video ref={videoRef} style={{ display: 'none' }} />
      </Box>
    );
  }

  return (
    <Box>
      {/* Hidden video element for tracking */}
      <Box sx={{ position: 'absolute', opacity: 0, pointerEvents: 'none' }}>
        <video ref={videoRef} style={{ width: 1, height: 1 }} />
      </Box>

      {/* Metrics Overlay */}
      <Paper
        elevation={3}
        sx={{
          position: 'fixed',
          top: 100,
          right: 20,
          width: 200,
          p: 2,
          borderRadius: 3,
          background: 'rgba(255, 255, 255, 0.95)',
          backdropFilter: 'blur(10px)',
          zIndex: 1000,
        }}
      >
        {/* Session Time */}
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 2 }}>
          <Timer fontSize="small" color="primary" />
          <Typography variant="h6" fontWeight={600}>
            {formatTime(metrics.sessionTime)}
          </Typography>
        </Box>

        {/* Attention Score */}
        <Box sx={{ mb: 2 }}>
          <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 0.5 }}>
            <Typography variant="body2" fontWeight={500}>
              {t.session.tracker.attention}
            </Typography>
            <Typography
              variant="body2"
              fontWeight={600}
              color={getAttentionColor(metrics.attention)}
            >
              {metrics.attention}%
            </Typography>
          </Box>
          <LinearProgress
            variant="determinate"
            value={metrics.attention}
            sx={{
              height: 6,
              borderRadius: 3,
              bgcolor: 'grey.200',
              '& .MuiLinearProgress-bar': {
                borderRadius: 3,
                bgcolor: getAttentionColor(metrics.attention),
              },
            }}
          />
        </Box>

        {/* Current Emotion */}
        <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 2 }}>
          <Typography variant="body2" fontWeight={500}>
            {t.session.tracker.mood}
          </Typography>
          <Chip
            size="small"
            label={`${getEmotionEmoji(metrics.emotion)} ${metrics.emotion}`}
            sx={{ textTransform: 'capitalize' }}
          />
        </Box>

        {/* Tracking Status */}
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
          <Box
            sx={{
              width: 8,
              height: 8,
              borderRadius: '50%',
              bgcolor: isTracking ? 'success.main' : 'grey.400',
              animation: isTracking ? 'pulse 2s infinite' : 'none',
              '@keyframes pulse': {
                '0%, 100%': { opacity: 1 },
                '50%': { opacity: 0.5 },
              },
            }}
          />
          <Typography variant="caption" color="text.secondary">
            {isTracking ? t.session.tracker.trackingActive : t.session.tracker.initializing}
          </Typography>
        </Box>

        {error && (
          <Typography variant="caption" color="error" sx={{ mt: 1, display: 'block' }}>
            {error}
          </Typography>
        )}
      </Paper>

      {/* Gaze Indicator (optional) */}
      {isTracking && (
        <Box
          sx={{
            position: 'fixed',
            left: `${metrics.gazePoint.x * 100}%`,
            top: `${metrics.gazePoint.y * 100}%`,
            width: 20,
            height: 20,
            borderRadius: '50%',
            bgcolor: 'primary.main',
            opacity: 0.3,
            transform: 'translate(-50%, -50%)',
            transition: 'all 0.1s ease-out',
            pointerEvents: 'none',
            zIndex: 999,
          }}
        />
      )}
    </Box>
  );
};

export default SessionTracker;
