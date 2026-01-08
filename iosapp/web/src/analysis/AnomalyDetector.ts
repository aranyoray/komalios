/**
 * Behavioral Anomaly Detector
 *
 * Detects unusual patterns during sessions:
 * - Spikes in gaze aversion
 * - Sudden silence
 * - Excessive tapping/flapping
 * - Sharp emotion changes
 * - Long response pauses
 *
 * Uses simple statistical thresholds (z-scores, moving averages)
 * NO raw recordings, only numeric summaries
 */

import { IntegratedEvent } from '../sync/MultimodalSyncEngine';

/**
 * Anomaly severity
 */
export type AnomalySeverity = 'low' | 'medium' | 'high';

/**
 * Detected anomaly
 */
export interface Anomaly {
  type: string;
  severity: AnomalySeverity;
  start: number;
  end: number;
  briefExplanation: string;
  metrics?: Record<string, number>;
}

/**
 * Detection thresholds
 */
interface AnomalyThresholds {
  gazeAversionZScore: number;      // Z-score threshold for gaze aversion
  silenceDurationMs: number;        // ms of silence to flag
  excessiveTapRate: number;         // taps per second
  emotionChangeRate: number;        // changes per minute
  longPauseMs: number;              // response pause threshold
  zScoreThreshold: number;          // General z-score cutoff
}

const DEFAULT_THRESHOLDS: AnomalyThresholds = {
  gazeAversionZScore: 2.0,    // 2 std devs above mean
  silenceDurationMs: 10000,   // 10 seconds
  excessiveTapRate: 5.0,      // 5 taps/sec
  emotionChangeRate: 8.0,     // 8 changes/min
  longPauseMs: 8000,          // 8 seconds
  zScoreThreshold: 2.0        // 2 std devs
};

/**
 * Anomaly Detector
 */
export class AnomalyDetector {
  private thresholds: AnomalyThresholds;

  constructor(thresholds: AnomalyThresholds = DEFAULT_THRESHOLDS) {
    this.thresholds = thresholds;
  }

  /**
   * Detect all anomalies in timeline
   */
  detectAnomalies(timeline: IntegratedEvent[]): Anomaly[] {
    if (timeline.length === 0) return [];

    const anomalies: Anomaly[] = [];

    // 1. Gaze aversion spikes
    anomalies.push(...this.detectGazeAversionSpikes(timeline));

    // 2. Sudden silence
    anomalies.push(...this.detectSuddenSilence(timeline));

    // 3. Excessive tapping
    anomalies.push(...this.detectExcessiveTapping(timeline));

    // 4. Sharp emotion changes
    anomalies.push(...this.detectSharpEmotionChanges(timeline));

    // 5. Long pauses before answering
    anomalies.push(...this.detectLongPauses(timeline));

    // Sort by timestamp
    return anomalies.sort((a, b) => a.start - b.start);
  }

  /**
   * Detect gaze aversion spikes
   */
  private detectGazeAversionSpikes(timeline: IntegratedEvent[]): Anomaly[] {
    const anomalies: Anomaly[] = [];
    const gazeEvents = timeline.filter(e => e.type === 'gaze');

    if (gazeEvents.length < 10) return anomalies;

    // Calculate baseline aversion rate
    const aversionCounts: number[] = [];
    const windowSize = 10; // 10-event sliding window

    for (let i = 0; i < gazeEvents.length - windowSize; i++) {
      const window = gazeEvents.slice(i, i + windowSize);
      const aversionCount = window.filter(e =>
        e.data.region === 'off-screen' || e.data.attentionLevel === 'low'
      ).length;
      aversionCounts.push(aversionCount);
    }

    const { mean, stdDev } = this.calculateStats(aversionCounts);

    // Detect spikes (z-score > threshold)
    for (let i = 0; i < aversionCounts.length; i++) {
      const zScore = (aversionCounts[i] - mean) / stdDev;

      if (zScore > this.thresholds.gazeAversionZScore) {
        const startIdx = i;
        const endIdx = Math.min(i + windowSize, gazeEvents.length - 1);

        anomalies.push({
          type: 'gaze-aversion-spike',
          severity: zScore > 3 ? 'high' : zScore > 2.5 ? 'medium' : 'low',
          start: gazeEvents[startIdx].timestamp,
          end: gazeEvents[endIdx].timestamp,
          briefExplanation: `Unusual increase in gaze aversion (z-score: ${zScore.toFixed(1)})`,
          metrics: {
            zScore,
            aversionCount: aversionCounts[i],
            baseline: mean
          }
        });
      }
    }

    return this.mergeOverlapping(anomalies);
  }

