# Attention Score Based on Calibrated Screen Area

## Overview

The attention score is now calculated based on how much time the user's gaze stays within the **calibrated screen area** (the area where calibration points were shown). This matches the calibration circle area and provides a more accurate measure of attention.

## How It Works

### **Calibrated Screen Area**
- **Full screen** (left, right, top, bottom) excluding header
- This is the same area where calibration points were displayed
- Defined by `screenDimensions` set during calibration

### **Attention Score Calculation**

1. **Gaze Points Tracking**
   - Tracks all gaze points with confidence > 0.3
   - Calculates time spent in calibrated area vs total tracking time
   - Uses timestamp differences between gaze points

2. **Fixation-Based Attention (30% weight)**
   - If fixations are detected, calculates attention from fixations
   - Filters fixations within calibrated area

3. **Gaze-Based Attention (70% weight)**
   - Primary method using continuous gaze tracking
   - More accurate for mobile devices where fixations may be sparse
   - Calculates: `(timeInCalibratedArea / totalTrackingTime) * 100`

4. **Combined Score**
   - If both fixations and gaze points available: `fixationAttention * 0.3 + gazeAttention * 0.7`
   - If only fixations: Uses fixation-based attention
   - If only gaze points: Uses gaze-based attention
   - Score ranges from 0-100%

### **Key Features**

✅ **Uses Calibrated Area**: Matches the calibration circle area exactly  
✅ **Continuous Tracking**: Uses gaze points, not just fixations  
✅ **Mobile Optimized**: Works even with sparse fixation data  
✅ **Accurate**: Combines fixation and gaze data for best accuracy  
✅ **Non-Zero Score**: If user is looking at screen, score will be > 0  

## Display in Session Summary

The attention score is now displayed in the **Session Complete** screen:

- **Location**: Session Summary section
- **Format**: Large percentage with color coding:
  - 🟢 Green: ≥70% (Good attention)
  - 🟡 Yellow: 50-69% (Moderate attention)
  - 🔴 Red: <50% (Low attention)
- **Data Source**: `sessionData.metrics.eyeTracking.attentionScore`

## Code Changes

### **1. eyeTracking.js**
- Updated `calculateMetrics()` to use calibrated screen area
- Calculates attention based on time in calibrated area
- Combines fixation and gaze-based attention

### **2. SessionFlow.jsx**
- Added attention score to session summary display
- Shows attention score with color coding
- Displays as percentage (0-100%)

## Expected Behavior

### **During Session**
- Attention score updates in real-time based on gaze within calibrated area
- Score reflects how much time user spends looking at the screen
- Score will be > 0 if user is looking at screen (not distracted)

### **After Session**
- Attention score displayed in session summary
- Color-coded based on score level
- Shows accurate percentage based on calibrated area tracking

## Testing

1. **Complete Calibration**: Ensure calibration sets screen dimensions
2. **Start Session**: Verify attention score updates during activity
3. **Check Score**: Verify score is not 0 if user is looking at screen
4. **View Summary**: Check that attention score displays correctly in session complete screen

## Status: ✅ Implemented

The attention score now:
- ✅ Uses calibrated screen area for calculation
- ✅ Shows in session summary
- ✅ Provides accurate 0-100% score based on attention time
- ✅ Works even with sparse fixation data

