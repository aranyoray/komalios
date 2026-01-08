# Eye Tracker Debugging Guide

## Quick Debug Commands

Open your browser console and use these commands:

```javascript
// Get debug statistics
window.debugEyeTracker.getStats()

// Run health check
window.debugEyeTracker.healthCheck()

// Get current metrics
window.debugEyeTracker.getMetrics()

// Get current gaze position
window.debugEyeTracker.getGaze()

// Enable/disable debug logging
window.debugEyeTracker.setDebugMode(true)  // Enable
window.debugEyeTracker.setDebugMode(false) // Disable
```

## Using the Debug Component

Add the debug component to any page to see real-time statistics:

```jsx
import EyeTrackerDebug from '../components/tracking/EyeTrackerDebug';

// In your component
<EyeTrackerDebug videoElement={videoElement} />
```

## What to Check

### 1. Initialization

Check if the tracker is initialized:
```javascript
const stats = window.debugEyeTracker.getStats();
console.log('Initialized:', stats.isInitialized);
console.log('FaceMesh exists:', stats.faceMesh?.exists);
```

### 2. Video Element Status

Verify video element is ready:
```javascript
const stats = window.debugEyeTracker.getStats();
const video = stats.videoElement;
console.log('Video exists:', video.exists);
console.log('Ready state:', video.readyState); // Should be 4 (HAVE_ENOUGH_DATA)
console.log('Dimensions:', video.videoWidth, 'x', video.videoHeight);
console.log('Playing:', video.playing);
```

### 3. Face Detection

Check if faces are being detected:
```javascript
const stats = window.debugEyeTracker.getStats();
const detectionRate = (stats.framesWithFace / stats.framesProcessed) * 100;
console.log('Face detection rate:', detectionRate.toFixed(1) + '%');
```

**Expected:** Should be >80% in good lighting conditions.

### 4. Gaze Tracking

Check if gaze is being calculated:
```javascript
const gaze = window.debugEyeTracker.getGaze();
console.log('Gaze:', gaze);
console.log('Confidence:', (gaze.confidence * 100).toFixed(1) + '%');
```

**Expected:** 
- `x` and `y` should be between 0 and 1
- Confidence should be >0.5 in good conditions
- Values should update when you move your eyes

### 5. Health Check

Run a comprehensive health check:
```javascript
const health = window.debugEyeTracker.healthCheck();
console.log('Healthy:', health.healthy);
console.log('Issues:', health.issues);
```

**Expected:** `healthy: true` with no issues.

## Common Issues and Solutions

### Issue: "Not initialized"

**Solution:**
```javascript
// Make sure you call initialize() first
await advancedEyeTracker.initialize(videoElement);
await advancedEyeTracker.start();
```

### Issue: "Video element missing" or "Video not ready"

**Solution:**
- Ensure video element exists and is playing
- Wait for video to load: `videoElement.addEventListener('loadedmetadata', ...)`
- Check camera permissions are granted

### Issue: "Low face detection rate"

**Possible causes:**
- Poor lighting
- Face not visible in camera
- Camera not focused
- Too close/far from camera

**Solution:**
- Improve lighting
- Position face in center of frame
- Ensure camera is focused
- Maintain 30-60cm distance

### Issue: "Iris landmarks not available"

**Possible causes:**
- MediaPipe refineLandmarks not enabled
- Face too far or at extreme angle
- Poor lighting

**Solution:**
- Check `refineLandmarks: true` in FaceMesh options
- Improve positioning and lighting
- System will fallback to eye center (lower accuracy)

### Issue: "Too many errors"

**Solution:**
```javascript
const stats = window.debugEyeTracker.getStats();
console.log('Recent errors:', stats.errors.slice(-5));
```

Check the error messages to identify the specific issue.

## Performance Monitoring

Monitor frame processing performance:

```javascript
const stats = window.debugEyeTracker.getStats();
console.log('Avg process time:', stats.performance.avgProcessTime.toFixed(2) + 'ms');
console.log('Target FPS:', stats.performance.targetFPS);
```

**Expected:**
- Process time: <50ms for smooth 30fps
- If process time >100ms, consider reducing target FPS

## Real-time Monitoring

Enable continuous monitoring:

```javascript
// Start monitoring
const monitorInterval = setInterval(() => {
  const stats = window.debugEyeTracker.getStats();
  const gaze = window.debugEyeTracker.getGaze();
  
  console.log('Frames:', stats.framesProcessed, 
              'Face detection:', ((stats.framesWithFace / stats.framesProcessed) * 100).toFixed(1) + '%',
              'Gaze:', gaze.x.toFixed(3), gaze.y.toFixed(3),
              'Confidence:', (gaze.confidence * 100).toFixed(1) + '%');
}, 1000);

// Stop monitoring
// clearInterval(monitorInterval);
```

## Debug Logging

Enable detailed debug logging:

```javascript
window.debugEyeTracker.setDebugMode(true);
```

This will log:
- Initialization steps
- Frame processing
- Face detection status
- Gaze calculations
- Errors and warnings

Disable when done:
```javascript
window.debugEyeTracker.setDebugMode(false);
```

## Testing Checklist

1. ✅ Tracker initializes without errors
2. ✅ Video element is ready (readyState = 4)
3. ✅ Face detection rate >80%
4. ✅ Gaze values update when moving eyes
5. ✅ Gaze confidence >0.5
6. ✅ Head pose values update when moving head
7. ✅ Blink detection works (blink count increases)
8. ✅ No errors in console
9. ✅ Health check passes
10. ✅ Performance is acceptable (<50ms per frame)

## Integration Testing

Test in your session flow:

```javascript
import { eyeTracker } from '../tracking/eyeTracking';

// In your component
useEffect(() => {
  const testTracking = async () => {
    // Get video element
    const video = document.querySelector('video');
    if (!video) return;
    
    // Initialize
    await eyeTracker.init(video);
    
    // Start
    eyeTracker.start();
    
    // Monitor
    const interval = setInterval(() => {
      const metrics = eyeTracker.getMetrics();
      console.log('Eye tracking metrics:', metrics);
    }, 2000);
    
    // Cleanup
    return () => {
      clearInterval(interval);
      eyeTracker.stop();
    };
  };
  
  testTracking();
}, []);
```

## Getting Help

If issues persist:

1. Check browser console for errors
2. Run `window.debugEyeTracker.healthCheck()` and review issues
3. Check `window.debugEyeTracker.getStats()` for detailed status
4. Review debug logs with `window.debugEyeTracker.setDebugMode(true)`
5. Verify MediaPipe is loading correctly (check Network tab)

