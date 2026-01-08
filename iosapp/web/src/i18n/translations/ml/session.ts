/**
 * Malayalam - Session Translations
 */

export const session = {
  title: "സെഷൻ",
  startSession: "സെഷൻ ആരംഭിക്കുക",
  endSession: "സെഷൻ അവസാനിപ്പിക്കുക",
  sessionDuration: "സെഷൻ കാലാവധി",
  sessionScore: "സെഷൻ സ്കോർ",
  sessionSummary: "സെഷൻ സംഗ്രഹം",
  takeBreak: "ഇടവേള എടുക്കുക",
  continueSession: "സെഷൻ തുടരുക",
  // Session Flow
  flow: {
    steps: {
      setup: "സെറ്റപ്പ്",
      checkIn: "ചെക്ക്-ഇൻ",
      activity: "പ്രവർത്തനം",
      review: "വിമർശനം",
    },
    preCheckIn: {
      title: "ഇന്ന് നിങ്ങൾ എങ്ങനെ അനുഭവിക്കുന്നു?",
    },
    postCheckIn: {
      title: "മികച്ച ജോലി! നമുക്ക് ചെക്ക്-ഇൻ ചെയ്യാം",
    },
    activity: {
      taskOf: "ടാസ്‌ക്ക് {current} ന്റെ {total}",
      activityOf: "പ്രവർത്തനം {current} ന്റെ {total}",
      completeTask: "ടാസ്‌ക്ക് പൂർത്തിയാക്കുക",
    },
    report: {
      sessionComplete: "സെഷൻ പൂർത്തിയായി!",
      sessionSummary: "സെഷൻ സംഗ്രഹം",
      attentionScore: "ശ്രദ്ധ സ്കോർ",
      sessionAverage: "(സെഷൻ ശരാശരി)",
      duration: "കാലാവധി",
      activities: "പ്രവർത്തനങ്ങൾ",
      engagement: "ഇടപെടൽ",
      moodCheck: "മൂഡ് ചെക്ക്",
      before: "മുമ്പ്",
      after: "ശേഷം",
      insights: "ഉൾക്കാഴ്ചകൾ",
      viewFullReport: "പൂർണ്ണ റിപ്പോർട്ട് കാണുക",
      done: "പൂർത്തിയായി",
    },
  },
  // Face Detection Setup
  faceSetup: {
    title: "മുഖം തിരിച്ചറിയൽ സെറ്റപ്പ്",
    instructions: "ഫ്രെയിമിന്റെ മധ്യത്തിൽ നിങ്ങളുടെ മുഖം സ്ഥാപിക്കുക",
    positionFace: "നിങ്ങളുടെ മുഖം മധ്യത്തിൽ സ്ഥാപിക്കുക",
    keepStill: "കുറച്ച് സെക്കൻഡുകൾ നിശ്ചലമായി നിൽക്കുക",
    detecting: "മുഖം തിരിച്ചറിയുന്നു...",
    detected: "മുഖം തിരിച്ചറിഞ്ഞു!",
    complete: "സെറ്റപ്പ് പൂർത്തിയായി!",
    skip: "ഒഴിവാക്കുക",
    continue: "തുടരുക",
    error: {
      permissionDenied: "കാമറ പ്രവേശനം നിരസിച്ചു. ദയവായി നിങ്ങളുടെ ബ്രൗസർ സെറ്റിംഗുകളിൽ കാമറ പ്രവേശനത്തിന് അനുമതി നൽകുക.",
      permissionDeniedNative: "കാമറ അനുമതി നിരസിച്ചു. ദയവായി നിങ്ങളുടെ ഉപകരണ സെറ്റിംഗുകളിൽ കാമറ പ്രവേശനം പ്രവർത്തനക്ഷമമാക്കുക (സെറ്റിംഗുകൾ > ആപ്പുകൾ > കോമൽ > അനുമതികൾ).",
      noCamera: "കാമറ കണ്ടെത്തിയില്ല. ദയവായി നിങ്ങളുടെ ഉപകരണത്തിൽ കാമറ ഉണ്ടെന്ന് ഉറപ്പാക്കുക.",
      cameraError: "കാമറ പ്രവേശന പിശക്. ദയവായി വീണ്ടും ശ്രമിക്കുക അല്ലെങ്കിൽ നിങ്ങളുടെ ഉപകരണ സെറ്റിംഗുകൾ പരിശോധിക്കുക.",
    },
  },
  // Eye Calibration
  calibration: {
    title: "കണ്ണ് കാലിബ്രേഷൻ",
    instructions: "ഓരോ പോയിന്റും ദൃശ്യമാകുമ്പോൾ, അതിലേക്ക് നോക്കുക. നിങ്ങളുടെ തല നിശ്ചലമായി സൂക്ഷിക്കുക, കണ്ണുകൾ മാത്രം നീക്കുക.",
    lookAtPoint: "പോയിന്റിലേക്ക് നോക്കുക",
    pointOf: "പോയിന്റ് {current} ന്റെ {total}",
    calibrating: "കാലിബ്രേറ്റ് ചെയ്യുന്നു...",
    complete: "കാലിബ്രേഷൻ പൂർത്തിയായി!",
    quality: {
      title: "കാലിബ്രേഷൻ ഗുണനിലവാരം",
      accuracy: "കൃത്യത",
      precision: "കൃത്യത",
      reliability: "വിശ്വാസ്യത",
      coverage: "കവറേജ്",
      continue: "തുടരുക",
      recalibrate: "വീണ്ടും കാലിബ്രേറ്റ് ചെയ്യുക",
    },
    skip: "ഒഴിവാക്കുക",
    error: {
      failed: "കാലിബ്രേഷൻ പരാജയപ്പെട്ടു. ദയവായി വീണ്ടും ശ്രമിക്കുക.",
      lowQuality: "കാലിബ്രേഷൻ ഗുണനിലവാരം കുറവായിരിക്കാം. വീണ്ടും കാലിബ്രേഷൻ പരിഗണിക്കുക.",
    },
  },
  // Session Tracker
  tracker: {
    attention: "ശ്രദ്ധ",
    mood: "മൂഡ്",
    trackingActive: "ട്രാക്കിംഗ് സജീവമാണ്",
    initializing: "ആരംഭിക്കുന്നു...",
  },
};

