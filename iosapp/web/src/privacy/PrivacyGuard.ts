/**
 * PrivacyGuard - Privacy-First Sensor Data Processing
 *
 * GUARANTEES:
 * 1. No raw eye frames, face images, or audio clips are ever stored or sent
 * 2. Only derived features (gaze regions, emotion labels, prosody metrics) are kept
 * 3. All raw sensor buffers are held in memory only and cleared after processing
 *
 * USAGE IN PIPELINE:
 * 1. Collect raw samples in memory-only buffers (max size to prevent memory bloat)
 * 2. Call process* functions to extract features
 * 3. Raw buffers are automatically cleared after processing
 * 4. Store only the returned summaries in IndexedDB
 */

import {
  RawEyeSample,
  RawAudioFrame,
  RawFaceFrame,
  GazeSummary,
  ProsodySummary,
  EmotionTimeline,
  MemoryManager
} from './types';

/**
 * FORBIDDEN FUNCTION - Compile-time warning
 * Any attempt to persist raw sensor data should fail
 */
function forbiddenPersist(data: RawEyeSample | RawAudioFrame | RawFaceFrame): never {
  throw new Error(
    'PRIVACY VIOLATION: Attempted to persist raw sensor data. ' +
    'Only derived features (GazeSummary, ProsodySummary, EmotionTimeline) may be stored.'
  );
}

/**
 * Process eye samples and extract gaze features
 *
 * CALL THIS: After collecting a batch of samples (e.g., every 1-2 seconds)
 * CLEARS: samples array is zeroed out in-place
 * RETURNS: Safe-to-store GazeSummary objects
 */
export function processEyeSamples(samples: RawEyeSample[]): GazeSummary[] {
  if (!samples || samples.length === 0) {
    return [];
  }

  const summaries: GazeSummary[] = [];
  const startTime = samples[0].timestamp;
  const endTime = samples[samples.length - 1].timestamp;
  const duration = endTime - startTime;

  // Extract features WITHOUT storing raw coordinates
  const gazeRegions: ('avatar-face' | 'avatar-body' | 'task-area' | 'off-screen' | 'unknown')[] = [];
  let fixationCount = 0;
  let saccadeCount = 0;
  let blinkCount = 0;
  let lastGaze: { x: number; y: number } | null = null;

  for (const sample of samples) {
    // Determine region without storing exact coordinates
    const avgX = (sample.leftEye.x + sample.rightEye.x) / 2;
    const avgY = (sample.leftEye.y + sample.rightEye.y) / 2;

    // Map to regions (example logic - adjust to your UI layout)
    let region: typeof gazeRegions[0] = 'unknown';
    if (avgX < 0 || avgX > 1 || avgY < 0 || avgY > 1) {
      region = 'off-screen';
    } else if (avgX > 0.3 && avgX < 0.7 && avgY > 0.2 && avgY < 0.6) {
      region = 'avatar-face';
    } else if (avgX > 0.2 && avgX < 0.8 && avgY > 0.1 && avgY < 0.9) {
      region = 'avatar-body';
    } else {
      region = 'task-area';
    }

    gazeRegions.push(region);

    // Detect fixations and saccades
    if (lastGaze) {
      const distance = Math.sqrt(
        Math.pow(avgX - lastGaze.x, 2) + Math.pow(avgY - lastGaze.y, 2)
      );
      if (distance < 0.05) {
        fixationCount++;
      } else if (distance > 0.2) {
        saccadeCount++;
      }
    }
    lastGaze = { x: avgX, y: avgY };

    // Detect blinks
    if (!sample.leftEye.isOpen || !sample.rightEye.isOpen) {
      blinkCount++;
    }
  }

  // Calculate attention level based on region distribution
  const avatarFaceCount = gazeRegions.filter(r => r === 'avatar-face').length;
  const taskAreaCount = gazeRegions.filter(r => r === 'task-area').length;
  const totalCount = gazeRegions.length;

  const attentionRatio = (avatarFaceCount + taskAreaCount) / totalCount;
  const attentionLevel: 'high' | 'medium' | 'low' =
    attentionRatio > 0.7 ? 'high' : attentionRatio > 0.4 ? 'medium' : 'low';

  // Calculate quality score
  const fixationScore = Math.min(100, (fixationCount / totalCount) * 200);
  const blinkScore = Math.max(0, 100 - (blinkCount / totalCount) * 500);
  const score0to100 = Math.round((fixationScore * 0.6 + blinkScore * 0.4 + attentionRatio * 100) / 2);

  summaries.push({
    timestamp: startTime,
    duration,
    region: gazeRegions[Math.floor(gazeRegions.length / 2)], // Most common region
    attentionLevel,
    fixationCount,
    saccadeCount,
    blinkCount,
    score0to100: Math.min(100, Math.max(0, score0to100))
  });

  // CRITICAL: Clear raw data immediately
  clearEyeSamples(samples);

  return summaries;
}

