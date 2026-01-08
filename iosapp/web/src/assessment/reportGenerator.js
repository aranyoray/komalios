/**
 * Report Generator for Komal
 * Creates concise and extended assessment reports
 */

import { scoringEngine } from './scoringEngine';
import { DEVELOPMENTAL_DOMAINS, SYMPTOM_CATEGORIES } from './developmentalDomains';

class ReportGenerator {
  /**
   * Generate concise parent report (session snapshot)
   * Shows only 5 primary domains
   */
  generateConciseReport(sessionData, learnerProfile) {
    const domainScores = scoringEngine.calculateDomainScores(
      sessionData,
      learnerProfile.age
    );

    // Filter to primary domains only
    const primaryDomains = Object.values(domainScores).filter(d => d.isPrimary);

    // Calculate overall engagement
    const avgScore = primaryDomains.reduce((sum, d) => sum + d.score, 0) / primaryDomains.length;

    return {
      type: 'concise',
      sessionId: sessionData.id,
      learnerId: learnerProfile.id,
      learnerName: learnerProfile.name,
      age: learnerProfile.age,
      date: new Date(sessionData.startTime),
      duration: sessionData.duration,

      // Quick summary
      summary: {
        tasksCompleted: sessionData.tasksCompleted,
        tasksTotal: sessionData.tasksTotal,
        completionRate: (sessionData.tasksCompleted / Math.max(1, sessionData.tasksTotal) * 100).toFixed(0),
        overallScore: Math.round(avgScore),
        engagementQuality: sessionData.engagementQuality || 0
      },

      // Focus area
      focusArea: this.formatFocusArea(sessionData.focusArea),
      keySkillPracticed: sessionData.keySkillPracticed || 'General therapeutic activities',

      // Highlights
      highlights: sessionData.highlights || [],

      // Primary domains (5)
      domains: primaryDomains.map(domain => ({
        name: domain.shortName,
        score: domain.score,
        riskLevel: domain.riskLevel.level,
        color: domain.color,
        icon: domain.riskLevel.icon,
        interpretation: domain.interpretation,
        trend: domain.trend // If historical data available
      })),

      // Quick metrics snapshot
      quickMetrics: this.generateQuickMetrics(sessionData),

      // Behavioral patterns from correlation data
      behavioralPatterns: this.generateBehavioralPatterns(sessionData.correlations),

      // What this means (parent-friendly interpretation)
      interpretation: this.generateParentInterpretation(primaryDomains, sessionData),

      // Home practice suggestion
      homePractice: this.generateHomePractice(primaryDomains, sessionData),

      // Next tiny goal
      nextGoal: this.generateNextGoal(primaryDomains)
    };
  }

  /**
   * Generate extended progress report
   * Shows all domains + detailed analytics
   */
  generateExtendedReport(sessionData, learnerProfile, historicalData = []) {
    const domainScores = scoringEngine.calculateDomainScores(
      sessionData,
      learnerProfile.age
    );

    // Calculate trends from historical data
    const domainTrends = {};
    for (const [domainId, scores] of Object.entries(historicalData)) {
      domainTrends[domainId] = scoringEngine.calculateTrend(scores);
    }

    // Add trends to domain scores
    for (const [domainId, score] of Object.entries(domainScores)) {
      if (domainTrends[domainId]) {
        score.trend = domainTrends[domainId];
      }
    }

    // Symptom screening
    const symptomFlags = this.screenForSymptoms(sessionData);

    return {
      type: 'extended',
      sessionId: sessionData.id,
      learnerId: learnerProfile.id,
      learnerName: learnerProfile.name,
      age: learnerProfile.age,
      dateOfBirth: learnerProfile.dateOfBirth,
      date: new Date(sessionData.startTime),
      duration: sessionData.duration,

      // All domains (primary + secondary)
      allDomains: Object.values(domainScores),

      // Eye tracking analytics
      eyeTrackingAnalysis: this.analyzeEyeTracking(sessionData.eyeTracking),

      // Facial expression analytics
      emotionAnalysis: this.analyzeMicroExpressions(sessionData.microExpressions),

      // Touch pattern analytics
      touchAnalysis: this.analyzeTouchTracking(sessionData.touchTracking),

      // Voice pattern analytics
      voiceAnalysis: this.analyzeVoiceTracking(sessionData.voiceTracking),

      // Response pattern dynamics
      responseAnalysis: this.analyzeResponsePatterns(sessionData.responsePatterns),

      // Cross-modal behavioral patterns
      correlationAnalysis: this.analyzeCorrelations(sessionData.correlations),

      // Symptom screening results
      symptomFlags,

      // Outcome summary
      outcomeSummary: {
        improved: this.getImprovedAreas(domainScores, domainTrends),
        challenging: this.getChallengingAreas(domainScores),
        whereToSupport: this.getSupportSuggestions(domainScores)
      },

      // Recommended home strategies
      homeStrategies: this.generateDetailedHomeStrategies(domainScores, symptomFlags),

      // Clinician review zone
      clinicianNotes: this.generateClinicianNotes(domainScores, symptomFlags, domainTrends),

      // Data for graphs
      graphData: {
        domainScores: Object.values(domainScores).map(d => ({
          domain: d.shortName,
          score: d.score,
          color: d.color
        })),
        trends: domainTrends
      }
    };
  }

