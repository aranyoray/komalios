/**
 * Extended Report Component
 * Detailed analysis with exportable data
 */

import React, { useState, useEffect } from 'react';
import {
  Box,
  Container,
  Typography,
  Grid,
  Card,
  CardContent,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Button,
  Divider,
  Chip,
  Paper,
  useMediaQuery,
  useTheme,
} from '@mui/material';
import {
  Download,
  Print,
  Share,
  CheckCircle,
  Warning,
  Info,
  TrendingUp,
  TrendingDown,
  Visibility,
  CalendarToday,
  LocalFireDepartment,
} from '@mui/icons-material';
import {
  RadarChart,
  PolarGrid,
  PolarAngleAxis,
  PolarRadiusAxis,
  Radar,
  ResponsiveContainer,
  ScatterChart,
  Scatter,
  ZAxis,
  Tooltip,
} from 'recharts';
import { analytics } from '../../services/analytics';
import { useLanguage } from '../../i18n/LanguageContext';
import { format } from 'date-fns';
import { gradients } from '../../theme';

const ExtendedReport = ({ learnerId, learnerName, period = 'month', learnerProfile = null }) => {
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
  const { t } = useLanguage();
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);

  // Standard chart height for consistency
  const chartHeight = isMobile ? 280 : 300;

  useEffect(() => {
    loadData();
  }, [learnerId, period, learnerProfile]);

  const loadData = async () => {
    try {
      console.log('[ExtendedReport] Loading analytics with learner profile:', learnerProfile);
      const analyticsData = await analytics.getAnalytics(learnerId, period, learnerProfile);
      setData(analyticsData);
    } catch (err) {
      console.error('Failed to load report data:', err);
    } finally {
      setLoading(false);
    }
  };

  if (loading || !data) {
    return <Box sx={{ p: 4 }}>{t.reports.extendedReport.loading}</Box>;
  }

  const { summary, timeSeries, focusAreaProgress, percentiles, recentSessions, insights } = data;

  // Skills radar data
  const skillsRadar = [
    { skill: 'Attention', value: summary.avgAttention, fullMark: 100 },
    { skill: 'Engagement', value: summary.avgEngagement, fullMark: 100 },
    { skill: 'Completion', value: summary.avgCompletion, fullMark: 100 },
    { skill: 'Consistency', value: Math.min(100, summary.streakDays * 10), fullMark: 100 },
    { skill: 'Duration', value: Math.min(100, summary.avgDuration * 6), fullMark: 100 },
  ];

  // Performance benchmarks
  const benchmarks = [
    { metric: 'Attention Score', value: summary.avgAttention, benchmark: 75, unit: '%' },
    { metric: 'Engagement Score', value: summary.avgEngagement, benchmark: 70, unit: '%' },
    { metric: 'Session Completion', value: summary.avgCompletion, benchmark: 80, unit: '%' },
    { metric: 'Avg Session Duration', value: summary.avgDuration, benchmark: 15, unit: 'min' },
    { metric: 'Blink Rate', value: summary.avgBlinkRate, benchmark: 15, unit: '/min' },
    { metric: 'Sessions Completed', value: summary.totalSessions, benchmark: period === 'month' ? 20 : 5, unit: '' },
  ];

  return (
    <Container
      maxWidth="lg"
      sx={{
        py: { xs: 2, sm: 3, md: 4 },
        px: { xs: 1, sm: 2, md: 3 },
        width: '100%',
      }}
    >
      {/* Enhanced Report Header */}
      {/* <Paper 
        sx={{ 
          p: { xs: 3, md: 4 }, 
          mb: 4, 
          background: gradients.primary, 
          color: 'white',
          borderRadius: 4,
          boxShadow: '0 8px 32px rgba(99, 102, 241, 0.3)',
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
        <Grid container spacing={3} alignItems="center" sx={{ position: 'relative', zIndex: 1 }}>
          <Grid item xs={12} md={8}>
            <Typography variant="h4" fontWeight={700} gutterBottom sx={{ fontSize: { xs: '1.75rem', md: '2rem' } }}>
              Extended Progress Report
            </Typography>
            <Typography variant="h6" sx={{ opacity: 0.95, fontWeight: 600, mb: 1 }}>
              {learnerName}
            </Typography>
            <Typography variant="body2" sx={{ opacity: 0.9, fontSize: '0.95rem' }}>
              Report generated: {format(new Date(), 'MMMM d, yyyy')}
            </Typography>
          </Grid>
          <Grid item xs={12} md={4}>
            <Box sx={{ display: 'flex', gap: 1.5, flexWrap: 'wrap', justifyContent: { xs: 'flex-start', md: 'flex-end' } }}>
              <Button 
                variant="contained" 
                startIcon={<Download />} 
                sx={{ 
                  bgcolor: 'white', 
                  color: 'primary.main',
                  fontWeight: 600,
                  '&:hover': {
                    bgcolor: 'grey.50',
                    transform: 'translateY(-2px)',
                    boxShadow: '0 4px 12px rgba(0,0,0,0.15)',
                  },
                }}
              >
                Export PDF
              </Button>
              <Button 
                variant="outlined" 
                startIcon={<Print />} 
                sx={{ 
                  borderColor: 'rgba(255,255,255,0.5)',
                  borderWidth: 2,
                  color: 'white',
                  fontWeight: 600,
                  '&:hover': {
                    borderColor: 'white',
                    bgcolor: 'rgba(255,255,255,0.1)',
                    borderWidth: 2,
                  },
                }}
              >
                Print
              </Button>
            </Box>
          </Grid>
        </Grid>
      </Paper> */}

      {/* Enhanced Executive Summary */}
      <Card sx={{
        mb: { xs: 3, sm: 4 },
        border: { xs: 'none', sm: '1px solid rgba(99, 102, 241, 0.1)' },
        borderRadius: 1,
        boxShadow: { xs: 'none', sm: '0 4px 20px rgba(0, 0, 0, 0.08)' },
        mx: { xs: 0, sm: 'inherit' },
        width: '100%',
      }}>
        <CardContent sx={{
          p: { xs: 2.5, sm: 3, md: 4 },
          px: { xs: 2.5, sm: 3, md: 4 },
        }}>
          <Box sx={{ mb: { xs: 2.5, sm: 3 } }}>
            <Typography
              variant="h5"
              fontWeight={700}
              sx={{
                fontSize: { xs: '1.25rem', sm: '1.5rem', md: '1.75rem' },
                background: gradients.primary,
                WebkitBackgroundClip: 'text',
                WebkitTextFillColor: 'transparent',
                backgroundClip: 'text',
              }}
            >
              {t.reports.extendedReport.executiveSummary}
            </Typography>
            <Typography
              variant="body2"
              color="text.secondary"
              sx={{
                mt: 0.5,
                fontSize: { xs: '0.875rem', sm: '1rem' },
              }}
            >
              {t.reports.extendedReport.keyMetricsAtGlance}
            </Typography>
          </Box>
          <Box sx={{
            display: 'grid',
            gridTemplateColumns: 'repeat(3, 1fr)',
            gap: { xs: 1, sm: 2, md: 3 }
          }}>
            <Box
              sx={{
                position: 'relative',
                p: { xs: 1, sm: 2.5 },
                borderRadius: 1,
                background: '#FFFFFF',
                border: '1px solid rgba(99, 102, 241, 0.15)',
                transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
                overflow: 'hidden',
                textAlign: 'center',
                display: 'flex',
                flexDirection: 'column',
                justifyContent: 'space-between',
                '&:hover': {
                  transform: 'translateY(-4px)',
                  borderColor: 'rgba(99, 102, 241, 0.3)',
                },
                '&::before': {
                  content: '""',
                  position: 'absolute',
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 4,
                  background: gradients.primary,
                },
              }}
            >
              <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'center', mb: { xs: 1, sm: 2 }, gap: 1 }}>
                <Box
                  sx={{
                    width: { xs: 24, sm: 56 },
                    height: { xs: 24, sm: 56 },
                    borderRadius: { xs: 1, sm: 2 },
                    background: gradients.primary,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    color: 'white',
                  }}
                >
                  <Visibility sx={{ fontSize: { xs: 14, sm: 24 } }} />
                </Box>
                {summary.attentionTrend !== undefined && (
                  <Chip
                    size="small"
                    icon={summary.attentionTrend >= 0 ? <TrendingUp sx={{ fontSize: { xs: 10, sm: 16 } }} /> : <TrendingDown sx={{ fontSize: { xs: 10, sm: 16 } }} />}
                    label={summary.attentionTrend >= 0 ? `+${summary.attentionTrend}%` : `${summary.attentionTrend}%`}
                    sx={{
                      bgcolor: summary.attentionTrend >= 0 ? 'success.50' : 'error.50',
                      color: summary.attentionTrend >= 0 ? 'success.700' : 'error.700',
                      fontWeight: 700,
                      fontSize: { xs: '0.6rem', sm: '0.75rem' },
                      height: { xs: 20, sm: 28 },
                      border: `1px solid ${summary.attentionTrend >= 0 ? 'success.200' : 'error.200'}`,
                      position: { xs: 'absolute', sm: 'static' },
                      top: 6,
                      right: 6,
                      '& .MuiChip-icon': { margin: '0 2px 0 4px' },
                      display: { xs: 'none', sm: 'inline-flex' } // Hide trend chip on very small screens if needed, or style absolute
                    }}
                  />
                )}
              </Box>
              <Typography
                variant="h2"
                fontWeight={800}
                sx={{
                  fontSize: { xs: '1.25rem', sm: '2.25rem', md: '2.5rem' },
                  background: gradients.primary,
                  WebkitBackgroundClip: 'text',
                  WebkitTextFillColor: 'transparent',
                  backgroundClip: 'text',
                  mb: 0.5,
                  lineHeight: 1.1,
                }}
              >
                {summary.avgAttention}%
              </Typography>
              <Typography
                variant="body1"
                fontWeight={600}
                sx={{
                  mb: 0.5,
                  fontSize: { xs: '0.65rem', sm: '0.9rem' },
                  lineHeight: 1.2,
                  display: '-webkit-box',
                  WebkitLineClamp: 2,
                  WebkitBoxOrient: 'vertical',
                  overflow: 'hidden',
                }}
              >
                {t.reports.extendedReport.overallAttentionScore}
              </Typography>
              <Typography
                variant="body2"
                color="text.secondary"
                sx={{
                  fontSize: { xs: '0.65rem', sm: '0.875rem' },
                  display: { xs: 'none', sm: 'block' },
                }}
              >
                {t.reports.extendedReport.averageAcrossSessions}
              </Typography>
            </Box>

            <Box
              sx={{
                position: 'relative',
                p: { xs: 1, sm: 2.5 },
                borderRadius: 1,
                background: '#FFFFFF',
                border: '1px solid rgba(236, 72, 153, 0.15)',
                transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
                overflow: 'hidden',
                textAlign: 'center',
                display: 'flex',
                flexDirection: 'column',
                justifyContent: 'space-between',
                '&:hover': {
                  transform: 'translateY(-4px)',
                  borderColor: 'rgba(236, 72, 153, 0.3)',
                },
                '&::before': {
                  content: '""',
                  position: 'absolute',
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 4,
                  background: gradients.secondary,
                },
              }}
            >
              <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'center', mb: { xs: 1, sm: 2 } }}>
                <Box
                  sx={{
                    width: { xs: 24, sm: 56 },
                    height: { xs: 24, sm: 56 },
                    borderRadius: { xs: 1, sm: 2 },
                    background: gradients.secondary,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    color: 'white',
                  }}
                >
                  <CalendarToday sx={{ fontSize: { xs: 14, sm: 24 } }} />
                </Box>
              </Box>
              <Typography
                variant="h2"
                fontWeight={800}
                sx={{
                  fontSize: { xs: '1.25rem', sm: '2.25rem', md: '2.5rem' },
                  background: gradients.secondary,
                  WebkitBackgroundClip: 'text',
                  WebkitTextFillColor: 'transparent',
                  backgroundClip: 'text',
                  mb: 0.5,
                  lineHeight: 1.1,
                }}
              >
                {summary.totalSessions}
              </Typography>
              <Typography
                variant="body1"
                fontWeight={600}
                sx={{
                  mb: 0.5,
                  fontSize: { xs: '0.65rem', sm: '0.9rem' },
                  lineHeight: 1.2,
                  display: '-webkit-box',
                  WebkitLineClamp: 2,
                  WebkitBoxOrient: 'vertical',
                  overflow: 'hidden',
                }}
              >
                {t.reports.extendedReport.totalSessions}
              </Typography>
              <Typography
                variant="body2"
                color="text.secondary"
                sx={{
                  fontSize: { xs: '0.65rem', sm: '0.875rem' },
                  display: { xs: 'none', sm: 'block' },
                }}
              >
                {summary.totalDuration} {t.reports.extendedReport.minutesTotalPractice}
              </Typography>
            </Box>

            <Box
              sx={{
                position: 'relative',
                p: { xs: 1, sm: 2.5 },
                borderRadius: 1,
                background: '#FFFFFF',
                border: '1px solid rgba(16, 185, 129, 0.15)',
                transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
                overflow: 'hidden',
                textAlign: 'center',
                display: 'flex',
                flexDirection: 'column',
                justifyContent: 'space-between',
                '&:hover': {
                  transform: 'translateY(-4px)',
                  borderColor: 'rgba(16, 185, 129, 0.3)',
                },
                '&::before': {
                  content: '""',
                  position: 'absolute',
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 4,
                  background: gradients.success,
                },
              }}
            >
              <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'center', mb: { xs: 1, sm: 2 } }}>
                <Box
                  sx={{
                    width: { xs: 24, sm: 56 },
                    height: { xs: 24, sm: 56 },
                    borderRadius: { xs: 1, sm: 2 },
                    background: gradients.success,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    color: 'white',
                  }}
                >
                  <LocalFireDepartment sx={{ fontSize: { xs: 14, sm: 24 } }} />
                </Box>
              </Box>
              <Typography
                variant="h2"
                fontWeight={800}
                sx={{
                  fontSize: { xs: '1.25rem', sm: '2.25rem', md: '2.5rem' },
                  background: gradients.success,
                  WebkitBackgroundClip: 'text',
                  WebkitTextFillColor: 'transparent',
                  backgroundClip: 'text',
                  mb: 0.5,
                  lineHeight: 1.1,
                }}
              >
                {summary.streakDays}
              </Typography>
              <Typography
                variant="body1"
                fontWeight={600}
                sx={{
                  mb: 0.5,
                  fontSize: { xs: '0.65rem', sm: '0.9rem' },
                  lineHeight: 1.2,
                  display: '-webkit-box',
                  WebkitLineClamp: 2,
                  WebkitBoxOrient: 'vertical',
                  overflow: 'hidden',
                }}
              >
                {t.reports.extendedReport.dayStreak}
              </Typography>
              <Typography
                variant="body2"
                color="text.secondary"
                sx={{
                  fontSize: { xs: '0.65rem', sm: '0.875rem' },
                  display: { xs: 'none', sm: 'block' },
                }}
              >
                {t.reports.extendedReport.consecutiveDays}
              </Typography>
            </Box>
          </Box>
        </CardContent>
      </Card>

      {/* Performance Metrics */}
      <Grid container spacing={{ xs: 2, sm: 3, md: 4 }} sx={{ px: { xs: 0, sm: 'inherit' } }}>
        {/* Skills Radar */}
        <Grid item xs={12} md={6} sx={{ px: { xs: 0, sm: 'inherit' }, width: '100%', mb: { xs: 2, sm: 0 } }}>
          <Card sx={{
            height: '100%',
            width: '100%',
            borderRadius: 1,
            border: { xs: 'none', sm: '1px solid rgba(0, 0, 0, 0.06)' },
            boxShadow: { xs: 'none', sm: '0 4px 20px rgba(0, 0, 0, 0.08)' },
            mx: { xs: 0, sm: 'inherit' },
          }}>
            <CardContent sx={{
              p: { xs: 2.5, sm: 3 },
              width: '100%',
              px: { xs: 2.5, sm: 3 },
            }}>
              <Typography variant="h6" fontWeight={600} gutterBottom sx={{ fontSize: { xs: '1rem', sm: '1.125rem' } }}>
                {t.reports.extendedReport.skillsOverview}
              </Typography>
              <Box sx={{ height: chartHeight, width: '100%', minWidth: 0 }}>
                <ResponsiveContainer width="100%" height="100%">
                  <RadarChart data={skillsRadar}>
                    <PolarGrid stroke="#E2E8F0" />
                    <PolarAngleAxis
                      dataKey="skill"
                      fontSize={isMobile ? 10 : 12}
                      tick={{ fontSize: isMobile ? 10 : 12 }}
                    />
                    <PolarRadiusAxis
                      angle={30}
                      domain={[0, 100]}
                      fontSize={isMobile ? 8 : 10}
                      tick={{ fontSize: isMobile ? 8 : 10 }}
                    />
                    <Radar
                      name="Score"
                      dataKey="value"
                      stroke="#6366F1"
                      fill="#6366F1"
                      fillOpacity={0.3}
                      strokeWidth={isMobile ? 1.5 : 2}
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
                    />
                  </RadarChart>
                </ResponsiveContainer>
              </Box>
            </CardContent>
          </Card>
        </Grid>

        {/* Benchmark Comparison */}
        <Grid item xs={12} md={6} sx={{ mb: { xs: 2, sm: 0 } }}>
          <Card sx={{
            height: '100%',
            width: '100%',
            borderRadius: 1,
            border: { xs: 'none', sm: '1px solid rgba(0, 0, 0, 0.06)' },
            boxShadow: { xs: 'none', sm: '0 4px 20px rgba(0, 0, 0, 0.08)' },
            mx: { xs: 0, sm: 'inherit' },
          }}>
            <CardContent sx={{ p: { xs: 2, sm: 3 }, width: '100%' }}>
              <Typography variant="h6" fontWeight={600} gutterBottom sx={{ fontSize: { xs: '1rem', sm: '1.125rem' }, mb: 2 }}>
                {t.reports.extendedReport.performanceVsBenchmarks}
              </Typography>
              <TableContainer sx={{ overflowX: 'auto', maxWidth: '100%' }}>
                <Table size="small" sx={{ minWidth: isMobile ? 400 : 'auto' }}>
                  <TableHead>
                    <TableRow sx={{ bgcolor: 'grey.50' }}>
                      <TableCell sx={{ fontWeight: 700, fontSize: { xs: '0.75rem', sm: '0.875rem' } }}>{t.reports.extendedReport.metric}</TableCell>
                      <TableCell align="right" sx={{ fontWeight: 700, fontSize: { xs: '0.75rem', sm: '0.875rem' } }}>{t.reports.extendedReport.value}</TableCell>
                      <TableCell align="right" sx={{ fontWeight: 700, fontSize: { xs: '0.75rem', sm: '0.875rem' } }}>{t.reports.extendedReport.target}</TableCell>
                      <TableCell align="center" sx={{ fontWeight: 700, fontSize: { xs: '0.75rem', sm: '0.875rem' } }}>{t.reports.extendedReport.status}</TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {benchmarks.map((row, index) => {
                      const isGood = row.value >= row.benchmark;
                      return (
                        <TableRow
                          key={row.metric}
                          sx={{
                            '&:hover': { bgcolor: 'action.hover' },
                            bgcolor: index % 2 === 0 ? 'transparent' : 'grey.50',
                          }}
                        >
                          <TableCell sx={{ fontWeight: 500 }}>{row.metric}</TableCell>
                          <TableCell align="right" sx={{ fontWeight: 700, fontSize: '0.95rem' }}>
                            {row.value}{row.unit}
                          </TableCell>
                          <TableCell align="right" sx={{ color: 'text.secondary', fontWeight: 500 }}>
                            {row.benchmark}{row.unit}
                          </TableCell>
                          <TableCell align="center">
                            {isGood ? (
                              <CheckCircle color="success" fontSize="small" />
                            ) : (
                              <Warning color="warning" fontSize="small" />
                            )}
                          </TableCell>
                        </TableRow>
                      );
                    })}
                  </TableBody>
                </Table>
              </TableContainer>
            </CardContent>
          </Card>
        </Grid>

        {/* Percentile Rankings - Hidden */}
        {false && (
          <Grid item xs={12} md={6} sx={{ mb: { xs: 2, sm: 0 } }}>
            <Card sx={{
              width: '100%',
              borderRadius: 1,
              border: { xs: 'none', sm: '1px solid rgba(0, 0, 0, 0.06)' },
              boxShadow: { xs: 'none', sm: '0 4px 20px rgba(0, 0, 0, 0.08)' },
              mx: { xs: 0, sm: 'inherit' },
            }}>
              <CardContent sx={{ p: { xs: 2, sm: 3 }, width: '100%' }}>
                <Typography variant="h6" fontWeight={600} gutterBottom sx={{ fontSize: { xs: '1rem', sm: '1.125rem' } }}>
                  Performance Distribution
                </Typography>
                <Box sx={{ mb: 3 }}>
                  <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                    Attention Score Percentiles
                  </Typography>
                  <Grid container spacing={2}>
                    {Object.entries(percentiles.attention).map(([key, value]) => (
                      <Grid item xs={3} key={key}>
                        <Box sx={{ textAlign: 'center' }}>
                          <Typography variant="h5" fontWeight={600} color="primary.main">
                            {value}
                          </Typography>
                          <Typography variant="caption" color="text.secondary">
                            {key.toUpperCase()}
                          </Typography>
                        </Box>
                      </Grid>
                    ))}
                  </Grid>
                </Box>
                <Divider sx={{ my: 2 }} />
                <Box>
                  <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                    Engagement Score Percentiles
                  </Typography>
                  <Grid container spacing={2}>
                    {Object.entries(percentiles.engagement).map(([key, value]) => (
                      <Grid item xs={3} key={key}>
                        <Box sx={{ textAlign: 'center' }}>
                          <Typography variant="h5" fontWeight={600} color="secondary.main">
                            {value}
                          </Typography>
                          <Typography variant="caption" color="text.secondary">
                            {key.toUpperCase()}
                          </Typography>
                        </Box>
                      </Grid>
                    ))}
                  </Grid>
                </Box>
              </CardContent>
            </Card>
          </Grid>
        )}

        {/* Focus Area Details */}
        <Grid item xs={12} md={12} sx={{ px: { xs: 0, sm: 'inherit' }, width: '100%', mb: { xs: 2, sm: 0 } }}>
          <Card sx={{
            width: '100%',
            borderRadius: 1,
            border: { xs: 'none', sm: '1px solid rgba(0, 0, 0, 0.06)' },
            boxShadow: { xs: 'none', sm: '0 4px 20px rgba(0, 0, 0, 0.08)' },
            mx: { xs: 0, sm: 'inherit' },
          }}>
            <CardContent sx={{ p: { xs: 2, sm: 3 }, width: '100%' }}>
              <Typography variant="h6" fontWeight={600} gutterBottom sx={{ fontSize: { xs: '1rem', sm: '1.125rem' }, mb: 2 }}>
                {t.reports.extendedReport.focusAreaBreakdown}
              </Typography>
              <TableContainer sx={{ overflowX: 'auto', maxWidth: '100%' }}>
                <Table size="small" sx={{ minWidth: isMobile ? 300 : 'auto' }}>
                  <TableHead>
                    <TableRow sx={{ bgcolor: 'grey.50' }}>
                      <TableCell sx={{ fontWeight: 700, fontSize: { xs: '0.75rem', sm: '0.875rem' } }}>{t.reports.extendedReport.focusArea}</TableCell>
                      <TableCell align="center" sx={{ fontWeight: 700, fontSize: { xs: '0.75rem', sm: '0.875rem' } }}>{t.reports.dashboard.sessions}</TableCell>
                      <TableCell align="center" sx={{ fontWeight: 700, fontSize: { xs: '0.75rem', sm: '0.875rem' } }}>{t.reports.extendedReport.successRate}</TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {focusAreaProgress.map((area, index) => (
                      <TableRow
                        key={area.id}
                        sx={{
                          '&:hover': { bgcolor: 'action.hover' },
                          bgcolor: index % 2 === 0 ? 'transparent' : 'grey.50',
                        }}
                      >
                        <TableCell sx={{ fontWeight: 500 }}>{area.name}</TableCell>
                        <TableCell align="center" sx={{ fontWeight: 600 }}>{area.sessions}</TableCell>
                        <TableCell align="center">
                          <Chip
                            size="small"
                            label={`${area.progress}%`}
                            color={area.progress >= 70 ? 'success' : area.progress >= 50 ? 'warning' : 'default'}
                            sx={{ fontWeight: 600, minWidth: 70 }}
                          />
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </TableContainer>
            </CardContent>
          </Card>
        </Grid>

        {/* Recent Sessions */}
        <Grid item xs={12} sx={{ mb: { xs: 2, sm: 0 } }}>
          <Card sx={{
            width: '100%',
            borderRadius: 1,
            border: { xs: 'none', sm: '1px solid rgba(0, 0, 0, 0.06)' },
            boxShadow: { xs: 'none', sm: '0 4px 20px rgba(0, 0, 0, 0.08)' },
            mx: { xs: 0, sm: 'inherit' },
          }}>
            <CardContent sx={{ p: { xs: 2, sm: 3 }, width: '100%' }}>
              <Typography variant="h6" fontWeight={600} gutterBottom sx={{ fontSize: { xs: '1rem', sm: '1.125rem' }, mb: 2 }}>
                {t.reports.extendedReport.recentSessionDetails}
              </Typography>
              <TableContainer sx={{ overflowX: 'auto', maxWidth: '100%' }}>
                <Table sx={{ minWidth: isMobile ? 600 : 'auto' }}>
                  <TableHead>
                    <TableRow sx={{ bgcolor: 'grey.50' }}>
                      <TableCell sx={{ fontWeight: 700, fontSize: { xs: '0.75rem', sm: '0.875rem' } }}>{t.reports.extendedReport.date}</TableCell>
                      <TableCell align="center" sx={{ fontWeight: 700, fontSize: { xs: '0.75rem', sm: '0.875rem' } }}>{t.reports.extendedReport.duration}</TableCell>
                      <TableCell align="center" sx={{ fontWeight: 700, fontSize: { xs: '0.75rem', sm: '0.875rem' } }}>{t.reports.dashboard.attention}</TableCell>
                      <TableCell align="center" sx={{ fontWeight: 700, fontSize: { xs: '0.75rem', sm: '0.875rem' } }}>{t.reports.dashboard.engagement}</TableCell>
                      <TableCell align="center" sx={{ fontWeight: 700, fontSize: { xs: '0.75rem', sm: '0.875rem' } }}>{t.reports.dashboard.completion}</TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {recentSessions.map((session, index) => (
                      <TableRow
                        key={index}
                        sx={{
                          '&:hover': { bgcolor: 'action.hover' },
                          bgcolor: index % 2 === 0 ? 'transparent' : 'grey.50',
                        }}
                      >
                        <TableCell sx={{ fontWeight: 500 }}>
                          {format(new Date(session.session_date), 'MMM d, yyyy h:mm a')}
                        </TableCell>
                        <TableCell align="center" sx={{ fontWeight: 600 }}>
                          {session.duration_minutes} min
                        </TableCell>
                        <TableCell align="center">
                          <Chip
                            label={`${session.attention_score}%`}
                            size="small"
                            sx={{
                              fontWeight: 700,
                              bgcolor: session.attention_score >= 75 ? 'success.50' : 'grey.50',
                              color: session.attention_score >= 75 ? 'success.700' : 'text.primary',
                              minWidth: 70,
                            }}
                          />
                        </TableCell>
                        <TableCell align="center">
                          <Chip
                            label={`${session.engagement_score}%`}
                            size="small"
                            sx={{
                              fontWeight: 700,
                              bgcolor: session.engagement_score >= 70 ? 'success.50' : 'grey.50',
                              color: session.engagement_score >= 70 ? 'success.700' : 'text.primary',
                              minWidth: 70,
                            }}
                          />
                        </TableCell>
                        <TableCell align="center">
                          <Chip
                            label={`${session.completion_rate}%`}
                            size="small"
                            sx={{
                              fontWeight: 700,
                              bgcolor: session.completion_rate >= 80 ? 'success.50' : 'grey.50',
                              color: session.completion_rate >= 80 ? 'success.700' : 'text.primary',
                              minWidth: 70,
                            }}
                          />
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </TableContainer>
            </CardContent>
          </Card>
        </Grid>


      </Grid>
    </Container >
  );
};

export default ExtendedReport;
