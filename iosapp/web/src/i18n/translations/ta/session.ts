/**
 * Tamil - Session Translations
 */

export const session = {
  title: "அமர்வு",
  startSession: "அமர்வைத் தொடங்கவும்",
  endSession: "அமர்வை முடிக்கவும்",
  sessionDuration: "அமர்வு காலம்",
  sessionScore: "அமர்வு மதிப்பெண்",
  sessionSummary: "அமர்வு சுருக்கம்",
  takeBreak: "இடைவெளி எடுக்கவும்",
  continueSession: "அமர்வைத் தொடரவும்",
  // Session Flow
  flow: {
    steps: {
      setup: "அமைப்பு",
      checkIn: "சரிபார்ப்பு",
      activity: "செயல்பாடு",
      review: "மதிப்பாய்வு",
    },
    preCheckIn: {
      title: "இன்று நீங்கள் எப்படி உணர்கிறீர்கள்?",
    },
    postCheckIn: {
      title: "சிறந்த வேலை! வாருங்கள், சரிபார்ப்பு செய்வோம்",
    },
    activity: {
      taskOf: "பணி {current} இல் {total}",
      activityOf: "செயல்பாடு {current} இல் {total}",
      completeTask: "பணியை முடிக்கவும்",
    },
    report: {
      sessionComplete: "அமர்வு முடிந்தது!",
      sessionSummary: "அமர்வு சுருக்கம்",
      attentionScore: "கவனம் மதிப்பெண்",
      sessionAverage: "(அமர்வு சராசரி)",
      duration: "காலம்",
      activities: "செயல்பாடுகள்",
      engagement: "ஈடுபாடு",
      moodCheck: "மனநிலை சரிபார்ப்பு",
      before: "முன்",
      after: "பின்",
      insights: "நுண்ணறிவுகள்",
      viewFullReport: "முழு அறிக்கையைப் பார்க்கவும்",
      done: "முடிந்தது",
    },
  },
  // Face Detection Setup
  faceSetup: {
    title: "முகம் கண்டறிதல் அமைப்பு",
    instructions: "சட்டத்தின் நடுவில் உங்கள் முகத்தை வைக்கவும்",
    positionFace: "உங்கள் முகத்தை நடுவில் வைக்கவும்",
    keepStill: "சில வினாடிகள் அசையாமல் இருங்கள்",
    detecting: "முகம் கண்டறியப்படுகிறது...",
    detected: "முகம் கண்டறியப்பட்டது!",
    complete: "அமைப்பு முடிந்தது!",
    skip: "தவிர்க்கவும்",
    continue: "தொடரவும்",
    error: {
      permissionDenied: "கேமரா அணுகல் மறுக்கப்பட்டது. தயவுசெய்து உங்கள் உலாவி அமைப்புகளில் கேமரா அணுகலுக்கான அனுமதியை வழங்கவும்.",
      permissionDeniedNative: "கேமரா அனுமதி மறுக்கப்பட்டது. தயவுசெய்து உங்கள் சாதன அமைப்புகளில் கேமரா அணுகலை இயக்கவும் (அமைப்புகள் > பயன்பாடுகள் > கோமல் > அனுமதிகள்).",
      noCamera: "கேமரா எதுவும் கிடைக்கவில்லை. தயவுசெய்து உங்கள் சாதனத்தில் கேமரா உள்ளதை உறுதிப்படுத்தவும்.",
      cameraError: "கேமரா அணுகல் பிழை. தயவுசெய்து மீண்டும் முயற்சிக்கவும் அல்லது உங்கள் சாதன அமைப்புகளைச் சரிபார்க்கவும்.",
    },
  },
  // Eye Calibration
  calibration: {
    title: "கண் அளவீட்டு",
    instructions: "ஒவ்வொரு புள்ளியும் தோன்றும்போது, அதைப் பாருங்கள். உங்கள் தலையை அசையாமல் வைத்து, உங்கள் கண்களை மட்டும் நகர்த்தவும்.",
    lookAtPoint: "புள்ளியைப் பாருங்கள்",
    pointOf: "புள்ளி {current} இல் {total}",
    calibrating: "அளவீடு செய்யப்படுகிறது...",
    complete: "அளவீட்டு முடிந்தது!",
    quality: {
      title: "அளவீட்டு தரம்",
      accuracy: "துல்லியம்",
      precision: "துல்லியம்",
      reliability: "நம்பகத்தன்மை",
      coverage: "உள்ளடக்கம்",
      continue: "தொடரவும்",
      recalibrate: "மீண்டும் அளவீடு செய்யவும்",
    },
    skip: "தவிர்க்கவும்",
    error: {
      failed: "அளவீட்டு தோல்வியடைந்தது. தயவுசெய்து மீண்டும் முயற்சிக்கவும்.",
      lowQuality: "அளவீட்டு தரம் குறைவாக இருக்கலாம். மீண்டும் அளவீடு செய்வதைக் கவனியுங்கள்.",
    },
  },
  // Session Tracker
  tracker: {
    attention: "கவனம்",
    mood: "மனநிலை",
    trackingActive: "கண்காணிப்பு செயலில்",
    initializing: "தொடங்கப்படுகிறது...",
  },
};

