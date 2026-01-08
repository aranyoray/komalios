/**
 * Detailed Subdomain Tracking Framework
 *
 * Comprehensive structure for tracking child development across 5 main domains
 * with 15+ subdomains, each with specific observables, tools, and frequencies.
 *
 * Based on evidence-based developmental assessment practices.
 */

export type SessionFrequency =
  | 'every_session'
  | '1-2_per_week'
  | '1_per_week'
  | 'every_alternate_session'
  | 'weekly';

export interface SubdomainDefinition {
  name: string;
  description: string;
  thingsToNote: string[];
  tools: string[];
  sessionFrequency: SessionFrequency;
  ageAppropriate: {
    '3-5': boolean;
    '6-10': boolean;
    '11-15': boolean;
  };
}

export interface DomainDefinition {
  name: string;
  notes: string;
  subdomains: Record<string, SubdomainDefinition>;
}

/**
 * ============================================================================
 * COMPLETE SUBDOMAIN FRAMEWORK
 * ============================================================================
 */

export const SUBDOMAIN_FRAMEWORK: Record<string, DomainDefinition> = {
  social_communication: {
    name: 'Social Communication',
    notes: 'Tracks conversational foundations, reciprocity, joint engagement, and nonverbal communication.',

    subdomains: {
      joint_attention: {
        name: 'Joint Attention',
        description: 'Shared focus on objects, events, or activities with another person',
        thingsToNote: [
          'child looks toward target when prompted',
          'spontaneous gaze shifts shared with avatar',
          'follows pointing gestures',
          'initiates joint attention'
        ],
        tools: [
          'eye_tracking_alignment',
          'gesture_recognition',
          'emoji_check_in_before_and_after_task'
        ],
        sessionFrequency: '1-2_per_week',
        ageAppropriate: {
          '3-5': true,
          '6-10': true,
          '11-15': false, // Less relevant for older children
        },
      },

      turn_taking: {
        name: 'Turn Taking',
        description: 'Ability to alternate roles in conversation or activity',
        thingsToNote: [
          'waits for turn',
          'responds in correct order',
          'hands over conversational floor',
          'avoids interrupting'
        ],
        tools: [
          'tap_sequence_tasks',
          'dialogue_turn_timer',
          'voice_latency_detector'
        ],
        sessionFrequency: '1-2_per_week',
        ageAppropriate: {
          '3-5': true,
          '6-10': true,
          '11-15': true,
        },
      },

      conversation_initiation: {
        name: 'Conversation Initiation',
        description: 'Starting social interactions voluntarily',
        thingsToNote: [
          'voluntary greetings',
          'spontaneous question asking',
          'self-directed engagement'
        ],
        tools: [
          'local_nlp_classifier_for_question_detection',
          'emotion_prompt_cards',
          'emoji_self_report_pre_task'
        ],
        sessionFrequency: '1_per_week',
        ageAppropriate: {
          '3-5': true,
          '6-10': true,
          '11-15': true,
        },
      },

      conversation_repair: {
        name: 'Conversation Repair',
        description: 'Fixing communication breakdowns',
        thingsToNote: [
          'clarification requests',
          'repeating information when misunderstood',
          'self-correction without frustration'
        ],
        tools: [
          'nlp_relevance_checker',
          'latency_and_pause_detector',
          'microexpression_recovery_tracker'
        ],
        sessionFrequency: '1_per_week',
        ageAppropriate: {
          '3-5': false, // Too advanced for young children
          '6-10': true,
          '11-15': true,
        },
      },

      appropriate_responses: {
        name: 'Appropriate Responses',
        description: 'Contextually and emotionally relevant replies',
        thingsToNote: [
          'stays on topic',
          'responds with semantically relevant content',
          'matches emotional tone'
        ],
        tools: [
          'semantic_relevance_nlp',
          'emotion_match_score',
          'three_point_emoji_scale_post_response'
        ],
        sessionFrequency: 'every_alternate_session',
        ageAppropriate: {
          '3-5': true,
          '6-10': true,
          '11-15': true,
        },
      },
    },
  },

  emotional_intelligence: {
    name: 'Emotional Intelligence',
    notes: 'Covers recognising, naming, regulating, and expressing emotions.',

    subdomains: {
      emotion_identification: {
        name: 'Emotion Identification',
        description: 'Recognizing and labeling emotions in self and others',
        thingsToNote: [
          'correctly labels basic emotions',
          'matches emotion to scenario',
          'selects correct emoji for feeling'
        ],
        tools: [
          'emoji_label_tasks',
          'facial_expression_classifier',
          'voice_prosody_mapping'
        ],
        sessionFrequency: 'every_session',
        ageAppropriate: {
          '3-5': true,
          '6-10': true,
          '11-15': true,
        },
      },

      emotion_regulation: {
        name: 'Emotion Regulation',
        description: 'Managing emotional responses effectively',
        thingsToNote: [
          'speed of recovery from negative signs',
          'ability to continue task after error',
          'use of coping prompts'
        ],
        tools: [
          'microexpression_recovery_speed',
          'frustration_signal_detector',
          'regulation_guide_popup'
        ],
        sessionFrequency: '1-2_per_week',
        ageAppropriate: {
          '3-5': true,
          '6-10': true,
          '11-15': true,
        },
      },

      social_empathy: {
        name: 'Social Empathy',
        description: 'Understanding and responding to others\' emotions',
        thingsToNote: [
          'recognises emotions in avatar',
          'responds kindly to cues',
          'reflects others\' feelings'
        ],
        tools: [
          'story_scenarios',
          'avatar_emotion_matching',
          'emoji_choice_check_for_other_person'
        ],
        sessionFrequency: '1_per_week',
        ageAppropriate: {
          '3-5': true,
          '6-10': true,
          '11-15': true,
        },
      },
    },
  },

  cognitive_development: {
    name: 'Cognitive Development',
    notes: 'Measures memory, flexibility, sequencing, and reasoning.',

    subdomains: {
      working_memory: {
        name: 'Working Memory',
        description: 'Holding and manipulating information temporarily',
        thingsToNote: [
          'recalls sequences',
          'remembers multi-step instructions',
          'holds information across turns'
        ],
        tools: [
          'sequence_tap_tasks',
          'prompt_delay_latency_tests',
          'emoji_self-report_of_difficulty'
        ],
        sessionFrequency: '1-2_per_week',
        ageAppropriate: {
          '3-5': true,
          '6-10': true,
          '11-15': true,
        },
      },

      attention_control: {
        name: 'Attention Control',
        description: 'Sustaining and directing focus',
        thingsToNote: [
          'gaze stability',
          'reduced distractibility',
          'sticking to task until end'
        ],
        tools: [
          'gaze_stability_score',
          'off_screen_glance_detector',
          'tap_focus_index'
        ],
        sessionFrequency: 'every_session',
        ageAppropriate: {
          '3-5': true,
          '6-10': true,
          '11-15': true,
        },
      },

      response_readiness: {
        name: 'Response Readiness',
        description: 'Speed and accuracy of reactions',
        thingsToNote: [
          'latency between cue and response',
          'hesitation signals',
          'unnecessary taps'
        ],
        tools: [
          'latency_measurement',
          'tap_error_rate',
          'prosody_hesitation_detector'
        ],
        sessionFrequency: '1-2_per_week',
        ageAppropriate: {
          '3-5': true,
          '6-10': true,
          '11-15': true,
        },
      },
    },
  },

  language_development: {
    name: 'Language Development',
    notes: 'Measures comprehension, expression, fluency, prosody, and vocabulary.',

    subdomains: {
      vocabulary_growth: {
        name: 'Vocabulary Growth',
        description: 'Learning and retaining new words',
        thingsToNote: [
          'new words learned',
          'retention of older words',
          'ability to generalize vocabulary'
        ],
        tools: [
          'local_wordbank_tracker',
          'voice_ai_vocabulary_detection',
          'emoji_rating_for_word_familiarity'
        ],
        sessionFrequency: 'weekly',
        ageAppropriate: {
          '3-5': true,
          '6-10': true,
          '11-15': true,
        },
      },

      fluency_and_prosody: {
        name: 'Fluency and Prosody',
        description: 'Smoothness and natural rhythm of speech',
        thingsToNote: [
          'smoothness of speech',
          'rate consistency',
          'intonation appropriateness'
        ],
        tools: [
          'on_device_prosody_extractor',
          'disfluency_counter',
          'pause_length_scoring'
        ],
        sessionFrequency: '1-2_per_week',
        ageAppropriate: {
          '3-5': true,
          '6-10': true,
          '11-15': true,
        },
      },

      comprehension: {
        name: 'Comprehension',
        description: 'Understanding spoken and written language',
        thingsToNote: [
          'follows verbal instructions',
          'correctly matches text-to-picture',
          'answers comprehension questions'
        ],
        tools: [
          'semantic_consistency_checker',
          'latency_plus_accuracy_mix_score',
          'emoji_understanding_confirmations'
        ],
        sessionFrequency: 'weekly',
        ageAppropriate: {
          '3-5': true,
          '6-10': true,
          '11-15': true,
        },
      },
    },
  },

  life_skills: {
    name: 'Life Skills',
    notes: 'Measures adaptive functioning, decision-making, regulation, and persistence.',

    subdomains: {
      problem_solving: {
        name: 'Problem Solving',
        description: 'Finding solutions through reasoning',
        thingsToNote: [
          'tries alternative strategies',
          'doesn\'t give up quickly',
          'shows reasoning in choices'
        ],
        tools: [
          'multi-path_tasks',
          'exploration_vs_goal_directed_index',
          'self_evaluation_emoji_after_task'
        ],
        sessionFrequency: 'weekly',
        ageAppropriate: {
          '3-5': true,
          '6-10': true,
          '11-15': true,
        },
      },

      task_persistence: {
        name: 'Task Persistence',
        description: 'Staying engaged despite challenges',
        thingsToNote: [
          'works through small mistakes',
          'returns after break',
          'engagement consistency'
        ],
        tools: [
          'engagement_arc_tracker',
          'fatigue_signal_detector',
          'post-task_emoji_motivation_check'
        ],
        sessionFrequency: 'every_alternate_session',
        ageAppropriate: {
          '3-5': true,
          '6-10': true,
          '11-15': true,
        },
      },
    },
  },
};

