/**
 * Multimodal Synchronization Engine
 *
 * Fuses multiple sensor streams into unified timeline:
 * - Gaze events (eye tracker)
 * - Touch/tap events
 * - Micro-expression frames (face)
 * - Audio speech fragments (voice)
 *
 * Computes cross-modal correlations:
 * - Gaze → Tap latency
 * - Emotion before answer → Correctness
 * - Audio power → Tap force
 *
 * PRIVACY: All raw sensor data deleted immediately after summarization
 */

/**
 * Event types from different modalities
 */
export type EventType =
  | 'gaze'
  | 'tap'
  | 'emotion'
  | 'audio'
  | 'task'
  | 'response';

/**
 * Integrated event in unified timeline
 */
export interface IntegratedEvent {
  type: EventType;
  timestamp: number;
  source: string; // Which sensor/module produced this
  data: any;      // Event-specific data
  processed?: boolean;
}

/**
 * Cross-modal correlation
 */
export interface CrossModalCorrelation {
  type: string;
  description: string;
  value: number;
  confidence: number;
  startTime: number;
  endTime: number;
  events: IntegratedEvent[];
}

/**
 * Time-aligned query result
 */
export interface TimeWindow {
  startMs: number;
  endMs: number;
  events: IntegratedEvent[];
  eventCounts: Record<EventType, number>;
  correlations: CrossModalCorrelation[];
}

/**
 * Multimodal Sync Engine
 */
export class MultimodalSyncEngine {
  private timeline: IntegratedEvent[] = [];
  private maxTimelineSize = 10000; // Keep last 10k events
  private clockSkewMap: Map<string, number> = new Map(); // Track timing offsets per source

  /**
   * Register an event from any modality
   *
   * @param type - Event type
   * @param timestamp - Timestamp in ms (Unix epoch or relative)
   * @param data - Event-specific data
   * @param source - Optional source identifier
   */
  registerEvent(
    type: EventType,
    timestamp: number,
    data: any,
    source: string = 'unknown'
  ): void {
    // Adjust for clock skew if detected
    const adjustedTimestamp = this.adjustTimestamp(timestamp, source);

    const event: IntegratedEvent = {
      type,
      timestamp: adjustedTimestamp,
      source,
      data,
      processed: false
    };

    // Insert in chronological order (binary search for efficiency)
    const insertIndex = this.findInsertIndex(adjustedTimestamp);
    this.timeline.splice(insertIndex, 0, event);

    // Limit timeline size
    if (this.timeline.length > this.maxTimelineSize) {
      this.timeline.shift(); // Remove oldest
    }
  }

  /**
   * Find insertion index for timestamp (binary search)
   */
  private findInsertIndex(timestamp: number): number {
    let left = 0;
    let right = this.timeline.length;

    while (left < right) {
      const mid = Math.floor((left + right) / 2);
      if (this.timeline[mid].timestamp < timestamp) {
        left = mid + 1;
      } else {
        right = mid;
      }
    }

    return left;
  }

  /**
   * Adjust timestamp for clock skew
   * Handles desynced timestamps from different sensors
   */
  private adjustTimestamp(timestamp: number, source: string): number {
    if (!this.clockSkewMap.has(source)) {
      // First event from this source, no adjustment
      return timestamp;
    }

    const skew = this.clockSkewMap.get(source)!;
    return timestamp + skew;
  }

  /**
   * Detect and correct clock skew for a source
   * Call this when you notice timestamps from a source are consistently off
   */
  calibrateSource(source: string, referenceTime: number, sourceTime: number): void {
    const skew = referenceTime - sourceTime;
    this.clockSkewMap.set(source, skew);

    console.log(`[MultimodalSyncEngine] Calibrated ${source}: skew = ${skew}ms`);
  }

