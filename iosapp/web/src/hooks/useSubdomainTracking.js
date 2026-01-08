/**
 * Subdomain Tracking Hook
 *
 * Integrates subdomain assessment framework with session management.
 * Handles:
 * - Session planning (which subdomains to assess)
 * - Measurement collection from all tools
 * - Assessment history storage
 * - Weekly coverage tracking
 */

import { useState, useCallback, useRef, useEffect } from 'react';
import { db } from '../services/db';
import {
  createSessionPlan,
  getPrioritizedSubdomains,
  getWeeklyCoverageStatus,
  getNextSessionRecommendation,
  recordSubdomainAssessment,
} from '../assessment/subdomainScheduler';
import { aggregateSubdomainMeasurements } from '../assessment/subdomainMeasurementTools';

export const useSubdomainTracking = (learnerId) => {
  const [sessionPlan, setSessionPlan] = useState(null);
  const [assessmentHistory, setAssessmentHistory] = useState({});
  const [currentMeasurements, setCurrentMeasurements] = useState([]);
  const [weeklyCoverage, setWeeklyCoverage] = useState(null);
  const [isInitialized, setIsInitialized] = useState(false);

  const ageBandRef = useRef('6-10'); // Default age band

  /**
   * Initialize subdomain tracking for learner
   */
  const initialize = useCallback(async (ageBand = '6-10') => {
    try {
      ageBandRef.current = ageBand;

      // Load learner's assessment history from IndexedDB
      const learner = await db.get('learners', learnerId);
      const history = learner?.subdomainAssessmentHistory || {};

      setAssessmentHistory(history);

      // Calculate weekly coverage
      const coverage = getWeeklyCoverageStatus(ageBand, history);
      setWeeklyCoverage(coverage);

      // Create session plan
      const plan = createSessionPlan(ageBand, history);
      setSessionPlan(plan);

      setIsInitialized(true);

      console.log('[SubdomainTracking] Initialized for learner:', learnerId);
      console.log('[SubdomainTracking] Session plan:', plan);
      console.log('[SubdomainTracking] Weekly coverage:', coverage.coveragePercentage + '%');

      return plan;
    } catch (error) {
      console.error('[SubdomainTracking] Initialization failed:', error);
      throw error;
    }
  }, [learnerId]);

  /**
   * Add a measurement result
   */
  const addMeasurement = useCallback((measurementResult) => {
    setCurrentMeasurements(prev => [...prev, measurementResult]);

    console.log('[SubdomainTracking] Measurement added:', {
      tool: measurementResult.tool,
      subdomain: measurementResult.subdomain,
      score: measurementResult.score,
    });
  }, []);

  /**
   * Add multiple measurements at once
   */
  const addMeasurements = useCallback((measurements) => {
    setCurrentMeasurements(prev => [...prev, ...measurements]);

    console.log('[SubdomainTracking] Bulk measurements added:', measurements.length);
  }, []);

  /**
   * Complete assessment for a subdomain
   */
  const completeSubdomainAssessment = useCallback(async (domainKey, subdomainKey) => {
    try {
      // Get measurements for this subdomain
      const subdomainMeasurements = currentMeasurements.filter(
        m => m.subdomain === subdomainKey || m.rawData?.subdomain === subdomainKey
      );

      if (subdomainMeasurements.length === 0) {
        console.warn('[SubdomainTracking] No measurements found for:', subdomainKey);
        return null;
      }

      // Aggregate measurements
      const aggregated = aggregateSubdomainMeasurements(subdomainMeasurements);

      // Create assessment record
      const assessment = {
        domainKey,
        subdomainKey,
        score: aggregated.score,
        confidence: aggregated.confidence,
        measurements: subdomainMeasurements,
        timestamp: new Date(),
        sessionId: sessionPlan?.sessionId,
      };

      // Update assessment history
      const fullKey = `${domainKey}.${subdomainKey}`;
      const updatedHistory = {
        ...assessmentHistory,
        [fullKey]: assessment.timestamp,
      };

      setAssessmentHistory(updatedHistory);

      // Save to learner profile in IndexedDB
      const learner = await db.get('learners', learnerId);
      if (learner) {
        learner.subdomainAssessmentHistory = updatedHistory;

        // Also add to subdomain scores history array
        if (!learner.subdomainScoresHistory) {
          learner.subdomainScoresHistory = [];
        }
        learner.subdomainScoresHistory.push(assessment);

        await db.update('learners', learner);
      }

      console.log('[SubdomainTracking] Subdomain assessment completed:', {
        subdomain: subdomainKey,
        score: aggregated.score,
        confidence: aggregated.confidence,
      });

      return assessment;
    } catch (error) {
      console.error('[SubdomainTracking] Assessment completion failed:', error);
      throw error;
    }
  }, [currentMeasurements, assessmentHistory, sessionPlan, learnerId]);

  /**
   * Complete all subdomain assessments for current session
   */
  const completeSessionAssessments = useCallback(async () => {
    if (!sessionPlan || !sessionPlan.subdomains) {
      console.warn('[SubdomainTracking] No session plan available');
      return [];
    }

    const assessments = [];

    // Complete each subdomain in the plan
    for (const item of sessionPlan.subdomains) {
      try {
        const assessment = await completeSubdomainAssessment(
          item.domainKey,
          item.subdomainKey
        );
        if (assessment) {
          assessments.push(assessment);
        }
      } catch (error) {
        console.error('[SubdomainTracking] Failed to complete:', item.subdomainKey, error);
      }
    }

    // Update weekly coverage
    const coverage = getWeeklyCoverageStatus(
      ageBandRef.current,
      assessmentHistory
    );
    setWeeklyCoverage(coverage);

    // Clear current measurements
    setCurrentMeasurements([]);

    console.log('[SubdomainTracking] Session assessments completed:', assessments.length);
    console.log('[SubdomainTracking] New weekly coverage:', coverage.coveragePercentage + '%');

    return assessments;
  }, [sessionPlan, completeSubdomainAssessment, assessmentHistory]);

  /**
   * Get next session recommendation
   */
  const getNextSessionInfo = useCallback(() => {
    if (!isInitialized) return null;

    return getNextSessionRecommendation(
      ageBandRef.current,
      assessmentHistory
    );
  }, [isInitialized, assessmentHistory]);

  /**
   * Refresh session plan (e.g., after completing assessments)
   */
  const refreshSessionPlan = useCallback(() => {
    if (!isInitialized) return null;

    const newPlan = createSessionPlan(
      ageBandRef.current,
      assessmentHistory
    );

    setSessionPlan(newPlan);

    console.log('[SubdomainTracking] Session plan refreshed');

    return newPlan;
  }, [isInitialized, assessmentHistory]);

  /**
   * Get detailed progress report
   */
  const getProgressReport = useCallback(async () => {
    try {
      const learner = await db.get('learners', learnerId);
      const scoresHistory = learner?.subdomainScoresHistory || [];

      // Group by subdomain
      const bySubdomain = {};
      for (const assessment of scoresHistory) {
        const key = `${assessment.domainKey}.${assessment.subdomainKey}`;
        if (!bySubdomain[key]) {
          bySubdomain[key] = [];
        }
        bySubdomain[key].push(assessment);
      }

      // Calculate trends
      const trends = {};
      for (const [key, assessments] of Object.entries(bySubdomain)) {
        assessments.sort((a, b) => a.timestamp - b.timestamp);

        const scores = assessments.map(a => a.score);
        const recent = scores.slice(-5); // Last 5 assessments

        trends[key] = {
          latestScore: scores[scores.length - 1],
          averageScore: scores.reduce((sum, s) => sum + s, 0) / scores.length,
          recentAverage: recent.reduce((sum, s) => sum + s, 0) / recent.length,
          trend: recent.length >= 2
            ? recent[recent.length - 1] - recent[0]
            : 0,
          assessmentCount: assessments.length,
        };
      }

      return {
        weeklyCoverage,
        trends,
        totalAssessments: scoresHistory.length,
        lastAssessmentDate: scoresHistory.length > 0
          ? scoresHistory[scoresHistory.length - 1].timestamp
          : null,
      };
    } catch (error) {
      console.error('[SubdomainTracking] Progress report failed:', error);
      throw error;
    }
  }, [learnerId, weeklyCoverage]);

  /**
   * Get measurements for a specific subdomain
   */
  const getSubdomainMeasurements = useCallback((subdomainKey) => {
    return currentMeasurements.filter(
      m => m.subdomain === subdomainKey || m.rawData?.subdomain === subdomainKey
    );
  }, [currentMeasurements]);

  /**
   * Clear all current measurements (e.g., when starting new session)
   */
  const clearMeasurements = useCallback(() => {
    setCurrentMeasurements([]);
    console.log('[SubdomainTracking] Measurements cleared');
  }, []);

  return {
    // State
    isInitialized,
    sessionPlan,
    assessmentHistory,
    currentMeasurements,
    weeklyCoverage,

    // Actions
    initialize,
    addMeasurement,
    addMeasurements,
    completeSubdomainAssessment,
    completeSessionAssessments,
    refreshSessionPlan,
    clearMeasurements,

    // Queries
    getNextSessionInfo,
    getProgressReport,
    getSubdomainMeasurements,
  };
};

/**
 * Helper: Create measurement result object
 * Use this to standardize measurement creation
 */
export function createMeasurement(tool, subdomain, score, rawData = {}) {
  return {
    tool,
    subdomain,
    score: Math.min(100, Math.max(0, Math.round(score))), // Clamp to 0-100
    rawData,
    timestamp: Date.now(),
    confidence: rawData.confidence || 0.8, // Default confidence
  };
}

/**
 * Helper: Create emoji check-in measurement
 */
export function createEmojiMeasurement(checkInType, emoji, label, value, timing) {
  const subdomainMapping = {
    feeling: 'emotion_identification',
    difficulty: 'working_memory',
    motivation: 'task_persistence',
    understanding: 'comprehension',
  };

  return {
    tool: `emoji_checkin_${checkInType}`,
    subdomain: subdomainMapping[checkInType] || 'emotion_identification',
    score: (value / 5) * 100, // Convert 1-5 to 0-100
    rawData: {
      checkInType,
      emoji,
      label,
      value,
      timing,
    },
    timestamp: Date.now(),
    confidence: 1.0, // Self-report is fully confident
  };
}
