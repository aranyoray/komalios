/**
 * Weighted Domain Scoring and Clinical Priority Bands
 *
 * IMPORTANT DISCLAIMER:
 * These functions provide guidance for educational and support purposes only.
 * They are NOT diagnostic tools and should NOT be used for clinical diagnosis.
 * Always consult qualified healthcare professionals for assessment and intervention.
 */

export type PriorityBand = 'high_support' | 'monitor' | 'strength';

export interface SubdomainScore {
  subdomainId: string;
  score: number;
  weight: number; // Relative importance (0-1)
}

export interface DomainResult {
  domainId: string;
  score: number;
  priority: PriorityBand;
}

/**
 * Compute weighted domain score from subdomain scores
 *
 * Uses weighted average to allow different subdomains to
 * contribute differently to overall domain score.
 *
 * Formula: Σ(score_i × weight_i) / Σ(weight_i)
 *
 * @param subdomains - Array of subdomain scores with weights
 * @returns Weighted domain score (0-100)
 *
 * @example
 * computeDomainScore([
 *   { subdomainId: 'joint-attention', score: 80, weight: 1.2 },
 *   { subdomainId: 'turn-taking', score: 70, weight: 1.0 },
 *   { subdomainId: 'problem-solving', score: 60, weight: 0.8 }
 * ]) // Returns weighted average
 */
export function computeDomainScore(subdomains: SubdomainScore[]): number {
  if (subdomains.length === 0) return 50; // Neutral default

  let weightedSum = 0;
  let totalWeight = 0;

  for (const subdomain of subdomains) {
    // Ensure score is valid
    const clampedScore = Math.max(0, Math.min(100, subdomain.score));

    // Ensure weight is positive
    const validWeight = Math.max(0, subdomain.weight);

    weightedSum += clampedScore * validWeight;
    totalWeight += validWeight;
  }

  if (totalWeight === 0) return 50; // All weights zero

  const domainScore = weightedSum / totalWeight;

  return Math.round(Math.max(0, Math.min(100, domainScore)));
}

/**
 * Determine priority band based on domain score
 *
 * Thresholds (age-adjusted recommended):
 * - <40: HIGH_SUPPORT - Needs significant adult support and practice
 * - 40-70: MONITOR - Developing skill, good target for practice
 * - >70: STRENGTH - Skill appears strong for current age band
 *
 * NOTE: These are guidance thresholds only. Individual variation is normal.
 * NOT diagnostic criteria.
 *
 * @param score - Domain score (0-100)
 * @returns Priority band classification
 *
 * @example
 * domainPriorityBand(35) // Returns 'high_support'
 * domainPriorityBand(55) // Returns 'monitor'
 * domainPriorityBand(85) // Returns 'strength'
 */
export function domainPriorityBand(score: number): PriorityBand {
  const clampedScore = Math.max(0, Math.min(100, score));

  if (clampedScore < 40) {
    return 'high_support';
  } else if (clampedScore <= 70) {
    return 'monitor';
  } else {
    return 'strength';
  }
}

/**
 * Rank domains by priority and score
 *
 * Sorting logic:
 * 1. High support domains first (need most attention)
 * 2. Monitor domains second (targets for practice)
 * 3. Strength domains last (celebrate successes)
 * 4. Within each priority, sort by score (lowest first)
 *
 * This helps caregivers focus on areas needing most support
 * while also celebrating strengths.
 *
 * @param domains - Array of domain IDs and scores
 * @returns Ranked domains with priority bands
 *
 * @example
 * rankDomains([
 *   { domainId: 'social-communication', score: 35 },
 *   { domainId: 'emotional-intelligence', score: 75 },
 *   { domainId: 'cognitive', score: 55 }
 * ])
 * // Returns:
 * // [
 * //   { domainId: 'social-communication', score: 35, priority: 'high_support' },
 * //   { domainId: 'cognitive', score: 55, priority: 'monitor' },
 * //   { domainId: 'emotional-intelligence', score: 75, priority: 'strength' }
 * // ]
 */
