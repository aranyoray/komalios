# Android 15 Deprecated APIs Fix

## Issue
Google Play Console warning about deprecated APIs for edge-to-edge:
- `android.view.Window.setStatusBarColor` ❌ Deprecated
- `android.view.Window.setNavigationBarColor` ❌ Deprecated  
- `LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES` ❌ Deprecated (constant)

## Solution

### ✅ Fixed in Your Code

**Removed deprecated programmatic calls:**
- Removed `window.setStatusBarColor()` - Now using theme attributes instead
- Removed `window.setNavigationBarColor()` - Now using theme attributes instead

**Using modern approach:**
- ✅ Theme attributes (`android:statusBarColor` in XML) - NOT deprecated
- ✅ `WindowInsetsControllerCompat` - Modern API for appearance control
- ✅ `EdgeToEdge.enable()` - Recommended by Google Play Console
- ✅ Theme attribute `android:windowLayoutInDisplayCutoutMode` - NOT deprecated

### ⚠️ Third-Party Library Warnings (Cannot Fix)

The following warnings are from third-party libraries and cannot be fixed by you:
- `com.google.android.material.bottomsheet.BottomSheetDialog.onCreate` - Material Components library
- `com.google.android.material.internal.EdgeToEdgeUtils.applyEdgeToEdge` - Material Components library
- `com.google.android.material.sidesheet.SheetDialog.onCreate` - Material Components library
- `androidx.activity.EdgeToEdgeApi28.adjustLayoutInDisplayCutoutMode` - AndroidX library
- `com.google.android.gms.ads.internal.overlay.zzm.zzJ` - Google Play Services (AdMob)

**These will be fixed when the libraries update.** You cannot control these.

## References

- [Android 15 Behavior Changes - Edge-to-Edge](https://developer.android.com/about/versions/15/behavior-changes-15#edge-to-edge)

