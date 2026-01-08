/**
 * Defensive Metric Calculators
 *
 * Production-ready metric computation with:
 * - Graceful handling of empty/undefined inputs
 * - Sensible defaults (neutral score of 50)
 * - Clamped outputs to [0, 100]
 * - No throwing - logs errors via ErrorBus instead
 * - Safe statistics helpers
 */

import { ErrorBus, reportScoringFailure } from '../core/ErrorBus';

/**
 * Safe median calculation
 * Returns 0 for empty arrays
 */
export function safeMedian(values: number[]): number {
  if (!values || values.length === 0) {
    return 0;
  }

  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);

  if (sorted.length % 2 === 0) {
    return (sorted[mid - 1] + sorted[mid]) / 2;
  } else {
    return sorted[mid];
  }
}

/**
 * Safe mean calculation
 * Returns 0 for empty arrays
 */
export function safeMean(values: number[]): number {
  if (!values || values.length === 0) {
    return 0;
  }

  return values.reduce((sum, v) => sum + v, 0) / values.length;
}

/**
 * Safe standard deviation calculation
 * Returns 0 for empty arrays or single values
 */
export function safeStdDev(values: number[]): number {
  if (!values || values.length <= 1) {
    return 0;
  }

  const mean = safeMean(values);
  const variance = values.reduce((sum, v) => sum + Math.pow(v - mean, 2), 0) / values.length;
  return Math.sqrt(variance);
}

/**
 * Clamp score to [0, 100]
 */
export function clampScore(score: number): number {
  if (typeof score !== 'number' || isNaN(score) || !isFinite(score)) {
    return 50; // Neutral default
  }
  return Math.max(0, Math.min(100, Math.round(score)));
}

/**
 * Safe percentile calculation
 */
export function safePercentile(values: number[], percentile: number): number {
  if (!values || values.length === 0) {
    return 0;
  }

  const sorted = [...values].sort((a, b) => a - b);
  const index = Math.floor((percentile / 100) * sorted.length);
  return sorted[Math.min(index, sorted.length - 1)];
}

/**
 * Normalized event structure
 * Represents any tracked event with timestamp and optional metadata
 */
export interface NormalizedEvent {
  timestamp: number;
  type: string;
  source?: string; // 'eye', 'face', 'touch', 'voice'
  data?: any;
}

/**
 * Session data structure for metric computation
 */
export interface SessionData {
  sessionId: string;
  duration: number; // milliseconds
  events: NormalizedEvent[];
  eyeTracking?: {
    fixations?: Array<{ duration: number; region?: string }>;
    saccades?: Array<{ timestamp: number }>;
    attentionScore?: number;
  };
  touchTracking?: {
    touches?: Array<{ timestamp: number; accuracy?: number; latency?: number }>;
    goalDirectedAccuracy?: number;
  };
  voiceTracking?: {
    utterances?: Array<{ timestamp: number; wordsPerMinute?: number; clarity?: number }>;
    vocabulary?: string[];
  };
  microExpressions?: {
    emotions?: Array<{ timestamp: number; label: string; confidence: number }>;
    engagementScore?: number;
  };
  correlations?: {
    patterns?: Array<{ category: string; quality: string }>;
  };
}

/**
 * Metric result structure
 */
export interface MetricResult {
  score0to100: number;
  rawValue?: number;
  confidence?: number;
  dataPoints?: number;
  error?: string;
}

/**
 * DEFENSIVE METRIC: Joint Attention
 *
 * Measures ability to share attention with avatar/task
 * Based on:
 * - Gaze fixations on social targets (avatar face)
 * - Response to avatar cues
 * - Sustained attention duration
 */
export function computeJointAttention(
  sessionData: SessionData | null | undefined
): MetricResult {
  const metricId = 'joint-attention';

  try {
    // Handle null/undefined input
    if (!sessionData) {
      return {
        score0to100: 50,
        confidence: 0,
        dataPoints: 0,
        error: 'No session data provided'
      };
    }

    // Extract relevant data
    const eyeTracking = sessionData.eyeTracking || {};
    const fixations = eyeTracking.fixations || [];

    // Handle empty fixations
    if (fixations.length === 0) {
      return {
        score0to100: 50,
        confidence: 0,
        dataPoints: 0,
        error: 'No fixation data available'
      };
    }

    // Count social fixations (avatar face)
    const socialFixations = fixations.filter(f =>
      f.region === 'avatar-face' || f.region === 'avatar'
    );
    const socialRatio = socialFixations.length / fixations.length;

    // Calculate average fixation duration on social targets
    const socialDurations = socialFixations
      .map(f => f.duration || 0)
      .filter(d => d > 0);
    const avgSocialDuration = safeMean(socialDurations);

    // Scoring:
    // - Social ratio (0-1) * 60 points
    // - Average duration bonus (up to 40 points)
    const ratioScore = socialRatio * 60;
    const durationScore = Math.min(40, (avgSocialDuration / 500) * 40); // 500ms = max

    const finalScore = ratioScore + durationScore;

    return {
      score0to100: clampScore(finalScore),
      rawValue: socialRatio,
      confidence: Math.min(1, fixations.length / 20), // More data = higher confidence
      dataPoints: fixations.length
    };
  } catch (error: any) {
    reportScoringFailure(metricId, error);
    return {
      score0to100: 50,
      confidence: 0,
      dataPoints: 0,
      error: error.message
    };
  }
}

