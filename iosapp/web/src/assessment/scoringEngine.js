/**
 * Clinical Scoring Engine for Komal
 * Converts tracking data to 0-100 domain scores
 * Based on research-validated criteria and normative data
 */

import { DEVELOPMENTAL_DOMAINS, RISK_LEVELS, getAgeGroup } from './developmentalDomains';

class ScoringEngine {
  /**
   * Calculate domain scores from session data
   * @param {Object} sessionData - Complete session with all tracking data
   * @param {number} childAge - Child's age in years
   * @returns {Object} Domain scores (0-100) and risk assessments
   */
  calculateDomainScores(sessionData, childAge) {
    const ageGroup = getAgeGroup(childAge);
    const domainScores = {};

    // Calculate score for each domain
    for (const [key, domain] of Object.entries(DEVELOPMENTAL_DOMAINS)) {
      const score = this.calculateDomainScore(
        domain,
        sessionData,
        ageGroup,
        childAge
      );

      domainScores[domain.id] = {
        score: Math.round(score),
        domain: domain.name,
        shortName: domain.shortName,
        isPrimary: domain.isPrimary,
        riskLevel: this.getRiskLevel(score),
        color: domain.color,
        interpretation: this.getInterpretation(score, domain.name),
        contributors: this.getTopContributors(domain, sessionData, score)
      };
    }

    return domainScores;
  }

  /**
   * Calculate single domain score
   */
  calculateDomainScore(domain, sessionData, ageGroup, childAge) {
    const metrics = domain.trackingMetrics;
    let totalScore = 0;
    let totalWeight = 0;

    // Eye tracking metrics
    if (metrics.eyeTracking && sessionData.eyeTracking) {
      for (const [metric, config] of Object.entries(metrics.eyeTracking)) {
        const value = sessionData.eyeTracking[metric];
        if (value !== undefined && value !== null) {
          const normalized = this.normalizeMetric(
            metric,
            value,
            ageGroup,
            config.inverse
          );
          totalScore += normalized * config.weight;
          totalWeight += config.weight;
        }
      }
    }

    // Micro-expressions metrics
    if (metrics.microExpressions && sessionData.microExpressions) {
      for (const [metric, config] of Object.entries(metrics.microExpressions)) {
        const value = sessionData.microExpressions[metric];
        if (value !== undefined && value !== null) {
          const normalized = this.normalizeMetric(
            metric,
            value,
            ageGroup,
            config.inverse
          );
          totalScore += normalized * config.weight;
          totalWeight += config.weight;
        }
      }
    }

    // Touch tracking metrics
    if (metrics.touchTracking && sessionData.touchTracking) {
      for (const [metric, config] of Object.entries(metrics.touchTracking)) {
        const value = sessionData.touchTracking[metric];
        if (value !== undefined && value !== null) {
          const normalized = this.normalizeMetric(
            metric,
            value,
            ageGroup,
            config.inverse
          );
          totalScore += normalized * config.weight;
          totalWeight += config.weight;
        }
      }
    }

    // Voice tracking metrics
    if (metrics.voiceTracking && sessionData.voiceTracking) {
      for (const [metric, config] of Object.entries(metrics.voiceTracking)) {
        const value = sessionData.voiceTracking[metric];
        if (value !== undefined && value !== null) {
          const normalized = this.normalizeMetric(
            metric,
            value,
            ageGroup,
            config.inverse
          );
          totalScore += normalized * config.weight;
          totalWeight += config.weight;
        }
      }
    }

    // Response patterns
    if (metrics.responsePatterns && sessionData.responsePatterns) {
      for (const [metric, config] of Object.entries(metrics.responsePatterns)) {
        const value = sessionData.responsePatterns[metric];
        if (value !== undefined && value !== null) {
          const normalized = this.normalizeMetric(
            metric,
            value,
            ageGroup,
            config.inverse
          );
          totalScore += normalized * config.weight;
          totalWeight += config.weight;
        }
      }
    }

    // Overall metrics
    if (metrics.overall) {
      for (const [metric, config] of Object.entries(metrics.overall)) {
        let value;
        if (metric === 'taskCompletionRate') {
          value = sessionData.tasksCompleted / Math.max(1, sessionData.tasksTotal);
        }
        if (value !== undefined && value !== null) {
          const normalized = this.normalizeMetric(
            metric,
            value,
            ageGroup,
            config.inverse
          );
          totalScore += normalized * config.weight;
          totalWeight += config.weight;
        }
      }
    }

    // Calculate final score (0-100)
    const finalScore = totalWeight > 0 ? (totalScore / totalWeight) * 100 : 50;

    // Age-based adjustment (younger children naturally score lower)
    const ageAdjustment = this.getAgeAdjustment(childAge);

    return Math.max(0, Math.min(100, finalScore + ageAdjustment));
  }

