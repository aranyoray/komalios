/**
 * Real-Time Cross-Modal Event Correlation Engine
 * Correlates events across eye tracking, touch tracking, voice, and facial expressions
 * Detects temporal patterns during 15-minute sessions
 */

class CorrelationEngine {
  constructor(config = {}) {
    this.config = {
      correlationWindow: config.correlationWindow || 500, // ms - events within this window are considered related
      maxEventHistory: config.maxEventHistory || 1000, // Keep last N events
      enableRealTimeAnalysis: config.enableRealTimeAnalysis !== false,
      ...config
    };

    // Event timeline - unified storage for all tracking events
    this.timeline = [];

    // Detected patterns
    this.patterns = {
      eyeTouch: [], // Eye movement → Touch correlation
      gazeVocalization: [], // Gaze pattern → Vocalization
      emotionBehavior: [], // Emotion → Behavioral response
      attentionResponse: [], // Attention change → Response latency
      frustrationAvoidance: [], // Frustration → Avoidance behavior
      socialEngagement: [] // Social gaze + vocalization
    };

    // Real-time statistics
    this.stats = {
      totalEvents: 0,
      correlatedEvents: 0,
      patternCounts: {},
      lastProcessedTime: 0
    };

    // Session start reference time
    this.sessionStartTime = null;
  }

  /**
   * Initialize engine with session start time
   */
  startSession() {
    this.sessionStartTime = performance.now();
    this.timeline = [];
    this.patterns = {
      eyeTouch: [],
      gazeVocalization: [],
      emotionBehavior: [],
      attentionResponse: [],
      frustrationAvoidance: [],
      socialEngagement: []
    };
    this.stats = {
      totalEvents: 0,
      correlatedEvents: 0,
      patternCounts: {},
      lastProcessedTime: 0
    };
  }

  /**
   * Add event from any tracking system
   * @param {string} source - 'eye' | 'touch' | 'voice' | 'face' | 'response'
   * @param {string} eventType - Specific event type
   * @param {Object} data - Event-specific data
   */
  addEvent(source, eventType, data) {
    const timestamp = performance.now();
    const relativeTime = this.sessionStartTime ? timestamp - this.sessionStartTime : 0;

    const event = {
      id: `${source}_${timestamp}`,
      source,
      eventType,
      timestamp,
      relativeTime,
      data,
      correlated: false
    };

    this.timeline.push(event);
    this.stats.totalEvents++;

    // Maintain max history size
    if (this.timeline.length > this.config.maxEventHistory) {
      this.timeline.shift();
    }

    // Process correlations in real-time
    if (this.config.enableRealTimeAnalysis) {
      this.processRecentCorrelations(event);
    }

    return event;
  }

  /**
   * Process correlations for newly added event
   */
  processRecentCorrelations(newEvent) {
    const windowStart = newEvent.timestamp - this.config.correlationWindow;

    // Get recent events within correlation window
    const recentEvents = this.timeline.filter(e =>
      e.timestamp >= windowStart &&
      e.timestamp < newEvent.timestamp &&
      e.source !== newEvent.source // Different modality
    );

    // Check for specific correlation patterns
    recentEvents.forEach(priorEvent => {
      this.detectPatterns(priorEvent, newEvent);
    });
  }

