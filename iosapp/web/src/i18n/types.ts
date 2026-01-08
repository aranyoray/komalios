/**
 * Translation Types
 * Central type definitions for all translations
 */

export interface Translation {
  // Language metadata
  languageName: string;
  languageNameInScript: string;

  // Feature-based translations
  common: CommonTranslations;
  auth: AuthTranslations;
  nav: NavTranslations;
  buttons: ButtonTranslations;
  onboarding: OnboardingTranslations;
  reports: ReportTranslations;
  settings: SettingsTranslations;
  learners: LearnerTranslations;
  session: SessionTranslations;
  chat: ChatTranslations;
  messages: MessageTranslations;
  profileSelect: ProfileSelectTranslations;
  createProfile: CreateProfileTranslations;
  learner: LearnerScreenTranslations;
  profile: ProfileTranslations;
  editLearnerProfile: EditLearnerProfileTranslations;
  parentDashboard: ParentDashboardTranslations;
}

// Common translations (used across multiple features)
export interface CommonTranslations {
  loading: string;
  error: string;
  success: string;
  confirm: string;
  warning: string;
  noDataAvailable: string;
  tryAgain: string;
  save: string;
  cancel: string;
  delete: string;
  edit: string;
  close: string;
  back: string;
  next: string;
  previous: string;
  select: string;
  selectLanguage: string;
  searchLanguages: string;
  noLanguagesFound: string;
  modeSelection: {
    title: string;
    subtitle: string;
    child: string;
    family: string;
    childDescription: string;
    familyDescription: string;
    selectMode: string;
  };
}

// Authentication translations
export interface AuthTranslations {
  signIn: string;
  signUp: string;
  signOut: string;
  email: string;
  password: string;
  phoneNumber: string;
  confirmPassword: string;
  forgotPassword: string;
  resetPassword: string;
  enterOTP: string;
  sendOTP: string;
  verifyOTP: string;
  continueWithGoogle: string;
  continueWithApple: string;
  continueWithPhone: string;
  continueWithEmail: string;
  alreadyHaveAccount: string;
  dontHaveAccount: string;
  selectLanguage: string;
  // Sign In page
  signInPage: {
    tagline: string;
    createAccount: string;
    enterEmailAndPassword: string;
    enterValidEmail: string;
    signInFailed: string;
    noAccountFound: string;
    fillAllFields: string;
    passwordMinLength: string;
    passwordsDoNotMatch: string;
    checkEmailVerify: string;
    accountCreated: string;
    signUpFailed: string;
    accountAlreadyExists: string;
    oauthSignInFailed: string;
    atLeast6Characters: string;
    termsAndPrivacy: string;
    designedForAges: string;
  };
  // Forgot Password page
  forgotPasswordPage: {
    title: string;
    subtitle: string;
    backToSignIn: string;
    enterEmailDescription: string;
    enterEmailAddress: string;
    sendResetLink: string;
    rememberPassword: string;
    checkEmail: string;
    resetCodeSent: string;
    didntReceiveCode: string;
    enterResetCode: string;
    tryAgain: string;
    failedToSendCode: string;
  };
  // Reset Password page
  resetPasswordPage: {
    title: string;
    subtitle: string;
    backToSignIn: string;
    enterResetCode: string;
    setNewPassword: string;
    enterValidCode: string;
    invalidOrExpiredCode: string;
    failedToVerifyCode: string;
    fillAllFields: string;
    codeExpired: string;
    passwordResetSuccess: string;
    newPassword: string;
    confirmNewPassword: string;
    passwordResetSuccessMessage: string;
  };
  // Email Confirm page
  emailConfirmPage: {
    verifyingEmail: string;
    verifyingYourEmail: string;
    emailConfirmed: string;
    emailConfirmedSuccess: string;
    emailAlreadyConfirmed: string;
    redirectingToSignIn: string;
    verificationFailed: string;
    linkExpired: string;
    missingToken: string;
    failedToVerify: string;
    goToSignIn: string;
    goHome: string;
  };
}

// Navigation translations
export interface NavTranslations {
  home: string;
  sessions: string;
  reports: string;
  settings: string;
  learners: string;
  learner: string;
  parentDashboard: string;
  profile: string;
  logout: string;
  openMenu: string;
  closeMenu: string;
  chat: string;
  activities: string;
  progress: string;
}