export function rankDomains(
  domains: Array<{ domainId: string; score: number }>
): DomainResult[] {
  // Add priority band to each domain
  const domainsWithPriority: DomainResult[] = domains.map(d => ({
    domainId: d.domainId,
    score: d.score,
    priority: domainPriorityBand(d.score)
  }));

  // Priority order for sorting
  const priorityOrder: Record<PriorityBand, number> = {
    high_support: 1,
    monitor: 2,
    strength: 3
  };

  // Sort by priority (high_support first), then by score (lowest first)
  domainsWithPriority.sort((a, b) => {
    // First, compare priorities
    const priorityDiff = priorityOrder[a.priority] - priorityOrder[b.priority];
    if (priorityDiff !== 0) return priorityDiff;

    // If same priority, sort by score (lowest first for high_support/monitor)
    if (a.priority === 'strength') {
      return b.score - a.score; // Highest first for strengths
    } else {
      return a.score - b.score; // Lowest first for support/monitor
    }
  });

  return domainsWithPriority;
}

/**
 * Get human-readable explanation for priority band
 *
 * @param priority - Priority band
 * @returns Explanation text
 */
export function explainPriorityBand(priority: PriorityBand): string {
  switch (priority) {
    case 'high_support':
      return 'This area needs significant support and practice. Consider working with caregivers or professionals to develop strategies.';

    case 'monitor':
      return 'This is a developing skill and a good target for practice. Continue regular activities to strengthen this area.';

    case 'strength':
      return 'This appears to be a strength! Celebrate this progress and continue to nurture this skill.';
  }
}

/**
 * Get suggested focus areas (top 3 priorities)
 *
 * Returns the 3 domains needing most attention, prioritizing
 * high_support bands and lowest scores.
 *
 * @param rankedDomains - Domains ranked by priority
 * @returns Top 3 focus areas
 */
export function getFocusAreas(rankedDomains: DomainResult[]): DomainResult[] {
  // Return high_support and monitor domains (skip strengths)
  const needsAttention = rankedDomains.filter(
    d => d.priority === 'high_support' || d.priority === 'monitor'
  );

  // Return top 3 (or fewer if less than 3)
  return needsAttention.slice(0, 3);
}

/**
 * Get celebration areas (top 2 strengths)
 *
 * Returns the strongest domains to celebrate with child and caregivers.
 *
 * @param rankedDomains - Domains ranked by priority
 * @returns Top 2 strengths
 */
export function getCelebrationAreas(rankedDomains: DomainResult[]): DomainResult[] {
  const strengths = rankedDomains.filter(d => d.priority === 'strength');

  // Return top 2 strengths (highest scores)
  return strengths
    .sort((a, b) => b.score - a.score)
    .slice(0, 2);
}

/**
 * USAGE EXAMPLE:
 *
 * // 1. Compute domain score from subdomains
 * const socialCommScore = computeDomainScore([
 *   { subdomainId: 'joint-attention', score: 75, weight: 1.2 },
 *   { subdomainId: 'turn-taking', score: 80, weight: 1.0 },
 *   { subdomainId: 'nonverbal', score: 70, weight: 0.9 }
 * ]); // Returns weighted average
 *
 * // 2. Determine priority
 * const priority = domainPriorityBand(socialCommScore);
 * console.log(priority); // 'strength' if >70
 *
 * // 3. Rank all domains
 * const ranked = rankDomains([
 *   { domainId: 'social-communication', score: 75 },
 *   { domainId: 'emotional-intelligence', score: 45 },
 *   { domainId: 'cognitive', score: 85 },
 *   { domainId: 'life-skills', score: 35 },
 *   { domainId: 'language', score: 60 }
 * ]);
 *
 * // 4. Get focus areas (for intervention)
 * const focusAreas = getFocusAreas(ranked);
 * // Returns: life-skills (35), emotional-intelligence (45), language (60)
 *
 * // 5. Get celebration areas (to encourage)
 * const celebrations = getCelebrationAreas(ranked);
 * // Returns: cognitive (85), social-communication (75)
 *
 * // IMPORTANT REMINDER:
 * // These are guidance tools for educational support, NOT diagnostic instruments.
 */