  /**
   * Detect correlation patterns between two events
   */
  detectPatterns(event1, event2) {
    const timeDiff = event2.timestamp - event1.timestamp;

    // Pattern 1: Eye movement (saccade) → Touch
    if (event1.source === 'eye' && event1.eventType === 'saccade' &&
        event2.source === 'touch' && event2.eventType === 'tap') {
      this.patterns.eyeTouch.push({
        timestamp: event2.timestamp,
        relativeTime: event2.relativeTime,
        delay: timeDiff,
        gazeFrom: event1.data.from,
        gazeTo: event1.data.to,
        touchLocation: event2.data.location,
        touchTarget: event2.data.target,
        wasAccurate: event2.data.isAccurate,
        pattern: 'look-then-tap'
      });

      event1.correlated = true;
      event2.correlated = true;
      this.stats.correlatedEvents++;
      this.incrementPatternCount('eyeTouch');
    }

    // Pattern 2: Gaze to avatar → Vocalization
    if (event1.source === 'eye' && event1.eventType === 'roiEnter' &&
        event1.data.roi === 'avatar' &&
        event2.source === 'voice' && event2.eventType === 'vocalization') {
      this.patterns.gazeVocalization.push({
        timestamp: event2.timestamp,
        relativeTime: event2.relativeTime,
        delay: timeDiff,
        gazeTarget: event1.data.roi,
        vocalizationType: event2.data.type,
        duration: event2.data.duration,
        confidence: event2.data.confidence,
        pattern: 'social-vocalization'
      });

      event1.correlated = true;
      event2.correlated = true;
      this.stats.correlatedEvents++;
      this.incrementPatternCount('gazeVocalization');
    }

    // Pattern 3: Frustration emotion → Hesitation taps
    if (event1.source === 'face' && event1.eventType === 'emotion' &&
        event1.data.emotion === 'frustration' &&
        event2.source === 'touch' && event2.eventType === 'hesitation') {
      this.patterns.emotionBehavior.push({
        timestamp: event2.timestamp,
        relativeTime: event2.relativeTime,
        delay: timeDiff,
        emotion: event1.data.emotion,
        emotionConfidence: event1.data.confidence,
        hesitationCount: event2.data.count,
        location: event2.data.location,
        pattern: 'frustration-hesitation'
      });

      event1.correlated = true;
      event2.correlated = true;
      this.stats.correlatedEvents++;
      this.incrementPatternCount('emotionBehavior');
    }

    // Pattern 4: Attention drop → Response latency
    if (event1.source === 'eye' && event1.eventType === 'attentionDrop' &&
        event2.source === 'response' && event2.eventType === 'delayed') {
      this.patterns.attentionResponse.push({
        timestamp: event2.timestamp,
        relativeTime: event2.relativeTime,
        delay: timeDiff,
        attentionScore: event1.data.score,
        responseLatency: event2.data.latency,
        taskDifficulty: event2.data.difficulty,
        pattern: 'attention-delay'
      });

      event1.correlated = true;
      event2.correlated = true;
      this.stats.correlatedEvents++;
      this.incrementPatternCount('attentionResponse');
    }

    // Pattern 5: Frustration → Gaze aversion (avoidance)
    if (event1.source === 'face' && event1.eventType === 'emotion' &&
        (event1.data.emotion === 'frustration' || event1.data.emotion === 'anxiety') &&
        event2.source === 'eye' && event2.eventType === 'aversion') {
      this.patterns.frustrationAvoidance.push({
        timestamp: event2.timestamp,
        relativeTime: event2.relativeTime,
        delay: timeDiff,
        emotion: event1.data.emotion,
        emotionIntensity: event1.data.confidence,
        aversionType: event2.data.type,
        duration: event2.data.duration,
        pattern: 'emotional-avoidance'
      });

      event1.correlated = true;
      event2.correlated = true;
      this.stats.correlatedEvents++;
      this.incrementPatternCount('frustrationAvoidance');
    }

    // Pattern 6: Social gaze + Vocalization (social engagement)
    if (event1.source === 'eye' && event1.eventType === 'socialGaze' &&
        event2.source === 'voice' && event2.eventType === 'vocalization') {
      this.patterns.socialEngagement.push({
        timestamp: event2.timestamp,
        relativeTime: event2.relativeTime,
        delay: timeDiff,
        gazeTarget: event1.data.target,
        gazeDuration: event1.data.duration,
        vocalizationType: event2.data.type,
        vocalConfidence: event2.data.confidence,
        pattern: 'joint-attention-communication'
      });

      event1.correlated = true;
      event2.correlated = true;
      this.stats.correlatedEvents++;
      this.incrementPatternCount('socialEngagement');
    }
  }

  /**
   * Increment pattern count for statistics
   */
  incrementPatternCount(patternType) {
    if (!this.stats.patternCounts[patternType]) {
      this.stats.patternCounts[patternType] = 0;
    }
    this.stats.patternCounts[patternType]++;
  }

