/**
 * Concise Session Report (Session Snapshot)
 * Exact format as specified in requirements
 */

import React from 'react';
import {
  Box,
  Card,
  CardContent,
  Typography,
  Grid,
  Chip,
  Divider,
  Paper,
  Rating,
  Button,
  IconButton,
  useMediaQuery,
  useTheme,
} from '@mui/material';
import {
  Share,
  WhatsApp,
  Sms,
  TrendingUp,
  EmojiEmotions,
  TouchApp,
  Speed,
  Home,
  Flag,
  CheckCircle,
  Star,
} from '@mui/icons-material';
import { Share as CapShare } from '@capacitor/share';
import { useLanguage } from '../../i18n/LanguageContext';
import { gradients } from '../../theme';

const ConciseSessionReport = ({ report, learnerName, onShare }) => {
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
  const { t } = useLanguage();
  
  const {
    focusArea,
    tasksCompleted,
    totalTasks,
    engagementQuality,
    keySkillPractised,
    highlight,
    attentionMetrics,
    emotionMetrics,
    touchMetrics,
    responseMetrics,
    summary,
    homePractice,
    nextGoal,
  } = report;

  const handleShare = async (method) => {
    const text = generateShareText();

    if (method === 'native') {
      try {
        await CapShare.share({
          title: t.reports.conciseReport.sessionReport.replace('{name}', learnerName),
          text: text,
          dialogTitle: t.reports.conciseReport.shareReport,
        });
      } catch (e) {
        // Fallback to web share
        if (navigator.share) {
          navigator.share({ title: t.reports.conciseReport.sessionReport.replace('{name}', learnerName), text });
        }
      }
    } else if (method === 'whatsapp') {
      window.open(`https://wa.me/?text=${encodeURIComponent(text)}`, '_blank');
    } else if (method === 'sms') {
      window.open(`sms:?body=${encodeURIComponent(text)}`, '_blank');
    }
  };

  const generateShareText = () => {
    return `
📊 ${learnerName}'s Session Snapshot

Focus Area: ${focusArea}
• Completed: ${tasksCompleted}/${totalTasks} tasks
• Engagement: ${engagementQuality}/10
• Key Skill: ${keySkillPractised}
${highlight ? `• Highlight: ${highlight} 🎉` : ''}

Attention: ${attentionMetrics.score}% ${attentionMetrics.trend}
${summary}

Home Practice: ${homePractice.question}
Next Goal: ${nextGoal}

— Komal SEL App
    `.trim();
  };

  return (
    <Card 
      sx={{ 
        borderRadius: { xs: 0, sm: 4 },
        overflow: 'hidden',
        boxShadow: '0 8px 32px rgba(0,0,0,0.12)',
        border: '1px solid rgba(99, 102, 241, 0.1)',
      }}
    >
      {/* Enhanced Header */}
      <Box 
        sx={{ 
          background: gradients.primary,
          color: 'white', 
          p: { xs: 2.5, sm: 3 },
          position: 'relative',
          overflow: 'hidden',
          '&::before': {
            content: '""',
            position: 'absolute',
            top: 0,
            right: 0,
            width: '40%',
            height: '100%',
            background: 'radial-gradient(circle, rgba(255,255,255,0.1) 0%, transparent 70%)',
            pointerEvents: 'none',
          },
        }}
      >
        <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', position: 'relative', zIndex: 1 }}>
          <Box>
            <Typography 
              variant="h5" 
              fontWeight={700}
              sx={{ fontSize: { xs: '1.25rem', sm: '1.5rem' }, mb: 0.5 }}
            >
              {t.reports.conciseReport.sessionSnapshot}
            </Typography>
            <Typography variant="body2" sx={{ opacity: 0.95, fontSize: { xs: '0.875rem', sm: '0.95rem' } }}>
              {learnerName} • {new Date().toLocaleDateString()}
            </Typography>
          </Box>
          <Chip
            icon={<CheckCircle sx={{ color: 'white !important' }} />}
            label={t.reports.conciseReport.completed}
            sx={{
              bgcolor: 'rgba(255,255,255,0.2)',
              color: 'white',
              fontWeight: 600,
              backdropFilter: 'blur(10px)',
            }}
          />
        </Box>
      </Box>

      <CardContent sx={{ p: { xs: 2, sm: 3 } }}>
        {/* Enhanced Focus Area Summary */}
        <Paper 
          elevation={0} 
          sx={{ 
            background: 'linear-gradient(135deg, #6366F108 0%, #6366F103 100%)',
            border: '1px solid rgba(99, 102, 241, 0.1)',
            p: { xs: 2, sm: 2.5 }, 
            borderRadius: 3, 
            mb: 3,
            position: 'relative',
            overflow: 'hidden',
            '&::before': {
              content: '""',
              position: 'absolute',
              top: 0,
              left: 0,
              right: 0,
              height: 3,
              background: gradients.primary,
            },
          }}
        >
          <Typography variant="subtitle1" fontWeight={700} gutterBottom sx={{ mb: 2 }}>
            {t.reports.conciseReport.focusArea} <Box component="span" sx={{ color: 'primary.main' }}>{focusArea}</Box>
          </Typography>
          
          <Grid container spacing={2}>
            <Grid item xs={12} sm={6}>
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1.5 }}>
                <CheckCircle sx={{ color: 'success.main', fontSize: '1.25rem' }} />
                <Typography variant="body1" fontWeight={600}>
                  {t.reports.conciseReport.completedTasks} <Box component="span" sx={{ color: 'primary.main' }}>{tasksCompleted}/{totalTasks}</Box> {t.reports.conciseReport.tasks}
                </Typography>
              </Box>
            </Grid>
            
            <Grid item xs={12} sm={6}>
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1.5 }}>
                <Star sx={{ color: 'warning.main', fontSize: '1.25rem' }} />
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                  <Typography variant="body1" fontWeight={600}>{t.reports.conciseReport.engagement}</Typography>
                  <Rating value={engagementQuality / 2} max={5} readOnly size="small" />
                  <Typography variant="body2" color="text.secondary">({engagementQuality}/10)</Typography>
                </Box>
              </Box>
            </Grid>
          </Grid>
          
          <Box sx={{ mt: 2, p: 1.5, bgcolor: 'rgba(99, 102, 241, 0.05)', borderRadius: 2 }}>
            <Typography variant="body2" fontWeight={600} color="text.secondary" gutterBottom>
              {t.reports.conciseReport.keySkillPractised}
            </Typography>
            <Typography variant="body1" sx={{ fontStyle: 'italic', color: 'primary.dark' }}>
              "{keySkillPractised}"
            </Typography>
          </Box>
          
          {highlight && (
            <Box 
              sx={{ 
                mt: 2, 
                p: 1.5, 
                bgcolor: 'success.50', 
                borderRadius: 2,
                border: '1px solid',
                borderColor: 'success.200',
              }}
            >
              <Typography variant="body1" fontWeight={600} sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                <EmojiEmotions sx={{ color: 'success.main' }} />
                {t.reports.conciseReport.highlight} {highlight} 🎉
              </Typography>
            </Box>
          )}
        </Paper>

        {/* Enhanced Quick Metrics */}
        <Typography 
          variant="h6" 
          fontWeight={700} 
          gutterBottom
          sx={{ 
            mb: 3,
            fontSize: { xs: '1.125rem', sm: '1.25rem' },
          }}
        >
          {t.reports.conciseReport.quickMetrics}
        </Typography>

        <Grid container spacing={{ xs: 2, sm: 2.5 }} sx={{ mb: 3 }}>
          {/* Attention & Concentration */}
          <Grid item xs={12} sm={6}>
            <Paper 
              sx={{ 
                p: { xs: 2, sm: 2.5 }, 
                borderRadius: 3,
                border: '1px solid',
                borderColor: 'primary.200',
                background: 'linear-gradient(135deg, #6366F108 0%, #6366F103 100%)',
                transition: 'all 0.3s ease',
                '&:hover': {
                  transform: 'translateY(-2px)',
                  boxShadow: '0 4px 12px rgba(99, 102, 241, 0.15)',
                },
              }}
            >
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, mb: 2 }}>
                <Box
                  sx={{
                    width: 40,
                    height: 40,
                    borderRadius: 2,
                    background: gradients.primary,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    color: 'white',
                  }}
                >
                  <TrendingUp />
                </Box>
                <Typography variant="subtitle1" fontWeight={700} color="primary.main">
                  {t.reports.conciseReport.attentionConcentration}
                </Typography>
              </Box>
              <Box sx={{ pl: { xs: 0, sm: 6 } }}>
                <Typography variant="body1" sx={{ mb: 1 }}>
                  {t.reports.conciseReport.attentionScore} <Box component="span" fontWeight={700} sx={{ fontSize: '1.125rem', color: 'primary.main' }}>{attentionMetrics.score}%</Box> {attentionMetrics.trend}
                </Typography>
                <Typography variant="body2" color="text.secondary" sx={{ mb: 1.5 }}>
                  {t.reports.conciseReport.socialGaze} {attentionMetrics.socialGaze}
                </Typography>
                <Chip
                  label={attentionMetrics.interpretation}
                  size="small"
                  sx={{
                    bgcolor: 'primary.50',
                    color: 'primary.700',
                    fontWeight: 500,
                    fontSize: '0.75rem',
                  }}
                />
              </Box>
            </Paper>
          </Grid>

          {/* Emotion & Expression */}
          <Grid item xs={12} sm={6}>
            <Paper 
              sx={{ 
                p: { xs: 2, sm: 2.5 }, 
                borderRadius: 3,
                border: '1px solid',
                borderColor: 'secondary.200',
                background: 'linear-gradient(135deg, #EC489908 0%, #EC489903 100%)',
                transition: 'all 0.3s ease',
                '&:hover': {
                  transform: 'translateY(-2px)',
                  boxShadow: '0 4px 12px rgba(236, 72, 153, 0.15)',
                },
              }}
            >
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, mb: 2 }}>
                <Box
                  sx={{
                    width: 40,
                    height: 40,
                    borderRadius: 2,
                    background: gradients.secondary,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    color: 'white',
                  }}
                >
                  <EmojiEmotions />
                </Box>
                <Typography variant="subtitle1" fontWeight={700} color="secondary.main">
                  {t.reports.conciseReport.emotionExpression}
                </Typography>
              </Box>
              <Box sx={{ pl: { xs: 0, sm: 6 } }}>
                <Typography variant="body1" sx={{ mb: 1 }}>
                  {t.reports.conciseReport.positiveExpressions} <Box component="span" fontWeight={700} color="success.main">{emotionMetrics.positiveExpressions}</Box>
                </Typography>
                <Typography variant="body2" color="text.secondary" sx={{ mb: 1.5 }}>
                  {t.reports.conciseReport.frustrationEpisodes} {emotionMetrics.frustrationEpisodes}
                </Typography>
                <Chip
                  label={emotionMetrics.interpretation}
                  size="small"
                  sx={{
                    bgcolor: 'secondary.50',
                    color: 'secondary.700',
                    fontWeight: 500,
                    fontSize: '0.75rem',
                  }}
                />
              </Box>
            </Paper>
          </Grid>

          {/* Touch & Motor Behavior */}
          <Grid item xs={12} sm={6}>
            <Paper 
              sx={{ 
                p: { xs: 2, sm: 2.5 }, 
                borderRadius: 3,
                border: '1px solid',
                borderColor: 'success.200',
                background: 'linear-gradient(135deg, #10B98108 0%, #10B98103 100%)',
                transition: 'all 0.3s ease',
                '&:hover': {
                  transform: 'translateY(-2px)',
                  boxShadow: '0 4px 12px rgba(16, 185, 129, 0.15)',
                },
              }}
            >
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, mb: 2 }}>
                <Box
                  sx={{
                    width: 40,
                    height: 40,
                    borderRadius: 2,
                    background: gradients.success,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    color: 'white',
                  }}
                >
                  <TouchApp />
                </Box>
                <Typography variant="subtitle1" fontWeight={700} color="success.main">
                  {t.reports.conciseReport.touchMotorBehavior}
                </Typography>
              </Box>
              <Box sx={{ pl: { xs: 0, sm: 6 } }}>
                <Typography variant="body1" sx={{ mb: 1 }}>
                  {t.reports.conciseReport.accurateTouches} <Box component="span" fontWeight={700} color="success.main">{touchMetrics.accurateTouches}</Box>
                </Typography>
                <Typography variant="body2" color="text.secondary" sx={{ mb: 1.5 }}>
                  {t.reports.conciseReport.hesitationTaps} {touchMetrics.hesitationTaps}
                </Typography>
                <Chip
                  label={touchMetrics.interpretation}
                  size="small"
                  sx={{
                    bgcolor: 'success.50',
                    color: 'success.700',
                    fontWeight: 500,
                    fontSize: '0.75rem',
                  }}
                />
              </Box>
            </Paper>
          </Grid>

          {/* Response Pattern */}
          <Grid item xs={12} sm={6}>
            <Paper 
              sx={{ 
                p: { xs: 2, sm: 2.5 }, 
                borderRadius: 3,
                border: '1px solid',
                borderColor: 'warning.200',
                background: 'linear-gradient(135deg, #F59E0B08 0%, #F59E0B03 100%)',
                transition: 'all 0.3s ease',
                '&:hover': {
                  transform: 'translateY(-2px)',
                  boxShadow: '0 4px 12px rgba(245, 158, 11, 0.15)',
                },
              }}
            >
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, mb: 2 }}>
                <Box
                  sx={{
                    width: 40,
                    height: 40,
                    borderRadius: 2,
                    background: gradients.warm,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    color: 'white',
                  }}
                >
                  <Speed />
                </Box>
                <Typography variant="subtitle1" fontWeight={700} color="warning.main">
                  {t.reports.conciseReport.responsePattern}
                </Typography>
              </Box>
              <Box sx={{ pl: { xs: 0, sm: 6 } }}>
                <Typography variant="body1" sx={{ mb: 1 }}>
                  {t.reports.conciseReport.initiationDelay} <Box component="span" fontWeight={700} color="warning.main">{responseMetrics.initiationDelay}</Box>
                </Typography>
                <Typography variant="body2" color="text.secondary" sx={{ mb: 1.5 }}>
                  {t.reports.conciseReport.retryAttempts} {responseMetrics.retryAttempts}
                </Typography>
                <Chip
                  label={responseMetrics.interpretation}
                  size="small"
                  sx={{
                    bgcolor: 'warning.50',
                    color: 'warning.700',
                    fontWeight: 500,
                    fontSize: '0.75rem',
                  }}
                />
              </Box>
            </Paper>
          </Grid>
        </Grid>

        <Divider sx={{ my: { xs: 2.5, sm: 3 } }} />

        {/* Enhanced What This Means */}
        <Box sx={{ mb: 3 }}>
          <Typography 
            variant="h6" 
            fontWeight={700} 
            gutterBottom
            sx={{ 
              mb: 2,
              fontSize: { xs: '1.125rem', sm: '1.25rem' },
            }}
          >
            {t.reports.conciseReport.whatThisMeans}
          </Typography>
          <Paper
            sx={{
              p: { xs: 2, sm: 2.5 },
              borderRadius: 3,
              background: 'linear-gradient(135deg, #F8FAFC 0%, #E2E8F0 100%)',
              border: '1px solid',
              borderColor: 'grey.200',
            }}
          >
            <Typography variant="body1" color="text.primary" sx={{ lineHeight: 1.7 }}>
              {summary}
            </Typography>
          </Paper>
        </Box>

        {/* Enhanced Small Home Practice */}
        <Paper 
          sx={{ 
            background: 'linear-gradient(135deg, #6366F108 0%, #6366F103 100%)',
            border: '1px solid',
            borderColor: 'primary.200',
            p: { xs: 2, sm: 2.5 }, 
            borderRadius: 3, 
            mb: 3,
            position: 'relative',
            overflow: 'hidden',
            '&::before': {
              content: '""',
              position: 'absolute',
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              background: gradients.primary,
            },
          }}
        >
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, mb: 1.5 }}>
            <Home sx={{ color: 'primary.main', fontSize: '1.5rem' }} />
            <Typography variant="subtitle1" fontWeight={700} color="primary.main">
              {t.reports.conciseReport.smallHomePractice}
            </Typography>
          </Box>
          <Typography variant="body1" fontWeight={600} gutterBottom sx={{ pl: { xs: 0, sm: 5 }, mb: 1 }}>
            {t.reports.conciseReport.ask} <Box component="span" sx={{ fontStyle: 'italic', color: 'primary.dark' }}>"{homePractice.question}"</Box>
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ pl: { xs: 0, sm: 5 } }}>
            → {homePractice.purpose}
          </Typography>
        </Paper>

        {/* Enhanced Next Tiny Goal */}
        <Paper 
          sx={{ 
            background: 'linear-gradient(135deg, #10B98108 0%, #10B98103 100%)',
            border: '1px solid',
            borderColor: 'success.200',
            p: { xs: 2, sm: 2.5 }, 
            borderRadius: 3, 
            mb: 3,
            position: 'relative',
            overflow: 'hidden',
            '&::before': {
              content: '""',
              position: 'absolute',
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              background: gradients.success,
            },
          }}
        >
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, mb: 1.5 }}>
            <Flag sx={{ color: 'success.main', fontSize: '1.5rem' }} />
            <Typography variant="subtitle1" fontWeight={700} color="success.main">
              {t.reports.conciseReport.nextTinyGoal}
            </Typography>
          </Box>
          <Typography variant="body1" sx={{ pl: { xs: 0, sm: 5 }, fontWeight: 500 }}>
            {nextGoal}
          </Typography>
        </Paper>

        {/* Enhanced Share Buttons */}
        <Box sx={{ display: 'flex', gap: { xs: 1, sm: 1.5 }, flexWrap: 'wrap', mt: 2 }}>
          <Button
            variant="outlined"
            startIcon={<Share />}
            onClick={() => handleShare('native')}
            sx={{
              fontWeight: 600,
              borderWidth: 2,
              '&:hover': {
                borderWidth: 2,
              },
            }}
          >
            {t.reports.conciseReport.share}
          </Button>
          <Button
            variant="outlined"
            startIcon={<WhatsApp />}
            onClick={() => handleShare('whatsapp')}
            sx={{ 
              color: '#25D366', 
              borderColor: '#25D366',
              borderWidth: 2,
              fontWeight: 600,
              '&:hover': {
                borderColor: '#25D366',
                borderWidth: 2,
                bgcolor: 'rgba(37, 211, 102, 0.04)',
              },
            }}
          >
            {t.reports.conciseReport.whatsapp}
          </Button>
          <Button
            variant="outlined"
            startIcon={<Sms />}
            onClick={() => handleShare('sms')}
            sx={{
              fontWeight: 600,
              borderWidth: 2,
              '&:hover': {
                borderWidth: 2,
              },
            }}
          >
            {t.reports.conciseReport.sms}
          </Button>
        </Box>
      </CardContent>
    </Card>
  );
};

