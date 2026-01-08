/**
 * Behavioral Science Profiles
 *
 * Applies basic behavioral science principles to infer behavioral patterns.
 * These are observational heuristics, NOT diagnostic tools.
 *
 * Based on established behavioral science concepts:
 * - Approach/avoidance motivation (Elliot & Church, 1997)
 * - Flow theory and optimal challenge (Csikszentmihalyi, 1990)
 * - Social reciprocity in communication (Trevarthen & Aitken, 2001)
 */

/**
 * ============================================================================
 * APPROACH-AVOIDANCE PROFILE
 * ============================================================================
 */

export interface ApproachAvoidanceInputs {
  voluntaryInitiations: number;  // Number of times child initiated interaction
  skippedTasks: number;          // Number of tasks avoided/skipped
  helpSeekingEvents: number;     // Times child asked for help
  persistence: number;            // Retries before quitting (0-10 scale)
  positiveEmotionRatio: number;  // Proportion of positive vs negative emotions (0-1)
}

export interface ApproachAvoidanceProfile {
  approachScore: number;   // 0-100
  avoidanceScore: number;  // 0-100
  styleLabel: 'approach-oriented' | 'balanced' | 'avoidance-oriented';
  confidence: number;      // 0-1, based on data quality
}

/**
 * Compute approach-avoidance behavioral profile
 *
 * Psychological intuition:
 * - APPROACH behaviors: initiating, persisting, seeking challenges, positive affect
 * - AVOIDANCE behaviors: skipping, giving up quickly, negative affect, withdrawal
 *
 * Weighted formula:
 * - Approach = 30% initiations + 25% persistence + 25% help-seeking + 20% positive emotions
 * - Avoidance = 40% skipped tasks + 30% low persistence + 30% negative emotions
 *
 * NOT diagnostic - observational patterns only.
 *
 * @param inputs - Session behavioral data
 * @returns Approach-avoidance profile
 */
export function computeApproachAvoidanceProfile(
  inputs: ApproachAvoidanceInputs
): ApproachAvoidanceProfile {
  // Normalize inputs to 0-1 scale
  const initiationsNorm = Math.min(1, inputs.voluntaryInitiations / 10); // 10+ initiations = max
  const skippedNorm = Math.min(1, inputs.skippedTasks / 5); // 5+ skips = max avoidance
  const helpSeekingNorm = Math.min(1, inputs.helpSeekingEvents / 8); // 8+ help requests = engaged
  const persistenceNorm = Math.min(1, inputs.persistence / 10); // 0-10 scale
  const positiveEmotionNorm = inputs.positiveEmotionRatio; // Already 0-1

  // APPROACH SCORE (0-100)
  // Components: initiations, persistence, help-seeking (adaptive!), positive emotions
  const approachScore = Math.round(
    initiationsNorm * 30 +
    persistenceNorm * 25 +
    helpSeekingNorm * 25 + // Help-seeking is approach behavior (problem-solving)
    positiveEmotionNorm * 20
  );

  // AVOIDANCE SCORE (0-100)
  // Components: skipped tasks, low persistence, negative emotions
  const avoidanceScore = Math.round(
    skippedNorm * 40 +
    (1 - persistenceNorm) * 30 +
    (1 - positiveEmotionNorm) * 30
  );

  // Determine style label
  let styleLabel: 'approach-oriented' | 'balanced' | 'avoidance-oriented';
  const approachAvoidanceDiff = approachScore - avoidanceScore;

  if (approachAvoidanceDiff > 20) {
    styleLabel = 'approach-oriented';
  } else if (approachAvoidanceDiff < -20) {
    styleLabel = 'avoidance-oriented';
  } else {
    styleLabel = 'balanced';
  }

  // Confidence based on data points
  const dataPoints = [
    inputs.voluntaryInitiations > 0 ? 1 : 0,
    inputs.skippedTasks > 0 ? 1 : 0,
    inputs.helpSeekingEvents > 0 ? 1 : 0,
    inputs.persistence > 0 ? 1 : 0,
    1 // Always have emotion data
  ].reduce((sum, val) => sum + val, 0);

  const confidence = dataPoints / 5;

  return {
    approachScore: Math.min(100, Math.max(0, approachScore)),
    avoidanceScore: Math.min(100, Math.max(0, avoidanceScore)),
    styleLabel,
    confidence
  };
}

