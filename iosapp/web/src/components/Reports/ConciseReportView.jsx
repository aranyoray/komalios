/**
 * Concise Daily Report View
 * Shows 5 domain scores, dropdown graph, and 2-3 key highlights
 */

import React, { useState } from 'react';
import {
  Box,
  Paper,
  Typography,
  Accordion,
  AccordionSummary,
  AccordionDetails,
  Chip,
  LinearProgress,
  Grid
} from '@mui/material';
import ExpandMoreIcon from '@mui/icons-material/ExpandMore';
import { Radar } from 'react-chartjs-2';
import {
  Chart as ChartJS,
  RadialLinearScale,
  PointElement,
  LineElement,
  Filler,
  Tooltip,
  Legend
} from 'chart.js';

// Register Chart.js components
ChartJS.register(
  RadialLinearScale,
  PointElement,
  LineElement,
  Filler,
  Tooltip,
  Legend
);

const ConciseReportView = ({ report }) => {
  const [graphExpanded, setGraphExpanded] = useState(false);

  if (!report) return null;

  // Prepare radar chart data
  const radarData = {
    labels: report.graphData.labels,
    datasets: [
      {
        label: 'Session Scores',
        data: report.graphData.scores,
        backgroundColor: 'rgba(99, 102, 241, 0.2)',
        borderColor: 'rgba(99, 102, 241, 1)',
        borderWidth: 2,
        pointBackgroundColor: report.graphData.colors,
        pointBorderColor: '#fff',
        pointHoverBackgroundColor: '#fff',
        pointHoverBorderColor: report.graphData.colors
      }
    ]
  };

  const radarOptions = {
    responsive: true,
    maintainAspectRatio: false,
    scales: {
      r: {
        beginAtZero: true,
        max: 100,
        ticks: {
          stepSize: 20
        }
      }
    },
    plugins: {
      legend: {
        display: false
      }
    }
  };

  return (
    <Box sx={{ maxWidth: 800, mx: 'auto', p: 2 }}>
      {/* Header */}
      <Paper sx={{ p: 3, mb: 3 }}>
        <Typography variant="h5" fontWeight="bold" gutterBottom>
          Session Summary
        </Typography>
        <Typography variant="body2" color="text.secondary">
          {new Date(report.date).toLocaleDateString('en-US', {
            weekday: 'long',
            year: 'numeric',
            month: 'long',
            day: 'numeric'
          })}
        </Typography>
        <Typography variant="body2" color="text.secondary">
          Duration: {Math.round(report.duration / 60)} minutes • Tasks Completed: {report.summary.tasksCompleted}/{report.summary.tasksTotal} ({report.summary.completionRate}%)
        </Typography>
      </Paper>

      {/* Key Highlights */}
      <Paper sx={{ p: 3, mb: 3 }}>
        <Typography variant="h6" fontWeight="bold" gutterBottom>
          Key Highlights
        </Typography>
        <Box component="ul" sx={{ pl: 2, mt: 2 }}>
          {report.highlights.map((highlight, index) => (
            <Typography
              key={index}
              component="li"
              variant="body1"
              sx={{ mb: 1.5, lineHeight: 1.6 }}
            >
              {highlight}
            </Typography>
          ))}
        </Box>
      </Paper>

      {/* Domain Scores */}
      <Paper sx={{ p: 3, mb: 3 }}>
        <Typography variant="h6" fontWeight="bold" gutterBottom>
          Domain Scores
        </Typography>
        <Grid container spacing={2} sx={{ mt: 1 }}>
          {report.domains.map((domain) => (
            <Grid item xs={12} key={domain.id}>
              <Box
                sx={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  mb: 1
                }}
              >
                <Box sx={{ flex: 1, mr: 2 }}>
                  <Typography variant="body1" fontWeight="medium">
                    {domain.name}
                  </Typography>
                </Box>
                <Chip
                  label={domain.strengthFlag.label}
                  size="small"
                  sx={{
                    bgcolor:
                      domain.strengthFlag.color === 'green'
                        ? 'success.light'
                        : domain.strengthFlag.color === 'amber'
                        ? 'warning.light'
                        : 'error.light',
                    color: 'white',
                    fontWeight: 'bold',
                    mr: 2
                  }}
                />
                <Typography variant="h6" fontWeight="bold" sx={{ minWidth: 60 }}>
                  {domain.score}/100
                </Typography>
              </Box>
              <LinearProgress
                variant="determinate"
                value={domain.score}
                sx={{
                  height: 8,
                  borderRadius: 1,
                  bgcolor: 'grey.200',
                  '& .MuiLinearProgress-bar': {
                    bgcolor: domain.color,
                    borderRadius: 1
                  }
                }}
              />
            </Grid>
          ))}
        </Grid>
      </Paper>

      {/* Radar Chart (Dropdown) */}
      <Accordion expanded={graphExpanded} onChange={() => setGraphExpanded(!graphExpanded)}>
        <AccordionSummary expandIcon={<ExpandMoreIcon />}>
          <Typography variant="h6" fontWeight="bold">
            Visual Overview
          </Typography>
        </AccordionSummary>
        <AccordionDetails>
          <Box sx={{ height: 400, p: 2 }}>
            <Radar data={radarData} options={radarOptions} />
          </Box>
          <Typography variant="caption" color="text.secondary" sx={{ display: 'block', textAlign: 'center', mt: 2 }}>
            Radar chart showing performance across all 5 developmental domains
          </Typography>
        </AccordionDetails>
      </Accordion>

      {/* Focus Areas */}
      <Paper sx={{ p: 3, mt: 3 }}>
        <Typography variant="h6" fontWeight="bold" gutterBottom>
          Focus Areas
        </Typography>
        <Grid container spacing={2}>
          <Grid item xs={12} sm={6}>
            <Typography variant="subtitle2" color="success.main" fontWeight="bold">
              Top Strengths
            </Typography>
            <Box component="ul" sx={{ pl: 2, mt: 1 }}>
              {report.focusAreas.strengths.map((area, index) => (
                <Typography key={index} component="li" variant="body2">
                  {area}
                </Typography>
              ))}
            </Box>
          </Grid>
          <Grid item xs={12} sm={6}>
            <Typography variant="subtitle2" color="warning.main" fontWeight="bold">
              Areas to Support
            </Typography>
            <Box component="ul" sx={{ pl: 2, mt: 1 }}>
              {report.focusAreas.priorities.map((area, index) => (
                <Typography key={index} component="li" variant="body2">
                  {area}
                </Typography>
              ))}
            </Box>
          </Grid>
        </Grid>
      </Paper>
    </Box>
  );
};

export default ConciseReportView;
