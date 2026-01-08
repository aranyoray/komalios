/**
 * Subdomain Measurement Tools
 *
 * Implements the specific measurement tools for tracking
 * developmental subdomains during sessions.
 *
 * Each tool corresponds to the "tools" array in the subdomain framework.
 */

import { ErrorBus } from '../core/ErrorBus';

export interface MeasurementResult {
  tool: string;
  subdomain: string;
  score: number; // 0-100
  rawData: any;
  timestamp: number;
  confidence: number; // 0-1
}

/**
 * ============================================================================
 * EYE TRACKING TOOLS
 * ============================================================================
 */

/**
 * Eye tracking alignment for joint attention
 *
 * Measures if child's gaze aligns with target areas
 */
export function measureEyeTrackingAlignment(
  gazeSamples: Array<{ timestamp: number; x: number; y: number }>,
  targetArea: { x: number; y: number; width: number; height: number },
  durationMs: number
): MeasurementResult {
  if (gazeSamples.length === 0) {
    return {
      tool: 'eye_tracking_alignment',
      subdomain: 'joint_attention',
      score: 0,
      rawData: { samplesCount: 0 },
      timestamp: Date.now(),
      confidence: 0,
    };
  }

  // Calculate how many samples are within target area
  let withinTarget = 0;
  for (const sample of gazeSamples) {
    if (
      sample.x >= targetArea.x &&
      sample.x <= targetArea.x + targetArea.width &&
      sample.y >= targetArea.y &&
      sample.y <= targetArea.y + targetArea.height
    ) {
      withinTarget++;
    }
  }

  const alignmentRatio = withinTarget / gazeSamples.length;
  const score = Math.round(alignmentRatio * 100);

  return {
    tool: 'eye_tracking_alignment',
    subdomain: 'joint_attention',
    score,
    rawData: {
      totalSamples: gazeSamples.length,
      withinTarget,
      alignmentRatio,
      durationMs,
    },
    timestamp: Date.now(),
    confidence: gazeSamples.length > 30 ? 0.9 : 0.6, // Higher confidence with more samples
  };
}

/**
 * Gaze stability score for attention control
 */
export function measureGazeStability(
  gazeSamples: Array<{ timestamp: number; x: number; y: number }>,
  durationMs: number
): MeasurementResult {
  if (gazeSamples.length < 10) {
    return {
      tool: 'gaze_stability_score',
      subdomain: 'attention_control',
      score: 0,
      rawData: {},
      timestamp: Date.now(),
      confidence: 0,
    };
  }

  // Calculate gaze dispersion (lower = more stable)
  let sumX = 0,
    sumY = 0;
  for (const sample of gazeSamples) {
    sumX += sample.x;
    sumY += sample.y;
  }
  const avgX = sumX / gazeSamples.length;
  const avgY = sumY / gazeSamples.length;

  let sumSquaredDist = 0;
  for (const sample of gazeSamples) {
    const dx = sample.x - avgX;
    const dy = sample.y - avgY;
    sumSquaredDist += dx * dx + dy * dy;
  }

  const variance = sumSquaredDist / gazeSamples.length;
  const stdDev = Math.sqrt(variance);

  // Lower std dev = higher stability
  // Normalize: assume std dev range 0-200 pixels
  const stabilityScore = Math.max(0, Math.min(100, 100 - (stdDev / 200) * 100));

  return {
    tool: 'gaze_stability_score',
    subdomain: 'attention_control',
    score: Math.round(stabilityScore),
    rawData: {
      samplesCount: gazeSamples.length,
      stdDev,
      variance,
      durationMs,
    },
    timestamp: Date.now(),
    confidence: 0.8,
  };
}

/**
 * Off-screen glance detector
 */
