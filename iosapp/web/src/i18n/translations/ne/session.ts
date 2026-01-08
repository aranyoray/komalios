/**
 * Nepali - Session Translations
 */

export const session = {
  title: "सत्र",
  startSession: "सत्र सुरु गर्नुहोस्",
  endSession: "सत्र समाप्त गर्नुहोस्",
  sessionDuration: "सत्र अवधि",
  sessionScore: "सत्र स्कोर",
  sessionSummary: "सत्र सारांश",
  takeBreak: "विश्राम लिनुहोस्",
  continueSession: "सत्र जारी राख्नुहोस्",
  // Session Flow
  flow: {
    steps: {
      setup: "सेटअप",
      checkIn: "चेक-इन",
      activity: "गतिविधि",
      review: "समीक्षा",
    },
    preCheckIn: {
      title: "आज तपाइँ कस्तो महसुस गर्नुहुन्छ?",
    },
    postCheckIn: {
      title: "उत्कृष्ट काम! चल्नुहोस्, चेक-इन गरौं",
    },
    activity: {
      taskOf: "कार्य {current} मध्ये {total}",
      activityOf: "गतिविधि {current} मध्ये {total}",
      completeTask: "कार्य पूर्ण गर्नुहोस्",
    },
    report: {
      sessionComplete: "सत्र पूर्ण!",
      sessionSummary: "सत्र सारांश",
      attentionScore: "ध्यान स्कोर",
      sessionAverage: "(सत्र औसत)",
      duration: "अवधि",
      activities: "गतिविधिहरू",
      engagement: "संलग्नता",
      moodCheck: "मूड चेक",
      before: "अघि",
      after: "पछि",
      insights: "अन्तर्दृष्टि",
      viewFullReport: "पूर्ण रिपोर्ट हेर्नुहोस्",
      done: "सम्पन्न",
    },
  },
  // Face Detection Setup
  faceSetup: {
    title: "अनुहार पहिचान सेटअप",
    instructions: "फ्रेमको केन्द्रमा तपाइँको अनुहार राख्नुहोस्",
    positionFace: "तपाइँको अनुहार केन्द्रमा राख्नुहोस्",
    keepStill: "केही सेकेन्ड स्थिर रहनुहोस्",
    detecting: "अनुहार पहिचान हुँदैछ...",
    detected: "अनुहार पहिचान भयो!",
    complete: "सेटअप पूर्ण!",
    skip: "छोड्नुहोस्",
    continue: "जारी राख्नुहोस्",
    error: {
      permissionDenied: "क्यामेरा पहुँच अस्वीकार गरियो। कृपया तपाइँको ब्राउजर सेटिङहरूमा क्यामेरा पहुँचको अनुमति दिनुहोस्।",
      permissionDeniedNative: "क्यामेरा अनुमति अस्वीकार गरियो। कृपया तपाइँको उपकरण सेटिङहरूमा क्यामेरा पहुँच सक्षम गर्नुहोस् (सेटिङहरू > एपहरू > कोमल > अनुमतिहरू)।",
      noCamera: "कुनै क्यामेरा फेला परेन। कृपया तपाइँको उपकरणमा क्यामेरा छ भन्ने निश्चित गर्नुहोस्।",
      cameraError: "क्यामेरा पहुँच त्रुटि। कृपया फेरि प्रयास गर्नुहोस् वा तपाइँको उपकरण सेटिङहरू जाँच गर्नुहोस्।",
    },
  },
  // Eye Calibration
  calibration: {
    title: "आँखा क्यालिब्रेसन",
    instructions: "प्रत्येक बिन्दु देखिने बेला, त्यसमा हेर्नुहोस्। तपाइँको टाउको स्थिर राख्नुहोस् र मात्र तपाइँको आँखाहरू सार्नुहोस्।",
    lookAtPoint: "बिन्दुमा हेर्नुहोस्",
    pointOf: "बिन्दु {current} मध्ये {total}",
    calibrating: "क्यालिब्रेट हुँदैछ...",
    complete: "क्यालिब्रेसन पूर्ण!",
    quality: {
      title: "क्यालिब्रेसन गुणस्तर",
      accuracy: "शुद्धता",
      precision: "शुद्धता",
      reliability: "विश्वसनीयता",
      coverage: "कभरेज",
      continue: "जारी राख्नुहोस्",
      recalibrate: "पुनः क्यालिब्रेट गर्नुहोस्",
    },
    skip: "छोड्नुहोस्",
    error: {
      failed: "क्यालिब्रेसन असफल। कृपया फेरि प्रयास गर्नुहोस्।",
      lowQuality: "क्यालिब्रेसन गुणस्तर कम हुन सक्छ। पुनः क्यालिब्रेसन विचार गर्नुहोस्।",
    },
  },
  // Session Tracker
  tracker: {
    attention: "ध्यान",
    mood: "मूड",
    trackingActive: "ट्र्याकिङ सक्रिय",
    initializing: "सुरु गर्दैछ...",
  },
};

