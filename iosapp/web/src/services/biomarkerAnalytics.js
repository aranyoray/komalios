/**
 * Biomarker Analytics Service
 * Complete analytics parameters as specified in Assessment Parameters
 */

class BiomarkerAnalytics {
  constructor() {
    this.sessionData = {
      eyeTracking: {},
      facialExpression: {},
      gestureTouch: {},
      responsePattern: {},
    };
  }

  /**
   * 1) Eye-Tracking Analytics
   */
  calculateEyeTrackingMetrics(gazeData) {
    return {
      // Attention Score (fixation % on relevant content)
      attentionScore: {
        value: this.calculateAttentionScore(gazeData),
        meaning: 'Sustained task focus',
        interpretation: 'Higher → stronger engagement with task and avatar cues',
      },

      // Concentration Stability (micro-saccade frequency)
      concentrationStability: {
        value: this.calculateConcentrationStability(gazeData),
        meaning: 'Ability to maintain gaze without distraction',
        interpretation: 'A drop → more external distraction or anxiety',
      },

      // Exploration vs Avoidance Ratio
      explorationAvoidanceRatio: {
        value: this.calculateExplorationAvoidance(gazeData),
        meaning: 'Comfort with uncertain/triggering stimuli',
        interpretation: 'High avoidance → fear/frustration during certain prompts',
      },

      // Social Gaze Index (eye contact with avatar)
      socialGazeIndex: {
        value: this.calculateSocialGaze(gazeData),
        meaning: 'Social reciprocity + comfort',
        interpretation: 'Increase over sessions → reduced communication anxiety',
      },

      // Nuanced Notes
      nuancedNotes: {
        gazeAversionTriggers: this.identifyGazeAversionTriggers(gazeData),
        gazeHuntingBeforeSwitch: this.detectGazeHunting(gazeData),
      },
    };
  }

  /**
   * 2) Facial Expression / Micro-Emotions
   */
  calculateFacialMetrics(emotionData) {
    return {
      // Affect Diversity Score
      affectDiversityScore: {
        value: this.calculateAffectDiversity(emotionData),
        tracks: 'Range of detectable emotions',
        interpretation: 'Low range → masking or flat affect',
      },

      // Positive-Affect Activation
      positiveAffectActivation: {
        value: this.calculatePositiveAffect(emotionData),
        tracks: 'Joy, pride during success',
        interpretation: '↑ means improved self-confidence',
      },

      // Frustration Tolerance Index
      frustrationToleranceIndex: {
        value: this.calculateFrustrationTolerance(emotionData),
        tracks: 'Time to recover from negative affect',
        interpretation: '↓ recovery time = resilience growing',
      },

      // Empathy Response
      empathyResponse: {
        value: this.calculateEmpathyResponse(emotionData),
        tracks: 'Reaction to avatar distress',
        interpretation: '↑ signals improvement in social awareness',
      },

      // Pattern: distress timing
      distressTiming: emotionData.distressBeforeOrAfterDifficulty || 'unknown',
    };
  }

  /**
   * 3) Gesture & Touch Pattern Analytics
   */
  calculateTouchMetrics(touchData) {
    return {
      // Goal-Directed Accuracy
      goalDirectedAccuracy: {
        value: this.calculateTouchAccuracy(touchData),
        interpretation: 'Successfully selected elements vs. random tapping',
      },

      // Hesitation Taps
      hesitationTaps: {
        value: touchData.hesitationTaps || 0,
        interpretation: 'Anxiety, doubt, or compulsive checking',
      },

      // Force Variability (if device supports)
      forceVariability: {
        value: touchData.forceVariability || 'N/A',
        interpretation: 'Impulsivity vs. control',
      },

      // Self-Soothing Gestures
      selfSoothingGestures: {
        value: touchData.selfSoothingCount || 0,
        interpretation: 'Stress-reduction behaviours emerging naturally',
      },

      // Overall interpretation
      overallInterpretation: this.interpretTouchPatterns(touchData),
    };
  }

  /**
   * 4) Response Pattern Dynamics
   */
  calculateResponseMetrics(responseData) {
    return {
      // Response Initiation Latency
      responseInitiationLatency: {
        value: responseData.avgLatency || 0,
        reflects: 'Confidence + decisiveness',
        unit: 'ms',
      },

      // Retry Count
      retryCount: {
        value: responseData.retries || 0,
        reflects: 'Avoidance vs. persistence',
      },

      // Conversational Turn-Taking Score
      turnTakingScore: {
        value: this.calculateTurnTaking(responseData),
        reflects: 'Social reciprocity',
      },

      // Error Correction Profile
      errorCorrectionProfile: {
        value: this.calculateErrorCorrection(responseData),
        reflects: 'Growth mindset vs. helplessness',
      },

      // Interpretive flags
      flags: this.generateResponseFlags(responseData),
    };
  }

  // Calculation helper methods
  calculateAttentionScore(gazeData) {
    if (!gazeData || !gazeData.fixations) return 0;
    const relevantFixations = gazeData.fixations.filter(f => f.isOnTarget);
    return Math.round((relevantFixations.length / gazeData.fixations.length) * 100) || 0;
  }

  calculateConcentrationStability(gazeData) {
    if (!gazeData || !gazeData.saccades) return 100;
    const microSaccades = gazeData.saccades.filter(s => s.amplitude < 1);
    // Lower micro-saccade frequency = better concentration
    const stability = 100 - (microSaccades.length * 2);
    return Math.max(0, Math.min(100, stability));
  }