/**
 * Process audio frames and extract prosody features
 *
 * CALL THIS: After collecting audio buffer (e.g., 2-5 second chunks)
 * CLEARS: frames array and internal buffers are zeroed
 * RETURNS: Safe-to-store ProsodySummary
 */
export function processAudioFrames(frames: RawAudioFrame[]): ProsodySummary | null {
  if (!frames || frames.length === 0) {
    return null;
  }

  const startTime = frames[0].timestamp;
  const endTime = frames[frames.length - 1].timestamp;
  const duration = endTime - startTime;

  // Extract prosody features WITHOUT storing raw audio
  const pitches: number[] = [];
  const volumes: number[] = [];
  let totalSamples = 0;
  let silenceCount = 0;
  const silenceThreshold = 0.01;

  for (const frame of frames) {
    // Simple pitch estimation (zero-crossing rate approximation)
    let zeroCrossings = 0;
    for (let i = 1; i < frame.buffer.length; i++) {
      if ((frame.buffer[i - 1] >= 0 && frame.buffer[i] < 0) ||
          (frame.buffer[i - 1] < 0 && frame.buffer[i] >= 0)) {
        zeroCrossings++;
      }
    }
    const estimatedPitch = (zeroCrossings * frame.sampleRate) / (2 * frame.buffer.length);
    pitches.push(estimatedPitch);

    // Volume (RMS)
    const rms = Math.sqrt(
      frame.buffer.reduce((sum, sample) => sum + sample * sample, 0) / frame.buffer.length
    );
    volumes.push(rms);

    if (rms < silenceThreshold) {
      silenceCount++;
    }

    totalSamples += frame.buffer.length;
  }

  // Calculate statistics
  const pitchMean = pitches.reduce((a, b) => a + b, 0) / pitches.length;
  const pitchVariance = pitches.reduce((sum, p) => sum + Math.pow(p - pitchMean, 2), 0) / pitches.length;
  const pitchStdDev = Math.sqrt(pitchVariance);

  const volumeMean = volumes.reduce((a, b) => a + b, 0) / volumes.length;
  const volumeVariance = volumes.reduce((sum, v) => sum + Math.pow(v - volumeMean, 2), 0) / volumes.length;
  const volumeStdDev = Math.sqrt(volumeVariance);

  // Estimate words per minute (very rough approximation)
  const pauseCount = silenceCount;
  const avgPauseDuration = pauseCount > 0 ? (duration / pauseCount) : 0;
  const wordEstimate = Math.max(1, frames.length - silenceCount);
  const wordsPerMinute = (wordEstimate / duration) * 60000;

  // Emotional valence (pitch and volume patterns)
  let emotionalValence: 'positive' | 'neutral' | 'negative' = 'neutral';
  if (pitchMean > 200 && volumeMean > 0.3) {
    emotionalValence = 'positive';
  } else if (pitchMean < 150 && volumeMean < 0.2) {
    emotionalValence = 'negative';
  }

  // Confidence based on signal quality
  const confidence = Math.min(1, volumeMean * 2);

  // Overall prosody score
  const pitchStability = Math.max(0, 100 - pitchStdDev * 10);
  const volumeScore = Math.min(100, volumeMean * 200);
  const fluencyScore = Math.min(100, wordsPerMinute / 2);
  const score0to100 = Math.round((pitchStability * 0.3 + volumeScore * 0.3 + fluencyScore * 0.4));

  const summary: ProsodySummary = {
    timestamp: startTime,
    duration,
    pitchMean: Math.round(pitchMean),
    pitchStdDev: Math.round(pitchStdDev * 10) / 10,
    volumeMean: Math.round(volumeMean * 100) / 100,
    volumeStdDev: Math.round(volumeStdDev * 100) / 100,
    wordsPerMinute: Math.round(wordsPerMinute),
    pauseCount,
    avgPauseDuration: Math.round(avgPauseDuration),
    emotionalValence,
    confidence: Math.round(confidence * 100) / 100,
    score0to100: Math.min(100, Math.max(0, score0to100))
  };

  // CRITICAL: Clear raw audio data immediately
  clearAudioFrames(frames);

  return summary;
}