/**
 * ============================================================================
 * EMOJI CHECK-IN SYSTEM
 * ============================================================================
 */

export interface EmojiCheckIn {
  type: 'feeling' | 'difficulty' | 'motivation' | 'understanding';
  question: string;
  options: EmojiOption[];
  timing: 'pre_task' | 'post_task' | 'mid_session';
}

export interface EmojiOption {
  emoji: string;
  label: string;
  value: number; // 1-5 scale
}

export const EMOJI_CHECKINS: Record<string, EmojiCheckIn> = {
  feeling_pre_task: {
    type: 'feeling',
    question: 'How do you feel right now?',
    options: [
      { emoji: '😊', label: 'Happy', value: 5 },
      { emoji: '🙂', label: 'Okay', value: 4 },
      { emoji: '😐', label: 'Neutral', value: 3 },
      { emoji: '☹️', label: 'Sad', value: 2 },
      { emoji: '😢', label: 'Very Sad', value: 1 },
    ],
    timing: 'pre_task',
  },

  difficulty_post_task: {
    type: 'difficulty',
    question: 'How difficult was this task for you?',
    options: [
      { emoji: '🚶', label: 'Very Easy', value: 1 },
      { emoji: '🏃', label: 'Easy', value: 2 },
      { emoji: '🧗', label: 'Medium', value: 3 },
      { emoji: '⛰️', label: 'Hard', value: 4 },
      { emoji: '🏔️', label: 'Very Hard', value: 5 },
    ],
    timing: 'post_task',
  },

  emotion_choice: {
    type: 'feeling',
    question: 'Choose your feeling:',
    options: [
      { emoji: '😊', label: 'Happy', value: 5 },
      { emoji: '😢', label: 'Sad', value: 2 },
      { emoji: '😱', label: 'Scared', value: 1 },
      { emoji: '🎉', label: 'Excited', value: 5 },
      { emoji: '😡', label: 'Angry', value: 2 },
    ],
    timing: 'mid_session',
  },

  motivation_check: {
    type: 'motivation',
    question: 'Do you want to continue?',
    options: [
      { emoji: '👍', label: 'Yes!', value: 5 },
      { emoji: '😐', label: 'Maybe', value: 3 },
      { emoji: '👎', label: 'No', value: 1 },
    ],
    timing: 'mid_session',
  },

  understanding_check: {
    type: 'understanding',
    question: 'Did you understand?',
    options: [
      { emoji: '✅', label: 'Yes', value: 5 },
      { emoji: '🤔', label: 'A little', value: 3 },
      { emoji: '❌', label: 'No', value: 1 },
    ],
    timing: 'post_task',
  },
};