  /**
   * Get all detected patterns
   */
  getPatterns() {
    return { ...this.patterns };
  }

  /**
   * Get pattern summary for reporting
   */
  getPatternSummary() {
    const summary = {
      totalPatterns: 0,
      patternTypes: {},
      insights: []
    };

    // Count patterns
    for (const [type, patterns] of Object.entries(this.patterns)) {
      const count = patterns.length;
      summary.totalPatterns += count;
      summary.patternTypes[type] = count;
    }

    // Generate insights
    if (this.patterns.eyeTouch.length > 0) {
      const accuracyRate = this.patterns.eyeTouch.filter(p => p.wasAccurate).length /
                          this.patterns.eyeTouch.length;
      const avgDelay = this.patterns.eyeTouch.reduce((sum, p) => sum + p.delay, 0) /
                      this.patterns.eyeTouch.length;

      summary.insights.push({
        category: 'Eye-Hand Coordination',
        metric: 'Look-then-tap accuracy',
        value: (accuracyRate * 100).toFixed(0) + '%',
        avgDelay: Math.round(avgDelay) + 'ms',
        interpretation: accuracyRate > 0.8 ?
          'Good eye-hand coordination and intentional targeting' :
          'Some difficulty coordinating gaze and touch'
      });
    }

    if (this.patterns.gazeVocalization.length > 0) {
      const socialVocalizations = this.patterns.gazeVocalization.filter(p =>
        p.gazeTarget === 'avatar' || p.pattern === 'social-vocalization'
      ).length;

      summary.insights.push({
        category: 'Social Communication',
        metric: 'Avatar gaze with vocalization',
        value: socialVocalizations,
        interpretation: socialVocalizations > 5 ?
          'Strong social engagement and communication attempts' :
          'Limited social-communicative behavior'
      });
    }

    if (this.patterns.emotionBehavior.length > 0) {
      const frustrationResponses = this.patterns.emotionBehavior.filter(p =>
        p.emotion === 'frustration'
      ).length;

      summary.insights.push({
        category: 'Emotional Regulation',
        metric: 'Frustration-related hesitation',
        value: frustrationResponses,
        interpretation: frustrationResponses > 3 ?
          'Frustration impacts decision-making and confidence' :
          'Good emotional regulation under challenge'
      });
    }

    if (this.patterns.attentionResponse.length > 0) {
      const avgLatency = this.patterns.attentionResponse.reduce((sum, p) =>
        sum + p.responseLatency, 0) / this.patterns.attentionResponse.length;

      summary.insights.push({
        category: 'Attention & Response',
        metric: 'Response delay after attention drop',
        value: Math.round(avgLatency) + 'ms',
        interpretation: avgLatency > 2000 ?
          'Attention lapses significantly impact response time' :
          'Can recover attention and respond reasonably quickly'
      });
    }

    return summary;
  }

  /**
   * Get timeline of all events
   */
  getTimeline() {
    return [...this.timeline];
  }

  /**
   * Get statistics
   */
  getStats() {
    return {
      ...this.stats,
      correlationRate: this.stats.totalEvents > 0 ?
        (this.stats.correlatedEvents / this.stats.totalEvents * 100).toFixed(1) + '%' :
        '0%'
    };
  }

  /**
   * Export session data for storage
   */
  exportSessionData() {
    return {
      timeline: this.timeline,
      patterns: this.patterns,
      patternSummary: this.getPatternSummary(),
      stats: this.getStats(),
      sessionDuration: this.sessionStartTime ?
        performance.now() - this.sessionStartTime : 0
    };
  }

  /**
   * Reset engine
   */
  reset() {
    this.timeline = [];
    this.patterns = {
      eyeTouch: [],
      gazeVocalization: [],
      emotionBehavior: [],
      attentionResponse: [],
      frustrationAvoidance: [],
      socialEngagement: []
    };
    this.stats = {
      totalEvents: 0,
      correlatedEvents: 0,
      patternCounts: {},
      lastProcessedTime: 0
    };
    this.sessionStartTime = null;
  }
}

export default CorrelationEngine;
