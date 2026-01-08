# Attention Score Data Structure Fix

## Problem Identified

The final averaged attention score (25) was being calculated correctly, but wasn't reaching the session data structure properly:

1. **`[useSession]`**: Shows `attentionScore: 25` ✅ (correct)
2. **`[SessionFlow]`**: Shows `attentionScore: undefined` ❌ (not found in session data)
3. **Database Save**: Shows `attentionScore: 0` ❌ (using fallback)

## Root Cause

The issue was in `calculateFinalMetrics()`:
- It was calling `calculateMetrics()` FIRST, which recalculated with empty data after tracking stopped
- This overwrote the attention score before averaging from history
- The averaging happened AFTER the damage was done

## Solution Implemented

### **1. Fixed `calculateFinalMetrics()` Order**

**Before:**
```javascript
calculateFinalMetrics() {
  this.calculateMetrics(); // ❌ Recalculates with empty data
  // ... then averages from history
}
```

**After:**
```javascript
calculateFinalMetrics() {
  // STEP 1: Average from history FIRST (before any other calculations)
  if (this.attentionScoreHistory.length > 0) {
    const avgScore = ...;
    this.metrics.attentionScore = Math.round(avgScore); // ✅ Set averaged score
  }
  // STEP 2: Other metrics (gaze aversions, etc.)
  // Do NOT call calculateMetrics() here
}
```

### **2. Fixed Data Structure Merging**

**Before:**
```javascript
const completedSession = {
  ...sessionData,
  ...finalMetrics, // ❌ Doesn't merge properly - different structure
};
```

**After:**
```javascript
const completedSession = {
  ...sessionData,
  metrics: {
    ...(sessionData.metrics || {}),
    eyeTracking: finalMetrics.eyeTracking, // ✅ Properly nested
    // ... other metrics
  },
};
```

## Data Flow (Fixed)

### **1. During Session**
```
calculateMetrics() called every frame:
├── Calculates attention score
├── Adds to attentionScoreHistory[]
└── Updates this.metrics.attentionScore (real-time)
```

### **2. Session End**
```
stop() called:
├── calculateFinalMetrics()
│   ├── STEP 1: Average from history FIRST
│   │   └── this.metrics.attentionScore = averaged score (25)
│   └── STEP 2: Other metrics (no recalculation)
│
├── getMetrics()
│   └── Returns { attentionScore: 25 } ✅
│
└── endSession()
    ├── finalMetrics.eyeTracking.attentionScore = 25 ✅
    └── completedSession.metrics.eyeTracking.attentionScore = 25 ✅
```

### **3. Session Summary**
```
renderReportContent():
├── Reads: sessionData.metrics.eyeTracking.attentionScore
└── Displays: 25% ✅
```

### **4. Database Save**
```
saveSessionToDatabase():
├── Extracts: sessionData.metrics.eyeTracking.attentionScore
└── Saves: 25 ✅
```

## Key Changes

1. **No Recalculation After Stop**: `calculateFinalMetrics()` no longer calls `calculateMetrics()` which would use empty data
2. **Average First**: Averaging from history happens FIRST, before any other operations
3. **Proper Structure**: `completedSession` now has proper `metrics.eyeTracking.attentionScore` structure
4. **Debug Logging**: Added comprehensive logging to verify the flow

## Status: ✅ Fixed

The final averaged attention score now:
- ✅ Is calculated correctly (averaged from history, not recalculated)
- ✅ Is properly structured in `completedSession.metrics.eyeTracking.attentionScore`
- ✅ Is displayed in session summary
- ✅ Is saved to database
- ✅ Is shown in reports

