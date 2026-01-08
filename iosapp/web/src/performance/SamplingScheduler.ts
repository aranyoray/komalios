/**
 * Performance-Oriented Sampling Scheduler
 *
 * Limits CPU/battery usage by:
 * - Downsampling sensor processing to reasonable rates
 * - Batching scoring calculations between tasks
 * - Preventing unnecessary computations
 *
 * JUSTIFICATIONS FOR DEFAULT SAMPLING RATES:
 *
 * 1. Eye Tracking (10-15 Hz):
 *    - Human gaze shifts (saccades) occur 2-3 times per second
 *    - Fixations last 200-400ms on average
 *    - 10-15 Hz captures all meaningful gaze behavior
 *    - Higher rates waste CPU without improving accuracy
 *
 * 2. Face/Emotion Detection (5-10 Hz):
 *    - Facial expressions change over 0.5-2 seconds
 *    - Micro-expressions are 1/5 to 1/2 second
 *    - 5-10 Hz is sufficient for emotion trend analysis
 *    - Real-time emotion recognition is computationally expensive
 *
 * 3. Audio/Prosody (20-50 Hz processing, but batched):
 *    - Speech prosody features computed over 100-500ms windows
 *    - Pitch/volume patterns emerge over syllables/words
 *    - Process in chunks rather than frame-by-frame
 *
 * 4. Touch Events (event-driven, no sampling needed):
 *    - Touch events are discrete and infrequent
 *    - Process immediately when they occur
 */

/**
 * Sampling configuration for each sensor type
 */
export interface SamplingConfig {
  eyeHz: number;        // Default: 10-15 Hz
  faceHz: number;       // Default: 5-10 Hz
  audioChunkMs: number; // Default: 100-200ms chunks
  scoringDebounceMs: number; // Default: 500-1000ms
}

/**
 * Default sampling configuration
 * Based on psychophysical and UX constraints
 */
export const DEFAULT_SAMPLING_CONFIG: SamplingConfig = {
  eyeHz: 12,            // 12 samples/sec = ~83ms intervals
  faceHz: 8,            // 8 samples/sec = 125ms intervals
  audioChunkMs: 150,    // Process audio in 150ms chunks
  scoringDebounceMs: 750 // Batch scoring every 750ms
};

/**
 * Aggressive battery-saving configuration
 * For low-power devices or low battery scenarios
 */
export const BATTERY_SAVER_CONFIG: SamplingConfig = {
  eyeHz: 8,             // Reduce to 8 Hz
  faceHz: 5,            // Reduce to 5 Hz
  audioChunkMs: 250,    // Larger chunks
  scoringDebounceMs: 1500 // Less frequent scoring
};

/**
 * High-performance configuration
 * For research or detailed analysis scenarios
 */
export const HIGH_PERFORMANCE_CONFIG: SamplingConfig = {
  eyeHz: 15,            // Maximum useful rate
  faceHz: 10,           // Maximum useful rate
  audioChunkMs: 100,    // Smaller chunks for responsiveness
  scoringDebounceMs: 500 // More frequent scoring
};

/**
 * Sensor Scheduler
 * Determines when to process sensor frames based on target Hz
 */
export class SensorScheduler {
  private config: SamplingConfig;
  private lastEyeProcessTime = 0;
  private lastFaceProcessTime = 0;
  private lastAudioProcessTime = 0;

  constructor(config: SamplingConfig = DEFAULT_SAMPLING_CONFIG) {
    this.config = config;
  }

  /**
   * Update sampling configuration (e.g., when battery is low)
   */
  updateConfig(config: Partial<SamplingConfig>): void {
    this.config = { ...this.config, ...config };
    console.log('[SensorScheduler] Config updated:', this.config);
  }

  /**
   * Should we process this eye frame?
   * Returns true if enough time has passed based on target Hz
   */
  shouldProcessEyeFrame(timestampMs: number): boolean {
    const intervalMs = 1000 / this.config.eyeHz;
    const timeSinceLastProcess = timestampMs - this.lastEyeProcessTime;

    if (timeSinceLastProcess >= intervalMs) {
      this.lastEyeProcessTime = timestampMs;
      return true;
    }

    return false;
  }

