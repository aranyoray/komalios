# Attention Score Debugging Guide

## Debug Logs Added

Comprehensive debugging has been added to track why attention score might be 0. Check the browser console for detailed logs.

## Debug Log Locations

### **1. Eye Tracker Start**
- Logs when eye tracker starts
- Shows screen dimensions, video element status
- Initial state check after 1 second

### **2. Gaze Callback (onGaze)**
- Logs first 5 gaze callbacks and every 50th callback
- Shows gaze coordinates, confidence, timestamp
- Verifies gaze data is being received

### **3. Attention Score Calculation (calculateMetrics)**
- **Initial State**: Total gaze points, fixations, screen dimensions
- **After Filtering**: Filtered gaze points count
- **Screen Dimensions**: Calibrated area boundaries
- **Factor 1 - Center Attention**: Score, time, weight
- **Factor 2 - Area Coverage**: Score, points in area, total points
- **Factor 3 - Gaze Stability**: Variance, normalized variance, score
- **Factor 4 - Fixation Quality**: Average duration, score
- **Combined Score**: Breakdown of all factors
- **Blink Penalty**: If applicable
- **Final Score**: Complete breakdown
- **Warning if Score is 0**: Possible reasons and data available

### **4. Session Flow - Metrics Collection**
- Logs attention score every 5 seconds during activity
- Shows source of attention score
- Shows eye tracking metrics structure

### **5. Session End (useSession)**
- Logs attention score when ending session
- Shows eye tracking metrics and data
- Warning if score is 0 with possible issues

### **6. Database Save (SessionFlow)**
- Logs attention score before saving
- Shows all possible sources
- Warning if score is 0 with diagnostic info

## How to Debug

### **Step 1: Check Console During Session**

1. Open browser console (F12)
2. Start a session
3. Look for `[EyeTracker]` logs
4. Check if gaze callbacks are being received
5. Check if `calculateMetrics` is being called
6. Check attention score calculation logs

### **Step 2: Check for Common Issues**

#### **Issue: No Gaze Points**
```
[AttentionScore] ⚠️ Factor 1 - No gaze points available
```
**Possible Causes:**
- Eye tracker not started
- Camera not working
- Face not detected
- Calibration not applied

**Check:**
- `[EyeTracker] 🚀 Starting eye tracking` log
- `[EyeTracker] 👁️ Gaze callback received` logs
- Camera permissions

#### **Issue: No Tracking Time**
```
[AttentionScore] ⚠️ Factor 1 - No tracking time available
```
**Possible Causes:**
- Gaze points don't have timestamps
- Time delta calculation failing

**Check:**
- Gaze points array structure
- Timestamp values

#### **Issue: Screen Dimensions Not Set**
```
[AttentionScore] 📐 Screen dimensions: { screenWidth: window.innerWidth, ... }
```
**If `hasScreenDimensions: false`:**
- Calibration didn't set screen dimensions
- Check calibration completion

#### **Issue: All Factors Zero**
```
[AttentionScore] ❌ ATTENTION SCORE IS 0!
```
**Check the breakdown:**
- `centerAttentionScore`: Should be > 0 if looking at center
- `areaCoverageScore`: Should be > 0 if looking at screen
- `stabilityScore`: Defaults to 50 if not enough data
- `fixationQualityScore`: Defaults to 50 if no fixations

### **Step 3: Verify Data Flow**

1. **Gaze Collection**: Check `[EyeTracker] 👁️ Gaze callback received`
2. **Metrics Calculation**: Check `[EyeTracker] 📊 Metrics calculated`
3. **Attention Score**: Check `[AttentionScore] ✅ Final attention score`
4. **Session Collection**: Check `[SessionFlow] 📊 Attention score update`
5. **Session End**: Check `[useSession] 🛑 Ending session - attention score`
6. **Database Save**: Check `[SessionFlow] 💾 Saving attention score to database`

## Expected Log Flow

```
[EyeTracker] 🚀 Starting eye tracking
[EyeTracker] 👁️ Gaze callback received (count: 1)
[EyeTracker] 📊 Metrics calculated (attentionScore: 45)
[AttentionScore] 🔍 Starting attention score calculation
[AttentionScore] ✅ Final attention score: 45%
[SessionFlow] 📊 Attention score update: 45%
[useSession] 🛑 Ending session - attention score: 45%
[SessionFlow] 💾 Saving attention score to database: 45%
```

## Common Problems & Solutions

### **Problem: Score is 0, but gaze callbacks are received**
- **Check**: Screen dimensions set correctly?
- **Check**: Gaze points within calibrated area?
- **Check**: Confidence filter too strict? (> 0.3)

### **Problem: Score is 0, no gaze callbacks**
- **Check**: Eye tracker started?
- **Check**: Camera permissions?
- **Check**: Face detection working?

### **Problem: Score is 0, but area coverage > 50%**
- **Check**: Minimum score guarantee should apply
- **Check**: Combined score calculation
- **Check**: Blink penalty too high?

## Debugging Checklist

- [ ] Eye tracker started (`[EyeTracker] 🚀 Starting`)
- [ ] Gaze callbacks received (`[EyeTracker] 👁️ Gaze callback`)
- [ ] Screen dimensions set (`hasScreenDimensions: true`)
- [ ] Gaze points collected (`filteredGazePoints > 0`)
- [ ] Metrics calculated (`[EyeTracker] 📊 Metrics calculated`)
- [ ] Attention score calculated (`[AttentionScore] ✅ Final attention score`)
- [ ] Score > 0 in logs
- [ ] Score saved to database correctly

## Next Steps

After checking logs:
1. Identify which factor is causing score to be 0
2. Check if data is available for that factor
3. Verify screen dimensions are set
4. Check if gaze points are being collected
5. Verify calibration is applied