/**
 * DEFENSIVE METRIC: Response Readiness
 *
 * Measures how quickly and appropriately child responds to prompts
 * Based on:
 * - Touch response latency
 * - Attention shifts (gaze + emotion correlation)
 * - Task completion speed
 */
export function computeResponseReadiness(
  sessionData: SessionData | null | undefined
): MetricResult {
  const metricId = 'response-readiness';

  try {
    if (!sessionData) {
      return {
        score0to100: 50,
        confidence: 0,
        dataPoints: 0,
        error: 'No session data provided'
      };
    }

    const touchTracking = sessionData.touchTracking || {};
    const touches = touchTracking.touches || [];

    if (touches.length === 0) {
      return {
        score0to100: 50,
        confidence: 0,
        dataPoints: 0,
        error: 'No touch data available'
      };
    }

    // Extract latencies
    const latencies = touches
      .map(t => t.latency || 0)
      .filter(l => l > 0 && l < 10000); // Filter outliers

    if (latencies.length === 0) {
      return {
        score0to100: 50,
        confidence: 0,
        dataPoints: 0,
        error: 'No valid latency data'
      };
    }

    // Calculate metrics
    const medianLatency = safeMedian(latencies);
    const avgLatency = safeMean(latencies);

    // Scoring:
    // - Lower latency = higher score
    // - Optimal range: 200-800ms
    // - Too fast (<100ms) or too slow (>3000ms) reduces score
    let score = 100;

    if (medianLatency < 100) {
      score = 60; // Impulsive
    } else if (medianLatency < 200) {
      score = 80; // Very fast
    } else if (medianLatency <= 800) {
      score = 100; // Optimal
    } else if (medianLatency <= 1500) {
      score = 75; // Slightly slow
    } else if (medianLatency <= 3000) {
      score = 50; // Slow
    } else {
      score = 30; // Very slow
    }

    return {
      score0to100: clampScore(score),
      rawValue: medianLatency,
      confidence: Math.min(1, latencies.length / 10),
      dataPoints: latencies.length
    };
  } catch (error: any) {
    reportScoringFailure(metricId, error);
    return {
      score0to100: 50,
      confidence: 0,
      dataPoints: 0,
      error: error.message
    };
  }
}

/**
 * DEFENSIVE METRIC: Dysregulation (Emotion Regulation)
 *
 * Measures emotional stability and regulation
 * Based on:
 * - Emotion variety (too many rapid changes = dysregulation)
 * - Negative emotion duration
 * - Engagement stability
 */
export function computeDysregulation(
  sessionData: SessionData | null | undefined
): MetricResult {
  const metricId = 'dysregulation';

  try {
    if (!sessionData) {
      return {
        score0to100: 50,
        confidence: 0,
        dataPoints: 0,
        error: 'No session data provided'
      };
    }

    const microExpressions = sessionData.microExpressions || {};
    const emotions = microExpressions.emotions || [];

    if (emotions.length === 0) {
      return {
        score0to100: 50,
        confidence: 0,
        dataPoints: 0,
        error: 'No emotion data available'
      };
    }

    // Count emotion changes
    let emotionChanges = 0;
    let lastEmotion = emotions[0]?.label;
    for (let i = 1; i < emotions.length; i++) {
      if (emotions[i].label !== lastEmotion) {
        emotionChanges++;
        lastEmotion = emotions[i].label;
      }
    }

    // Calculate emotion change rate (per minute)
    const durationMinutes = (sessionData.duration || 1) / 60000;
    const changeRate = emotionChanges / durationMinutes;

    // Count negative emotions
    const negativeEmotions = emotions.filter(e =>
      ['angry', 'sad', 'frustrated', 'fearful'].includes(e.label)
    );
    const negativeRatio = negativeEmotions.length / emotions.length;

    // Scoring (inverted - lower dysregulation = higher score):
    // - Fewer emotion changes = better regulation
    // - Fewer negative emotions = better regulation
    // - Optimal change rate: 1-3 per minute
    let changeScore = 100;
    if (changeRate < 1) {
      changeScore = 90; // Very stable (might be low engagement)
    } else if (changeRate <= 3) {
      changeScore = 100; // Optimal variability
    } else if (changeRate <= 6) {
      changeScore = 70; // High variability
    } else {
      changeScore = 40; // Very high variability (dysregulated)
    }

    const negativeScore = (1 - negativeRatio) * 100;

    const finalScore = changeScore * 0.6 + negativeScore * 0.4;

    return {
      score0to100: clampScore(finalScore),
      rawValue: changeRate,
      confidence: Math.min(1, emotions.length / 15),
      dataPoints: emotions.length
    };
  } catch (error: any) {
    reportScoringFailure(metricId, error);
    return {
      score0to100: 50,
      confidence: 0,
      dataPoints: 0,
      error: error.message
    };
  }
}