  /**
   * Should we process this face frame?
   * Returns true if enough time has passed based on target Hz
   */
  shouldProcessFaceFrame(timestampMs: number): boolean {
    const intervalMs = 1000 / this.config.faceHz;
    const timeSinceLastProcess = timestampMs - this.lastFaceProcessTime;

    if (timeSinceLastProcess >= intervalMs) {
      this.lastFaceProcessTime = timestampMs;
      return true;
    }

    return false;
  }

  /**
   * Should we process this audio chunk?
   * Returns true if enough time has passed for next chunk
   */
  shouldProcessAudioChunk(timestampMs: number): boolean {
    const timeSinceLastProcess = timestampMs - this.lastAudioProcessTime;

    if (timeSinceLastProcess >= this.config.audioChunkMs) {
      this.lastAudioProcessTime = timestampMs;
      return true;
    }

    return false;
  }

  /**
   * Get current sampling rates (for monitoring/debugging)
   */
  getCurrentRates(): {
    eyeHz: number;
    faceHz: number;
    audioChunkMs: number;
  } {
    return {
      eyeHz: this.config.eyeHz,
      faceHz: this.config.faceHz,
      audioChunkMs: this.config.audioChunkMs
    };
  }

  /**
   * Reset timing state (e.g., when starting new session)
   */
  reset(): void {
    this.lastEyeProcessTime = 0;
    this.lastFaceProcessTime = 0;
    this.lastAudioProcessTime = 0;
  }
}

/**
 * Metric update queue entry
 */
interface MetricUpdate {
  metricId: string;
  rawData: any;
  timestamp: number;
}

/**
 * Scoring Scheduler
 * Batches expensive metric calculations to run between tasks
 */
export class ScoringScheduler {
  private config: SamplingConfig;
  private updateQueue: MetricUpdate[] = [];
  private lastScoringTime = 0;
  private scoringTimer: NodeJS.Timeout | null = null;
  private scoringCallback: ((updates: MetricUpdate[]) => void) | null = null;

  constructor(config: SamplingConfig = DEFAULT_SAMPLING_CONFIG) {
    this.config = config;
  }

  /**
   * Update configuration
   */
  updateConfig(config: Partial<SamplingConfig>): void {
    this.config = { ...this.config, ...config };
    this.restartTimer();
  }

  /**
   * Queue a metric update
   * Expensive computations are deferred until batch processing
   */
  queueMetricUpdate(metricId: string, rawData: any): void {
    this.updateQueue.push({
      metricId,
      rawData,
      timestamp: Date.now()
    });

    // Prevent queue from growing too large
    // Keep only last 100 updates per metric
    const metricUpdates = this.updateQueue.filter(u => u.metricId === metricId);
    if (metricUpdates.length > 100) {
      // Remove oldest updates for this metric
      const toRemove = metricUpdates.slice(0, metricUpdates.length - 100);
      this.updateQueue = this.updateQueue.filter(u => !toRemove.includes(u));
    }
  }

  /**
   * Register callback for batch scoring
   * Called at most once every config.scoringDebounceMs
   */
  onBatchScore(callback: (updates: MetricUpdate[]) => void): void {
    this.scoringCallback = callback;
    this.startTimer();
  }

  /**
   * Start the debounced scoring timer
   */
  private startTimer(): void {
    if (this.scoringTimer) return;

    this.scoringTimer = setInterval(() => {
      this.processBatch();
    }, this.config.scoringDebounceMs);
  }

  /**
   * Restart timer with new config
   */
  private restartTimer(): void {
    this.stopTimer();
    this.startTimer();
  }

  /**
   * Stop the scoring timer
   */
  private stopTimer(): void {
    if (this.scoringTimer) {
      clearInterval(this.scoringTimer);
      this.scoringTimer = null;
    }
  }

  /**
   * Process batched updates
   */
  private processBatch(): void {
    if (this.updateQueue.length === 0) return;

    const now = Date.now();
    const timeSinceLastScoring = now - this.lastScoringTime;

    // Only process if enough time has passed
    if (timeSinceLastScoring >= this.config.scoringDebounceMs) {
      if (this.scoringCallback) {
        // Pass queue to callback
        const updates = [...this.updateQueue];
        this.scoringCallback(updates);

        // Clear processed updates
        this.updateQueue = [];
        this.lastScoringTime = now;
      }
    }
  }