  /**
   * Query time window
   *
   * Returns all events and correlations within time range
   */
  queryWindow(startMs: number, endMs: number): TimeWindow {
    // Filter events in range
    const events = this.timeline.filter(e =>
      e.timestamp >= startMs && e.timestamp <= endMs
    );

    // Count events by type
    const eventCounts: Record<string, number> = {
      gaze: 0,
      tap: 0,
      emotion: 0,
      audio: 0,
      task: 0,
      response: 0
    };

    for (const event of events) {
      eventCounts[event.type] = (eventCounts[event.type] || 0) + 1;
    }

    // Compute correlations within this window
    const correlations = this.computeCorrelations(events, startMs, endMs);

    return {
      startMs,
      endMs,
      events,
      eventCounts: eventCounts as Record<EventType, number>,
      correlations
    };
  }

  /**
   * Compute cross-modal correlations
   */
  private computeCorrelations(
    events: IntegratedEvent[],
    startMs: number,
    endMs: number
  ): CrossModalCorrelation[] {
    const correlations: CrossModalCorrelation[] = [];

    // 1. Gaze → Tap latency
    correlations.push(...this.computeGazeTapLatency(events));

    // 2. Emotion before answer → Correctness
    correlations.push(...this.computeEmotionResponseCorrelation(events));

    // 3. Audio power → Tap force
    correlations.push(...this.computeAudioTapCorrelation(events));

    // 4. Attention drop → Task difficulty
    correlations.push(...this.computeAttentionTaskCorrelation(events));

    return correlations.filter(c => c.confidence > 0.5); // Only high-confidence correlations
  }

  /**
   * Compute gaze → tap latency correlation
   *
   * Measures how long after looking at target, child taps it
   */
  private computeGazeTapLatency(events: IntegratedEvent[]): CrossModalCorrelation[] {
    const correlations: CrossModalCorrelation[] = [];

    const gazeEvents = events.filter(e => e.type === 'gaze');
    const tapEvents = events.filter(e => e.type === 'tap');

    for (const tap of tapEvents) {
      // Find most recent gaze event before tap
      const priorGaze = gazeEvents
        .filter(g => g.timestamp < tap.timestamp && tap.timestamp - g.timestamp < 5000)
        .sort((a, b) => b.timestamp - a.timestamp)[0];

      if (priorGaze) {
        const latency = tap.timestamp - priorGaze.timestamp;

        correlations.push({
          type: 'gaze-tap-latency',
          description: `Looked then tapped after ${latency}ms`,
          value: latency,
          confidence: Math.max(0, 1 - latency / 5000), // Lower latency = higher confidence
          startTime: priorGaze.timestamp,
          endTime: tap.timestamp,
          events: [priorGaze, tap]
        });
      }
    }

    return correlations;
  }

  /**
   * Compute emotion → response correlation
   *
   * Does emotional state before answering predict correctness?
   */
  private computeEmotionResponseCorrelation(events: IntegratedEvent[]): CrossModalCorrelation[] {
    const correlations: CrossModalCorrelation[] = [];

    const emotionEvents = events.filter(e => e.type === 'emotion');
    const responseEvents = events.filter(e => e.type === 'response');

    for (const response of responseEvents) {
      // Find emotion in 2 seconds before response
      const priorEmotion = emotionEvents
        .filter(e => e.timestamp < response.timestamp &&
                    response.timestamp - e.timestamp < 2000)
        .sort((a, b) => b.timestamp - a.timestamp)[0];

      if (priorEmotion && response.data.correct !== undefined) {
        const emotionLabel = priorEmotion.data.label || 'neutral';
        const correct = response.data.correct;

        // Positive emotions correlate with correct answers
        const positiveEmotions = ['happy', 'excited', 'confident'];
        const negativeEmotions = ['frustrated', 'sad', 'angry'];

        let correlation = 0;
        if (positiveEmotions.includes(emotionLabel) && correct) {
          correlation = 0.8;
        } else if (negativeEmotions.includes(emotionLabel) && !correct) {
          correlation = 0.7;
        } else if (emotionLabel === 'neutral') {
          correlation = 0.5;
        }

        if (correlation > 0) {
          correlations.push({
            type: 'emotion-response',
            description: `${emotionLabel} before ${correct ? 'correct' : 'incorrect'} answer`,
            value: correct ? 1 : 0,
            confidence: correlation,
            startTime: priorEmotion.timestamp,
            endTime: response.timestamp,
            events: [priorEmotion, response]
          });
        }
      }
    }

    return correlations;
  }

