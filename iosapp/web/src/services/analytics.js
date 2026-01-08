/**
 * Analytics Service
 * Aggregates session data for reports and insights
 */

import { supabase } from './supabase';
import { format, subDays, subWeeks, subMonths, startOfDay, endOfDay, eachDayOfInterval } from 'date-fns';
import { geminiFlash } from './geminiService';

class AnalyticsService {
  constructor() {
    this.cache = new Map();
    this.cacheTimeout = 5 * 60 * 1000; // 5 minutes
  }

  // Save session metrics to database
  async saveSessionMetrics(learnerId, sessionData) {
    // Helper function to ensure integer values
    const toInt = (value) => {
      if (value === null || value === undefined) return null;
      const num = Number(value);
      return isNaN(num) ? null : Math.round(num);
    };

    const metrics = {
      learner_id: learnerId,
      session_id: sessionData.session_id || null,
      session_date: sessionData.session_date || new Date().toISOString(),
      duration_minutes: toInt(sessionData.duration_minutes || sessionData.duration),
      attention_score: toInt(sessionData.attention_score || sessionData.attentionScore),
      engagement_score: toInt(sessionData.engagement_score || sessionData.engagementScore),
      completion_rate: toInt(sessionData.completion_rate || sessionData.completionRate),
      blink_rate: sessionData.blink_rate || sessionData.blinkRate, // NUMERIC(5,2) - can be decimal
      emotion_data: sessionData.emotion_data || sessionData.emotionData || {},
      emotion_timeline: sessionData.emotion_timeline || [],
      gaze_heatmap: sessionData.gaze_heatmap || sessionData.gazeHeatmap || [],
      gaze_metrics: sessionData.gaze_metrics || {},
      activities_completed: toInt(sessionData.activities_completed || sessionData.activitiesCompleted || 0),
      focus_areas: sessionData.focus_areas || sessionData.focusAreas || [],
      difficulty_level: sessionData.difficulty_level || sessionData.difficultyLevel || 'adaptive',
      responses: sessionData.responses || [],
      biomarker_summary: sessionData.biomarker_summary || {},
      clinical_flags: sessionData.clinical_flags || [],
    };

    const { data, error } = await supabase
      .from('session_analytics')
      .insert(metrics)
      .select()
      .single();

    if (error) throw error;
    return data;
  }

  // Get analytics for different time periods
  async getAnalytics(learnerId, period = 'week', learnerProfile = null) {
    const cacheKey = `${learnerId}-${period}`;
    const cached = this.cache.get(cacheKey);

    if (cached && Date.now() - cached.timestamp < this.cacheTimeout) {
      return cached.data;
    }

    const endDate = new Date();
    let startDate;

    switch (period) {
      case 'session':
        startDate = startOfDay(endDate);
        break;
      case 'week':
        startDate = subWeeks(endDate, 1);
        break;
      case 'month':
        startDate = subMonths(endDate, 1);
        break;
      case '3months':
        startDate = subMonths(endDate, 3);
        break;
      default:
        startDate = subWeeks(endDate, 1);
    }

    const { data: sessions, error } = await supabase
      .from('session_analytics')
      .select('*')
      .eq('learner_id', learnerId)
      .gte('session_date', startDate.toISOString())
      .lte('session_date', endDate.toISOString())
      .order('session_date', { ascending: true });

    if (error) throw error;

    // Get learner profile if not provided
    let profile = learnerProfile;
    if (!profile) {
      try {
        const { data: learnerData } = await supabase
          .from('learners')
          .select('focus_areas, name')
          .eq('id', learnerId)
          .single();
        profile = learnerData;
      } catch (err) {
        console.warn('[Analytics] Could not fetch learner profile:', err);
      }
    }

    const analytics = await this.aggregateMetrics(sessions || [], period, startDate, endDate, profile);

    this.cache.set(cacheKey, {
      data: analytics,
      timestamp: Date.now(),
    });

    return analytics;
  }

