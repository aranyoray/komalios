# Advanced On-Device Eye Tracking Implementation

## Overview

This document describes the improved on-device eye tracking system for the Komal app, based on research from mobile eye tracking devices, MAC-Gaze (Motion-Aware Continual Calibration), Open Gaze, and eye tracking laboratory best practices.

## Architecture

### Components

1. **`advancedEyeTracking.js`** - Core eye tracking engine using MediaPipe Face Mesh
2. **`eyeTracking.js`** - High-level wrapper that integrates with the session system
3. **`EyeCalibration.jsx`** - UI component for 9-point calibration
4. **`mlTracking.js`** - Legacy MediaPipe service (still used for face detection)

### Key Features

- ✅ **Real-time gaze estimation** using MediaPipe Face Mesh iris landmarks
- ✅ **Head pose compensation** for accurate tracking when user moves head
- ✅ **Motion-aware calibration** using least squares transformation
- ✅ **On-device processing** - all computation happens locally
- ✅ **Mobile optimized** - frame rate throttling and performance tuning
- ✅ **Blink detection** using Eye Aspect Ratio (EAR)
- ✅ **Fixation and saccade detection** for attention analysis

## How It Works

### 1. Face Detection & Landmark Extraction

MediaPipe Face Mesh provides 468 facial landmarks, including:
- **Eye regions**: 16 landmarks per eye outlining the eye shape
- **Iris landmarks**: 5 landmarks per iris (10 total) for precise gaze calculation
- **Face outline**: For head pose estimation

### 2. Gaze Estimation Algorithm

The gaze estimation process:

1. **Extract iris centers** from MediaPipe iris landmarks
2. **Normalize iris position** relative to eye corners (0-1 range)
3. **Average both eyes** for more stable gaze estimation
4. **Compensate for head pose** (yaw, pitch, roll rotations)
5. **Apply calibration transformation** if calibrated
6. **Smooth gaze data** using exponential moving average

### 3. Head Pose Estimation

Head pose is estimated using facial landmarks:
- **Yaw** (left-right): Calculated from eye corner positions
- **Pitch** (up-down): Calculated from nose tip to bridge distance
- **Roll** (tilt): Calculated from eye line angle

Head pose compensation is critical because:
- When head turns left, gaze appears to move right (and vice versa)
- When head tilts, gaze coordinates need rotation correction
- Without compensation, gaze accuracy degrades significantly

### 4. Calibration System

The calibration system uses a **9-point calibration** process:

1. User looks at 9 points on screen (corners, edges, center)
2. System collects gaze samples for each point
3. Calculates transformation matrix using least squares
4. Applies transformation to map raw gaze to screen coordinates

**Calibration data format:**
```javascript
{
  target: { x: 0.5, y: 0.5 },  // Target point (0-1 normalized)
  gaze: { x: 0.48, y: 0.52 },  // Measured gaze (0-1 normalized)
}
```

**Transformation matrix:**
- 2x3 affine transformation matrix
- Maps raw gaze coordinates to calibrated screen coordinates
- Compensates for individual eye geometry and device positioning

### 5. Blink Detection

Uses **Eye Aspect Ratio (EAR)**:
- EAR = (vertical eye distance) / (horizontal eye distance)
- When eye closes, EAR drops below threshold (~0.25)
- Prevents false positives with temporal filtering (200ms cooldown)

### 6. Fixation & Saccade Detection

**Fixations:**
- Gaze staying within 5% of screen for >100ms
- Indicates focused attention on specific area

**Saccades:**
- Rapid eye movements (>10% screen per second)
- Indicates gaze shifts between areas of interest

## Performance Optimization

### Frame Rate Management

- **Target FPS**: 30 FPS (configurable)
- **Frame skipping**: Automatic throttling if processing is slow
- **Battery-aware**: Reduces FPS when device is not charging

### Memory Management

- **Gaze history**: Last 60 frames (2 seconds at 30fps)
- **Gaze points buffer**: Last 1000 points
- **Automatic cleanup**: Old data removed automatically

### Smoothing

- **Gaze smoothing**: Exponential moving average (factor: 0.7)
- **Head pose smoothing**: Exponential moving average (factor: 0.8)
- Reduces jitter and improves stability

## Integration

### Using in Components

```javascript
import { eyeTracker } from '../tracking/eyeTracking';

// Initialize with video element
await eyeTracker.init(videoElement);

// Start tracking
eyeTracker.start();

// Get current metrics
const metrics = eyeTracker.getMetrics();

// Set ROI (Region of Interest) for attention tracking
eyeTracker.setROI('avatar-face', x, y, width, height);

// Stop tracking
eyeTracker.stop();
```

### Calibration

