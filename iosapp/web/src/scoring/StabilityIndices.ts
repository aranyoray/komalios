/**
 * Stability & Improvement Indices
 *
 * Longitudinal scoring helpers for tracking progress over time.
 * Used in monthly reports to summarize subdomain trajectories.
 */

export type TrajectoryLabel = 'improving' | 'stable' | 'fluctuating' | 'declining';

export interface TrajectoryAnnotation {
  stability: number;      // 0-100
  improvement: number;    // 0-100
  label: TrajectoryLabel;
}

/**
 * Compute stability index from score history
 *
 * Measures consistency of performance over time.
 * Higher scores = more stable trajectories.
 *
 * Formula combines:
 * 1. Inverse of coefficient of variation (CV)
 * 2. Penalty for big drops (>15 points between consecutive scores)
 * 3. Bonus for sustained performance
 *
 * @param scores - Array of scores over time (0-100 each)
 * @returns Stability index (0-100)
 *
 * @example
 * computeStabilityIndex([70, 72, 71, 73, 72]) // High stability (~95)
 * computeStabilityIndex([60, 40, 80, 30, 90]) // Low stability (~20)
 * computeStabilityIndex([50, 65, 70, 75, 80]) // Moderate (~70, improving trend)
 */
export function computeStabilityIndex(scores: number[]): number {
  if (scores.length === 0) return 50; // No data
  if (scores.length === 1) return 75; // Single point, assume moderate stability

  // Calculate mean and standard deviation
  const mean = scores.reduce((sum, s) => sum + s, 0) / scores.length;
  const variance = scores.reduce((sum, s) => sum + Math.pow(s - mean, 2), 0) / scores.length;
  const stdDev = Math.sqrt(variance);

  // Coefficient of variation (CV) - normalized measure of dispersion
  const cv = mean > 0 ? stdDev / mean : 0;

  // Base stability from inverse CV (lower CV = higher stability)
  // CV of 0 = perfect stability (100), CV of 0.5 = moderate (50), CV of 1+ = low (0-20)
  const baseStability = Math.max(0, 100 - cv * 200);

  // Penalty for big drops (consecutive score drops >15 points)
  let bigDrops = 0;
  for (let i = 1; i < scores.length; i++) {
    const drop = scores[i - 1] - scores[i];
    if (drop > 15) bigDrops++;
  }
  const dropPenalty = Math.min(30, bigDrops * 10); // Max 30 point penalty

  // Bonus for sustained performance (all scores within 10 points of mean)
  const sustained = scores.every(s => Math.abs(s - mean) <= 10);
  const sustainedBonus = sustained ? 10 : 0;

  // Final stability score
  const stability = baseStability - dropPenalty + sustainedBonus;

  return Math.round(Math.max(0, Math.min(100, stability)));
}

/**
 * Compute improvement index from score history
 *
 * Measures progress by comparing first third vs last third of scores.
 * Uses effect size-like calculation.
 *
 * Formula:
 * - Compare average of first 1/3 to average of last 1/3
 * - Normalize by pooled standard deviation
 * - Map to 0-100 scale
 *
 * @param scores - Array of scores over time (0-100 each)
 * @returns Improvement index (0-100)
 *   - 50 = no change
 *   - >50 = improvement
 *   - <50 = decline
 *
 * @example
 * computeImprovementIndex([40, 45, 50, 55, 60, 65, 70]) // High improvement (~85)
 * computeImprovementIndex([70, 65, 60, 55, 50, 45, 40]) // Decline (~15)
 * computeImprovementIndex([60, 58, 62, 61, 59, 60, 61]) // Stable (~50)
 */
export function computeImprovementIndex(scores: number[]): number {
  if (scores.length < 3) return 50; // Need at least 3 points

  // Split into first third and last third
  const thirdSize = Math.floor(scores.length / 3);
  const firstThird = scores.slice(0, thirdSize);
  const lastThird = scores.slice(-thirdSize);

  // Calculate means
  const firstMean = firstThird.reduce((sum, s) => sum + s, 0) / firstThird.length;
  const lastMean = lastThird.reduce((sum, s) => sum + s, 0) / lastThird.length;

  // Calculate change
  const change = lastMean - firstMean;

  // Calculate pooled standard deviation for normalization
  const firstVar = firstThird.reduce((sum, s) => sum + Math.pow(s - firstMean, 2), 0) / firstThird.length;
  const lastVar = lastThird.reduce((sum, s) => sum + Math.pow(s - lastMean, 2), 0) / lastThird.length;
  const pooledStdDev = Math.sqrt((firstVar + lastVar) / 2);

  // Effect size (Cohen's d-like measure)
  const effectSize = pooledStdDev > 0 ? change / pooledStdDev : 0;

  // Map effect size to 0-100 scale
  // Effect size of -1 = 0 (large decline)
  // Effect size of 0 = 50 (no change)
  // Effect size of +1 = 100 (large improvement)
  const improvement = 50 + effectSize * 50;

  return Math.round(Math.max(0, Math.min(100, improvement)));
}

