/**
 * Adaptive UX Animations for SEL
 *
 * Low-arousal, child-centered animation system that adapts to behavioral state.
 * Designed to support regulation, not overstimulate.
 */

import { EngagementState } from '../engagement/EngagementStateMachine';

export type AnimationLevel = 'calm' | 'engaged' | 'celebratory' | 'soothing';
export type AgeBand = '3-5' | '6-10' | '11-15';

/**
 * Animation profile parameters
 */
export interface AnimationProfile {
  level: AnimationLevel;
  movementAmplitude: number;    // 0-1, how much movement
  colourIntensity: number;       // 0-1, how vibrant colors are
  animationFrequency: number;    // Hz, animations per second
  soundVolume: number;           // 0-1
  durationMs: number;            // How long animations last
  description: string;
}

/**
 * Get animation profile based on engagement state and age
 *
 * Design philosophy:
 * - Calm/soothing when child is dysregulated or needs break
 * - Engaged/moderate when child is focused
 * - Celebratory (but gentle) for achievements
 * - Always age-appropriate (younger = more visual, older = more subtle)
 *
 * @param state - Current engagement state
 * @param ageBand - Child's age band
 * @returns Animation profile parameters
 */
export function getAnimationProfile(
  state: EngagementState,
  ageBand: AgeBand
): AnimationProfile {
  // Base parameters by age
  const ageMultipliers = {
    '3-5': { movement: 1.2, colour: 1.1, frequency: 1.0 }, // Younger kids like more movement
    '6-10': { movement: 1.0, colour: 1.0, frequency: 1.0 }, // Baseline
    '11-15': { movement: 0.8, colour: 0.9, frequency: 0.9 } // Older kids prefer subtler
  };

  const mult = ageMultipliers[ageBand];

  // Profile by engagement state
  switch (state) {
    case 'Engaged':
      return {
        level: 'engaged',
        movementAmplitude: 0.5 * mult.movement,
        colourIntensity: 0.7 * mult.colour,
        animationFrequency: 2.0 * mult.frequency, // 2 Hz - moderate
        soundVolume: 0.5,
        durationMs: 800,
        description: 'Moderate, supportive animations that maintain engagement without distraction'
      };

    case 'SlightlyFatigued':
      return {
        level: 'engaged',
        movementAmplitude: 0.4 * mult.movement, // Slightly reduced
        colourIntensity: 0.6 * mult.colour,
        animationFrequency: 1.5 * mult.frequency, // Slower
        soundVolume: 0.4,
        durationMs: 1000,
        description: 'Gentle animations to re-engage without overwhelming'
      };

    case 'Disengaged':
      return {
        level: 'soothing',
        movementAmplitude: 0.3 * mult.movement, // Minimal movement
        colourIntensity: 0.5 * mult.colour, // Muted colors
        animationFrequency: 1.0 * mult.frequency, // Slow, calming
        soundVolume: 0.3,
        durationMs: 1500,
        description: 'Calm, soothing animations to help child regulate'
      };

    case 'NeedsBreak':
      return {
        level: 'calm',
        movementAmplitude: 0.2 * mult.movement, // Very minimal
        colourIntensity: 0.4 * mult.colour, // Soft, muted
        animationFrequency: 0.5 * mult.frequency, // Very slow
        soundVolume: 0.2,
        durationMs: 2000,
        description: 'Minimal, calming presence while child rests'
      };
  }
}

/**
 * Celebratory animation profile (for achievements)
 *
 * Even celebrations are kept gentle and non-overstimulating.
 * No loud sounds, bright flashes, or intense movements.
 *
 * @param ageBand - Child's age band
 * @param magnitude - Achievement magnitude ('small'|'medium'|'large')
 * @returns Celebratory animation profile
 */
export function getCelebrationProfile(
  ageBand: AgeBand,
  magnitude: 'small' | 'medium' | 'large'
): AnimationProfile {
  const ageMultipliers = {
    '3-5': { movement: 1.2, colour: 1.1 },
    '6-10': { movement: 1.0, colour: 1.0 },
    '11-15': { movement: 0.8, colour: 0.9 }
  };

  const mult = ageMultipliers[ageBand];

  // Scale by magnitude
  const magnitudeScale = {
    small: 0.7,
    medium: 1.0,
    large: 1.3
  }[magnitude];

  return {
    level: 'celebratory',
    movementAmplitude: (0.6 * mult.movement * magnitudeScale),
    colourIntensity: (0.8 * mult.colour * magnitudeScale),
    animationFrequency: 3.0 * magnitudeScale, // Faster for celebration
    soundVolume: 0.6 * magnitudeScale,
    durationMs: 1200,
    description: `Gentle ${magnitude} celebration - sparkles and soft glow, no intense flashing`
  };
}

/**
 * ============================================================================
 * MICROFEEDBACK UX PATTERNS
 * ============================================================================
 */

export type MicrofeedbackType =
  | 'turn-taking-success'
  | 'good-regulation'
  | 'prosocial-response'
  | 'attention-sustained'
  | 'help-seeking';

/**
 * UI intent for microfeedback
 */
export interface FeedbackIntent {
  type: MicrofeedbackType;
  visualEffect: string;
  audioEffect: string;
  duration: number;
  priority: 'low' | 'medium' | 'high';
}

