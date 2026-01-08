/**
 * Child Engagement State Machine
 *
 * Automatically adapts UI based on child's engagement level
 * Optimized for ages 3-15 with age-appropriate interventions
 *
 * States:
 * - Engaged: Child is focused and responding well
 * - SlightlyFatigued: Minor signs of disengagement
 * - Disengaged: Clear disengagement, needs intervention
 * - NeedsBreak: Child needs a break from activity
 */

import { ErrorBus } from '../core/ErrorBus';

/**
 * Engagement states
 */
export type EngagementState = 'Engaged' | 'SlightlyFatigued' | 'Disengaged' | 'NeedsBreak';

/**
 * Engagement metrics from sensors
 */
export interface EngagementMetrics {
  // Gaze stability (0-1)
  gazeStability: number;

  // Average response delay (ms)
  avgResponseDelay: number;

  // Tap error rate (0-1, percentage of missed/wrong taps)
  tapErrorRate: number;

  // Attention score (0-100)
  attentionScore: number;

  // Emotion valence (-1 to 1, negative to positive)
  emotionValence: number;

  // Time in current activity (ms)
  timeInActivity: number;
}

/**
 * UI configuration for each state
 */
export interface UIConfig {
  // Button size multiplier (1.0 = normal)
  buttonSizeMultiplier: number;

  // Number of choices to show (max)
  maxChoices: number;

  // Prompt text length (characters)
  maxPromptLength: number;

  // Animation intensity (0-1)
  animationIntensity: number;

  // Interaction pace (ms between prompts)
  interactionPaceMs: number;

  // Enable positive reinforcement
  enablePositiveReinforcement: boolean;

  // Audio feedback volume (0-1)
  audioVolume: number;

  // Visual complexity (0-1)
  visualComplexity: number;
}

/**
 * State transition thresholds
 */
interface TransitionThresholds {
  // Engaged → SlightlyFatigued
  engagedToFatigued: {
    gazeStabilityBelow: number;
    avgDelayAbove: number;
    errorRateAbove: number;
  };

  // SlightlyFatigued → Disengaged
  fatiguedToDisengaged: {
    gazeStabilityBelow: number;
    avgDelayAbove: number;
    errorRateAbove: number;
    attentionBelow: number;
  };

  // Disengaged → NeedsBreak
  disengagedToBreak: {
    gazeStabilityBelow: number;
    avgDelayAbove: number;
    errorRateAbove: number;
    emotionValenceBelow: number;
    timeInActivityAbove: number;
  };

  // Recovery conditions (reverse transitions)
  recovery: {
    gazeStabilityAbove: number;
    avgDelayBelow: number;
    errorRateBelow: number;
    attentionAbove: number;
    sustainedDuration: number; // ms to sustain improvement
  };
}

/**
 * Default thresholds based on research and UX best practices
 */
const DEFAULT_THRESHOLDS: TransitionThresholds = {
  engagedToFatigued: {
    gazeStabilityBelow: 0.6,  // 60% stability
    avgDelayAbove: 2000,      // 2 seconds
    errorRateAbove: 0.3       // 30% errors
  },
  fatiguedToDisengaged: {
    gazeStabilityBelow: 0.4,  // 40% stability
    avgDelayAbove: 3500,      // 3.5 seconds
    errorRateAbove: 0.5,      // 50% errors
    attentionBelow: 40        // 40/100
  },
  disengagedToBreak: {
    gazeStabilityBelow: 0.2,  // 20% stability
    avgDelayAbove: 5000,      // 5 seconds
    errorRateAbove: 0.7,      // 70% errors
    emotionValenceBelow: -0.5, // Negative emotions
    timeInActivityAbove: 900000 // 15 minutes
  },
  recovery: {
    gazeStabilityAbove: 0.7,  // 70% stability
    avgDelayBelow: 1500,      // 1.5 seconds
    errorRateBelow: 0.2,      // 20% errors
    attentionAbove: 60,       // 60/100
    sustainedDuration: 30000  // 30 seconds sustained
  }
};

/**
 * Engagement State Machine
 */
export class EngagementStateMachine {
  private currentState: EngagementState = 'Engaged';
  private previousState: EngagementState = 'Engaged';
  private stateEnteredAt: number = Date.now();
  private recoveryStartedAt: number | null = null;
  private thresholds: TransitionThresholds;

  // History for trend detection
  private metricsHistory: EngagementMetrics[] = [];
  private maxHistorySize = 20; // Keep last 20 metric snapshots

