/**
 * Interactive Report Dashboard
 * Data-driven analytics with interactive charts
 */

import React, { useState, useEffect } from 'react';
import {
  Box,
  Container,
  Typography,
  Grid,
  Card,
  CardContent,
  ToggleButton,
  ToggleButtonGroup,
  Chip,
  LinearProgress,
  Skeleton,
  Alert,
  useMediaQuery,
  useTheme,
} from '@mui/material';
import {
  TrendingUp,
  TrendingDown,
  Timer,
  Visibility,
  EmojiEmotions,
  Psychology,
  CalendarToday,
} from '@mui/icons-material';
import {
  LineChart,
  Line,
  AreaChart,
  Area,
  BarChart,
  Bar,
  PieChart,
  Pie,
  Cell,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from 'recharts';
import { analytics } from '../../services/analytics';
import { useLanguage } from '../../i18n/LanguageContext';
import { gradients } from '../../theme';

const COLORS = ['#6366F1', '#EC4899', '#10B981', '#F59E0B', '#06B6D4'];

const ReportDashboard = ({ learnerId, learnerName, learnerProfile = null }) => {
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
  const { t } = useLanguage();
  const [period, setPeriod] = useState('week');
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  // Standard chart height for consistency
  const chartHeight = isMobile ? 280 : 300;
  const emotionChartHeight = isMobile ? 120 : 160;

  useEffect(() => {
    loadAnalytics();
  }, [learnerId, period, learnerProfile]);

  const loadAnalytics = async () => {
    setLoading(true);
    setError(null);
    try {
      console.log('[ReportDashboard] Loading analytics with learner profile:', learnerProfile);
      const analyticsData = await analytics.getAnalytics(learnerId, period, learnerProfile);
      setData(analyticsData);
    } catch (err) {
      console.error('Failed to load analytics:', err);
      setError(t.reports.dashboard.failedToLoad);
    } finally {
      setLoading(false);
    }
  };

  const handlePeriodChange = (event, newPeriod) => {
    if (newPeriod) {
      setPeriod(newPeriod);
    }
  };

  if (loading) {
    return (
      <Container maxWidth="lg" sx={{ py: 4 }}>
        <Skeleton variant="rectangular" height={60} sx={{ mb: 3, borderRadius: 2 }} />
        <Grid container spacing={3}>
          {[1, 2, 3, 4].map((i) => (
            <Grid item xs={12} sm={6} md={3} key={i}>
              <Skeleton variant="rectangular" height={120} sx={{ borderRadius: 2 }} />
            </Grid>
          ))}
        </Grid>
        <Skeleton variant="rectangular" height={300} sx={{ mt: 3, borderRadius: 2 }} />
      </Container>
    );
  }

  if (error) {
    return (
      <Container maxWidth="lg" sx={{ py: 4 }}>
        <Alert severity="error">{error}</Alert>
      </Container>
    );
  }

  const { summary, timeSeries, emotionBreakdown, focusAreaProgress, insights, isDemo } = data;

  return (
    <Container
      maxWidth="lg"
      sx={{
        py: { xs: 2, sm: 3, md: 4 },
        px: { xs: 0.5, sm: 2, md: 3 }, // Reduced padding for xs
        width: '100%',
        maxWidth: { xs: '100%', sm: 'lg' },
      }}
    >
      {/* White Background Container */}
      <Box
        sx={{
          background: 'rgba(255, 255, 255, 0.95)',
          backdropFilter: 'blur(20px)',
          borderRadius: 1,
          p: { xs: 1, sm: 3, md: 4 }, // Reduced padding for xs
          boxShadow: '0 8px 32px rgba(0, 0, 0, 0.08)',
          border: '1px solid rgba(255, 255, 255, 0.8)',
        }}
      >
        {/* Demo Data Banner */}
        {isDemo && (
          <Box
            sx={{
              mb: 3,
              p: 1.5,
              borderRadius: 1,
              bgcolor: 'linear-gradient(135deg, #EEF2FF 0%, #E0E7FF 100%)',
              background: 'linear-gradient(135deg, #EEF2FF 0%, #E0E7FF 100%)',
              border: '1px solid #C7D2FE',
              display: 'flex',
              alignItems: 'center',
              gap: 1.5,
            }}
          >

            <Box>
              <Typography variant="body2" fontWeight={600} color="#4338CA">
                Preview Mode
              </Typography>
              <Typography variant="caption" color="#6366F1">
                Complete sessions to see your real analytics
              </Typography>
            </Box>
          </Box>
        )}


        {/* Summary Cards */}
        <Box sx={{
          mb: { xs: 2, md: 4 },
          display: 'grid',
          gridTemplateColumns: { xs: 'repeat(4, 1fr)', sm: 'repeat(2, 1fr)', md: 'repeat(4, 1fr)' },
          gap: { xs: 1, sm: 2 }
        }}>
          <MetricCard
            title={t.reports.dashboard.sessions}
            value={summary.totalSessions}
            subtitle={`${summary.totalDuration} ${t.reports.dashboard.minTotal}`}
            icon={<CalendarToday />}
            color="#6366F1"
          />
          <MetricCard
            title={t.reports.dashboard.attention}
            value={`${summary.avgAttention}%`}
            trend={summary.attentionTrend}
            icon={<Visibility />}
            color="#10B981"
          />
          <MetricCard
            title={t.reports.dashboard.engagement}
            value={`${summary.avgEngagement}%`}
            trend={summary.engagementTrend}
            icon={<Psychology />}
            color="#EC4899"
          />
          <MetricCard
            title={t.reports.dashboard.completion}
            value={`${summary.avgCompletion}%`}
            subtitle={`${summary.streakDays} ${t.reports.dashboard.dayStreak}`}
            icon={<EmojiEmotions />}
            color="#F59E0B"
          />
        </Box>

        {/* Main Charts */}
        <Grid container spacing={{ xs: 1.5, sm: 2 }}>
          {/* Attention & Engagement Trend */}
          <Grid item xs={12} lg={8} sx={{ width: '100%', px: { xs: 0, sm: 'inherit' } }}>
            <Card
              sx={{
                height: '100%',
                width: '100%',
                background: 'linear-gradient(135deg, #FFFFFF 0%, #F8FAFC 100%)',
                border: '1px solid rgba(99, 102, 241, 0.1)',
                borderRadius: 1,
                mx: { xs: 0, sm: 'inherit' },
              }}
            >
              <CardContent sx={{
                p: { xs: 0, sm: 3 },
                width: '100%',
                '&:last-child': { pb: { xs: 0, sm: 3 } },
              }}>
                <Box sx={{
                  display: 'flex',
                  alignItems: { xs: 'flex-start', sm: 'center' },
                  justifyContent: 'space-between',
                  flexDirection: { xs: 'column', sm: 'row' },
                  gap: { xs: 1.5, sm: 0 },
                  mb: { xs: 2, sm: 3 },
                  px: { xs: 1, sm: 0 },
                }}>
                  <Typography variant="h6" fontWeight={700} sx={{ fontSize: { xs: '1rem', sm: '1.125rem' }, pt: { xs: 1, sm: 0 } }}>
                    {t.reports.dashboard.attentionEngagementTrend}
                  </Typography>
                  <Box sx={{ display: 'flex', gap: 1, flexWrap: 'wrap' }}>
                    <Chip
                      label={t.reports.dashboard.attention}
                      size="small"
                      sx={{
                        bgcolor: '#6366F115',
                        color: '#6366F1',
                        fontWeight: 600,
                        fontSize: { xs: '0.7rem', sm: '0.75rem' },
                      }}
                    />
                    <Chip
                      label={t.reports.dashboard.engagement}
                      size="small"
                      sx={{
                        bgcolor: '#EC489915',
                        color: '#EC4899',
                        fontWeight: 600,
                        fontSize: { xs: '0.7rem', sm: '0.75rem' },
                      }}
                    />
                  </Box>
                </Box>
                <Box sx={{
                  height: chartHeight,
                  width: '100%',
                  minWidth: 0,
                }}>
                  <ResponsiveContainer width="100%" height="100%">
                    <AreaChart data={timeSeries} margin={{
                      top: 10,
                      right: isMobile ? 0 : 10,
                      left: isMobile ? 0 : 0,
                      bottom: isMobile ? 0 : 0
                    }}>
                      <defs>
                        <linearGradient id="attentionGradient" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="5%" stopColor="#6366F1" stopOpacity={0.4} />
                          <stop offset="95%" stopColor="#6366F1" stopOpacity={0} />
                        </linearGradient>
                        <linearGradient id="engagementGradient" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="5%" stopColor="#EC4899" stopOpacity={0.4} />
                          <stop offset="95%" stopColor="#EC4899" stopOpacity={0} />
                        </linearGradient>
                      </defs>
                      <CartesianGrid strokeDasharray="3 3" stroke="#E2E8F0" vertical={false} />
                      <XAxis
                        dataKey="date"
                        stroke="#64748B"
                        fontSize={isMobile ? 10 : 12}
                        tickLine={false}
                        axisLine={false}
                        angle={isMobile ? -45 : 0}
                        textAnchor={isMobile ? 'end' : 'middle'}
                        height={isMobile ? 60 : 30}
                      />
                      <YAxis
                        stroke="#64748B"
                        fontSize={isMobile ? 10 : 12}
                        domain={[0, 100]}
                        tickLine={false}
                        axisLine={false}
                        width={isMobile ? 35 : 50}
                      />
                      <Tooltip
                        contentStyle={{
                          background: 'white',
                          border: '1px solid #E2E8F0',
                          borderRadius: 12,
                          boxShadow: '0 8px 24px rgba(0,0,0,0.12)',
                          padding: isMobile ? '8px' : '12px',
                          fontSize: isMobile ? '0.75rem' : '0.875rem',
                        }}
                        labelStyle={{ fontWeight: 600, marginBottom: 8, fontSize: isMobile ? '0.75rem' : '0.875rem' }}
                      />
                      <Legend
                        wrapperStyle={{ paddingTop: 10, fontSize: isMobile ? '0.7rem' : '0.875rem' }}
                        iconType="circle"
                        iconSize={isMobile ? 8 : 10}
                      />
                      <Area
                        type="monotone"
                        dataKey="attention"
                        stroke="#6366F1"
                        fill="url(#attentionGradient)"
                        strokeWidth={isMobile ? 2 : 3}
                        name={t.reports.dashboard.attention}
                        connectNulls
                        dot={isMobile ? false : { fill: '#6366F1', r: 4 }}
                        activeDot={{ r: isMobile ? 5 : 6 }}
                      />
                      <Area
                        type="monotone"
                        dataKey="engagement"
                        stroke="#EC4899"
                        fill="url(#engagementGradient)"
                        strokeWidth={isMobile ? 2 : 3}
                        name={t.reports.dashboard.engagement}
                        connectNulls
                        dot={isMobile ? false : { fill: '#EC4899', r: 4 }}
                        activeDot={{ r: isMobile ? 5 : 6 }}
                      />
                    </AreaChart>
                  </ResponsiveContainer>
                </Box>
              </CardContent>
            </Card>
          </Grid>

          {/* Emotion Breakdown */}
          <Grid item xs={12} lg={4} sx={{ px: { xs: 0, sm: 'inherit' }, width: '100%' }}>
            <Card
              sx={{
                height: '100%',
                width: '100%',
                background: 'linear-gradient(135deg, #FFFFFF 0%, #F8FAFC 100%)',
                border: { xs: 'none', sm: '1px solid rgba(236, 72, 153, 0.1)' },
                borderRadius: 1,
                mx: { xs: 0, sm: 'inherit' },
              }}
            >
              <CardContent sx={{
                p: { xs: 2.5, sm: 3 },
                width: '100%',
                '&:last-child': { pb: { xs: 2.5, sm: 3 } },
                px: { xs: 2.5, sm: 3 },
              }}>
                <Typography
                  variant="h6"
                  fontWeight={700}
                  gutterBottom
                  sx={{
                    mb: { xs: 3, sm: 3 },
                    fontSize: { xs: '1rem', sm: '1.125rem' },
                    px: { xs: 0, sm: 0 },
                  }}
                >
                  {t.reports.dashboard.emotionDistribution}
                </Typography>
                <Box sx={{
                  height: emotionChartHeight,
                  width: '100%',
                  minWidth: 0,
                  display: 'flex',
                  flexDirection: 'row',
                  alignItems: 'center',
                  justifyContent: 'flex-start',
                  gap: { xs: 1.5, sm: 2 },
                  mx: { xs: 0, sm: 0 },
                  px: { xs: 2, sm: 0 },
                  py: { xs: 1, sm: 0 },
                }}>
                  <Box sx={{
                    display: 'inline-flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    height: emotionChartHeight,
                    width: emotionChartHeight,
                    flexShrink: 0,
                  }}>
                    <ResponsiveContainer width="100%" height="100%">
                      <PieChart>
                        <Pie
                          data={emotionBreakdown}
                          cx="50%"
                          cy="50%"
                          innerRadius={isMobile ? 35 : 55}
                          outerRadius={isMobile ? 50 : 75}
                          paddingAngle={2}
                          dataKey="value"
                          stroke="#FFFFFF"
                          strokeWidth={2}
                          isAnimationActive={true}
                          animationBegin={0}
                          animationDuration={800}
                          animationEasing="ease-out"
                        >
                          {emotionBreakdown.map((entry, index) => (
                            <Cell
                              key={`cell-${index}`}
                              fill={entry.color}
                              style={{
                                filter: 'drop-shadow(0 1px 2px rgba(0,0,0,0.1))',
                                transition: 'all 0.3s ease',
                                cursor: 'pointer',
                              }}
                            />
                          ))}
                        </Pie>
                        <Tooltip
                          formatter={(value) => `${value}%`}
                          contentStyle={{
                            background: 'white',
                            border: '1px solid #E2E8F0',
                            borderRadius: 12,
                            boxShadow: '0 8px 24px rgba(0,0,0,0.12)',
                            padding: isMobile ? '8px' : '12px',
                            fontSize: isMobile ? '0.75rem' : '0.875rem',
                          }}
                        />
                      </PieChart>
                    </ResponsiveContainer>
                  </Box>
                  <Box sx={{
                    display: 'inline-flex',
                    flexDirection: 'column',
                    flexWrap: 'wrap',
                    alignItems: 'flex-start',
                    justifyContent: 'center',
                    gap: { xs: 1, sm: 1 },
                    flex: 1,
                  }}>
                    {emotionBreakdown.map((entry, index) => (
                      <Box
                        key={index}
                        sx={{
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: 0.5,
                        }}
                      >
                        <Box
                          sx={{
                            width: { xs: 8, sm: 10 },
                            height: { xs: 8, sm: 10 },
                            borderRadius: '50%',
                            bgcolor: entry.color,
                            flexShrink: 0,
                          }}
                        />
                        <Typography
                          variant="caption"
                          sx={{
                            fontSize: { xs: '0.7rem', sm: '0.875rem' },
                            fontWeight: 500,
                            whiteSpace: 'nowrap',
                          }}
                        >
                          {entry.name}
                        </Typography>
                      </Box>
                    ))}
                  </Box>
                </Box>
              </CardContent>
            </Card>
          </Grid>

          {/* Focus Area Progress */}
          <Grid item xs={12} md={6} sx={{ px: { xs: 0, sm: 'inherit' }, width: '100%' }}>
            <Card sx={{
              height: '100%',
              width: '100%',
              borderRadius: 1,
              boxShadow: { xs: 'none', sm: '0 4px 20px rgba(0, 0, 0, 0.08)' },
              border: { xs: 'none', sm: '1px solid rgba(0, 0, 0, 0.06)' },
              mx: { xs: 0, sm: 'inherit' },
            }}>
              <CardContent sx={{
                p: { xs: 1.5, sm: 3 },
                width: '100%',
                '&:last-child': { pb: { xs: 1.5, sm: 3 } },
                px: { xs: 1.5, sm: 3 },
              }}>
                <Typography variant="h6" fontWeight={700} gutterBottom sx={{ mb: { xs: 2, sm: 3 }, fontSize: { xs: '1rem', sm: '1.125rem' } }}>
                  {t.reports.dashboard.focusAreaProgress}
                </Typography>
                {focusAreaProgress.map((area, index) => (
                  <Box
                    key={area.id}
                    sx={{
                      mb: 3,
                      p: 2,
                      borderRadius: 2,
                      bgcolor: index % 2 === 0 ? 'grey.50' : 'transparent',
                      transition: 'all 0.2s ease',
                      '&:hover': {
                        bgcolor: 'action.hover',
                        transform: 'translateX(4px)',
                      },
                    }}
                  >
                    <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 1.5 }}>
                      <Typography variant="body1" fontWeight={600} sx={{ fontSize: '0.95rem' }}>
                        {area.name}
                      </Typography>
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        <Chip
                          label={`${area.sessions} ${t.reports.dashboard.sessionsLabel}`}
                          size="small"
                          sx={{
                            bgcolor: 'primary.50',
                            color: 'primary.700',
                            fontWeight: 600,
                            fontSize: '0.75rem',
                            height: 24,
                          }}
                        />
                        <Typography
                          variant="body2"
                          fontWeight={700}
                          sx={{
                            minWidth: 50,
                            textAlign: 'right',
                            color: area.progress >= 70 ? 'success.main' : area.progress >= 50 ? 'warning.main' : 'text.secondary',
                          }}
                        >
                          {area.progress}%
                        </Typography>
                      </Box>
                    </Box>
                    <LinearProgress
                      variant="determinate"
                      value={area.progress}
                      sx={{
                        height: 10,
                        borderRadius: 5,
                        bgcolor: 'grey.100',
                        '& .MuiLinearProgress-bar': {
                          borderRadius: 5,
                          background: area.progress >= 70
                            ? gradients.success
                            : area.progress >= 50
                              ? gradients.warm
                              : gradients.primary,
                          transition: 'all 0.3s ease',
                        },
                      }}
                    />
                  </Box>
                ))}
              </CardContent>
            </Card>
          </Grid>

          {/* Session Duration */}
          <Grid item xs={12} md={6} sx={{ px: { xs: 0, sm: 'inherit' }, width: '100%' }}>
            <Card sx={{
              height: '100%',
              width: '100%',
              borderRadius: 1,
              boxShadow: { xs: 'none', sm: '0 4px 20px rgba(0, 0, 0, 0.08)' },
              border: { xs: 'none', sm: '1px solid rgba(0, 0, 0, 0.06)' },
              mx: { xs: 0, sm: 'inherit' },
            }}>
              <CardContent sx={{
                p: { xs: 1.5, sm: 3 },
                width: '100%',
                '&:last-child': { pb: { xs: 1.5, sm: 3 } },
                px: { xs: 1.5, sm: 3 },
              }}>
                <Typography variant="h6" fontWeight={700} gutterBottom sx={{ mb: { xs: 2, sm: 3 }, fontSize: { xs: '1rem', sm: '1.125rem' } }}>
                  {t.reports.dashboard.dailySessionTime}
                </Typography>
                <Box sx={{ height: chartHeight, width: '100%', minWidth: 0, mx: { xs: -1.5, sm: 0 }, px: { xs: 1.5, sm: 0 } }}>
                  <ResponsiveContainer width="100%" height="100%">
                    <BarChart data={timeSeries} margin={{
                      top: 10,
                      right: isMobile ? 0 : 10,
                      left: isMobile ? 0 : 0,
                      bottom: isMobile ? 0 : 0
                    }}>
                      <defs>
                        <linearGradient id="barGradient" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="0%" stopColor="#6366F1" stopOpacity={1} />
                          <stop offset="100%" stopColor="#8B5CF6" stopOpacity={1} />
                        </linearGradient>
                      </defs>
                      <CartesianGrid strokeDasharray="3 3" stroke="#E2E8F0" vertical={false} />
                      <XAxis
                        dataKey="date"
                        stroke="#64748B"
                        fontSize={isMobile ? 10 : 12}
                        tickLine={false}
                        axisLine={false}
                        angle={isMobile ? -45 : 0}
                        textAnchor={isMobile ? 'end' : 'middle'}
                        height={isMobile ? 60 : 30}
                      />
                      <YAxis
                        stroke="#64748B"
                        fontSize={isMobile ? 10 : 12}
                        tickLine={false}
                        axisLine={false}
                        width={isMobile ? 35 : 50}
                      />
                      <Tooltip
                        formatter={(value) => [`${value} min`, t.reports.metrics.duration]}
                        contentStyle={{
                          background: 'white',
                          border: '1px solid #E2E8F0',
                          borderRadius: 12,
                          boxShadow: '0 8px 24px rgba(0,0,0,0.12)',
                          padding: isMobile ? '8px' : '12px',
                          fontSize: isMobile ? '0.75rem' : '0.875rem',
                        }}
                        labelStyle={{ fontWeight: 600, marginBottom: 8, fontSize: isMobile ? '0.75rem' : '0.875rem' }}
                      />
                      <Bar
                        dataKey="duration"
                        fill="url(#barGradient)"
                        radius={[8, 8, 0, 0]}
                        name={t.reports.dashboard.durationMin}
                        maxBarSize={isMobile ? 40 : 60}
                      />
                    </BarChart>
                  </ResponsiveContainer>
                </Box>
              </CardContent>
            </Card>
          </Grid>


        </Grid>
      </Box>
    </Container>
  );
};

