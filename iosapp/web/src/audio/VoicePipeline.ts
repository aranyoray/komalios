/**
 * Real-Time Voice Analysis Pipeline
 * Low-latency on-device prosody extraction
 * Target: <20ms per chunk, no recordings saved
 */

export interface VoiceFeatures {
  pitchMean: number;
  pitchVariability: number;
  speechRateWpm: number;
  pauseLengthMs: number;
  disfluencyRate: number;
}

export class VoicePipeline {
  private buffer: Float32Array = new Float32Array(0);
  private latest: VoiceFeatures | null = null;

  analyzeChunk(chunk: Float32Array, timestamp: number): void {
    const startTime = performance.now();

    // Extract features
    const pitchMean = this.estimatePitch(chunk);
    const pitchVariability = this.calculateVariability(chunk);
    const speechRateWpm = this.estimateSpeechRate(chunk);
    const pauseLengthMs = this.detectPauses(chunk);
    const disfluencyRate = this.detectDisfluencies(chunk);

    this.latest = { pitchMean, pitchVariability, speechRateWpm, pauseLengthMs, disfluencyRate };

    // Clear buffer (privacy)
    chunk.fill(0);

    const elapsed = performance.now() - startTime;
    if (elapsed > 20) console.warn(`[VoicePipeline] Chunk processing took ${elapsed}ms`);
  }

  getLatestSummary(): VoiceFeatures | null {
    return this.latest;
  }

  private estimatePitch(chunk: Float32Array): number {
    let zeroCrossings = 0;
    for (let i = 1; i < chunk.length; i++) {
      if ((chunk[i - 1] >= 0 && chunk[i] < 0) || (chunk[i - 1] < 0 && chunk[i] >= 0)) {
        zeroCrossings++;
      }
    }
    return (zeroCrossings / 2) * 44100 / chunk.length; // Rough pitch in Hz
  }

  private calculateVariability(chunk: Float32Array): number {
    const values = Array.from(chunk);
    const mean = values.reduce((a, b) => a + b, 0) / values.length;
    const variance = values.reduce((sum, v) => sum + Math.pow(v - mean, 2), 0) / values.length;
    return Math.sqrt(variance);
  }

  private estimateSpeechRate(chunk: Float32Array): number {
    // Simplified: energy peaks per second * scaling factor
    let peaks = 0;
    const threshold = 0.1;
    for (let i = 1; i < chunk.length - 1; i++) {
      if (chunk[i] > threshold && chunk[i] > chunk[i - 1] && chunk[i] > chunk[i + 1]) peaks++;
    }
    return peaks * 20; // Rough WPM estimate
  }

  private detectPauses(chunk: Float32Array): number {
    const silenceThreshold = 0.01;
    let silentSamples = 0;
    for (const sample of chunk) {
      if (Math.abs(sample) < silenceThreshold) silentSamples++;
    }
    return (silentSamples / chunk.length) * 1000; // ms
  }

  private detectDisfluencies(chunk: Float32Array): number {
    // Simplified: detect repeated patterns
    return 0.05; // Placeholder
  }
}
