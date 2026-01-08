/**
 * Learner Home Page
 * Main interaction page with emoji checker, avatar, and focus areas
 */

import React, { useState, useEffect } from 'react';
import {
  Container,
  Box,
  Typography,
  Card,
  CardContent,
  Button,
  Grid,
  IconButton,
} from '@mui/material';
import {
  VolumeUp,
  VolumeOff,
  Lock,
} from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../../contexts/AuthContext';
import { useLanguage } from '../../i18n/LanguageContext';
import EmojiMoodChecker from '../../components/Session/EmojiMoodChecker';
import { Haptics, ImpactStyle } from '@capacitor/haptics';
import { stopCurrentAudio } from '../../services/elevenLabsTTS';
const learnerBg = '/assets/learnerbgfinal.png';

const LearnerHome = () => {
  const navigate = useNavigate();
  const { currentProfile } = useAuth();
  const { t } = useLanguage();

  const [currentMood, setCurrentMood] = useState(null);
  const [isMuted, setIsMuted] = useState(false);

  // Pastel Color Palette for Activities
  const ACTIVITY_COLORS = [
    '#FEE2E2', // Soft Red
    '#FEF3C7', // Soft Amber
    '#DBEAFE', // Soft Blue
    '#FCE7F3', // Soft Pink
    '#D1FAE5', // Soft Emerald
    '#EDE9FE', // Soft Violet
  ];

  // Focus areas matching CreateProfile.jsx SKILLS_CONFIG exactly
  const FOCUS_AREAS = [
    { id: 'social-skills', icon: '🤝', label: t.learner.skills.socialSkills },
    { id: 'emotion-intelligence', icon: '❤️', label: t.learner.skills.emotionIntelligence },
    { id: 'thought-expression', icon: '🗣️', label: t.learner.skills.thoughtExpression },
    { id: 'cognitive-growth', icon: '🧠', label: t.learner.skills.cognitiveGrowth },
    { id: 'life-skills', icon: '🌟', label: t.learner.skills.lifeSkills },
  ];

  // Filter to user's selected focus areas
  let activeAreas = [];
  if (currentProfile?.focus_areas && Array.isArray(currentProfile.focus_areas) && currentProfile.focus_areas.length > 0) {
    activeAreas = currentProfile.focus_areas
      .map(areaId => FOCUS_AREAS.find(area => area.id === areaId))
      .filter(Boolean);
  } else {
    activeAreas = FOCUS_AREAS;
  }

  useEffect(() => {
    // Stop audio on unmount
    return () => {
      stopCurrentAudio();
    };
  }, []);

  const handleMoodSelect = async (mood) => {
    setCurrentMood(mood.id);
    try {
      await Haptics.impact({ style: ImpactStyle.Medium });
    } catch (e) { }

    if (!isMuted) {
      // Optional: Short feedback
    }
  };

  const handleStartSession = async () => {
    try {
      await Haptics.impact({ style: ImpactStyle.Heavy });
    } catch (e) { }

    const firstFocusArea = currentProfile?.focus_areas && Array.isArray(currentProfile.focus_areas) && currentProfile.focus_areas.length > 0
      ? currentProfile.focus_areas[0]
      : null;

    const url = firstFocusArea
      ? `/session/${currentProfile?.id || 'default'}?focus=${firstFocusArea}`
      : `/session/${currentProfile?.id || 'default'}`;

    navigate(url);
  };

  const handleFocusAreaSelect = (area) => {
    if (!isMuted) {
      // Optional feedback
    }
    navigate(`/session/${currentProfile?.id}?focus=${area.id}`);
  };

  const handleParentMode = () => {
    navigate('/parent/dashboard');
  };

  return (
    <Box sx={{
      minHeight: '100%',
      // Use 100vh only if we want to ensure it fills the viewport, 
      // but let Layout handle the scrolling.
      height: '100%',
      backgroundImage: `url(${learnerBg})`,
      backgroundSize: 'cover',
      backgroundPosition: 'center',
      backgroundRepeat: 'no-repeat',
      backgroundAttachment: 'fixed',
      overflowX: 'hidden',
      overflowY: 'auto',
      display: 'flex',
      flexDirection: 'column'
    }}> {/* Themed Background Image */}

      {/* 1. App Header - Floating Pill Profile Card */}
      <Box
        sx={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          mx: 2,
          mt: {
            xs: `calc(72px + env(safe-area-inset-top, 20px))`, // mobile header ~56px + 16px
            sm: `calc(80px + env(safe-area-inset-top, 24px))`  // desktop header ~64px + 16px
          },
          px: 2,
          py: 1,
          bgcolor: 'rgba(255, 255, 255, 0.3)',
          backdropFilter: 'blur(12px)',
          WebkitBackdropFilter: 'blur(12px)',
          borderRadius: 50,
          border: '1px solid rgba(255, 255, 255, 0.3)',
          boxShadow: '0 8px 32px rgba(0, 0, 0, 0.05)',
          zIndex: 10,
        }}
      >
        {/* Left: Avatar & Name */}
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5 }}>
          <Box
            sx={{
              width: 36,
              height: 36,
              borderRadius: '50%',
              bgcolor: 'rgba(255, 255, 255, 0.8)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontSize: '1rem',
              fontWeight: 800,
              color: '#4F46E5',
              boxShadow: '0 2px 10px rgba(0,0,0,0.05)'
            }}
          >
            {currentProfile?.name ? currentProfile.name.charAt(0).toUpperCase() : 'K'}
          </Box>
          <Typography variant="body1" fontWeight={800} sx={{ color: '#1E1B4B', fontSize: '1rem' }}>
            {currentProfile?.name || 'Friend'}
          </Typography>
        </Box>

        {/* Right: Controls */}
        <Box sx={{ display: 'flex', gap: 1 }}>
          <IconButton
            onClick={() => setIsMuted(!isMuted)}
            size="small"
            sx={{
              color: '#4F46E5',
              bgcolor: 'rgba(255, 255, 255, 0.6)',
              '&:hover': { bgcolor: 'rgba(255, 255, 255, 0.8)' }
            }}
          >
            {isMuted ? <VolumeOff fontSize="small" /> : <VolumeUp fontSize="small" />}
          </IconButton>
          <IconButton
            onClick={handleParentMode}
            size="small"
            sx={{
              color: '#4F46E5',
              bgcolor: 'rgba(255, 255, 255, 0.6)',
              '&:hover': { bgcolor: 'rgba(255, 255, 255, 0.8)' }
            }}
          >
            <Lock fontSize="small" />
          </IconButton>
        </Box>
      </Box>

      <Container maxWidth="sm" sx={{
        pt: 1,
        pb: { xs: 4, sm: 2 },
        display: 'flex',
        flexDirection: 'column',
        flex: 1,
        minHeight: 0,
        gap: 2
      }}>

        {/* Spacer to push everything down */}
        <Box sx={{ flex: 1 }} />

        {/* 2. Hero Mood Section - Centered */}
        <Card
          sx={{
            borderRadius: 1.5,
            boxShadow: '0 8px 30px rgba(79, 70, 229, 0.05)',
            bgcolor: 'rgba(255, 255, 255, 0.4)',
            backdropFilter: 'blur(10px)',
            WebkitBackdropFilter: 'blur(10px)',
            border: '1px solid rgba(255, 255, 255, 0.4)',
            overflow: 'hidden',
            flexShrink: 0
          }}
        >
          <CardContent sx={{ p: 2, pb: 0, '&:last-child': { pb: 0 }, textAlign: 'center' }}>
            <Typography variant="h4" fontWeight={900} sx={{ color: 'white', mb: 2, textShadow: '0 2px 10px rgba(0,0,0,0.1)', fontSize: '1.75rem' }}>
              How are you feeling?
            </Typography>

            <Box sx={{
              bgcolor: 'rgba(255, 255, 255, 0.5)',
              p: 2,
              mx: -2,
              mb: 0,
              mt: 2
            }}>
              <EmojiMoodChecker
                onMoodSelect={handleMoodSelect}
                selectedMood={currentMood}
                size="medium"
              />
            </Box>
          </CardContent>
        </Card>

        {/* 4. Session Card (Primary CTA) */}
        <Card
          sx={{
            borderRadius: 1.5,
            boxShadow: '0 4px 20px rgba(0,0,0,0.03)',
            bgcolor: 'rgba(255, 255, 255, 0.4)',
            backdropFilter: 'blur(10px)',
            WebkitBackdropFilter: 'blur(10px)',
            border: '1px solid rgba(255, 255, 255, 0.4)',
            flexShrink: 0
          }}
        >
          <CardContent sx={{ p: 2, textAlign: 'center' }}>
            <Typography variant="body1" sx={{ color: '#4B5563', mb: 1.5, fontWeight: 700 }}>
              Ready to learn and grow?
            </Typography>
            <Button
              variant="contained"
              fullWidth
              onClick={handleStartSession}
              sx={{
                bgcolor: 'white',
                color: '#4338CA', // Indigo 700
                py: 1.75, // Slightly more padding
                borderRadius: 50,
                fontSize: '1.25rem', // Larger font
                fontWeight: 900, // Even bolder
                textTransform: 'none',
                boxShadow: '0 10px 30px rgba(255, 255, 255, 0.4)',
                '&:hover': {
                  bgcolor: 'rgba(255, 255, 255, 0.9)',
                  transform: 'translateY(-2px)',
                },
                transition: 'all 0.2s cubic-bezier(0.34, 1.56, 0.64, 1)'
              }}
            >
              Start Session
            </Button>
          </CardContent>
        </Card>

        {/* Spacer to push Activities to bottom */}
        <Box sx={{ flex: 1 }} />

        {/* 3. Bottom Section: Activities */}
        <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2, mt: 'auto' }}>
          {/* Activities Grid (Mini) */}
          <Box sx={{ px: 1 }}>
            <Grid container spacing={1}>
              {activeAreas.map((area, index) => (
                <Grid item xs={6} key={area.id}>
                  <Card
                    onClick={() => handleFocusAreaSelect(area)}
                    sx={{
                      borderRadius: 1,
                      boxShadow: '0 2px 8px rgba(0,0,0,0.03)',
                      bgcolor: `${ACTIVITY_COLORS[index % ACTIVITY_COLORS.length]}CC`,
                      backdropFilter: 'blur(8px)',
                      WebkitBackdropFilter: 'blur(8px)',
                      border: '1px solid rgba(255, 255, 255, 0.3)',
                      cursor: 'pointer',
                      transition: 'all 0.2s ease',
                      '&:hover': { transform: 'translateY(-2px)' }
                    }}
                  >
                    <Box sx={{ py: 1, px: 1, display: 'flex', alignItems: 'center', gap: 1 }}>
                      <Typography sx={{ fontSize: '1rem' }}>{area.icon}</Typography>
                      <Typography variant="caption" fontWeight={700} sx={{ color: '#1E1B4B', lineHeight: 1 }}>
                        {area.label}
                      </Typography>
                    </Box>
                  </Card>
                </Grid>
              ))}
            </Grid>
          </Box>

        </Box>
      </Container>
    </Box>
  );
};

export default LearnerHome;