  /**
   * Normalize metric to 0-1 range based on research norms
   */
  normalizeMetric(metricName, value, ageGroup, inverse = false) {
    // Research-based normative ranges by age group
    const norms = {
      // Eye tracking
      attentionScore: {
        PRESCHOOL: { min: 40, max: 70 },
        ELEMENTARY: { min: 50, max: 80 },
        PRETEEN: { min: 60, max: 90 }
      },
      concentrationStability: {
        PRESCHOOL: { min: 0.4, max: 0.7 },
        ELEMENTARY: { min: 0.5, max: 0.8 },
        PRETEEN: { min: 0.6, max: 0.9 }
      },
      socialGazeIndex: {
        PRESCHOOL: { min: 0.3, max: 0.7 },
        ELEMENTARY: { min: 0.4, max: 0.8 },
        PRETEEN: { min: 0.5, max: 0.85 }
      },
      avgFixationDuration: {
        PRESCHOOL: { min: 1.0, max: 3.0 },
        ELEMENTARY: { min: 1.5, max: 4.0 },
        PRETEEN: { min: 2.0, max: 5.0 }
      },
      gazeAversions: {
        PRESCHOOL: { min: 0, max: 10 },
        ELEMENTARY: { min: 0, max: 7 },
        PRETEEN: { min: 0, max: 5 }
      },

      // Micro-expressions
      affectDiversityScore: {
        PRESCHOOL: { min: 3, max: 6 },
        ELEMENTARY: { min: 4, max: 7 },
        PRETEEN: { min: 5, max: 7 }
      },
      frustrationToleranceIndex: {
        PRESCHOOL: { min: 0.3, max: 0.7 },
        ELEMENTARY: { min: 0.4, max: 0.8 },
        PRETEEN: { min: 0.5, max: 0.9 }
      },
      empathyResponse: {
        PRESCHOOL: { min: 0.3, max: 0.6 },
        ELEMENTARY: { min: 0.4, max: 0.75 },
        PRETEEN: { min: 0.5, max: 0.85 }
      },
      positiveAffectActivation: {
        PRESCHOOL: { min: 0.4, max: 0.8 },
        ELEMENTARY: { min: 0.5, max: 0.85 },
        PRETEEN: { min: 0.5, max: 0.9 }
      },

      // Touch tracking
      goalDirectedAccuracy: {
        PRESCHOOL: { min: 0.5, max: 0.8 },
        ELEMENTARY: { min: 0.6, max: 0.9 },
        PRETEEN: { min: 0.7, max: 0.95 }
      },
      hesitationTaps: {
        PRESCHOOL: { min: 0, max: 20 },
        ELEMENTARY: { min: 0, max: 15 },
        PRETEEN: { min: 0, max: 10 }
      },

      // Voice tracking
      vocalActivity: {
        PRESCHOOL: { min: 0.2, max: 0.6 },
        ELEMENTARY: { min: 0.3, max: 0.7 },
        PRETEEN: { min: 0.35, max: 0.75 }
      },
      speechRate: {
        PRESCHOOL: { min: 60, max: 120 },
        ELEMENTARY: { min: 80, max: 150 },
        PRETEEN: { min: 100, max: 180 }
      },
      confidence: {
        PRESCHOOL: { min: 0.4, max: 0.7 },
        ELEMENTARY: { min: 0.5, max: 0.8 },
        PRETEEN: { min: 0.6, max: 0.9 }
      },
      hesitations: {
        PRESCHOOL: { min: 0, max: 15 },
        ELEMENTARY: { min: 0, max: 10 },
        PRETEEN: { min: 0, max: 7 }
      },

      // Response patterns
      initiationLatency: {
        PRESCHOOL: { min: 1.0, max: 5.0 },
        ELEMENTARY: { min: 0.8, max: 3.5 },
        PRETEEN: { min: 0.5, max: 2.5 }
      },
      recoveryTime: {
        PRESCHOOL: { min: 2.0, max: 8.0 },
        ELEMENTARY: { min: 1.5, max: 5.0 },
        PRETEEN: { min: 1.0, max: 3.5 }
      },
      impulsiveGuessing: {
        PRESCHOOL: { min: 0, max: 8 },
        ELEMENTARY: { min: 0, max: 5 },
        PRETEEN: { min: 0, max: 3 }
      },
      freezeMode: {
        PRESCHOOL: { min: 0, max: 6 },
        ELEMENTARY: { min: 0, max: 4 },
        PRETEEN: { min: 0, max: 2 }
      },
      healthyPersistence: {
        PRESCHOOL: { min: 3, max: 8 },
        ELEMENTARY: { min: 5, max: 12 },
        PRETEEN: { min: 7, max: 15 }
      },

      // Task completion
      taskCompletionRate: {
        PRESCHOOL: { min: 0.4, max: 0.8 },
        ELEMENTARY: { min: 0.5, max: 0.9 },
        PRETEEN: { min: 0.6, max: 0.95 }
      }
    };

    const norm = norms[metricName]?.[ageGroup];
    if (!norm) {
      // Fallback: assume 0-1 range
      return inverse ? 1 - value : value;
    }

    // Normalize to 0-1 based on age-appropriate norms
    let normalized = (value - norm.min) / (norm.max - norm.min);
    normalized = Math.max(0, Math.min(1, normalized));

    return inverse ? 1 - normalized : normalized;
  }