```javascript
import EyeCalibration from '../components/tracking/EyeCalibration';

<EyeCalibration
  onComplete={(result) => {
    console.log('Calibration complete:', result);
    // result contains calibration data and quality metrics
  }}
  onSkip={() => {
    // User skipped calibration
  }}
  videoStream={videoStream}
/>
```

### Advanced Tracker (Direct Access)

```javascript
import AdvancedEyeTracker from '../tracking/advancedEyeTracking';

const tracker = new AdvancedEyeTracker();

// Initialize
await tracker.initialize(videoElement);

// Start
tracker.start();

// Set callbacks
tracker.setCallback('onGaze', (gaze) => {
  console.log('Gaze:', gaze.x, gaze.y, gaze.confidence);
});

tracker.setCallback('onBlink', (blink) => {
  console.log('Blink detected:', blink.count);
});

// Calibrate
const calibrationData = [
  { target: { x: 0.1, y: 0.1 }, gaze: { x: 0.12, y: 0.09 } },
  { target: { x: 0.5, y: 0.5 }, gaze: { x: 0.48, y: 0.52 } },
  // ... more points
];
tracker.calibrate(calibrationData);

// Get metrics
const metrics = tracker.getMetrics();
```

## Accuracy & Limitations

### Expected Accuracy

- **Without calibration**: ~5-10% error (50-100px on 1080p screen)
- **With calibration**: ~2-5% error (20-50px on 1080p screen)
- **Best case**: <2% error with good lighting and stable head position

### Limitations

1. **Lighting**: Requires good lighting for accurate face detection
2. **Head movement**: Large head movements (>30° rotation) reduce accuracy
3. **Distance**: Optimal distance is 30-60cm from screen
4. **Eye visibility**: Requires both eyes visible (glasses OK, sunglasses may reduce accuracy)
5. **Device performance**: Lower-end devices may have reduced frame rates

### Improving Accuracy

1. **Calibration**: Always perform 9-point calibration for best results
2. **Lighting**: Ensure good, even lighting on face
3. **Position**: Maintain consistent distance and angle to screen
4. **Recalibration**: Recalibrate if device position or user position changes significantly

## Research References

This implementation is based on:

1. **Mobile Eye Tracking Devices** - Bitbrain, eye tracking laboratory techniques
2. **MAC-Gaze** - Motion-Aware Continual Calibration for Mobile Gaze Tracking
3. **Open Gaze** - Deep learning eye tracking for smartphones (arXiv:2308.13495)
4. **Eye Tracking Laboratory Best Practices** - University of Lancashire

## Future Improvements

Potential enhancements:

1. **Machine Learning Model**: Train custom gaze estimation model for better accuracy
2. **Continual Calibration**: Automatic recalibration during use (MAC-Gaze approach)
3. **IMU Integration**: Use device accelerometer/gyroscope for head pose (if available)
4. **Multi-user Support**: Store calibration per user profile
5. **Offline Model**: Bundle MediaPipe models locally instead of CDN

## Troubleshooting

### Gaze not updating

- Check if video element is playing
- Verify MediaPipe is initialized (`mlTracking.isInitialized`)
- Check browser console for errors
- Ensure camera permissions are granted

### Low accuracy

- Perform calibration (9-point)
- Check lighting conditions
- Ensure face is well-positioned (centered, good distance)
- Check for head pose compensation (should be active)

### High CPU usage

- Reduce target FPS in `advancedEyeTracking.js`
- Enable frame skipping
- Check if multiple trackers are running simultaneously

### Blink detection not working

- Check EAR threshold (default: 0.25)
- Verify eye landmarks are detected correctly
- Check blink cooldown (default: 200ms)

## API Reference

### AdvancedEyeTracker

#### Methods

- `initialize(videoElement, options)` - Initialize tracker
- `start()` - Start tracking
- `stop()` - Stop tracking
- `calibrate(calibrationData)` - Calibrate using calibration points
- `getGaze()` - Get current gaze position
- `getMetrics()` - Get tracking metrics
- `setCallback(type, callback)` - Set event callback
- `reset()` - Reset tracking data
- `destroy()` - Cleanup and destroy

#### Callbacks

- `onGaze(gaze)` - Gaze position updated
- `onBlink(blink)` - Blink detected
- `onFixation(fixation)` - Fixation detected
- `onSaccade(saccade)` - Saccade detected
- `onHeadPose(headPose)` - Head pose updated

### EyeTracker (High-level)

#### Methods

- `init(videoElement)` - Initialize
- `start()` - Start tracking
- `stop()` - Stop tracking
- `setROI(name, x, y, width, height)` - Set region of interest
- `getMetrics()` - Get metrics
- `getSessionData()` - Get session data for storage
- `calibrate(calibrationData)` - Calibrate tracker

## License

This implementation uses MediaPipe Face Mesh, which is licensed under Apache 2.0.

