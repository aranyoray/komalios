/**
 * Difficulty-Adjusted Scoring Utilities
 *
 * Provides helpers for normalizing, adjusting, and aggregating scores
 * based on task difficulty to ensure fair assessment across varying
 * challenge levels.
 */

export type Difficulty = 'easy' | 'medium' | 'hard';

export interface MetricScore {
  metricId: string;
  score: number;
  difficulty: Difficulty;
}

/**
 * Normalize raw score to 0-100 range
 *
 * Maps a raw score from [min, max] range to [0, 100]
 * Clamps values outside the range
 *
 * @param raw - Raw score value
 * @param min - Minimum expected value
 * @param max - Maximum expected value
 * @returns Normalized score in [0, 100]
 *
 * @example
 * normalizeScore(500, 0, 1000) // Returns 50
 * normalizeScore(-10, 0, 100) // Returns 0 (clamped)
 * normalizeScore(150, 0, 100) // Returns 100 (clamped)
 */
export function normalizeScore(raw: number, min: number, max: number): number {
  if (max === min) return 50; // Neutral if no range

  // Linear mapping to [0, 100]
  const normalized = ((raw - min) / (max - min)) * 100;

  // Clamp to [0, 100]
  return Math.max(0, Math.min(100, Math.round(normalized)));
}

/**
 * Adjust score based on task difficulty
 *
 * Philosophy:
 * - Easy tasks: Score as-is (expected high performance)
 * - Medium tasks: Slight boost (5-10%) for good performance
 * - Hard tasks: Reward effort, avoid over-penalizing
 *   - Scores >60 get 10-15% boost
 *   - Scores <60 get gentler treatment (small boost to avoid discouragement)
 *
 * @param score - Raw score (0-100)
 * @param difficulty - Task difficulty level
 * @returns Adjusted score (0-100)
 *
 * @example
 * difficultyAdjust(80, 'hard') // Returns ~88-92 (rewarded for hard task)
 * difficultyAdjust(40, 'hard') // Returns ~45-48 (gentle boost, not penalized)
 * difficultyAdjust(90, 'easy') // Returns 90 (no adjustment)
 */
export function difficultyAdjust(score: number, difficulty: Difficulty): number {
  // Clamp input
  const clampedScore = Math.max(0, Math.min(100, score));

  switch (difficulty) {
    case 'easy':
      // No adjustment - easy tasks should be performed well
      return clampedScore;

    case 'medium':
      // Slight boost for good performance (5-7%)
      if (clampedScore >= 70) {
        const boost = clampedScore * 0.06; // 6% boost
        return Math.min(100, Math.round(clampedScore + boost));
      }
      return clampedScore;

    case 'hard':
      // Reward effort on hard tasks
      if (clampedScore >= 60) {
        // Good performance: 10-15% boost
        const boost = clampedScore * 0.12; // 12% boost
        return Math.min(100, Math.round(clampedScore + boost));
      } else {
        // Lower performance: gentle boost (5-8%) to avoid discouragement
        const boost = clampedScore * 0.07; // 7% boost
        return Math.min(100, Math.round(clampedScore + boost));
      }

    default:
      return clampedScore;
  }
}

/**
 * Aggregate multiple metric scores into single subdomain score
 *
 * Uses difficulty-aware weighting:
 * - Hard task scores weighted 1.3x
 * - Medium task scores weighted 1.1x
 * - Easy task scores weighted 1.0x
 *
 * This ensures harder tasks contribute more to the final score,
 * rewarding children who tackle challenging material.
 *
 * @param metricScores - Array of metric scores with difficulties
 * @returns Aggregated subdomain score (0-100)
 *
 * @example
 * aggregateMetricScores([
 *   { metricId: 'vocab', score: 80, difficulty: 'hard' },
 *   { metricId: 'grammar', score: 90, difficulty: 'easy' },
 *   { metricId: 'fluency', score: 70, difficulty: 'medium' }
 * ]) // Returns weighted average
 */
export function aggregateMetricScores(metricScores: MetricScore[]): number {
  if (metricScores.length === 0) return 50; // Neutral default

  // Difficulty weight multipliers
  const difficultyWeights: Record<Difficulty, number> = {
    easy: 1.0,
    medium: 1.1,
    hard: 1.3
  };

  let weightedSum = 0;
  let totalWeight = 0;

  for (const metric of metricScores) {
    // Adjust score for difficulty
    const adjustedScore = difficultyAdjust(metric.score, metric.difficulty);

    // Apply difficulty weight
    const weight = difficultyWeights[metric.difficulty];
    weightedSum += adjustedScore * weight;
    totalWeight += weight;
  }

  // Calculate weighted average
  const aggregated = totalWeight > 0 ? weightedSum / totalWeight : 50;

  return Math.round(Math.max(0, Math.min(100, aggregated)));
}

/**
 * USAGE EXAMPLE:
 *
 * // 1. Normalize raw latency to 0-100
 * const latencyScore = normalizeScore(1500, 500, 3000);
 * // 1500ms latency → 50/100
 *
 * // 2. Adjust for difficulty
 * const adjusted = difficultyAdjust(75, 'hard');
 * // 75 on hard task → ~84 (rewarded)
 *
 * // 3. Aggregate multiple metrics
 * const subdomainScore = aggregateMetricScores([
 *   { metricId: 'attention', score: 80, difficulty: 'hard' },
 *   { metricId: 'memory', score: 70, difficulty: 'medium' },
 *   { metricId: 'speed', score: 90, difficulty: 'easy' }
 * ]);
 * // Returns weighted average with difficulty adjustments
 */
