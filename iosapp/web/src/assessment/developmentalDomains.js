/**
 * Clinical Assessment Framework for Komal
 * Research-based developmental domain assessment for ages 3-15
 *
 * Based on:
 * - DSM-5 developmental criteria
 * - CDC developmental milestones
 * - CASEL SEL framework
 * - Early childhood screening tools (M-CHAT, ASQ, BRIEF)
 */

// ============================================================================
// DEVELOPMENTAL DOMAINS (Ages 3-15)
// ============================================================================

export const DEVELOPMENTAL_DOMAINS = {
  SOCIAL_COMMUNICATION: {
    id: 'social_communication',
    name: 'Social Communication',
    shortName: 'Social',
    description: 'Social interaction, joint attention, communication reciprocity',
    isPrimary: true, // Show in concise report
    color: '#6366F1',

    // Research-based indicators
    redFlags: {
      '3-5': [
        'Limited eye contact during interactions',
        'Difficulty initiating social interactions',
        'Poor response to name',
        'Limited shared enjoyment',
        'Difficulty with turn-taking'
      ],
      '6-10': [
        'Difficulty making friends',
        'Limited understanding of social cues',
        'Difficulty with group activities',
        'Poor conversational reciprocity',
        'Limited empathy responses'
      ],
      '11-15': [
        'Social isolation or withdrawal',
        'Difficulty reading social situations',
        'Limited peer relationships',
        'Difficulty with perspective-taking',
        'Poor social problem-solving'
      ]
    },

    // Mapping from tracking data
    trackingMetrics: {
      eyeTracking: {
        socialGazeIndex: { weight: 0.35, inverse: false }, // Higher = better
        avgFixationDuration: { weight: 0.15, inverse: false },
        gazeAversions: { weight: 0.15, inverse: true } // More aversions = worse
      },
      microExpressions: {
        empathyResponse: { weight: 0.20, inverse: false },
        affectDiversityScore: { weight: 0.15, inverse: false }
      }
    }
  },

  EMOTIONAL_INTELLIGENCE: {
    id: 'emotional_intelligence',
    name: 'Emotional Intelligence',
    shortName: 'Emotional',
    description: 'Emotion recognition, regulation, self-awareness',
    isPrimary: true,
    color: '#F59E0B',

    redFlags: {
      '3-5': [
        'Extreme emotional reactions',
        'Difficulty calming down',
        'Limited emotion recognition',
        'Frequent meltdowns',
        'Inability to express feelings'
      ],
      '6-10': [
        'Poor emotional regulation',
        'Difficulty managing frustration',
        'Limited coping strategies',
        'Emotional outbursts',
        'Difficulty identifying own emotions'
      ],
      '11-15': [
        'Mood instability',
        'Poor stress management',
        'Limited emotional insight',
        'Difficulty with emotion-focused coping',
        'Emotional numbness or reactivity'
      ]
    },

    trackingMetrics: {
      microExpressions: {
        frustrationToleranceIndex: { weight: 0.30, inverse: false },
        affectDiversityScore: { weight: 0.20, inverse: false },
        positiveAffectActivation: { weight: 0.15, inverse: false }
      },
      responsePatterns: {
        recoveryTime: { weight: 0.20, inverse: true }, // Faster recovery = better
        freezeMode: { weight: 0.15, inverse: true }
      }
    }
  },

  COGNITIVE_DEVELOPMENT: {
    id: 'cognitive_development',
    name: 'Cognitive Development',
    shortName: 'Cognitive',
    description: 'Attention, executive function, problem-solving',
    isPrimary: true,
    color: '#8B5CF6',

    redFlags: {
      '3-5': [
        'Very short attention span (<5 min)',
        'Difficulty following simple instructions',
        'Limited problem-solving attempts',
        'Impulsive behavior',
        'Difficulty with task completion'
      ],
      '6-10': [
        'Poor sustained attention',
        'Difficulty with planning',
        'Limited working memory',
        'Poor impulse control',
        'Difficulty with task switching'
      ],
      '11-15': [
        'Executive function deficits',
        'Poor time management',
        'Limited abstract thinking',
        'Difficulty with complex problem-solving',
        'Poor metacognition'
      ]
    },

    trackingMetrics: {
      eyeTracking: {
        attentionScore: { weight: 0.30, inverse: false },
        concentrationStability: { weight: 0.25, inverse: false }
      },
      touchTracking: {
        goalDirectedAccuracy: { weight: 0.20, inverse: false },
        hesitationTaps: { weight: 0.15, inverse: true }
      },
      responsePatterns: {
        impulsiveGuessing: { weight: 0.10, inverse: true }
      }
    }
  },

  LANGUAGE_DEVELOPMENT: {
    id: 'language_development',
    name: 'Language Development',
    shortName: 'Language',
    description: 'Receptive and expressive language, communication',
    isPrimary: true,
    color: '#10B981',

    redFlags: {
      '3-5': [
        'Limited vocabulary (<50 words)',
        'No 2-word phrases',
        'Difficulty following verbal instructions',
        'Limited vocal attempts',
        'Echolalia or repetitive speech'
      ],
      '6-10': [
        'Difficulty with complex sentences',
        'Poor narrative skills',
        'Limited conversational skills',
        'Difficulty understanding abstract language',
        'Word-finding difficulties'
      ],
      '11-15': [
        'Limited vocabulary for age',
        'Difficulty with figurative language',
        'Poor written expression',
        'Difficulty with verbal reasoning',
        'Limited academic language'
      ]
    },

    trackingMetrics: {
      voiceTracking: {
        vocalActivity: { weight: 0.25, inverse: false },
        speechRate: { weight: 0.20, inverse: false },
        confidence: { weight: 0.20, inverse: false },
        hesitations: { weight: 0.15, inverse: true }
      },
      responsePatterns: {
        initiationLatency: { weight: 0.20, inverse: true }
      }
    }
  },

  LIFE_SKILLS: {
    id: 'life_skills',
    name: 'Life Skills & Independence',
    shortName: 'Life Skills',
    description: 'Self-care, independence, adaptive behavior',
    isPrimary: true,
    color: '#EC4899',

    redFlags: {
      '3-5': [
        'Limited self-help skills',
        'Resistance to routines',
        'Difficulty with transitions',
        'Limited play skills',
        'Extreme rigidity'
      ],
      '6-10': [
        'Poor organizational skills',
        'Difficulty with self-care tasks',
        'Limited responsibility-taking',
        'Poor adaptability',
        'Difficulty with daily routines'
      ],
      '11-15': [
        'Limited independence',
        'Poor decision-making',
        'Difficulty with goal-setting',
        'Limited self-advocacy',
        'Poor life planning skills'
      ]
    },

    trackingMetrics: {
      responsePatterns: {
        healthyPersistence: { weight: 0.30, inverse: false },
        errorCorrection: { weight: 0.25, inverse: false }
      },
      touchTracking: {
        goalDirectedAccuracy: { weight: 0.25, inverse: false }
      },
      overall: {
        taskCompletionRate: { weight: 0.20, inverse: false }
      }
    }
  },

  // Secondary domains (shown in extended report only)
  MOTOR_DEVELOPMENT: {
    id: 'motor_development',
    name: 'Motor Development',
    shortName: 'Motor',
    description: 'Fine and gross motor skills, coordination',
    isPrimary: false,
    color: '#14B8A6',

    trackingMetrics: {
      touchTracking: {
        goalDirectedAccuracy: { weight: 0.40, inverse: false },
        hesitationTaps: { weight: 0.30, inverse: true },
        touchPressure: { weight: 0.30, inverse: false }
      }
    }
  },

  SENSORY_PROCESSING: {
    id: 'sensory_processing',
    name: 'Sensory Processing',
    shortName: 'Sensory',
    description: 'Sensory integration, responsiveness',
    isPrimary: false,
    color: '#F97316',

    trackingMetrics: {
      eyeTracking: {
        explorationAvoidanceRatio: { weight: 0.40, inverse: false }
      },
      microExpressions: {
        frustrationEpisodes: { weight: 0.30, inverse: true }
      },
      touchTracking: {
        selfSoothingGestures: { weight: 0.30, inverse: true }
      }
    }
  },

  BEHAVIORAL_REGULATION: {
    id: 'behavioral_regulation',
    name: 'Behavioral Regulation',
    shortName: 'Behavior',
    description: 'Self-control, impulse control, flexibility',
    isPrimary: false,
    color: '#06B6D4',

    trackingMetrics: {
      touchTracking: {
        hesitationTaps: { weight: 0.30, inverse: true }
      },
      responsePatterns: {
        impulsiveGuessing: { weight: 0.35, inverse: true },
        freezeMode: { weight: 0.35, inverse: true }
      }
    }
  }
};

