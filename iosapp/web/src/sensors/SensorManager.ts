/**
 * SensorManager - Robust Sensor Initialization with Graceful Degradation
 *
 * Handles:
 * - Eye tracking (camera + permission)
 * - Facial expression (camera + permission)
 * - Microphone (mic + permission)
 * - Touch + standard events (always available)
 *
 * Features:
 * - Capability detection on init
 * - Permission status checking
 * - Graceful degradation when sensors unavailable
 * - Structured error handling
 * - Event-based architecture
 */

import { RawEyeSample, RawAudioFrame, RawFaceFrame } from '../privacy/types';

/**
 * Sensor capabilities detected on initialization
 */
export interface SensorCapabilities {
  eye: boolean;     // Camera available + permission granted
  face: boolean;    // Camera available + permission granted
  mic: boolean;     // Microphone available + permission granted
  touch: boolean;   // Always true (standard browser feature)
}

/**
 * Structured error object for sensor failures
 */
export interface SensorError {
  sensor: 'eye' | 'face' | 'mic' | 'touch';
  code: string;
  message: string;
  timestamp: number;
  permissionDenied?: boolean;
  deviceUnavailable?: boolean;
}

/**
 * Event listener type definitions
 */
export type EyeSampleListener = (sample: RawEyeSample) => void;
export type FaceFrameListener = (frame: RawFaceFrame) => void;
export type AudioFrameListener = (frame: RawAudioFrame) => void;
export type TouchEventListener = (event: TouchEvent | MouseEvent) => void;
export type ErrorListener = (error: SensorError) => void;

/**
 * SensorManager Class
 * Central hub for all sensor initialization, management, and event distribution
 */
export class SensorManager {
  private capabilities: SensorCapabilities = {
    eye: false,
    face: false,
    mic: false,
    touch: true // Always available in browser
  };

  private isRunning = false;
  private videoStream: MediaStream | null = null;
  private audioStream: MediaStream | null = null;
  private videoElement: HTMLVideoElement | null = null;

  // Event listeners
  private eyeListeners: EyeSampleListener[] = [];
  private faceListeners: FaceFrameListener[] = [];
  private audioListeners: AudioFrameListener[] = [];
  private touchListeners: TouchEventListener[] = [];
  private errorListeners: ErrorListener[] = [];

  // Animation frame IDs for cleanup
  private eyeTrackingFrameId: number | null = null;
  private faceDetectionFrameId: number | null = null;
  private audioProcessorId: NodeJS.Timeout | null = null;

  /**
   * Initialize sensor capabilities
   * Detects what's available and requests permissions
   */
  async init(): Promise<SensorCapabilities> {
    console.log('[SensorManager] Initializing sensors...');

    // Check touch support (always true in modern browsers)
    this.capabilities.touch = 'ontouchstart' in window || navigator.maxTouchPoints > 0;

    // Check camera availability for eye + face tracking
    await this.initCamera();

    // Check microphone availability
    await this.initMicrophone();

    console.log('[SensorManager] Capabilities detected:', this.capabilities);
    return this.capabilities;
  }