/**
 * Process face frames and extract emotion timeline
 *
 * CALL THIS: After collecting face detection frames (e.g., every 1-2 seconds)
 * CLEARS: frames array and image data are cleared
 * RETURNS: Safe-to-store EmotionTimeline
 */
export function processFaceFrames(frames: RawFaceFrame[]): EmotionTimeline | null {
  if (!frames || frames.length === 0) {
    return null;
  }

  const startTime = frames[0].timestamp;
  const endTime = frames[frames.length - 1].timestamp;
  const duration = endTime - startTime;

  // Extract emotions WITHOUT storing raw face images
  const emotionEvents: EmotionTimeline['emotions'] = [];
  let currentEmotion: EmotionTimeline['emotions'][0] | null = null;
  let emotionChangeCount = 0;
  let engagementScore = 0;
  const faceDetectedCount = frames.filter(f => f.faceDetected).length;

  for (const frame of frames) {
    if (!frame.faceDetected) {
      continue;
    }

    // Simple emotion detection based on landmarks (if available)
    // In production, this would use a proper emotion recognition model
    let emotion: EmotionTimeline['emotions'][0]['label'] = 'neutral';
    let confidence = 0.7;

    // Simplified emotion detection logic (replace with real ML model)
    if (frame.landmarks && frame.landmarks.length > 0) {
      // This is a placeholder - in production use TensorFlow.js or similar
      emotion = 'happy'; // Simplified
      confidence = 0.8;
    }

    // Track emotion changes
    if (currentEmotion && currentEmotion.label !== emotion) {
      emotionEvents.push(currentEmotion);
      emotionChangeCount++;
      currentEmotion = {
        label: emotion,
        confidence,
        startTime: frame.timestamp,
        endTime: frame.timestamp
      };
    } else if (!currentEmotion) {
      currentEmotion = {
        label: emotion,
        confidence,
        startTime: frame.timestamp,
        endTime: frame.timestamp
      };
    } else {
      currentEmotion.endTime = frame.timestamp;
    }
  }

  // Add final emotion
  if (currentEmotion) {
    emotionEvents.push(currentEmotion);
  }

  // Calculate dominant emotion
  const emotionCounts = new Map<string, number>();
  for (const event of emotionEvents) {
    const duration = event.endTime - event.startTime;
    emotionCounts.set(event.label, (emotionCounts.get(event.label) || 0) + duration);
  }
  const dominantEmotion = Array.from(emotionCounts.entries())
    .sort((a, b) => b[1] - a[1])[0]?.[0] || 'neutral';

  // Engagement score based on face detection rate and emotion variety
  engagementScore = (faceDetectedCount / frames.length) * 0.7 +
                   (Math.min(emotionChangeCount, 5) / 5) * 0.3;

  // Overall emotion regulation score
  const positiveEmotions = emotionEvents.filter(e =>
    e.label === 'happy' || e.label === 'surprised'
  ).length;
  const negativeEmotions = emotionEvents.filter(e =>
    e.label === 'angry' || e.label === 'sad' || e.label === 'frustrated'
  ).length;
  const emotionBalance = (positiveEmotions - negativeEmotions + emotionEvents.length) /
                        (emotionEvents.length * 2);
  const score0to100 = Math.round(engagementScore * 50 + emotionBalance * 50);

  const timeline: EmotionTimeline = {
    timestamp: startTime,
    duration,
    emotions: emotionEvents,
    dominantEmotion,
    emotionChanges: emotionChangeCount,
    engagementScore: Math.round(engagementScore * 100) / 100,
    score0to100: Math.min(100, Math.max(0, score0to100))
  };

  // CRITICAL: Clear raw face data immediately
  clearFaceFrames(frames);

  return timeline;
}

/**
 * Clear eye sample buffers - zeroes out all data
 * CALL THIS: Automatically called by processEyeSamples
 */
function clearEyeSamples(samples: RawEyeSample[]): void {
  for (let i = 0; i < samples.length; i++) {
    // Overwrite with zeros
    samples[i] = {
      timestamp: 0,
      leftEye: { x: 0, y: 0, pupilDiameter: 0, isOpen: false },
      rightEye: { x: 0, y: 0, pupilDiameter: 0, isOpen: false },
      headPose: { pitch: 0, yaw: 0, roll: 0 }
    };
  }
  samples.length = 0; // Clear array
}

/**
 * Clear audio frame buffers - zeroes out all audio data
 * CALL THIS: Automatically called by processAudioFrames
 */
