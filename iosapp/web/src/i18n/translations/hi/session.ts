/**
 * Hindi - Session Translations
 */

export const session = {
  title: 'सत्र',
  startSession: 'सत्र शुरू करें',
  endSession: 'सत्र समाप्त करें',
  sessionDuration: 'सत्र अवधि',
  sessionScore: 'सत्र स्कोर',
  sessionSummary: 'सत्र सारांश',
  takeBreak: 'ब्रेक लें',
  continueSession: 'सत्र जारी रखें',
  // Session Flow
  flow: {
    steps: {
      setup: 'सेटअप',
      checkIn: 'चेक-इन',
      activity: 'गतिविधि',
      review: 'समीक्षा',
    },
    preCheckIn: {
      title: 'आज आप कैसा महसूस कर रहे हैं?',
    },
    postCheckIn: {
      title: 'बढ़िया काम! चलिए चेक-इन करते हैं',
    },
    activity: {
      taskOf: 'कार्य {current} का {total}',
      activityOf: 'गतिविधि {current} का {total}',
      completeTask: 'कार्य पूर्ण करें',
    },
    report: {
      sessionComplete: 'सत्र पूर्ण!',
      sessionSummary: 'सत्र सारांश',
      attentionScore: 'ध्यान स्कोर',
      sessionAverage: '(सत्र औसत)',
      duration: 'अवधि',
      activities: 'गतिविधियाँ',
      engagement: 'भागीदारी',
      moodCheck: 'मूड चेक',
      before: 'पहले',
      after: 'बाद में',
      insights: 'अंतर्दृष्टि',
      viewFullReport: 'पूर्ण रिपोर्ट देखें',
      done: 'पूर्ण',
    },
  },
  // Face Detection Setup
  faceSetup: {
    title: 'चेहरा पहचान सेटअप',
    instructions: 'फ्रेम के केंद्र में अपना चेहरा रखें',
    positionFace: 'अपना चेहरा केंद्र में रखें',
    keepStill: 'कुछ सेकंड के लिए स्थिर रहें',
    detecting: 'चेहरा पहचाना जा रहा है...',
    detected: 'चेहरा पहचान लिया गया!',
    complete: 'सेटअप पूर्ण!',
    skip: 'छोड़ें',
    continue: 'जारी रखें',
    error: {
      permissionDenied: 'कैमरा पहुंच अस्वीकृत। कृपया अपनी ब्राउज़र सेटिंग्स में कैमरा पहुंच की अनुमति दें।',
      permissionDeniedNative: 'कैमरा अनुमति अस्वीकृत। कृपया अपनी डिवाइस सेटिंग्स में कैमरा पहुंच सक्षम करें (सेटिंग्स > ऐप्स > कोमल > अनुमतियाँ)।',
      noCamera: 'कोई कैमरा नहीं मिला। कृपया सुनिश्चित करें कि आपके डिवाइस में कैमरा है।',
      cameraError: 'कैमरा पहुंच त्रुटि। कृपया फिर से कोशिश करें या अपनी डिवाइस सेटिंग्स जांचें।',
    },
  },
  // Eye Calibration
  calibration: {
    title: 'आंख कैलिब्रेशन',
    instructions: 'जैसे-जैसे प्रत्येक बिंदु दिखाई दे, उस पर देखें। अपना सिर स्थिर रखें और केवल अपनी आंखें हिलाएं।',
    lookAtPoint: 'बिंदु पर देखें',
    pointOf: 'बिंदु {current} का {total}',
    calibrating: 'कैलिब्रेट किया जा रहा है...',
    complete: 'कैलिब्रेशन पूर्ण!',
    quality: {
      title: 'कैलिब्रेशन गुणवत्ता',
      accuracy: 'सटीकता',
      precision: 'परिशुद्धता',
      reliability: 'विश्वसनीयता',
      coverage: 'कवरेज',
      continue: 'जारी रखें',
      recalibrate: 'फिर से कैलिब्रेट करें',
    },
    skip: 'छोड़ें',
    error: {
      failed: 'कैलिब्रेशन विफल। कृपया फिर से कोशिश करें।',
      lowQuality: 'कैलिब्रेशन गुणवत्ता कम हो सकती है। पुनः कैलिब्रेशन पर विचार करें।',
    },
  },
  // Session Tracker
  tracker: {
    attention: 'ध्यान',
    mood: 'मूड',
    trackingActive: 'ट्रैकिंग सक्रिय',
    initializing: 'आरंभ किया जा रहा है...',
  },
};

