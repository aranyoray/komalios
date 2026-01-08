/**
 * Parent Dashboard with PIN Protection
 * Access to reports, settings, and child progress
 */

import React, { useState, useEffect } from 'react';
import {
  Box,
  Container,
  Typography,
  Grid,
  Card,
  CardContent,
  Button,
  TextField,
  IconButton,
  Avatar,
  Chip,
  LinearProgress,
  Alert,
} from '@mui/material';
import {
  Lock,
  ArrowBack,
  Assessment,
  Schedule,
  Notifications,
  Download,
  Visibility,
  VisibilityOff,
} from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../../contexts/AuthContext';
import { useLanguage } from '../../i18n/LanguageContext';
import ReportDashboard from '../../components/Reports/ReportDashboard';
import ConciseSessionReport, { generateMockReport, transformSessionToReport } from '../../components/Reports/ConciseSessionReport';
import { analytics } from '../../services/analytics';
import { supabaseDB } from '../../services/supabaseDB';
import { getParentPin } from '../../utils/parentPin';
import { gradients } from '../../theme';
const sidebarBg = '/assets/sidebarimage.png';
import { computeSubdomainScores } from '../../assessment/subdomainMetrics';
import { generateConciseHighlights, generateSessionSummary } from '../../services/aiInsightsService';