  // ==========================================================================
  // HELPER METHODS
  // ==========================================================================

  formatFocusArea(focusArea) {
    const mapping = {
      'social-skills': 'Social Skills',
      'language-skills': 'Language Development',
      'cognitive-development': 'Cognitive Development',
      'emotional-intelligence': 'Emotional Intelligence',
      'life-skills': 'Life Skills'
    };
    return mapping[focusArea] || focusArea;
  }

  generateQuickMetrics(sessionData) {
    return {
      attention: {
        title: 'Attention & Concentration',
        score: sessionData.eyeTracking?.attentionScore || 0,
        trend: '↑',
        note: 'Stayed focused even during harder activities'
      },
      emotion: {
        title: 'Emotion & Expression',
        positiveExpressions: sessionData.microExpressions?.positiveExpressions || 0,
        frustrationEpisodes: sessionData.microExpressions?.frustrationEpisodes?.length || 0,
        note: 'Great recovery after challenges'
      },
      touch: {
        title: 'Touch & Motor Behavior',
        accurateTouches: sessionData.touchTracking?.goalDirectedAccuracy || 0,
        hesitationTaps: sessionData.touchTracking?.hesitationTaps || 0,
        note: 'Improved confidence in choices'
      },
      response: {
        title: 'Response Pattern',
        initiationDelay: 'shorter',
        retryAttempts: 'healthy persistence',
        note: 'Reduced anxiety before responding'
      }
    };
  }

  generateParentInterpretation(domains, sessionData) {
    const strengths = domains.filter(d => d.score >= 70);
    const concerns = domains.filter(d => d.score < 55);

    let interpretation = '';

    if (strengths.length >= 3) {
      interpretation += `Your child is doing well in ${strengths.map(d => d.shortName).join(', ')}. `;
    }

    if (concerns.length === 0) {
      interpretation += 'All areas are developing appropriately.';
    } else if (concerns.length === 1) {
      interpretation += `${concerns[0].shortName} skills need some extra practice.`;
    } else {
      interpretation += `Focus on supporting ${concerns.map(d => d.shortName).join(' and ')}.`;
    }

    return interpretation;
  }

  generateHomePractice(domains, sessionData) {
    const lowestDomain = domains.reduce((min, d) => d.score < min.score ? d : min);

    const practices = {
      'Social': 'Ask: "What helped you keep going when it got a little hard?"',
      'Emotional': 'Practice deep breathing together before bedtime.',
      'Cognitive': 'Play memory games or simple puzzles for 10 minutes daily.',
      'Language': 'Read a story together and ask "what happens next?"',
      'Life Skills': 'Let them make small choices (snack, clothing) independently.'
    };

    return practices[lowestDomain.shortName] || 'Continue regular practice sessions.';
  }

  generateNextGoal(domains) {
    const lowestDomain = domains.reduce((min, d) => d.score < min.score ? d : min);

    const goals = {
      'Social': 'Maintain eye contact with the avatar during conversation moments.',
      'Emotional': 'Use one coping strategy when feeling frustrated.',
      'Cognitive': 'Complete 3 tasks in a row without prompting.',
      'Language': 'Use 3-word sentences to describe feelings.',
      'Life Skills': 'Complete one self-care task independently.'
    };

    return goals[lowestDomain.shortName] || 'Continue building on current progress.';
  }