/**
 * ============================================================================
 * SESSION STRUCTURE
 * ============================================================================
 */

export const SESSION_STRUCTURE = {
  dailyDurationMinutes: {
    min: 7,
    max: 15,
    recommended: 10,
  },

  weeklyCoverageGoal: 'Each subdomain touched once across 7 days',

  emojiCheckInFrequency: {
    timesPerSession: {
      min: 2,
      max: 3,
    },
    types: [
      'feeling_pre_task',
      'difficulty_post_task',
      'motivation_check',
    ],
  },

  breakTriggers: {
    fatigueSignals: true,
    lowMotivation: true,
    timeLimit: 15, // minutes
    errorSpike: true,
  },
};

/**
 * ============================================================================
 * HELPER FUNCTIONS
 * ============================================================================
 */

/**
 * Get subdomains appropriate for child's age
 */
export function getAgeAppropriateSubdomains(
  ageBand: '3-5' | '6-10' | '11-15'
): Record<string, SubdomainDefinition[]> {
  const result: Record<string, SubdomainDefinition[]> = {};

  for (const [domainKey, domain] of Object.entries(SUBDOMAIN_FRAMEWORK)) {
    result[domainKey] = [];

    for (const subdomain of Object.values(domain.subdomains)) {
      if (subdomain.ageAppropriate[ageBand]) {
        result[domainKey].push(subdomain);
      }
    }
  }

  return result;
}