// Enhanced Metric Card Component
const MetricCard = ({ title, value, subtitle, trend, icon, color }) => {
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('sm'));

  return (
    <Card
      sx={{
        height: '100%',
        width: '100%',
        aspectRatio: { xs: '1/1', sm: '1.2/1', md: 'auto' },
        background: '#FFFFFF',
        border: `1px solid ${color}20`,
        position: 'relative',
        overflow: 'hidden',
        transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
        borderRadius: { xs: 1, sm: 3 },
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'space-between',
        '&:hover': {
          transform: 'translateY(-4px)',
          borderColor: `${color}40`,
        },
        '&::before': {
          content: '""',
          position: 'absolute',
          top: 0,
          left: 0,
          right: 0,
          height: 3,
          background: `linear-gradient(90deg, ${color} 0%, ${color}80 100%)`,
        },
      }}
    >
      <CardContent sx={{
        p: { xs: 1, sm: 2.5 },
        width: '100%',
        height: '100%',
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'space-between',
        '&:last-child': { pb: { xs: 1, sm: 2.5 } }
      }}>
        <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', mb: 0, position: 'relative' }}>
          <Box
            sx={{
              width: { xs: 24, sm: 48 },
              height: { xs: 24, sm: 48 },
              borderRadius: { xs: 1, sm: 3 },
              background: `linear-gradient(135deg, ${color} 0%, ${color}CC 100%)`,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: 'white',
              transition: 'transform 0.3s ease',
              '& svg': {
                fontSize: { xs: '0.9rem', sm: '1.5rem' },
              },
            }}
          >
            {icon}
          </Box>
          {trend !== undefined && (
            <Chip
              size="small"
              icon={trend >= 0 ? <TrendingUp sx={{ fontSize: { xs: '0.6rem', sm: '1rem' } }} /> : <TrendingDown sx={{ fontSize: { xs: '0.6rem', sm: '1rem' } }} />}
              label={`${trend >= 0 ? '+' : ''}${trend}%`}
              sx={{
                bgcolor: trend >= 0 ? 'success.50' : 'error.50',
                color: trend >= 0 ? 'success.700' : 'error.700',
                fontWeight: 700,
                fontSize: { xs: '0.5rem', sm: '0.75rem' },
                height: { xs: 18, sm: 26 },
                pl: { xs: 0.5, sm: 0 },
                '& .MuiChip-icon': {
                  marginLeft: { xs: '2px', sm: '8px' },
                  marginRight: { xs: '-4px', sm: '0' },
                },
                '& .MuiChip-label': {
                  paddingLeft: { xs: '4px', sm: '8px' },
                  paddingRight: { xs: '4px', sm: '8px' },
                },
                border: `1px solid ${trend >= 0 ? 'success.200' : 'error.200'}`,
                position: { xs: 'absolute', sm: 'static' },
                top: { xs: -4, sm: 'auto' },
                right: { xs: -4, sm: 'auto' },
                transform: { xs: 'scale(0.85)', sm: 'none' },
                transformOrigin: 'top right',
              }}
            />
          )}
        </Box>
        <Box sx={{ mt: 'auto', pt: { xs: 1, sm: 0 } }}>
          <Typography
            variant="h3"
            fontWeight={800}
            sx={{
              fontSize: { xs: '1rem', sm: '1.75rem', md: '2rem' },
              lineHeight: 1,
              mb: { xs: 0.5, sm: 0 },
              background: `linear-gradient(135deg, ${color} 0%, ${color}CC 100%)`,
              WebkitBackgroundClip: 'text',
              WebkitTextFillColor: 'transparent',
              backgroundClip: 'text',
            }}
          >
            {value}
          </Typography>
          <Typography
            variant="body2"
            color="text.secondary"
            fontWeight={500}
            sx={{
              fontSize: { xs: '0.6rem', sm: '0.875rem' },
              lineHeight: 1.1,
              display: '-webkit-box',
              WebkitLineClamp: 2,
              WebkitBoxOrient: 'vertical',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
            }}
          >
            {subtitle || title}
          </Typography>
        </Box>
      </CardContent>
    </Card>
  );
};

export default ReportDashboard;