// Button translations
export interface ButtonTranslations {
  save: string;
  cancel: string;
  delete: string;
  edit: string;
  close: string;
  next: string;
  previous: string;
  start: string;
  pause: string;
  resume: string;
  finish: string;
  submit: string;
  back: string;
  select: string;
  confirm: string;
}

// Onboarding translations
export interface OnboardingTranslations {
  skip: string;
  next: string;
  back: string;
  getStarted: string;
  goToProfileSelection: string;
  steps: {
    welcome: {
      title: string;
      subtitle: string;
      description: string;
    };
    personalized: {
      title: string;
      subtitle: string;
      description: string;
    };
    progress: {
      title: string;
      subtitle: string;
      description: string;
    };
    secure: {
      title: string;
      subtitle: string;
      description: string;
    };
  };
}

// Reports translations
export interface ReportTranslations {
  title: string;
  progressReports: string;
  detailedAnalytics: string;
  selectLearnerToView: string;
  dashboardTab: string;
  extendedReportTab: string;
  liveAnalytics: string;
  realTimeUpdates: string;
  child: string;
  conciseReportTab: string;
  dailyReport: string;
  monthlyReport: string;
  selectDate: string;
  selectLearner: string;
  noReportsAvailable: string;
  generatingReport: string;
  domains: {
    socialCommunication: string;
    emotionalIntelligence: string;
    cognitive: string;
    lifeSkills: string;
    language: string;
  };
  subdomains: {
    jointAttention: string;
    socialReciprocity: string;
    emotionRecognition: string;
    emotionRegulation: string;
    attentionControl: string;
    workingMemory: string;
    problemSolving: string;
    fineMotor: string;
    grossMotor: string;
    vocabulary: string;
    comprehension: string;
  };
  metrics: {
    score: string;
    improvement: string;
    stability: string;
    engagement: string;
    duration: string;
    accuracy: string;
    attempts: string;
    completed: string;
  };
  timePeriods: {
    today: string;
    yesterday: string;
    thisWeek: string;
    thisMonth: string;
    last7Days: string;
    last30Days: string;
  };
  dashboard: {
    progressDashboard: string;
    comprehensiveAnalytics: string;
    failedToLoad: string;
    sessions: string;
    attention: string;
    engagement: string;
    completion: string;
    minTotal: string;
    dayStreak: string;
    attentionEngagementTrend: string;
    emotionDistribution: string;
    focusAreaProgress: string;
    sessionsLabel: string;
    dailySessionTime: string;
    durationMin: string;
    keyInsights: string;
  };
  extendedReport: {
    loading: string;
    executiveSummary: string;
    keyMetricsAtGlance: string;
    overallAttentionScore: string;
    averageAcrossSessions: string;
    totalSessions: string;
    minutesTotalPractice: string;
    dayStreak: string;
    consecutiveDays: string;
    skillsOverview: string;
    performanceVsBenchmarks: string;
    metric: string;
    value: string;
    target: string;
    status: string;
    focusAreaBreakdown: string;
    focusArea: string;
    successRate: string;
    recentSessionDetails: string;
    date: string;
    duration: string;
    recommendations: string;
  };
  conciseReport: {
    sessionSnapshot: string;
    completed: string;
    focusArea: string;
    completedTasks: string;
    tasks: string;
    engagement: string;
    keySkillPractised: string;
    highlight: string;
    quickMetrics: string;
    attentionConcentration: string;
    attentionScore: string;
    socialGaze: string;
    emotionExpression: string;
    positiveExpressions: string;
    frustrationEpisodes: string;
    touchMotorBehavior: string;
    accurateTouches: string;
    hesitationTaps: string;
    responsePattern: string;
    initiationDelay: string;
    retryAttempts: string;
    whatThisMeans: string;
    smallHomePractice: string;
    ask: string;
    nextTinyGoal: string;
    share: string;
    whatsapp: string;
    sms: string;
    shareReport: string;
    sessionReport: string;
  };
}