/**
 * ============================================================================
 * CHALLENGE SWEET SPOT ESTIMATOR
 * ============================================================================
 */

export type ChallengeZone = 'too_easy' | 'optimal' | 'too_hard';

export interface TaskChallengeInputs {
  accuracy: number;           // 0-1, task accuracy
  dysregulationEvents: number; // Count of frustration/regulation failures
  timeOnTask: number;         // Seconds spent on task
  smileyRating?: number;      // 1-5 if available (child self-report)
}

export interface ChallengeEstimate {
  challengeZone: ChallengeZone;
  challengeIndex: number; // 0-100 (50 = optimal)
  explanation: string;
}

/**
 * Estimate challenge sweet spot based on flow theory
 *
 * Psychological intuition (Csikszentmihalyi's Flow):
 * - TOO EASY: high accuracy + low engagement (boredom)
 * - OPTIMAL: moderate accuracy + high engagement + few frustrations (flow state)
 * - TOO HARD: low accuracy + high frustration (anxiety/defeat)
 *
 * Heuristic rules:
 * - Accuracy >90% + short time = too_easy
 * - Accuracy 60-85% + moderate time + low frustration = optimal
 * - Accuracy <60% + high frustration = too_hard
 *
 * @param inputs - Task performance data
 * @returns Challenge zone estimate
 */
export function estimateChallengeZone(inputs: TaskChallengeInputs): ChallengeEstimate {
  const { accuracy, dysregulationEvents, timeOnTask, smileyRating } = inputs;

  // Normalize time on task (assume 60-180s is typical)
  const expectedTime = 120; // 2 minutes
  const timeRatio = timeOnTask / expectedTime; // <1 = quick, >1 = slow

  // Rule-based classification
  let challengeZone: ChallengeZone;
  let challengeIndex: number;
  let explanation: string;

  // Rule 1: TOO EASY
  // High accuracy (>85%), completed quickly (<0.8x expected time), few errors
  if (accuracy > 0.85 && timeRatio < 0.8 && dysregulationEvents === 0) {
    challengeZone = 'too_easy';
    challengeIndex = 25; // Below optimal
    explanation = 'Task completed quickly with high accuracy. Child may be ready for more challenge.';
  }

  // Rule 2: TOO HARD
  // Low accuracy (<55%), high frustration (3+ events), OR very long time (>1.5x expected)
  else if (
    accuracy < 0.55 ||
    dysregulationEvents >= 3 ||
    timeRatio > 1.5
  ) {
    challengeZone = 'too_hard';
    challengeIndex = 75; // Above optimal
    explanation = 'Task showed signs of struggle. Consider simplifying or providing more support.';
  }

  // Rule 3: OPTIMAL
  // Moderate accuracy (60-85%), reasonable time, low frustration
  else if (
    accuracy >= 0.60 &&
    accuracy <= 0.85 &&
    dysregulationEvents <= 1 &&
    timeRatio >= 0.8 &&
    timeRatio <= 1.3
  ) {
    challengeZone = 'optimal';
    challengeIndex = 50; // Perfect zone
    explanation = 'Task provided good challenge level. Child was engaged and successful with effort.';
  }

  // Default: Between zones
  else {
    // Calculate index based on accuracy (closer to 70% = closer to optimal)
    const optimalAccuracy = 0.70;
    const deviationFromOptimal = Math.abs(accuracy - optimalAccuracy);
    challengeIndex = Math.round(50 + (deviationFromOptimal * 100));

    if (accuracy > 0.75) {
      challengeZone = 'too_easy';
      explanation = 'Task was manageable. Could increase complexity slightly.';
    } else {
      challengeZone = 'too_hard';
      explanation = 'Task was challenging. May benefit from slightly easier version.';
    }
  }

  // Adjust based on smiley rating if available
  if (smileyRating !== undefined) {
    if (smileyRating <= 2 && challengeZone !== 'too_hard') {
      challengeZone = 'too_hard';
      explanation += ' (Child reported difficulty)';
    } else if (smileyRating >= 4 && challengeZone !== 'optimal') {
      if (accuracy > 0.75) {
        challengeZone = 'too_easy';
        explanation += ' (Child reported it was easy)';
      } else {
        challengeZone = 'optimal';
        explanation += ' (Child felt good about it)';
      }
    }
  }

  return {
    challengeZone,
    challengeIndex: Math.min(100, Math.max(0, challengeIndex)),
    explanation
  };
}

