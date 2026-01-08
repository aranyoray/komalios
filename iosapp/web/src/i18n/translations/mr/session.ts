/**
 * Marathi - Session Translations
 */

export const session = {
  title: "सत्र",
  startSession: "सत्र सुरू करा",
  endSession: "सत्र समाप्त करा",
  sessionDuration: "सत्र कालावधी",
  sessionScore: "सत्र गुण",
  sessionSummary: "सत्र सारांश",
  takeBreak: "विश्रांती घ्या",
  continueSession: "सत्र सुरू ठेवा",
  // Session Flow
  flow: {
    steps: {
      setup: "सेटअप",
      checkIn: "चेक-इन",
      activity: "क्रियाकलाप",
      review: "पुनरावलोकन",
    },
    preCheckIn: {
      title: "आज तुम्ही कसे वाटते?",
    },
    postCheckIn: {
      title: "छान काम! चला चेक-इन करूया",
    },
    activity: {
      taskOf: "कार्य {current} पैकी {total}",
      activityOf: "क्रियाकलाप {current} पैकी {total}",
      completeTask: "कार्य पूर्ण करा",
    },
    report: {
      sessionComplete: "सत्र पूर्ण!",
      sessionSummary: "सत्र सारांश",
      attentionScore: "लक्ष गुण",
      sessionAverage: "(सत्र सरासरी)",
      duration: "कालावधी",
      activities: "क्रियाकलाप",
      engagement: "सहभाग",
      moodCheck: "मूड चेक",
      before: "आधी",
      after: "नंतर",
      insights: "अंतर्दृष्टी",
      viewFullReport: "पूर्ण अहवाल पहा",
      done: "पूर्ण",
    },
  },
  // Face Detection Setup
  faceSetup: {
    title: "चेहरा ओळखणे सेटअप",
    instructions: "फ्रेमच्या मध्यभागी तुमचा चेहरा ठेवा",
    positionFace: "तुमचा चेहरा मध्यभागी ठेवा",
    keepStill: "काही सेकंद स्थिर रहा",
    detecting: "चेहरा ओळखला जात आहे...",
    detected: "चेहरा ओळखला गेला!",
    complete: "सेटअप पूर्ण!",
    skip: "वगळा",
    continue: "पुढे जा",
    error: {
      permissionDenied: "कॅमेरा प्रवेश नाकारला. कृपया तुमच्या ब्राउझर सेटिंग्जमध्ये कॅमेरा प्रवेशाची परवानगी द्या.",
      permissionDeniedNative: "कॅमेरा परवानगी नाकारली. कृपया तुमच्या डिव्हाइस सेटिंग्जमध्ये कॅमेरा प्रवेश सक्षम करा (सेटिंग्ज > ॲप्स > कोमल > परवानग्या).",
      noCamera: "कॅमेरा सापडला नाही. कृपया तुमच्या डिव्हाइसमध्ये कॅमेरा आहे याची खात्री करा.",
      cameraError: "कॅमेरा प्रवेश त्रुटी. कृपया पुन्हा प्रयत्न करा किंवा तुमच्या डिव्हाइस सेटिंग्ज तपासा.",
    },
  },
  // Eye Calibration
  calibration: {
    title: "डोळा कॅलिब्रेशन",
    instructions: "प्रत्येक बिंदू दिसत असताना, त्याकडे पहा. तुमचे डोके स्थिर ठेवा आणि फक्त तुमचे डोळे हलवा.",
    lookAtPoint: "बिंदूकडे पहा",
    pointOf: "बिंदू {current} पैकी {total}",
    calibrating: "कॅलिब्रेट होत आहे...",
    complete: "कॅलिब्रेशन पूर्ण!",
    quality: {
      title: "कॅलिब्रेशन गुणवत्ता",
      accuracy: "अचूकता",
      precision: "अचूकता",
      reliability: "विश्वासार्हता",
      coverage: "कव्हरेज",
      continue: "पुढे जा",
      recalibrate: "पुन्हा कॅलिब्रेट करा",
    },
    skip: "वगळा",
    error: {
      failed: "कॅलिब्रेशन अयशस्वी. कृपया पुन्हा प्रयत्न करा.",
      lowQuality: "कॅलिब्रेशन गुणवत्ता कमी असू शकते. पुन्हा कॅलिब्रेशन विचारात घ्या.",
    },
  },
  // Session Tracker
  tracker: {
    attention: "लक्ष",
    mood: "मूड",
    trackingActive: "ट्रॅकिंग सक्रिय",
    initializing: "सुरू करत आहे...",
  },
};

