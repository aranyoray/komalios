/**
 * Reports Page for Parents/Therapists
 * Interactive analytics dashboard with extended reports
 */

import React, { useState } from 'react';
import {
  Box,
  Container,
  Typography,
  Paper,
  Tabs,
  Tab,
  Alert,
} from '@mui/material';
import {
  Dashboard,
  Assessment,
  Psychology,
} from '@mui/icons-material';
import { useAuth } from '../../contexts/AuthContext';
import { useLanguage } from '../../i18n/LanguageContext';
import ReportDashboard from '../../components/Reports/ReportDashboard';
import ExtendedReport from '../../components/Reports/ExtendedReport';
import { gradients } from '../../theme';

const Reports = () => {
  const { currentProfile } = useAuth();
  const { t } = useLanguage();
  const [tabValue, setTabValue] = useState(0);

  // For parent mode, we'd need to select which learner's reports to view
  // For now, we'll use the current profile if it's a learner
  const learnerId = currentProfile?.id;
  const learnerName = currentProfile?.name || t.reports.child;

  if (!learnerId) {
    return (
      <Container maxWidth="lg" sx={{ py: 4 }}>
        <Alert
          severity="info"
          sx={{
            borderRadius: 3,
            fontSize: '1rem',
            py: 2,
          }}
        >
          {t.reports.selectLearnerToView}
        </Alert>
      </Container>
    );
  }

  return (
    <Box sx={{
      minHeight: '100vh',
      overflow: 'auto',
      backgroundImage: 'url(/assets/beach.png)',
      backgroundSize: 'cover',
      backgroundPosition: 'center',
      backgroundRepeat: 'no-repeat',
      backgroundAttachment: 'fixed',
    }}>


      {/* Enhanced Tabs */}
      <Container maxWidth="lg" sx={{ mt: 4, position: 'relative', zIndex: 2, px: { xs: 1.5, sm: 2, md: 3 } }}>
        <Paper
          sx={{
            borderRadius: 1,
            overflow: 'hidden',
            boxShadow: '0 8px 32px rgba(0,0,0,0.12)',
            border: '1px solid rgba(255,255,255,0.2)',
          }}
        >
          <Tabs
            value={tabValue}
            onChange={(e, v) => setTabValue(v)}
            variant="fullWidth"
            sx={{
              bgcolor: 'background.paper',
              '& .MuiTab-root': {
                py: 1.5,
                fontWeight: 600,
                fontSize: '1rem',
                textTransform: 'none',
                minHeight: 48,
                '&.Mui-selected': {
                  color: 'primary.main',
                },
              },
              '& .MuiTabs-indicator': {
                height: 3,
                borderRadius: '3px 3px 0 0',
                background: gradients.primary,
              },
            }}
          >
            <Tab
              icon={<Dashboard sx={{ mb: 0.5 }} />}
              label={t.reports.dashboardTab}
              iconPosition="start"
            />
            <Tab
              icon={<Assessment sx={{ mb: 0.5 }} />}
              label={t.reports.extendedReportTab}
              iconPosition="start"
            />
          </Tabs>
        </Paper>
      </Container>

      {/* Tab Content */}
      <Box sx={{ py: { xs: 0, md: 4 }, width: '100%' }}>
        {tabValue === 0 && (
          <ReportDashboard
            learnerId={learnerId}
            learnerName={learnerName}
            learnerProfile={currentProfile}
          />
        )}

        {tabValue === 1 && (
          <ExtendedReport
            learnerId={learnerId}
            learnerName={learnerName}
            period="month"
            learnerProfile={currentProfile}
          />
        )}
      </Box>
    </Box >
  );
};

export default Reports;