export default ConciseSessionReport;

// Helper function to generate mock report data
export const generateMockReport = (sessionData) => {
  return {
    focusArea: sessionData.focusArea || 'Emotional Control',
    tasksCompleted: sessionData.tasksCompleted || 8,
    totalTasks: sessionData.totalTasks || 10,
    engagementQuality: sessionData.engagementQuality || 7,
    keySkillPractised: sessionData.keySkill || 'Managing frustration calmly',
    highlight: sessionData.highlight || 'Started conversation with avatar without prompt',

    attentionMetrics: {
      score: sessionData.attentionScore || 72,
      trend: '⬆️',
      socialGaze: 'Good comfort with avatar 😊',
      interpretation: 'Stayed focused even during harder activities',
    },

    emotionMetrics: {
      positiveExpressions: '↑',
      frustrationEpisodes: '↓ (from last session)',
      interpretation: 'Great recovery after challenges',
    },

    touchMetrics: {
      accurateTouches: '↑',
      hesitationTaps: 'few',
      interpretation: 'Improved confidence in choices',
    },

    responseMetrics: {
      initiationDelay: 'shorter',
      retryAttempts: 'healthy persistence',
      interpretation: 'Reduced anxiety before responding',
    },

    summary: 'Your child is becoming more confident, staying focused longer, and handling tricky moments better.',

    homePractice: {
      question: 'What helped you keep going when it got a little hard?',
      purpose: 'Reinforces coping strategies practiced in the app',
    },

    nextGoal: 'Maintain eye contact with the avatar during conversation moments.',
  };
};

