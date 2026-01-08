/**
 * Comprehensive Subdomain Metrics Framework for Komal
 * Detailed assessment across 5 main domains with 19 subdomains
 * Based on research-validated SEL and developmental criteria
 */

export const SUBDOMAIN_FRAMEWORK = {
  social_communication: {
    id: 'social_communication',
    name: 'Social Communication',
    color: '#6366F1',
    subdomains: {
      joint_attention: {
        id: 'joint_attention',
        name: 'Joint Attention and Social Orienting',
        age_range: '3-10',
        sensors: ['eye', 'touch', 'response_pattern'],
        metrics: {
          ja_correct_trials: {
            id: 'ja_correct_trials',
            name: 'Correct Joint-Attention Responses',
            what_to_track: 'Child looks at partner/avatar or target object when cued by name, gaze, or pointing and taps the referenced object',
            compute: (sessionData) => {
              // Extract joint attention trials from correlations
              const { correlations } = sessionData;
              if (!correlations?.patterns?.socialEngagement) {
                return { score: 50, raw: { successful: 0, total: 0 } };
              }

              const trials = correlations.patterns.socialEngagement;
              const total = trials.length;
              const successful = trials.filter(t =>
                t.delay < 3000 && // Responded within 3 seconds
                t.pattern === 'joint-attention-communication'
              ).length;

              const successRate = total > 0 ? (successful / total) : 0;
              return {
                score: Math.round(successRate * 100),
                raw: { successful, total },
                display: {
                  label: successRate >= 0.75 ? 'Strong' : successRate >= 0.4 ? 'Developing' : 'Priority',
                  color: successRate >= 0.75 ? 'green' : successRate >= 0.4 ? 'amber' : 'red'
                }
              };
            }
          },
          ja_latency: {
            id: 'ja_latency',
            name: 'Joint-Attention Latency',
            what_to_track: 'Delay between cue and first look to partner or target',
            compute: (sessionData) => {
              const { correlations } = sessionData;
              if (!correlations?.patterns?.gazeVocalization) {
                return { score: 50, raw: { median: 0 } };
              }

              const latencies = correlations.patterns.gazeVocalization.map(p => p.delay);
              if (latencies.length === 0) return { score: 50, raw: { median: 0 } };

              latencies.sort((a, b) => a - b);
              const median = latencies[Math.floor(latencies.length / 2)];

              // Age-normalized scoring: faster = better
              // <500ms = 100, 500-1500ms = 80-60, >2000ms = <50
              let score = 100;
              if (median > 2000) score = 30;
              else if (median > 1500) score = 50;
              else if (median > 1000) score = 70;
              else if (median > 500) score = 85;

              return {
                score,
                raw: { median, latencies },
                display: {
                  label: median < 1000 ? 'Fast' : median < 2000 ? 'Typical' : 'Slow'
                }
              };
            }
          }
        }
      },

      readiness_to_answer: {
        id: 'readiness_to_answer',
        name: 'Readiness to Give Answers',
        age_range: '5-15',
        sensors: ['response_pattern', 'eye', 'voice'],
        metrics: {
          rta_response_rate: {
            id: 'rta_response_rate',
            name: 'Response Rate',
            what_to_track: 'Proportion of prompts where child attempts an answer without timing out',
            compute: (sessionData) => {
              const { voiceTracking, tasksCompleted, tasksTotal } = sessionData;
              if (!voiceTracking) return { score: 50, raw: { rate: 0 } };

              const responded = tasksCompleted || 0;
              const total = tasksTotal || 1;
              const rate = responded / total;

              return {
                score: Math.round(rate * 100),
                raw: { responded, total, rate },
                display: { gauge: Math.round(rate * 100) }
              };
            }
          },
          rta_initiation_latency: {
            id: 'rta_initiation_latency',
            name: 'Initiation Latency',
            what_to_track: 'Time from prompt to first vocalization or tap',
            compute: (sessionData) => {
              const { correlations } = sessionData;
              if (!correlations?.patterns?.attentionResponse) {
                return { score: 50, raw: { median: 0 } };
              }

              const latencies = correlations.patterns.attentionResponse.map(p => p.responseLatency);
              if (latencies.length === 0) return { score: 50, raw: { median: 0 } };

              latencies.sort((a, b) => a - b);
              const median = latencies[Math.floor(latencies.length / 2)];

              // Inverse-normalized: faster but not impulsive
              let score = 100;
              if (median < 200) score = 60; // Too impulsive
              else if (median < 500) score = 90;
              else if (median < 1000) score = 100;
              else if (median < 2000) score = 75;
              else score = 50;

              return {
                score,
                raw: { median, latencies }
              };
            }
          }
        }
      },

      appropriate_responses: {
        id: 'appropriate_responses',
        name: 'Appropriate Responses',
        age_range: '5-15',
        sensors: ['touch', 'voice'],
        metrics: {
          ar_task_accuracy: {
            id: 'ar_task_accuracy',
            name: 'Task Accuracy',
            what_to_track: 'Correct choices in structured questions and games',
            compute: (sessionData) => {
              const { touchTracking } = sessionData;
              if (!touchTracking?.patterns) {
                return { score: 50, raw: { correct: 0, total: 0 } };
              }

              const accurate = touchTracking.patterns.accurateTouches || 0;
              const total = touchTracking.totalTaps || 1;
              const accuracy = accurate / total;

              return {
                score: Math.round(accuracy * 100),
                raw: { correct: accurate, incorrect: total - accurate, total }
              };
            }
          }
        }
      },

      turn_taking: {
        id: 'turn_taking',
        name: 'Turn Taking',
        age_range: '3-15',
        sensors: ['voice', 'touch', 'response_pattern'],
        metrics: {
          tt_alternation_index: {
            id: 'tt_alternation_index',
            name: 'Turn Alternation',
            what_to_track: 'Orderly alternation of turns between child and avatar',
            compute: (sessionData) => {
              const { voiceTracking } = sessionData;
              if (!voiceTracking?.vocalizations) {
                return { score: 50, raw: { alternating: 0, total: 0 } };
              }

              // Simplified: assume proper turn-taking if vocalizations spaced appropriately
              const vocalizations = voiceTracking.vocalizations || [];
              let alternating = 0;
              for (let i = 1; i < vocalizations.length; i++) {
                const gap = vocalizations[i].startTime - vocalizations[i-1].endTime;
                if (gap > 500 && gap < 5000) alternating++; // Proper pause
              }

              const total = Math.max(1, vocalizations.length - 1);
              const rate = alternating / total;

              return {
                score: Math.round(rate * 100),
                raw: { alternating, total }
              };
            }
          },
          tt_interruptions: {
            id: 'tt_interruptions',
            name: 'Interruptions',
            what_to_track: 'Instances where child taps or speaks over avatar turn',
            compute: (sessionData) => {
              const { correlations } = sessionData;
              if (!correlations?.patterns) {
                return { score: 80, raw: { count: 0 } };
              }

              // Count simultaneous events as interruptions
              const interruptions = 0; // Placeholder - would need avatar turn tracking

              // Age-adjusted scoring: fewer = better
              const score = Math.max(0, 100 - (interruptions * 10));

              return {
                score,
                raw: { count: interruptions },
                display: {
                  label: interruptions < 2 ? 'Low' : interruptions < 5 ? 'Medium' : 'High'
                }
              };
            }
          }
        }
      },

      initiative_questions_repair: {
        id: 'initiative_questions_repair',
        name: 'Initiative, Questions, and Conversation Repair',
        age_range: '6-15',
        sensors: ['voice', 'response_pattern', 'eye'],
        metrics: {
          ti_spontaneous_initiative: {
            id: 'ti_spontaneous_initiative',
            name: 'Taking Initiative',
            what_to_track: 'Child starts topics, suggests ideas, or initiates turns without prompt',
            compute: (sessionData) => {
              const { voiceTracking, duration } = sessionData;
              if (!voiceTracking) return { score: 50, raw: { perMinute: 0 } };

              const initiations = voiceTracking.vocalActivity || 0;
              const durationMin = (duration || 900) / 60;
              const perMinute = initiations / durationMin;

              // Age-adjusted: 1-3 initiations/min is good
              let score = 50;
              if (perMinute >= 1 && perMinute <= 3) score = 90;
              else if (perMinute > 3) score = 75; // Too much
              else score = Math.max(30, perMinute * 50);

              return {
                score: Math.round(score),
                raw: { initiations, perMinute: perMinute.toFixed(2) }
              };
            }
          }
        }
      },

      nonverbal_communication: {
        id: 'nonverbal_communication',
        name: 'Nonverbal Communication',
        age_range: '3-15',
        sensors: ['eye', 'facial', 'voice'],
        metrics: {
          nv_gaze_to_face: {
            id: 'nv_gaze_to_face',
            name: 'Gaze to Partner Face',
            what_to_track: 'Proportion of time looking at avatar/partner face in social tasks',
            compute: (sessionData) => {
              const { eyeTracking } = sessionData;
              if (!eyeTracking) return { score: 50, raw: { proportion: 0 } };

              const proportion = eyeTracking.socialGazeIndex || 0;
              const score = Math.round(proportion * 100);

              return {
                score,
                raw: { proportion },
                display: { dial: score }
              };
            }
          }
        }
      },

      social_problem_solving: {
        id: 'social_problem_solving',
        name: 'Social Problem-Solving',
        age_range: '8-15',
        sensors: ['response_pattern', 'eye'],
        metrics: {
          sps_prosocial_solutions: {
            id: 'sps_prosocial_solutions',
            name: 'Prosocial Solution Quality',
            what_to_track: 'Quality of solutions in peer-conflict vignettes',
            compute: (sessionData) => {
              // Placeholder - would need NLP classification
              return {
                score: 70,
                raw: { prosocialCount: 0, total: 0 }
              };
            }
          }
        }
      }
    }
  },

  emotional_intelligence: {
    id: 'emotional_intelligence',
    name: 'Emotional Intelligence',
    color: '#F59E0B',
    subdomains: {
      emotion_recognition: {
        id: 'emotion_recognition',
        name: 'Emotion Recognition',
        age_range: '3-15',
        sensors: ['touch', 'eye', 'facial'],
        metrics: {
          er_face_accuracy: {
            id: 'er_face_accuracy',
            name: 'Facial Emotion Accuracy',
            what_to_track: 'Correct labeling of facial emotions',
            compute: (sessionData) => {
              const { microExpressions } = sessionData;
              if (!microExpressions) return { score: 50, raw: { correct: 0, total: 0 } };

              // Simplified based on engagement
              const engagementScore = microExpressions.engagementScore || 0.5;
              const score = Math.round(engagementScore * 100);

              return {
                score,
                raw: { correct: 0, incorrect: 0, total: 0 }
              };
            }
          }
        }
      },

      emotion_regulation: {
        id: 'emotion_regulation',
        name: 'Emotion Regulation and Self-Control',
        age_range: '3-15',
        sensors: ['touch', 'facial', 'response_pattern'],
        metrics: {
          er_dysregulation_events: {
            id: 'er_dysregulation_events',
            name: 'Dysregulation Events',
            what_to_track: 'Frustration indicators: rage taps, task quit, negative facial expression',
            compute: (sessionData) => {
              const { touchTracking, correlations } = sessionData;
              if (!touchTracking) return { score: 80, raw: { count: 0 } };

              const hesitations = touchTracking.hesitationTaps || 0;
              const frustrationEvents = correlations?.patterns?.emotionBehavior?.filter(
                p => p.emotion === 'frustration'
              ).length || 0;

              const totalEvents = hesitations + frustrationEvents;

              // Age-adjusted: fewer = better
              const score = Math.max(0, 100 - (totalEvents * 5));

              return {
                score,
                raw: { count: totalEvents },
                display: {
                  color: score >= 75 ? 'green' : score >= 40 ? 'amber' : 'red'
                }
              };
            }
          },
          er_regulation_success: {
            id: 'er_regulation_success',
            name: 'Regulation Success',
            what_to_track: 'Return to baseline after using coping tools',
            compute: (sessionData) => {
              const { correlations } = sessionData;
              if (!correlations?.patterns?.emotionBehavior) {
                return { score: 75, raw: { regulated: 0, triggered: 0 } };
              }

              const triggered = correlations.patterns.emotionBehavior.length;
              const regulated = correlations.patterns.emotionBehavior.filter(
                p => p.emotion === 'frustration' && p.hesitationCount < 3
              ).length;

              const rate = triggered > 0 ? regulated / triggered : 1;
              const score = Math.round(rate * 100);

              return {
                score,
                raw: { regulated, triggered }
              };
            }
          }
        }
      },

      coping_persistence: {
        id: 'coping_persistence',
        name: 'Coping and Persistence',
        age_range: '8-15',
        sensors: ['response_pattern'],
        metrics: {
          cp_task_persistence: {
            id: 'cp_task_persistence',
            name: 'Task Persistence',
            what_to_track: 'Retries and completion of challenging tasks',
            compute: (sessionData) => {
              const { tasksCompleted, tasksTotal } = sessionData;
              const completionRate = tasksTotal > 0 ? tasksCompleted / tasksTotal : 0;

              // Simple scoring based on completion
              const score = Math.round(completionRate * 100);

              return {
                score,
                raw: { completed: tasksCompleted, total: tasksTotal }
              };
            }
          }
        }
      }
    }
  },

  cognitive_development: {
    id: 'cognitive_development',
    name: 'Cognitive Development',
    color: '#8B5CF6',
    subdomains: {
      attention_concentration: {
        id: 'attention_concentration',
        name: 'Attention and Concentration',
        age_range: '3-15',
        sensors: ['eye', 'touch', 'response_pattern'],
        metrics: {
          ac_hit_rate: {
            id: 'ac_hit_rate',
            name: 'Sustained Attention Hit Rate',
            what_to_track: 'Correct responses to target stimuli over time',
            compute: (sessionData) => {
              const { touchTracking } = sessionData;
              if (!touchTracking?.patterns) {
                return { score: 50, raw: { hits: 0, targets: 0 } };
              }

              const hits = touchTracking.patterns.accurateTouches || 0;
              const targets = touchTracking.totalTaps || 1;
              const hitRate = hits / targets;

              return {
                score: Math.round(hitRate * 100),
                raw: { hits, targets }
              };
            }
          },
          ac_rt_variability: {
            id: 'ac_rt_variability',
            name: 'Reaction Time Variability',
            what_to_track: 'Standard deviation of reaction times',
            compute: (sessionData) => {
              const { correlations } = sessionData;
              if (!correlations?.patterns?.eyeTouch) {
                return { score: 50, raw: { sd: 0 } };
              }

              const delays = correlations.patterns.eyeTouch.map(p => p.delay);
              if (delays.length < 2) return { score: 50, raw: { sd: 0 } };

              const mean = delays.reduce((a, b) => a + b, 0) / delays.length;
              const variance = delays.reduce((sum, d) => sum + Math.pow(d - mean, 2), 0) / delays.length;
              const sd = Math.sqrt(variance);

              // Lower variability = higher score
              const score = Math.max(0, 100 - (sd / 20));

              return {
                score: Math.round(score),
                raw: { sd: Math.round(sd), mean: Math.round(mean) }
              };
            }
          }
        }
      },

      working_memory_flexibility: {
        id: 'working_memory_flexibility',
        name: 'Working Memory and Flexibility',
        age_range: '5-15',
        sensors: ['touch', 'response_pattern'],
        metrics: {
          wm_span: {
            id: 'wm_span',
            name: 'Memory Span',
            what_to_track: 'Longest correctly recalled sequence',
            compute: (sessionData) => {
              // Placeholder - would need specific memory tasks
              return {
                score: 60,
                raw: { maxSpan: 0 }
              };
            }
          }
        }
      },

      planning_persistence: {
        id: 'planning_persistence',
        name: 'Planning and Task Persistence',
        age_range: '8-15',
        sensors: ['response_pattern', 'touch'],
        metrics: {
          pl_pre_move_latency: {
            id: 'pl_pre_move_latency',
            name: 'Planning Latency',
            what_to_track: 'Time before first move in complex puzzles',
            compute: (sessionData) => {
              const { correlations } = sessionData;
              if (!correlations?.patterns?.eyeTouch) {
                return { score: 50, raw: { latency: 0 } };
              }

              const delays = correlations.patterns.eyeTouch.map(p => p.delay);
              if (delays.length === 0) return { score: 50, raw: { latency: 0 } };

              const median = delays.sort((a, b) => a - b)[Math.floor(delays.length / 2)];

              // Optimal zone: 300-1500ms
              let score = 50;
              if (median >= 300 && median <= 1500) score = 90;
              else if (median < 300) score = 60; // Too fast
              else if (median > 3000) score = 40; // Too slow
              else score = 70;

              return {
                score,
                raw: { latency: median }
              };
            }
          }
        }
      }
    }
  },

  life_skills: {
    id: 'life_skills',
    name: 'Life Skills and Adaptive Functioning',
    color: '#EC4899',
    subdomains: {
      independence_help_seeking: {
        id: 'independence_help_seeking',
        name: 'Independence and Help-Seeking',
        age_range: '5-15',
        sensors: ['touch', 'eye', 'response_pattern'],
        metrics: {
          ih_help_button_rate: {
            id: 'ih_help_button_rate',
            name: 'Help Button Rate',
            what_to_track: 'Use of hints/help features when stuck',
            compute: (sessionData) => {
              // Placeholder - would need help button tracking
              return {
                score: 70,
                raw: { helpPresses: 0, opportunities: 0 },
                display: { label: 'Optimal' }
              };
            }
          }
        }
      },

      rule_following_inhibition: {
        id: 'rule_following_inhibition',
        name: 'Rule-Following and Inhibition',
        age_range: '5-15',
        sensors: ['touch', 'response_pattern'],
        metrics: {
          rf_no_go_accuracy: {
            id: 'rf_no_go_accuracy',
            name: 'No-Go Accuracy',
            what_to_track: 'Ability to withhold response in stop/no-go games',
            compute: (sessionData) => {
              const { touchTracking } = sessionData;
              if (!touchTracking) return { score: 50, raw: { correct: 0, total: 0 } };

              // Inverse of impulsive touches
              const impulsive = touchTracking.hesitationTaps || 0;
              const total = touchTracking.totalTaps || 1;
              const inhibitionRate = Math.max(0, 1 - (impulsive / total));

              return {
                score: Math.round(inhibitionRate * 100),
                raw: { correct: total - impulsive, total }
              };
            }
          }
        }
      }
    }
  },

  language_sel: {
    id: 'language_sel',
    name: 'Language Development for SEL',
    color: '#10B981',
    subdomains: {
      sel_vocabulary: {
        id: 'sel_vocabulary',
        name: 'SEL Vocabulary',
        age_range: '3-15',
        sensors: ['voice', 'touch'],
        metrics: {
          sv_expressive: {
            id: 'sv_expressive',
            name: 'Expressive SEL Vocabulary',
            what_to_track: 'Unique appropriate SEL words produced in speech',
            compute: (sessionData) => {
              const { voiceTracking } = sessionData;
              if (!voiceTracking) return { score: 50, raw: { uniqueWords: 0 } };

              const vocalActivity = voiceTracking.vocalActivity || 0;
              // Simplified: estimate from vocal activity
              const estimatedWords = Math.round(vocalActivity * 50);

              return {
                score: Math.min(100, estimatedWords * 2),
                raw: { uniqueWords: estimatedWords }
              };
            }
          }
        }
      },

      fluency_coherence: {
        id: 'fluency_coherence',
        name: 'Fluency and Coherence',
        age_range: '8-15',
        sensors: ['voice'],
        metrics: {
          fc_words_per_minute: {
            id: 'fc_words_per_minute',
            name: 'Speech Fluency',
            what_to_track: 'Words per minute excluding long pauses',
            compute: (sessionData) => {
              const { voiceTracking, duration } = sessionData;
              if (!voiceTracking) return { score: 50, raw: { wpm: 0 } };

              const speechDuration = voiceTracking.totalSpeechDuration || 0;
              const wpm = voiceTracking.speechRate || 0;

              // Age-adjusted optimal zone: 80-150 WPM
              let score = 50;
              if (wpm >= 80 && wpm <= 150) score = 90;
              else if (wpm < 80 && wpm > 40) score = 70;
              else if (wpm > 150) score = 75;

              return {
                score,
                raw: { wpm }
              };
            }
          }
        }
      },

      prosody_clarity: {
        id: 'prosody_clarity',
        name: 'Prosody and Clarity',
        age_range: '5-15',
        sensors: ['voice'],
        metrics: {
          pc_disfluency_index: {
            id: 'pc_disfluency_index',
            name: 'Disfluency Index',
            what_to_track: 'Stuttering, long pauses, repetitions',
            compute: (sessionData) => {
              const { voiceTracking } = sessionData;
              if (!voiceTracking) return { score: 80, raw: { count: 0 } };

              const hesitations = voiceTracking.hesitations || 0;
              const score = Math.max(0, 100 - (hesitations * 3));

              return {
                score,
                raw: { count: hesitations },
                display: { label: hesitations < 5 ? 'Low' : hesitations < 10 ? 'Medium' : 'High' }
              };
            }
          }
        }
      },

      pragmatics: {
        id: 'pragmatics',
        name: 'Pragmatics and SEL Language Use',
        age_range: '6-15',
        sensors: ['voice'],
        metrics: {
          pr_politeness_empathy: {
            id: 'pr_politeness_empathy',
            name: 'Politeness and Empathy Phrases',
            what_to_track: 'Use of polite forms and empathy statements',
            compute: (sessionData) => {
              // Placeholder - would need NLP
              return {
                score: 60,
                raw: { count: 0 }
              };
            }
          }
        }
      }
    }
  }
};

