/**
 * Harvard SEL Framework Scoring System
 * 5 Core Competencies for Social-Emotional Learning
 */

export const SEL_DOMAINS = {
  SELF_AWARENESS: {
    id: 'self-awareness',
    name: 'Self-Awareness',
    description: 'Labeling feelings, noticing triggers',
    subdomains: [
      { id: 'emotion-recognition', name: 'Emotion Recognition', weight: 0.3 },
      { id: 'self-perception', name: 'Self-Perception', weight: 0.25 },
      { id: 'strength-identification', name: 'Strength Identification', weight: 0.25 },
      { id: 'trigger-awareness', name: 'Trigger Awareness', weight: 0.2 },
    ],
  },
  SELF_MANAGEMENT: {
    id: 'self-management',
    name: 'Self-Management',
    description: 'Using coping tools (breathing, pauses)',
    subdomains: [
      { id: 'impulse-control', name: 'Impulse Control', weight: 0.25 },
      { id: 'stress-management', name: 'Stress Management', weight: 0.25 },
      { id: 'goal-setting', name: 'Goal Setting', weight: 0.2 },
      { id: 'organization', name: 'Organization', weight: 0.15 },
      { id: 'motivation', name: 'Motivation', weight: 0.15 },
    ],
  },
  SOCIAL_AWARENESS: {
    id: 'social-awareness',
    name: 'Social Awareness',
    description: 'Recognizing avatar emotions/cues',
    subdomains: [
      { id: 'perspective-taking', name: 'Perspective Taking', weight: 0.3 },
      { id: 'empathy', name: 'Empathy', weight: 0.3 },
      { id: 'social-cue-reading', name: 'Social Cue Reading', weight: 0.25 },
      { id: 'respect-diversity', name: 'Respect for Diversity', weight: 0.15 },
    ],
  },
  RELATIONSHIP_SKILLS: {
    id: 'relationship-skills',
    name: 'Relationship Skills',
    description: 'Repair after mistakes, positive engagement',
    subdomains: [
      { id: 'communication', name: 'Communication', weight: 0.25 },
      { id: 'cooperation', name: 'Cooperation', weight: 0.2 },
      { id: 'conflict-resolution', name: 'Conflict Resolution', weight: 0.25 },
      { id: 'help-seeking', name: 'Help Seeking', weight: 0.15 },
      { id: 'relationship-building', name: 'Relationship Building', weight: 0.15 },
    ],
  },
  RESPONSIBLE_DECISION_MAKING: {
    id: 'responsible-decision-making',
    name: 'Responsible Decision-Making',
    description: 'Better choices under uncertainty',
    subdomains: [
      { id: 'problem-identification', name: 'Problem Identification', weight: 0.2 },
      { id: 'situation-analysis', name: 'Situation Analysis', weight: 0.25 },
      { id: 'consequence-evaluation', name: 'Consequence Evaluation', weight: 0.25 },
      { id: 'ethical-responsibility', name: 'Ethical Responsibility', weight: 0.15 },
      { id: 'reflection', name: 'Reflection', weight: 0.15 },
    ],
  },
};

class SELFramework {
  constructor() {
    this.domains = SEL_DOMAINS;
  }

  /**
   * Calculate domain scores from session metrics
   */
  calculateDomainScores(sessionMetrics) {
    const scores = {};

    // Self-Awareness: emotion recognition, triggers
    scores['self-awareness'] = this.calculateSelfAwareness(sessionMetrics);

    // Self-Management: impulse control, stress management
    scores['self-management'] = this.calculateSelfManagement(sessionMetrics);

    // Social Awareness: empathy, social cues
    scores['social-awareness'] = this.calculateSocialAwareness(sessionMetrics);

    // Relationship Skills: communication, cooperation
    scores['relationship-skills'] = this.calculateRelationshipSkills(sessionMetrics);

    // Responsible Decision-Making: choices, consequences
    scores['responsible-decision-making'] = this.calculateDecisionMaking(sessionMetrics);

    return scores;
  }