/**
 * Transform database session data into ConciseSessionReport format
 * @param {Object} dbSession - Session data from database (Supabase or IndexedDB)
 * @param {Object} learnerProfile - Learner profile data
 * @returns {Object} Report data in ConciseSessionReport format
 */
export const transformSessionToReport = (dbSession, learnerProfile) => {
  console.log('[transformSessionToReport] Input session data:', dbSession);
  console.log('[transformSessionToReport] Learner profile:', learnerProfile);
  
  // Handle both Supabase (snake_case) and local (camelCase) formats
  const focusArea = dbSession.focus_area || dbSession.focusArea || 'Social Skills';
  const tasksCompleted = dbSession.tasks_completed || dbSession.tasksCompleted || 0;
  const totalTasks = dbSession.tasks_total || dbSession.tasksTotal || 0;
  const engagementQuality = dbSession.engagement_quality || dbSession.engagementQuality || 0;
  const keySkillPracticed = dbSession.key_skill_practiced || dbSession.keySkillPracticed || 'General therapeutic activities';
  const highlights = dbSession.highlights || [];
  const highlight = highlights.length > 0 ? highlights[0] : null;
  
  console.log('[transformSessionToReport] Extracted basic fields:', {
    focusArea,
    tasksCompleted,
    totalTasks,
    engagementQuality,
    keySkillPracticed,
    highlight,
  });

  // Extract tracking data (handle both formats)
  const eyeTracking = dbSession.eye_tracking || dbSession.eyeTracking || {};
  const microExpressions = dbSession.micro_expressions || dbSession.microExpressions || {};
  const touchTracking = dbSession.touch_tracking || dbSession.touchTracking || {};
  const responsePatterns = dbSession.response_patterns || dbSession.responsePatterns || {};
  
  console.log('[transformSessionToReport] Extracted tracking data:', {
    eyeTracking,
    microExpressions,
    touchTracking,
    responsePatterns,
  });

  // Calculate attention metrics
  const attentionScore = eyeTracking.attentionScore || eyeTracking.attention_score || 0;
  const socialGazeIndex = eyeTracking.socialGazeIndex || eyeTracking.social_gaze_index || 0;
  const socialGazeText = socialGazeIndex > 0.6 
    ? 'Good comfort with avatar 😊' 
    : socialGazeIndex > 0.4 
    ? 'Developing social engagement' 
    : 'Building social connection';
  
  const attentionTrend = attentionScore >= 70 ? '⬆️' : attentionScore >= 50 ? '→' : '⬇️';
  const attentionInterpretation = attentionScore >= 70
    ? 'Stayed focused even during harder activities'
    : attentionScore >= 50
    ? 'Maintained focus with occasional breaks'
    : 'May benefit from shorter activity intervals';

  // Calculate emotion metrics
  const positiveExpressions = microExpressions.positiveAffectActivation || microExpressions.positive_affect_activation || 0;
  const frustrationEpisodes = microExpressions.frustrationEpisodes || microExpressions.frustration_episodes || [];
  const frustrationCount = Array.isArray(frustrationEpisodes) ? frustrationEpisodes.length : (frustrationEpisodes || 0);
  
  const emotionTrend = positiveExpressions > 0.6 ? '↑' : positiveExpressions > 0.4 ? '→' : '↓';
  const frustrationTrend = frustrationCount === 0 ? '↓' : frustrationCount < 3 ? '→' : '↑';
  const emotionInterpretation = frustrationCount === 0
    ? 'Great emotional regulation throughout'
    : frustrationCount < 3
    ? 'Good recovery after challenges'
    : 'Some difficulty managing frustration';

  // Calculate touch metrics
  const accurateTouches = touchTracking.goalDirectedAccuracy || touchTracking.goal_directed_accuracy || 0;
  const hesitationTaps = touchTracking.hesitationTaps || touchTracking.hesitation_taps || 0;
  
  const touchTrend = accurateTouches > 0.75 ? '↑' : accurateTouches > 0.5 ? '→' : '↓';
  const touchInterpretation = accurateTouches > 0.75
    ? 'Improved confidence in choices'
    : accurateTouches > 0.5
    ? 'Developing motor planning skills'
    : 'Building touch confidence';

  // Calculate response metrics
  const avgLatency = responsePatterns.avgLatency || responsePatterns.avg_latency || 0;
  const retryAttempts = responsePatterns.retries || responsePatterns.retryAttempts || 0;
  
  const responseDelay = avgLatency < 1000 ? 'shorter' : avgLatency < 2000 ? 'moderate' : 'longer';
  const retryText = retryAttempts < 3 ? 'healthy persistence' : retryAttempts < 6 ? 'moderate persistence' : 'high persistence';
  const responseInterpretation = avgLatency < 1000 && retryAttempts < 5
    ? 'Reduced anxiety before responding'
    : avgLatency < 2000
    ? 'Developing response confidence'
    : 'May benefit from additional support';

  // Generate summary based on metrics
  const strengths = [];
  if (attentionScore >= 70) strengths.push('staying focused');
  if (frustrationCount === 0) strengths.push('managing emotions');
  if (accurateTouches > 0.75) strengths.push('making confident choices');
  
  const summary = strengths.length > 0
    ? `Your child is ${strengths.join(', ')}, and showing great progress in their therapy sessions.`
    : `Your child is developing important skills through regular practice. Continue supporting their growth with patience and encouragement.`;

  // Generate home practice based on focus area
  const homePracticeQuestions = {
    'Social Skills': {
      question: 'What helped you keep going when it got a little hard?',
      purpose: 'Reinforces coping strategies practiced in the app',
    },
    'Emotional Intelligence': {
      question: 'How did you feel when you completed the activity?',
      purpose: 'Helps identify and express emotions',
    },
    'Language Development': {
      question: 'Can you tell me about what you did with the avatar today?',
      purpose: 'Encourages language and communication',
    },
    'Cognitive Development': {
      question: 'What was your favorite part of today\'s session?',
      purpose: 'Promotes memory and recall skills',
    },
    'Life Skills': {
      question: 'What did you learn that you can use at home?',
      purpose: 'Connects learning to daily life',
    },
  };

  const homePractice = homePracticeQuestions[focusArea] || homePracticeQuestions['Social Skills'];

  // Generate next goal based on focus area
  const nextGoals = {
    'Social Skills': 'Maintain eye contact with the avatar during conversation moments.',
    'Emotional Intelligence': 'Use one coping strategy when feeling frustrated.',
    'Language Development': 'Use 3-word sentences to describe feelings.',
    'Cognitive Development': 'Complete 3 tasks in a row without prompting.',
    'Life Skills': 'Complete one self-care task independently.',
  };

  const nextGoal = nextGoals[focusArea] || nextGoals['Social Skills'];

  const reportData = {
    focusArea,
    tasksCompleted,
    totalTasks,
    engagementQuality: Math.round(engagementQuality * 10) / 10, // Round to 1 decimal
    keySkillPractised: keySkillPracticed,
    highlight,

    attentionMetrics: {
      score: Math.round(attentionScore),
      trend: attentionTrend,
      socialGaze: socialGazeText,
      interpretation: attentionInterpretation,
    },

    emotionMetrics: {
      positiveExpressions: emotionTrend,
      frustrationEpisodes: `${frustrationTrend} (${frustrationCount} ${frustrationCount === 1 ? 'episode' : 'episodes'})`,
      interpretation: emotionInterpretation,
    },

    touchMetrics: {
      accurateTouches: touchTrend,
      hesitationTaps: hesitationTaps < 5 ? 'few' : hesitationTaps < 10 ? 'some' : 'several',
      interpretation: touchInterpretation,
    },

    responseMetrics: {
      initiationDelay: responseDelay,
      retryAttempts: retryText,
      interpretation: responseInterpretation,
    },

    summary,
    homePractice,
    nextGoal,
  };
  
  console.log('[transformSessionToReport] Final transformed report:', reportData);
  return reportData;
};