export function detectOffScreenGlances(
  gazeSamples: Array<{ timestamp: number; x: number; y: number; onScreen: boolean }>,
  screenBounds: { width: number; height: number }
): MeasurementResult {
  let offScreenCount = 0;
  let offScreenDurationMs = 0;
  let lastOffScreenStart = 0;

  for (let i = 0; i < gazeSamples.length; i++) {
    const sample = gazeSamples[i];

    if (!sample.onScreen) {
      if (lastOffScreenStart === 0) {
        lastOffScreenStart = sample.timestamp;
      }
      offScreenCount++;
    } else if (lastOffScreenStart > 0) {
      offScreenDurationMs += sample.timestamp - lastOffScreenStart;
      lastOffScreenStart = 0;
    }
  }

  const offScreenRatio = gazeSamples.length > 0 ? offScreenCount / gazeSamples.length : 0;
  // Lower off-screen ratio = higher score
  const score = Math.round((1 - offScreenRatio) * 100);

  return {
    tool: 'off_screen_glance_detector',
    subdomain: 'attention_control',
    score,
    rawData: {
      offScreenCount,
      totalSamples: gazeSamples.length,
      offScreenRatio,
      offScreenDurationMs,
    },
    timestamp: Date.now(),
    confidence: 0.85,
  };
}

/**
 * ============================================================================
 * VOICE/AUDIO TOOLS
 * ============================================================================
 */

/**
 * Voice latency detector for turn-taking
 */
export function measureVoiceLatency(
  promptTimestamp: number,
  responseTimestamp: number,
  appropriateRangeMs: { min: number; max: number } = { min: 500, max: 3000 }
): MeasurementResult {
  const latencyMs = responseTimestamp - promptTimestamp;

  // Score based on whether latency is in appropriate range
  let score: number;
  if (latencyMs < appropriateRangeMs.min) {
    // Too fast (might not be listening)
    score = 50;
  } else if (latencyMs > appropriateRangeMs.max) {
    // Too slow (hesitation)
    const penalty = Math.min(50, ((latencyMs - appropriateRangeMs.max) / 5000) * 50);
    score = 100 - penalty;
  } else {
    // In appropriate range
    score = 100;
  }

  return {
    tool: 'voice_latency_detector',
    subdomain: 'turn_taking',
    score: Math.round(score),
    rawData: {
      latencyMs,
      appropriateRange: appropriateRangeMs,
    },
    timestamp: Date.now(),
    confidence: 0.9,
  };
}

/**
 * Prosody extractor for fluency assessment
 */
export function extractProsodyFeatures(audioFeatures: {
  pitchMean: number;
  pitchVariance: number;
  volumeMean: number;
  pauseCount: number;
  disfluencyCount: number;
  durationMs: number;
}): MeasurementResult {
  // Fluency score based on:
  // - Low disfluency count
  // - Appropriate pause count (not too many, not too few)
  // - Consistent pitch variation (not monotone, not erratic)

  const expectedPausesPerSecond = 0.5; // ~1 pause per 2 seconds
  const durationSeconds = audioFeatures.durationMs / 1000;
  const expectedPauses = durationSeconds * expectedPausesPerSecond;

  const pauseScore = Math.max(
    0,
    100 - Math.abs(audioFeatures.pauseCount - expectedPauses) * 10
  );

  const disfluencyScore = Math.max(0, 100 - audioFeatures.disfluencyCount * 20);

  // Pitch variance: sweet spot is moderate (not flat, not chaotic)
  const pitchScore =
    audioFeatures.pitchVariance > 10 && audioFeatures.pitchVariance < 100 ? 100 : 60;

  const fluencyScore = (pauseScore * 0.4 + disfluencyScore * 0.4 + pitchScore * 0.2);

  return {
    tool: 'on_device_prosody_extractor',
    subdomain: 'fluency_and_prosody',
    score: Math.round(fluencyScore),
    rawData: audioFeatures,
    timestamp: Date.now(),
    confidence: 0.75,
  };
}

/**
 * ============================================================================
 * TAP/TOUCH TOOLS
 * ============================================================================
 */

/**
 * Tap sequence task for working memory
 */