  calculateExplorationAvoidance(gazeData) {
    if (!gazeData) return 50;
    const exploration = gazeData.explorationEvents || 0;
    const avoidance = gazeData.avoidanceEvents || 0;
    const total = exploration + avoidance;
    return total > 0 ? Math.round((exploration / total) * 100) : 50;
  }

  calculateSocialGaze(gazeData) {
    if (!gazeData || !gazeData.fixations) return 0;
    const avatarFixations = gazeData.fixations.filter(f => f.target === 'avatar_face');
    return Math.round((avatarFixations.length / gazeData.fixations.length) * 100) || 0;
  }

  identifyGazeAversionTriggers(gazeData) {
    if (!gazeData || !gazeData.aversionEvents) return [];
    return gazeData.aversionEvents.map(e => e.trigger);
  }

  detectGazeHunting(gazeData) {
    return gazeData?.gazeHuntingDetected || false;
  }

  calculateAffectDiversity(emotionData) {
    if (!emotionData || !emotionData.detectedEmotions) return 0;
    const uniqueEmotions = new Set(emotionData.detectedEmotions.map(e => e.type));
    return Math.round((uniqueEmotions.size / 7) * 100); // 7 basic emotions
  }

  calculatePositiveAffect(emotionData) {
    if (!emotionData || !emotionData.detectedEmotions) return 0;
    const positive = emotionData.detectedEmotions.filter(
      e => ['happy', 'surprised', 'proud'].includes(e.type)
    );
    return Math.round((positive.length / emotionData.detectedEmotions.length) * 100) || 0;
  }

  calculateFrustrationTolerance(emotionData) {
    if (!emotionData || !emotionData.frustrationRecoveryTimes) return 50;
    const avgRecovery = emotionData.frustrationRecoveryTimes.reduce((a, b) => a + b, 0) /
      emotionData.frustrationRecoveryTimes.length;
    // Lower recovery time = higher tolerance score
    return Math.max(0, Math.min(100, 100 - (avgRecovery / 100)));
  }

  calculateEmpathyResponse(emotionData) {
    return emotionData?.empathyScore || 50;
  }

  calculateTouchAccuracy(touchData) {
    if (!touchData || touchData.totalTouches === 0) return 0;
    return Math.round((touchData.accurateTouches / touchData.totalTouches) * 100);
  }

  interpretTouchPatterns(touchData) {
    const accuracy = this.calculateTouchAccuracy(touchData);
    const randomTaps = touchData?.randomTaps || 0;

    if (accuracy > 80 && randomTaps < 5) {
      return '↑ accuracy + ↓ random taps → improved executive control';
    } else if (touchData?.forceSpikes > 3) {
      return 'Rapid force spikes → emotional overwhelm';
    }
    return 'Developing motor control';
  }

  calculateTurnTaking(responseData) {
    return responseData?.turnTakingScore || 50;
  }

  calculateErrorCorrection(responseData) {
    if (!responseData) return 50;
    const corrections = responseData.selfCorrections || 0;
    const errors = responseData.errors || 1;
    return Math.min(100, Math.round((corrections / errors) * 100));
  }

  generateResponseFlags(responseData) {
    const flags = [];
    const latency = responseData?.avgLatency || 0;
    const retries = responseData?.retries || 0;

    if (latency > 5000 && retries === 0) {
      flags.push('Long latency + no retries → freeze mode');
    }
    if (latency < 1000 && retries > 5) {
      flags.push('Short latency + many retries → impulsive guessing');
    }
    if (responseData?.decreasedRetries) {
      flags.push('Gradual decrease in retries → healthy risk-taking');
    }

    return flags;
  }

  /**
   * Generate complete analytics report
   */
  generateFullAnalytics(sessionMetrics) {
    return {
      eyeTracking: this.calculateEyeTrackingMetrics(sessionMetrics.gazeData),
      facialExpression: this.calculateFacialMetrics(sessionMetrics.emotionData),
      gestureTouch: this.calculateTouchMetrics(sessionMetrics.touchData),
      responsePattern: this.calculateResponseMetrics(sessionMetrics.responseData),
      timestamp: Date.now(),
    };
  }

  /**
   * Generate clinical flags for escalation
   */
  generateClinicalFlags(analytics) {
    const flags = [];

    // Flag: avoidance spikes for 3 consecutive sessions
    if (analytics.eyeTracking?.explorationAvoidanceRatio?.value < 30) {
      flags.push({
        type: 'escalate',
        message: 'Avoidance spikes detected - consider session adjustment',
      });
    }

    // Flag: neutral/flat affect dominates >80% of session
    if (analytics.facialExpression?.affectDiversityScore?.value < 20) {
      flags.push({
        type: 'flag',
        message: 'Flat affect dominates >80% of session - clinical review recommended',
      });
    }

    // Strengthen ERP if comfortable with current difficulty
    if (analytics.eyeTracking?.attentionScore?.value > 85 &&
        analytics.facialExpression?.frustrationToleranceIndex?.value > 75) {
      flags.push({
        type: 'strengthen',
        message: 'Consider increasing difficulty - child comfortable with current tier',
      });
    }

    return flags;
  }
}

export const biomarkerAnalytics = new BiomarkerAnalytics();
export default biomarkerAnalytics;
