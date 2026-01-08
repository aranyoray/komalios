/**
 * Session Summarizer
 * Maintains rolling aggregates and generates post-session summaries
 */

export interface MetricUpdate {
  attention?: number;
  emotion?: string;
  latency?: number;
  vocabulary?: string[];
}

export interface SessionSummary {
  timeline: Array<{ time: number; metric: string; value: any }>;
  strengths: string[];
  areasForSupport: string[];
  anomalies: string[];
  suggestedNextTasks: string[];
  selProgressMarkers: Record<string, number>;
}

export class SessionSummarizer {
  private updates: MetricUpdate[] = [];
  private attentionScores: number[] = [];
  private emotions: string[] = [];
  private latencies: number[] = [];
  private vocabulary: Set<string> = new Set();

  update(metric: MetricUpdate): void {
    this.updates.push(metric);
    if (metric.attention) this.attentionScores.push(metric.attention);
    if (metric.emotion) this.emotions.push(metric.emotion);
    if (metric.latency) this.latencies.push(metric.latency);
    if (metric.vocabulary) metric.vocabulary.forEach(w => this.vocabulary.add(w));
  }

  finalize(): SessionSummary {
    const avgAttention = this.avg(this.attentionScores);
    const avgLatency = this.avg(this.latencies);

    return {
      timeline: this.buildTimeline(),
      strengths: this.identifyStrengths(avgAttention, avgLatency),
      areasForSupport: this.identifyAreasForSupport(avgAttention, avgLatency),
      anomalies: [],
      suggestedNextTasks: this.suggestTasks(avgAttention),
      selProgressMarkers: {
        attention: Math.round(avgAttention),
        responseSpeed: Math.round((1 - avgLatency / 5000) * 100),
        vocabularySize: this.vocabulary.size
      }
    };
  }

  reset(): void {
    this.updates = [];
    this.attentionScores = [];
    this.emotions = [];
    this.latencies = [];
    this.vocabulary.clear();
  }

  private buildTimeline(): Array<{ time: number; metric: string; value: any }> {
    return this.updates.map((u, i) => ({
      time: i * 1000,
      metric: 'mixed',
      value: u
    }));
  }

  private identifyStrengths(attention: number, latency: number): string[] {
    const strengths: string[] = [];
    if (attention > 70) strengths.push('Strong sustained attention');
    if (latency < 2000) strengths.push('Quick response times');
    if (this.vocabulary.size > 10) strengths.push('Rich vocabulary usage');
    return strengths.slice(0, 3);
  }

  private identifyAreasForSupport(attention: number, latency: number): string[] {
    const areas: string[] = [];
    if (attention < 50) areas.push('Attention and focus');
    if (latency > 4000) areas.push('Response speed');
    if (this.vocabulary.size < 5) areas.push('Vocabulary development');
    return areas.slice(0, 3);
  }

  private suggestTasks(attention: number): string[] {
    if (attention < 50) return ['Short listening tasks', 'Visual matching'];
    if (attention > 70) return ['Complex sequencing', 'Problem-solving'];
    return ['Turn-taking games', 'Emotion naming'];
  }

  private avg(nums: number[]): number {
    return nums.length ? nums.reduce((a, b) => a + b, 0) / nums.length : 0;
  }
}
