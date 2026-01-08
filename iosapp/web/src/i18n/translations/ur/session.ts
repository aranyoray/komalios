/**
 * Urdu - Session Translations
 */

export const session = {
  title: "سیشن",
  startSession: "سیشن شروع کریں",
  endSession: "سیشن ختم کریں",
  sessionDuration: "سیشن کی مدت",
  sessionScore: "سیشن اسکور",
  sessionSummary: "سیشن کا خلاصہ",
  takeBreak: "وقفہ لیں",
  continueSession: "سیشن جاری رکھیں",
  // Session Flow
  flow: {
    steps: {
      setup: "سیٹ اپ",
      checkIn: "چیک-ان",
      activity: "سرگرمی",
      review: "جائزہ",
    },
    preCheckIn: {
      title: "آج آپ کیسا محسوس کر رہے ہیں؟",
    },
    postCheckIn: {
      title: "شاندار کام! چلیں، چیک-ان کریں",
    },
    activity: {
      taskOf: "کام {current} میں سے {total}",
      activityOf: "سرگرمی {current} میں سے {total}",
      completeTask: "کام مکمل کریں",
    },
    report: {
      sessionComplete: "سیشن مکمل!",
      sessionSummary: "سیشن کا خلاصہ",
      attentionScore: "توجہ اسکور",
      sessionAverage: "(سیشن اوسط)",
      duration: "دورانیہ",
      activities: "سرگرمیاں",
      engagement: "مصروفیت",
      moodCheck: "موڈ چیک",
      before: "پہلے",
      after: "بعد",
      insights: "بصیرتیں",
      viewFullReport: "مکمل رپورٹ دیکھیں",
      done: "مکمل",
    },
  },
  // Face Detection Setup
  faceSetup: {
    title: "چہرہ پہچان سیٹ اپ",
    instructions: "فریم کے وسط میں اپنا چہرہ رکھیں",
    positionFace: "اپنا چہرہ وسط میں رکھیں",
    keepStill: "کچھ سیکنڈ کے لیے ساکن رہیں",
    detecting: "چہرہ پہچانا جا رہا ہے...",
    detected: "چہرہ پہچان لیا گیا!",
    complete: "سیٹ اپ مکمل!",
    skip: "چھوڑ دیں",
    continue: "جاری رکھیں",
    error: {
      permissionDenied: "کیمرہ تک رسائی مسترد۔ براہ کرم اپنے براؤزر کی ترتیبات میں کیمرہ تک رسائی کی اجازت دیں۔",
      permissionDeniedNative: "کیمرہ کی اجازت مسترد۔ براہ کرم اپنے ڈیوائس کی ترتیبات میں کیمرہ تک رسائی فعال کریں (ترتیبات > ایپس > کومل > اجازتیں)۔",
      noCamera: "کوئی کیمرہ نہیں ملا۔ براہ کرم یقینی بنائیں کہ آپ کے ڈیوائس میں کیمرہ موجود ہے۔",
      cameraError: "کیمرہ تک رسائی میں خرابی۔ براہ کرم دوبارہ کوشش کریں یا اپنے ڈیوائس کی ترتیبات چیک کریں۔",
    },
  },
  // Eye Calibration
  calibration: {
    title: "آنکھ کیلیبریشن",
    instructions: "ہر نقطہ نظر آنے پر، اس کی طرف دیکھیں۔ اپنا سر ساکن رکھیں اور صرف اپنی آنکھیں حرکت دیں۔",
    lookAtPoint: "نقطہ کی طرف دیکھیں",
    pointOf: "نقطہ {current} میں سے {total}",
    calibrating: "کیلیبریٹ ہو رہا ہے...",
    complete: "کیلیبریشن مکمل!",
    quality: {
      title: "کیلیبریشن کی معیار",
      accuracy: "درستگی",
      precision: "درستگی",
      reliability: "قابل اعتمادیت",
      coverage: "کوریج",
      continue: "جاری رکھیں",
      recalibrate: "دوبارہ کیلیبریٹ کریں",
    },
    skip: "چھوڑ دیں",
    error: {
      failed: "کیلیبریشن ناکام۔ براہ کرم دوبارہ کوشش کریں۔",
      lowQuality: "کیلیبریشن کا معیار کم ہو سکتا ہے۔ دوبارہ کیلیبریشن پر غور کریں۔",
    },
  },
  // Session Tracker
  tracker: {
    attention: "توجہ",
    mood: "موڈ",
    trackingActive: "ٹریکنگ فعال",
    initializing: "شروع ہو رہا ہے...",
  },
};