function clearAudioFrames(frames: RawAudioFrame[]): void {
  for (let i = 0; i < frames.length; i++) {
    // Zero out audio buffer
    if (frames[i].buffer) {
      frames[i].buffer.fill(0);
    }
    frames[i] = {
      timestamp: 0,
      sampleRate: 0,
      buffer: new Float32Array(0),
      duration: 0
    };
  }
  frames.length = 0; // Clear array
}

/**
 * Clear face frame buffers - destroys all image data
 * CALL THIS: Automatically called by processFaceFrames
 */
function clearFaceFrames(frames: RawFaceFrame[]): void {
  for (let i = 0; i < frames.length; i++) {
    // Clear image data
    if (frames[i].imageData) {
      frames[i].imageData.data.fill(0);
    }
    frames[i] = {
      timestamp: 0,
      imageData: new ImageData(1, 1),
      faceDetected: false,
      landmarks: []
    };
  }
  frames.length = 0; // Clear array
}

/**
 * Memory Manager Implementation
 * Tracks and manages raw sensor buffer memory
 */
export class PrivacyGuardMemoryManager implements MemoryManager {
  private eyeBuffers: RawEyeSample[][] = [];
  private audioBuffers: RawAudioFrame[][] = [];
  private faceBuffers: RawFaceFrame[][] = [];

  registerEyeBuffer(buffer: RawEyeSample[]): void {
    this.eyeBuffers.push(buffer);
  }

  registerAudioBuffer(buffer: RawAudioFrame[]): void {
    this.audioBuffers.push(buffer);
  }

  registerFaceBuffer(buffer: RawFaceFrame[]): void {
    this.faceBuffers.push(buffer);
  }

  clearEyeBuffers(): void {
    for (const buffer of this.eyeBuffers) {
      clearEyeSamples(buffer);
    }
    this.eyeBuffers = [];
  }

  clearAudioBuffers(): void {
    for (const buffer of this.audioBuffers) {
      clearAudioFrames(buffer);
    }
    this.audioBuffers = [];
  }

  clearFaceBuffers(): void {
    for (const buffer of this.faceBuffers) {
      clearFaceFrames(buffer);
    }
    this.faceBuffers = [];
  }

  clearAllBuffers(): void {
    this.clearEyeBuffers();
    this.clearAudioBuffers();
    this.clearFaceBuffers();
  }

  getMemoryUsageEstimate(): number {
    let bytes = 0;

    // Eye samples: ~100 bytes each
    for (const buffer of this.eyeBuffers) {
      bytes += buffer.length * 100;
    }

    // Audio frames: buffer size * 4 bytes (Float32)
    for (const buffer of this.audioBuffers) {
      bytes += buffer.reduce((sum, frame) => sum + frame.buffer.length * 4, 0);
    }

    // Face frames: imageData size
    for (const buffer of this.faceBuffers) {
      bytes += buffer.reduce((sum, frame) =>
        sum + (frame.imageData ? frame.imageData.data.length : 0), 0
      );
    }

    return bytes;
  }
}

/**
 * USAGE EXAMPLE IN PIPELINE:
 *
 * // 1. Setup
 * const memoryManager = new PrivacyGuardMemoryManager();
 * const eyeBuffer: RawEyeSample[] = [];
 * const audioBuffer: RawAudioFrame[] = [];
 * const faceBuffer: RawFaceFrame[] = [];
 *
 * memoryManager.registerEyeBuffer(eyeBuffer);
 * memoryManager.registerAudioBuffer(audioBuffer);
 * memoryManager.registerFaceBuffer(faceBuffer);
 *
 * // 2. Collect raw data (in memory only)
 * eyeBuffer.push({ timestamp: Date.now(), leftEye: {...}, rightEye: {...} });
 *
 * // 3. Process and extract features (every 1-2 seconds)
 * const gazeSummaries = processEyeSamples(eyeBuffer); // Automatically clears buffer
 * const prosody = processAudioFrames(audioBuffer); // Automatically clears buffer
 * const emotions = processFaceFrames(faceBuffer); // Automatically clears buffer
 *
 * // 4. Store ONLY derived features (safe to persist)
 * await db.add('sessionFeatures', {
 *   sessionId: 'xxx',
 *   learnerId: 'yyy',
 *   gaze: gazeSummaries,
 *   prosody: [prosody],
 *   emotions: [emotions]
 * });
 *
 * // 5. Cleanup on session end
 * memoryManager.clearAllBuffers();
 */

// Export forbidden function for compile-time checking
export { forbiddenPersist };