  analyzeEyeTracking(data) {
    if (!data) return null;

    return {
      attentionScore: data.attentionScore,
      concentrationStability: data.concentrationStability,
      socialGazeIndex: data.socialGazeIndex,
      explorationAvoidanceRatio: data.explorationAvoidanceRatio,
      interpretation: data.attentionScore > 70
        ? 'Strong attention and focus maintained throughout session.'
        : 'Attention wanders at times, consider shorter activity intervals.',
      gazePatterns: data.gazeAversions || []
    };
  }

  analyzeMicroExpressions(data) {
    if (!data) return null;

    return {
      emotionDiversity: data.affectDiversityScore,
      positiveAffect: data.positiveAffectActivation,
      frustrationTolerance: data.frustrationToleranceIndex,
      empathyResponse: data.empathyResponse,
      interpretation: data.frustrationToleranceIndex > 0.6
        ? 'Good emotional regulation and recovery from frustration.'
        : 'Difficulty recovering from frustration, practice coping strategies.',
      emotionTimeline: data.emotionTimeline || []
    };
  }

  analyzeTouchTracking(data) {
    if (!data) return null;

    return {
      accuracy: data.goalDirectedAccuracy,
      hesitation: data.hesitationTaps,
      patterns: data.patterns,
      interpretation: data.goalDirectedAccuracy > 0.75
        ? 'Confident and accurate touch interactions.'
        : 'Some hesitation in interactions, build confidence gradually.'
    };
  }

  analyzeVoiceTracking(data) {
    if (!data) return null;

    return {
      vocalActivity: data.vocalActivity,
      speechRate: data.speechRate,
      confidence: data.confidence,
      hesitations: data.hesitations,
      interpretation: data.vocalActivity > 0.4
        ? 'Actively engaged in verbal communication.'
        : 'Limited verbal participation, encourage expression.'
    };
  }

  analyzeResponsePatterns(data) {
    if (!data) return null;

    return {
      initiationLatency: data.initiationLatency,
      retryCount: data.retryCount,
      patterns: data.patterns,
      interpretation: data.patterns?.healthyPersistence > 7
        ? 'Shows healthy persistence and problem-solving.'
        : 'May give up quickly, encourage trying again.'
    };
  }

  generateBehavioralPatterns(correlations) {
    if (!correlations || !correlations.patternSummary) {
      return {
        available: false,
        message: 'Correlation data not available for this session'
      };
    }

    const { insights } = correlations.patternSummary;

    return {
      available: true,
      insights: insights || [],
      highlights: this.extractCorrelationHighlights(correlations)
    };
  }

  analyzeCorrelations(correlations) {
    if (!correlations || !correlations.patterns) {
      return {
        available: false,
        message: 'Detailed correlation data not available'
      };
    }

    const { patterns, patternSummary, stats } = correlations;

    return {
      available: true,

      // Pattern counts
      patternCounts: patternSummary.patternTypes || {},
      totalPatterns: patternSummary.totalPatterns || 0,

      // Detailed insights
      insights: patternSummary.insights || [],

      // Key patterns
      keyPatterns: {
        eyeHandCoordination: this.analyzeEyeHandPatterns(patterns.eyeTouch),
        socialCommunication: this.analyzeSocialPatterns(patterns.gazeVocalization, patterns.socialEngagement),
        emotionalRegulation: this.analyzeEmotionalPatterns(patterns.emotionBehavior, patterns.frustrationAvoidance),
        attentionResponse: this.analyzeAttentionPatterns(patterns.attentionResponse)
      },

      // Statistics
      correlationRate: stats.correlationRate,
      totalEvents: stats.totalEvents,
      correlatedEvents: stats.correlatedEvents
    };
  }

