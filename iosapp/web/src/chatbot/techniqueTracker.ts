/**
 * Technique Effectiveness Tracker
 *
 * Tracks therapeutic technique effectiveness across conversations.
 * Helps identify which methods work best for each child and situation.
 *
 * RESEARCH FOUNDATIONS:
 * - A/B testing in clinical settings (Kazdin, 2011) - Single-case design
 * - Treatment response prediction (Lutz et al., 2006) - Progress monitoring
 * - Evidence-based practice (APA, 2006) - Systematic effectiveness tracking
 */

import { TherapeuticTechnique, Message } from './komalChatbot';
import { ErrorBus } from '../core/ErrorBus';

export interface TechniqueUse {
  technique: TherapeuticTechnique;
  timestamp: number;
  childAge: number;
  ageBand: '3-5' | '6-10' | '11-15';
  context: {
    detectedEmotion?: string;
    situation?: string;
    targetDomain?: string;
  };
  outcome: TechniqueOutcome | null; // Set after child responds
}

export interface TechniqueOutcome {
  childEngagement: number;      // 0-100: Did child respond positively?
  emotionalShift: number;        // -100 to +100: Emotion change (negative to positive)
  conversationContinued: boolean; // Did conversation continue naturally?
  messageLength: number;         // Length of child's next response
  responseTime: number;          // Seconds until child responded
}

export interface TechniqueStats {
  technique: TherapeuticTechnique;
  totalUses: number;
  avgEngagement: number;
  avgEmotionalShift: number;
  continuationRate: number;      // % of times conversation continued
  successRate: number;           // Overall effectiveness (0-100)
  ageBandBreakdown: Record<string, { uses: number, successRate: number }>;
  contextBreakdown: Record<string, { uses: number, successRate: number }>;
}

export interface TechniqueComparison {
  bestTechnique: TherapeuticTechnique;
  worstTechnique: TherapeuticTechnique;
  stats: TechniqueStats[];
  recommendations: string[];
}

/**
 * ============================================================================
 * TECHNIQUE TRACKER CLASS
 * ============================================================================
 */

export class TechniqueTracker {
  private techniqueHistory: TechniqueUse[] = [];
  private childId: string;

  constructor(childId: string, existingHistory?: TechniqueUse[]) {
    this.childId = childId;
    if (existingHistory) {
      this.techniqueHistory = existingHistory;
    }
  }

  /**
   * Record technique use
   *
   * Called when Komal generates response using specific technique.
   * Outcome is filled in later after child responds.
   *
   * @param technique - Technique used
   * @param childAge - Child's age
   * @param ageBand - Age band
   * @param context - Contextual information
   * @returns Technique use ID
   */
  recordTechniqueUse(
    technique: TherapeuticTechnique,
    childAge: number,
    ageBand: '3-5' | '6-10' | '11-15',
    context: TechniqueUse['context']
  ): number {
    const use: TechniqueUse = {
      technique,
      timestamp: Date.now(),
      childAge,
      ageBand,
      context,
      outcome: null
    };

    this.techniqueHistory.push(use);
    return this.techniqueHistory.length - 1; // Return index as ID
  }

  /**
   * Record outcome after child responds
   *
   * Analyzes child's response to measure technique effectiveness.
   *
   * Outcome indicators (Kazdin, 2011):
   * - Engagement: Did child provide substantive response?
   * - Emotional shift: Did emotion improve?
   * - Continuation: Did conversation continue naturally?
   *
   * @param useId - Technique use ID
   * @param childResponse - Child's response message
   * @param previousEmotion - Emotion before technique
   * @param currentEmotion - Emotion after technique
   */
  recordOutcome(
    useId: number,
    childResponse: Message,
    previousEmotion?: string,
    currentEmotion?: string
  ): void {
    if (useId < 0 || useId >= this.techniqueHistory.length) {
      ErrorBus.report({
        code: 'INVALID_TECHNIQUE_USE_ID',
        message: `Invalid technique use ID: ${useId}`,
        severity: 'warn',
        context: { useId }
      });
      return;
    }

    const use = this.techniqueHistory[useId];

    // Compute engagement (message length and quality)
    const childEngagement = this.computeEngagement(childResponse.content);

    // Compute emotional shift
    const emotionalShift = this.computeEmotionalShift(previousEmotion, currentEmotion);

    // Check if conversation continued (child didn't disengage)
    const conversationContinued = childResponse.content.length > 5 &&
                                  !childResponse.content.toLowerCase().includes('bye');

    // Response time (if available)
    const responseTime = use.timestamp > 0
      ? (childResponse.timestamp - use.timestamp) / 1000
      : 0;

    use.outcome = {
      childEngagement,
      emotionalShift,
      conversationContinued,
      messageLength: childResponse.content.length,
      responseTime
    };
  }

