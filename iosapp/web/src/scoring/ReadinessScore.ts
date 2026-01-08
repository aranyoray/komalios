/**
 * Cross-Domain Readiness To Learn Score
 * Combines multiple metrics into single readiness indicator
 */

export interface ReadinessInputs {
  attentionStability: number; // 0-100
  emotionalBaseline: number;  // 0-100
  linguisticReadiness: number; // 0-100
  motorReadiness: number;     // 0-100
  latencyPatterns: number;    // 0-100 (lower latency = higher score)
  engagement: number;         // 0-100
}

export interface ReadinessResult {
  score: number; // 0-100
  explanation: string[];
  tag: 'ready' | 'needs short break' | 'needs warmup';
}

export class ReadinessScoreCalculator {
  calculate(inputs: ReadinessInputs): ReadinessResult {
    // Transparent weighting system
    const score = (
      inputs.attentionStability * 0.25 +
      inputs.emotionalBaseline * 0.20 +
      inputs.linguisticReadiness * 0.15 +
      inputs.motorReadiness * 0.10 +
      inputs.latencyPatterns * 0.15 +
      inputs.engagement * 0.15
    );

    const rounded = Math.round(score);
    const explanation: string[] = [];

    if (inputs.attentionStability > 70) explanation.push('Good focus');
    if (inputs.emotionalBaseline > 60) explanation.push('Emotionally stable');
    if (inputs.engagement < 50) explanation.push('May need engagement boost');

    let tag: 'ready' | 'needs short break' | 'needs warmup';
    if (rounded >= 70) tag = 'ready';
    else if (rounded >= 40) tag = 'needs warmup';
    else tag = 'needs short break';

    return { score: rounded, explanation, tag };
  }
}
