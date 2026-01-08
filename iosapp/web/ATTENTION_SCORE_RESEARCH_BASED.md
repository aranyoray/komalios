# Research-Based Attention Score Implementation

## Overview

The attention score is now calculated using a **multi-factor approach** based on eye tracking research (MAC-Gaze, Open Gaze, eye tracking laboratory best practices) and optimized for therapy/learning applications.

## Research Foundation

Based on:
1. **MAC-Gaze**: Motion-Aware Continual Calibration for Mobile Gaze Tracking
2. **Open Gaze**: Deep learning eye tracking for smartphones
3. **Eye Tracking Laboratory Best Practices**: University of Lancashire
4. **Mobile Eye Tracking Devices**: Bitbrain and industry standards

## Multi-Factor Attention Score

### **Factor 1: Center-Focused Attention (40% weight)**

**Rationale:**
- Main content in therapy/learning apps is typically centered
- Last calibration point (id: 13) is at screen center (50%, 50%)
- Research shows users focus on center for primary content

**Calculation:**
- Distance from center calculated for each gaze point
- Exponential decay weighting: `weight = exp(-distance / 0.5)`
- Closer to center = higher weight
- Score: `(weightedTime / totalTime) * 100`

**Weight Distribution:**
- Center (0% distance): 100% weight
- 25% from center: ~60% weight
- 50% from center: ~37% weight
- Edge: ~14% weight

### **Factor 2: Calibrated Area Coverage (30% weight)**

**Rationale:**
- Time spent within calibrated boundaries indicates screen attention
- Calibrated area = full screen excluding header (where calibration points were shown)

**Calculation:**
- Counts time gaze is within calibrated area boundaries
- Excludes distracted gaze (outside area or in header)
- Score: `(timeInArea / totalTime) * 100`

### **Factor 3: Gaze Stability (20% weight)**

**Rationale:**
- Low variance = focused attention
- High variance = distracted/frequent saccades
- Research threshold: variance < 1% = very stable, > 5% = unstable

**Calculation:**
- Calculates variance of recent gaze points (last 30 points or 1 second)
- Normalizes variance to screen size
- Score: `100 * (1 - min(variance / 0.05, 1))`

### **Factor 4: Fixation Quality (10% weight)**

**Rationale:**
- Longer fixations indicate sustained attention
- Research thresholds: >300ms = optimal, <150ms = poor

**Calculation:**
- Average fixation duration
- Score: duration < 150ms = 0%, 150-300ms = linear, >300ms = 100%

### **Blink Rate Penalty**

**Rationale:**
- Normal blink rate: ~15-20/min
- Excessive blinking (>30/min) indicates fatigue/distraction

**Penalty:**
- Reduces score by up to 10% for excessive blinking
- Formula: `penalty = min(10, ((blinkRate - 30) / 30) * 10)`

## Final Score Calculation

```
Attention Score = 
  (Center Attention × 0.40) +
  (Area Coverage × 0.30) +
  (Gaze Stability × 0.20) +
  (Fixation Quality × 0.10) -
  (Blink Penalty)
```

**Minimum Score Guarantee:**
- If area coverage > 50%, minimum score is 30%
- Ensures users looking at screen get some credit

## Score Interpretation

- **90-100%**: Excellent attention - focused on center, stable gaze, long fixations
- **70-89%**: Good attention - mostly focused, some movement
- **50-69%**: Moderate attention - looking at screen but distracted
- **30-49%**: Low attention - frequent distractions, unstable gaze
- **0-29%**: Very low attention - mostly distracted or not looking

## Advantages

✅ **Research-Based**: Uses established eye tracking research  
✅ **Multi-Factor**: Considers multiple attention indicators  
✅ **Center-Weighted**: Prioritizes center area (where content is)  
✅ **Stability-Aware**: Accounts for gaze variance  
✅ **Fixation-Aware**: Considers fixation duration  
✅ **Blink-Aware**: Penalizes excessive blinking  
✅ **Minimum Guarantee**: Ensures non-zero score if looking at screen  

## Application Use Case

Optimized for **therapy/learning applications** where:
- Main content is centered (avatar, activities, instructions)
- Sustained attention is important
- Distraction detection is critical
- User engagement needs accurate measurement

## Testing Recommendations

1. **Center Focus**: Verify higher score when looking at center
2. **Area Coverage**: Verify score increases with more time in calibrated area
3. **Stability**: Verify score decreases with high gaze variance
4. **Fixations**: Verify score increases with longer fixations
5. **Blinking**: Verify score decreases with excessive blinking
6. **Minimum**: Verify score is at least 30% if area coverage > 50%

## Status: ✅ Implemented

The attention score now uses a comprehensive, research-based multi-factor approach optimized for therapy/learning applications.