/**
 * DEFENSIVE METRIC: SEL Vocabulary
 *
 * Measures use of social-emotional vocabulary
 * Based on:
 * - Unique emotion words used
 * - Social language patterns
 * - Vocabulary diversity
 */
export function computeSelVocabulary(
  sessionData: SessionData | null | undefined
): MetricResult {
  const metricId = 'sel-vocabulary';

  try {
    if (!sessionData) {
      return {
        score0to100: 50,
        confidence: 0,
        dataPoints: 0,
        error: 'No session data provided'
      };
    }

    const voiceTracking = sessionData.voiceTracking || {};
    const vocabulary = voiceTracking.vocabulary || [];

    if (vocabulary.length === 0) {
      return {
        score0to100: 50,
        confidence: 0,
        dataPoints: 0,
        error: 'No vocabulary data available'
      };
    }

    // SEL vocabulary word lists
    const emotionWords = new Set([
      'happy', 'sad', 'angry', 'scared', 'worried', 'excited', 'calm',
      'frustrated', 'proud', 'shy', 'nervous', 'confident', 'surprised'
    ]);

    const socialWords = new Set([
      'friend', 'share', 'help', 'together', 'please', 'thank',
      'sorry', 'kind', 'fair', 'listen', 'turn', 'wait'
    ]);

    // Count SEL words used
    const emotionWordsUsed = vocabulary.filter(w =>
      emotionWords.has(w.toLowerCase())
    );
    const socialWordsUsed = vocabulary.filter(w =>
      socialWords.has(w.toLowerCase())
    );

    const totalSELWords = emotionWordsUsed.length + socialWordsUsed.length;
    const uniqueSELWords = new Set([...emotionWordsUsed, ...socialWordsUsed]).size;

    // Scoring:
    // - More unique SEL words = higher score
    // - Frequency bonus (using SEL words multiple times)
    const uniqueScore = Math.min(100, (uniqueSELWords / 8) * 100); // 8 words = 100 score
    const frequencyBonus = Math.min(20, (totalSELWords / uniqueSELWords - 1) * 10);

    const finalScore = uniqueScore * 0.8 + frequencyBonus;

    return {
      score0to100: clampScore(finalScore),
      rawValue: uniqueSELWords,
      confidence: Math.min(1, vocabulary.length / 20),
      dataPoints: vocabulary.length
    };
  } catch (error: any) {
    reportScoringFailure(metricId, error);
    return {
      score0to100: 50,
      confidence: 0,
      dataPoints: 0,
      error: error.message
    };
  }
}

/**
 * DEFENSIVE METRIC: Attention Span
 *
 * Measures sustained attention and concentration
 * Based on:
 * - Fixation durations
 * - Saccade frequency
 * - Task engagement time
 */