  /**
   * Compute engagement from child's response
   *
   * Based on:
   * - Message length (longer = more engaged)
   * - Substantive content (not just "ok" or "yeah")
   * - Elaboration (multiple sentences)
   *
   * @param response - Child's response text
   * @returns Engagement score 0-100
   */
  private computeEngagement(response: string): number {
    const length = response.length;
    const words = response.split(/\s+/).length;
    const sentences = response.split(/[.!?]+/).filter(s => s.trim().length > 0).length;

    // Check for low-engagement responses
    const lowEngagementPhrases = ['ok', 'yeah', 'no', 'idk', 'maybe', 'i guess'];
    const isLowEngagement = lowEngagementPhrases.some(phrase =>
      response.toLowerCase().trim() === phrase
    );

    if (isLowEngagement) return 20; // Low engagement

    // Score based on length and elaboration
    const lengthScore = Math.min(100, length / 2); // 200 chars = 100
    const wordScore = Math.min(100, words * 10);   // 10 words = 100
    const sentenceBonus = sentences > 1 ? 20 : 0;  // Bonus for multiple sentences

    const score = (lengthScore * 0.4 + wordScore * 0.4 + sentenceBonus * 0.2);

    return Math.round(Math.max(0, Math.min(100, score)));
  }

  /**
   * Compute emotional shift
   *
   * Based on emotion valence change from before to after technique.
   *
   * Emotion valence (Russell, 1980):
   * - Positive: happy, excited, proud, calm (+50 to +100)
   * - Neutral: okay, confused (0)
   * - Negative: sad, angry, scared, frustrated (-100 to -50)
   *
   * @param previousEmotion - Emotion before technique
   * @param currentEmotion - Emotion after technique
   * @returns Shift score -100 to +100
   */
  private computeEmotionalShift(
    previousEmotion?: string,
    currentEmotion?: string
  ): number {
    if (!previousEmotion || !currentEmotion) return 0;

    const emotionValence: Record<string, number> = {
      happy: 80, excited: 90, proud: 85, calm: 70, glad: 75,
      okay: 0, confused: -10,
      sad: -70, angry: -80, mad: -80, scared: -75, worried: -65,
      frustrated: -60, upset: -70
    };

    const prevValence = emotionValence[previousEmotion.toLowerCase()] || 0;
    const currValence = emotionValence[currentEmotion.toLowerCase()] || 0;

    const shift = currValence - prevValence;

    return Math.max(-100, Math.min(100, shift));
  }

  /**
   * Get technique statistics
   *
   * Aggregates effectiveness metrics for each technique.
   *
   * @returns Array of technique stats
   */
  getTechniqueStats(): TechniqueStats[] {
    const techniques: TherapeuticTechnique[] = [
      'rogerian_reflection',
      'emotion_coaching',
      'cbt_thought_challenge',
      'social_story',
      'open_ended_exploration',
      'scaffolded_question',
      'validation_affirmation'
    ];

    return techniques.map(technique => {
      const uses = this.techniqueHistory.filter(u => u.technique === technique);
      const usesWithOutcome = uses.filter(u => u.outcome !== null);

      if (usesWithOutcome.length === 0) {
        return {
          technique,
          totalUses: uses.length,
          avgEngagement: 0,
          avgEmotionalShift: 0,
          continuationRate: 0,
          successRate: 0,
          ageBandBreakdown: {},
          contextBreakdown: {}
        };
      }

      // Compute averages
      const avgEngagement = usesWithOutcome.reduce((sum, u) =>
        sum + (u.outcome?.childEngagement || 0), 0
      ) / usesWithOutcome.length;

      const avgEmotionalShift = usesWithOutcome.reduce((sum, u) =>
        sum + (u.outcome?.emotionalShift || 0), 0
      ) / usesWithOutcome.length;

      const continuationRate = usesWithOutcome.filter(u =>
        u.outcome?.conversationContinued
      ).length / usesWithOutcome.length * 100;

      // Overall success rate (composite)
      const successRate = this.computeSuccessRate(usesWithOutcome);

      // Age band breakdown
      const ageBandBreakdown = this.computeAgeBandBreakdown(usesWithOutcome);

      // Context breakdown
      const contextBreakdown = this.computeContextBreakdown(usesWithOutcome);

      return {
        technique,
        totalUses: uses.length,
        avgEngagement: Math.round(avgEngagement),
        avgEmotionalShift: Math.round(avgEmotionalShift),
        continuationRate: Math.round(continuationRate),
        successRate: Math.round(successRate),
        ageBandBreakdown,
        contextBreakdown
      };
    });
  }

