/**
 * Onboarding Home Page for Komal
 * Mobile-first professional design for SEL therapy app
 */

import React, { useState, useEffect, useMemo } from 'react';
import {
  Container,
  Typography,
  Button,
  Box,
  Stepper,
  Step,
  StepLabel,
} from '@mui/material';
import {
  ArrowForward,
  ArrowBack,
  Psychology,
  Face,
  Assessment,
  EmojiEmotions,
  CheckCircle,
  PlayArrow,
} from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { useLanguage } from '../i18n/LanguageContext';
import {
  initializeAdMob,
  requestTrackingPermission,
  showBannerAds,
  hideBannerAds,
} from '../services/admobService';

const Home = () => {
  const navigate = useNavigate();
  const { isAuthenticated } = useAuth();
  const { t } = useLanguage();
  const [activeStep, setActiveStep] = useState(0);

  // Get onboarding steps from translations
  const onboardingSteps = useMemo(() => [
    {
      title: t.onboarding.steps.welcome.title,
      subtitle: t.onboarding.steps.welcome.subtitle,
      description: t.onboarding.steps.welcome.description,
      image: '/assets/finalstrokemonkey.png',
      color: '#240460', // Deep Violet
    },
    {
      title: t.onboarding.steps.personalized.title,
      subtitle: t.onboarding.steps.personalized.subtitle,
      description: t.onboarding.steps.personalized.description,
      icon: <Psychology sx={{ fontSize: 80 }} />,
      color: '#6366F1', // Indigo -> nicely matches violet theme
    },
    {
      title: t.onboarding.steps.progress.title,
      subtitle: t.onboarding.steps.progress.subtitle,
      description: t.onboarding.steps.progress.description,
      icon: <Assessment sx={{ fontSize: 80 }} />,
      color: '#059669', // Emerald -> soft green
    },
    {
      title: t.onboarding.steps.secure.title,
      subtitle: t.onboarding.steps.secure.subtitle,
      description: t.onboarding.steps.secure.description,
      icon: <Face sx={{ fontSize: 80 }} />,
      color: '#D81B60', // Pink -> energetic accent
    },
  ], [t]);

  // Initialize and show AdMob banner ads
  useEffect(() => {
    let isMounted = true;

    const setupAds = async () => {
      try {
        // Initialize AdMob
        const initialized = await initializeAdMob();
        if (!initialized || !isMounted) {
          return;
        }

        // Request tracking permission (iOS 14+)
        await requestTrackingPermission();

        // Show banner ad at bottom
        await showBannerAds('bottom');
      } catch (error) {
        console.error('[Home] Error setting up ads:', error);
      }
    };

    setupAds();

    // Cleanup: Hide banner ads when component unmounts
    return () => {
      isMounted = false;
      hideBannerAds().catch((error) => {
        console.error('[Home] Error hiding ads on unmount:', error);
      });
    };
  }, []);

  const handleNext = () => {
    if (activeStep < onboardingSteps.length - 1) {
      setActiveStep(activeStep + 1);
    } else {
      handleGetStarted();
    }
  };

  const handleBack = () => {
    if (activeStep > 0) {
      setActiveStep(activeStep - 1);
    }
  };

  const handleGetStarted = () => {
    navigate(isAuthenticated ? '/mode-selection' : '/signin');
  };

  const handleSkip = () => {
    navigate(isAuthenticated ? '/mode-selection' : '/signin');
  };

  const currentStep = onboardingSteps[activeStep];

  return (
    <Box
      sx={{
        minHeight: '100vh',
        backgroundColor: '#ffffff', // Simple white background
        position: 'relative',
        overflow: 'hidden',
        display: 'flex',
        flexDirection: 'column',
      }}
    >
      {/* Top Header: Progress Indicator + Skip Button */}
      <Box
        sx={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          pt: { xs: 3, sm: 4 },
          px: { xs: 3, sm: 4 },
        }}
      >
        {/* Step Indicator - at complete top */}
        <Box sx={{ flex: 1 }}>
          <Stepper activeStep={activeStep} alternativeLabel>
            {onboardingSteps.map((step, index) => (
              <Step key={index}>
                <StepLabel
                  sx={{
                    '& .MuiStepLabel-label': {
                      display: 'none',
                    },
                    '& .MuiStepIcon-root': {
                      color: 'rgba(36, 4, 96, 0.2)', // Light violet for inactive
                      width: 28,
                      height: 28,
                      '&.Mui-active': {
                        color: 'primary.main', // Deep Violet for active
                      },
                      '&.Mui-completed': {
                        color: 'primary.main',
                      },
                      '& .MuiStepIcon-text': {
                        fill: '#fff',
                        fontWeight: 'bold',
                      },
                    },
                  }}
                />
              </Step>
            ))}
          </Stepper>
        </Box>

        {/* Skip Button - top right */}
        <Button
          onClick={handleSkip}
          sx={{
            color: 'text.secondary',
            textTransform: 'none',
            fontSize: '1rem',
            fontWeight: 600,
            ml: 2,
            '&:hover': {
              backgroundColor: 'rgba(36, 4, 96, 0.04)',
            },
          }}
        >
          {t.onboarding.skip}
        </Button>
      </Box>

      {/* Main Content Area - Upper section */}
      <Container
        maxWidth="sm"
        sx={{
          flex: 1,
          display: 'flex',
          flexDirection: 'column',
          justifyContent: 'flex-start',
          pt: { xs: 4, sm: 6 },
          px: { xs: 3, sm: 4 },
        }}
      >
        {/* Content - Text and animated stuff at upper top */}
        <Box
          sx={{
            textAlign: 'center',
            '@keyframes slideIn': {
              from: { opacity: 0, transform: 'translateY(10px)' },
              to: { opacity: 1, transform: 'translateY(0)' },
            },
            animation: 'slideIn 0.4s ease-out',
          }}
        >
          {/* Icon Circle */}
          <Box
            sx={{
              width: 140,
              height: 140,
              borderRadius: currentStep.image ? '0' : '50%',
              backgroundColor: currentStep.image ? 'transparent' : `${currentStep.color}15`,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              mb: 4,
              mx: 'auto',
              color: currentStep.color,
              transition: 'all 0.3s ease',
            }}
          >
            {currentStep.image ? (
              <img
                src={currentStep.image}
                alt={currentStep.title}
                style={{
                  width: '100%',
                  height: '100%',
                  objectFit: 'contain',
                }}
              />
            ) : (
              currentStep.icon
            )}
          </Box>

          {/* Title */}
          <Typography
            variant="h4"
            sx={{
              fontWeight: 800,
              mb: 2,
              color: 'text.primary',
              fontSize: { xs: '1.75rem', sm: '2rem' },
            }}
          >
            {currentStep.title}
          </Typography>

          {/* Subtitle */}
          <Typography
            variant="h6"
            sx={{
              mb: 2,
              color: currentStep.color,
              fontWeight: 600,
              opacity: 0.9,
            }}
          >
            {currentStep.subtitle}
          </Typography>

          {/* Description */}
          <Typography
            variant="body1"
            sx={{
              color: 'text.secondary',
              lineHeight: 1.6,
              maxWidth: '90%',
              mx: 'auto',
            }}
          >
            {currentStep.description}
          </Typography>
        </Box>
      </Container>

      {/* Navigation Buttons - Fixed at bottom */}
      <Box
        sx={{
          position: 'sticky',
          bottom: 0,
          left: 0,
          right: 0,
          backgroundColor: '#ffffff',
          px: { xs: 3, sm: 4 },
          py: { xs: 3, sm: 4 },
          display: 'flex',
          flexDirection: 'column',
          gap: 2,
        }}
      >
        <Box
          sx={{
            display: 'flex',
            gap: 2,
            justifyContent: 'space-between',
            alignItems: 'center',
            maxWidth: 'sm',
            width: '100%',
            mx: 'auto',
          }}
        >
          <Button
            onClick={handleBack}
            disabled={activeStep === 0}
            startIcon={<ArrowBack />}
            sx={{
              color: 'text.secondary',
              textTransform: 'none',
              fontSize: '1rem',
              opacity: activeStep === 0 ? 0 : 1, // Hide if disabled
              '&:hover': {
                backgroundColor: 'rgba(36, 4, 96, 0.04)',
              },
            }}
          >
            {t.onboarding.back}
          </Button>

          <Button
            variant="contained"
            color="primary"
            onClick={handleNext}
            endIcon={activeStep === onboardingSteps.length - 1 ? <CheckCircle /> : <ArrowForward />}
            sx={{
              px: 4,
              py: 1.5,
              fontSize: '1.1rem',
              fontWeight: 700,
              minWidth: 160,
            }}
          >
            {activeStep === onboardingSteps.length - 1 ? t.onboarding.getStarted : t.onboarding.next}
          </Button>
        </Box>

        {/* Quick Start (for authenticated users) */}
        {isAuthenticated && (
          <Box sx={{ textAlign: 'center' }}>
            <Button
              variant="text"
              startIcon={<PlayArrow />}
              onClick={handleGetStarted}
              sx={{
                color: 'text.secondary',
                '&:hover': {
                  color: 'primary.main',
                  backgroundColor: 'transparent',
                },
              }}
            >
              {t.onboarding.goToProfileSelection}
            </Button>
          </Box>
        )}
      </Box>
    </Box>
  );
};

export default Home;
