/**
 * Mode Selection Screen
 * Allows users to choose between Child (learner) or Family (parent) mode
 * Shown after onboarding screen
 */

import React, { useState, useEffect } from 'react';
import {
  Box,
  Container,
  Typography,
  Button,
  Card,
  CardContent,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  Alert,
  CircularProgress,
} from '@mui/material';
// Using emoji for child and family instead of icons
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { useLanguage } from '../i18n/LanguageContext';
import { verifyParentPin } from '../utils/parentPin';
const sunsetBg = '/assets/sunset.png';

const ModeSelection = () => {
  const navigate = useNavigate();
  const { user, currentProfile, selectProfile } = useAuth();
  const { t } = useLanguage();
  const [hasLearnerProfile, setHasLearnerProfile] = useState(false);
  const [loading, setLoading] = useState(true);
  const [pinDialogOpen, setPinDialogOpen] = useState(false);
  const [pin, setPin] = useState('');
  const [pinError, setPinError] = useState('');
  const [verifyingPin, setVerifyingPin] = useState(false);

  // Check if there's a learner profile available
  useEffect(() => {
    const checkLearnerProfile = async () => {
      try {
        const lastProfile = localStorage.getItem('komal_last_profile');
        const lastProfileType = localStorage.getItem('komal_last_profile_type');

        if (lastProfile && lastProfileType === 'learner') {
          setHasLearnerProfile(true);
        } else if (currentProfile && currentProfile.id) {
          setHasLearnerProfile(true);
        }
      } catch (error) {
        console.error('[ModeSelection] Error checking learner profile:', error);
      } finally {
        setLoading(false);
      }
    };

    checkLearnerProfile();
  }, [currentProfile]);

  const handleChildClick = async () => {
    try {
      const lastProfile = localStorage.getItem('komal_last_profile');
      const lastProfileType = localStorage.getItem('komal_last_profile_type');

      if (lastProfile && lastProfileType === 'learner') {
        // Load the last selected learner profile
        await selectProfile(lastProfile, 'learner');
      }

      navigate('/learner');
    } catch (error) {
      console.error('[ModeSelection] Error loading learner profile:', error);
      // If error, still navigate to learner page
      navigate('/learner');
    }
  };

  const handleFamilyClick = () => {
    setPinDialogOpen(true);
    setPin('');
    setPinError('');
  };

  const handlePinSubmit = async () => {
    // Validate PIN format
    if (!pin || pin.length !== 4 || !/^\d{4}$/.test(pin)) {
      setPinError(t.profileSelect.pinError || 'Please enter a 4-digit PIN');
      return;
    }

    setVerifyingPin(true);
    setPinError('');

    try {
      if (!user) {
        setPinError('User not found. Please sign in again.');
        return;
      }

      const isValid = await verifyParentPin(user, pin);

      if (isValid) {
        setPinDialogOpen(false);
        setPin('');
        setPinError('');
        navigate('/profile-select');
      } else {
        setPinError(t.profileSelect.pinIncorrect || 'Incorrect PIN. Please try again.');
        setPin('');
      }
    } catch (error) {
      console.error('[ModeSelection] Error verifying PIN:', error);
      setPinError(t.profileSelect.pinRequired || 'Failed to verify PIN. Please try again.');
      setPin('');
    } finally {
      setVerifyingPin(false);
    }
  };

  const handlePinDialogClose = () => {
    if (!verifyingPin) {
      setPinDialogOpen(false);
      setPin('');
      setPinError('');
    }
  };

  if (loading) {
    return (
      <Box
        sx={{
          minHeight: '100vh',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          background: 'linear-gradient(135deg, #F8FAFC 0%, #EEF2FF 100%)',
        }}
      >
        <CircularProgress />
      </Box>
    );
  }

  return (
    <Box
      sx={{
        height: '100%',
        backgroundImage: `url(${sunsetBg})`,
        backgroundSize: 'cover',
        backgroundPosition: 'center',
        backgroundRepeat: 'no-repeat',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        overflow: 'hidden',
        p: { xs: 1.5, sm: 2 },
      }}
    >
      <Container maxWidth="sm" sx={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
        <Box sx={{ textAlign: 'center', mb: { xs: 3, sm: 6 } }}>
          <Typography
            variant="h4"
            sx={{
              fontWeight: 900,
              color: 'white',
              mb: 0.5,
              fontSize: { xs: '2rem', sm: '3rem' },
              textShadow: '0 2px 10px rgba(0,0,0,0.2)'
            }}
          >
            {t.common.modeSelection.title}
          </Typography>
          <Typography
            variant="body1"
            sx={{
              color: 'rgba(255, 255, 255, 0.9)',
              fontSize: { xs: '0.875rem', sm: '1.1rem' },
              textShadow: '0 1px 5px rgba(0,0,0,0.1)'
            }}
          >
            {t.common.modeSelection.subtitle}
          </Typography>
        </Box>

        <Box
          sx={{
            display: 'flex',
            flexDirection: { xs: 'column', sm: 'row' },
            gap: { xs: 1, sm: 3 },
            justifyContent: 'center',
            alignItems: 'stretch',
            overflow: 'hidden'
          }}
        >
          {/* Child Option */}
          {hasLearnerProfile && (
            <Card
              sx={{
                flex: 1,
                maxWidth: { xs: '100%', sm: '280px' },
                cursor: 'pointer',
                transition: 'all 0.3s ease',
                border: '2px solid transparent',
                '&:hover': {
                  transform: 'translateY(-8px)',
                  boxShadow: '0 12px 24px rgba(0, 0, 0, 0.15)',
                  border: '2px solid',
                  borderColor: 'primary.main',
                },
              }}
              onClick={handleChildClick}
            >
              <CardContent
                sx={{
                  display: 'flex',
                  flexDirection: 'column',
                  alignItems: 'center',
                  textAlign: 'center',
                  p: { xs: 1.5, sm: 4 },
                }}
              >
                {/* Circular frame with child illustration */}
                <Box
                  sx={{
                    width: { xs: 80, sm: 160 },
                    height: { xs: 80, sm: 160 },
                    borderRadius: '50%',
                    bgcolor: 'background.paper',
                    border: '3px solid',
                    borderColor: 'primary.light',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    mb: { xs: 0.5, sm: 3 },
                    boxShadow: '0 4px 12px rgba(0, 0, 0, 0.1)',
                    overflow: 'hidden',
                  }}
                >
                  <Box
                    component="img"
                    src="/icons/child.jpg"
                    alt="Child"
                    sx={{
                      width: '100%',
                      height: '100%',
                      objectFit: 'cover',
                    }}
                  />
                </Box>

                {/* Button */}
                <Button
                  variant="contained"
                  fullWidth
                  sx={{
                    py: 1.5,
                    borderRadius: 2,
                    textTransform: 'none',
                    fontSize: '1rem',
                    fontWeight: 600,
                    bgcolor: '#FFF9C4', // Pastel Yellow
                    color: '#5D4037',
                    '&:hover': {
                      bgcolor: '#FFF59D',
                    },
                  }}
                >
                  {t.common.modeSelection.child}
                </Button>
                <Typography
                  variant="body2"
                  sx={{
                    color: 'text.secondary',
                    mt: { xs: 0.5, sm: 1.5 },
                    fontSize: { xs: '0.7rem', sm: '0.875rem' }
                  }}
                >
                  {t.common.modeSelection.childDescription}
                </Typography>
              </CardContent>
            </Card>
          )}

          {/* Family Option */}
          <Card
            sx={{
              flex: 1,
              maxWidth: { xs: '100%', sm: '280px' },
              cursor: 'pointer',
              transition: 'all 0.3s ease',
              border: '2px solid transparent',
              '&:hover': {
                transform: 'translateY(-8px)',
                boxShadow: '0 12px 24px rgba(0, 0, 0, 0.15)',
                border: '2px solid',
                borderColor: 'primary.main',
              },
            }}
            onClick={handleFamilyClick}
          >
            <CardContent
              sx={{
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                textAlign: 'center',
                p: { xs: 1.5, sm: 4 },
              }}
            >
              {/* Circular frame with family illustration */}
              <Box
                sx={{
                  width: { xs: 80, sm: 160 },
                  height: { xs: 80, sm: 160 },
                  borderRadius: '50%',
                  bgcolor: 'background.paper',
                  border: '3px solid',
                  borderColor: 'primary.light',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  mb: { xs: 0.5, sm: 3 },
                  boxShadow: '0 4px 12px rgba(0, 0, 0, 0.1)',
                  overflow: 'hidden',
                }}
              >
                <Box
                  component="img"
                  src="/icons/family.jpg"
                  alt="Family"
                  sx={{
                    width: '100%',
                    height: '100%',
                    objectFit: 'cover',
                  }}
                />
              </Box>

              {/* Button */}
              <Button
                variant="contained"
                fullWidth
                sx={{
                  py: 1.5,
                  borderRadius: 2,
                  textTransform: 'none',
                  fontSize: '1rem',
                  fontWeight: 600,
                  bgcolor: '#E3F2FD', // Pastel Blue
                  color: '#1565C0',
                  '&:hover': {
                    bgcolor: '#BBDEFB',
                  },
                }}
              >
                {t.common.modeSelection.family}
              </Button>
              <Typography
                variant="body2"
                sx={{
                  color: 'text.secondary',
                  mt: { xs: 0.5, sm: 1.5 },
                  fontSize: { xs: '0.7rem', sm: '0.875rem' }
                }}
              >
                {t.common.modeSelection.familyDescription}
              </Typography>
            </CardContent>
          </Card>
        </Box>

        {/* PIN Dialog */}
        <Dialog
          open={pinDialogOpen}
          onClose={handlePinDialogClose}
          maxWidth="xs"
          fullWidth
        >
          <DialogTitle>
            {t.profileSelect.enterPinForParent}
          </DialogTitle>
          <DialogContent>
            <TextField
              autoFocus
              margin="dense"
              label={t.profileSelect.pin}
              type="password"
              fullWidth
              variant="outlined"
              value={pin}
              onChange={(e) => {
                const value = e.target.value.replace(/\D/g, '').slice(0, 4);
                setPin(value);
                setPinError('');
              }}
              error={!!pinError}
              helperText={pinError || t.profileSelect.pinHelper}
              disabled={verifyingPin}
              inputProps={{
                maxLength: 4,
                inputMode: 'numeric',
                pattern: '[0-9]*',
              }}
            />
            {pinError && (
              <Alert severity="error" sx={{ mt: 2 }}>
                {pinError}
              </Alert>
            )}
          </DialogContent>
          <DialogActions>
            <Button
              onClick={handlePinDialogClose}
              disabled={verifyingPin}
            >
              {t.common.cancel}
            </Button>
            <Button
              onClick={handlePinSubmit}
              variant="contained"
              disabled={verifyingPin || pin.length !== 4}
            >
              {verifyingPin ? (
                <CircularProgress size={20} />
              ) : (
                t.profileSelect.continue
              )}
            </Button>
          </DialogActions>
        </Dialog>
      </Container>
    </Box>
  );
};

export default ModeSelection;

