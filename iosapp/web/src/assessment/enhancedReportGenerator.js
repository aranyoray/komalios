/**
 * Enhanced Report Generator with Subdomain Framework
 * Creates concise daily and extended monthly reports
 * Integrates ChatGPT for intelligent highlights
 */

import { computeSubdomainScores, calculateGeneralizationScore, calculateUnderstandingScore } from './subdomainMetrics';
import { generateConciseHighlights, generateSubdomainInsights } from '../services/aiInsightsService';

class EnhancedReportGenerator {
  /**
   * Generate concise daily report
   * Shows 5 overall domain scores, dropdown graph, 2-3 highlights
   */
  async generateConciseReport(sessionData, learnerProfile) {
    // Compute all subdomain scores
    const domainScores = computeSubdomainScores(sessionData, learnerProfile.age);

    // Generate highlights using ChatGPT
    const highlights = await generateConciseHighlights(sessionData, domainScores);

    // Format for display
    const report = {
      type: 'concise',
      sessionId: sessionData.id,
      learnerId: learnerProfile.id,
      learnerName: learnerProfile.name,
      age: learnerProfile.age,
      date: new Date(sessionData.startTime),
      duration: sessionData.duration,

      // Summary
      summary: {
        tasksCompleted: sessionData.tasksCompleted,
        tasksTotal: sessionData.tasksTotal,
        completionRate: (sessionData.tasksCompleted / Math.max(1, sessionData.tasksTotal) * 100).toFixed(0)
      },

      // 5 Main Domains with Overall Scores
      domains: [
        {
          id: 'social_communication',
          name: domainScores.social_communication.name,
          score: domainScores.social_communication.overallScore,
          color: domainScores.social_communication.color,
          strengthFlag: this.getStrengthFlag(domainScores.social_communication.overallScore)
        },
        {
          id: 'emotional_intelligence',
          name: domainScores.emotional_intelligence.name,
          score: domainScores.emotional_intelligence.overallScore,
          color: domainScores.emotional_intelligence.color,
          strengthFlag: this.getStrengthFlag(domainScores.emotional_intelligence.overallScore)
        },
        {
          id: 'cognitive_development',
          name: domainScores.cognitive_development.name,
          score: domainScores.cognitive_development.overallScore,
          color: domainScores.cognitive_development.color,
          strengthFlag: this.getStrengthFlag(domainScores.cognitive_development.overallScore)
        },
        {
          id: 'life_skills',
          name: domainScores.life_skills.name,
          score: domainScores.life_skills.overallScore,
          color: domainScores.life_skills.color,
          strengthFlag: this.getStrengthFlag(domainScores.life_skills.overallScore)
        },
        {
          id: 'language_sel',
          name: domainScores.language_sel.name,
          score: domainScores.language_sel.overallScore,
          color: domainScores.language_sel.color,
          strengthFlag: this.getStrengthFlag(domainScores.language_sel.overallScore)
        }
      ],

      // Key Highlights (2-3 bullets from ChatGPT)
      highlights: highlights || [],

      // Graph Data (for dropdown visualization)
      graphData: {
        labels: [
          'Social Communication',
          'Emotional Intelligence',
          'Cognitive Development',
          'Life Skills',
          'Language Development'
        ],
        scores: [
          domainScores.social_communication.overallScore,
          domainScores.emotional_intelligence.overallScore,
          domainScores.cognitive_development.overallScore,
          domainScores.life_skills.overallScore,
          domainScores.language_sel.overallScore
        ],
        colors: [
          domainScores.social_communication.color,
          domainScores.emotional_intelligence.color,
          domainScores.cognitive_development.color,
          domainScores.life_skills.color,
          domainScores.language_sel.color
        ]
      },

      // Focus Areas (top 2 strengths, top 2 priorities)
      focusAreas: this.identifyFocusAreas(domainScores),

      // Raw domain data for future analysis
      rawDomainScores: domainScores
    };

    return report;
  }

  /**
   * Generate extended monthly report
   * Accordion format with graphs per subdomain, detailed analytics
   */
  async generateExtendedReport(sessionData, learnerProfile, historicalData = {}) {
    // Compute all subdomain scores
    const domainScores = computeSubdomainScores(sessionData, learnerProfile.age);

    // Calculate generalization and understanding scores for each subdomain
    const enrichedDomains = {};

    for (const [domainId, domain] of Object.entries(domainScores)) {
      enrichedDomains[domainId] = {
        ...domain,
        subdomains: {}
      };

      for (const [subdomainId, subdomain] of Object.entries(domain.subdomains)) {
        const subdomainHistory = historicalData[subdomainId] || [];

        const generalization = calculateGeneralizationScore(subdomainHistory);
        const understanding = calculateUnderstandingScore(subdomainHistory);

        // Generate AI insights for this subdomain
        const insights = await generateSubdomainInsights(subdomain, subdomainHistory);

        enrichedDomains[domainId].subdomains[subdomainId] = {
          ...subdomain,
          generalizationScore: generalization.score,
          generalizationConfidence: generalization.confidence,
          understandingScore: understanding.score,
          understandingTrend: understanding.trend,
          sessionsContributed: subdomainHistory.length,
          scoreTrend: this.calculateScoreTrend(subdomainHistory),
          insights,
          graphData: this.prepareSubdomainGraphData(subdomain, subdomainHistory)
        };
      }
    }

    // Overall report structure
    const report = {
      type: 'extended',
      sessionId: sessionData.id,
      learnerId: learnerProfile.id,
      learnerName: learnerProfile.name,
      age: learnerProfile.age,
      dateOfBirth: learnerProfile.dateOfBirth,
      reportDate: new Date(),
      sessionDate: new Date(sessionData.startTime),

      // All domains with full subdomain breakdown
      domains: enrichedDomains,

      // Monthly summary (first week vs last week comparison)
      monthlySummary: this.generateMonthlySummary(enrichedDomains, historicalData),

      // Heatmap data (subdomains × weeks)
      heatmapData: this.generateHeatmapData(historicalData),

      // Narrative summary per domain (auto-generated)
      narrativeSummaries: await this.generateNarrativeSummaries(enrichedDomains),

      // Correlation insights
      correlationInsights: sessionData.correlations
        ? this.analyzeCorrelations(sessionData.correlations)
        : null
    };

    return report;
  }