// ============================================================================
// RISK LEVELS
// ============================================================================

export const RISK_LEVELS = {
  LOW: {
    range: [70, 100],
    label: 'Typical Development',
    color: '#10B981',
    icon: '✅',
    description: 'Skills developing as expected for age'
  },
  MODERATE: {
    range: [40, 69],
    label: 'Some Concerns',
    color: '#F59E0B',
    icon: '⚠️',
    description: 'Monitor and consider support strategies'
  },
  HIGH: {
    range: [0, 39],
    label: 'Significant Concerns',
    color: '#EF4444',
    icon: '🚨',
    description: 'Recommend professional evaluation'
  }
};

// ============================================================================
// AGE-BASED EXPECTATIONS
// ============================================================================

export const AGE_GROUPS = {
  PRESCHOOL: { min: 3, max: 5, label: '3-5 years' },
  ELEMENTARY: { min: 6, max: 10, label: '6-10 years' },
  PRETEEN: { min: 11, max: 15, label: '11-15 years' }
};

export const getAgeGroup = (age) => {
  if (age >= 3 && age <= 5) return 'PRESCHOOL';
  if (age >= 6 && age <= 10) return 'ELEMENTARY';
  if (age >= 11 && age <= 15) return 'PRETEEN';
  return 'ELEMENTARY'; // default
};