  // State change listeners
  private listeners: Array<(state: EngagementState, previousState: EngagementState) => void> = [];

  constructor(thresholds: TransitionThresholds = DEFAULT_THRESHOLDS) {
    this.thresholds = thresholds;
  }

  /**
   * Update engagement state based on current metrics
   */
  update(metrics: EngagementMetrics): EngagementState {
    // Add to history
    this.metricsHistory.push(metrics);
    if (this.metricsHistory.length > this.maxHistorySize) {
      this.metricsHistory.shift();
    }

    const previousState = this.currentState;

    // Check transitions based on current state
    switch (this.currentState) {
      case 'Engaged':
        if (this.shouldTransitionToFatigued(metrics)) {
          this.transitionTo('SlightlyFatigued');
        }
        break;

      case 'SlightlyFatigued':
        if (this.shouldTransitionToDisengaged(metrics)) {
          this.transitionTo('Disengaged');
        } else if (this.shouldRecover(metrics)) {
          this.transitionTo('Engaged');
        }
        break;

      case 'Disengaged':
        if (this.shouldTransitionToBreak(metrics)) {
          this.transitionTo('NeedsBreak');
        } else if (this.shouldRecover(metrics)) {
          this.transitionTo('SlightlyFatigued');
        }
        break;

      case 'NeedsBreak':
        // Can only recover from break after some time
        const timeInBreak = Date.now() - this.stateEnteredAt;
        if (timeInBreak > 60000 && this.shouldRecover(metrics)) {
          // After 1 minute break, can recover
          this.transitionTo('Engaged');
        }
        break;
    }

    // Notify listeners if state changed
    if (this.currentState !== previousState) {
      this.notifyListeners(this.currentState, previousState);
    }

    return this.currentState;
  }

  /**
   * Check if should transition from Engaged to SlightlyFatigued
   */
  private shouldTransitionToFatigued(metrics: EngagementMetrics): boolean {
    const t = this.thresholds.engagedToFatigued;

    // Count how many conditions are met
    let conditionsMet = 0;

    if (metrics.gazeStability < t.gazeStabilityBelow) conditionsMet++;
    if (metrics.avgResponseDelay > t.avgDelayAbove) conditionsMet++;
    if (metrics.tapErrorRate > t.errorRateAbove) conditionsMet++;

    // Need at least 2 of 3 conditions to transition
    return conditionsMet >= 2;
  }

  /**
   * Check if should transition from SlightlyFatigued to Disengaged
   */
  private shouldTransitionToDisengaged(metrics: EngagementMetrics): boolean {
    const t = this.thresholds.fatiguedToDisengaged;

    let conditionsMet = 0;

    if (metrics.gazeStability < t.gazeStabilityBelow) conditionsMet++;
    if (metrics.avgResponseDelay > t.avgDelayAbove) conditionsMet++;
    if (metrics.tapErrorRate > t.errorRateAbove) conditionsMet++;
    if (metrics.attentionScore < t.attentionBelow) conditionsMet++;

    // Need at least 3 of 4 conditions
    return conditionsMet >= 3;
  }

  /**
   * Check if should transition from Disengaged to NeedsBreak
   */
  private shouldTransitionToBreak(metrics: EngagementMetrics): boolean {
    const t = this.thresholds.disengagedToBreak;

    let conditionsMet = 0;

    if (metrics.gazeStability < t.gazeStabilityBelow) conditionsMet++;
    if (metrics.avgResponseDelay > t.avgDelayAbove) conditionsMet++;
    if (metrics.tapErrorRate > t.errorRateAbove) conditionsMet++;
    if (metrics.emotionValence < t.emotionValenceBelow) conditionsMet++;
    if (metrics.timeInActivity > t.timeInActivityAbove) conditionsMet++;

    // Need at least 3 of 5 conditions, OR time limit exceeded
    return conditionsMet >= 3 || metrics.timeInActivity > t.timeInActivityAbove;
  }

