/**
 * Historical Data Service
 * Tracks subdomain scores over time for trend analysis
 */

import { db } from './db';

class HistoricalDataService {
  /**
   * Save subdomain scores from a session
   */
  async saveSubdomainScores(learnerId, sessionId, domainScores) {
    try {
      const timestamp = Date.now();

      // Extract all subdomain scores
      const subdomainEntries = [];

      for (const domain of Object.values(domainScores)) {
        if (domain.subdomains) {
          for (const subdomain of Object.values(domain.subdomains)) {
            subdomainEntries.push({
              id: `${learnerId}_${subdomain.id}_${timestamp}`,
              learnerId,
              sessionId,
              domainId: domain.id,
              subdomainId: subdomain.id,
              score: subdomain.score,
              timestamp,
              metrics: subdomain.metrics
            });
          }
        }
      }

      // Save all entries
      for (const entry of subdomainEntries) {
        await db.add('subdomainHistory', entry);
      }

      console.log(`[HistoricalData] Saved ${subdomainEntries.length} subdomain scores`);
      return subdomainEntries.length;
    } catch (error) {
      console.error('[HistoricalData] Error saving subdomain scores:', error);
      return 0;
    }
  }

  /**
   * Get historical scores for a subdomain
   */
  async getSubdomainHistory(learnerId, subdomainId, limit = 30) {
    try {
      // Get all history for this learner
      const allHistory = await db.getAllByIndex('subdomainHistory', 'learnerId', learnerId);

      // Filter by subdomain
      const subdomainHistory = allHistory
        .filter(entry => entry.subdomainId === subdomainId)
        .sort((a, b) => a.timestamp - b.timestamp) // Oldest first
        .slice(-limit); // Last N entries

      return subdomainHistory.map(entry => ({
        score: entry.score,
        timestamp: entry.timestamp,
        sessionId: entry.sessionId,
        metrics: entry.metrics
      }));
    } catch (error) {
      console.error('[HistoricalData] Error fetching subdomain history:', error);
      return [];
    }
  }

  /**
   * Get historical data for all subdomains
   * Returns: { subdomainId: [scores], ... }
   */
  async getAllSubdomainHistory(learnerId, limit = 30) {
    try {
      const allHistory = await db.getAllByIndex('subdomainHistory', 'learnerId', learnerId);

      // Group by subdomain
      const grouped = {};

      for (const entry of allHistory) {
        if (!grouped[entry.subdomainId]) {
          grouped[entry.subdomainId] = [];
        }
        grouped[entry.subdomainId].push({
          score: entry.score,
          timestamp: entry.timestamp,
          sessionId: entry.sessionId
        });
      }

      // Sort and limit each subdomain
      for (const subdomainId in grouped) {
        grouped[subdomainId] = grouped[subdomainId]
          .sort((a, b) => a.timestamp - b.timestamp)
          .slice(-limit)
          .map(entry => entry.score);
      }

      return grouped;
    } catch (error) {
      console.error('[HistoricalData] Error fetching all subdomain history:', error);
      return {};
    }
  }

  /**
   * Get weekly aggregated scores
   */
  async getWeeklyScores(learnerId, weeks = 4) {
    try {
      const now = Date.now();
      const weekMs = 7 * 24 * 60 * 60 * 1000;
      const startTime = now - (weeks * weekMs);

      const allHistory = await db.getAllByIndex('subdomainHistory', 'learnerId', learnerId);

      // Filter by time range
      const recentHistory = allHistory.filter(entry => entry.timestamp >= startTime);

      // Group by week and subdomain
      const weeklyData = {};

      for (const entry of recentHistory) {
        const weekNumber = Math.floor((entry.timestamp - startTime) / weekMs);
        const weekKey = `week_${weekNumber}`;

        if (!weeklyData[weekKey]) {
          weeklyData[weekKey] = {};
        }

        if (!weeklyData[weekKey][entry.subdomainId]) {
          weeklyData[weekKey][entry.subdomainId] = [];
        }

        weeklyData[weekKey][entry.subdomainId].push(entry.score);
      }

      // Calculate averages
      for (const weekKey in weeklyData) {
        for (const subdomainId in weeklyData[weekKey]) {
          const scores = weeklyData[weekKey][subdomainId];
          const average = scores.reduce((a, b) => a + b, 0) / scores.length;
          weeklyData[weekKey][subdomainId] = Math.round(average);
        }
      }

      return weeklyData;
    } catch (error) {
      console.error('[HistoricalData] Error fetching weekly scores:', error);
      return {};
    }
  }

  /**
   * Delete old history (keep last N days)
   */
  async cleanOldHistory(learnerId, daysToKeep = 90) {
    try {
      const cutoffTime = Date.now() - (daysToKeep * 24 * 60 * 60 * 1000);
      const allHistory = await db.getAllByIndex('subdomainHistory', 'learnerId', learnerId);

      let deleted = 0;
      for (const entry of allHistory) {
        if (entry.timestamp < cutoffTime) {
          await db.delete('subdomainHistory', entry.id);
          deleted++;
        }
      }

      console.log(`[HistoricalData] Cleaned ${deleted} old entries`);
      return deleted;
    } catch (error) {
      console.error('[HistoricalData] Error cleaning old history:', error);
      return 0;
    }
  }
}

export const historicalDataService = new HistoricalDataService();
export default historicalDataService;
