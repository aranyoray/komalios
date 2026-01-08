/**
 * Subdomain Assessment Scheduler
 *
 * Intelligently schedules subdomain assessments to ensure:
 * - Weekly coverage of all age-appropriate subdomains
 * - Proper frequency adherence (every session, 1-2x/week, weekly, etc.)
 * - Balanced distribution across sessions
 * - Priority to overdue assessments
 */

import {
  SUBDOMAIN_FRAMEWORK,
  SubdomainDefinition,
  SessionFrequency,
  getAgeAppropriateSubdomains,
} from './detailedSubdomainFramework';

export interface SubdomainScheduleItem {
  domainKey: string;
  subdomainKey: string;
  subdomain: SubdomainDefinition;
  priority: number; // Higher = more urgent
  daysSinceLastAssessment: number;
}

export interface SessionPlan {
  subdomains: SubdomainScheduleItem[];
  emojiCheckIns: {
    pre_task: string[];
    mid_session: string[];
    post_task: string[];
  };
  estimatedDurationMinutes: number;
}

/**
 * Calculate days since last assessment
 */
function getDaysSince(lastDate: Date | null, currentDate: Date = new Date()): number {
  if (!lastDate) return Infinity; // Never assessed
  return (currentDate.getTime() - lastDate.getTime()) / (1000 * 60 * 60 * 24);
}

/**
 * Calculate expected interval in days for a frequency
 */
function getExpectedIntervalDays(frequency: SessionFrequency): number {
  switch (frequency) {
    case 'every_session':
      return 1;
    case 'every_alternate_session':
      return 2;
    case '1-2_per_week':
      return 4; // Midpoint between 3-7 days
    case '1_per_week':
    case 'weekly':
      return 7;
    default:
      return 7;
  }
}

/**
 * Calculate priority score for a subdomain
 * Higher score = more urgent to assess
 */
function calculatePriority(
  daysSince: number,
  frequency: SessionFrequency,
  subdomain: SubdomainDefinition
): number {
  const expectedInterval = getExpectedIntervalDays(frequency);

  // Base priority: how overdue is it?
  const overdueFactor = daysSince / expectedInterval;

  // Boost for "every_session" frequency
  const frequencyBoost = frequency === 'every_session' ? 2 : 1;

  // Count of tools (more tools = more comprehensive assessment)
  const toolsWeight = subdomain.tools.length / 3; // Normalize to ~1

  return overdueFactor * frequencyBoost * toolsWeight;
}

/**
 * Get prioritized list of subdomains due for assessment
 */
export function getPrioritizedSubdomains(
  ageBand: '3-5' | '6-10' | '11-15',
  lastAssessmentDates: Record<string, Date | null>,
  currentDate: Date = new Date()
): SubdomainScheduleItem[] {
  const items: SubdomainScheduleItem[] = [];

  // Get age-appropriate subdomains
  for (const [domainKey, domain] of Object.entries(SUBDOMAIN_FRAMEWORK)) {
    for (const [subdomainKey, subdomain] of Object.entries(domain.subdomains)) {
      // Check age appropriateness
      if (!subdomain.ageAppropriate[ageBand]) {
        continue;
      }

      const fullKey = `${domainKey}.${subdomainKey}`;
      const lastDate = lastAssessmentDates[fullKey] || null;
      const daysSince = getDaysSince(lastDate, currentDate);

      // Calculate priority
      const priority = calculatePriority(
        daysSince,
        subdomain.sessionFrequency,
        subdomain
      );

      items.push({
        domainKey,
        subdomainKey,
        subdomain,
        priority,
        daysSinceLastAssessment: daysSince === Infinity ? -1 : daysSince,
      });
    }
  }

  // Sort by priority (highest first)
  items.sort((a, b) => b.priority - a.priority);

  return items;
}

/**
 * Create a balanced session plan
 *
 * Selects 2-4 subdomains to assess in a single session:
 * - Highest priority items
 * - Distributed across different domains
 * - Respects time constraints (7-15 minutes)
 */