  /**
   * Check if should recover to better state
   * Requires sustained improvement
   */
  private shouldRecover(metrics: EngagementMetrics): boolean {
    const t = this.thresholds.recovery;

    // Check if metrics meet recovery criteria
    const meetsRecoveryCriteria =
      metrics.gazeStability > t.gazeStabilityAbove &&
      metrics.avgResponseDelay < t.avgDelayBelow &&
      metrics.tapErrorRate < t.errorRateBelow &&
      metrics.attentionScore > t.attentionAbove;

    if (!meetsRecoveryCriteria) {
      // Reset recovery timer
      this.recoveryStartedAt = null;
      return false;
    }

    // Start tracking recovery if not already
    if (!this.recoveryStartedAt) {
      this.recoveryStartedAt = Date.now();
      return false;
    }

    // Check if sustained long enough
    const recoveryDuration = Date.now() - this.recoveryStartedAt;
    if (recoveryDuration >= t.sustainedDuration) {
      this.recoveryStartedAt = null; // Reset for next time
      return true;
    }

    return false;
  }

  /**
   * Transition to new state
   */
  private transitionTo(newState: EngagementState): void {
    this.previousState = this.currentState;
    this.currentState = newState;
    this.stateEnteredAt = Date.now();

    // Log transition
    console.log(`[EngagementStateMachine] ${this.previousState} → ${newState}`);

    // Report to ErrorBus for monitoring
    ErrorBus.report({
      code: 'ENGAGEMENT_STATE_CHANGE',
      message: `Engagement state changed: ${this.previousState} → ${newState}`,
      severity: newState === 'NeedsBreak' ? 'warn' : 'info',
      context: {
        previousState: this.previousState,
        newState,
        timeInPreviousState: Date.now() - this.stateEnteredAt
      }
    });
  }

  /**
   * Subscribe to state changes
   */
  onChange(callback: (state: EngagementState, previousState: EngagementState) => void): () => void {
    this.listeners.push(callback);

    return () => {
      this.listeners = this.listeners.filter(l => l !== callback);
    };
  }

  /**
   * Notify all listeners
   */
  private notifyListeners(state: EngagementState, previousState: EngagementState): void {
    for (const listener of this.listeners) {
      try {
        listener(state, previousState);
      } catch (error) {
        console.error('[EngagementStateMachine] Listener error:', error);
      }
    }
  }

  /**
   * Get current state
   */
  getState(): EngagementState {
    return this.currentState;
  }

  /**
   * Get time in current state (ms)
   */
  getTimeInState(): number {
    return Date.now() - this.stateEnteredAt;
  }

  /**
   * Get recent metrics trend
   */
  getMetricsTrend(): {
    improving: boolean;
    stable: boolean;
    declining: boolean;
  } {
    if (this.metricsHistory.length < 5) {
      return { improving: false, stable: true, declining: false };
    }

    // Compare recent 3 vs previous 3
    const recent = this.metricsHistory.slice(-3);
    const previous = this.metricsHistory.slice(-6, -3);

    const recentAvg = this.avgMetrics(recent);
    const previousAvg = this.avgMetrics(previous);

    // Calculate overall quality score
    const recentQuality = this.calculateQuality(recentAvg);
    const previousQuality = this.calculateQuality(previousAvg);

    const change = recentQuality - previousQuality;

    if (change > 5) return { improving: true, stable: false, declining: false };
    if (change < -5) return { improving: false, stable: false, declining: true };
    return { improving: false, stable: true, declining: false };
  }

  /**
   * Average metrics
   */
  private avgMetrics(metrics: EngagementMetrics[]): EngagementMetrics {
    const avg = {
      gazeStability: 0,
      avgResponseDelay: 0,
      tapErrorRate: 0,
      attentionScore: 0,
      emotionValence: 0,
      timeInActivity: 0
    };

    for (const m of metrics) {
      avg.gazeStability += m.gazeStability;
      avg.avgResponseDelay += m.avgResponseDelay;
      avg.tapErrorRate += m.tapErrorRate;
      avg.attentionScore += m.attentionScore;
      avg.emotionValence += m.emotionValence;
      avg.timeInActivity += m.timeInActivity;
    }

    const count = metrics.length;
    return {
      gazeStability: avg.gazeStability / count,
      avgResponseDelay: avg.avgResponseDelay / count,
      tapErrorRate: avg.tapErrorRate / count,
      attentionScore: avg.attentionScore / count,
      emotionValence: avg.emotionValence / count,
      timeInActivity: avg.timeInActivity / count
    };
  }

  /**
   * Calculate overall quality score
   */
  private calculateQuality(metrics: EngagementMetrics): number {
    return (
      metrics.gazeStability * 25 +
      (1 - Math.min(metrics.avgResponseDelay / 5000, 1)) * 25 +
      (1 - metrics.tapErrorRate) * 25 +
      metrics.attentionScore * 0.25
    );
  }

