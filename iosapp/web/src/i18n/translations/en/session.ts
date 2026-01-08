/**
 * English - Session Translations
 */

export const session = {
  title: 'Session',
  startSession: 'Start Session',
  endSession: 'End Session',
  sessionDuration: 'Session Duration',
  sessionScore: 'Session Score',
  sessionSummary: 'Session Summary',
  takeBreak: 'Take a Break',
  continueSession: 'Continue Session',
  // Session Flow
  flow: {
    steps: {
      setup: 'Setup',
      checkIn: 'Check-in',
      activity: 'Activity',
      review: 'Review',
    },
    preCheckIn: {
      title: 'How are you feeling today?',
    },
    postCheckIn: {
      title: 'Great job! Let\'s check in',
    },
    activity: {
      taskOf: 'Task {current} of {total}',
      activityOf: 'Activity {current} of {total}',
      completeTask: 'Complete Task',
    },
    report: {
      sessionComplete: 'Session Complete!',
      sessionSummary: 'Session Summary',
      attentionScore: 'Attention Score',
      sessionAverage: '(Session Average)',
      duration: 'Duration',
      activities: 'Activities',
      engagement: 'Engagement',
      moodCheck: 'Mood Check',
      before: 'Before',
      after: 'After',
      insights: 'Insights',
      viewFullReport: 'View Full Report',
      done: 'Done',
    },
  },
  // Face Detection Setup
  faceSetup: {
    title: 'Face Detection Setup',
    instructions: 'Position your face in the center of the frame',
    positionFace: 'Position your face in the center',
    keepStill: 'Keep still for a few seconds',
    detecting: 'Detecting face...',
    detected: 'Face detected!',
    complete: 'Setup complete!',
    skip: 'Skip',
    continue: 'Continue',
    error: {
      permissionDenied: 'Camera access denied. Please allow camera access in your browser settings.',
      permissionDeniedNative: 'Camera permission denied. Please enable camera access in your device settings (Settings > Apps > Komal > Permissions).',
      noCamera: 'No camera found. Please ensure your device has a camera.',
      cameraError: 'Camera access error. Please try again or check your device settings.',
    },
  },
  // Eye Calibration
  calibration: {
    title: 'Eye Calibration',
    instructions: 'Look at each point as it appears. Keep your head still and only move your eyes.',
    lookAtPoint: 'Look at the point',
    pointOf: 'Point {current} of {total}',
    calibrating: 'Calibrating...',
    complete: 'Calibration complete!',
    quality: {
      title: 'Calibration Quality',
      accuracy: 'Accuracy',
      precision: 'Precision',
      reliability: 'Reliability',
      coverage: 'Coverage',
      continue: 'Continue',
      recalibrate: 'Recalibrate',
    },
    skip: 'Skip',
    error: {
      failed: 'Calibration failed. Please try again.',
      lowQuality: 'Calibration quality may be low. Consider recalibration.',
    },
  },
  // Session Tracker
  tracker: {
    attention: 'Attention',
    mood: 'Mood',
    trackingActive: 'Tracking active',
    initializing: 'Initializing...',
  },
};