/**
 * Get subdomains due for assessment based on frequency
 */
export function getSubdomainsDueForAssessment(
  lastAssessmentDates: Record<string, Date>,
  currentDate: Date = new Date()
): string[] {
  const due: string[] = [];

  for (const [domainKey, domain] of Object.entries(SUBDOMAIN_FRAMEWORK)) {
    for (const [subdomainKey, subdomain] of Object.entries(domain.subdomains)) {
      const fullKey = `${domainKey}.${subdomainKey}`;
      const lastDate = lastAssessmentDates[fullKey];

      if (!lastDate || shouldAssessNow(lastDate, currentDate, subdomain.sessionFrequency)) {
        due.push(fullKey);
      }
    }
  }

  return due;
}

/**
 * Check if subdomain should be assessed now based on frequency
 */
function shouldAssessNow(
  lastDate: Date,
  currentDate: Date,
  frequency: SessionFrequency
): boolean {
  const daysSince = (currentDate.getTime() - lastDate.getTime()) / (1000 * 60 * 60 * 24);

  switch (frequency) {
    case 'every_session':
      return true; // Always assess

    case '1-2_per_week':
      return daysSince >= 3; // ~3-7 days

    case '1_per_week':
    case 'weekly':
      return daysSince >= 7;

    case 'every_alternate_session':
      return daysSince >= 2; // Every 2+ days

    default:
      return daysSince >= 7;
  }
}

/**
 * Get emoji check-in for specific timing
 */
export function getEmojiCheckInForTiming(timing: 'pre_task' | 'post_task' | 'mid_session'): EmojiCheckIn[] {
  return Object.values(EMOJI_CHECKINS).filter(checkIn => checkIn.timing === timing);
}

/**
 * Get all subdomains for a domain
 */
export function getSubdomainsForDomain(domainKey: string): SubdomainDefinition[] {
  const domain = SUBDOMAIN_FRAMEWORK[domainKey];
  return domain ? Object.values(domain.subdomains) : [];
}

/**
 * Get total subdomain count
 */
export function getTotalSubdomainCount(): number {
  let count = 0;
  for (const domain of Object.values(SUBDOMAIN_FRAMEWORK)) {
    count += Object.keys(domain.subdomains).length;
  }
  return count;
}

console.log(`Subdomain Framework loaded: ${Object.keys(SUBDOMAIN_FRAMEWORK).length} domains, ${getTotalSubdomainCount()} subdomains`);