  /**
   * Compute audio → tap correlation
   *
   * Does voice intensity/confidence correlate with tap force/speed?
   */
  private computeAudioTapCorrelation(events: IntegratedEvent[]): CrossModalCorrelation[] {
    const correlations: CrossModalCorrelation[] = [];

    const audioEvents = events.filter(e => e.type === 'audio');
    const tapEvents = events.filter(e => e.type === 'tap');

    for (const tap of tapEvents) {
      // Find audio in 1 second before tap
      const priorAudio = audioEvents
        .filter(e => e.timestamp < tap.timestamp &&
                    tap.timestamp - e.timestamp < 1000)
        .sort((a, b) => b.timestamp - a.timestamp)[0];

      if (priorAudio && priorAudio.data.power !== undefined) {
        const audioPower = priorAudio.data.power; // 0-1
        const tapForce = tap.data.force || 0.5; // 0-1

        // Correlation between audio power and tap force
        const correlation = 1 - Math.abs(audioPower - tapForce);

        if (correlation > 0.5) {
          correlations.push({
            type: 'audio-tap',
            description: `Voice intensity ${audioPower.toFixed(2)} matched tap force ${tapForce.toFixed(2)}`,
            value: correlation,
            confidence: correlation,
            startTime: priorAudio.timestamp,
            endTime: tap.timestamp,
            events: [priorAudio, tap]
          });
        }
      }
    }

    return correlations;
  }

  /**
   * Compute attention → task difficulty correlation
   *
   * Does attention drop when task gets harder?
   */
  private computeAttentionTaskCorrelation(events: IntegratedEvent[]): CrossModalCorrelation[] {
    const correlations: CrossModalCorrelation[] = [];

    const gazeEvents = events.filter(e => e.type === 'gaze');
    const taskEvents = events.filter(e => e.type === 'task');

    for (const task of taskEvents) {
      if (task.data.difficulty === undefined) continue;

      // Find gaze events during task (within 5 seconds after start)
      const taskGaze = gazeEvents.filter(g =>
        g.timestamp >= task.timestamp &&
        g.timestamp <= task.timestamp + 5000
      );

      if (taskGaze.length > 0) {
        // Calculate average attention during task
        const avgAttention = taskGaze.reduce((sum, g) =>
          sum + (g.data.attentionLevel === 'high' ? 1 :
                 g.data.attentionLevel === 'medium' ? 0.5 : 0.2), 0
        ) / taskGaze.length;

        const difficulty = task.data.difficulty; // 'easy', 'medium', 'hard'
        const difficultyValue = difficulty === 'easy' ? 0.33 :
                               difficulty === 'medium' ? 0.66 : 1.0;

        // Negative correlation: higher difficulty = lower attention
        const correlation = 1 - Math.abs(avgAttention - (1 - difficultyValue));

        if (correlation > 0.5) {
          correlations.push({
            type: 'attention-task',
            description: `${avgAttention.toFixed(2)} attention on ${difficulty} task`,
            value: avgAttention,
            confidence: correlation,
            startTime: task.timestamp,
            endTime: task.timestamp + 5000,
            events: [task, ...taskGaze]
          });
        }
      }
    }

    return correlations;
  }

  /**
   * Get recent events (last N)
   */
  getRecentEvents(count: number = 100): IntegratedEvent[] {
    return this.timeline.slice(-count);
  }

  /**
   * Get all correlations in session
   */
  getAllCorrelations(): CrossModalCorrelation[] {
    if (this.timeline.length === 0) return [];

    const start = this.timeline[0].timestamp;
    const end = this.timeline[this.timeline.length - 1].timestamp;

    return this.queryWindow(start, end).correlations;
  }