  /**
   * Initialize camera for eye and face tracking
   */
  private async initCamera(): Promise<void> {
    try {
      // Check if getUserMedia is supported
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        console.warn('[SensorManager] Camera API not supported');
        return;
      }

      // Request camera permission
      this.videoStream = await navigator.mediaDevices.getUserMedia({
        video: {
          facingMode: 'user',
          width: { ideal: 640 },
          height: { ideal: 480 }
        }
      });

      // Camera available and permission granted
      this.capabilities.eye = true;
      this.capabilities.face = true;

      console.log('[SensorManager] Camera initialized successfully');
    } catch (error: any) {
      const sensorError: SensorError = {
        sensor: 'eye',
        code: error.name || 'CAMERA_ERROR',
        message: error.message || 'Camera initialization failed',
        timestamp: Date.now(),
        permissionDenied: error.name === 'NotAllowedError' || error.name === 'PermissionDeniedError',
        deviceUnavailable: error.name === 'NotFoundError' || error.name === 'DevicesNotFoundError'
      };

      this.emitError(sensorError);

      // Set both eye and face to false
      this.capabilities.eye = false;
      this.capabilities.face = false;

      console.warn('[SensorManager] Camera initialization failed:', error.name, error.message);
    }
  }

  /**
   * Initialize microphone for voice tracking
   */
  private async initMicrophone(): Promise<void> {
    try {
      // Check if getUserMedia is supported
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        console.warn('[SensorManager] Microphone API not supported');
        return;
      }

      // Request microphone permission
      this.audioStream = await navigator.mediaDevices.getUserMedia({
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true
        }
      });

      this.capabilities.mic = true;
      console.log('[SensorManager] Microphone initialized successfully');
    } catch (error: any) {
      const sensorError: SensorError = {
        sensor: 'mic',
        code: error.name || 'MIC_ERROR',
        message: error.message || 'Microphone initialization failed',
        timestamp: Date.now(),
        permissionDenied: error.name === 'NotAllowedError' || error.name === 'PermissionDeniedError',
        deviceUnavailable: error.name === 'NotFoundError' || error.name === 'DevicesNotFoundError'
      };

      this.emitError(sensorError);
      this.capabilities.mic = false;

      console.warn('[SensorManager] Microphone initialization failed:', error.name, error.message);
    }
  }

  /**
   * Get current sensor capabilities
   */
  getCapabilities(): SensorCapabilities {
    return { ...this.capabilities };
  }

  /**
   * Start all available sensors
   */
  async start(): Promise<void> {
    if (this.isRunning) {
      console.warn('[SensorManager] Already running');
      return;
    }

    this.isRunning = true;
    console.log('[SensorManager] Starting sensors...');

    // Start eye tracking if available
    if (this.capabilities.eye) {
      this.startEyeTracking();
    }

    // Start face detection if available
    if (this.capabilities.face) {
      this.startFaceDetection();
    }

    // Start audio processing if available
    if (this.capabilities.mic) {
      this.startAudioProcessing();
    }

    // Start touch tracking (always available)
    if (this.capabilities.touch) {
      this.startTouchTracking();
    }

    console.log('[SensorManager] Sensors started');
  }

  /**
   * Stop all sensors
   */
  stop(): void {
    if (!this.isRunning) {
      return;
    }

    console.log('[SensorManager] Stopping sensors...');

    // Stop eye tracking
    if (this.eyeTrackingFrameId !== null) {
      cancelAnimationFrame(this.eyeTrackingFrameId);
      this.eyeTrackingFrameId = null;
    }

    // Stop face detection
    if (this.faceDetectionFrameId !== null) {
      cancelAnimationFrame(this.faceDetectionFrameId);
      this.faceDetectionFrameId = null;
    }

    // Stop audio processing
    if (this.audioProcessorId !== null) {
      clearInterval(this.audioProcessorId);
      this.audioProcessorId = null;
    }

    // Stop touch tracking
    this.stopTouchTracking();

    // Stop media streams
    if (this.videoStream) {
      this.videoStream.getTracks().forEach(track => track.stop());
      this.videoStream = null;
    }

    if (this.audioStream) {
      this.audioStream.getTracks().forEach(track => track.stop());
      this.audioStream = null;
    }

    this.isRunning = false;
    console.log('[SensorManager] Sensors stopped');
  }

  /**
   * Start eye tracking
   */
  private startEyeTracking(): void {
    if (!this.videoStream) return;

    try {
      // Create video element if needed
      if (!this.videoElement) {
        this.videoElement = document.createElement('video');
        this.videoElement.autoplay = true;
        this.videoElement.playsInline = true;
        this.videoElement.muted = true;
        this.videoElement.srcObject = this.videoStream;
      }

      // Start processing loop
      const processEyeFrame = () => {
        if (!this.isRunning) return;

        try {
          // Simulate eye tracking (replace with real implementation)
          const sample: RawEyeSample = {
            timestamp: Date.now(),
            leftEye: {
              x: Math.random(),
              y: Math.random(),
              pupilDiameter: 3 + Math.random() * 2,
              isOpen: Math.random() > 0.05
            },
            rightEye: {
              x: Math.random(),
              y: Math.random(),
              pupilDiameter: 3 + Math.random() * 2,
              isOpen: Math.random() > 0.05
            },
            headPose: {
              pitch: (Math.random() - 0.5) * 30,
              yaw: (Math.random() - 0.5) * 30,
              roll: (Math.random() - 0.5) * 10
            }
          };

          this.emitEyeSample(sample);
          this.eyeTrackingFrameId = requestAnimationFrame(processEyeFrame);
        } catch (error: any) {
          this.handleSensorError('eye', error);
        }
      };

      processEyeFrame();
      console.log('[SensorManager] Eye tracking started');
    } catch (error: any) {
      this.handleSensorError('eye', error);
    }
  }

  /**
   * Start face detection
   */
  private startFaceDetection(): void {
    if (!this.videoStream) return;

    try {
      const processFaceFrame = () => {
        if (!this.isRunning) return;

        try {
          // Create canvas for face detection
          const canvas = document.createElement('canvas');
          canvas.width = 640;
          canvas.height = 480;
          const ctx = canvas.getContext('2d');

          if (ctx && this.videoElement) {
            ctx.drawImage(this.videoElement, 0, 0, canvas.width, canvas.height);
            const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);

            const frame: RawFaceFrame = {
              timestamp: Date.now(),
              imageData,
              faceDetected: Math.random() > 0.1, // Simulate detection
              landmarks: [] // Would be populated by real face detector
            };

            this.emitFaceFrame(frame);
          }

          this.faceDetectionFrameId = requestAnimationFrame(processFaceFrame);
        } catch (error: any) {
          this.handleSensorError('face', error);
        }
      };

      processFaceFrame();
      console.log('[SensorManager] Face detection started');
    } catch (error: any) {
      this.handleSensorError('face', error);
    }
  }

  /**
   * Start audio processing
   */
  private startAudioProcessing(): void {
    if (!this.audioStream) return;

    try {
      const audioContext = new AudioContext();
      const source = audioContext.createMediaStreamSource(this.audioStream);
      const analyser = audioContext.createAnalyser();
      analyser.fftSize = 2048;
      source.connect(analyser);

      const bufferLength = analyser.fftSize;
      const dataArray = new Float32Array(bufferLength);

      // Process audio at regular intervals
      this.audioProcessorId = setInterval(() => {
        try {
          analyser.getFloatTimeDomainData(dataArray);

          const frame: RawAudioFrame = {
            timestamp: Date.now(),
            sampleRate: audioContext.sampleRate,
            buffer: new Float32Array(dataArray),
            duration: (bufferLength / audioContext.sampleRate) * 1000
          };

          this.emitAudioFrame(frame);
        } catch (error: any) {
          this.handleSensorError('mic', error);
        }
      }, 100); // Process every 100ms

      console.log('[SensorManager] Audio processing started');
    } catch (error: any) {
      this.handleSensorError('mic', error);
    }
  }

  /**
   * Start touch tracking
   */
  private startTouchTracking(): void {
    // Touch events
    document.addEventListener('touchstart', this.handleTouchEvent);
    document.addEventListener('touchmove', this.handleTouchEvent);
    document.addEventListener('touchend', this.handleTouchEvent);

    // Mouse events as fallback
    document.addEventListener('mousedown', this.handleTouchEvent);
    document.addEventListener('mousemove', this.handleTouchEvent);
    document.addEventListener('mouseup', this.handleTouchEvent);

    console.log('[SensorManager] Touch tracking started');
  }

  /**
   * Stop touch tracking
   */
  private stopTouchTracking(): void {
    document.removeEventListener('touchstart', this.handleTouchEvent);
    document.removeEventListener('touchmove', this.handleTouchEvent);
    document.removeEventListener('touchend', this.handleTouchEvent);
    document.removeEventListener('mousedown', this.handleTouchEvent);
    document.removeEventListener('mousemove', this.handleTouchEvent);
    document.removeEventListener('mouseup', this.handleTouchEvent);
  }

  /**
   * Handle touch/mouse events
   */
  private handleTouchEvent = (event: TouchEvent | MouseEvent): void => {
    this.emitTouchEvent(event);
  };

  /**
   * Handle sensor errors gracefully
   */
  private handleSensorError(sensor: 'eye' | 'face' | 'mic' | 'touch', error: any): void {
    const sensorError: SensorError = {
      sensor,
      code: error.name || 'SENSOR_ERROR',
      message: error.message || 'Sensor processing error',
      timestamp: Date.now()
    };

    this.emitError(sensorError);

    // Disable the failed sensor
    this.capabilities[sensor] = false;

    // Stop the failed sensor stream
    if (sensor === 'eye' && this.eyeTrackingFrameId) {
      cancelAnimationFrame(this.eyeTrackingFrameId);
      this.eyeTrackingFrameId = null;
    } else if (sensor === 'face' && this.faceDetectionFrameId) {
      cancelAnimationFrame(this.faceDetectionFrameId);
      this.faceDetectionFrameId = null;
    } else if (sensor === 'mic' && this.audioProcessorId) {
      clearInterval(this.audioProcessorId);
      this.audioProcessorId = null;
    }

    console.error(`[SensorManager] ${sensor} sensor failed and has been disabled:`, error);
  }

  /**
   * Subscribe to events
   */
  subscribe(
    eventType: 'eye' | 'face' | 'audio' | 'touch' | 'error',
    callback: any
  ): () => void {
    switch (eventType) {
      case 'eye':
        this.eyeListeners.push(callback as EyeSampleListener);
        return () => {
          this.eyeListeners = this.eyeListeners.filter(l => l !== callback);
        };
      case 'face':
        this.faceListeners.push(callback as FaceFrameListener);
        return () => {
          this.faceListeners = this.faceListeners.filter(l => l !== callback);
        };
      case 'audio':
        this.audioListeners.push(callback as AudioFrameListener);
        return () => {
          this.audioListeners = this.audioListeners.filter(l => l !== callback);
        };
      case 'touch':
        this.touchListeners.push(callback as TouchEventListener);
        return () => {
          this.touchListeners = this.touchListeners.filter(l => l !== callback);
        };
      case 'error':
        this.errorListeners.push(callback as ErrorListener);
        return () => {
          this.errorListeners = this.errorListeners.filter(l => l !== callback);
        };
      default:
        return () => {};
    }
  }

  /**
   * Emit events to listeners
   */
  private emitEyeSample(sample: RawEyeSample): void {
    for (const listener of this.eyeListeners) {
      try {
        listener(sample);
      } catch (error) {
        console.error('[SensorManager] Eye listener error:', error);
      }
    }
  }

  private emitFaceFrame(frame: RawFaceFrame): void {
    for (const listener of this.faceListeners) {
      try {
        listener(frame);
      } catch (error) {
        console.error('[SensorManager] Face listener error:', error);
      }
    }
  }

  private emitAudioFrame(frame: RawAudioFrame): void {
    for (const listener of this.audioListeners) {
      try {
        listener(frame);
      } catch (error) {
        console.error('[SensorManager] Audio listener error:', error);
      }
    }
  }

  private emitTouchEvent(event: TouchEvent | MouseEvent): void {
    for (const listener of this.touchListeners) {
      try {
        listener(event);
      } catch (error) {
        console.error('[SensorManager] Touch listener error:', error);
      }
    }
  }

  private emitError(error: SensorError): void {
    for (const listener of this.errorListeners) {
      try {
        listener(error);
      } catch (err) {
        console.error('[SensorManager] Error listener error:', err);
      }
    }
  }
}

/**
 * USAGE EXAMPLE:
 *
 * const sensorManager = new SensorManager();
 *
 * // Initialize and detect capabilities
 * const capabilities = await sensorManager.init();
 * console.log('Available sensors:', capabilities);
 *
 * // Subscribe to events
 * const unsubEye = sensorManager.subscribe('eye', (sample) => {
 *   console.log('Eye sample:', sample);
 * });
 *
 * const unsubError = sensorManager.subscribe('error', (error) => {
 *   console.warn('Sensor error:', error);
 *   // Show non-intrusive UI message to adult
 * });
 *
 * // Start sensors
 * await sensorManager.start();
 *
 * // App degrades gracefully if sensors unavailable
 * if (!capabilities.eye) {
 *   console.log('Eye tracking not available, skipping gaze metrics');
 * }
 *
 * // Stop when done
 * sensorManager.stop();
 * unsubEye();
 * unsubError();
 */
