# Android Edge-to-Edge and Deprecated API Fixes

## Overview

This document describes the fixes applied to address Android 15 (SDK 35) edge-to-edge display warnings and deprecated API usage.

## Issues Fixed

### 1. Edge-to-Edge Display Support

**Problem:** Apps targeting SDK 35 display edge-to-edge by default, but the app wasn't properly handling window insets.

**Solution:**
- Added `EdgeToEdge.enable(this)` in `MainActivity.onCreate()` before `super.onCreate()`
- Implemented `setupEdgeToEdgeInsets()` method to handle window insets properly
- Updated theme styles to support edge-to-edge display

### 2. Deprecated APIs

**Problem:** The app (via third-party libraries) was using deprecated APIs:
- `Window.setStatusBarColor()`
- `Window.setNavigationBarColor()`
- `LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES`

**Solution:**
- Updated theme styles to use modern window insets API instead of deprecated color setters
- Set `android:statusBarColor` and `android:navigationBarColor` to transparent in themes
- Used `android:windowLayoutInDisplayCutoutMode` in theme XML instead of deprecated constants
- Added proper window insets handling in `MainActivity`

## Changes Made

### 1. MainActivity.java

**Added:**
- `EdgeToEdge.enable(this)` call before `super.onCreate()`
- `setupEdgeToEdgeInsets()` method to handle window insets
- Proper window insets controller configuration
- Imports for edge-to-edge support:
  - `androidx.activity.EdgeToEdge`
  - `androidx.core.view.WindowCompat`
  - `androidx.core.view.WindowInsetsCompat`
  - `androidx.core.view.WindowInsetsControllerCompat`

**Key Features:**
- Edge-to-edge is enabled before any content is displayed
- Window insets are properly handled to prevent content overlap with system bars
- Status bar and navigation bar appearance is configured correctly

### 2. styles.xml (values/)

**Updated:**
- Added `android:windowLayoutInDisplayCutoutMode="shortEdges"` to `AppTheme.NoActionBar`
- Configured window transparency settings for edge-to-edge support

### 3. styles.xml (values-v31/)

**Updated:**
- Added complete `AppTheme.NoActionBar` style definition for API 31+
- Set `android:statusBarColor` and `android:navigationBarColor` to transparent
- Configured proper light/dark status bar appearance
- Used modern window insets API instead of deprecated methods

## Third-Party Library Deprecated APIs

**Note:** Some deprecated API warnings may still appear from third-party libraries:
- Material Components (`com.google.android.material`)
- Google Play Services (`com.google.android.gms.ads`)

These libraries will be updated by their maintainers. The app now properly handles edge-to-edge regardless of these library warnings.

## Testing

After applying these changes:

1. **Build the app:**
   ```bash
   cd web/android
   ./gradlew clean build
   ```

2. **Test edge-to-edge display:**
   - Install on Android 15+ device
   - Verify content extends behind system bars
   - Verify content doesn't overlap with status bar or navigation bar
   - Test on devices with display cutouts (notches)

3. **Verify warnings:**
   - Check Google Play Console for reduced warnings
   - Run lint: `./gradlew lint`
   - Check for any remaining deprecated API usage

## Backward Compatibility

The changes maintain backward compatibility:
- Edge-to-edge is enabled only on Android 15+ (SDK 35)
- Window insets handling works on all supported Android versions (API 24+)
- Theme styles use version-specific resources (values-v31/)

## References

- [Android Edge-to-Edge Guide](https://developer.android.com/develop/ui/views/layout/edge-to-edge)
- [WindowInsets API](https://developer.android.com/reference/android/view/WindowInsets)
- [Android 15 Changes](https://developer.android.com/about/versions/15/changes)

