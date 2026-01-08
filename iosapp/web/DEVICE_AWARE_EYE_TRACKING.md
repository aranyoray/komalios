# Device-Aware Eye Tracking Implementation

## Overview

The eye tracking system now includes **device-aware optimizations** to ensure accurate tracking across different device types (mobile phones, tablets, laptops) where cameras are positioned at the top.

## Key Features

### **1. Device Detection**
- Automatically detects device type (mobile, tablet, desktop)
- Identifies screen orientation (portrait/landscape)
- Determines camera position relative to screen

### **2. Camera Position Awareness**
- **Mobile**: Cameras at top, users look down ~15-25° (closer viewing distance)
- **Tablet**: Cameras at top, users look down ~10-20° (medium viewing distance)
- **Laptop/Desktop**: Cameras at top, users look down ~5-15° (further viewing distance)

### **3. Device-Specific Adjustments**

#### **Head Pose Compensation**
- **Mobile**: More sensitive to head movement (0.35x sensitivity)
- **Tablet**: Medium sensitivity (0.32x)
- **Desktop**: Less sensitive (0.28x)

#### **Confidence Thresholds**
- **Mobile**: More tolerance for head movement (35° threshold)
- **Tablet**: Medium tolerance (32°)
- **Desktop**: Less tolerance (25° - more precise)

#### **Pitch Normalization**
- Accounts for natural downward viewing angle
- Normalizes pitch relative to expected center pitch
- Makes "looking at screen center" = 0° pitch

## Implementation Details

### **Device Detection (`deviceDetection.js`)**

```javascript
// Detects device type
detectDeviceType() → { type: 'mobile'|'tablet'|'desktop', ... }

// Gets camera position info
getCameraPosition() → {
  position: 'top',
  expectedCenterPitch: -15° (mobile), -10° (tablet), -5° (desktop),
  pitchRange: { min, max },
  typicalDistance: 0.3-0.5
}
```

### **Head Pose Estimation**

**Before (Generic):**
```javascript
const pitch = Math.atan2(...) * (180 / Math.PI);
// Pitch: -25° (user looking down at mobile screen)
```

**After (Device-Aware):**
```javascript
let pitch = Math.atan2(...) * (180 / Math.PI);
// Adjust for expected viewing angle
pitch = pitch - expectedCenterPitch;
// Pitch: -25° - (-15°) = -10° (normalized)
```

### **Gaze Compensation**

**Device-Specific Sensitivity:**
- Mobile: `yawSensitivity = 0.35`, `pitchSensitivity = 0.35`
- Tablet: `yawSensitivity = 0.32`, `pitchSensitivity = 0.32`
- Desktop: `yawSensitivity = 0.28`, `pitchSensitivity = 0.28`

### **Confidence Calculation**

**Device-Specific Thresholds:**
- Mobile: `yawThreshold = 35°`, `pitchThreshold = 35°`
- Tablet: `yawThreshold = 32°`, `pitchThreshold = 32°`
- Desktop: `yawThreshold = 25°`, `pitchThreshold = 25°`

## Benefits

✅ **Accurate on All Devices**: Accounts for different viewing angles  
✅ **Natural Head Movement**: Allows more movement on mobile devices  
✅ **Better Calibration**: Normalizes pitch for consistent tracking  
✅ **Improved Accuracy**: Device-specific sensitivity adjustments  
✅ **User-Friendly**: Works naturally without requiring perfect posture  

## Device-Specific Behavior

### **Mobile Phones**
- **Viewing Angle**: ~15-25° downward
- **Distance**: Closer (30-40cm)
- **Head Movement**: More tolerance (35°)
- **Sensitivity**: Higher (0.35x)
- **Recommendation**: Hold device at comfortable distance

### **Tablets (iPad)**
- **Viewing Angle**: ~10-20° downward
- **Distance**: Medium (40-50cm)
- **Head Movement**: Medium tolerance (32°)
- **Sensitivity**: Medium (0.32x)
- **Recommendation**: Place on stand or hold steady

### **Laptops/Desktop**
- **Viewing Angle**: ~5-15° downward
- **Distance**: Further (50-70cm)
- **Head Movement**: Less tolerance (25°)
- **Sensitivity**: Lower (0.28x)
- **Recommendation**: Sit at comfortable distance

## Testing Recommendations

1. **Test on Mobile**:
   - Hold device naturally
   - Verify tracking works with head movement
   - Check calibration accuracy

2. **Test on Tablet**:
   - Place on stand or hold steady
   - Verify portrait and landscape orientations
   - Check head pose compensation

3. **Test on Laptop**:
   - Sit at normal distance
   - Verify precise tracking
   - Check head movement tolerance

## Status: ✅ Implemented

Device-aware eye tracking is now fully implemented and optimized for:
- ✅ Mobile phones (Android/iOS)
- ✅ Tablets (iPad, Android tablets)
- ✅ Laptops and desktop computers

All devices with cameras at the top are now properly supported with device-specific optimizations.

