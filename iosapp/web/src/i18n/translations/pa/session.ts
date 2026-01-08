/**
 * Punjabi - Session Translations
 */

export const session = {
  title: "ਸੈਸ਼ਨ",
  startSession: "ਸੈਸ਼ਨ ਸ਼ੁਰੂ ਕਰੋ",
  endSession: "ਸੈਸ਼ਨ ਖਤਮ ਕਰੋ",
  sessionDuration: "ਸੈਸ਼ਨ ਦੀ ਮਿਆਦ",
  sessionScore: "ਸੈਸ਼ਨ ਸਕੋਰ",
  sessionSummary: "ਸੈਸ਼ਨ ਸਾਰ",
  takeBreak: "ਬਰੇਕ ਲਓ",
  continueSession: "ਸੈਸ਼ਨ ਜਾਰੀ ਰੱਖੋ",
  // Session Flow
  flow: {
    steps: {
      setup: "ਸੈੱਟਅੱਪ",
      checkIn: "ਚੈਕ-ਇਨ",
      activity: "ਗਤੀਵਿਧੀ",
      review: "ਸਮੀਖਿਆ",
    },
    preCheckIn: {
      title: "ਅੱਜ ਤੁਸੀਂ ਕਿਵੇਂ ਮਹਿਸੂਸ ਕਰ ਰਹੇ ਹੋ?",
    },
    postCheckIn: {
      title: "ਸ਼ਾਨਦਾਰ ਕੰਮ! ਚਲੋ, ਚੈਕ-ਇਨ ਕਰੀਏ",
    },
    activity: {
      taskOf: "ਕਾਰਜ {current} ਵਿੱਚੋਂ {total}",
      activityOf: "ਗਤੀਵਿਧੀ {current} ਵਿੱਚੋਂ {total}",
      completeTask: "ਕਾਰਜ ਪੂਰਾ ਕਰੋ",
    },
    report: {
      sessionComplete: "ਸੈਸ਼ਨ ਪੂਰਾ!",
      sessionSummary: "ਸੈਸ਼ਨ ਸਾਰ",
      attentionScore: "ਧਿਆਨ ਸਕੋਰ",
      sessionAverage: "(ਸੈਸ਼ਨ ਔਸਤ)",
      duration: "ਮਿਆਦ",
      activities: "ਗਤੀਵਿਧੀਆਂ",
      engagement: "ਸ਼ਮੂਲੀਅਤ",
      moodCheck: "ਮੂਡ ਚੈਕ",
      before: "ਪਹਿਲਾਂ",
      after: "ਬਾਅਦ",
      insights: "ਸੂਝ",
      viewFullReport: "ਪੂਰੀ ਰਿਪੋਰਟ ਦੇਖੋ",
      done: "ਪੂਰਾ",
    },
  },
  // Face Detection Setup
  faceSetup: {
    title: "ਚਿਹਰਾ ਪਛਾਣ ਸੈੱਟਅੱਪ",
    instructions: "ਫਰੇਮ ਦੇ ਮੱਧ ਵਿੱਚ ਆਪਣਾ ਚਿਹਰਾ ਰੱਖੋ",
    positionFace: "ਆਪਣਾ ਚਿਹਰਾ ਮੱਧ ਵਿੱਚ ਰੱਖੋ",
    keepStill: "ਕੁਝ ਸਕਿੰਟਾਂ ਲਈ ਸਥਿਰ ਰਹੋ",
    detecting: "ਚਿਹਰਾ ਪਛਾਣਿਆ ਜਾ ਰਿਹਾ ਹੈ...",
    detected: "ਚਿਹਰਾ ਪਛਾਣਿਆ ਗਿਆ!",
    complete: "ਸੈੱਟਅੱਪ ਪੂਰਾ!",
    skip: "ਛੱਡੋ",
    continue: "ਜਾਰੀ ਰੱਖੋ",
    error: {
      permissionDenied: "ਕੈਮਰਾ ਪਹੁੰਚ ਇਨਕਾਰ। ਕਿਰਪਾ ਕਰਕੇ ਆਪਣੇ ਬ੍ਰਾਊਜ਼ਰ ਸੈਟਿੰਗਾਂ ਵਿੱਚ ਕੈਮਰਾ ਪਹੁੰਚ ਦੀ ਇਜਾਜ਼ਤ ਦਿਓ।",
      permissionDeniedNative: "ਕੈਮਰਾ ਇਜਾਜ਼ਤ ਇਨਕਾਰ। ਕਿਰਪਾ ਕਰਕੇ ਆਪਣੇ ਡਿਵਾਈਸ ਸੈਟਿੰਗਾਂ ਵਿੱਚ ਕੈਮਰਾ ਪਹੁੰਚ ਸਮਰੱਥ ਕਰੋ (ਸੈਟਿੰਗਾਂ > ਐਪਸ > ਕੋਮਲ > ਇਜਾਜ਼ਤਾਂ)।",
      noCamera: "ਕੋਈ ਕੈਮਰਾ ਨਹੀਂ ਮਿਲਿਆ। ਕਿਰਪਾ ਕਰਕੇ ਯਕੀਨੀ ਬਣਾਓ ਕਿ ਆਪਣੇ ਡਿਵਾਈਸ ਵਿੱਚ ਕੈਮਰਾ ਹੈ।",
      cameraError: "ਕੈਮਰਾ ਪਹੁੰਚ ਗਲਤੀ। ਕਿਰਪਾ ਕਰਕੇ ਦੁਬਾਰਾ ਕੋਸ਼ਿਸ਼ ਕਰੋ ਜਾਂ ਆਪਣੇ ਡਿਵਾਈਸ ਸੈਟਿੰਗਾਂ ਦੀ ਜਾਂਚ ਕਰੋ।",
    },
  },
  // Eye Calibration
  calibration: {
    title: "ਅੱਖ ਕੈਲੀਬ੍ਰੇਸ਼ਨ",
    instructions: "ਹਰ ਬਿੰਦੂ ਦਿਖਾਈ ਦੇਣ 'ਤੇ, ਉਸ ਵੱਲ ਦੇਖੋ। ਆਪਣਾ ਸਿਰ ਸਥਿਰ ਰੱਖੋ ਅਤੇ ਸਿਰਫ਼ ਆਪਣੀਆਂ ਅੱਖਾਂ ਹਿਲਾਓ।",
    lookAtPoint: "ਬਿੰਦੂ ਵੱਲ ਦੇਖੋ",
    pointOf: "ਬਿੰਦੂ {current} ਵਿੱਚੋਂ {total}",
    calibrating: "ਕੈਲੀਬ੍ਰੇਟ ਹੋ ਰਿਹਾ ਹੈ...",
    complete: "ਕੈਲੀਬ੍ਰੇਸ਼ਨ ਪੂਰਾ!",
    quality: {
      title: "ਕੈਲੀਬ੍ਰੇਸ਼ਨ ਗੁਣਵੱਤਾ",
      accuracy: "ਸਟੀਕਤਾ",
      precision: "ਸਟੀਕਤਾ",
      reliability: "ਭਰੋਸੇਮੰਦੀ",
      coverage: "ਕਵਰੇਜ",
      continue: "ਜਾਰੀ ਰੱਖੋ",
      recalibrate: "ਦੁਬਾਰਾ ਕੈਲੀਬ੍ਰੇਟ ਕਰੋ",
    },
    skip: "ਛੱਡੋ",
    error: {
      failed: "ਕੈਲੀਬ੍ਰੇਸ਼ਨ ਅਸਫਲ। ਕਿਰਪਾ ਕਰਕੇ ਦੁਬਾਰਾ ਕੋਸ਼ਿਸ਼ ਕਰੋ।",
      lowQuality: "ਕੈਲੀਬ੍ਰੇਸ਼ਨ ਗੁਣਵੱਤਾ ਘੱਟ ਹੋ ਸਕਦੀ ਹੈ। ਦੁਬਾਰਾ ਕੈਲੀਬ੍ਰੇਸ਼ਨ 'ਤੇ ਵਿਚਾਰ ਕਰੋ।",
    },
  },
  // Session Tracker
  tracker: {
    attention: "ਧਿਆਨ",
    mood: "ਮੂਡ",
    trackingActive: "ਟਰੈਕਿੰਗ ਸਰਗਰਮ",
    initializing: "ਸ਼ੁਰੂ ਕਰ ਰਿਹਾ ਹੈ...",
  },
};

