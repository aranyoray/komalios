# Calibration and Activity Area Matching

## Overview

The calibration system uses **full-screen coordinates** (left, right, top, bottom) excluding the header area. This provides maximum accuracy and flexibility for gaze tracking during activities, allowing detection of distractions when gaze moves outside the valid area.

## Coordinate System

### Calibration Area
- **Full screen calibration**: Calibrates to entire screen (left=0, right=window.innerWidth, top=headerHeight, bottom=window.innerHeight)
- **Header exclusion**: Top header area is excluded from calibration (typically 100-120px)
- Calibration points are positioned as percentages of the full screen
- Gaze coordinates are in screen pixel coordinates (0 to window.innerWidth/Height)

### Activity Area
- Activities can be displayed anywhere on screen
- Gaze tracking works across the entire screen
- Gaze outside the valid area (below header) is considered "distracted"

## How It Works

### 1. Header Height Measurement

During calibration:
1. The calibration component automatically detects and measures the header height
2. Uses DOM traversal to find the sticky header element
3. Falls back to estimated header height (120px) if not found
4. Stores header height in calibration data

### 2. Coordinate Conversion

**During Calibration:**
- Gaze samples are collected in normalized coordinates (0-1) relative to full screen
- Converted to screen pixel coordinates: `screenX = gaze.x * window.innerWidth`
- Calibration points use full-screen normalized coordinates (0-1 relative to full screen)
- Header area is excluded from valid calibration area

**During Activities:**
- Gaze is converted to screen pixel coordinates (0 to window.innerWidth/Height)
- ROI (Regions of Interest) use screen pixel coordinates
- Distraction detection: Gaze below header or outside screen bounds is flagged

### 3. ROI Setting

When setting ROI for avatar or other elements:

```javascript
// Get element position in screen coordinates
const avatarElement = document.querySelector('[data-avatar]');

if (avatarElement) {
  const avatarRect = avatarElement.getBoundingClientRect();
  
  // Use screen coordinates directly
  const x = avatarRect.left; // Screen X coordinate
  const y = avatarRect.top;  // Screen Y coordinate
  const width = avatarRect.width;
  const height = avatarRect.height;
  
  // Set ROI using screen coordinates
  eyeTracker.setROI('avatar-face', x, y, width, height);
}
```

### 4. Distraction Detection

Gaze outside the valid area is automatically detected:

```javascript
// Gaze is flagged as distracted if:
- screenY < headerHeight (looking at header)
- screenX < 0 (left of screen)
- screenX > window.innerWidth (right of screen)
- screenY > window.innerHeight (below screen)
```

## Implementation Details

### Calibration Component

```javascript
// Measures header height and screen dimensions
const screenDims = getScreenDimensions(); // { width, height, topOffset (headerHeight) }

// Converts gaze to screen coordinates
const screenX = gaze.x * window.innerWidth;
const screenY = gaze.y * window.innerHeight;

// Stores in calibration data
calibrationPoint = {
  target: { x: point.x / 100, y: point.y / 100 }, // Full-screen normalized
  gaze: { x: avgX, y: avgY }, // Full-screen normalized
  screenDimensions: {
    width: window.innerWidth,
    height: window.innerHeight,
    headerHeight: screenDims.topOffset,
  },
};
```

### Eye Tracker

```javascript
// Set screen dimensions after calibration
eyeTracker.setScreenDimensions(width, height, headerHeight);

// Gaze is automatically converted to screen coordinates
const gaze = eyeTracker.getGaze();
// gaze.screenX and gaze.screenY are screen pixel coordinates
// gaze.isDistracted indicates if gaze is outside valid area
```

### ROI Tracking

```javascript
// ROI coordinates should be screen pixel coordinates
eyeTracker.setROI('avatar-face', x, y, width, height);
// x, y, width, height are in screen pixels

// ROI checking uses screen pixel coordinates
checkROI(gazePoint); // gazePoint.x and gazePoint.y are screen pixels
```

### Distraction Detection

```javascript
// Automatic distraction detection
if (gaze.isDistracted) {
  // Gaze is outside valid area (header or off-screen)
  // Event is automatically emitted: 'distraction'
}
```

## Benefits

1. **Maximum Accuracy**: Full-screen calibration provides better accuracy across entire screen
2. **Flexible Tracking**: Gaze can be tracked anywhere on screen, not limited to container
3. **Distraction Detection**: Automatic detection when gaze moves outside valid area
4. **Consistent Coordinates**: All coordinates use screen pixels for simplicity
5. **Responsive Design**: Works correctly on different screen sizes

## Testing

To verify full-screen calibration:

1. Complete calibration
2. Check console logs for screen dimensions and header height
3. During activity, verify ROI detection works correctly
4. Check that gaze coordinates match element positions on screen
5. Test distraction detection by looking at header or off-screen

## Troubleshooting

### Gaze doesn't match element positions

- **Check screen dimensions**: Verify dimensions are measured correctly
- **Verify ROI coordinates**: Ensure ROI is set using screen pixel coordinates
- **Check calibration data**: Ensure screen dimensions are stored in calibration
- **Verify header height**: Make sure header height is measured correctly

### ROI detection not working

- **Verify coordinate system**: Ensure ROI uses screen pixel coordinates
- **Check screen dimensions**: Make sure `setScreenDimensions()` was called
- **Debug gaze coordinates**: Log gaze.screenX and gaze.screenY to verify
- **Check element positions**: Verify ROI coordinates match actual element positions

### Distraction detection not working

- **Check header height**: Verify header height is set correctly
- **Debug gaze coordinates**: Log gaze.isDistracted to see distraction status
- **Verify bounds**: Check that screen bounds are correct