export function computeAttentionSpan(
  sessionData: SessionData | null | undefined
): MetricResult {
  const metricId = 'attention-span';

  try {
    if (!sessionData) {
      return {
        score0to100: 50,
        confidence: 0,
        dataPoints: 0,
        error: 'No session data provided'
      };
    }

    const eyeTracking = sessionData.eyeTracking || {};
    const fixations = eyeTracking.fixations || [];
    const saccades = eyeTracking.saccades || [];

    if (fixations.length === 0) {
      return {
        score0to100: 50,
        confidence: 0,
        dataPoints: 0,
        error: 'No fixation data available'
      };
    }

    // Calculate fixation statistics
    const fixationDurations = fixations
      .map(f => f.duration || 0)
      .filter(d => d > 0);

    const avgFixation = safeMean(fixationDurations);
    const maxFixation = Math.max(...fixationDurations, 0);
    const stdDevFixation = safeStdDev(fixationDurations);

    // Calculate saccade frequency
    const durationSeconds = (sessionData.duration || 1) / 1000;
    const saccadeRate = saccades.length / durationSeconds;

    // Scoring:
    // - Longer average fixations = better attention
    // - Lower saccade rate = more stable attention
    // - Lower variability = more consistent attention
    const fixationScore = Math.min(100, (avgFixation / 400) * 100); // 400ms = optimal
    const stabilityScore = Math.max(0, 100 - saccadeRate * 10);
    const consistencyScore = Math.max(0, 100 - (stdDevFixation / avgFixation) * 100);

    const finalScore = fixationScore * 0.5 + stabilityScore * 0.3 + consistencyScore * 0.2;

    return {
      score0to100: clampScore(finalScore),
      rawValue: avgFixation,
      confidence: Math.min(1, fixations.length / 20),
      dataPoints: fixations.length
    };
  } catch (error: any) {
    reportScoringFailure(metricId, error);
    return {
      score0to100: 50,
      confidence: 0,
      dataPoints: 0,
      error: error.message
    };
  }
}

/**
 * DEFENSIVE METRIC: Goal-Directed Behavior
 *
 * Measures purposeful, task-oriented actions
 * Based on:
 * - Touch accuracy on targets
 * - Sequential task completion
 * - Intentional vs random actions
 */
export function computeGoalDirectedBehavior(
  sessionData: SessionData | null | undefined
): MetricResult {
  const metricId = 'goal-directed-behavior';

  try {
    if (!sessionData) {
      return {
        score0to100: 50,
        confidence: 0,
        dataPoints: 0,
        error: 'No session data provided'
      };
    }

    const touchTracking = sessionData.touchTracking || {};
    const touches = touchTracking.touches || [];
    const goalDirectedAccuracy = touchTracking.goalDirectedAccuracy;

    if (touches.length === 0 && goalDirectedAccuracy === undefined) {
      return {
        score0to100: 50,
        confidence: 0,
        dataPoints: 0,
        error: 'No touch data available'
      };
    }

    // Use pre-computed accuracy if available
    if (goalDirectedAccuracy !== undefined && goalDirectedAccuracy !== null) {
      return {
        score0to100: clampScore(goalDirectedAccuracy * 100),
        rawValue: goalDirectedAccuracy,
        confidence: 0.9,
        dataPoints: touches.length
      };
    }

    // Otherwise compute from touch accuracy
    const accuracies = touches
      .map(t => t.accuracy || 0)
      .filter(a => a >= 0 && a <= 1);

    if (accuracies.length === 0) {
      return {
        score0to100: 50,
        confidence: 0,
        dataPoints: 0,
        error: 'No valid accuracy data'
      };
    }

    const avgAccuracy = safeMean(accuracies);
    const score = avgAccuracy * 100;

    return {
      score0to100: clampScore(score),
      rawValue: avgAccuracy,
      confidence: Math.min(1, accuracies.length / 10),
      dataPoints: accuracies.length
    };
  } catch (error: any) {
    reportScoringFailure(metricId, error);
    return {
      score0to100: 50,
      confidence: 0,
      dataPoints: 0,
      error: error.message
    };
  }
}

/**
 * Export all defensive metrics
 */
export const defensiveMetrics = {
  computeJointAttention,
  computeResponseReadiness,
  computeDysregulation,
  computeSelVocabulary,
  computeAttentionSpan,
  computeGoalDirectedBehavior
};

/**
 * USAGE EXAMPLE:
 *
 * import { defensiveMetrics } from './defensiveMetrics';
 *
 * // Compute metrics safely
 * const results = {
 *   jointAttention: defensiveMetrics.computeJointAttention(sessionData),
 *   responseReadiness: defensiveMetrics.computeResponseReadiness(sessionData),
 *   dysregulation: defensiveMetrics.computeDysregulation(sessionData),
 *   selVocabulary: defensiveMetrics.computeSelVocabulary(sessionData),
 *   attentionSpan: defensiveMetrics.computeAttentionSpan(sessionData),
 *   goalDirected: defensiveMetrics.computeGoalDirectedBehavior(sessionData)
 * };
 *
 * // All metrics return safe defaults on error, never throw
 * console.log('Joint Attention:', results.jointAttention.score0to100);
 */
