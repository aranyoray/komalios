/**
 * Voice Tracking System for Komal
 * Measures vocal activity, pitch, speech rate, emotional state
 * Uses Web Audio API for real-time analysis
 */

class VoiceTracker {
  constructor() {
    this.isActive = false;
    this.audioContext = null;
    this.analyser = null;
    this.microphone = null;
    this.dataArray = null;
    this.bufferLength = null;

    this.vocalizations = [];
    this.speechSegments = [];
    this.sessionStartTime = 0;
    this.lastVocalTime = 0;
    this.isSpeaking = false;

    // Metrics
    this.metrics = {
      vocalActivity: 0,
      totalSpeechDuration: 0,
      pitchVariation: {
        avg: 0,
        min: 0,
        max: 0,
        stdDev: 0
      },
      speechRate: 0,
      pauseDuration: {
        avg: 0,
        max: 0
      },
      volumePatterns: {
        avg: 0,
        variability: 0
      },
      vocalizationTypes: {
        words: 0,
        sounds: 0,
        silence: 0
      },
      confidence: 0,
      hesitations: 0
    };

    this.volumeSamples = [];
    this.pitchSamples = [];
    this.pauseDurations = [];

    // Event callbacks for correlation engine
    this.eventCallbacks = [];
  }

  /**
   * Register callback for events (for correlation engine)
   */
  onEvent(callback) {
    this.eventCallbacks.push(callback);
  }

  /**
   * Emit event to correlation engine
   */
  emitEvent(eventType, data) {
    this.eventCallbacks.forEach(callback => {
      callback('voice', eventType, data);
    });
  }