/**
 * Annotate trajectory with stability, improvement, and label
 *
 * Combines stability and improvement indices to classify trajectory.
 *
 * Classification logic:
 * - improving: improvement >60 AND stability >40
 * - stable: improvement 40-60 AND stability >60
 * - fluctuating: stability <40
 * - declining: improvement <40 AND stability >40
 *
 * @param scores - Array of scores over time
 * @returns Trajectory annotation with indices and label
 *
 * @example
 * annotateTrajectory([50, 55, 60, 65, 70])
 * // Returns: { stability: 85, improvement: 75, label: 'improving' }
 *
 * annotateTrajectory([70, 40, 80, 30, 90])
 * // Returns: { stability: 20, improvement: 55, label: 'fluctuating' }
 */
export function annotateTrajectory(scores: number[]): TrajectoryAnnotation {
  if (scores.length === 0) {
    return {
      stability: 50,
      improvement: 50,
      label: 'stable'
    };
  }

  const stability = computeStabilityIndex(scores);
  const improvement = computeImprovementIndex(scores);

  // Determine label
  let label: TrajectoryLabel;

  if (stability < 40) {
    // Low stability = fluctuating regardless of improvement
    label = 'fluctuating';
  } else if (improvement >= 60) {
    // High improvement + good stability = improving
    label = 'improving';
  } else if (improvement <= 40) {
    // Low improvement + good stability = declining
    label = 'declining';
  } else {
    // Moderate improvement + good stability = stable
    label = 'stable';
  }

  return {
    stability,
    improvement,
    label
  };
}

/**
 * Get human-readable trajectory description
 *
 * @param annotation - Trajectory annotation
 * @returns Description text
 */
export function describeTrajectory(annotation: TrajectoryAnnotation): string {
  const { stability, improvement, label } = annotation;

  switch (label) {
    case 'improving':
      return `This skill is showing improvement over time (improvement: ${improvement}/100). ` +
             `Performance is ${stability > 70 ? 'consistent' : 'moderately consistent'}.`;

    case 'stable':
      return `This skill is stable over time (stability: ${stability}/100). ` +
             `Performance is consistent with minor variations.`;

    case 'fluctuating':
      return `This skill shows variable performance (stability: ${stability}/100). ` +
             `Focus on consistency may help. Consider external factors affecting performance.`;

    case 'declining':
      return `This skill may need extra attention (improvement: ${improvement}/100). ` +
             `Consider increasing practice or support in this area.`;
  }
}

/**
 * Suggest actions based on trajectory
 *
 * @param annotation - Trajectory annotation
 * @returns Array of suggested actions
 */
export function suggestActionsForTrajectory(annotation: TrajectoryAnnotation): string[] {
  const actions: string[] = [];

  switch (annotation.label) {
    case 'improving':
      actions.push('Continue current approach - it\'s working!');
      actions.push('Gradually increase challenge level');
      actions.push('Celebrate progress with the child');
      break;

    case 'stable':
      actions.push('Maintain current practice routine');
      actions.push('Look for opportunities to apply skill in new contexts');
      actions.push('Consider small challenges to encourage growth');
      break;

    case 'fluctuating':
      actions.push('Review external factors (sleep, stress, environment)');
      actions.push('Increase consistency in practice schedule');
      actions.push('Break tasks into smaller, more manageable steps');
      actions.push('Provide more structured support during activities');
      break;

    case 'declining':
      actions.push('Increase frequency of practice sessions');
      actions.push('Simplify tasks temporarily to rebuild confidence');
      actions.push('Consider consulting with educators or professionals');
      actions.push('Review and adjust support strategies');
      break;
  }

  return actions;
}

/**
 * USAGE EXAMPLE:
 *
 * // Track joint attention scores over 8 weeks
 * const jointAttentionScores = [45, 48, 52, 50, 55, 58, 60, 62];
 *
 * // Compute indices
 * const stability = computeStabilityIndex(jointAttentionScores);
 * console.log('Stability:', stability); // ~85 (consistent improvement)
 *
 * const improvement = computeImprovementIndex(jointAttentionScores);
 * console.log('Improvement:', improvement); // ~70 (clear progress)
 *
 * // Get full annotation
 * const trajectory = annotateTrajectory(jointAttentionScores);
 * console.log(trajectory);
 * // { stability: 85, improvement: 70, label: 'improving' }
 *
 * // Get description and suggestions
 * console.log(describeTrajectory(trajectory));
 * // "This skill is showing improvement over time..."
 *
 * const actions = suggestActionsForTrajectory(trajectory);
 * console.log(actions);
 * // ["Continue current approach - it's working!", ...]
 *
 * // Use in monthly report:
 * const report = {
 *   subdomain: 'Joint Attention',
 *   trajectory,
 *   description: describeTrajectory(trajectory),
 *   suggestedActions: suggestActionsForTrajectory(trajectory),
 *   weeklyScores: jointAttentionScores
 * };
 */
