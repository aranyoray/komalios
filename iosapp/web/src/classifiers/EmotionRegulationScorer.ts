/**
 * Emotion Regulation Index from Microexpressions
 * Heuristic-based (not medical diagnosis)
 */

export interface EmotionEvent {
  timestamp: number;
  valence: number; // -1 to 1
  label: string;
}

export interface RegulationResult {
  score: number; // 0-100
  tags: string[];
  valenceWaveform: number[];
}

export class EmotionRegulationScorer {
  compute(emotions: EmotionEvent[]): RegulationResult {
    if (emotions.length === 0) {
      return { score: 50, tags: [], valenceWaveform: [] };
    }

    const valences = emotions.map(e => e.valence);
    const negativeCount = emotions.filter(e => e.valence < -0.3).length;
    const negativeRatio = negativeCount / emotions.length;

    // Recovery speed: time from negative to neutral
    const recoveryTimes: number[] = [];
    for (let i = 1; i < emotions.length; i++) {
      if (emotions[i - 1].valence < 0 && emotions[i].valence >= 0) {
        recoveryTimes.push(emotions[i].timestamp - emotions[i - 1].timestamp);
      }
    }
    const avgRecovery = recoveryTimes.length ? recoveryTimes.reduce((a, b) => a + b) / recoveryTimes.length : 0;

    // Variability
    const mean = valences.reduce((a, b) => a + b, 0) / valences.length;
    const variance = valences.reduce((sum, v) => sum + Math.pow(v - mean, 2), 0) / valences.length;

    // Scoring (heuristic)
    const negativeScore = (1 - negativeRatio) * 40; // Max 40 points
    const recoveryScore = avgRecovery < 5000 ? 30 : avgRecovery < 10000 ? 20 : 10; // Max 30 points
    const stabilityScore = variance < 0.3 ? 30 : variance < 0.5 ? 20 : 10; // Max 30 points

    const score = Math.round(negativeScore + recoveryScore + stabilityScore);

    const tags: string[] = [];
    if (avgRecovery < 5000) tags.push('quick recovery');
    if (negativeRatio > 0.5) tags.push('frequent spikes');
    if (variance < 0.3) tags.push('stable baseline');

    return { score: Math.max(0, Math.min(100, score)), tags, valenceWaveform: valences };
  }
}