/**
 * Get microfeedback UI intent
 *
 * Returns intent for UI layer to implement (not direct DOM manipulation).
 * Keeps all feedback subtle and non-gamified.
 *
 * @param type - Type of positive behavior to reinforce
 * @returns UI intent for implementing feedback
 */
export function getMicrofeedback(type: MicrofeedbackType): FeedbackIntent {
  switch (type) {
    case 'turn-taking-success':
      return {
        type,
        visualEffect: 'playSubtleSparkle', // Small sparkle near avatar
        audioEffect: 'softChime', // Gentle chime sound
        duration: 800,
        priority: 'medium'
      };

    case 'good-regulation':
      return {
        type,
        visualEffect: 'showSoftGlowOnAvatar', // Warm glow around avatar
        audioEffect: 'gentleHum', // Very soft hum
        duration: 1200,
        priority: 'high' // Important to reinforce regulation
      };

    case 'prosocial-response':
      return {
        type,
        visualEffect: 'avatarSmile', // Avatar smiles gently
        audioEffect: 'warmTone', // Warm, positive tone
        duration: 1000,
        priority: 'high' // Reinforce prosocial behavior
      };

    case 'attention-sustained':
      return {
        type,
        visualEffect: 'subtlePulse', // Gentle pulse on task area
        audioEffect: 'none', // No sound for sustained attention (not disruptive)
        duration: 500,
        priority: 'low'
      };

    case 'help-seeking':
      return {
        type,
        visualEffect: 'supportiveHighlight', // Highlight help button briefly
        audioEffect: 'softAcknowledgment', // Soft "I'm here" sound
        duration: 600,
        priority: 'medium'
      };
  }
}

/**
 * ============================================================================
 * LATENCY & LOADING FALLBACKS
 * ============================================================================
 */

export type LoadingState =
  | 'thinking'
  | 'loading'
  | 'preparing'
  | 'timeout';

/**
 * Child-friendly loading message
 */
export interface LoadingMessage {
  state: LoadingState;
  message: string;
  animationIntent: string;
  estimatedDuration: number; // ms
}

/**
 * Start friendly spinner with child-appropriate message
 *
 * @param label - What is being loaded
 * @returns Loading message and animation intent
 */
export function startFriendlySpinner(label: string): LoadingMessage {
  return {
    state: 'thinking',
    message: `Komal is ${label}...`,
    animationIntent: 'gentleSpinner', // Slow, smooth spinner
    estimatedDuration: 3000
  };
}

/**
 * Soft timeout handler
 *
 * Wraps a promise with timeout that shows calm animation instead of freezing.
 * If timeout occurs, suggests a break instead of retrying aggressively.
 *
 * @param promise - Promise to wrap
 * @param timeoutMs - Timeout duration
 * @param onTimeout - Callback if timeout occurs
 * @returns Wrapped promise with timeout
 */
export async function withSoftTimeout<T>(
  promise: Promise<T>,
  timeoutMs: number,
  onTimeout: () => void
): Promise<{ status: 'success' | 'timeout'; data?: T }> {
  let timeoutId: NodeJS.Timeout;

  const timeoutPromise = new Promise<{ status: 'timeout' }>((resolve) => {
    timeoutId = setTimeout(() => {
      onTimeout();
      resolve({ status: 'timeout' });
    }, timeoutMs);
  });

  try {
    const result = await Promise.race([
      promise.then(data => ({ status: 'success' as const, data })),
      timeoutPromise
    ]);

    clearTimeout(timeoutId!);
    return result;
  } catch (error) {
    clearTimeout(timeoutId!);
    throw error;
  }
}

/**
 * Get timeout message (suggests break after repeated timeouts)
 *
 * @param timeoutCount - Number of consecutive timeouts
 * @returns Message to display
 */
export function getTimeoutMessage(timeoutCount: number): LoadingMessage {
  if (timeoutCount === 1) {
    return {
      state: 'timeout',
      message: 'This is taking a bit longer than usual. Let\'s keep waiting...',
      animationIntent: 'calmWaiting',
      estimatedDuration: 5000
    };
  } else if (timeoutCount === 2) {
    return {
      state: 'timeout',
      message: 'Still working on it. Would you like to try something else?',
      animationIntent: 'patientWaiting',
      estimatedDuration: 0
    };
  } else {
    return {
      state: 'timeout',
      message: 'This seems to be taking a while. Maybe it\'s a good time for a short break?',
      animationIntent: 'suggestBreak',
      estimatedDuration: 0
    };
  }
}

/**
 * USAGE EXAMPLES:
 *
 * // 1. Get animation profile based on state
 * const profile = getAnimationProfile('Engaged', '6-10');
 * applyAnimationSettings(profile);
 *
 * // 2. Show celebration
 * const celebration = getCelebrationProfile('3-5', 'medium');
 * playAnimation(celebration);
 *
 * // 3. Microfeedback
 * const feedback = getMicrofeedback('prosocial-response');
 * showFeedback(feedback);
 *
 * // 4. Loading state
 * const loading = startFriendlySpinner('thinking');
 * showLoadingScreen(loading);
 *
 * // 5. Soft timeout
 * const result = await withSoftTimeout(
 *   fetchData(),
 *   5000,
 *   () => showTimeoutMessage(getTimeoutMessage(timeoutCount++))
 * );
 */