// ============================================================================
// SYMPTOM FLAGS
// ============================================================================

export const SYMPTOM_CATEGORIES = {
  AUTISM_SPECTRUM: {
    name: 'Autism Spectrum Traits',
    indicators: [
      'socialGazeIndex < 0.4',
      'affectDiversityScore < 3',
      'repetitivePatterns',
      'limitedJointAttention'
    ]
  },
  ADHD_TRAITS: {
    name: 'ADHD-Related Traits',
    indicators: [
      'attentionScore < 50',
      'impulsiveGuessing > 5',
      'concentrationStability < 0.5',
      'hyperactivityMarkers'
    ]
  },
  ANXIETY_TRAITS: {
    name: 'Anxiety-Related Traits',
    indicators: [
      'hesitationTaps > 15',
      'freezeMode > 3',
      'highStressMarkers',
      'avoidanceBehaviors'
    ]
  },
  LANGUAGE_DELAY: {
    name: 'Language Development Concerns',
    indicators: [
      'vocalActivity < 0.3',
      'hesitations > 10',
      'limitedVocabulary',
      'poorNarrativeSkills'
    ]
  },
  EMOTIONAL_DYSREGULATION: {
    name: 'Emotional Regulation Concerns',
    indicators: [
      'frustrationToleranceIndex < 0.5',
      'recoveryTime > 5',
      'frequentMeltdowns',
      'emotionalInstability'
    ]
  }
};

export default DEVELOPMENTAL_DOMAINS;