  /**
   * Determine strength flag based on score
   */
  getStrengthFlag(score) {
    if (score >= 75) return { level: 'strong', color: 'green', label: 'Strong' };
    if (score >= 40) return { level: 'developing', color: 'amber', label: 'Developing' };
    return { level: 'priority', color: 'red', label: 'Priority' };
  }

  /**
   * Identify top strengths and priority areas
   */
  identifyFocusAreas(domainScores) {
    const domains = Object.values(domainScores).map(d => ({
      name: d.name,
      score: d.overallScore
    }));

    domains.sort((a, b) => b.score - a.score);

    return {
      strengths: domains.slice(0, 2).map(d => d.name),
      priorities: domains.slice(-2).reverse().map(d => d.name)
    };
  }

  /**
   * Calculate score trend from historical data
   */
  calculateScoreTrend(historicalScores) {
    if (!historicalScores || historicalScores.length < 2) {
      return { direction: 'stable', change: 0 };
    }

    const firstScore = historicalScores[0];
    const lastScore = historicalScores[historicalScores.length - 1];
    const change = lastScore - firstScore;

    let direction = 'stable';
    if (change > 5) direction = 'improving';
    else if (change < -5) direction = 'declining';

    return { direction, change };
  }

  /**
   * Prepare graph data for subdomain
   */
  prepareSubdomainGraphData(subdomain, historicalScores) {
    if (!historicalScores || historicalScores.length === 0) {
      return { available: false };
    }

    return {
      available: true,
      labels: historicalScores.map((_, i) => `Session ${i + 1}`),
      data: historicalScores,
      currentScore: subdomain.score,
      targetScore: 70
    };
  }

  /**
   * Generate monthly summary
   */
  generateMonthlySummary(enrichedDomains, historicalData) {
    // Compare first week vs last week
    // This would need week-based historical data structure
    return {
      overallProgress: 'improving', // Placeholder
      domainsImproved: [],
      domainsStable: [],
      domainsDeclining: []
    };
  }

  /**
   * Generate heatmap data (subdomains × weeks)
   */
  generateHeatmapData(historicalData) {
    // This would create a matrix of subdomain scores across weeks
    return {
      available: false,
      rows: [], // subdomain names
      columns: [], // week labels
      data: [] // score matrix
    };
  }

  /**
   * Generate narrative summaries using ChatGPT
   */
  async generateNarrativeSummaries(enrichedDomains) {
    const narratives = {};

    // For now, create simple narratives
    // In production, this would call ChatGPT for each domain
    for (const [domainId, domain] of Object.entries(enrichedDomains)) {
      const avgScore = domain.overallScore;

      let narrative = `${domain.name}: `;
      if (avgScore >= 75) {
        narrative += 'This is a strong area showing consistent skill development. ';
      } else if (avgScore >= 50) {
        narrative += 'This area is progressing well with room for continued growth. ';
      } else {
        narrative += 'This area would benefit from focused support and practice. ';
      }

      // Add subdomain specifics
      const topSubdomain = Object.values(domain.subdomains).reduce((max, s) =>
        s.score > max.score ? s : max
      );
      narrative += `Particularly strong in ${topSubdomain.name}.`;

      narratives[domainId] = narrative;
    }

    return narratives;
  }

  /**
   * Analyze correlations
   */
  analyzeCorrelations(correlations) {
    if (!correlations?.patternSummary) {
      return { available: false };
    }

    return {
      available: true,
      insights: correlations.patternSummary.insights || [],
      totalPatterns: correlations.patternSummary.totalPatterns || 0,
      highlights: this.extractCorrelationHighlights(correlations)
    };
  }

  /**
   * Extract correlation highlights
   */
  extractCorrelationHighlights(correlations) {
    const highlights = [];

    if (correlations.patterns?.eyeTouch && correlations.patterns.eyeTouch.length > 3) {
      highlights.push({
        category: 'Eye-Hand Coordination',
        observation: `Demonstrated look-before-tap pattern ${correlations.patterns.eyeTouch.length} times`,
        quality: 'Positive'
      });
    }

    if (correlations.patterns?.socialEngagement && correlations.patterns.socialEngagement.length > 2) {
      highlights.push({
        category: 'Social Engagement',
        observation: `Combined gaze and vocalization during social interactions`,
        quality: 'Strong'
      });
    }

    return highlights;
  }
}

export const enhancedReportGenerator = new EnhancedReportGenerator();
export default enhancedReportGenerator;
