/**
 * Generalization Matrix - Monthly Progress Tracking
 *
 * Tracks: consistency, transfer, spontaneity, retention
 * for each subdomain across sessions
 */

export interface SubdomainHistory {
  sessionId: string;
  timestamp: number;
  score: number;
  context: string; // task context
  prompted: boolean; // or spontaneous
}

export interface GeneralizationScores {
  consistency: number;    // 0-100 (low variance)
  transfer: number;       // 0-100 (performance across contexts)
  spontaneity: number;    // 0-100 (unprompted skill use)
  retention: number;      // 0-100 (current vs previous month)
  compositeScore: number; // weighted sum
}

export type SubdomainMatrix = Record<string, GeneralizationScores>;

export class GeneralizationMatrixBuilder {
  buildMatrix(historyBySubdomain: Record<string, SubdomainHistory[]>): SubdomainMatrix {
    const matrix: SubdomainMatrix = {};

    for (const [subdomain, history] of Object.entries(historyBySubdomain)) {
      matrix[subdomain] = this.computeGeneralization(history);
    }

    return matrix;
  }

  private computeGeneralization(history: SubdomainHistory[]): GeneralizationScores {
    if (history.length === 0) {
      return { consistency: 50, transfer: 50, spontaneity: 50, retention: 50, compositeScore: 50 };
    }

    const consistency = this.computeConsistency(history);
    const transfer = this.computeTransfer(history);
    const spontaneity = this.computeSpontaneity(history);
    const retention = this.computeRetention(history);

    const compositeScore = (
      consistency * 0.25 +
      transfer * 0.30 +
      spontaneity * 0.25 +
      retention * 0.20
    );

    return {
      consistency,
      transfer,
      spontaneity,
      retention,
      compositeScore: Math.round(compositeScore)
    };
  }

  private computeConsistency(history: SubdomainHistory[]): number {
    const scores = history.map(h => h.score);
    const mean = scores.reduce((a, b) => a + b, 0) / scores.length;
    const variance = scores.reduce((sum, s) => sum + Math.pow(s - mean, 2), 0) / scores.length;
    const normalized = 1 - Math.min(variance / 1000, 1); // Lower variance = higher consistency
    return Math.round(normalized * 100);
  }

  private computeTransfer(history: SubdomainHistory[]): number {
    const contextGroups = this.groupByContext(history);
    if (contextGroups.size <= 1) return 50; // Need multiple contexts

    const avgScores = Array.from(contextGroups.values()).map(group => {
      const scores = group.map(h => h.score);
      return scores.reduce((a, b) => a + b, 0) / scores.length;
    });

    const overallMean = avgScores.reduce((a, b) => a + b, 0) / avgScores.length;
    const variance = avgScores.reduce((sum, s) => sum + Math.pow(s - overallMean, 2), 0) / avgScores.length;
    const transferScore = 1 - Math.min(variance / 500, 1);
    return Math.round(transferScore * 100);
  }

  private computeSpontaneity(history: SubdomainHistory[]): number {
    const spontaneousCount = history.filter(h => !h.prompted).length;
    const ratio = spontaneousCount / history.length;
    return Math.round(ratio * 100);
  }

  private computeRetention(history: SubdomainHistory[]): number {
    if (history.length < 2) return 50;

    const sorted = history.sort((a, b) => a.timestamp - b.timestamp);
    const now = Date.now();
    const oneMonthAgo = now - 30 * 24 * 60 * 60 * 1000;

    const currentMonth = sorted.filter(h => h.timestamp >= oneMonthAgo);
    const previousMonth = sorted.filter(h => h.timestamp < oneMonthAgo);

    if (currentMonth.length === 0 || previousMonth.length === 0) return 50;

    const currentAvg = currentMonth.reduce((sum, h) => sum + h.score, 0) / currentMonth.length;
    const previousAvg = previousMonth.reduce((sum, h) => sum + h.score, 0) / previousMonth.length;

    const improvement = currentAvg - previousAvg;
    const retentionScore = 50 + improvement; // Neutral at 50, improve/decline from there

    return Math.max(0, Math.min(100, Math.round(retentionScore)));
  }

  private groupByContext(history: SubdomainHistory[]): Map<string, SubdomainHistory[]> {
    const groups = new Map<string, SubdomainHistory[]>();
    for (const h of history) {
      if (!groups.has(h.context)) groups.set(h.context, []);
      groups.get(h.context)!.push(h);
    }
    return groups;
  }
}