  /**
   * Age-based score adjustment
   * Younger children naturally have lower scores, adjust for developmental stage
   */
  getAgeAdjustment(age) {
    if (age >= 3 && age <= 4) return -5; // Preschool adjustment
    if (age >= 5 && age <= 6) return -2;
    if (age >= 7 && age <= 10) return 0; // Baseline
    if (age >= 11 && age <= 13) return +2;
    if (age >= 14 && age <= 15) return +5;
    return 0;
  }

  /**
   * Get risk level for a score
   */
  getRiskLevel(score) {
    for (const [key, level] of Object.entries(RISK_LEVELS)) {
      if (score >= level.range[0] && score <= level.range[1]) {
        return {
          level: key,
          ...level
        };
      }
    }
    return RISK_LEVELS.MODERATE;
  }

  /**
   * Get human-readable interpretation
   */
  getInterpretation(score, domainName) {
    if (score >= 80) {
      return `${domainName} skills are developing very well.`;
    } else if (score >= 70) {
      return `${domainName} skills are developing typically for age.`;
    } else if (score >= 55) {
      return `${domainName} skills are emerging, continue practice.`;
    } else if (score >= 40) {
      return `${domainName} skills show some delays, monitor closely.`;
    } else {
      return `${domainName} skills need focused support and intervention.`;
    }
  }

  /**
   * Identify top contributing factors to the score
   */
  getTopContributors(domain, sessionData, score) {
    const contributors = [];
    const metrics = domain.trackingMetrics;

    // Collect all metric values and their contributions
    const allMetrics = [];

    if (metrics.eyeTracking && sessionData.eyeTracking) {
      for (const [metric, config] of Object.entries(metrics.eyeTracking)) {
        const value = sessionData.eyeTracking[metric];
        if (value !== undefined) {
          allMetrics.push({
            name: this.formatMetricName(metric),
            value,
            weight: config.weight,
            category: 'Eye Tracking'
          });
        }
      }
    }

    if (metrics.microExpressions && sessionData.microExpressions) {
      for (const [metric, config] of Object.entries(metrics.microExpressions)) {
        const value = sessionData.microExpressions[metric];
        if (value !== undefined) {
          allMetrics.push({
            name: this.formatMetricName(metric),
            value,
            weight: config.weight,
            category: 'Emotional Expression'
          });
        }
      }
    }

    // Sort by weight and return top 3
    allMetrics.sort((a, b) => b.weight - a.weight);
    return allMetrics.slice(0, 3);
  }

  /**
   * Format metric name for display
   */
  formatMetricName(name) {
    return name
      .replace(/([A-Z])/g, ' $1')
      .replace(/^./, str => str.toUpperCase())
      .trim();
  }

  /**
   * Calculate trend (change over time)
   * @param {Array} historicalScores - Array of {date, score} objects
   * @returns {Object} Trend analysis
   */
  calculateTrend(historicalScores) {
    if (historicalScores.length < 2) {
      return { direction: 'stable', change: 0, confidence: 'low' };
    }

    // Simple linear regression
    const n = historicalScores.length;
    const xMean = (n - 1) / 2;
    const yMean = historicalScores.reduce((sum, s) => sum + s.score, 0) / n;

    let numerator = 0;
    let denominator = 0;

    historicalScores.forEach((point, i) => {
      numerator += (i - xMean) * (point.score - yMean);
      denominator += Math.pow(i - xMean, 2);
    });

    const slope = numerator / denominator;
    const change = slope * (n - 1); // Total change across period

    let direction = 'stable';
    if (change > 5) direction = 'improving';
    else if (change < -5) direction = 'declining';

    let confidence = 'low';
    if (n >= 7) confidence = 'high';
    else if (n >= 4) confidence = 'moderate';

    return { direction, change: Math.round(change), confidence, slope };
  }
}

export const scoringEngine = new ScoringEngine();
export default scoringEngine;