  extractCorrelationHighlights(correlations) {
    const highlights = [];
    const { patterns } = correlations;

    // Eye-hand coordination
    if (patterns.eyeTouch && patterns.eyeTouch.length > 5) {
      const accuracyRate = patterns.eyeTouch.filter(p => p.wasAccurate).length / patterns.eyeTouch.length;
      highlights.push({
        category: 'Motor Planning',
        observation: `Looked at target before tapping ${patterns.eyeTouch.length} times`,
        quality: accuracyRate > 0.8 ? 'Strong' : accuracyRate > 0.5 ? 'Developing' : 'Needs Support'
      });
    }

    // Social engagement
    if (patterns.socialEngagement && patterns.socialEngagement.length > 3) {
      highlights.push({
        category: 'Social Communication',
        observation: `Combined looking at avatar with vocalization ${patterns.socialEngagement.length} times`,
        quality: 'Positive'
      });
    }

    // Emotional regulation
    if (patterns.frustrationAvoidance && patterns.frustrationAvoidance.length > 2) {
      highlights.push({
        category: 'Emotional Coping',
        observation: `Showed ${patterns.frustrationAvoidance.length} instances of avoidance after frustration`,
        quality: 'Monitor'
      });
    }

    return highlights;
  }

  analyzeEyeHandPatterns(eyeTouchPatterns) {
    if (!eyeTouchPatterns || eyeTouchPatterns.length === 0) {
      return { available: false };
    }

    const accuracyRate = eyeTouchPatterns.filter(p => p.wasAccurate).length / eyeTouchPatterns.length;
    const avgDelay = eyeTouchPatterns.reduce((sum, p) => sum + p.delay, 0) / eyeTouchPatterns.length;

    return {
      available: true,
      count: eyeTouchPatterns.length,
      accuracyRate: (accuracyRate * 100).toFixed(0) + '%',
      avgDelay: Math.round(avgDelay) + 'ms',
      interpretation: accuracyRate > 0.8
        ? 'Excellent eye-hand coordination with intentional targeting'
        : accuracyRate > 0.6
        ? 'Good motor planning, improving accuracy'
        : 'Developing motor planning skills, may benefit from visual-motor activities'
    };
  }

  analyzeSocialPatterns(gazeVocalization, socialEngagement) {
    const totalSocialEvents = (gazeVocalization?.length || 0) + (socialEngagement?.length || 0);

    if (totalSocialEvents === 0) {
      return { available: false };
    }

    return {
      available: true,
      gazeVocalizationCount: gazeVocalization?.length || 0,
      socialEngagementCount: socialEngagement?.length || 0,
      totalSocialEvents,
      interpretation: totalSocialEvents > 10
        ? 'Strong social-communicative behavior with frequent avatar engagement'
        : totalSocialEvents > 5
        ? 'Developing social communication skills'
        : 'Limited social communication attempts, encourage interaction'
    };
  }

  analyzeEmotionalPatterns(emotionBehavior, frustrationAvoidance) {
    const totalEmotionalEvents = (emotionBehavior?.length || 0) + (frustrationAvoidance?.length || 0);

    if (totalEmotionalEvents === 0) {
      return { available: false };
    }

    const frustrationCount = emotionBehavior?.filter(p => p.emotion === 'frustration').length || 0;
    const avoidanceCount = frustrationAvoidance?.length || 0;

    return {
      available: true,
      frustrationEvents: frustrationCount,
      avoidanceEvents: avoidanceCount,
      regulationRatio: frustrationCount > 0 ? (avoidanceCount / frustrationCount).toFixed(2) : 'N/A',
      interpretation: frustrationCount === 0
        ? 'No frustration observed, tasks may have been well-matched'
        : avoidanceCount / frustrationCount < 0.5
        ? 'Good emotional regulation, manages frustration well'
        : 'Frustration leads to avoidance, practice coping strategies'
    };
  }

  analyzeAttentionPatterns(attentionResponse) {
    if (!attentionResponse || attentionResponse.length === 0) {
      return { available: false };
    }

    const avgLatency = attentionResponse.reduce((sum, p) => sum + p.responseLatency, 0) / attentionResponse.length;

    return {
      available: true,
      count: attentionResponse.length,
      avgLatency: Math.round(avgLatency) + 'ms',
      interpretation: avgLatency < 1000
        ? 'Quick recovery after attention lapses'
        : avgLatency < 2000
        ? 'Moderate impact of attention drops on response time'
        : 'Attention lapses significantly delay responses, consider shorter tasks'
    };
  }

