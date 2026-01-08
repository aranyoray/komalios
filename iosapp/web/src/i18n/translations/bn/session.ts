/**
 * Bengali - Session Translations
 */

export const session = {
  title: 'সেশন',
  startSession: 'সেশন শুরু করুন',
  endSession: 'সেশন শেষ করুন',
  sessionDuration: 'সেশনের সময়কাল',
  sessionScore: 'সেশন স্কোর',
  sessionSummary: 'সেশন সারাংশ',
  takeBreak: 'বিরতি নিন',
  continueSession: 'সেশন চালিয়ে যান',
  // Session Flow
  flow: {
    steps: {
      setup: 'সেটআপ',
      checkIn: 'চেক-ইন',
      activity: 'কার্যক্রম',
      review: 'পর্যালোচনা',
    },
    preCheckIn: {
      title: 'আজ আপনি কেমন অনুভব করছেন?',
    },
    postCheckIn: {
      title: 'দুর্দান্ত কাজ! আসুন চেক-ইন করি',
    },
    activity: {
      taskOf: 'কাজ {current} এর {total}',
      activityOf: 'কার্যক্রম {current} এর {total}',
      completeTask: 'কাজ সম্পন্ন করুন',
    },
    report: {
      sessionComplete: 'সেশন সম্পন্ন!',
      sessionSummary: 'সেশন সারাংশ',
      attentionScore: 'মনোযোগ স্কোর',
      sessionAverage: '(সেশন গড়)',
      duration: 'সময়কাল',
      activities: 'কার্যক্রম',
      engagement: 'নিযুক্তি',
      moodCheck: 'মুড চেক',
      before: 'পূর্বে',
      after: 'পরে',
      insights: 'অনুভূতি',
      viewFullReport: 'সম্পূর্ণ রিপোর্ট দেখুন',
      done: 'সম্পন্ন',
    },
  },
  // Face Detection Setup
  faceSetup: {
    title: 'মুখ সনাক্তকরণ সেটআপ',
    instructions: 'ফ্রেমের কেন্দ্রে আপনার মুখ রাখুন',
    positionFace: 'কেন্দ্রে আপনার মুখ রাখুন',
    keepStill: 'কয়েক সেকেন্ড স্থির থাকুন',
    detecting: 'মুখ সনাক্ত করা হচ্ছে...',
    detected: 'মুখ সনাক্ত করা হয়েছে!',
    complete: 'সেটআপ সম্পন্ন!',
    skip: 'এড়িয়ে যান',
    continue: 'চালিয়ে যান',
    error: {
      permissionDenied: 'ক্যামেরা অ্যাক্সেস অস্বীকার করা হয়েছে। অনুগ্রহ করে আপনার ব্রাউজার সেটিংসে ক্যামেরা অ্যাক্সেস অনুমোদন করুন।',
      permissionDeniedNative: 'ক্যামেরা অনুমতি অস্বীকার করা হয়েছে। অনুগ্রহ করে আপনার ডিভাইস সেটিংসে ক্যামেরা অ্যাক্সেস সক্রিয় করুন (সেটিংস > অ্যাপস > কোমল > অনুমতি)।',
      noCamera: 'কোন ক্যামেরা পাওয়া যায়নি। অনুগ্রহ করে নিশ্চিত করুন যে আপনার ডিভাইসে একটি ক্যামেরা রয়েছে।',
      cameraError: 'ক্যামেরা অ্যাক্সেস ত্রুটি। অনুগ্রহ করে আবার চেষ্টা করুন বা আপনার ডিভাইস সেটিংস পরীক্ষা করুন।',
    },
  },
  // Eye Calibration
  calibration: {
    title: 'চোখ ক্যালিব্রেশন',
    instructions: 'প্রতিটি বিন্দু উপস্থিত হওয়ার সাথে সাথে তাতে তাকান। আপনার মাথা স্থির রাখুন এবং শুধুমাত্র আপনার চোখ সরান।',
    lookAtPoint: 'বিন্দুতে তাকান',
    pointOf: 'বিন্দু {current} এর {total}',
    calibrating: 'ক্যালিব্রেট করা হচ্ছে...',
    complete: 'ক্যালিব্রেশন সম্পন্ন!',
    quality: {
      title: 'ক্যালিব্রেশন মান',
      accuracy: 'নির্ভুলতা',
      precision: 'সূক্ষ্মতা',
      reliability: 'নির্ভরযোগ্যতা',
      coverage: 'কভারেজ',
      continue: 'চালিয়ে যান',
      recalibrate: 'পুনরায় ক্যালিব্রেট করুন',
    },
    skip: 'এড়িয়ে যান',
    error: {
      failed: 'ক্যালিব্রেশন ব্যর্থ হয়েছে। অনুগ্রহ করে আবার চেষ্টা করুন।',
      lowQuality: 'ক্যালিব্রেশন মান কম হতে পারে। পুনরায় ক্যালিব্রেশন বিবেচনা করুন।',
    },
  },
  // Session Tracker
  tracker: {
    attention: 'মনোযোগ',
    mood: 'মুড',
    trackingActive: 'ট্র্যাকিং সক্রিয়',
    initializing: 'আরম্ভ করা হচ্ছে...',
  },
};