/**
 * ============================================================================
 * SOCIAL RECIPROCITY INDEX
 * ============================================================================
 */

export interface SocialReciprocityFeatures {
  turnTakingAlternation: number;  // 0-1, how well turns alternate
  responseContingency: number;    // 0-1, semantic relevance of responses
  nonverbalMirroring: number;     // 0-1, smiling back, nodding, etc.
  repairAttempts: number;         // Count of communication repair attempts
}

export interface ReciprocityResult {
  reciprocityIndex: number; // 0-100
  label: 'low' | 'moderate' | 'high';
  explanation: string;
}

/**
 * Compute social reciprocity index
 *
 * Psychological intuition (Trevarthen's Intersubjectivity):
 * Social reciprocity = back-and-forth, contingent, responsive interaction
 *
 * Components:
 * - Turn-taking: alternating smoothly (not dominating or withdrawn)
 * - Contingency: responses relate to partner's input
 * - Mirroring: nonverbal synchrony (affective attunement)
 * - Repair: attempts to fix communication breakdowns (sophisticated skill)
 *
 * Heuristic formula:
 * Index = 30% turn-taking + 30% contingency + 25% mirroring + 15% repair
 *
 * NOT diagnostic of autism or social communication disorder.
 * Observational pattern only.
 *
 * @param features - Social interaction features
 * @returns Reciprocity index and classification
 */
export function computeReciprocityIndex(
  features: SocialReciprocityFeatures
): ReciprocityResult {
  // Normalize repair attempts (4+ = excellent)
  const repairNorm = Math.min(1, features.repairAttempts / 4);

  // Weighted formula
  const reciprocityIndex = Math.round(
    features.turnTakingAlternation * 30 +
    features.responseContingency * 30 +
    features.nonverbalMirroring * 25 +
    repairNorm * 15
  );

  // Classify
  let label: 'low' | 'moderate' | 'high';
  let explanation: string;

  if (reciprocityIndex < 40) {
    label = 'low';
    explanation = 'Social back-and-forth may benefit from practice. ' +
                 'Focus on turn-taking games and responsive interaction.';
  } else if (reciprocityIndex <= 70) {
    label = 'moderate';
    explanation = 'Shows developing social reciprocity. ' +
                 'Continue to encourage responsive, back-and-forth interactions.';
  } else {
    label = 'high';
    explanation = 'Strong social reciprocity observed. ' +
                 'Child engages in responsive, contingent back-and-forth interactions.';
  }

  return {
    reciprocityIndex: Math.min(100, Math.max(0, reciprocityIndex)),
    label,
    explanation
  };
}

/**
 * USAGE EXAMPLES:
 *
 * // 1. Approach-Avoidance Profile
 * const profile = computeApproachAvoidanceProfile({
 *   voluntaryInitiations: 8,
 *   skippedTasks: 1,
 *   helpSeekingEvents: 5,
 *   persistence: 7,
 *   positiveEmotionRatio: 0.75
 * });
 * console.log(profile);
 * // {
 * //   approachScore: 78,
 * //   avoidanceScore: 32,
 * //   styleLabel: 'approach-oriented',
 * //   confidence: 1.0
 * // }
 *
 * // 2. Challenge Sweet Spot
 * const challenge = estimateChallengeZone({
 *   accuracy: 0.72,
 *   dysregulationEvents: 1,
 *   timeOnTask: 140,
 *   smileyRating: 4
 * });
 * console.log(challenge);
 * // {
 * //   challengeZone: 'optimal',
 * //   challengeIndex: 50,
 * //   explanation: 'Task provided good challenge level...'
 * // }
 *
 * // 3. Social Reciprocity
 * const reciprocity = computeReciprocityIndex({
 *   turnTakingAlternation: 0.8,
 *   responseContingency: 0.7,
 *   nonverbalMirroring: 0.6,
 *   repairAttempts: 3
 * });
 * console.log(reciprocity);
 * // {
 * //   reciprocityIndex: 72,
 * //   label: 'high',
 * //   explanation: 'Strong social reciprocity observed...'
 * // }
 */
