/**
 * Home Page for Komal
 * Professional landing page with gradients and animations
 */

import React from 'react';
import {
  Container,
  Typography,
  Button,
  Box,
  Grid,
  Card,
  CardContent,
} from '@mui/material';
import {
  Psychology,
  Visibility,
  Assessment,
  Language,
  ArrowForward,
  PlayArrow,
} from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import { useLanguage } from '../i18n/LanguageContext';
import { getTranslation } from '../i18n/translations-ui';
import { gradients } from '../theme';
import { useAuth } from '../contexts/AuthContext';

const Home = () => {
  const navigate = useNavigate();
  const { language } = useLanguage();
  const { isAuthenticated } = useAuth();
  const t = (key) => getTranslation(language, key);

  const features = [
    {
      icon: <Psychology sx={{ fontSize: 40 }} />,
      title: t('adaptiveLearning'),
      description: t('adaptiveDesc'),
      gradient: gradients.primary,
    },
    {
      icon: <Visibility sx={{ fontSize: 40 }} />,
      title: t('biomarkerTracking'),
      description: t('biomarkerDesc'),
      gradient: gradients.secondary,
    },
    {
      icon: <Assessment sx={{ fontSize: 40 }} />,
      title: t('progressReports'),
      description: t('progressDesc'),
      gradient: gradients.success,
    },
    {
      icon: <Language sx={{ fontSize: 40 }} />,
      title: t('multiLanguage'),
      description: t('multiLanguageDesc'),
      gradient: gradients.cool,
    },
  ];

  return (
    <Box>
      {/* Hero Section */}
      <Box
        sx={{
          background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
          color: 'white',
          pt: { xs: 8, md: 12 },
          pb: { xs: 10, md: 16 },
          position: 'relative',
          overflow: 'hidden',
          '&::before': {
            content: '""',
            position: 'absolute',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            background: 'radial-gradient(circle at 30% 70%, rgba(255,255,255,0.1) 0%, transparent 50%)',
          },
        }}
      >
        <Container maxWidth="lg">
          <Grid container spacing={4} alignItems="center">
            <Grid item xs={12} md={7}>
              <Box
                sx={{
                  '@keyframes fadeInUp': {
                    from: { opacity: 0, transform: 'translateY(30px)' },
                    to: { opacity: 1, transform: 'translateY(0)' },
                  },
                  animation: 'fadeInUp 0.8s ease-out',
                }}
              >
                <Typography
                  variant="h1"
                  onClick={() => {
                    if (isAuthenticated) {
                      navigate('/profile-select');
                    }
                  }}
                  sx={{
                    fontSize: { xs: '2.5rem', md: '3.5rem', lg: '4rem' },
                    fontWeight: 800,
                    lineHeight: 1.1,
                    mb: 3,
                    cursor: isAuthenticated ? 'pointer' : 'default',
                    transition: 'all 0.2s ease',
                    '&:hover': isAuthenticated ? {
                      opacity: 0.8,
                      transform: 'scale(1.02)',
                    } : {},
                  }}
                >
                  {t('heroTitle')}
                </Typography>
                <Typography
                  variant="h5"
                  sx={{
                    opacity: 0.9,
                    mb: 4,
                    fontWeight: 400,
                    lineHeight: 1.5,
                    maxWidth: 500,
                  }}
                >
                  {t('heroSubtitle')}
                </Typography>
                <Box sx={{ display: 'flex', gap: 2, flexWrap: 'wrap' }}>
                  <Button
                    variant="contained"
                    size="large"
                    endIcon={<ArrowForward />}
                    onClick={() => navigate(isAuthenticated ? '/profile-select' : '/signin')}
                    sx={{
                      background: 'white',
                      color: '#6366F1',
                      px: 4,
                      py: 1.5,
                      fontSize: '1.1rem',
                      '&:hover': {
                        background: 'rgba(255,255,255,0.9)',
                        transform: 'translateY(-2px)',
                      },
                    }}
                  >
                    {t('getStarted')}
                  </Button>
                  <Button
                    variant="outlined"
                    size="large"
                    startIcon={<PlayArrow />}
                    sx={{
                      borderColor: 'rgba(255,255,255,0.5)',
                      color: 'white',
                      px: 4,
                      py: 1.5,
                      fontSize: '1.1rem',
                      '&:hover': {
                        borderColor: 'white',
                        background: 'rgba(255,255,255,0.1)',
                      },
                    }}
                  >
                    {t('learnMore')}
                  </Button>
                </Box>
              </Box>
            </Grid>
            <Grid item xs={12} md={5}>
              <Box
                sx={{
                  display: { xs: 'none', md: 'flex' },
                  justifyContent: 'center',
                  alignItems: 'center',
                  '@keyframes float': {
                    '0%, 100%': { transform: 'translateY(0)' },
                    '50%': { transform: 'translateY(-20px)' },
                  },
                  animation: 'float 6s ease-in-out infinite',
                }}
              >
                <Box
                  sx={{
                    width: 300,
                    height: 300,
                    borderRadius: '50%',
                    background: 'rgba(255,255,255,0.1)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                  }}
                >
                  <Box
                    sx={{
                      width: 200,
                      height: 200,
                      borderRadius: '50%',
                      background: 'rgba(255,255,255,0.15)',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                    }}
                  >
                    <Typography variant="h2" sx={{ fontSize: '4rem' }}>
                      🧠
                    </Typography>
                  </Box>
                </Box>
              </Box>
            </Grid>
          </Grid>
        </Container>
      </Box>

      {/* Features Section */}
      <Container 
        maxWidth="lg" 
        sx={{ 
          py: { xs: 6, sm: 8, md: 10, lg: 12 },
          px: { xs: 2, sm: 3, md: 4 },
        }}
      >
        <Box 
          textAlign="center" 
          mb={{ xs: 4, sm: 5, md: 6, lg: 10 }}
          sx={{
            px: { xs: 1, sm: 0 },
          }}
        >
          <Typography
            variant="h2"
            sx={{
              fontWeight: 700,
              mb: { xs: 1.5, sm: 2 },
              fontSize: { xs: '1.75rem', sm: '2rem', md: '2.5rem', lg: '3rem' },
              background: gradients.primary,
              backgroundClip: 'text',
              WebkitBackgroundClip: 'text',
              WebkitTextFillColor: 'transparent',
              lineHeight: 1.2,
            }}
          >
            {t('features')}
          </Typography>
          <Typography 
            variant="h6" 
            color="text.secondary" 
            sx={{ 
              maxWidth: { xs: '100%', sm: 600, md: 700 },
              mx: 'auto',
              fontSize: { xs: '0.9rem', sm: '1rem', md: '1.05rem', lg: '1.1rem' },
              lineHeight: { xs: 1.5, sm: 1.6 },
              px: { xs: 2, sm: 0 },
            }}
          >
            Evidence-based tools designed by therapists for meaningful progress
          </Typography>
        </Box>

        <Grid 
          container 
          spacing={{ xs: 2, sm: 3, md: 4, lg: 5 }}
          sx={{
            justifyContent: { xs: 'center', sm: 'flex-start' },
          }}
        >
          {features.map((feature, index) => (
            <Grid 
              item 
              xs={12} 
              sm={6} 
              md={6} 
              lg={3} 
              xl={3}
              key={index}
              sx={{
                display: 'flex',
                maxWidth: { xs: '100%', sm: 'calc(50% - 12px)', md: 'calc(50% - 16px)', lg: 'calc(25% - 20px)' },
              }}
            >
              <Card
                elevation={0}
                sx={{
                  width: '100%',
                  height: '100%',
                  minHeight: { xs: 260, sm: 300, md: 320, lg: 340 },
                  transition: 'all 0.4s cubic-bezier(0.4, 0, 0.2, 1)',
                  cursor: 'pointer',
                  border: '1px solid',
                  borderColor: 'divider',
                  borderRadius: { xs: 3, sm: 4 },
                  background: 'white',
                  position: 'relative',
                  overflow: 'hidden',
                  '&::before': {
                    content: '""',
                    position: 'absolute',
                    top: 0,
                    left: 0,
                    right: 0,
                    height: { xs: 3, sm: 4 },
                    background: feature.gradient,
                    transform: 'scaleX(0)',
                    transformOrigin: 'left',
                    transition: 'transform 0.4s ease',
                  },
                  '&:hover': {
                    transform: { xs: 'translateY(-4px)', sm: 'translateY(-8px)', md: 'translateY(-12px)' },
                    boxShadow: { 
                      xs: '0 12px 24px rgba(0,0,0,0.1)',
                      sm: '0 16px 32px rgba(0,0,0,0.12)',
                      md: '0 24px 48px rgba(0,0,0,0.15)',
                    },
                    borderColor: 'primary.light',
                    '&::before': {
                      transform: 'scaleX(1)',
                    },
                    '& .feature-icon': {
                      transform: { xs: 'scale(1.05)', sm: 'scale(1.08)', md: 'scale(1.1) rotate(5deg)' },
                    },
                  },
                  '&:active': {
                    transform: { xs: 'translateY(-2px)', sm: 'translateY(-4px)' },
                  },
                }}
              >
                <CardContent 
                  sx={{ 
                    p: { xs: 2.5, sm: 3.5, md: 4, lg: 5 },
                    textAlign: 'center',
                    height: '100%',
                    display: 'flex',
                    flexDirection: 'column',
                    justifyContent: 'center',
                    alignItems: 'center',
                  }}
                >
                  <Box
                    className="feature-icon"
                    sx={{
                      width: { xs: 80, sm: 90, md: 100, lg: 110 },
                      height: { xs: 80, sm: 90, md: 100, lg: 110 },
                      borderRadius: { xs: 2.5, sm: 3 },
                      background: feature.gradient,
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      mx: 'auto',
                      mb: { xs: 2.5, sm: 3, md: 3.5, lg: 4 },
                      color: 'white',
                      transition: 'all 0.4s cubic-bezier(0.4, 0, 0.2, 1)',
                      boxShadow: { 
                        xs: '0 4px 12px rgba(0,0,0,0.1)',
                        sm: '0 6px 16px rgba(0,0,0,0.11)',
                        md: '0 8px 24px rgba(0,0,0,0.12)',
                      },
                    }}
                  >
                    {React.cloneElement(feature.icon, {
                      sx: { 
                        fontSize: { xs: 36, sm: 42, md: 46, lg: 52 },
                      }
                    })}
                  </Box>
                  <Typography 
                    variant="h5" 
                    fontWeight={700} 
                    gutterBottom
                    sx={{
                      mb: { xs: 1, sm: 1.5, md: 2 },
                      fontSize: { 
                        xs: '1.1rem', 
                        sm: '1.25rem', 
                        md: '1.35rem', 
                        lg: '1.5rem' 
                      },
                      color: 'text.primary',
                      lineHeight: 1.3,
                    }}
                  >
                    {feature.title}
                  </Typography>
                  <Typography 
                    variant="body1" 
                    color="text.secondary"
                    sx={{
                      fontSize: { 
                        xs: '0.85rem', 
                        sm: '0.9rem', 
                        md: '0.95rem', 
                        lg: '1rem' 
                      },
                      lineHeight: { xs: 1.6, sm: 1.65, md: 1.7 },
                      maxWidth: { xs: '100%', sm: 280, md: 300 },
                      mx: 'auto',
                      px: { xs: 1, sm: 0 },
                    }}
                  >
                    {feature.description}
                  </Typography>
                </CardContent>
              </Card>
            </Grid>
          ))}
        </Grid>
      </Container>

      {/* Partners Carousel */}
      <Box sx={{ py: { xs: 6, md: 10 }, bgcolor: 'grey.50' }}>
        <Container maxWidth="lg">
          <Box textAlign="center" mb={6}>
            <Typography
              variant="h4"
              sx={{
                fontWeight: 700,
                mb: 2,
                color: 'text.primary',
              }}
            >
              Our Research Partners
            </Typography>
            <Typography variant="body1" color="text.secondary">
              Built on world-class research from leading institutions
            </Typography>
          </Box>

          {/* Scrolling Carousel */}
          <Box
            sx={{
              overflow: 'hidden',
              position: 'relative',
              '&::before': {
                content: '""',
                position: 'absolute',
                left: 0,
                top: 0,
                bottom: 0,
                width: 100,
                background: 'linear-gradient(90deg, #F9FAFB 0%, transparent 100%)',
                zIndex: 1,
              },
              '&::after': {
                content: '""',
                position: 'absolute',
                right: 0,
                top: 0,
                bottom: 0,
                width: 100,
                background: 'linear-gradient(90deg, transparent 0%, #F9FAFB 100%)',
                zIndex: 1,
              },
            }}
          >
            <Box
              sx={{
                display: 'flex',
                gap: 6,
                py: 4,
                '@keyframes scroll': {
                  '0%': { transform: 'translateX(0)' },
                  '100%': { transform: 'translateX(-50%)' },
                },
                animation: 'scroll 30s linear infinite',
                '&:hover': {
                  animationPlayState: 'paused',
                },
                width: 'max-content',
              }}
            >
              {/* First set of logos */}
              {[
                { name: 'Harvard', subtitle: 'SEL Framework', color: '#A51C30' },
                { name: 'Princeton', subtitle: 'CAFE Dataset', color: '#FF6B00' },
                { name: 'NIH', subtitle: 'Research Data', color: '#20558A' },
                { name: 'Nature', subtitle: 'Scientific Data', color: '#E15B5B' },
                { name: 'MDPI', subtitle: 'Open Access', color: '#3D85C6' },
                { name: 'Kaggle', subtitle: 'ML Datasets', color: '#20BEFF' },
                { name: 'AffectNet', subtitle: 'Emotion AI', color: '#8E44AD' },
                { name: 'GitHub', subtitle: 'Open Source', color: '#333333' },
              ].map((partner, index) => (
                <Box
                  key={`first-${index}`}
                  sx={{
                    display: 'flex',
                    flexDirection: 'column',
                    alignItems: 'center',
                    minWidth: 120,
                    opacity: 0.7,
                    transition: 'all 0.3s ease',
                    '&:hover': {
                      opacity: 1,
                      transform: 'scale(1.05)',
                    },
                  }}
                >
                  <Box
                    sx={{
                      width: 80,
                      height: 80,
                      borderRadius: 2,
                      bgcolor: 'white',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      boxShadow: '0 2px 8px rgba(0,0,0,0.08)',
                      mb: 1,
                    }}
                  >
                    <Typography
                      sx={{
                        fontWeight: 700,
                        fontSize: '0.9rem',
                        color: partner.color,
                        textAlign: 'center',
                        px: 1,
                      }}
                    >
                      {partner.name}
                    </Typography>
                  </Box>
                  <Typography variant="caption" color="text.secondary" sx={{ fontSize: '0.7rem' }}>
                    {partner.subtitle}
                  </Typography>
                </Box>
              ))}
              {/* Duplicate for seamless loop */}
              {[
                { name: 'Harvard', subtitle: 'SEL Framework', color: '#A51C30' },
                { name: 'Princeton', subtitle: 'CAFE Dataset', color: '#FF6B00' },
                { name: 'NIH', subtitle: 'Research Data', color: '#20558A' },
                { name: 'Nature', subtitle: 'Scientific Data', color: '#E15B5B' },
                { name: 'MDPI', subtitle: 'Open Access', color: '#3D85C6' },
                { name: 'Kaggle', subtitle: 'ML Datasets', color: '#20BEFF' },
                { name: 'AffectNet', subtitle: 'Emotion AI', color: '#8E44AD' },
                { name: 'GitHub', subtitle: 'Open Source', color: '#333333' },
              ].map((partner, index) => (
                <Box
                  key={`second-${index}`}
                  sx={{
                    display: 'flex',
                    flexDirection: 'column',
                    alignItems: 'center',
                    minWidth: 120,
                    opacity: 0.7,
                    transition: 'all 0.3s ease',
                    '&:hover': {
                      opacity: 1,
                      transform: 'scale(1.05)',
                    },
                  }}
                >
                  <Box
                    sx={{
                      width: 80,
                      height: 80,
                      borderRadius: 2,
                      bgcolor: 'white',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      boxShadow: '0 2px 8px rgba(0,0,0,0.08)',
                      mb: 1,
                    }}
                  >
                    <Typography
                      sx={{
                        fontWeight: 700,
                        fontSize: '0.9rem',
                        color: partner.color,
                        textAlign: 'center',
                        px: 1,
                      }}
                    >
                      {partner.name}
                    </Typography>
                  </Box>
                  <Typography variant="caption" color="text.secondary" sx={{ fontSize: '0.7rem' }}>
                    {partner.subtitle}
                  </Typography>
                </Box>
              ))}
            </Box>
          </Box>
        </Container>
      </Box>

      {/* CTA Section */}
      <Box
        sx={{
          background: 'linear-gradient(135deg, #F8FAFC 0%, #EEF2FF 100%)',
          py: { xs: 8, md: 12 },
        }}
      >
        <Container maxWidth="md">
          <Box
            sx={{
              textAlign: 'center',
              p: { xs: 4, md: 6 },
              borderRadius: 4,
              background: 'white',
              boxShadow: '0 20px 60px rgba(99, 102, 241, 0.15)',
            }}
          >
            <Typography variant="h3" fontWeight={700} gutterBottom>
              Ready to get started?
            </Typography>
            <Typography variant="h6" color="text.secondary" sx={{ mb: 4 }}>
              Join thousands of families using Komal for their child's development
            </Typography>
            <Button
              variant="contained"
              size="large"
              endIcon={<ArrowForward />}
              onClick={() => navigate(isAuthenticated ? '/profile-select' : '/signin')}
              sx={{ px: 6, py: 2, fontSize: '1.1rem' }}
            >
              {isAuthenticated ? 'Select Profile' : 'Create Free Account'}
            </Button>
          </Box>
        </Container>
      </Box>
    </Box>
  );
};

export default Home;