  /**
   * Reset state machine
   */
  reset(): void {
    this.currentState = 'Engaged';
    this.previousState = 'Engaged';
    this.stateEnteredAt = Date.now();
    this.recoveryStartedAt = null;
    this.metricsHistory = [];
  }
}

/**
 * Get UI configuration for current engagement state
 *
 * Adapts UI to reduce cognitive load and provide support
 */
export function nextUIConfig(state: EngagementState, childAge: number): UIConfig {
  // Base configuration
  const baseConfig: UIConfig = {
    buttonSizeMultiplier: 1.0,
    maxChoices: 4,
    maxPromptLength: 100,
    animationIntensity: 0.7,
    interactionPaceMs: 3000,
    enablePositiveReinforcement: true,
    audioVolume: 0.6,
    visualComplexity: 0.7
  };

  // Age adjustments
  if (childAge < 6) {
    // Younger children need simpler UI
    baseConfig.buttonSizeMultiplier = 1.3;
    baseConfig.maxChoices = 2;
    baseConfig.maxPromptLength = 50;
    baseConfig.animationIntensity = 0.9;
    baseConfig.interactionPaceMs = 4000;
  } else if (childAge < 10) {
    baseConfig.buttonSizeMultiplier = 1.1;
    baseConfig.maxChoices = 3;
    baseConfig.maxPromptLength = 75;
  }

  // State-specific adjustments
  switch (state) {
    case 'Engaged':
      // Normal configuration
      return baseConfig;

    case 'SlightlyFatigued':
      // Reduce cognitive load slightly
      return {
        ...baseConfig,
        buttonSizeMultiplier: baseConfig.buttonSizeMultiplier * 1.2,
        maxChoices: Math.max(2, baseConfig.maxChoices - 1),
        maxPromptLength: Math.floor(baseConfig.maxPromptLength * 0.8),
        animationIntensity: Math.min(1.0, baseConfig.animationIntensity * 1.2),
        interactionPaceMs: baseConfig.interactionPaceMs * 1.3,
        enablePositiveReinforcement: true,
        audioVolume: baseConfig.audioVolume * 1.1,
        visualComplexity: baseConfig.visualComplexity * 0.8
      };

    case 'Disengaged':
      // Significantly reduce cognitive load
      return {
        ...baseConfig,
        buttonSizeMultiplier: baseConfig.buttonSizeMultiplier * 1.5,
        maxChoices: 2, // Binary choices only
        maxPromptLength: Math.floor(baseConfig.maxPromptLength * 0.5),
        animationIntensity: 1.0, // Maximum engagement animations
        interactionPaceMs: baseConfig.interactionPaceMs * 1.5,
        enablePositiveReinforcement: true,
        audioVolume: baseConfig.audioVolume * 1.2,
        visualComplexity: 0.4 // Very simple
      };

    case 'NeedsBreak':
      // Minimal interaction, soothing UI
      return {
        ...baseConfig,
        buttonSizeMultiplier: 1.5,
        maxChoices: 1, // Single option (e.g., "Continue when ready")
        maxPromptLength: 30,
        animationIntensity: 0.3, // Calm animations
        interactionPaceMs: 10000, // Very slow pace
        enablePositiveReinforcement: true,
        audioVolume: 0.4, // Quieter
        visualComplexity: 0.2 // Minimal
      };
  }
}

/**
 * USAGE EXAMPLE:
 *
 * // Setup
 * const stateMachine = new EngagementStateMachine();
 *
 * // Subscribe to changes
 * stateMachine.onChange((newState, prevState) => {
 *   console.log(`State changed: ${prevState} → ${newState}`);
 *
 *   // Update UI
 *   const uiConfig = nextUIConfig(newState, childAge);
 *   applyUIConfig(uiConfig);
 *
 *   // Show intervention if needed
 *   if (newState === 'Disengaged') {
 *     showEncouragementAnimation();
 *   } else if (newState === 'NeedsBreak') {
 *     showBreakScreen();
 *   }
 * });
 *
 * // Update in game loop
 * setInterval(() => {
 *   const metrics = collectEngagementMetrics();
 *   const state = stateMachine.update(metrics);
 *
 *   console.log('Current state:', state);
 *   console.log('Time in state:', stateMachine.getTimeInState() / 1000, 'seconds');
 * }, 1000);
 */
