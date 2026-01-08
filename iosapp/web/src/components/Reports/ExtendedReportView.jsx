/**
 * Extended Monthly Report View
 * Accordion format with graphs per subdomain, detailed analytics
 */

import React from 'react';
import {
  Box,
  Paper,
  Typography,
  Accordion,
  AccordionSummary,
  AccordionDetails,
  Grid,
  Chip,
  LinearProgress,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow
} from '@mui/material';
import ExpandMoreIcon from '@mui/icons-material/ExpandMore';
import TrendingUpIcon from '@mui/icons-material/TrendingUp';
import TrendingDownIcon from '@mui/icons-material/TrendingDown';
import TrendingFlatIcon from '@mui/icons-material/TrendingFlat';
import { Line } from 'react-chartjs-2';

const ExtendedReportView = ({ report }) => {
  if (!report) return null;

  const getTrendIcon = (trend) => {
    if (trend === 'improving') return <TrendingUpIcon fontSize="small" color="success" />;
    if (trend === 'declining') return <TrendingDownIcon fontSize="small" color="error" />;
    return <TrendingFlatIcon fontSize="small" color="action" />;
  };

  const renderSubdomainGraph = (graphData) => {
    if (!graphData || !graphData.available) {
      return (
        <Typography variant="body2" color="text.secondary" align="center">
          More sessions needed to show trend graph
        </Typography>
      );
    }

    const data = {
      labels: graphData.labels,
      datasets: [
        {
          label: 'Score',
          data: graphData.data,
          borderColor: 'rgb(99, 102, 241)',
          backgroundColor: 'rgba(99, 102, 241, 0.1)',
          fill: true,
          tension: 0.4
        },
        {
          label: 'Target (70)',
          data: Array(graphData.data.length).fill(70),
          borderColor: 'rgba(16, 185, 129, 0.5)',
          borderDash: [5, 5],
          borderWidth: 2,
          fill: false,
          pointRadius: 0
        }
      ]
    };

    const options = {
      responsive: true,
      maintainAspectRatio: false,
      scales: {
        y: {
          beginAtZero: true,
          max: 100,
          ticks: {
            stepSize: 20
          }
        }
      },
      plugins: {
        legend: {
          display: true,
          position: 'top'
        }
      }
    };

    return (
      <Box sx={{ height: 250 }}>
        <Line data={data} options={options} />
      </Box>
    );
  };

  return (
    <Box sx={{ maxWidth: 1200, mx: 'auto', p: 2 }}>
      {/* Header */}
      <Paper sx={{ p: 3, mb: 3 }}>
        <Typography variant="h4" fontWeight="bold" gutterBottom>
          Extended Progress Report
        </Typography>
        <Typography variant="body1" color="text.secondary">
          {report.learnerName} • Age {report.age}
        </Typography>
        <Typography variant="body2" color="text.secondary">
          Report Date: {new Date(report.reportDate).toLocaleDateString()}
        </Typography>
      </Paper>

      {/* Domains with Subdomain Breakdown */}
      {Object.entries(report.domains).map(([domainId, domain]) => (
        <Accordion key={domainId} defaultExpanded={false}>
          <AccordionSummary expandIcon={<ExpandMoreIcon />}>
            <Box sx={{ display: 'flex', alignItems: 'center', width: '100%' }}>
              <Box
                sx={{
                  width: 12,
                  height: 12,
                  borderRadius: '50%',
                  bgcolor: domain.color,
                  mr: 2
                }}
              />
              <Typography variant="h6" fontWeight="bold" sx={{ flex: 1 }}>
                {domain.name}
              </Typography>
              <Chip
                label={`${domain.overallScore}/100`}
                sx={{
                  bgcolor: domain.color,
                  color: 'white',
                  fontWeight: 'bold',
                  mr: 2
                }}
              />
            </Box>
          </AccordionSummary>
          <AccordionDetails>
            {/* Narrative Summary */}
            {report.narrativeSummaries && report.narrativeSummaries[domainId] && (
              <Paper sx={{ p: 2, mb: 3, bgcolor: 'grey.50' }}>
                <Typography variant="body1">
                  {report.narrativeSummaries[domainId]}
                </Typography>
              </Paper>
            )}

            {/* Subdomains Table */}
            <TableContainer component={Paper} sx={{ mb: 3 }}>
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell><strong>Subdomain</strong></TableCell>
                    <TableCell align="center"><strong>Score</strong></TableCell>
                    <TableCell align="center"><strong>Trend</strong></TableCell>
                    <TableCell align="center"><strong>Generalization</strong></TableCell>
                    <TableCell align="center"><strong>Understanding</strong></TableCell>
                    <TableCell align="center"><strong>Sessions</strong></TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {Object.values(domain.subdomains).map((subdomain) => (
                    <TableRow key={subdomain.id}>
                      <TableCell>{subdomain.name}</TableCell>
                      <TableCell align="center">
                        <Chip
                          label={subdomain.score}
                          size="small"
                          sx={{
                            bgcolor:
                              subdomain.score >= 75
                                ? 'success.light'
                                : subdomain.score >= 40
                                ? 'warning.light'
                                : 'error.light',
                            color: 'white'
                          }}
                        />
                      </TableCell>
                      <TableCell align="center">
                        <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                          {getTrendIcon(subdomain.scoreTrend?.direction)}
                          <Typography variant="caption" sx={{ ml: 0.5 }}>
                            {subdomain.scoreTrend?.change > 0 ? '+' : ''}
                            {subdomain.scoreTrend?.change || 0}
                          </Typography>
                        </Box>
                      </TableCell>
                      <TableCell align="center">
                        {subdomain.generalizationScore || 'N/A'}
                      </TableCell>
                      <TableCell align="center">
                        {subdomain.understandingScore || 'N/A'}
                      </TableCell>
                      <TableCell align="center">
                        {subdomain.sessionsContributed || 0}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>

            {/* Individual Subdomain Details */}
            {Object.values(domain.subdomains).map((subdomain) => (
              <Accordion key={subdomain.id} sx={{ mb: 2 }}>
                <AccordionSummary expandIcon={<ExpandMoreIcon />}>
                  <Typography variant="subtitle1" fontWeight="medium">
                    {subdomain.name} ({subdomain.score}/100)
                  </Typography>
                </AccordionSummary>
                <AccordionDetails>
                  {/* Insights */}
                  {subdomain.insights && (
                    <Paper sx={{ p: 2, mb: 2, bgcolor: 'info.50' }}>
                      <Typography variant="body2" color="text.secondary" gutterBottom>
                        <strong>Insights:</strong>
                      </Typography>
                      <Typography variant="body2">
                        {subdomain.insights}
                      </Typography>
                    </Paper>
                  )}

                  {/* Metrics Breakdown */}
                  <Typography variant="subtitle2" gutterBottom>
                    Metrics:
                  </Typography>
                  <Grid container spacing={2} sx={{ mb: 2 }}>
                    {Object.values(subdomain.metrics).map((metric) => (
                      <Grid item xs={12} sm={6} key={metric.id}>
                        <Paper sx={{ p: 2 }}>
                          <Typography variant="caption" color="text.secondary">
                            {metric.name}
                          </Typography>
                          <Box sx={{ display: 'flex', alignItems: 'center', mt: 1 }}>
                            <Typography variant="h6" fontWeight="bold" sx={{ mr: 2 }}>
                              {metric.score}/100
                            </Typography>
                            <LinearProgress
                              variant="determinate"
                              value={metric.score}
                              sx={{ flex: 1, height: 6, borderRadius: 1 }}
                            />
                          </Box>
                          {metric.raw && (
                            <Typography variant="caption" color="text.secondary" sx={{ mt: 0.5, display: 'block' }}>
                              {JSON.stringify(metric.raw)}
                            </Typography>
                          )}
                        </Paper>
                      </Grid>
                    ))}
                  </Grid>

                  {/* Trend Graph */}
                  <Typography variant="subtitle2" gutterBottom>
                    Progress Over Time:
                  </Typography>
                  {renderSubdomainGraph(subdomain.graphData)}
                </AccordionDetails>
              </Accordion>
            ))}
          </AccordionDetails>
        </Accordion>
      ))}

      {/* Correlation Insights */}
      {report.correlationInsights && report.correlationInsights.available && (
        <Paper sx={{ p: 3, mt: 3 }}>
          <Typography variant="h6" fontWeight="bold" gutterBottom>
            Behavioral Patterns
          </Typography>
          <Typography variant="body2" color="text.secondary" gutterBottom>
            Cross-modal correlations detected: {report.correlationInsights.totalPatterns}
          </Typography>
          <Grid container spacing={2} sx={{ mt: 1 }}>
            {report.correlationInsights.highlights.map((highlight, index) => (
              <Grid item xs={12} sm={6} key={index}>
                <Paper sx={{ p: 2, bgcolor: 'grey.50' }}>
                  <Typography variant="subtitle2" color="primary" gutterBottom>
                    {highlight.category}
                  </Typography>
                  <Typography variant="body2">
                    {highlight.observation}
                  </Typography>
                  <Chip
                    label={highlight.quality}
                    size="small"
                    sx={{ mt: 1 }}
                    color={
                      highlight.quality === 'Strong' || highlight.quality === 'Positive'
                        ? 'success'
                        : 'default'
                    }
                  />
                </Paper>
              </Grid>
            ))}
          </Grid>
        </Paper>
      )}
    </Box>
  );
};

export default ExtendedReportView;