/**
 * Compute all subdomain scores for a session
 */
export function computeSubdomainScores(sessionData, childAge) {
  const results = {};

  for (const [domainId, domain] of Object.entries(SUBDOMAIN_FRAMEWORK)) {
    results[domainId] = {
      id: domainId,
      name: domain.name,
      color: domain.color,
      subdomains: {}
    };

    for (const [subdomainId, subdomain] of Object.entries(domain.subdomains)) {
      const subdomainScores = {};

      for (const [metricId, metric] of Object.entries(subdomain.metrics)) {
        try {
          const result = metric.compute(sessionData);
          subdomainScores[metricId] = {
            ...result,
            name: metric.name,
            id: metricId
          };
        } catch (error) {
          console.error(`Error computing ${metricId}:`, error);
          subdomainScores[metricId] = {
            score: 50,
            raw: {},
            error: error.message
          };
        }
      }

      // Aggregate subdomain score
      const metricScores = Object.values(subdomainScores).map(m => m.score);
      const subdomainScore = metricScores.reduce((a, b) => a + b, 0) / metricScores.length;

      results[domainId].subdomains[subdomainId] = {
        id: subdomainId,
        name: subdomain.name,
        score: Math.round(subdomainScore),
        metrics: subdomainScores,
        ageRange: subdomain.age_range
      };
    }

    // Aggregate domain score
    const subdomainScores = Object.values(results[domainId].subdomains).map(s => s.score);
    results[domainId].overallScore = Math.round(
      subdomainScores.reduce((a, b) => a + b, 0) / subdomainScores.length
    );
  }

  return results;
}