  /**
   * Detect sudden silence
   */
  private detectSuddenSilence(timeline: IntegratedEvent[]): Anomaly[] {
    const anomalies: Anomaly[] = [];
    const audioEvents = timeline.filter(e => e.type === 'audio');

    for (let i = 1; i < audioEvents.length; i++) {
      const gap = audioEvents[i].timestamp - audioEvents[i - 1].timestamp;

      if (gap > this.thresholds.silenceDurationMs) {
        anomalies.push({
          type: 'sudden-silence',
          severity: gap > 20000 ? 'high' : gap > 15000 ? 'medium' : 'low',
          start: audioEvents[i - 1].timestamp,
          end: audioEvents[i].timestamp,
          briefExplanation: `Unusual silence for ${(gap / 1000).toFixed(1)}s`,
          metrics: {
            durationMs: gap,
            threshold: this.thresholds.silenceDurationMs
          }
        });
      }
    }

    return anomalies;
  }

  /**
   * Detect excessive tapping
   */
  private detectExcessiveTapping(timeline: IntegratedEvent[]): Anomaly[] {
    const anomalies: Anomaly[] = [];
    const tapEvents = timeline.filter(e => e.type === 'tap');

    if (tapEvents.length < 5) return anomalies;

    // Calculate tap rate in 1-second windows
    const windowMs = 1000;

    for (let i = 0; i < tapEvents.length; i++) {
      const windowStart = tapEvents[i].timestamp;
      const windowEnd = windowStart + windowMs;

      const tapsInWindow = tapEvents.filter(e =>
        e.timestamp >= windowStart && e.timestamp < windowEnd
      );

      const tapRate = tapsInWindow.length;

      if (tapRate > this.thresholds.excessiveTapRate) {
        anomalies.push({
          type: 'excessive-tapping',
          severity: tapRate > 10 ? 'high' : tapRate > 7 ? 'medium' : 'low',
          start: windowStart,
          end: windowEnd,
          briefExplanation: `Rapid tapping: ${tapRate} taps/second`,
          metrics: {
            tapRate,
            threshold: this.thresholds.excessiveTapRate
          }
        });
      }
    }

    return this.mergeOverlapping(anomalies);
  }

  /**
   * Detect sharp emotion changes
   */
  private detectSharpEmotionChanges(timeline: IntegratedEvent[]): Anomaly[] {
    const anomalies: Anomaly[] = [];
    const emotionEvents = timeline.filter(e => e.type === 'emotion');

    if (emotionEvents.length < 5) return anomalies;

    // Calculate emotion change rate in 1-minute windows
    const windowMs = 60000;

    for (let i = 0; i < emotionEvents.length; i++) {
      const windowStart = emotionEvents[i].timestamp;
      const windowEnd = windowStart + windowMs;

      const emotionsInWindow = emotionEvents.filter(e =>
        e.timestamp >= windowStart && e.timestamp < windowEnd
      );

      // Count emotion changes
      let changes = 0;
      for (let j = 1; j < emotionsInWindow.length; j++) {
        if (emotionsInWindow[j].data.label !== emotionsInWindow[j - 1].data.label) {
          changes++;
        }
      }

      const changeRate = changes / (emotionsInWindow.length - 1 || 1);

      if (changes > this.thresholds.emotionChangeRate) {
        anomalies.push({
          type: 'sharp-emotion-changes',
          severity: changes > 12 ? 'high' : changes > 10 ? 'medium' : 'low',
          start: windowStart,
          end: windowEnd,
          briefExplanation: `Rapid emotional fluctuation: ${changes} changes/minute`,
          metrics: {
            changes,
            changeRate,
            threshold: this.thresholds.emotionChangeRate
          }
        });
      }
    }

    return this.mergeOverlapping(anomalies);
  }