  /**
   * Compute overall success rate for technique
   *
   * Composite score based on:
   * - Engagement (40%)
   * - Emotional shift (30%)
   * - Continuation rate (30%)
   *
   * @param uses - Technique uses with outcomes
   * @returns Success rate 0-100
   */
  private computeSuccessRate(uses: TechniqueUse[]): number {
    if (uses.length === 0) return 0;

    const avgEngagement = uses.reduce((sum, u) =>
      sum + (u.outcome?.childEngagement || 0), 0
    ) / uses.length;

    const avgEmotionalShift = uses.reduce((sum, u) =>
      sum + (u.outcome?.emotionalShift || 0), 0
    ) / uses.length;

    // Normalize emotional shift from -100-100 to 0-100
    const normalizedShift = (avgEmotionalShift + 100) / 2;

    const continuationRate = uses.filter(u =>
      u.outcome?.conversationContinued
    ).length / uses.length * 100;

    const successRate = (
      avgEngagement * 0.4 +
      normalizedShift * 0.3 +
      continuationRate * 0.3
    );

    return successRate;
  }

  /**
   * Compute age band breakdown
   */
  private computeAgeBandBreakdown(
    uses: TechniqueUse[]
  ): Record<string, { uses: number, successRate: number }> {
    const breakdown: Record<string, TechniqueUse[]> = {
      '3-5': [],
      '6-10': [],
      '11-15': []
    };

    uses.forEach(use => {
      breakdown[use.ageBand].push(use);
    });

    const result: Record<string, { uses: number, successRate: number }> = {};

    Object.entries(breakdown).forEach(([band, bandUses]) => {
      result[band] = {
        uses: bandUses.length,
        successRate: Math.round(this.computeSuccessRate(bandUses))
      };
    });

    return result;
  }

  /**
   * Compute context breakdown (by emotion type)
   */
  private computeContextBreakdown(
    uses: TechniqueUse[]
  ): Record<string, { uses: number, successRate: number }> {
    const breakdown: Record<string, TechniqueUse[]> = {};

    uses.forEach(use => {
      const emotion = use.context.detectedEmotion || 'neutral';
      if (!breakdown[emotion]) breakdown[emotion] = [];
      breakdown[emotion].push(use);
    });

    const result: Record<string, { uses: number, successRate: number }> = {};

    Object.entries(breakdown).forEach(([emotion, emotionUses]) => {
      result[emotion] = {
        uses: emotionUses.length,
        successRate: Math.round(this.computeSuccessRate(emotionUses))
      };
    });

    return result;
  }

  /**
   * Compare techniques and generate recommendations
   *
   * Identifies most/least effective techniques and provides actionable advice.
   *
   * @param minSampleSize - Minimum uses required for comparison (default 3)
   * @returns Comparison report with recommendations
   */
  compareTechniques(minSampleSize: number = 3): TechniqueComparison {
    const stats = this.getTechniqueStats();

    // Filter techniques with enough data
    const validStats = stats.filter(s => s.totalUses >= minSampleSize);

    if (validStats.length === 0) {
      return {
        bestTechnique: 'rogerian_reflection',
        worstTechnique: 'rogerian_reflection',
        stats,
        recommendations: ['Need more conversation data to compare techniques effectively.']
      };
    }

    // Sort by success rate
    const sorted = [...validStats].sort((a, b) => b.successRate - a.successRate);

    const bestTechnique = sorted[0].technique;
    const worstTechnique = sorted[sorted.length - 1].technique;

    // Generate recommendations
    const recommendations = this.generateRecommendations(sorted);

    return {
      bestTechnique,
      worstTechnique,
      stats,
      recommendations
    };
  }