  async aggregateMetrics(sessions, period, startDate, endDate, learnerProfile = null) {
    if (sessions.length === 0) {
      return this.getEmptyAnalytics(period);
    }

    // ... existing basic stats ...
    const totalSessions = sessions.length;
    const totalDuration = sessions.reduce((sum, s) => sum + (s.duration_minutes || 0), 0);
    const avgDuration = totalDuration / totalSessions;

    // Attention metrics
    const attentionScores = sessions.map(s => s.attention_score).filter(Boolean);
    const avgAttention = attentionScores.reduce((a, b) => a + b, 0) / attentionScores.length || 0;
    const attentionTrend = this.calculateTrend(attentionScores);

    // Engagement metrics
    const engagementScores = sessions.map(s => s.engagement_score).filter(Boolean);
    const avgEngagement = engagementScores.reduce((a, b) => a + b, 0) / engagementScores.length || 0;
    const engagementTrend = this.calculateTrend(engagementScores);

    // Completion rates
    const completionRates = sessions.map(s => s.completion_rate).filter(Boolean);
    const avgCompletion = completionRates.reduce((a, b) => a + b, 0) / completionRates.length || 0;

    // Emotion analysis
    const emotionData = this.aggregateEmotions(sessions);

    // Time series data for charts
    const timeSeriesData = this.generateTimeSeries(sessions, period, startDate, endDate);

    // Focus area progress - use learner's selected focus areas
    const focusAreaProgress = this.calculateFocusAreaProgress(sessions, learnerProfile);

    // Blink rate analysis
    const blinkRates = sessions.map(s => s.blink_rate).filter(Boolean);
    const avgBlinkRate = blinkRates.reduce((a, b) => a + b, 0) / blinkRates.length || 0;

    // Performance percentiles
    const percentiles = this.calculatePercentiles(sessions);

    // Generate insights using Gemini
    const insights = await this.generateInsights(sessions, avgAttention, avgEngagement, learnerProfile?.name);

    return {
      summary: {
        totalSessions,
        totalDuration,
        avgDuration: Math.round(avgDuration * 10) / 10,
        avgAttention: Math.round(avgAttention),
        avgEngagement: Math.round(avgEngagement),
        avgCompletion: Math.round(avgCompletion),
        avgBlinkRate: Math.round(avgBlinkRate),
        attentionTrend,
        engagementTrend,
        streakDays: this.calculateStreak(sessions),
      },
      timeSeries: timeSeriesData,
      emotionBreakdown: emotionData,
      focusAreaProgress,
      percentiles,
      recentSessions: sessions.slice(-5).reverse(),
      insights,
    };
  }

  calculateTrend(values) {
    if (values.length < 2) return 0;

    const firstHalf = values.slice(0, Math.floor(values.length / 2));
    const secondHalf = values.slice(Math.floor(values.length / 2));

    const firstAvg = firstHalf.reduce((a, b) => a + b, 0) / firstHalf.length;
    const secondAvg = secondHalf.reduce((a, b) => a + b, 0) / secondHalf.length;

    return Math.round(((secondAvg - firstAvg) / firstAvg) * 100);
  }

  generateTimeSeries(sessions, period, startDate, endDate) {
    const days = eachDayOfInterval({ start: startDate, end: endDate });

    return days.map(day => {
      const dayStr = format(day, 'yyyy-MM-dd');
      const daySessions = sessions.filter(s =>
        format(new Date(s.session_date), 'yyyy-MM-dd') === dayStr
      );

      if (daySessions.length === 0) {
        return {
          date: format(day, 'MMM d'),
          attention: null,
          engagement: null,
          sessions: 0,
        };
      }

      return {
        date: format(day, 'MMM d'),
        attention: Math.round(daySessions.reduce((a, s) => a + (s.attention_score || 0), 0) / daySessions.length),
        engagement: Math.round(daySessions.reduce((a, s) => a + (s.engagement_score || 0), 0) / daySessions.length),
        completion: Math.round(daySessions.reduce((a, s) => a + (s.completion_rate || 0), 0) / daySessions.length),
        sessions: daySessions.length,
        duration: Math.round(daySessions.reduce((a, s) => a + (s.duration_minutes || 0), 0)),
      };
    });
  }

  aggregateEmotions(sessions) {
    const emotions = {
      happy: 0,
      focused: 0,
      neutral: 0,
      surprised: 0,
      sad: 0,
    };

    let total = 0;
    sessions.forEach(session => {
      if (session.emotion_data) {
        Object.entries(session.emotion_data).forEach(([emotion, count]) => {
          if (emotions.hasOwnProperty(emotion)) {
            emotions[emotion] += count;
            total += count;
          }
        });
      }
    });

    // Convert to percentages
    return Object.entries(emotions).map(([name, value]) => ({
      name,
      value: total > 0 ? Math.round((value / total) * 100) : 0,
      color: this.getEmotionColor(name),
    }));
  }

  getEmotionColor(emotion) {
    const colors = {
      happy: '#10B981',
      focused: '#6366F1',
      neutral: '#64748B',
      surprised: '#F59E0B',
      sad: '#EF4444',
    };
    return colors[emotion] || '#94A3B8';
  }