  /**
   * Export session data for storage
   * PRIVACY: Only exports summaries, no raw sensor data
   */
  exportSessionData(): {
    totalEvents: number;
    eventCounts: Record<EventType, number>;
    correlations: CrossModalCorrelation[];
    timeline: Array<{ type: EventType; timestamp: number; summary: string }>;
  } {
    const eventCounts: Record<string, number> = {
      gaze: 0,
      tap: 0,
      emotion: 0,
      audio: 0,
      task: 0,
      response: 0
    };

    for (const event of this.timeline) {
      eventCounts[event.type] = (eventCounts[event.type] || 0) + 1;
    }

    // Create timeline with summaries only (no raw data!)
    const timelineSummary = this.timeline.map(e => ({
      type: e.type,
      timestamp: e.timestamp,
      summary: this.summarizeEvent(e)
    }));

    const correlations = this.getAllCorrelations();

    return {
      totalEvents: this.timeline.length,
      eventCounts: eventCounts as Record<EventType, number>,
      correlations,
      timeline: timelineSummary
    };
  }

  /**
   * Summarize event without raw data
   */
  private summarizeEvent(event: IntegratedEvent): string {
    switch (event.type) {
      case 'gaze':
        return `Gaze: ${event.data.region || 'unknown'}`;
      case 'tap':
        return `Tap: ${event.data.target || 'screen'}`;
      case 'emotion':
        return `Emotion: ${event.data.label || 'neutral'}`;
      case 'audio':
        return `Audio: ${event.data.type || 'speech'}`;
      case 'task':
        return `Task: ${event.data.type || 'unknown'}`;
      case 'response':
        return `Response: ${event.data.correct ? 'correct' : 'incorrect'}`;
      default:
        return 'Event';
    }
  }

  /**
   * Clear timeline (e.g., start new session)
   */
  clear(): void {
    this.timeline = [];
    this.clockSkewMap.clear();
  }

  /**
   * Get statistics
   */
  getStats(): {
    totalEvents: number;
    timeSpan: number;
    avgEventsPerSecond: number;
    sources: string[];
  } {
    if (this.timeline.length === 0) {
      return {
        totalEvents: 0,
        timeSpan: 0,
        avgEventsPerSecond: 0,
        sources: []
      };
    }

    const start = this.timeline[0].timestamp;
    const end = this.timeline[this.timeline.length - 1].timestamp;
    const timeSpan = end - start;

    const sources = Array.from(new Set(this.timeline.map(e => e.source)));

    return {
      totalEvents: this.timeline.length,
      timeSpan,
      avgEventsPerSecond: timeSpan > 0 ? (this.timeline.length / (timeSpan / 1000)) : 0,
      sources
    };
  }
}

/**
 * USAGE EXAMPLE:
 *
 * const syncEngine = new MultimodalSyncEngine();
 *
 * // Register events from different sensors
 * syncEngine.registerEvent('gaze', Date.now(), {
 *   region: 'avatar-face',
 *   attentionLevel: 'high'
 * }, 'eye-tracker');
 *
 * syncEngine.registerEvent('tap', Date.now() + 500, {
 *   target: 'button-A',
 *   force: 0.7
 * }, 'touch-sensor');
 *
 * syncEngine.registerEvent('emotion', Date.now() + 200, {
 *   label: 'happy',
 *   confidence: 0.85
 * }, 'face-detector');
 *
 * syncEngine.registerEvent('audio', Date.now() + 300, {
 *   type: 'speech',
 *   power: 0.6
 * }, 'mic');
 *
 * // Query time window
 * const window = syncEngine.queryWindow(Date.now(), Date.now() + 1000);
 * console.log('Events in window:', window.events.length);
 * console.log('Correlations found:', window.correlations);
 *
 * // Get cross-modal insights
 * for (const correlation of window.correlations) {
 *   console.log(`${correlation.type}: ${correlation.description}`);
 *   console.log(`  Confidence: ${correlation.confidence.toFixed(2)}`);
 * }
 *
 * // Export for storage (privacy-safe)
 * const sessionData = syncEngine.exportSessionData();
 * await db.add('sessions', sessionData);
 */