export function evaluateTapSequence(
  expectedSequence: number[],
  actualSequence: number[],
  timeLimitMs: number,
  actualTimeMs: number
): MeasurementResult {
  if (expectedSequence.length === 0) {
    return {
      tool: 'sequence_tap_tasks',
      subdomain: 'working_memory',
      score: 0,
      rawData: {},
      timestamp: Date.now(),
      confidence: 0,
    };
  }

  // Calculate accuracy
  let correctCount = 0;
  const maxLength = Math.max(expectedSequence.length, actualSequence.length);

  for (let i = 0; i < maxLength; i++) {
    if (expectedSequence[i] === actualSequence[i]) {
      correctCount++;
    }
  }

  const accuracy = (correctCount / expectedSequence.length) * 100;

  // Time bonus/penalty
  let timeScore = 100;
  if (actualTimeMs > timeLimitMs) {
    timeScore = Math.max(50, 100 - ((actualTimeMs - timeLimitMs) / timeLimitMs) * 50);
  }

  const finalScore = accuracy * 0.7 + timeScore * 0.3;

  return {
    tool: 'sequence_tap_tasks',
    subdomain: 'working_memory',
    score: Math.round(finalScore),
    rawData: {
      expectedSequence,
      actualSequence,
      correctCount,
      accuracy,
      timeLimitMs,
      actualTimeMs,
    },
    timestamp: Date.now(),
    confidence: 0.9,
  };
}

/**
 * Tap focus index for attention
 */
export function calculateTapFocusIndex(
  tapEvents: Array<{ timestamp: number; x: number; y: number; targetHit: boolean }>
): MeasurementResult {
  if (tapEvents.length === 0) {
    return {
      tool: 'tap_focus_index',
      subdomain: 'attention_control',
      score: 0,
      rawData: {},
      timestamp: Date.now(),
      confidence: 0,
    };
  }

  const hitCount = tapEvents.filter(t => t.targetHit).length;
  const accuracy = (hitCount / tapEvents.length) * 100;

  // Calculate tap consistency (lower variance in timing = better focus)
  const intervals: number[] = [];
  for (let i = 1; i < tapEvents.length; i++) {
    intervals.push(tapEvents[i].timestamp - tapEvents[i - 1].timestamp);
  }

  let varianceScore = 100;
  if (intervals.length > 1) {
    const mean = intervals.reduce((a, b) => a + b, 0) / intervals.length;
    const variance =
      intervals.reduce((sum, val) => sum + Math.pow(val - mean, 2), 0) / intervals.length;
    const cv = Math.sqrt(variance) / mean; // Coefficient of variation

    // Lower CV = more consistent = higher score
    varianceScore = Math.max(0, 100 - cv * 100);
  }

  const focusIndex = accuracy * 0.6 + varianceScore * 0.4;

  return {
    tool: 'tap_focus_index',
    subdomain: 'attention_control',
    score: Math.round(focusIndex),
    rawData: {
      totalTaps: tapEvents.length,
      hitCount,
      accuracy,
      varianceScore,
    },
    timestamp: Date.now(),
    confidence: 0.85,
  };
}

/**
 * Tap error rate
 */
export function calculateTapErrorRate(
  totalTaps: number,
  incorrectTaps: number
): MeasurementResult {
  const errorRate = totalTaps > 0 ? incorrectTaps / totalTaps : 0;
  const score = Math.round((1 - errorRate) * 100);

  return {
    tool: 'tap_error_rate',
    subdomain: 'response_readiness',
    score,
    rawData: {
      totalTaps,
      incorrectTaps,
      errorRate,
    },
    timestamp: Date.now(),
    confidence: 0.9,
  };
}

/**
 * ============================================================================
 * NLP/SEMANTIC TOOLS
 * ============================================================================
 */

/**
 * Semantic relevance checker for appropriate responses
 */
