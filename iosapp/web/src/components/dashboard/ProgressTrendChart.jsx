/**
 * Progress Trend Chart Component
 * Shows daily progress trends for selected domain
 */

import React, { useState } from 'react';
import { Line } from 'react-chartjs-2';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
  Filler
} from 'chart.js';
import { Box, Typography, Paper, Select, MenuItem, FormControl, InputLabel } from '@mui/material';

// Register Chart.js components
ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
  Filler
);

const ProgressTrendChart = ({ historicalData, domains }) => {
  const [selectedDomain, setSelectedDomain] = useState(domains[0]?.id || 'social_communication');

  if (!historicalData || Object.keys(historicalData).length === 0) {
    return (
      <Paper sx={{ p: 3, textAlign: 'center' }}>
        <Typography color="text.secondary">
          Complete at least 3 sessions to see progress trends
        </Typography>
      </Paper>
    );
  }

  const domainData = historicalData[selectedDomain] || [];

  if (domainData.length < 2) {
    return (
      <Paper sx={{ p: 3, textAlign: 'center' }}>
        <Typography color="text.secondary">
          More data needed to show trends
        </Typography>
      </Paper>
    );
  }

  // Prepare data for chart
  const data = {
    labels: domainData.map(d => new Date(d.date).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })),
    datasets: [
      {
        label: 'Score',
        data: domainData.map(d => d.score),
        borderColor: domains.find(dom => dom.id === selectedDomain)?.color || '#6366F1',
        backgroundColor: (context) => {
          const chart = context.chart;
          const {ctx, chartArea} = chart;

          if (!chartArea) {
            return null;
          }

          const gradient = ctx.createLinearGradient(0, chartArea.bottom, 0, chartArea.top);
          gradient.addColorStop(0, 'rgba(99, 102, 241, 0.01)');
          gradient.addColorStop(1, 'rgba(99, 102, 241, 0.15)');

          return gradient;
        },
        borderWidth: 3,
        fill: true,
        tension: 0.4,
        pointRadius: 6,
        pointHoverRadius: 8,
        pointBackgroundColor: '#fff',
        pointBorderWidth: 2
      },
      {
        label: 'Target (70)',
        data: Array(domainData.length).fill(70),
        borderColor: 'rgba(16, 185, 129, 0.5)',
        borderWidth: 2,
        borderDash: [5, 5],
        fill: false,
        pointRadius: 0
      }
    ]
  };

  const options = {
    responsive: true,
    maintainAspectRatio: false,
    interaction: {
      mode: 'index',
      intersect: false
    },
    plugins: {
      legend: {
        display: true,
        position: 'top',
        labels: {
          usePointStyle: true,
          padding: 15
        }
      },
      tooltip: {
        backgroundColor: 'rgba(0, 0, 0, 0.8)',
        padding: 12,
        callbacks: {
          label: function(context) {
            if (context.datasetIndex === 0) {
              return `Score: ${context.parsed.y}/100`;
            }
            return 'Target: 70/100';
          },
          afterLabel: function(context) {
            if (context.datasetIndex === 0 && context.dataIndex > 0) {
              const current = context.parsed.y;
              const previous = domainData[context.dataIndex - 1]?.score;
              const change = current - previous;

              if (change > 0) {
                return `↑ +${change.toFixed(0)} from last session`;
              } else if (change < 0) {
                return `↓ ${change.toFixed(0)} from last session`;
              } else {
                return '→ No change';
              }
            }
            return '';
          }
        }
      }
    },
    scales: {
      y: {
        beginAtZero: true,
        max: 100,
        ticks: {
          stepSize: 20
        },
        grid: {
          color: 'rgba(0, 0, 0, 0.05)'
        }
      },
      x: {
        grid: {
          display: false
        }
      }
    }
  };

  // Calculate trend
  const calculateTrend = () => {
    if (domainData.length < 2) return null;

    const firstScore = domainData[0].score;
    const lastScore = domainData[domainData.length - 1].score;
    const change = lastScore - firstScore;

    if (change > 5) {
      return { direction: 'improving', icon: '📈', color: 'success.main', text: `+${change} points improvement` };
    } else if (change < -5) {
      return { direction: 'declining', icon: '📉', color: 'error.main', text: `${change} points decline` };
    } else {
      return { direction: 'stable', icon: '➡️', color: 'text.secondary', text: 'Stable progress' };
    }
  };

  const trend = calculateTrend();

  return (
    <Paper sx={{ p: 3 }}>
      <Box display="flex" justifyContent="space-between" alignItems="center" sx={{ mb: 2 }}>
        <Typography variant="h6" fontWeight="bold">
          Daily Progress Tracker
        </Typography>

        <FormControl size="small" sx={{ minWidth: 200 }}>
          <InputLabel>Domain</InputLabel>
          <Select
            value={selectedDomain}
            label="Domain"
            onChange={(e) => setSelectedDomain(e.target.value)}
          >
            {domains.map(domain => (
              <MenuItem key={domain.id} value={domain.id}>
                {domain.name}
              </MenuItem>
            ))}
          </Select>
        </FormControl>
      </Box>

      {/* Trend indicator */}
      {trend && (
        <Box
          sx={{
            display: 'flex',
            alignItems: 'center',
            gap: 1,
            mb: 2,
            p: 1.5,
            bgcolor: 'grey.50',
            borderRadius: 1
          }}
        >
          <Typography variant="h6">{trend.icon}</Typography>
          <Typography variant="body2" sx={{ color: trend.color, fontWeight: 'bold' }}>
            {trend.text}
          </Typography>
          <Typography variant="caption" color="text.secondary">
            over {domainData.length} sessions
          </Typography>
        </Box>
      )}

      <Box sx={{ height: 300 }}>
        <Line data={data} options={options} />
      </Box>

      {/* Stats summary */}
      <Box display="flex" gap={2} sx={{ mt: 3 }}>
        <Box flex={1} sx={{ textAlign: 'center', p: 2, bgcolor: 'grey.50', borderRadius: 1 }}>
          <Typography variant="h4" fontWeight="bold" color="primary">
            {domainData[domainData.length - 1]?.score}
          </Typography>
          <Typography variant="caption" color="text.secondary">
            Current Score
          </Typography>
        </Box>

        <Box flex={1} sx={{ textAlign: 'center', p: 2, bgcolor: 'grey.50', borderRadius: 1 }}>
          <Typography variant="h4" fontWeight="bold" color="primary">
            {Math.max(...domainData.map(d => d.score))}
          </Typography>
          <Typography variant="caption" color="text.secondary">
            Best Score
          </Typography>
        </Box>

        <Box flex={1} sx={{ textAlign: 'center', p: 2, bgcolor: 'grey.50', borderRadius: 1 }}>
          <Typography variant="h4" fontWeight="bold" color="primary">
            {(domainData.reduce((sum, d) => sum + d.score, 0) / domainData.length).toFixed(0)}
          </Typography>
          <Typography variant="caption" color="text.secondary">
            Average Score
          </Typography>
        </Box>
      </Box>
    </Paper>
  );
};

export default ProgressTrendChart;
