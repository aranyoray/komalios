# Head Pose Integration in Attention Score

## Overview

The attention score now includes **head position and movement** as factors, following modern eye tracking algorithms that account for head pose compensation and stability.

## Research Foundation

Modern eye tracking research (MAC-Gaze, Open Gaze) shows that:
1. **Head position** relative to optimal viewing angle affects attention measurement
2. **Head stability** indicates focused attention vs distraction
3. **Head movement patterns** correlate with engagement levels
4. **Excessive head rotation** (>30°) reduces gaze tracking accuracy

## New Factors Added

### **Factor 5: Head Pose Stability (10% weight)**

**Rationale:**
- Optimal head position: Yaw/Pitch < 15°, Roll < 10°
- Acceptable: Yaw/Pitch 15-30°, Roll 10-20°
- Poor: Yaw/Pitch > 30°, Roll > 20°

**Calculation:**
- Yaw score: <15° = 100%, 15-30° = linear decay, >30° = penalty
- Pitch score: <15° = 100%, 15-30° = linear decay, >30° = penalty
- Roll score: <10° = 100%, 10-20° = linear decay, >20° = penalty
- Combined: `(yawScore × 0.4 + pitchScore × 0.4 + rollScore × 0.2)`

### **Factor 6: Head Movement Stability (5% weight)**

**Rationale:**
- Frequent head movements indicate distraction or discomfort
- Stable head position indicates focused attention
- Variance in head pose over time indicates movement

**Calculation:**
- Calculate variance of yaw/pitch over recent samples (last 30 gaze points)
- Lower variance = higher score
- Variance < 5° = very stable (100%), > 20° = unstable (0%)
- Formula: `100 * (1 - min(variance / 20, 1))`

## Updated Attention Score Formula

```
Attention Score = 
  (Center Attention × 0.35) +
  (Area Coverage × 0.25) +
  (Gaze Stability × 0.15) +
  (Fixation Quality × 0.10) +
  (Head Pose Stability × 0.10) +  // NEW
  (Head Movement Stability × 0.05) +  // NEW
  (Blink Penalty)
```

## Weight Distribution

| Factor | Weight | Description |
|--------|--------|-------------|
| Center Attention | 35% | Gaze near screen center |
| Area Coverage | 25% | Time in calibrated area |
| Gaze Stability | 15% | Low gaze variance |
| Fixation Quality | 10% | Long fixations |
| **Head Pose** | **10%** | **Optimal head position** |
| **Head Movement** | **5%** | **Stable head position** |

## Head Pose Thresholds

### **Optimal (100% score)**
- Yaw: < 15°
- Pitch: < 15°
- Roll: < 10°

### **Acceptable (50-100% score)**
- Yaw: 15-30°
- Pitch: 15-30°
- Roll: 10-20°

### **Poor (0-50% score)**
- Yaw: > 30°
- Pitch: > 30°
- Roll: > 20°

## Benefits

✅ **More Accurate**: Accounts for head position effects on gaze  
✅ **Distraction Detection**: Excessive head movement indicates distraction  
✅ **Research-Based**: Uses established head pose thresholds  
✅ **Real-World Optimized**: Works with natural head movements  
✅ **Comprehensive**: Considers both position and movement  

## Integration

- Head pose data comes from `advancedEyeTracker.getMetrics().headPose`
- Head pose history from `advancedEyeTracker.gazeData.history`
- Already being tracked and compensated in gaze calculation
- Now factored into attention score for better accuracy

## Expected Behavior

- **Stable head, looking at center**: High attention score
- **Frequent head movement**: Lower attention score
- **Head turned away (>30°)**: Reduced attention score
- **Optimal head position**: Maximum attention score

## Status: ✅ Implemented

Head position and movement are now integrated into the attention score calculation using modern eye tracking algorithms.