export function checkSemanticRelevance(
  prompt: string,
  response: string
): MeasurementResult {
  // Simple keyword overlap method (production would use embeddings)
  const promptWords = prompt.toLowerCase().split(/\s+/).filter(w => w.length > 3);
  const responseWords = response.toLowerCase().split(/\s+/).filter(w => w.length > 3);

  const promptSet = new Set(promptWords);
  const overlapCount = responseWords.filter(w => promptSet.has(w)).length;

  const relevanceRatio = Math.min(1, overlapCount / Math.max(1, promptWords.length * 0.3));
  const score = relevanceRatio * 100;

  return {
    tool: 'semantic_relevance_nlp',
    subdomain: 'appropriate_responses',
    score: Math.round(score),
    rawData: {
      promptWords: promptWords.length,
      responseWords: responseWords.length,
      overlapCount,
      relevanceRatio,
    },
    timestamp: Date.now(),
    confidence: 0.6, // Low confidence for simple method
  };
}

/**
 * Question detection for conversation initiation
 */
export function detectQuestion(text: string): MeasurementResult {
  const hasQuestionMark = text.includes('?');
  const questionWords = ['what', 'where', 'when', 'why', 'who', 'how', 'can', 'could', 'would'];

  const lowerText = text.toLowerCase();
  const hasQuestionWord = questionWords.some(word => lowerText.includes(word));

  const isQuestion = hasQuestionMark || hasQuestionWord;
  const score = isQuestion ? 100 : 0;

  return {
    tool: 'local_nlp_classifier_for_question_detection',
    subdomain: 'conversation_initiation',
    score,
    rawData: {
      text,
      hasQuestionMark,
      hasQuestionWord,
      isQuestion,
    },
    timestamp: Date.now(),
    confidence: 0.85,
  };
}

/**
 * ============================================================================
 * EMOJI SELF-REPORT TOOLS
 * ============================================================================
 */

/**
 * Process emoji check-in response
 */
export function processEmojiCheckIn(
  checkInType: string,
  selectedOption: { emoji: string; label: string; value: number }
): MeasurementResult {
  // Emoji responses are direct self-reports
  // Value is already normalized to 1-5, convert to 0-100
  const score = ((selectedOption.value - 1) / 4) * 100; // 1-5 → 0-100

  return {
    tool: `emoji_check_in_${checkInType}`,
    subdomain: checkInType, // e.g., 'difficulty', 'feeling'
    score: Math.round(score),
    rawData: {
      checkInType,
      selectedEmoji: selectedOption.emoji,
      selectedLabel: selectedOption.label,
      selectedValue: selectedOption.value,
    },
    timestamp: Date.now(),
    confidence: 1.0, // High confidence - it's a direct report
  };
}

/**
 * ============================================================================
 * COMPOSITE/ENGAGEMENT TOOLS
 * ============================================================================
 */

/**
 * Engagement arc tracker
 */
export function trackEngagementArc(
  engagementSamples: Array<{ timestamp: number; score: number }> // 0-100 engagement over time
): MeasurementResult {
  if (engagementSamples.length === 0) {
    return {
      tool: 'engagement_arc_tracker',
      subdomain: 'task_persistence',
      score: 0,
      rawData: {},
      timestamp: Date.now(),
      confidence: 0,
    };
  }

  // Calculate average engagement
  const avgEngagement =
    engagementSamples.reduce((sum, s) => sum + s.score, 0) / engagementSamples.length;

  // Calculate engagement consistency (low variance = persistent)
  const variance =
    engagementSamples.reduce((sum, s) => sum + Math.pow(s.score - avgEngagement, 2), 0) /
    engagementSamples.length;
  const consistencyScore = Math.max(0, 100 - Math.sqrt(variance));

  // Check for upward trend (learning/warming up)
  const firstHalf = engagementSamples.slice(0, Math.floor(engagementSamples.length / 2));
  const secondHalf = engagementSamples.slice(Math.floor(engagementSamples.length / 2));

  const firstHalfAvg = firstHalf.reduce((sum, s) => sum + s.score, 0) / firstHalf.length;
  const secondHalfAvg = secondHalf.reduce((sum, s) => sum + s.score, 0) / secondHalf.length;

  const trendBonus = secondHalfAvg > firstHalfAvg ? 10 : 0;

  const persistenceScore = avgEngagement * 0.7 + consistencyScore * 0.3 + trendBonus;

  return {
    tool: 'engagement_arc_tracker',
    subdomain: 'task_persistence',
    score: Math.round(Math.min(100, persistenceScore)),
    rawData: {
      samplesCount: engagementSamples.length,
      avgEngagement,
      consistencyScore,
      trendBonus,
      firstHalfAvg,
      secondHalfAvg,
    },
    timestamp: Date.now(),
    confidence: engagementSamples.length > 10 ? 0.9 : 0.6,
  };
}