  /**
   * Force immediate processing (e.g., at end of task)
   */
  flush(): void {
    if (this.updateQueue.length > 0 && this.scoringCallback) {
      const updates = [...this.updateQueue];
      this.scoringCallback(updates);
      this.updateQueue = [];
      this.lastScoringTime = Date.now();
    }
  }

  /**
   * Clear queue without processing
   */
  clear(): void {
    this.updateQueue = [];
  }

  /**
   * Get queue size (for monitoring)
   */
  getQueueSize(): number {
    return this.updateQueue.length;
  }

  /**
   * Cleanup
   */
  destroy(): void {
    this.stopTimer();
    this.updateQueue = [];
    this.scoringCallback = null;
  }
}

/**
 * Create a sensor scheduler with specified config
 */
export function createSensorScheduler(
  config: SamplingConfig = DEFAULT_SAMPLING_CONFIG
): SensorScheduler {
  return new SensorScheduler(config);
}

/**
 * Create a scoring scheduler with specified config
 */
export function createScoringScheduler(
  config: SamplingConfig = DEFAULT_SAMPLING_CONFIG
): ScoringScheduler {
  return new ScoringScheduler(config);
}

/**
 * Battery-aware configuration helper
 * Adjusts sampling rates based on battery level
 */
export async function getBatteryAwareConfig(): Promise<SamplingConfig> {
  try {
    // Check if Battery Status API is available
    if ('getBattery' in navigator) {
      const battery = await (navigator as any).getBattery();
      const level = battery.level; // 0-1
      const charging = battery.charging;

      // If battery is low (<20%) and not charging, use battery saver
      if (level < 0.2 && !charging) {
        console.log('[SamplingScheduler] Low battery detected, using BATTERY_SAVER_CONFIG');
        return BATTERY_SAVER_CONFIG;
      }

      // If battery is medium (20-50%) and not charging, use default
      if (level < 0.5 && !charging) {
        console.log('[SamplingScheduler] Medium battery detected, using DEFAULT_SAMPLING_CONFIG');
        return DEFAULT_SAMPLING_CONFIG;
      }

      // Otherwise use high performance
      console.log('[SamplingScheduler] Good battery level, using HIGH_PERFORMANCE_CONFIG');
      return HIGH_PERFORMANCE_CONFIG;
    }
  } catch (error) {
    console.warn('[SamplingScheduler] Battery API not available, using default config');
  }

  return DEFAULT_SAMPLING_CONFIG;
}

/**
 * USAGE EXAMPLE:
 *
 * // 1. Create schedulers
 * const sensorScheduler = createSensorScheduler(DEFAULT_SAMPLING_CONFIG);
 * const scoringScheduler = createScoringScheduler(DEFAULT_SAMPLING_CONFIG);
 *
 * // 2. In sensor processing loop
 * sensorManager.subscribe('eye', (sample) => {
 *   // Only process if scheduler says so
 *   if (sensorScheduler.shouldProcessEyeFrame(sample.timestamp)) {
 *     // Extract features from sample
 *     const features = extractEyeFeatures(sample);
 *
 *     // Queue for batched scoring
 *     scoringScheduler.queueMetricUpdate('joint-attention', features);
 *   }
 * });
 *
 * // 3. Register batch scoring callback
 * scoringScheduler.onBatchScore((updates) => {
 *   console.log(`Processing ${updates.length} metric updates`);
 *
 *   // Group by metric ID
 *   const grouped = groupBy(updates, 'metricId');
 *
 *   // Compute scores for each metric
 *   for (const [metricId, metricUpdates] of Object.entries(grouped)) {
 *     const score = computeMetric(metricId, metricUpdates);
 *     updateUI(metricId, score);
 *   }
 * });
 *
 * // 4. Adjust based on battery
 * const batteryConfig = await getBatteryAwareConfig();
 * sensorScheduler.updateConfig(batteryConfig);
 * scoringScheduler.updateConfig(batteryConfig);
 *
 * // 5. Force flush at end of task
 * scoringScheduler.flush();
 *
 * // 6. Cleanup
 * scoringScheduler.destroy();
 */