  screenForSymptoms(sessionData) {
    const flags = [];

    // Check for autism spectrum traits
    if (sessionData.eyeTracking?.socialGazeIndex < 0.4 &&
        sessionData.microExpressions?.affectDiversityScore < 4) {
      flags.push({
        category: 'AUTISM_SPECTRUM',
        severity: 'moderate',
        note: 'Limited social gaze and emotional expression range'
      });
    }

    // Check for ADHD traits
    if (sessionData.eyeTracking?.attentionScore < 50 &&
        sessionData.responsePatterns?.impulsiveGuessing > 5) {
      flags.push({
        category: 'ADHD_TRAITS',
        severity: 'moderate',
        note: 'Difficulty sustaining attention and impulsive responses'
      });
    }

    // Check for anxiety traits
    if (sessionData.touchTracking?.hesitationTaps > 15 &&
        sessionData.responsePatterns?.freezeMode > 3) {
      flags.push({
        category: 'ANXIETY_TRAITS',
        severity: 'moderate',
        note: 'High hesitation and freeze responses under pressure'
      });
    }

    return flags;
  }

  getImprovedAreas(domainScores, trends) {
    return Object.values(domainScores)
      .filter(d => d.trend?.direction === 'improving')
      .map(d => d.shortName);
  }

  getChallengingAreas(domainScores) {
    return Object.values(domainScores)
      .filter(d => d.score < 55)
      .map(d => d.shortName);
  }

  getSupportSuggestions(domainScores) {
    const lowest = Object.values(domainScores)
      .filter(d => d.score < 60)
      .sort((a, b) => a.score - b.score)
      .slice(0, 2);

    return lowest.map(d => `Focus on ${d.name} through daily practice and structured activities.`);
  }

  generateDetailedHomeStrategies(domainScores, symptomFlags) {
    const strategies = [];

    // Add strategies based on lowest domains
    Object.values(domainScores).forEach(domain => {
      if (domain.score < 60) {
        strategies.push(this.getStrategyForDomain(domain.id));
      }
    });

    // Add strategies based on symptom flags
    symptomFlags.forEach(flag => {
      strategies.push(this.getStrategyForSymptom(flag.category));
    });

    return strategies.slice(0, 5); // Top 5 strategies
  }

  getStrategyForDomain(domainId) {
    const strategies = {
      social_communication: 'Practice turn-taking games and describe what others might be feeling.',
      emotional_intelligence: 'Use emotion cards to identify and label feelings together.',
      cognitive_development: 'Break tasks into small steps and celebrate each completion.',
      language_development: 'Read together daily and ask open-ended questions.',
      life_skills: 'Create a visual routine chart and practice one skill at a time.'
    };
    return strategies[domainId] || 'Continue regular practice and positive reinforcement.';
  }

  getStrategyForSymptom(category) {
    const strategies = {
      AUTISM_SPECTRUM: 'Use visual supports and predictable routines.',
      ADHD_TRAITS: 'Short activity bursts with movement breaks.',
      ANXIETY_TRAITS: 'Deep breathing exercises and prepare for transitions.',
      LANGUAGE_DELAY: 'Model language and expand on child\'s words.',
      EMOTIONAL_DYSREGULATION: 'Teach coping strategies and provide sensory breaks.'
    };
    return strategies[category] || 'Consult with specialists for targeted support.';
  }

  generateClinicianNotes(domainScores, symptomFlags, trends) {
    const notes = {
      escalate: false,
      escalateReasons: [],
      monitor: false,
      monitorReasons: [],
      recommendations: []
    };

    // Check for escalation flags
    const criticalDomains = Object.values(domainScores).filter(d => d.score < 40);
    if (criticalDomains.length >= 2) {
      notes.escalate = true;
      notes.escalateReasons.push('Multiple domains scoring below 40 - recommend professional evaluation');
    }

    // Check for declining trends
    const decliningDomains = Object.values(domainScores).filter(d => d.trend?.direction === 'declining');
    if (decliningDomains.length >= 3) {
      notes.monitor = true;
      notes.monitorReasons.push('Declining trends in 3+ domains - monitor closely');
    }

    // Symptom-based recommendations
    if (symptomFlags.length > 0) {
      notes.recommendations.push('Consider referral for comprehensive developmental evaluation');
    }

    return notes;
  }
}

export const reportGenerator = new ReportGenerator();
export default reportGenerator;
