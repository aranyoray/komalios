/**
 * Eye Tracker Debug Component
 * 
 * Displays real-time debugging information for the advanced eye tracker
 * Use this component to verify the tracker is working correctly
 */

import React, { useState, useEffect, useRef } from 'react';
import { Box, Typography, Paper, Button, Chip, CircularProgress } from '@mui/material';
import { advancedEyeTracker } from '../../tracking/advancedEyeTracking';

export default function EyeTrackerDebug({ videoElement }) {
  const [debugStats, setDebugStats] = useState(null);
  const [healthCheck, setHealthCheck] = useState(null);
  const [isMonitoring, setIsMonitoring] = useState(false);
  const intervalRef = useRef(null);

  useEffect(() => {
    if (isMonitoring) {
      intervalRef.current = setInterval(() => {
        const stats = advancedEyeTracker.getDebugStats();
        const health = advancedEyeTracker.healthCheck();
        setDebugStats(stats);
        setHealthCheck(health);
      }, 1000); // Update every second
    } else {
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
        intervalRef.current = null;
      }
    }

    return () => {
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
      }
    };
  }, [isMonitoring]);

  const handleStartMonitoring = () => {
    setIsMonitoring(true);
  };

  const handleStopMonitoring = () => {
    setIsMonitoring(false);
  };

  const handleRunHealthCheck = () => {
    const health = advancedEyeTracker.healthCheck();
    setHealthCheck(health);
    console.log('[EyeTrackerDebug] Health Check:', health);
  };

  if (!debugStats && !healthCheck) {
    return (
      <Paper sx={{ p: 2, m: 2 }}>
        <Typography variant="h6" gutterBottom>
          Eye Tracker Debug
        </Typography>
        <Button
          variant="contained"
          onClick={handleStartMonitoring}
          sx={{ mt: 1 }}
        >
          Start Monitoring
        </Button>
        <Button
          variant="outlined"
          onClick={handleRunHealthCheck}
          sx={{ mt: 1, ml: 1 }}
        >
          Run Health Check
        </Button>
      </Paper>
    );
  }

  return (
    <Paper sx={{ p: 2, m: 2, maxWidth: 800 }}>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2 }}>
        <Typography variant="h6">Eye Tracker Debug</Typography>
        <Box>
          {isMonitoring ? (
            <>
              <Chip label="Monitoring" color="success" size="small" sx={{ mr: 1 }} />
              <Button size="small" onClick={handleStopMonitoring}>
                Stop
              </Button>
            </>
          ) : (
            <Button size="small" variant="contained" onClick={handleStartMonitoring}>
              Start Monitoring
            </Button>
          )}
          <Button
            size="small"
            variant="outlined"
            onClick={handleRunHealthCheck}
            sx={{ ml: 1 }}
          >
            Health Check
          </Button>
        </Box>
      </Box>

      {/* Health Status */}
      {healthCheck && (
        <Box sx={{ mb: 2, p: 1.5, bgcolor: healthCheck.healthy ? 'success.light' : 'error.light', borderRadius: 1 }}>
          <Typography variant="subtitle2" gutterBottom>
            Health Status: {healthCheck.healthy ? '✅ Healthy' : '❌ Issues Detected'}
          </Typography>
          {healthCheck.issues.length > 0 && (
            <Box>
              <Typography variant="caption" color="error" component="div">
                Issues:
              </Typography>
              <ul style={{ margin: '4px 0', paddingLeft: 20 }}>
                {healthCheck.issues.map((issue, idx) => (
                  <li key={idx}>
                    <Typography variant="caption">{issue}</Typography>
                  </li>
                ))}
              </ul>
            </Box>
          )}
        </Box>
      )}

      {/* Debug Stats */}
      {debugStats && (
        <Box>
          <Typography variant="subtitle2" gutterBottom sx={{ mt: 2 }}>
            Tracking Statistics
          </Typography>
          <Box sx={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 1, mb: 2 }}>
            <Paper variant="outlined" sx={{ p: 1 }}>
              <Typography variant="caption" color="text.secondary">Frames Processed</Typography>
              <Typography variant="h6">{debugStats.framesProcessed}</Typography>
            </Paper>
            <Paper variant="outlined" sx={{ p: 1 }}>
              <Typography variant="caption" color="text.secondary">Frames with Face</Typography>
              <Typography variant="h6" color="success.main">
                {debugStats.framesWithFace}
              </Typography>
            </Paper>
            <Paper variant="outlined" sx={{ p: 1 }}>
              <Typography variant="caption" color="text.secondary">Frames without Face</Typography>
              <Typography variant="h6" color="error.main">
                {debugStats.framesWithoutFace}
              </Typography>
            </Paper>
            <Paper variant="outlined" sx={{ p: 1 }}>
              <Typography variant="caption" color="text.secondary">Face Detection Rate</Typography>
              <Typography variant="h6">
                {debugStats.framesProcessed > 0
                  ? ((debugStats.framesWithFace / debugStats.framesProcessed) * 100).toFixed(1)
                  : 0}%
              </Typography>
            </Paper>
          </Box>

          <Typography variant="subtitle2" gutterBottom sx={{ mt: 2 }}>
            Video Element Status
          </Typography>
          <Box sx={{ mb: 2 }}>
            <Typography variant="body2">
              Exists: {debugStats.videoElement?.exists ? '✅' : '❌'}
            </Typography>
            <Typography variant="body2">
              Ready State: {debugStats.videoElement?.readyState} (
              {debugStats.videoElement?.readyState === 4 ? 'Ready' :
               debugStats.videoElement?.readyState === 3 ? 'Enough Data' :
               debugStats.videoElement?.readyState === 2 ? 'Metadata' :
               debugStats.videoElement?.readyState === 1 ? 'Have Data' : 'Nothing'})
            </Typography>
            <Typography variant="body2">
              Dimensions: {debugStats.videoElement?.videoWidth} x {debugStats.videoElement?.videoHeight}
            </Typography>
            <Typography variant="body2">
              Playing: {debugStats.videoElement?.playing ? '✅' : '❌'}
            </Typography>
          </Box>

          <Typography variant="subtitle2" gutterBottom sx={{ mt: 2 }}>
            Performance
          </Typography>
          <Box sx={{ mb: 2 }}>
            <Typography variant="body2">
              Target FPS: {debugStats.performance?.targetFPS}
            </Typography>
            <Typography variant="body2">
              Avg Process Time: {debugStats.performance?.avgProcessTime?.toFixed(2)}ms
            </Typography>
            <Typography variant="body2">
              Last Process Time: {debugStats.performance?.lastProcessTime?.toFixed(2)}ms
            </Typography>
          </Box>

          <Typography variant="subtitle2" gutterBottom sx={{ mt: 2 }}>
            System Status
          </Typography>
          <Box sx={{ mb: 2 }}>
            <Typography variant="body2">
              Initialized: {debugStats.isInitialized ? '✅' : '❌'}
            </Typography>
            <Typography variant="body2">
              Tracking: {debugStats.isTracking ? '✅' : '❌'}
            </Typography>
            <Typography variant="body2">
              FaceMesh Created: {debugStats.faceMesh?.exists ? '✅' : '❌'}
            </Typography>
            <Typography variant="body2">
              Calibrated: {debugStats.calibration?.isCalibrated ? '✅' : '❌'}
            </Typography>
            {debugStats.calibration?.isCalibrated && (
              <Typography variant="body2">
                Calibration Points: {debugStats.calibration?.pointsCount}
              </Typography>
            )}
          </Box>

          {debugStats.errors && debugStats.errors.length > 0 && (
            <>
              <Typography variant="subtitle2" gutterBottom sx={{ mt: 2, color: 'error.main' }}>
                Recent Errors ({debugStats.errors.length})
              </Typography>
              <Box sx={{ maxHeight: 200, overflow: 'auto', mb: 2 }}>
                {debugStats.errors.slice(-5).map((error, idx) => (
                  <Paper key={idx} variant="outlined" sx={{ p: 1, mb: 1, bgcolor: 'error.light' }}>
                    <Typography variant="caption" component="div">
                      <strong>{error.timestamp}</strong>
                    </Typography>
                    <Typography variant="body2">{error.message}</Typography>
                    {error.data && (
                      <Typography variant="caption" component="pre" sx={{ fontSize: '0.7rem', mt: 0.5 }}>
                        {JSON.stringify(error.data, null, 2)}
                      </Typography>
                    )}
                  </Paper>
                ))}
              </Box>
            </>
          )}

          {/* Current Gaze */}
          <Typography variant="subtitle2" gutterBottom sx={{ mt: 2 }}>
            Current Gaze
          </Typography>
          <Box>
            {(() => {
              const metrics = advancedEyeTracker.getMetrics();
              return (
                <Box>
                  <Typography variant="body2">
                    Position: ({metrics.gaze.x?.toFixed(3) || 'N/A'}, {metrics.gaze.y?.toFixed(3) || 'N/A'})
                  </Typography>
                  <Typography variant="body2">
                    Confidence: {(metrics.gaze.confidence * 100)?.toFixed(1) || 0}%
                  </Typography>
                  <Typography variant="body2">
                    Head Pose: Yaw={metrics.headPose.yaw?.toFixed(1) || 0}°, 
                    Pitch={metrics.headPose.pitch?.toFixed(1) || 0}°, 
                    Roll={metrics.headPose.roll?.toFixed(1) || 0}°
                  </Typography>
                  <Typography variant="body2">
                    Eye Openness: L={metrics.eyeMetrics.leftEyeOpenness?.toFixed(3) || 0}, 
                    R={metrics.eyeMetrics.rightEyeOpenness?.toFixed(3) || 0}
                  </Typography>
                  <Typography variant="body2">
                    Blinks: {metrics.eyeMetrics.blinkCount}
                  </Typography>
                  <Typography variant="body2">
                    Fixations: {metrics.fixations}, Saccades: {metrics.saccades}
                  </Typography>
                </Box>
              );
            })()}
          </Box>
        </Box>
      )}
    </Paper>
  );
}

