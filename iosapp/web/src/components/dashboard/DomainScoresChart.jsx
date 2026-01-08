/**
 * Domain Scores Chart Component
 * Displays 0-100 scores for developmental domains with color-coded risk levels
 */

import React from 'react';
import { Bar } from 'react-chartjs-2';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  BarElement,
  Title,
  Tooltip,
  Legend
} from 'chart.js';
import { Box, Typography, Paper } from '@mui/material';

// Register Chart.js components
ChartJS.register(
  CategoryScale,
  LinearScale,
  BarElement,
  Title,
  Tooltip,
  Legend
);

const DomainScoresChart = ({ domainScores, title = 'Developmental Domain Scores' }) => {
  if (!domainScores || domainScores.length === 0) {
    return (
      <Paper sx={{ p: 3, textAlign: 'center' }}>
        <Typography color="text.secondary">
          No assessment data available yet
        </Typography>
      </Paper>
    );
  }

  // Prepare data for chart
  const data = {
    labels: domainScores.map(d => d.shortName || d.name),
    datasets: [
      {
        label: 'Score (0-100)',
        data: domainScores.map(d => d.score),
        backgroundColor: domainScores.map(d => {
          // Color based on risk level
          if (d.score >= 70) return 'rgba(16, 185, 129, 0.8)'; // Green
          if (d.score >= 40) return 'rgba(245, 158, 11, 0.8)'; // Orange
          return 'rgba(239, 68, 68, 0.8)'; // Red
        }),
        borderColor: domainScores.map(d => d.color || '#6366F1'),
        borderWidth: 2,
        borderRadius: 8
      }
    ]
  };

  const options = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        display: false
      },
      title: {
        display: false
      },
      tooltip: {
        callbacks: {
          label: function(context) {
            const score = context.parsed.y;
            let level = 'Typical';
            if (score < 40) level = 'Significant Concerns';
            else if (score < 70) level = 'Some Concerns';

            return [
              `Score: ${score}/100`,
              `Level: ${level}`
            ];
          },
          footer: function(items) {
            const index = items[0].dataIndex;
            const domain = domainScores[index];
            return domain.interpretation || '';
          }
        }
      }
    },
    scales: {
      y: {
        beginAtZero: true,
        max: 100,
        ticks: {
          stepSize: 20,
          callback: function(value) {
            return value;
          }
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

  return (
    <Paper sx={{ p: 3 }}>
      <Typography variant="h6" fontWeight="bold" gutterBottom>
        {title}
      </Typography>

      <Typography variant="caption" color="text.secondary" display="block" sx={{ mb: 2 }}>
        0-39: Significant Concerns 🚨 | 40-69: Some Concerns ⚠️ | 70-100: Typical Development ✅
      </Typography>

      <Box sx={{ height: 300 }}>
        <Bar data={data} options={options} />
      </Box>

      {/* Domain details */}
      <Box sx={{ mt: 3 }}>
        {domainScores.map((domain, index) => (
          <Box
            key={index}
            sx={{
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              mb: 1,
              p: 1,
              borderRadius: 1,
              bgcolor: 'grey.50'
            }}
          >
            <Box display="flex" alignItems="center" gap={1}>
              <Box
                sx={{
                  width: 12,
                  height: 12,
                  borderRadius: '50%',
                  bgcolor: domain.color
                }}
              />
              <Typography variant="body2">
                {domain.name || domain.shortName}
              </Typography>
            </Box>
            <Box display="flex" alignItems="center" gap={1}>
              <Typography variant="body2" fontWeight="bold">
                {domain.score}/100
              </Typography>
              <Typography variant="body2">
                {domain.riskLevel?.icon || (domain.score >= 70 ? '✅' : domain.score >= 40 ? '⚠️' : '🚨')}
              </Typography>
            </Box>
          </Box>
        ))}
      </Box>
    </Paper>
  );
};

export default DomainScoresChart;