// Settings translations
export interface SettingsTranslations {
  title: string;
  language: string;
  notifications: string;
  privacy: string;
  account: string;
  helpSupport: string;
  aboutApp: string;
  version: string;
  changeLanguage: string;
  darkMode: string;
  soundEffects: string;
  vibration: string;
  dataPrivacy: string;
  parentalConsent: string;
  deleteAccount: string;
  logout: string;
}

// Learner translations
export interface LearnerTranslations {
  title: string;
  addLearner: string;
  editLearner: string;
  deleteLearner: string;
  learnerName: string;
  age: string;
  grade: string;
  selectAge: string;
  enterName: string;
}

// Session translations
export interface SessionTranslations {
  title: string;
  startSession: string;
  endSession: string;
  sessionDuration: string;
  sessionScore: string;
  sessionSummary: string;
  takeBreak: string;
  continueSession: string;
  // Session Flow
  flow: {
    steps: {
      setup: string;
      checkIn: string;
      activity: string;
      review: string;
    };
    preCheckIn: {
      title: string;
    };
    postCheckIn: {
      title: string;
    };
    activity: {
      taskOf: string;
      activityOf: string;
      completeTask: string;
    };
    report: {
      sessionComplete: string;
      sessionSummary: string;
      attentionScore: string;
      sessionAverage: string;
      duration: string;
      activities: string;
      engagement: string;
      moodCheck: string;
      before: string;
      after: string;
      insights: string;
      viewFullReport: string;
      done: string;
    };
  };
  // Face Detection Setup
  faceSetup: {
    title: string;
    instructions: string;
    positionFace: string;
    keepStill: string;
    detecting: string;
    detected: string;
    complete: string;
    skip: string;
    continue: string;
    error: {
      permissionDenied: string;
      permissionDeniedNative: string;
      noCamera: string;
      cameraError: string;
    };
  };
  // Eye Calibration
  calibration: {
    title: string;
    instructions: string;
    lookAtPoint: string;
    pointOf: string;
    calibrating: string;
    complete: string;
    quality: {
      title: string;
      accuracy: string;
      precision: string;
      reliability: string;
      coverage: string;
      continue: string;
      recalibrate: string;
    };
    skip: string;
    error: {
      failed: string;
      lowQuality: string;
    };
  };
  // Session Tracker
  tracker: {
    attention: string;
    mood: string;
    trackingActive: string;
    initializing: string;
  };
}

// Chat translations
export interface ChatTranslations {
  title: string;
  typePlaceholder: string;
  komalTyping: string;
  startConversation: string;
  endConversation: string;
}

// Message translations
export interface MessageTranslations {
  loading: string;
  error: string;
  success: string;
  confirm: string;
  warning: string;
  noDataAvailable: string;
  tryAgain: string;
  sessionEnded: string;
  welcomeBack: string;
}

// Profile selection translations
export interface ProfileSelectTranslations {
  title: string;
  subtitle: string;
  age: string;
  noProfiles: string;
  noProfilesDescription: string;
  createFirstProfile: string;
  addChild: string;
  addChildDescription: string;
  guardianMode: string;
  exitParentMode: string;
  enterPinForParent: string;
  enterPinForLearner: string;
  pin: string;
  pinPlaceholder: string;
  pinHelper: string;
  pinError: string;
  pinIncorrect: string;
  pinRequired: string;
  loadError: string;
  userNotFound: string;
  continue: string;
  skills: {
    socialSkills: string;
    emotionIntelligence: string;
    thoughtExpression: string;
    cognitiveGrowth: string;
    lifeSkills: string;
  };
}

// Create profile translations
export interface CreateProfileTranslations {
  title: string;
  subtitle: string;
  childName: string;
  age: string;
  ageRequired: string;
  ageLabel: {
    lessThan3: string;
    moreThan15: string;
    yearsOld: string;
  };
  focusAreas: string;
  focusAreasRequired: string;
  focusAreasDescription: string;
  diagnosis: string;
  diagnosisOptional: string;
  diagnosisDescription: string;
  selectAreas: string;
  selectAllThatApply: string;
  fillRequiredFields: string;
  creating: string;
  createProfile: string;
  userNotFound: string;
  unableToDetermineUserId: string;
  failedToCreate: string;
  diagnoses: {
    autism: string;
    adhd: string;
    anxiety: string;
    developmentalDelay: string;
    sensoryProcessing: string;
    learningDisability: string;
    speechDelay: string;
    other: string;
  };
  skills: {
    socialSkills: string;
    emotionIntelligence: string;
    thoughtExpression: string;
    cognitiveGrowth: string;
    lifeSkills: string;
  };
}