  /**
   * Generate personalized recommendations
   *
   * Based on technique effectiveness patterns (Lutz et al., 2006)
   *
   * @param sortedStats - Techniques sorted by success rate
   * @returns Array of recommendations
   */
  private generateRecommendations(sortedStats: TechniqueStats[]): string[] {
    const recommendations: string[] = [];
    const best = sortedStats[0];
    const worst = sortedStats[sortedStats.length - 1];

    // Recommendation 1: Best technique
    recommendations.push(
      `${this.getTechniqueName(best.technique)} is working best for this child ` +
      `(${best.successRate}% success rate). Use this approach more frequently.`
    );

    // Recommendation 2: Age-specific insight
    const ageInsight = this.getAgeInsight(best);
    if (ageInsight) recommendations.push(ageInsight);

    // Recommendation 3: Emotional context insight
    const emotionInsight = this.getEmotionInsight(best);
    if (emotionInsight) recommendations.push(emotionInsight);

    // Recommendation 4: Technique to avoid/modify
    if (worst.successRate < 40) {
      recommendations.push(
        `${this.getTechniqueName(worst.technique)} seems less effective ` +
        `(${worst.successRate}% success rate). Consider using it less or modifying approach.`
      );
    }

    // Recommendation 5: Engagement tip
    const avgEngagement = sortedStats.reduce((sum, s) => sum + s.avgEngagement, 0) / sortedStats.length;
    if (avgEngagement < 50) {
      recommendations.push(
        'Overall engagement is moderate. Try more open-ended questions and follow child\'s interests.'
      );
    }

    return recommendations;
  }

  /**
   * Get age-specific insight
   */
  private getAgeInsight(stats: TechniqueStats): string | null {
    const bands = Object.entries(stats.ageBandBreakdown);
    if (bands.length === 0) return null;

    const bestBand = bands.sort((a, b) => b[1].successRate - a[1].successRate)[0];

    if (bestBand[1].successRate > stats.successRate + 10) {
      return `This technique works especially well with age ${bestBand[0]} children.`;
    }

    return null;
  }

  /**
   * Get emotion-specific insight
   */
  private getEmotionInsight(stats: TechniqueStats): string | null {
    const contexts = Object.entries(stats.contextBreakdown);
    if (contexts.length === 0) return null;

    const bestContext = contexts.sort((a, b) => b[1].successRate - a[1].successRate)[0];

    if (bestContext[1].successRate > stats.successRate + 15) {
      return `Particularly effective when child is feeling ${bestContext[0]}.`;
    }

    return null;
  }

  /**
   * Get human-readable technique name
   */
  private getTechniqueName(technique: TherapeuticTechnique): string {
    const names: Record<TherapeuticTechnique, string> = {
      rogerian_reflection: 'Reflective listening',
      emotion_coaching: 'Emotion coaching',
      cbt_thought_challenge: 'Thought reframing',
      social_story: 'Social stories',
      open_ended_exploration: 'Open exploration',
      scaffolded_question: 'Guided questioning',
      validation_affirmation: 'Validation & affirmation'
    };

    return names[technique];
  }

  /**
   * Export history for storage
   */
  exportHistory(): TechniqueUse[] {
    return this.techniqueHistory;
  }

  /**
   * Get total technique uses
   */
  getTotalUses(): number {
    return this.techniqueHistory.length;
  }
}

/**
 * USAGE EXAMPLE:
 *
 * // Initialize tracker for child
 * const tracker = new TechniqueTracker('child-123');
 *
 * // Record technique use
 * const useId = tracker.recordTechniqueUse(
 *   'emotion_coaching',
 *   7,
 *   '6-10',
 *   { detectedEmotion: 'angry', targetDomain: 'emotional-intelligence' }
 * );
 *
 * // After child responds
 * tracker.recordOutcome(
 *   useId,
 *   childResponse,
 *   'angry',
 *   'calm'
 * );
 *
 * // Get statistics
 * const stats = tracker.getTechniqueStats();
 * console.log(stats);
 * // [
 * //   { technique: 'emotion_coaching', totalUses: 5, successRate: 85, ... },
 * //   { technique: 'rogerian_reflection', totalUses: 8, successRate: 72, ... }
 * // ]
 *
 * // Compare techniques
 * const comparison = tracker.compareTechniques();
 * console.log('Best technique:', comparison.bestTechnique);
 * console.log('Recommendations:', comparison.recommendations);
 * // [
 * //   "Emotion coaching is working best for this child (85% success rate)...",
 * //   "This technique works especially well with age 6-10 children.",
 * //   "Particularly effective when child is feeling angry."
 * // ]
 */