/**
 * Calculate generalization score
 * Stability across different contexts (100 - normalized variance)
 */
export function calculateGeneralizationScore(historicalScores) {
  if (!historicalScores || historicalScores.length < 3) {
    return { score: 50, confidence: 'low' };
  }

  // Calculate variance
  const mean = historicalScores.reduce((a, b) => a + b, 0) / historicalScores.length;
  const variance = historicalScores.reduce((sum, score) => sum + Math.pow(score - mean, 2), 0) / historicalScores.length;
  const normalizedVariance = Math.min(variance / 100, 1); // Normalize to 0-1

  const generalizationScore = Math.round((1 - normalizedVariance) * 100);

  return {
    score: generalizationScore,
    confidence: historicalScores.length >= 7 ? 'high' : historicalScores.length >= 4 ? 'medium' : 'low',
    variance: variance.toFixed(2)
  };
}

/**
 * Calculate understanding score
 * Improvement on concept-application items
 */
export function calculateUnderstandingScore(historicalScores) {
  if (!historicalScores || historicalScores.length < 2) {
    return { score: 50, trend: 'stable' };
  }

  // Calculate linear trend
  const n = historicalScores.length;
  const xMean = (n - 1) / 2;
  const yMean = historicalScores.reduce((a, b) => a + b, 0) / n;

  let numerator = 0;
  let denominator = 0;

  historicalScores.forEach((score, i) => {
    numerator += (i - xMean) * (score - yMean);
    denominator += Math.pow(i - xMean, 2);
  });

  const slope = numerator / denominator;
  const improvement = slope * (n - 1); // Total change

  let understandingScore = 50 + improvement;
  understandingScore = Math.max(0, Math.min(100, understandingScore));

  return {
    score: Math.round(understandingScore),
    trend: improvement > 5 ? 'improving' : improvement < -5 ? 'declining' : 'stable',
    improvement: improvement.toFixed(1)
  };
}

export default SUBDOMAIN_FRAMEWORK;
