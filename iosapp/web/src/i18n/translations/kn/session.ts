/**
 * Kannada - Session Translations
 */

export const session = {
  title: "ಅಧಿವೇಶನ",
  startSession: "ಅಧಿವೇಶನ ಪ್ರಾರಂಭಿಸಿ",
  endSession: "ಅಧಿವೇಶನ ಮುಗಿಸಿ",
  sessionDuration: "ಅಧಿವೇಶನ ಅವಧಿ",
  sessionScore: "ಅಧಿವೇಶನ ಅಂಕ",
  sessionSummary: "ಅಧಿವೇಶನ ಸಾರಾಂಶ",
  takeBreak: "ವಿರಾಮ ತೆಗೆದುಕೊಳ್ಳಿ",
  continueSession: "ಅಧಿವೇಶನ ಮುಂದುವರಿಸಿ",
  // Session Flow
  flow: {
    steps: {
      setup: "ಸೆಟ್‌ಅಪ್",
      checkIn: "ಚೆಕ್-ಇನ್",
      activity: "ಚಟುವಟಿಕೆ",
      review: "ವಿಮರ್ಶೆ",
    },
    preCheckIn: {
      title: "ಇಂದು ನೀವು ಹೇಗೆ ಅನುಭವಿಸುತ್ತೀರಿ?",
    },
    postCheckIn: {
      title: "ಉತ್ತಮ ಕೆಲಸ! ಚೆಕ್-ಇನ್ ಮಾಡೋಣ",
    },
    activity: {
      taskOf: "ಕಾರ್ಯ {current} ನ {total}",
      activityOf: "ಚಟುವಟಿಕೆ {current} ನ {total}",
      completeTask: "ಕಾರ್ಯ ಪೂರ್ಣಗೊಳಿಸಿ",
    },
    report: {
      sessionComplete: "ಅಧಿವೇಶನ ಪೂರ್ಣಗೊಂಡಿದೆ!",
      sessionSummary: "ಅಧಿವೇಶನ ಸಾರಾಂಶ",
      attentionScore: "ಗಮನ ಅಂಕ",
      sessionAverage: "(ಅಧಿವೇಶನ ಸರಾಸರಿ)",
      duration: "ಅವಧಿ",
      activities: "ಚಟುವಟಿಕೆಗಳು",
      engagement: "ತೊಡಗಿಸಿಕೊಳ್ಳುವಿಕೆ",
      moodCheck: "ಮನಸ್ಥಿತಿ ಪರಿಶೀಲನೆ",
      before: "ಮೊದಲು",
      after: "ನಂತರ",
      insights: "ಒಳನೋಟಗಳು",
      viewFullReport: "ಪೂರ್ಣ ವರದಿ ವೀಕ್ಷಿಸಿ",
      done: "ಪೂರ್ಣಗೊಂಡಿದೆ",
    },
  },
  // Face Detection Setup
  faceSetup: {
    title: "ಮುಖ ಗುರುತಿಸುವಿಕೆ ಸೆಟ್‌ಅಪ್",
    instructions: "ಫ್ರೇಮ್‌ನ ಕೇಂದ್ರದಲ್ಲಿ ನಿಮ್ಮ ಮುಖವನ್ನು ಇರಿಸಿ",
    positionFace: "ನಿಮ್ಮ ಮುಖವನ್ನು ಕೇಂದ್ರದಲ್ಲಿ ಇರಿಸಿ",
    keepStill: "ಕೆಲವು ಸೆಕೆಂಡ್‌ಗಳವರೆಗೆ ಸ್ಥಿರವಾಗಿ ಇರಿ",
    detecting: "ಮುಖವನ್ನು ಗುರುತಿಸಲಾಗುತ್ತಿದೆ...",
    detected: "ಮುಖವನ್ನು ಗುರುತಿಸಲಾಗಿದೆ!",
    complete: "ಸೆಟ್‌ಅಪ್ ಪೂರ್ಣಗೊಂಡಿದೆ!",
    skip: "ಬಿಟ್ಟುಬಿಡಿ",
    continue: "ಮುಂದುವರಿಸಿ",
    error: {
      permissionDenied: "ಕ್ಯಾಮೆರಾ ಪ್ರವೇಶ ನಿರಾಕರಿಸಲಾಗಿದೆ. ದಯವಿಟ್ಟು ನಿಮ್ಮ ಬ್ರೌಸರ್ ಸೆಟ್ಟಿಂಗ್‌ಗಳಲ್ಲಿ ಕ್ಯಾಮೆರಾ ಪ್ರವೇಶಕ್ಕೆ ಅನುಮತಿ ನೀಡಿ.",
      permissionDeniedNative: "ಕ್ಯಾಮೆರಾ ಅನುಮತಿ ನಿರಾಕರಿಸಲಾಗಿದೆ. ದಯವಿಟ್ಟು ನಿಮ್ಮ ಸಾಧನ ಸೆಟ್ಟಿಂಗ್‌ಗಳಲ್ಲಿ ಕ್ಯಾಮೆರಾ ಪ್ರವೇಶವನ್ನು ಸಕ್ರಿಯಗೊಳಿಸಿ (ಸೆಟ್ಟಿಂಗ್‌ಗಳು > ಆ್ಯಪ್‌ಗಳು > ಕೋಮಲ್ > ಅನುಮತಿಗಳು).",
      noCamera: "ಯಾವುದೇ ಕ್ಯಾಮೆರಾ ಕಂಡುಬಂದಿಲ್ಲ. ದಯವಿಟ್ಟು ನಿಮ್ಮ ಸಾಧನದಲ್ಲಿ ಕ್ಯಾಮೆರಾ ಇದೆ ಎಂದು ಖಚಿತಪಡಿಸಿಕೊಳ್ಳಿ.",
      cameraError: "ಕ್ಯಾಮೆರಾ ಪ್ರವೇಶ ದೋಷ. ದಯವಿಟ್ಟು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ ಅಥವಾ ನಿಮ್ಮ ಸಾಧನ ಸೆಟ್ಟಿಂಗ್‌ಗಳನ್ನು ಪರಿಶೀಲಿಸಿ.",
    },
  },
  // Eye Calibration
  calibration: {
    title: "ಕಣ್ಣು ಕ್ಯಾಲಿಬ್ರೇಷನ್",
    instructions: "ಪ್ರತಿ ಬಿಂದು ಕಾಣಿಸಿದಂತೆ, ಅದರ ಮೇಲೆ ನೋಡಿ. ನಿಮ್ಮ ತಲೆಯನ್ನು ಸ್ಥಿರವಾಗಿ ಇರಿಸಿ ಮತ್ತು ಕೇವಲ ನಿಮ್ಮ ಕಣ್ಣುಗಳನ್ನು ಚಲಿಸಿ.",
    lookAtPoint: "ಬಿಂದುವಿನ ಮೇಲೆ ನೋಡಿ",
    pointOf: "ಬಿಂದು {current} ನ {total}",
    calibrating: "ಕ್ಯಾಲಿಬ್ರೇಟ್ ಮಾಡಲಾಗುತ್ತಿದೆ...",
    complete: "ಕ್ಯಾಲಿಬ್ರೇಷನ್ ಪೂರ್ಣಗೊಂಡಿದೆ!",
    quality: {
      title: "ಕ್ಯಾಲಿಬ್ರೇಷನ್ ಗುಣಮಟ್ಟ",
      accuracy: "ನಿಖರತೆ",
      precision: "ನಿಖರತೆ",
      reliability: "ವಿಶ್ವಾಸಾರ್ಹತೆ",
      coverage: "ವ್ಯಾಪ್ತಿ",
      continue: "ಮುಂದುವರಿಸಿ",
      recalibrate: "ಮತ್ತೆ ಕ್ಯಾಲಿಬ್ರೇಟ್ ಮಾಡಿ",
    },
    skip: "ಬಿಟ್ಟುಬಿಡಿ",
    error: {
      failed: "ಕ್ಯಾಲಿಬ್ರೇಷನ್ ವಿಫಲವಾಗಿದೆ. ದಯವಿಟ್ಟು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.",
      lowQuality: "ಕ್ಯಾಲಿಬ್ರೇಷನ್ ಗುಣಮಟ್ಟ ಕಡಿಮೆಯಾಗಿರಬಹುದು. ಮರು-ಕ್ಯಾಲಿಬ್ರೇಷನ್ ಪರಿಗಣಿಸಿ.",
    },
  },
  // Session Tracker
  tracker: {
    attention: "ಗಮನ",
    mood: "ಮನಸ್ಥಿತಿ",
    trackingActive: "ಟ್ರ್ಯಾಕಿಂಗ್ ಸಕ್ರಿಯ",
    initializing: "ಪ್ರಾರಂಭಿಸಲಾಗುತ್ತಿದೆ...",
  },
};

