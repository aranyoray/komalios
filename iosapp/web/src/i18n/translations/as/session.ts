/**
 * Assamese - Session Translations
 */

export const session = {
  title: "অধিবেশন",
  startSession: "অধিবেশন আৰম্ভ কৰক",
  endSession: "অধিবেশন সমাপ্ত কৰক",
  sessionDuration: "অধিবেশনৰ সময়কাল",
  sessionScore: "অধিবেশনৰ স্কোৰ",
  sessionSummary: "অধিবেশনৰ সাৰাংশ",
  takeBreak: "বিৰতি লওক",
  continueSession: "অধিবেশন অব্যাহত ৰাখক",
  // Session Flow
  flow: {
    steps: {
      setup: "ছেটআপ",
      checkIn: "চেক-ইন",
      activity: "কাৰ্যকলাপ",
      review: "পৰ্যালোচনা",
    },
    preCheckIn: {
      title: "আজি আপুনি কেনে অনুভৱ কৰিছে?",
    },
    postCheckIn: {
      title: "বহুত ভাল কাম! আহক চেক-ইন কৰোঁ",
    },
    activity: {
      taskOf: "কাৰ্য {current} ৰ {total}",
      activityOf: "কাৰ্যকলাপ {current} ৰ {total}",
      completeTask: "কাৰ্য সম্পূৰ্ণ কৰক",
    },
    report: {
      sessionComplete: "অধিবেশন সম্পূৰ্ণ!",
      sessionSummary: "অধিবেশনৰ সাৰাংশ",
      attentionScore: "মনোযোগ স্কোৰ",
      sessionAverage: "(অধিবেশন গড়)",
      duration: "সময়কাল",
      activities: "কাৰ্যকলাপবোৰ",
      engagement: "সংযুক্তি",
      moodCheck: "মুড চেক",
      before: "আগতে",
      after: "পিছত",
      insights: "অন্তৰ্দৃষ্টি",
      viewFullReport: "সম্পূৰ্ণ প্ৰতিবেদন চাওক",
      done: "সম্পূৰ্ণ",
    },
  },
  // Face Detection Setup
  faceSetup: {
    title: "মুখ চিনাক্তকৰণ ছেটআপ",
    instructions: "ফ্ৰেমৰ কেন্দ্ৰত আপোনাৰ মুখ ৰাখক",
    positionFace: "আপোনাৰ মুখ কেন্দ্ৰত ৰাখক",
    keepStill: "কিছু ছেকেণ্ডৰ বাবে স্থিৰ হৈ থাকক",
    detecting: "মুখ চিনাক্ত কৰা হৈছে...",
    detected: "মুখ চিনাক্ত কৰা হ\ল!",
    complete: "ছেটআপ সম্পূৰ্ণ!",
    skip: "এৰি দিয়ক",
    continue: "অব্যাহত ৰাখক",
    error: {
      permissionDenied: "কেমেৰা প্ৰৱেশ অস্বীকৃত। অনুগ্ৰহ কৰি আপোনাৰ ব্ৰাউজাৰ ছেটিংবোৰত কেমেৰা প্ৰৱেশৰ অনুমতি দিয়ক।",
      permissionDeniedNative: "কেমেৰা অনুমতি অস্বীকৃত। অনুগ্ৰহ কৰি আপোনাৰ ডিভাইছ ছেটিংবোৰত কেমেৰা প্ৰৱেশ সক্ষম কৰক (ছেটিংবোৰ > এপবোৰ > কোমল > অনুমতিবোৰ)।",
      noCamera: "কোনো কেমেৰা পোৱা নগ\ল। অনুগ্ৰহ কৰি নিশ্চিত কৰক যে আপোনাৰ ডিভাইছত কেমেৰা আছে।",
      cameraError: "কেমেৰা প্ৰৱেশ ত্ৰুটি। অনুগ্ৰহ কৰি পুনৰ চেষ্টা কৰক বা আপোনাৰ ডিভাইছ ছেটিংবোৰ পৰীক্ষা কৰক।",
    },
  },
  // Eye Calibration
  calibration: {
    title: "চকু কেলিব্ৰেছন",
    instructions: "প্ৰতিটো বিন্দু দেখা দিয়ালে তালৈ চাওক। আপোনাৰ মূৰ স্থিৰ ৰাখক আৰু কেৱল আপোনাৰ চকুহাল লৰাওক।",
    lookAtPoint: "বিন্দুটোলৈ চাওক",
    pointOf: "বিন্দু {current} ৰ {total}",
    calibrating: "কেলিব্ৰেট কৰা হৈছে...",
    complete: "কেলিব্ৰেছন সম্পূৰ্ণ!",
    quality: {
      title: "কেলিব্ৰেছন গুণাগুণ",
      accuracy: "নিৰ্ভুলতা",
      precision: "সূক্ষ্মতা",
      reliability: "নিৰ্ভৰযোগ্যতা",
      coverage: "কভাৰেজ",
      continue: "অব্যাহত ৰাখক",
      recalibrate: "পুনৰ কেলিব্ৰেট কৰক",
    },
    skip: "এৰি দিয়ক",
    error: {
      failed: "কেলিব্ৰেছন ব্যৰ্থ। অনুগ্ৰহ কৰি পুনৰ চেষ্টা কৰক।",
      lowQuality: "কেলিব্ৰেছন গুণাগুণ কম হ\ব পাৰে। পুনৰ কেলিব্ৰেছনৰ কথা বিবেচনা কৰক।",
    },
  },
  // Session Tracker
  tracker: {
    attention: "মনোযোগ",
    mood: "মুড",
    trackingActive: "ট্ৰেকিং সক্ৰিয়",
    initializing: "আৰম্ভ কৰা হৈছে...",
  },
};