  /**
   * Detect long pauses before answering
   */
  private detectLongPauses(timeline: IntegratedEvent[]): Anomaly[] {
    const anomalies: Anomaly[] = [];
    const taskEvents = timeline.filter(e => e.type === 'task');
    const responseEvents = timeline.filter(e => e.type === 'response');

    for (const task of taskEvents) {
      // Find corresponding response
      const response = responseEvents.find(r =>
        r.timestamp > task.timestamp &&
        r.timestamp < task.timestamp + 30000 // Within 30 seconds
      );

      if (response) {
        const pause = response.timestamp - task.timestamp;

        if (pause > this.thresholds.longPauseMs) {
          anomalies.push({
            type: 'long-response-pause',
            severity: pause > 15000 ? 'high' : pause > 12000 ? 'medium' : 'low',
            start: task.timestamp,
            end: response.timestamp,
            briefExplanation: `Long pause before answering: ${(pause / 1000).toFixed(1)}s`,
            metrics: {
              pauseMs: pause,
              threshold: this.thresholds.longPauseMs
            }
          });
        }
      }
    }

    return anomalies;
  }

  /**
   * Calculate mean and standard deviation
   */
  private calculateStats(values: number[]): { mean: number; stdDev: number } {
    if (values.length === 0) return { mean: 0, stdDev: 0 };

    const mean = values.reduce((a, b) => a + b, 0) / values.length;
    const variance = values.reduce((sum, v) => sum + Math.pow(v - mean, 2), 0) / values.length;
    const stdDev = Math.sqrt(variance);

    return { mean, stdDev };
  }

  /**
   * Merge overlapping anomalies
   */
  private mergeOverlapping(anomalies: Anomaly[]): Anomaly[] {
    if (anomalies.length <= 1) return anomalies;

    const sorted = anomalies.sort((a, b) => a.start - b.start);
    const merged: Anomaly[] = [sorted[0]];

    for (let i = 1; i < sorted.length; i++) {
      const current = sorted[i];
      const last = merged[merged.length - 1];

      if (current.start <= last.end && current.type === last.type) {
        // Merge
        last.end = Math.max(last.end, current.end);
        last.severity = this.maxSeverity(last.severity, current.severity);
      } else {
        merged.push(current);
      }
    }

    return merged;
  }

  /**
   * Get maximum severity
   */
  private maxSeverity(a: AnomalySeverity, b: AnomalySeverity): AnomalySeverity {
    const severityRank = { low: 1, medium: 2, high: 3 };
    return severityRank[a] >= severityRank[b] ? a : b;
  }
}

/**
 * USAGE EXAMPLE:
 *
 * const detector = new AnomalyDetector();
 * const anomalies = detector.detectAnomalies(timeline);
 *
 * for (const anomaly of anomalies) {
 *   console.log(`[${anomaly.severity.toUpperCase()}] ${anomaly.type}`);
 *   console.log(`  ${anomaly.briefExplanation}`);
 *   console.log(`  Duration: ${(anomaly.end - anomaly.start) / 1000}s`);
 *
 *   if (anomaly.metrics) {
 *     console.log(`  Metrics:`, anomaly.metrics);
 *   }
 * }
 *
 * // Include in therapist/parent report
 * const report = {
 *   sessionId: 'xxx',
 *   anomalies: anomalies.map(a => ({
 *     type: a.type,
 *     severity: a.severity,
 *     explanation: a.briefExplanation,
 *     timestamp: new Date(a.start).toISOString()
 *   }))
 * };
 */
