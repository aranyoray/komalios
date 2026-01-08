# Capacitor Device API Integration

## Overview

The eye tracking system now uses **Capacitor's Device API** (`@capacitor/device`) for more reliable device detection instead of user agent sniffing. This provides accurate device information on native platforms (iOS/Android) while maintaining browser fallback for web.

## Benefits

✅ **More Reliable**: Uses native device APIs instead of user agent strings  
✅ **Accurate Device Info**: Gets actual device model, manufacturer, OS version  
✅ **Better Tablet Detection**: Can distinguish iPad from iPhone, tablets from phones  
✅ **Platform Detection**: Knows if running on iOS, Android, or web  
✅ **Future-Proof**: Uses official Capacitor APIs that are maintained  

## Implementation

### **Device Detection Flow**

```
1. Check if running on native platform (Capacitor.isNativePlatform())
   ├── YES → Use Capacitor Device API
   │   ├── Device.getInfo() → Get platform, model, manufacturer
   │   ├── Distinguish phone vs tablet using model name
   │   └── Return native device info
   │
   └── NO → Use browser fallback
       ├── User agent detection
       ├── Screen size detection
       └── Return web device info
```

### **Code Example**

```javascript
import { Device } from '@capacitor/device';
import { Capacitor } from '@capacitor/core';

// Detect device type
const deviceInfo = await detectDeviceType();

// Returns:
// {
//   type: 'mobile' | 'tablet' | 'desktop',
//   platform: 'ios' | 'android' | 'web',
//   model: 'iPhone 14 Pro' | 'iPad Pro' | 'Samsung Galaxy S23',
//   manufacturer: 'Apple' | 'Samsung',
//   operatingSystem: 'iOS' | 'Android',
//   osVersion: '17.0',
//   isNative: true | false,
//   screenWidth: 390,
//   screenHeight: 844,
// }
```

### **Device Type Detection**

**Native Platforms (iOS/Android):**
- Uses `Device.getInfo()` to get platform and model
- Checks model name for tablet indicators:
  - iPad: Model contains "iPad"
  - Android tablets: Model contains "tablet"
- Falls back to screen size if model detection fails

**Web Platform:**
- Uses user agent detection
- Uses screen size as fallback
- Same logic as before for compatibility

## Device Information Available

### **From Capacitor Device API:**
- `platform`: 'ios' | 'android' | 'web'
- `model`: Device model name (e.g., "iPhone 14 Pro", "iPad Pro")
- `manufacturer`: Device manufacturer (e.g., "Apple", "Samsung")
- `operatingSystem`: OS name (e.g., "iOS", "Android")
- `osVersion`: OS version (e.g., "17.0", "14")

### **Additional Info:**
- `type`: 'mobile' | 'tablet' | 'desktop'
- `isMobile`: boolean
- `isTablet`: boolean
- `isDesktop`: boolean
- `isNative`: boolean (true if using Capacitor API)
- `screenWidth`: number
- `screenHeight`: number

## Usage in Eye Tracking

The device information is used to:

1. **Adjust Head Pose Compensation**:
   - Mobile: More sensitive (0.35x)
   - Tablet: Medium (0.32x)
   - Desktop: Less sensitive (0.28x)

2. **Set Confidence Thresholds**:
   - Mobile: 35° tolerance
   - Tablet: 32° tolerance
   - Desktop: 25° tolerance

3. **Normalize Pitch**:
   - Accounts for expected viewing angle based on device type
   - Mobile: -15° to -25° expected
   - Tablet: -10° to -20° expected
   - Desktop: -5° to -15° expected

## Fallback Behavior

If Capacitor Device API is unavailable or fails:
- Falls back to browser-based detection
- Uses user agent and screen size
- Maintains same API interface
- No breaking changes

## Installation

```bash
npm install @capacitor/device@7
```

**Note**: Version 7 matches the project's Capacitor version (7.4.4).

## Status: ✅ Implemented

- ✅ Capacitor Device API integrated
- ✅ Native platform detection working
- ✅ Browser fallback maintained
- ✅ Device type detection accurate
- ✅ Tablet vs phone distinction improved

The system now uses official Capacitor APIs for better reliability and accuracy across all platforms.