  calculateSelfAwareness(metrics) {
    const subdomains = {};

    // Emotion Recognition: from facial expression accuracy
    subdomains['emotion-recognition'] = {
      score: metrics.emotionRecognitionAccuracy || metrics.affectDiversity || 60,
      trend: this.calculateTrend(metrics.history?.emotionRecognition),
    };

    // Self-Perception: from confidence indicators
    subdomains['self-perception'] = {
      score: 100 - (metrics.hesitationTaps || 0) * 2,
      trend: this.calculateTrend(metrics.history?.selfPerception),
    };

    // Strength Identification: from success responses
    subdomains['strength-identification'] = {
      score: metrics.positiveAffectActivation || 65,
      trend: this.calculateTrend(metrics.history?.strengthId),
    };

    // Trigger Awareness: from recovery patterns
    subdomains['trigger-awareness'] = {
      score: metrics.triggerAwareness || 55,
      trend: this.calculateTrend(metrics.history?.triggerAwareness),
    };

    return {
      subdomains,
      overall: this.calculateWeightedScore(subdomains, SEL_DOMAINS.SELF_AWARENESS.subdomains),
      trend: this.getOverallTrend(subdomains),
    };
  }

  calculateSelfManagement(metrics) {
    const subdomains = {};

    // Impulse Control: from response latency and accuracy
    subdomains['impulse-control'] = {
      score: metrics.impulseControl || (100 - metrics.impulsiveResponses * 5) || 60,
      trend: this.calculateTrend(metrics.history?.impulseControl),
    };

    // Stress Management: from frustration tolerance
    subdomains['stress-management'] = {
      score: metrics.frustrationToleranceIndex || 65,
      trend: this.calculateTrend(metrics.history?.stressManagement),
    };

    // Goal Setting: from task completion patterns
    subdomains['goal-setting'] = {
      score: metrics.completionRate || 70,
      trend: this.calculateTrend(metrics.history?.goalSetting),
    };

    // Organization: from sequential task performance
    subdomains['organization'] = {
      score: metrics.organizationScore || 60,
      trend: this.calculateTrend(metrics.history?.organization),
    };

    // Motivation: from retry attempts and persistence
    subdomains['motivation'] = {
      score: metrics.persistenceScore || Math.min(100, metrics.retryCount * 10 + 50),
      trend: this.calculateTrend(metrics.history?.motivation),
    };

    return {
      subdomains,
      overall: this.calculateWeightedScore(subdomains, SEL_DOMAINS.SELF_MANAGEMENT.subdomains),
      trend: this.getOverallTrend(subdomains),
    };
  }

  calculateSocialAwareness(metrics) {
    const subdomains = {};

    // Perspective Taking: from avatar interaction
    subdomains['perspective-taking'] = {
      score: metrics.perspectiveTaking || 60,
      trend: this.calculateTrend(metrics.history?.perspectiveTaking),
    };

    // Empathy: from empathy response metrics
    subdomains['empathy'] = {
      score: metrics.empathyResponse || 55,
      trend: this.calculateTrend(metrics.history?.empathy),
    };

    // Social Cue Reading: from social gaze index
    subdomains['social-cue-reading'] = {
      score: metrics.socialGazeIndex || 65,
      trend: this.calculateTrend(metrics.history?.socialCueReading),
    };

    // Respect for Diversity
    subdomains['respect-diversity'] = {
      score: metrics.diversityRespect || 70,
      trend: this.calculateTrend(metrics.history?.diversityRespect),
    };

    return {
      subdomains,
      overall: this.calculateWeightedScore(subdomains, SEL_DOMAINS.SOCIAL_AWARENESS.subdomains),
      trend: this.getOverallTrend(subdomains),
    };
  }

  calculateRelationshipSkills(metrics) {
    const subdomains = {};

    // Communication: from turn-taking score
    subdomains['communication'] = {
      score: metrics.turnTakingScore || 60,
      trend: this.calculateTrend(metrics.history?.communication),
    };

    // Cooperation: from collaborative task performance
    subdomains['cooperation'] = {
      score: metrics.cooperationScore || 65,
      trend: this.calculateTrend(metrics.history?.cooperation),
    };

    // Conflict Resolution: from error correction profile
    subdomains['conflict-resolution'] = {
      score: metrics.errorCorrectionScore || 55,
      trend: this.calculateTrend(metrics.history?.conflictResolution),
    };

    // Help Seeking
    subdomains['help-seeking'] = {
      score: metrics.helpSeekingScore || 50,
      trend: this.calculateTrend(metrics.history?.helpSeeking),
    };

    // Relationship Building: from social engagement
    subdomains['relationship-building'] = {
      score: metrics.socialEngagement || 60,
      trend: this.calculateTrend(metrics.history?.relationshipBuilding),
    };

    return {
      subdomains,
      overall: this.calculateWeightedScore(subdomains, SEL_DOMAINS.RELATIONSHIP_SKILLS.subdomains),
      trend: this.getOverallTrend(subdomains),
    };
  }