const ParentDashboard = () => {
  const navigate = useNavigate();
  const { currentProfile, user, isDevMode } = useAuth();
  const { t } = useLanguage();

  const [isUnlocked, setIsUnlocked] = useState(false);
  const [pin, setPin] = useState('');
  const [pinError, setPinError] = useState('');
  const [recentReport, setRecentReport] = useState(null);
  const [showPin, setShowPin] = useState(false);
  const [summaryData, setSummaryData] = useState(null);
  const [storedPin, setStoredPin] = useState('1234');

  // Load PIN from user level
  useEffect(() => {
    const loadPin = async () => {
      if (user) {
        const pin = await getParentPin(user);
        setStoredPin(pin);
      }
    };
    loadPin();
  }, [user]);

  useEffect(() => {
    if (isUnlocked) {
      loadRecentReport();
    }
  }, [currentProfile, isUnlocked]);

  const loadRecentReport = async () => {
    try {
      if (!currentProfile?.id) {
        console.warn('[Dashboard] No current profile available');
        return;
      }

      const data = await analytics.getAnalytics(currentProfile.id, 'week');
      setSummaryData(data.summary);

      // Try to fetch real session data from database
      try {
        console.log('[Dashboard] Fetching latest session for learner:', currentProfile.id);

        // Fetch more sessions to ensure we get the latest one
        const sessions = await supabaseDB.getSessionsByLearnerId(currentProfile.id, 10);

        console.log('[Dashboard] Sessions fetched:', sessions?.length || 0);

        if (sessions && sessions.length > 0) {
          // Sort by start_time descending to ensure we get the latest session
          const sortedSessions = [...sessions].sort((a, b) => {
            const timeA = a.start_time || a.startTime || 0;
            const timeB = b.start_time || b.startTime || 0;
            return new Date(timeB) - new Date(timeA);
          });

          const latestSession = sortedSessions[0];
          console.log('[Dashboard] Latest session:', {
            id: latestSession.id,
            start_time: latestSession.start_time || latestSession.startTime,
            focus_area: latestSession.focus_area || latestSession.focusArea,
            tasks_completed: latestSession.tasks_completed || latestSession.tasksCompleted,
          });

          const learnerProfile = currentProfile || {};

          // Transform database session to report format
          const reportData = transformSessionToReport(latestSession, learnerProfile);

          // Enhance with Gemini insights if available
          try {
            console.log('[Dashboard] Enhancing report with Gemini insights...');
            const domainScores = computeSubdomainScores(latestSession, learnerProfile.age || 7);

            // Run AI calls in parallel
            const [aiHighlights, aiSummary] = await Promise.all([
              generateConciseHighlights(latestSession, domainScores),
              generateSessionSummary(latestSession, domainScores)
            ]);

            if (aiHighlights && aiHighlights.length > 0) {
              reportData.highlight = aiHighlights[0];
            }
            if (aiSummary) {
              reportData.summary = aiSummary;
            }
            console.log('[Dashboard] Gemini enhancement complete');
          } catch (aiError) {
            console.warn('[Dashboard] Failed to enhance report with Gemini:', aiError);
          }

          console.log('[Dashboard] Transformed report data:', reportData);
          setRecentReport(reportData);
          return;
        } else {
          console.warn('[Dashboard] No sessions found in database for learner:', currentProfile.id);
        }
      } catch (sessionError) {
        console.error('[Dashboard] Failed to load session from database:', sessionError);
        console.warn('[Dashboard] Error details:', {
          message: sessionError.message,
          stack: sessionError.stack,
        });
      }

      // Fallback to mock data if no sessions found
      console.log('[Dashboard] Generating mock report data as fallback');
      if (data.recentSessions && data.recentSessions.length > 0) {
        const mockData = generateMockReport({
          focusArea: 'Emotional Control',
          tasksCompleted: 8,
          totalTasks: 10,
          engagementQuality: 7,
          attentionScore: data.summary.avgAttention || 72,
        });
        console.log('[Dashboard] Using MOCK data:', mockData);
        setRecentReport(mockData);
      } else {
        console.warn('[Dashboard] No recent sessions in analytics data, no report will be shown');
        setRecentReport(null);
      }
    } catch (err) {
      console.error('[Dashboard] Failed to load report:', err);
      setRecentReport(null);
    }
  };

  const handlePinSubmit = () => {
    if (pin === storedPin) {
      setIsUnlocked(true);
      setPinError('');
    } else {
      setPinError(t.parentDashboard.incorrectPin);
      setPin('');
    }
  };

  const handlePinKeyPress = (e) => {
    if (e.key === 'Enter' && pin.length === 4) {
      handlePinSubmit();
    }
  };

  const handleBackToChild = () => {
    navigate('/learner');
  };

  // PIN Entry Dialog
  if (!isUnlocked) {
    return (
      <Box
        sx={{
          height: '100%',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          backgroundImage: `url(${sidebarBg})`,
          backgroundSize: 'cover',
          backgroundPosition: 'center',
          p: 3,
          position: 'relative',
        }}
      >
        <Card
          sx={{
            maxWidth: 450,
            width: '100%',
            textAlign: 'center',
            borderRadius: 1,
            boxShadow: 'none',
            position: 'relative',
            zIndex: 1,
            background: 'rgba(255, 255, 255, 0.7)',
            backdropFilter: 'blur(16px)',
            WebkitBackdropFilter: 'blur(16px)',
          }}
        >
          <CardContent sx={{ p: { xs: 3, sm: 4 } }}>
            <Box
              sx={{
                width: 100,
                height: 100,
                borderRadius: '50%',
                background: '#E5E7EB',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                mx: 'auto',
                mb: 3,
              }}
            >
              <Lock sx={{ fontSize: 48, color: '#6B7280' }} />
            </Box>

            <Typography
              variant="h4"
              fontWeight={700}
              gutterBottom
              sx={{
                mb: 1,
                background: 'linear-gradient(135deg, #6366F1 0%, #8B5CF6 100%)',
                WebkitBackgroundClip: 'text',
                WebkitTextFillColor: 'transparent',
                backgroundClip: 'text',
              }}
            >
              {t.parentDashboard.parentAccess}
            </Typography>
            <Typography variant="body1" color="text.secondary" sx={{ mb: 4, fontSize: '1rem' }}>
              {t.parentDashboard.enterPinToAccess}
            </Typography>

            <TextField
              fullWidth
              type={showPin ? 'text' : 'password'}
              value={pin}
              onChange={(e) => {
                const value = e.target.value.replace(/\D/g, '').slice(0, 4);
                setPin(value);
                setPinError('');
              }}
              onKeyPress={handlePinKeyPress}
              placeholder="• • • •"
              inputProps={{
                maxLength: 4,
                style: {
                  textAlign: 'center',
                  fontSize: '2rem',
                  letterSpacing: '1rem',
                  fontWeight: 700,
                },
              }}
              InputProps={{
                endAdornment: (
                  <IconButton onClick={() => setShowPin(!showPin)} edge="end">
                    {showPin ? <VisibilityOff /> : <Visibility />}
                  </IconButton>
                ),
              }}
              error={!!pinError}
              helperText={pinError}
              sx={{
                mb: 3,
                '& .MuiOutlinedInput-root': {
                  borderRadius: 3,
                  fontSize: '1.25rem',
                },
              }}
            />

            <Button
              fullWidth
              variant="contained"
              size="large"
              onClick={handlePinSubmit}
              disabled={pin.length !== 4}
              sx={{
                mb: 2,
                py: 1.5,
                fontSize: '1rem',
                fontWeight: 600,
                bgcolor: '#FFF9C4',
                color: '#5D4037',
                '&:hover': {
                  bgcolor: '#FFF59D',
                },
                '&:disabled': {
                  bgcolor: 'grey.300',
                },
              }}
            >
              {t.parentDashboard.unlockDashboard}
            </Button>

            <Button
              fullWidth
              variant="outlined"
              onClick={handleBackToChild}
              startIcon={<ArrowBack />}
              sx={{
                borderWidth: 2,
                '&:hover': {
                  borderWidth: 2,
                },
              }}
            >
              {t.parentDashboard.backToChildMode}
            </Button>



            <Typography variant="caption" color="text.secondary" sx={{ mt: 3, display: 'block', opacity: 0.7 }}>
              {t.parentDashboard.defaultPin}
            </Typography>
          </CardContent>
        </Card>
      </Box>
    );
  }

  return (
    <Box sx={{ minHeight: '100vh', bgcolor: 'background.default' }}>
      {/* Enhanced Header */}
      <Box
        sx={{
          background: '#D4EDDA',
          color: '#333',
          py: { xs: 3, md: 4 },
          position: 'sticky',
          top: 0,
          zIndex: 10,
          boxShadow: '0 4px 20px rgba(0,0,0,0.05)',
          overflow: 'hidden',
        }}
      >
        <Container maxWidth="lg" sx={{ position: 'relative', zIndex: 1 }}>
          <Box sx={{ textAlign: 'center' }}>
            <Typography
              variant="h5"
              fontWeight={700}
              sx={{ fontSize: { xs: '1.25rem', md: '1.5rem' } }}
            >
              {t.parentDashboard.title}
            </Typography>
            <Typography variant="body2" sx={{ opacity: 0.95, fontSize: { xs: '0.875rem', md: '0.95rem' } }}>
              {t.parentDashboard.progressAndAnalytics.replace('{name}', currentProfile?.name || t.parentDashboard.child)}
            </Typography>
          </Box>
        </Container>
      </Box>

      {/* Reports Content */}
      <Box sx={{ py: 2, px: 2, bgcolor: '#F5F5F5', minHeight: 'calc(100vh - 100px)', overflow: 'hidden' }}>
        {/* 2x2 Stats Grid */}
        <Box sx={{
          display: 'grid',
          gridTemplateColumns: '1fr 1fr',
          gap: 1.5,
          mb: 3,
        }}>
          {/* Sessions This Week */}
          <Card sx={{
            bgcolor: '#fff',
            borderRadius: 1,
            boxShadow: '0 2px 8px rgba(0,0,0,0.06)',
            border: '1px solid rgba(0,0,0,0.05)',
          }}>
            <CardContent sx={{ textAlign: 'center', p: 1, '&:last-child': { pb: 1 } }}>
              <Box sx={{ width: '60%', height: 4, bgcolor: '#F87171', borderRadius: 2, mx: 'auto', mb: 1.5 }} />
              <Typography variant="h3" fontWeight={800} sx={{ color: '#F87171', mb: 0.5 }}>
                {summaryData?.totalSessions || 0}
              </Typography>
              <Typography variant="caption" color="text.secondary" fontWeight={500}>
                {t.parentDashboard.sessionsThisWeek}
              </Typography>
            </CardContent>
          </Card>

          {/* Avg Attention */}
          <Card sx={{
            bgcolor: '#fff',
            borderRadius: 1,
            boxShadow: '0 2px 8px rgba(0,0,0,0.06)',
            border: '1px solid rgba(0,0,0,0.05)',
          }}>
            <CardContent sx={{ textAlign: 'center', p: 1, '&:last-child': { pb: 1 } }}>
              <Box sx={{ width: '60%', height: 4, bgcolor: '#10B981', borderRadius: 2, mx: 'auto', mb: 1.5 }} />
              <Typography variant="h3" fontWeight={800} sx={{ color: '#10B981', mb: 0.5 }}>
                {summaryData?.avgAttention || 0}%
              </Typography>
              <Typography variant="caption" color="text.secondary" fontWeight={500}>
                {t.parentDashboard.avgAttention}
              </Typography>
            </CardContent>
          </Card>

          {/* Day Streak */}
          <Card sx={{
            bgcolor: '#fff',
            borderRadius: 1,
            boxShadow: '0 2px 8px rgba(0,0,0,0.06)',
            border: '1px solid rgba(0,0,0,0.05)',
          }}>
            <CardContent sx={{ textAlign: 'center', p: 1, '&:last-child': { pb: 1 } }}>
              <Box sx={{ width: '60%', height: 4, bgcolor: '#FBBF24', borderRadius: 2, mx: 'auto', mb: 1.5 }} />
              <Typography variant="h3" fontWeight={800} sx={{ color: '#FBBF24', mb: 0.5 }}>
                {summaryData?.streakDays || 0}
              </Typography>
              <Typography variant="caption" color="text.secondary" fontWeight={500}>
                {t.parentDashboard.dayStreak}
              </Typography>
            </CardContent>
          </Card>

          {/* Improvement */}
          <Card sx={{
            bgcolor: '#fff',
            borderRadius: 1,
            boxShadow: '0 2px 8px rgba(0,0,0,0.06)',
            border: '1px solid rgba(0,0,0,0.05)',
          }}>
            <CardContent sx={{ textAlign: 'center', p: 1, '&:last-child': { pb: 1 } }}>
              <Box sx={{ width: '60%', height: 4, bgcolor: '#F59E0B', borderRadius: 2, mx: 'auto', mb: 1.5 }} />
              <Typography variant="h3" fontWeight={800} sx={{ color: '#F59E0B', mb: 0.5 }}>
                {summaryData?.attentionTrend >= 0 ? '+' : ''}{summaryData?.attentionTrend || 0}%
              </Typography>
              <Typography variant="caption" color="text.secondary" fontWeight={500}>
                {t.parentDashboard.improvement}
              </Typography>
            </CardContent>
          </Card>
        </Box>

        {/* Full Dashboard - wrapped to prevent purple bg */}
        <Box sx={{ bgcolor: '#F5F5F5' }}>
          <ReportDashboard
            learnerId={currentProfile?.id}
            learnerName={currentProfile?.name || t.parentDashboard.child}
            learnerProfile={currentProfile}
          />
        </Box>
      </Box>
    </Box>
  );
};

export default ParentDashboard;