// Learner screen translations
export interface LearnerScreenTranslations {
  greeting: string;
  startSession: string;
  sessionDescription: string;
  chooseActivity: string;
  mute: string;
  unmute: string;
  parentMode: string;
  moodResponses: {
    sad: string;
    happy: string;
    neutral: string;
  };
  focusAreaMessage: string;
  skills: {
    socialSkills: string;
    emotionIntelligence: string;
    thoughtExpression: string;
    cognitiveGrowth: string;
    lifeSkills: string;
  };
}

// Edit learner profile translations
export interface EditLearnerProfileTranslations {
  title: string;
  subtitle: string;
  loadingProfile: string;
  profileUpdatedSuccessfully: string;
  saving: string;
  saveChanges: string;
  learnerProfileNotFound: string;
  learnerProfileIdNotFound: string;
  userRecordNotFound: string;
  failedToLoadProfile: string;
  failedToUpdateProfile: string;
  fillRequiredFields: string;
  // Reuse from createProfile
  childName: string;
  age: string;
  ageRequired: string;
  ageLabel: {
    lessThan3: string;
    moreThan15: string;
    yearsOld: string;
  };
  focusAreas: string;
  focusAreasRequired: string;
  focusAreasDescription: string;
  diagnosis: string;
  diagnosisOptional: string;
  diagnosisDescription: string;
  diagnoses: {
    autism: string;
    adhd: string;
    anxiety: string;
    developmentalDelay: string;
    sensoryProcessing: string;
    learningDisability: string;
    speechDelay: string;
    other: string;
  };
  skills: {
    socialSkills: string;
    emotionIntelligence: string;
    thoughtExpression: string;
    cognitiveGrowth: string;
    lifeSkills: string;
  };
}

// Profile page translations
export interface ProfileTranslations {
  title: string;
  subtitle: string;
  emailAddress: string;
  email: string;
  parentDashboardPin: string;
  parentDashboardPinDescription: string;
  changePin: string;
  setPin: string;
  currentPin: string;
  notSet: string;
  pinSecurityNote: string;
  learnerProfiles: string;
  learnerProfilesDescription: string;
  profile: string;
  profiles: string;
  loadingLearners: string;
  age: string;
  years: string;
  focusAreas: string;
  viewDetails: string;
  noLearnerProfiles: string;
  noLearnerProfilesDescription: string;
  createNewProfile: string;
  parentAccessRequired: string;
  enterPinToAccess: string;
  enterPin: string;
  unlock: string;
  changeParentDashboardPin: string;
  setParentDashboardPin: string;
  pinUpdatedSuccessfully: string;
  newPin: string;
  enter4DigitPin: string;
  enter4DigitPinHelper: string;
  confirmPin: string;
  reEnter4DigitPin: string;
  reEnterPinHelper: string;
  saving: string;
  savePin: string;
  pinMustBe4Digits: string;
  pinsDoNotMatch: string;
  failedToSavePin: string;
  pleaseEnter4DigitPin: string;
  incorrectPin: string;
  deleteLearnerProfile: string;
  deleteWarning: string;
  deleteConfirmation: string;
  yesDelete: string;
  verifyPinToDelete: string;
  enterPinToConfirmDeletion: string;
  failedToDeleteLearner: string;
  userRecordNotFound: string;
  languageSettings: string;
  languageSettingsDescription: string;
  currentLanguage: string;
  changeLanguage: string;
  skills: {
    socialSkills: string;
    emotionIntelligence: string;
    thoughtExpression: string;
    cognitiveGrowth: string;
    lifeSkills: string;
  };
}

// Parent dashboard translations
export interface ParentDashboardTranslations {
  parentAccess: string;
  enterPinToAccess: string;
  unlockDashboard: string;
  backToChildMode: string;
  defaultPin: string;
  incorrectPin: string;
  title: string;
  progressAndAnalytics: string;
  sessionsThisWeek: string;
  avgAttention: string;
  dayStreak: string;
  improvement: string;
  latestSession: string;
  child: string;
}