  calculateFocusAreaProgress(sessions, learnerProfile = null) {
    // Focus area mapping from IDs to display names (matching CreateProfile.jsx)
    const focusAreaMap = {
      'social-skills': 'Social Skills',
      'emotion-intelligence': 'Emotion Intelligence',
      'thought-expression': 'Thought Expression',
      'cognitive-growth': 'Cognitive Growth',
      'life-skills': 'Life Skills',
    };

    // Get learner's selected focus areas from profile
    const learnerFocusAreas = learnerProfile?.focus_areas || [];

    console.log('[Analytics] Learner focus areas from profile:', learnerFocusAreas);
    console.log('[Analytics] Learner profile:', learnerProfile);

    // If learner has selected focus areas, only show those
    // Otherwise, show all focus areas that appear in sessions
    const areasToTrack = learnerFocusAreas.length > 0
      ? learnerFocusAreas
      : Object.keys(focusAreaMap);

    const areas = {};
    areasToTrack.forEach(areaId => {
      areas[areaId] = { total: 0, improved: 0 };
    });

    // Count sessions per focus area
    sessions.forEach(session => {
      if (session.focus_areas && Array.isArray(session.focus_areas)) {
        session.focus_areas.forEach(area => {
          if (areas[area]) {
            areas[area].total++;
            if (session.completion_rate > 70) {
              areas[area].improved++;
            }
          }
        });
      } else if (session.focus_area) {
        // Handle single focus_area field (snake_case)
        const area = session.focus_area;
        if (areas[area]) {
          areas[area].total++;
          if (session.completion_rate > 70) {
            areas[area].improved++;
          }
        }
      }
    });

    // Return only focus areas that have sessions OR are in learner's selected areas
    return Object.entries(areas)
      .filter(([id, data]) => data.total > 0 || learnerFocusAreas.includes(id))
      .map(([id, data]) => ({
        id,
        name: focusAreaMap[id] || id.split('-').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' '),
        sessions: data.total,
        progress: data.total > 0 ? Math.round((data.improved / data.total) * 100) : 0,
      }));
  }

  calculatePercentiles(sessions) {
    const attention = sessions.map(s => s.attention_score).filter(Boolean).sort((a, b) => a - b);
    const engagement = sessions.map(s => s.engagement_score).filter(Boolean).sort((a, b) => a - b);

    return {
      attention: {
        p25: attention[Math.floor(attention.length * 0.25)] || 0,
        p50: attention[Math.floor(attention.length * 0.5)] || 0,
        p75: attention[Math.floor(attention.length * 0.75)] || 0,
        p90: attention[Math.floor(attention.length * 0.9)] || 0,
      },
      engagement: {
        p25: engagement[Math.floor(engagement.length * 0.25)] || 0,
        p50: engagement[Math.floor(engagement.length * 0.5)] || 0,
        p75: engagement[Math.floor(engagement.length * 0.75)] || 0,
        p90: engagement[Math.floor(engagement.length * 0.9)] || 0,
      },
    };
  }

  calculateStreak(sessions) {
    if (sessions.length === 0) return 0;

    let streak = 1;
    let maxStreak = 1;

    const sortedDates = sessions
      .map(s => format(new Date(s.session_date), 'yyyy-MM-dd'))
      .filter((date, i, arr) => arr.indexOf(date) === i)
      .sort();

    for (let i = 1; i < sortedDates.length; i++) {
      const prev = new Date(sortedDates[i - 1]);
      const curr = new Date(sortedDates[i]);
      const diff = (curr - prev) / (1000 * 60 * 60 * 24);

      if (diff === 1) {
        streak++;
        maxStreak = Math.max(maxStreak, streak);
      } else {
        streak = 1;
      }
    }

    return maxStreak;
  }

  async generateInsights(sessions, avgAttention, avgEngagement, childName = 'Your child') {
    try {
      const context = `
Child: ${childName}
Period: Last ${sessions.length} sessions
Average Attention: ${avgAttention}%
Average Engagement: ${avgEngagement}%
Total Sessions: ${sessions.length}
`;

      const systemInstruction = `You are an expert child development specialist. 
Based on the provided metrics, generate 2-4 key insights or recommendations for the parent.
Each insight should have:
1. A type: 'positive' (for strengths) or 'improvement' (for areas to work on).
2. An icon: An emoji representing the insight.
3. A text: A warm, encouraging 1-sentence explanation.

Format the response as a JSON array of objects.`;

      const prompt = `Generate insights for this data:\n${context}\n\nExample: [{"type": "positive", "icon": "🎯", "text": "Excellent attention during sessions!"}]`;

      const insights = await geminiFlash.generateStructuredJSON(prompt, systemInstruction);

      if (Array.isArray(insights) && insights.length > 0) {
        return insights;
      }
    } catch (error) {
      console.warn('[Analytics] Gemini failed to generate insights, using rule-based fallback', error);
    }

    // Rule-based fallback
    const insights = [];
    if (avgAttention >= 80) {
      insights.push({
        type: 'positive',
        icon: '🎯',
        text: `Excellent attention! Average score of ${avgAttention}% is above target.`,
      });
    } else if (avgAttention < 60) {
      insights.push({
        type: 'improvement',
        icon: '💡',
        text: `Attention could improve. Consider shorter sessions or more engaging activities.`,
      });
    }

    if (avgEngagement >= 75) {
      insights.push({
        type: 'positive',
        icon: '⭐',
        text: `High engagement level at ${avgEngagement}%! Activities are well-matched.`,
      });
    }

    if (sessions.length >= 5) {
      insights.push({
        type: 'positive',
        icon: '🔥',
        text: `Great consistency! ${sessions.length} sessions completed this period.`,
      });
    }

    return insights;
  }

  getEmptyAnalytics(period) {
    // Generate realistic demo data for preview
    const demoTimeSeries = this.generateDemoTimeSeries(period);
    const demoEmotions = [
      { name: 'happy', value: 35, color: '#10B981' },
      { name: 'focused', value: 42, color: '#6366F1' },
      { name: 'neutral', value: 15, color: '#64748B' },
      { name: 'surprised', value: 5, color: '#F59E0B' },
      { name: 'sad', value: 3, color: '#EF4444' },
    ];
    const demoFocusAreas = [
      { id: 'social-skills', name: 'Social Skills', sessions: 8, progress: 72 },
      { id: 'emotion-intelligence', name: 'Emotion Intelligence', sessions: 6, progress: 65 },
      { id: 'cognitive-growth', name: 'Cognitive Growth', sessions: 5, progress: 58 },
      { id: 'life-skills', name: 'Life Skills', sessions: 4, progress: 48 },
    ];

    return {
      summary: {
        totalSessions: 12,
        totalDuration: 42,
        avgDuration: 8.5,
        avgAttention: 76,
        avgEngagement: 82,
        avgCompletion: 71,
        avgBlinkRate: 18,
        attentionTrend: 12,
        engagementTrend: 8,
        streakDays: 5,
      },
      timeSeries: demoTimeSeries,
      emotionBreakdown: demoEmotions,
      focusAreaProgress: demoFocusAreas,
      percentiles: {
        attention: { p25: 65, p50: 76, p75: 84, p90: 91 },
        engagement: { p25: 70, p50: 82, p75: 88, p90: 94 }
      },
      recentSessions: [],
      insights: [
        { type: 'positive', icon: '🌟', text: 'Best focus time: Morning sessions show 15% higher attention.' },
        { type: 'positive', icon: '📈', text: 'Consistency improved this week with a 5-day streak!' },
        { type: 'improvement', icon: '💡', text: 'Engagement peaks after activity reminders.' },
        { type: 'positive', icon: '🎯', text: 'Social skills showing great progress at 72%.' },
      ],
      isDemo: true,
    };
  }

  generateDemoTimeSeries(period) {
    // format and subDays are already imported at the top
    const days = period === 'week' ? 7 : period === 'month' ? 30 : period === '3months' ? 90 : 7;
    const data = [];

    for (let i = days - 1; i >= 0; i--) {
      const date = subDays(new Date(), i);
      // Generate realistic varying data with an upward trend
      const baseAttention = 65 + Math.random() * 20 + (days - i) * 0.3;
      const baseEngagement = 70 + Math.random() * 18 + (days - i) * 0.25;
      const baseDuration = 5 + Math.random() * 8;

      // Add some null days to simulate real usage (skip weekends sometimes)
      const hasSession = Math.random() > 0.2;

      data.push({
        date: format(date, 'MMM d'),
        attention: hasSession ? Math.min(100, Math.round(baseAttention)) : null,
        engagement: hasSession ? Math.min(100, Math.round(baseEngagement)) : null,
        completion: hasSession ? Math.round(60 + Math.random() * 35) : null,
        sessions: hasSession ? Math.ceil(Math.random() * 3) : 0,
        duration: hasSession ? Math.round(baseDuration) : 0,
      });
    }

    return data;
  }

  clearCache() {
    this.cache.clear();
  }
}

export const analytics = new AnalyticsService();
export default analytics;
