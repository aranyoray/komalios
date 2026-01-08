/**
 * Touch Tracking System for Komal
 * Measures motor intent, frustration indicators, interaction patterns
 * Tracks accuracy, hesitation, pressure, self-soothing gestures
 */

class TouchTracker {
  constructor() {
    this.isActive = false;
    this.touches = [];
    this.hesitationTaps = [];
    this.selfSoothingGestures = [];
    this.targets = []; // Interactive elements that should be touched
    this.sessionStartTime = 0;

    // Metrics
    this.metrics = {
      goalDirectedAccuracy: 0,
      hesitationTaps: 0,
      totalTaps: 0,
      averageTapDuration: 0,
      touchPressure: {
        avg: 0,
        max: 0,
        variability: 0
      },
      touchHeatmap: [],
      patterns: {
        accurateTouches: 0,
        missedTouches: 0,
        accidentalTouches: 0,
        hesitantTouches: 0,
        forcefulTouches: 0
      }
    };

    // Event callbacks for correlation engine
    this.eventCallbacks = [];

    // Bind methods
    this.handleTouchStart = this.handleTouchStart.bind(this);
    this.handleTouchMove = this.handleTouchMove.bind(this);
    this.handleTouchEnd = this.handleTouchEnd.bind(this);
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
      callback('touch', eventType, data);
    });
  }

  start() {
    if (this.isActive) return;

    this.isActive = true;
    this.sessionStartTime = Date.now();
    this.touches = [];
    this.hesitationTaps = [];

    // Add event listeners
    document.addEventListener('touchstart', this.handleTouchStart, { passive: false });
    document.addEventListener('touchmove', this.handleTouchMove, { passive: false });
    document.addEventListener('touchend', this.handleTouchEnd, { passive: false });

    // Also track mouse events for desktop testing
    document.addEventListener('mousedown', this.handleTouchStart);
    document.addEventListener('mouseup', this.handleTouchEnd);

    console.log('[TouchTracker] Started');
  }

  stop() {
    if (!this.isActive) return;

    document.removeEventListener('touchstart', this.handleTouchStart);
    document.removeEventListener('touchmove', this.handleTouchMove);
    document.removeEventListener('touchend', this.handleTouchEnd);
    document.removeEventListener('mousedown', this.handleTouchStart);
    document.removeEventListener('mouseup', this.handleTouchEnd);

    this.isActive = false;
    this.calculateFinalMetrics();

    console.log('[TouchTracker] Stopped');
  }

  handleTouchStart(event) {
    if (!this.isActive) return;

    const touch = event.touches ? event.touches[0] : event;
    const timestamp = Date.now();

    const touchData = {
      id: this.touches.length,
      x: touch.clientX,
      y: touch.clientY,
      startTime: timestamp,
      endTime: null,
      duration: null,
      pressure: touch.force || 0.5, // 3D Touch on iOS
      target: event.target,
      isAccurate: false,
      isHesitation: false,
      isSelfSoothing: false
    };

    // Check if touch is on a valid target
    const hitTarget = this.checkTargetHit(touch.clientX, touch.clientY);
    if (hitTarget) {
      touchData.isAccurate = true;
      touchData.targetId = hitTarget.id;
    }

    this.touches.push(touchData);

    // Emit tap event for correlation
    this.emitEvent('tap', {
      location: { x: touch.clientX, y: touch.clientY },
      target: hitTarget ? hitTarget.id : null,
      isAccurate: touchData.isAccurate,
      pressure: touchData.pressure
    });

    // Detect hesitation (multiple rapid taps in same area)
    this.detectHesitation(touchData);
  }

  handleTouchMove(event) {
    // Could track swipe gestures, scrolling patterns
  }

  handleTouchEnd(event) {
    if (!this.isActive || this.touches.length === 0) return;

    const timestamp = Date.now();
    const lastTouch = this.touches[this.touches.length - 1];

    if (lastTouch && !lastTouch.endTime) {
      lastTouch.endTime = timestamp;
      lastTouch.duration = timestamp - lastTouch.startTime;
    }

    this.calculateMetrics();
  }

  /**
   * Check if touch hit a registered target
   */
  checkTargetHit(x, y) {
    for (const target of this.targets) {
      const rect = target.element.getBoundingClientRect();

      if (
        x >= rect.left &&
        x <= rect.right &&
        y >= rect.top &&
        y <= rect.bottom
      ) {
        return target;
      }
    }
    return null;
  }

  /**
   * Detect hesitation taps (multiple taps in same area quickly)
   */
  detectHesitation(currentTouch) {
    const HESITATION_WINDOW = 500; // ms
    const HESITATION_DISTANCE = 50; // px

    const recentTouches = this.touches.filter(t =>
      currentTouch.startTime - t.startTime < HESITATION_WINDOW &&
      t.id !== currentTouch.id
    );

    for (const touch of recentTouches) {
      const distance = Math.sqrt(
        Math.pow(currentTouch.x - touch.x, 2) +
        Math.pow(currentTouch.y - touch.y, 2)
      );

      if (distance < HESITATION_DISTANCE) {
        currentTouch.isHesitation = true;
        this.hesitationTaps.push(currentTouch);

        // Emit hesitation event for correlation
        this.emitEvent('hesitation', {
          location: { x: currentTouch.x, y: currentTouch.y },
          count: this.hesitationTaps.length,
          target: currentTouch.targetId || null
        });

        break;
      }
    }
  }

  /**
   * Detect self-soothing gestures (repeated tapping pattern)
   */
  detectSelfSoothing() {
    const SOOTHING_PATTERN = 3; // 3+ taps in same spot
    const SOOTHING_WINDOW = 2000; // 2 seconds

    const now = Date.now();
    const recentTouches = this.touches.filter(t =>
      now - t.startTime < SOOTHING_WINDOW
    );

    // Group by location
    const groups = {};
    recentTouches.forEach(touch => {
      const key = `${Math.floor(touch.x / 30)}-${Math.floor(touch.y / 30)}`;
      if (!groups[key]) groups[key] = [];
      groups[key].push(touch);
    });

    // Find groups with 3+ taps
    for (const [key, touches] of Object.entries(groups)) {
      if (touches.length >= SOOTHING_PATTERN) {
        this.selfSoothingGestures.push({
          timestamp: touches[0].startTime,
          count: touches.length,
          type: 'repeated-tap'
        });
      }
    }
  }

  /**
   * Register interactive target for accuracy tracking
   */
  registerTarget(id, element) {
    this.targets.push({ id, element });
  }

  /**
   * Unregister target
   */
  unregisterTarget(id) {
    this.targets = this.targets.filter(t => t.id !== id);
  }

  /**
   * Clear all targets
   */
  clearTargets() {
    this.targets = [];
  }

  /**
   * Calculate current metrics
   */
  calculateMetrics() {
    const completedTouches = this.touches.filter(t => t.endTime !== null);

    // Total taps
    this.metrics.totalTaps = completedTouches.length;

    // Goal-directed accuracy
    const accurateTouches = completedTouches.filter(t => t.isAccurate);
    this.metrics.goalDirectedAccuracy = this.metrics.totalTaps > 0
      ? accurateTouches.length / this.metrics.totalTaps
      : 0;

    // Hesitation taps
    this.metrics.hesitationTaps = this.hesitationTaps.length;

    // Average tap duration
    const totalDuration = completedTouches.reduce((sum, t) => sum + t.duration, 0);
    this.metrics.averageTapDuration = completedTouches.length > 0
      ? totalDuration / completedTouches.length / 1000
      : 0;

    // Touch pressure (if available)
    if (completedTouches.length > 0) {
      const pressures = completedTouches.map(t => t.pressure);
      this.metrics.touchPressure.avg = pressures.reduce((a, b) => a + b, 0) / pressures.length;
      this.metrics.touchPressure.max = Math.max(...pressures);

      const avgPressure = this.metrics.touchPressure.avg;
      const variance = pressures.reduce((sum, p) => sum + Math.pow(p - avgPressure, 2), 0) / pressures.length;
      this.metrics.touchPressure.variability = Math.sqrt(variance);
    }

    // Pattern analysis
    this.metrics.patterns.accurateTouches = accurateTouches.length;
    this.metrics.patterns.missedTouches = this.metrics.totalTaps - accurateTouches.length;
    this.metrics.patterns.hesitantTouches = this.hesitationTaps.length;
    this.metrics.patterns.forcefulTouches = completedTouches.filter(t => t.pressure > 0.7).length;

    // Detect self-soothing
    this.detectSelfSoothing();
  }

  /**
   * Calculate final metrics at session end
   */
  calculateFinalMetrics() {
    this.calculateMetrics();

    // Generate touch heatmap
    const heatmapData = {};

    this.touches.forEach(touch => {
      const key = `${Math.floor(touch.x / 20)}-${Math.floor(touch.y / 20)}`;
      heatmapData[key] = (heatmapData[key] || 0) + 1;
    });

    this.metrics.touchHeatmap = Object.entries(heatmapData).map(([key, count]) => {
      const [x, y] = key.split('-').map(Number);
      return { x: x * 20, y: y * 20, count };
    });

    return this.metrics;
  }

  /**
   * Get current metrics
   */
  getMetrics() {
    return { ...this.metrics };
  }

  /**
   * Get session data for storage
   */
  getSessionData() {
    return {
      ...this.getMetrics(),
      selfSoothingGestures: this.selfSoothingGestures
    };
  }
}

export const touchTracker = new TouchTracker();