export function createSessionPlan(
  ageBand: '3-5' | '6-10' | '11-15',
  lastAssessmentDates: Record<string, Date | null>,
  currentDate: Date = new Date(),
  targetDurationMinutes: number = 10
): SessionPlan {
  const prioritized = getPrioritizedSubdomains(ageBand, lastAssessmentDates, currentDate);

  const selectedSubdomains: SubdomainScheduleItem[] = [];
  const domainsUsed = new Set<string>();
  let estimatedDuration = 0;

  // Selection strategy:
  // 1. Always include "every_session" items
  // 2. Add highest priority items from different domains
  // 3. Stop when time limit reached

  for (const item of prioritized) {
    // Time per subdomain assessment: ~2-3 minutes
    const itemDuration = 2.5;

    // Check if adding this would exceed time
    if (estimatedDuration + itemDuration > targetDurationMinutes && selectedSubdomains.length >= 2) {
      break; // Already have at least 2, don't exceed time
    }

    // Prefer diversity across domains (but not strictly required)
    const isDifferentDomain = !domainsUsed.has(item.domainKey);
    const isHighPriority = item.priority > 1.5;

    if (isDifferentDomain || isHighPriority || selectedSubdomains.length < 2) {
      selectedSubdomains.push(item);
      domainsUsed.add(item.domainKey);
      estimatedDuration += itemDuration;
    }

    // Maximum 4 subdomains per session
    if (selectedSubdomains.length >= 4) {
      break;
    }
  }

  // Emoji check-ins
  const emojiCheckIns = {
    pre_task: ['feeling_pre_task'],
    mid_session: [] as string[],
    post_task: ['difficulty_post_task'],
  };

  // Add mid-session check if session is long enough
  if (estimatedDuration > 8) {
    emojiCheckIns.mid_session.push('motivation_check');
  }

  // Add understanding check for comprehension subdomains
  if (selectedSubdomains.some(s => s.subdomainKey === 'comprehension')) {
    emojiCheckIns.post_task.push('understanding_check');
  }

  // Add emotion checks for emotion-related subdomains
  if (selectedSubdomains.some(s =>
    s.domainKey === 'emotional_intelligence' ||
    s.subdomainKey === 'emotion_identification'
  )) {
    emojiCheckIns.mid_session.push('emotion_choice');
  }

  // Account for emoji check-in time (~0.5 min each)
  const totalCheckIns =
    emojiCheckIns.pre_task.length +
    emojiCheckIns.mid_session.length +
    emojiCheckIns.post_task.length;
  estimatedDuration += totalCheckIns * 0.5;

  return {
    subdomains: selectedSubdomains,
    emojiCheckIns,
    estimatedDurationMinutes: Math.round(estimatedDuration),
  };
}

/**
 * Get weekly coverage status
 *
 * Returns which subdomains have been assessed in the last 7 days
 * and which are still pending.
 */
export function getWeeklyCoverageStatus(
  ageBand: '3-5' | '6-10' | '11-15',
  lastAssessmentDates: Record<string, Date | null>,
  currentDate: Date = new Date()
): {
  assessed: string[];
  pending: string[];
  coveragePercentage: number;
} {
  const assessed: string[] = [];
  const pending: string[] = [];
  let totalCount = 0;

  for (const [domainKey, domain] of Object.entries(SUBDOMAIN_FRAMEWORK)) {
    for (const [subdomainKey, subdomain] of Object.entries(domain.subdomains)) {
      if (!subdomain.ageAppropriate[ageBand]) {
        continue;
      }

      totalCount++;
      const fullKey = `${domainKey}.${subdomainKey}`;
      const lastDate = lastAssessmentDates[fullKey];
      const daysSince = getDaysSince(lastDate, currentDate);

      if (daysSince <= 7) {
        assessed.push(fullKey);
      } else {
        pending.push(fullKey);
      }
    }
  }

  const coveragePercentage = totalCount > 0
    ? Math.round((assessed.length / totalCount) * 100)
    : 0;

  return {
    assessed,
    pending,
    coveragePercentage,
  };
}

/**
 * Suggest next session time based on urgency
 *
 * Returns recommended hours until next session.
 */
export function getNextSessionRecommendation(
  ageBand: '3-5' | '6-10' | '11-15',
  lastAssessmentDates: Record<string, Date | null>,
  currentDate: Date = new Date()
): {
  recommendedHoursUntilNext: number;
  urgency: 'low' | 'medium' | 'high';
  reason: string;
} {
  const prioritized = getPrioritizedSubdomains(ageBand, lastAssessmentDates, currentDate);

  if (prioritized.length === 0) {
    return {
      recommendedHoursUntilNext: 24,
      urgency: 'low',
      reason: 'All assessments up to date',
    };
  }

  const topPriority = prioritized[0].priority;

  // High urgency: priority > 2 (more than 2x overdue)
  if (topPriority > 2) {
    return {
      recommendedHoursUntilNext: 0, // Now
      urgency: 'high',
      reason: `${prioritized[0].subdomain.name} is significantly overdue`,
    };
  }

  // Medium urgency: priority > 1 (overdue)
  if (topPriority > 1) {
    return {
      recommendedHoursUntilNext: 12,
      urgency: 'medium',
      reason: `${prioritized[0].subdomain.name} is due for assessment`,
    };
  }

  // Low urgency: priority <= 1 (on schedule)
  return {
    recommendedHoursUntilNext: 24,
    urgency: 'low',
    reason: 'All assessments on schedule',
  };
}

/**
 * Export subdomain assessment record for storage
 */
export function recordSubdomainAssessment(
  domainKey: string,
  subdomainKey: string,
  timestamp: Date = new Date()
): { key: string; timestamp: Date } {
  const key = `${domainKey}.${subdomainKey}`;
  return { key, timestamp };
}

/**
 * Get human-readable session plan summary
 */
export function formatSessionPlanSummary(plan: SessionPlan): string {
  const subdomainNames = plan.subdomains.map(s => s.subdomain.name).join(', ');
  const duration = plan.estimatedDurationMinutes;
  const checkInCount =
    plan.emojiCheckIns.pre_task.length +
    plan.emojiCheckIns.mid_session.length +
    plan.emojiCheckIns.post_task.length;

  return `Session Plan: ${plan.subdomains.length} subdomains (${subdomainNames}) | ${duration} min | ${checkInCount} emoji check-ins`;
}