  async init() {
    try {
      // Get microphone access
      const stream = await navigator.mediaDevices.getUserMedia({
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true
        }
      });

      // Set up Web Audio API
      this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
      this.analyser = this.audioContext.createAnalyser();
      this.analyser.fftSize = 2048;
      this.bufferLength = this.analyser.frequencyBinCount;
      this.dataArray = new Uint8Array(this.bufferLength);

      this.microphone = this.audioContext.createMediaStreamSource(stream);
      this.microphone.connect(this.analyser);

      console.log('[VoiceTracker] Initialized');
      return true;
    } catch (error) {
      console.error('[VoiceTracker] Initialization failed:', error);
      return false;
    }
  }

  start() {
    if (this.isActive) return;

    this.isActive = true;
    this.sessionStartTime = Date.now();
    this.vocalizations = [];
    this.speechSegments = [];
    this.volumeSamples = [];
    this.pitchSamples = [];

    this.processAudio();

    console.log('[VoiceTracker] Started');
  }

  stop() {
    if (!this.isActive) return;

    this.isActive = false;

    if (this.microphone && this.microphone.mediaStream) {
      this.microphone.mediaStream.getTracks().forEach(track => track.stop());
    }

    if (this.audioContext) {
      this.audioContext.close();
    }

    this.calculateFinalMetrics();

    console.log('[VoiceTracker] Stopped');
  }

  /**
   * Process audio in real-time
   */
  processAudio() {
    if (!this.isActive) return;

    this.analyser.getByteTimeDomainData(this.dataArray);

    const timestamp = Date.now();

    // Calculate volume (RMS)
    const volume = this.calculateVolume();
    this.volumeSamples.push({ timestamp, volume });

    // Detect speech vs silence
    const SPEECH_THRESHOLD = 0.02;
    const isSpeaking = volume > SPEECH_THRESHOLD;

    if (isSpeaking && !this.isSpeaking) {
      // Speech started
      this.isSpeaking = true;
      this.currentSpeechStart = timestamp;

      // If there was a pause, record it
      if (this.lastVocalTime) {
        const pauseDuration = timestamp - this.lastVocalTime;
        this.pauseDurations.push(pauseDuration);

        // Check if this is a hesitation (short pause)
        if (pauseDuration < 300) {
          this.metrics.hesitations++;
        }
      }

      // Emit vocalization start event
      this.emitEvent('vocalization', {
        type: 'start',
        volume,
        duration: 0,
        confidence: volume > 0.05 ? 0.8 : 0.5
      });
    } else if (!isSpeaking && this.isSpeaking) {
      // Speech ended
      this.isSpeaking = false;
      this.lastVocalTime = timestamp;

      const duration = timestamp - this.currentSpeechStart;

      // Emit vocalization end event with full data
      this.emitEvent('vocalization', {
        type: 'speech',
        duration,
        confidence: this.calculateConfidence(duration, volume)
      });

      this.speechSegments.push({
        startTime: this.currentSpeechStart,
        endTime: timestamp,
        duration
      });

      // Estimate pitch during speech
      const pitch = this.estimatePitch();
      if (pitch > 0) {
        this.pitchSamples.push(pitch);
      }
    }

    // Continue processing
    requestAnimationFrame(() => this.processAudio());
  }

  /**
   * Calculate volume (RMS)
   */
  calculateVolume() {
    let sum = 0;
    for (let i = 0; i < this.bufferLength; i++) {
      const normalized = (this.dataArray[i] - 128) / 128;
      sum += normalized * normalized;
    }
    return Math.sqrt(sum / this.bufferLength);
  }

  /**
   * Estimate fundamental frequency (pitch) using autocorrelation
   */
  estimatePitch() {
    // Simplified pitch detection
    // In production, use a library like Pitchy or YIN algorithm

    const SIZE = this.bufferLength;
    const MAX_SAMPLES = Math.floor(SIZE / 2);
    let best_offset = -1;
    let best_correlation = 0;
    let rms = 0;

    // Calculate RMS
    for (let i = 0; i < SIZE; i++) {
      const val = (this.dataArray[i] - 128) / 128;
      rms += val * val;
    }
    rms = Math.sqrt(rms / SIZE);

    // Not enough signal
    if (rms < 0.01) return -1;

    // Autocorrelation
    let lastCorrelation = 1;
    for (let offset = 1; offset < MAX_SAMPLES; offset++) {
      let correlation = 0;

      for (let i = 0; i < MAX_SAMPLES; i++) {
        correlation += Math.abs(
          (this.dataArray[i] - 128) / 128 -
          (this.dataArray[i + offset] - 128) / 128
        );
      }

      correlation = 1 - correlation / MAX_SAMPLES;

      if (correlation > 0.9 && correlation > lastCorrelation) {
        const foundGoodCorrelation = correlation > best_correlation;
        if (foundGoodCorrelation) {
          best_correlation = correlation;
          best_offset = offset;
        }
      }

      lastCorrelation = correlation;
    }

    if (best_offset !== -1) {
      const sampleRate = this.audioContext.sampleRate;
      const fundamentalFreq = sampleRate / best_offset;
      return fundamentalFreq;
    }

    return -1;
  }

  /**
   * Calculate confidence score for vocalization
   */
  calculateConfidence(duration, volume) {
    // Longer duration and higher volume = higher confidence
    let confidence = 0.5; // baseline

    if (duration > 500) confidence += 0.2;
    if (duration > 1000) confidence += 0.1;
    if (volume > 0.05) confidence += 0.2;

    return Math.min(1.0, confidence);
  }

  /**
   * Calculate current metrics
   */
  calculateMetrics() {
    const now = Date.now();
    const sessionDuration = (now - this.sessionStartTime) / 1000; // seconds

    // Vocal activity (% of session)
    const totalSpeechDuration = this.speechSegments.reduce((sum, s) => sum + s.duration, 0) / 1000;
    this.metrics.totalSpeechDuration = totalSpeechDuration;
    this.metrics.vocalActivity = sessionDuration > 0 ? totalSpeechDuration / sessionDuration : 0;

    // Pitch variation
    if (this.pitchSamples.length > 0) {
      const pitches = this.pitchSamples.filter(p => p > 0 && p < 500); // Filter outliers

      if (pitches.length > 0) {
        this.metrics.pitchVariation.avg = pitches.reduce((a, b) => a + b, 0) / pitches.length;
        this.metrics.pitchVariation.min = Math.min(...pitches);
        this.metrics.pitchVariation.max = Math.max(...pitches);

        const avg = this.metrics.pitchVariation.avg;
        const variance = pitches.reduce((sum, p) => sum + Math.pow(p - avg, 2), 0) / pitches.length;
        this.metrics.pitchVariation.stdDev = Math.sqrt(variance);
      }
    }

    // Speech rate (estimated words per minute)
    // Rough estimate: 1 speech segment ≈ 1-3 words
    const estimatedWords = this.speechSegments.length * 2;
    this.metrics.speechRate = totalSpeechDuration > 0
      ? Math.round((estimatedWords / totalSpeechDuration) * 60)
      : 0;

    // Pause durations
    if (this.pauseDurations.length > 0) {
      this.metrics.pauseDuration.avg = this.pauseDurations.reduce((a, b) => a + b, 0) / this.pauseDurations.length / 1000;
      this.metrics.pauseDuration.max = Math.max(...this.pauseDurations) / 1000;
    }

    // Volume patterns
    if (this.volumeSamples.length > 0) {
      const volumes = this.volumeSamples.map(s => s.volume);
      this.metrics.volumePatterns.avg = volumes.reduce((a, b) => a + b, 0) / volumes.length;

      const avgVol = this.metrics.volumePatterns.avg;
      const variance = volumes.reduce((sum, v) => sum + Math.pow(v - avgVol, 2), 0) / volumes.length;
      this.metrics.volumePatterns.variability = Math.sqrt(variance);
    }

    // Vocalization types
    this.metrics.vocalizationTypes.words = this.speechSegments.length;
    this.metrics.vocalizationTypes.silence = 1 - this.metrics.vocalActivity;

    // Confidence (derived from speech characteristics)
    // Higher volume, consistent pitch, fewer pauses = higher confidence
    const volumeScore = Math.min(1, this.metrics.volumePatterns.avg / 0.1);
    const pitchScore = this.metrics.pitchVariation.stdDev < 50 ? 0.8 : 0.5;
    const pauseScore = this.metrics.pauseDuration.avg < 2 ? 0.8 : 0.4;

    this.metrics.confidence = (volumeScore + pitchScore + pauseScore) / 3;

    // Hesitations (long pauses before speaking)
    this.metrics.hesitations = this.pauseDurations.filter(p => p > 2000).length;
  }

  /**
   * Calculate final metrics at session end
   */
  calculateFinalMetrics() {
    this.calculateMetrics();
    return this.metrics;
  }

  /**
   * Get current metrics
   */
  getMetrics() {
    this.calculateMetrics();
    return { ...this.metrics };
  }

  /**
   * Get session data for storage
   */
  getSessionData() {
    return {
      ...this.getMetrics(),
      speechSegments: this.speechSegments.length,
      pauseCount: this.pauseDurations.length
    };
  }
}

export const voiceTracker = new VoiceTracker();