  calculateDecisionMaking(metrics) {
    const subdomains = {};

    // Problem Identification
    subdomains['problem-identification'] = {
      score: metrics.problemIdentification || 60,
      trend: this.calculateTrend(metrics.history?.problemId),
    };

    // Situation Analysis: from response patterns
    subdomains['situation-analysis'] = {
      score: 100 - (metrics.responseInitiationLatency || 30),
      trend: this.calculateTrend(metrics.history?.situationAnalysis),
    };

    // Consequence Evaluation
    subdomains['consequence-evaluation'] = {
      score: metrics.consequenceEvaluation || 55,
      trend: this.calculateTrend(metrics.history?.consequenceEval),
    };

    // Ethical Responsibility
    subdomains['ethical-responsibility'] = {
      score: metrics.ethicalResponsibility || 70,
      trend: this.calculateTrend(metrics.history?.ethicalResp),
    };

    // Reflection: from self-correction behaviors
    subdomains['reflection'] = {
      score: metrics.reflectionScore || 50,
      trend: this.calculateTrend(metrics.history?.reflection),
    };

    return {
      subdomains,
      overall: this.calculateWeightedScore(subdomains, SEL_DOMAINS.RESPONSIBLE_DECISION_MAKING.subdomains),
      trend: this.getOverallTrend(subdomains),
    };
  }

  calculateWeightedScore(subdomains, domainConfig) {
    let totalScore = 0;
    let totalWeight = 0;

    domainConfig.forEach(config => {
      const subdomain = subdomains[config.id];
      if (subdomain) {
        totalScore += subdomain.score * config.weight;
        totalWeight += config.weight;
      }
    });

    return totalWeight > 0 ? Math.round(totalScore / totalWeight) : 0;
  }

  calculateTrend(history) {
    if (!history || history.length < 2) return 'stable';

    const recent = history.slice(-3);
    const older = history.slice(-6, -3);

    if (recent.length === 0 || older.length === 0) return 'stable';

    const recentAvg = recent.reduce((a, b) => a + b, 0) / recent.length;
    const olderAvg = older.reduce((a, b) => a + b, 0) / older.length;

    const diff = recentAvg - olderAvg;
    if (diff > 5) return 'up';
    if (diff < -5) return 'down';
    return 'stable';
  }

  getOverallTrend(subdomains) {
    const trends = Object.values(subdomains).map(s => s.trend);
    const upCount = trends.filter(t => t === 'up').length;
    const downCount = trends.filter(t => t === 'down').length;

    if (upCount > downCount) return 'up';
    if (downCount > upCount) return 'down';
    return 'stable';
  }

  getTrendSymbol(trend) {
    switch (trend) {
      case 'up': return '↑';
      case 'down': return '↓';
      default: return '→';
    }
  }

  generateInterpretation(domainScores) {
    const interpretations = [];

    Object.entries(domainScores).forEach(([domainId, data]) => {
      const domain = Object.values(SEL_DOMAINS).find(d => d.id === domainId);
      if (!domain) return;

      let interpretation = '';
      if (data.overall >= 75) {
        interpretation = `Strong ${domain.name.toLowerCase()} skills demonstrated.`;
      } else if (data.overall >= 50) {
        interpretation = `Developing ${domain.name.toLowerCase()} with support.`;
      } else {
        interpretation = `${domain.name} needs focused attention.`;
      }

      interpretations.push({
        domain: domain.name,
        score: data.overall,
        trend: data.trend,
        interpretation,
      });
    });

    return interpretations;
  }
}

export const selFramework = new SELFramework();
export default selFramework;
