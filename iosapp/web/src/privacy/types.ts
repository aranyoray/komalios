/**
 * Privacy-First Type Definitions for Komal
 *
 * CRITICAL PRIVACY PRINCIPLE:
 * Raw sensor data (RawEyeSample, RawAudioFrame, RawFaceFrame) must NEVER
 * be persisted to disk, sent to any server, or stored in any database.
 *
 * Only derived feature summaries are allowed to be stored.
 */

/**
 * Raw Eye Sample - MUST NEVER BE PERSISTED
 * Held in memory only, cleared immediately after processing
 */
export interface RawEyeSample {
  timestamp: number;
  leftEye: {
    x: number;
    y: number;
    pupilDiameter?: number;
    isOpen: boolean;
  };
  rightEye: {
    x: number;
    y: number;
    pupilDiameter?: number;
    isOpen: boolean;
  };
  headPose?: {
    pitch: number;
    yaw: number;
    roll: number;
  };
}

/**
 * Raw Audio Frame - MUST NEVER BE PERSISTED
 * Audio buffer held in memory only, cleared after feature extraction
 */
export interface RawAudioFrame {
  timestamp: number;
  sampleRate: number;
  buffer: Float32Array; // Raw audio samples - NEVER persist
  duration: number;
}

/**
 * Raw Face Frame - MUST NEVER BE PERSISTED
 * Image data held in memory only, cleared after emotion detection
 */
export interface RawFaceFrame {
  timestamp: number;
  imageData: ImageData; // Raw pixels - NEVER persist
  faceDetected: boolean;
  landmarks?: {
    x: number;
    y: number;
  }[];
}

/**
 * SAFE TO STORE: Derived gaze summary
 * Contains no raw image or coordinate data
 */
export interface GazeSummary {
  timestamp: number;
  duration: number;
  region: 'avatar-face' | 'avatar-body' | 'task-area' | 'off-screen' | 'unknown';
  attentionLevel: 'high' | 'medium' | 'low';
  fixationCount: number;
  saccadeCount: number;
  blinkCount: number;
  score0to100: number; // Overall attention quality
}

/**
 * SAFE TO STORE: Derived prosody summary
 * Contains no raw audio data
 */
export interface ProsodySummary {
  timestamp: number;
  duration: number;
  pitchMean: number; // Hz
  pitchStdDev: number;
  volumeMean: number; // 0-1
  volumeStdDev: number;
  wordsPerMinute: number;
  pauseCount: number;
  avgPauseDuration: number; // ms
  emotionalValence: 'positive' | 'neutral' | 'negative';
  confidence: number; // 0-1
  score0to100: number; // Overall prosody quality
}

/**
 * SAFE TO STORE: Derived emotion timeline
 * Contains no raw face image data
 */
export interface EmotionTimeline {
  timestamp: number;
  duration: number;
  emotions: {
    label: 'happy' | 'sad' | 'angry' | 'fearful' | 'surprised' | 'disgusted' | 'neutral' | 'frustrated';
    confidence: number;
    startTime: number;
    endTime: number;
  }[];
  dominantEmotion: string;
  emotionChanges: number; // Count of emotion transitions
  engagementScore: number; // 0-1
  score0to100: number; // Overall emotional regulation quality
}

/**
 * Touch/Interaction Summary - Already safe, no raw sensor data
 */
export interface TouchSummary {
  timestamp: number;
  duration: number;
  tapCount: number;
  swipeCount: number;
  dragCount: number;
  avgResponseLatency: number; // ms
  accuracy: number; // 0-1, percentage of on-target touches
  score0to100: number;
}

/**
 * Complete Privacy-Safe Session Features
 * This is what gets stored in IndexedDB and optionally synced to cloud
 */
export interface SessionFeatures {
  sessionId: string;
  learnerId: string;
  timestamp: number;
  duration: number;

  // Derived features only - no raw sensor data
  gaze: GazeSummary[];
  prosody: ProsodySummary[];
  emotions: EmotionTimeline[];
  touch: TouchSummary[];

  // Additional safe metadata
  taskCompleted: boolean;
  taskType: string;
  errorCount: number;
}

/**
 * Memory Management Interface
 * Ensures raw buffers are cleared after processing
 */
export interface MemoryManager {
  clearEyeBuffers(): void;
  clearAudioBuffers(): void;
  clearFaceBuffers(): void;
  clearAllBuffers(): void;
  getMemoryUsageEstimate(): number; // bytes
}