/**
 * Fatigue signal detector
 */
export function detectFatigueSignals(metrics: {
  responseLatencyMs: number[];
  errorRate: number[];
  gazeStability: number[];
}): MeasurementResult {
  // Fatigue indicated by:
  // - Increasing response latency over time
  // - Increasing error rate
  // - Decreasing gaze stability

  let fatigueScore = 100; // Start with no fatigue

  // Check latency trend
  if (metrics.responseLatencyMs.length > 3) {
    const firstQuarter = metrics.responseLatencyMs.slice(0, metrics.responseLatencyMs.length / 4);
    const lastQuarter = metrics.responseLatencyMs.slice(-metrics.responseLatencyMs.length / 4);

    const firstAvg = firstQuarter.reduce((a, b) => a + b, 0) / firstQuarter.length;
    const lastAvg = lastQuarter.reduce((a, b) => a + b, 0) / lastQuarter.length;

    if (lastAvg > firstAvg * 1.5) {
      fatigueScore -= 30; // Significant latency increase
    }
  }

  // Check error rate trend
  if (metrics.errorRate.length > 3) {
    const recentErrors = metrics.errorRate.slice(-3).reduce((a, b) => a + b, 0) / 3;
    if (recentErrors > 0.3) {
      fatigueScore -= 30;
    }
  }

  // Check gaze stability trend
  if (metrics.gazeStability.length > 3) {
    const recentStability = metrics.gazeStability.slice(-3).reduce((a, b) => a + b, 0) / 3;
    if (recentStability < 50) {
      fatigueScore -= 20;
    }
  }

  const score = Math.max(0, fatigueScore);

  return {
    tool: 'fatigue_signal_detector',
    subdomain: 'task_persistence',
    score: Math.round(score),
    rawData: {
      latencyTrend: metrics.responseLatencyMs.length,
      errorTrend: metrics.errorRate.length,
      gazeStabilityTrend: metrics.gazeStability.length,
    },
    timestamp: Date.now(),
    confidence: 0.75,
  };
}

/**
 * ============================================================================
 * UTILITY FUNCTIONS
 * ============================================================================
 */

/**
 * Aggregate multiple measurement results for a subdomain
 */
export function aggregateSubdomainMeasurements(
  measurements: MeasurementResult[]
): { score: number; confidence: number } {
  if (measurements.length === 0) {
    return { score: 0, confidence: 0 };
  }

  // Weighted average by confidence
  let weightedSum = 0;
  let totalConfidence = 0;

  for (const measurement of measurements) {
    weightedSum += measurement.score * measurement.confidence;
    totalConfidence += measurement.confidence;
  }

  const score = totalConfidence > 0 ? weightedSum / totalConfidence : 0;
  const confidence = Math.min(1, totalConfidence / measurements.length);

  return {
    score: Math.round(score),
    confidence,
  };
}

/**
 * Log measurement for debugging
 */
export function logMeasurement(result: MeasurementResult): void {
  console.log(
    `[${result.tool}] ${result.subdomain}: ${result.score}/100 (confidence: ${(result.confidence * 100).toFixed(0)}%)`
  );

  if (result.confidence < 0.5) {
    ErrorBus.report({
      code: 'LOW_MEASUREMENT_CONFIDENCE',
      message: `Low confidence measurement: ${result.tool}`,
      severity: 'warn',
      context: { result },
    });
  }
}
