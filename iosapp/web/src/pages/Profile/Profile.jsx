/**
 * Profile Page
 * User profile information
 * Shows user data for logged in user/parent
 */

import React, { useState, useEffect } from 'react';
import {
  Container,
  Box,
  Typography,
  Paper,
  TextField,
  Grid,
  Button,
  IconButton,
  Alert,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  useTheme,
  useMediaQuery,
} from '@mui/material';
import {
  Email,
  Lock,
  Visibility,
  VisibilityOff,
  Edit,
  School,
  Person,
  Delete,
  Warning,
  Add,
} from '@mui/icons-material';
import { useAuth } from '../../contexts/AuthContext';
import { useLanguage } from '../../i18n/LanguageContext';
import { getParentPin, saveParentPin, verifyParentPin } from '../../utils/parentPin';
import { gradients } from '../../theme';
import { supabase } from '../../services/supabase';
import { useNavigate } from 'react-router-dom';
import LearnerAvatar from '../../components/common/LearnerAvatar';
import { LanguageSelector } from '../../components/LanguageSelector';
import { Language as LanguageIcon } from '@mui/icons-material';

const Profile = () => {
  const { user, currentProfile, switchProfile } = useAuth();
  const { t, getCurrentLanguageName } = useLanguage();
  const navigate = useNavigate();
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('sm'));

  const [userEmail, setUserEmail] = useState('');
  const [currentPin, setCurrentPin] = useState('');
  const [pinDialogOpen, setPinDialogOpen] = useState(false);
  const [pinUnlockDialogOpen, setPinUnlockDialogOpen] = useState(true); // Show PIN dialog on mount
  const [unlockPin, setUnlockPin] = useState('');
  const [showUnlockPin, setShowUnlockPin] = useState(false);
  const [unlockPinError, setUnlockPinError] = useState('');
  const [isUnlocked, setIsUnlocked] = useState(false);
  const [newPin, setNewPin] = useState('');
  const [confirmPin, setConfirmPin] = useState('');
  const [showNewPin, setShowNewPin] = useState(false);
  const [showConfirmPin, setShowConfirmPin] = useState(false);
  const [pinError, setPinError] = useState('');
  const [pinSuccess, setPinSuccess] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [learners, setLearners] = useState([]);
  const [isLoadingLearners, setIsLoadingLearners] = useState(false);
  // Delete learner states
  const [deleteConfirmDialogOpen, setDeleteConfirmDialogOpen] = useState(false);
  const [deletePinDialogOpen, setDeletePinDialogOpen] = useState(false);
  const [learnerToDelete, setLearnerToDelete] = useState(null);
  const [deletePin, setDeletePin] = useState('');
  const [showDeletePin, setShowDeletePin] = useState(false);
  const [deletePinError, setDeletePinError] = useState('');
  const [isDeleting, setIsDeleting] = useState(false);

  useEffect(() => {
    if (user) {
      setUserEmail(user.email || '');
    }
  }, [user]);

  useEffect(() => {
    // Load current PIN from user level
    const loadPin = async () => {
      if (user) {
        const pin = await getParentPin(user);
        setCurrentPin(pin);
      } else {
        setCurrentPin('1234'); // Default PIN
      }
    };
    loadPin();
  }, [user]);

  // Load learner profiles
  useEffect(() => {
    const loadLearners = async () => {
      if (!user || !isUnlocked) return;

      setIsLoadingLearners(true);
      try {
        // Get user record ID
        const { data: userRecord } = await supabase
          .from('users')
          .select('id')
          .eq('auth_id', user.id)
          .single();

        if (!userRecord) return;

        // Fetch all learners for this user
        const { data: learnersData, error } = await supabase
          .from('learners')
          .select('*')
          .eq('user_id', userRecord.id)
          .order('created_at', { ascending: false });

        if (error) throw error;
        setLearners(learnersData || []);
      } catch (err) {
        console.error('Failed to load learners:', err);
      } finally {
        setIsLoadingLearners(false);
      }
    };

    loadLearners();
  }, [user, isUnlocked]);

  // Handle PIN unlock for Profile page access
  const handleUnlockProfile = async () => {
    setUnlockPinError('');

    if (!unlockPin || unlockPin.length !== 4) {
      setUnlockPinError(t.profile.pleaseEnter4DigitPin);
      return;
    }

    const isValidPin = await verifyParentPin(user, unlockPin);
    if (isValidPin) {
      setIsUnlocked(true);
      setPinUnlockDialogOpen(false);
      setUnlockPin('');
    } else {
      setUnlockPinError(t.profile.incorrectPin);
      setUnlockPin('');
    }
  };

  const handleOpenPinDialog = () => {
    setPinDialogOpen(true);
    setNewPin('');
    setConfirmPin('');
    setPinError('');
    setPinSuccess(false);
  };

  const handleClosePinDialog = () => {
    setPinDialogOpen(false);
    setNewPin('');
    setConfirmPin('');
    setPinError('');
    setPinSuccess(false);
    setShowNewPin(false);
    setShowConfirmPin(false);
  };

  const handleSavePin = async () => {
    setPinError('');
    setPinSuccess(false);

    // Validate PIN
    if (!newPin || newPin.length !== 4 || !/^\d{4}$/.test(newPin)) {
      setPinError(t.profile.pinMustBe4Digits);
      return;
    }

    if (newPin !== confirmPin) {
      setPinError(t.profile.pinsDoNotMatch);
      return;
    }

    setIsSaving(true);

    try {
      // Save PIN at user level
      const success = await saveParentPin(user, newPin);

      if (success) {
        setCurrentPin(newPin);
        setPinSuccess(true);

        // Close dialog after a short delay
        setTimeout(() => {
          handleClosePinDialog();
        }, 1500);
      } else {
        throw new Error('Failed to save PIN');
      }
    } catch (error) {
      console.error('Failed to save PIN:', error);
      setPinError(error.message || t.profile.failedToSavePin);
    } finally {
      setIsSaving(false);
    }
  };

  // Delete learner handlers
  const handleDeleteClick = (learner) => {
    setLearnerToDelete(learner);
    setDeleteConfirmDialogOpen(true);
  };

  const handleDeleteConfirm = () => {
    setDeleteConfirmDialogOpen(false);
    setDeletePinDialogOpen(true);
    setDeletePin('');
    setDeletePinError('');
  };

  const handleDeleteCancel = () => {
    setDeleteConfirmDialogOpen(false);
    setLearnerToDelete(null);
  };

  const handleDeletePinChange = (e) => {
    const value = e.target.value.replace(/\D/g, '').slice(0, 4);
    setDeletePin(value);
    setDeletePinError('');
  };

  const handleDeletePinSubmit = async () => {
    setDeletePinError('');

    if (!deletePin || deletePin.length !== 4 || !/^\d{4}$/.test(deletePin)) {
      setDeletePinError(t.profile.pinMustBe4Digits);
      return;
    }

    // Verify PIN
    const isValidPin = await verifyParentPin(user, deletePin);
    if (!isValidPin) {
      setDeletePinError(t.profile.incorrectPin);
      setDeletePin('');
      return;
    }

    // PIN is correct, proceed with deletion
    await handleDeleteLearner();
  };

  const handleDeleteLearner = async () => {
    if (!learnerToDelete) return;

    setIsDeleting(true);
    setDeletePinError('');

    try {
      // Get user record ID
      const { data: userRecord } = await supabase
        .from('users')
        .select('id')
        .eq('auth_id', user.id)
        .single();

      if (!userRecord) {
        throw new Error(t.profile.userRecordNotFound);
      }

      // Delete learner from database
      const { error: deleteError } = await supabase
        .from('learners')
        .delete()
        .eq('id', learnerToDelete.id)
        .eq('user_id', userRecord.id);

      if (deleteError) throw deleteError;

      // Remove from local state
      setLearners(prev => prev.filter(l => l.id !== learnerToDelete.id));

      // If this was the current profile, clear it and switch to profile select
      if (currentProfile?.id === learnerToDelete.id) {
        switchProfile();
        navigate('/profile-select');
      }

      // Close dialogs
      setDeletePinDialogOpen(false);
      setLearnerToDelete(null);
      setDeletePin('');

    } catch (error) {
      console.error('Failed to delete learner:', error);
      setDeletePinError(error.message || t.profile.failedToDeleteLearner);
    } finally {
      setIsDeleting(false);
    }
  };

  const handleCloseDeletePinDialog = () => {
    setDeletePinDialogOpen(false);
    setDeletePin('');
    setDeletePinError('');
    setShowDeletePin(false);
    setLearnerToDelete(null);
  };

  // Show PIN unlock dialog if not unlocked
  if (!isUnlocked) {
    return (
      <Box
        sx={{
          height: 'calc(100vh - 64px)',
          width: '100%',
          overflow: 'hidden',
          backgroundColor: '#ffffff',
          backgroundImage: 'radial-gradient(circle, rgba(139, 92, 246, 0.15) 1.5px, transparent 1.5px)',
          backgroundSize: '20px 20px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Box sx={{ width: '100%', maxWidth: 320, textAlign: 'center', px: 3 }}>
          <Box
            sx={{
              width: 72,
              height: 72,
              borderRadius: '50%',
              backgroundColor: 'rgba(156, 163, 175, 0.2)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              mx: 'auto',
              mb: 2.5,
            }}
          >
            <Lock sx={{ fontSize: 32, color: '#6B7280' }} />
          </Box>
          <Typography
            variant="h6"
            fontWeight={600}
            sx={{
              mb: 0.5,
              fontSize: '1.125rem',
              color: '#374151',
            }}
          >
            {t.profile.parentAccessRequired}
          </Typography>
          <Typography
            variant="body2"
            sx={{
              mb: 3,
              fontSize: '0.875rem',
              color: '#9CA3AF',
            }}
          >
            {t.profile.enterPinToAccess}
          </Typography>
          <TextField
            fullWidth
            label={t.profile.enterPin}
            type={showUnlockPin ? 'text' : 'password'}
            value={unlockPin}
            onChange={(e) => {
              const value = e.target.value.replace(/\D/g, '').slice(0, 4);
              setUnlockPin(value);
              setUnlockPinError('');
            }}
            onKeyPress={(e) => {
              if (e.key === 'Enter' && unlockPin.length === 4) {
                handleUnlockProfile();
              }
            }}
            error={!!unlockPinError}
            helperText={unlockPinError}
            size="small"
            sx={{
              mb: 2,
            }}
            InputProps={{
              startAdornment: <Lock sx={{ mr: 1, color: '#9CA3AF', fontSize: 18 }} />,
              endAdornment: (
                <IconButton
                  onClick={() => setShowUnlockPin(!showUnlockPin)}
                  edge="end"
                  size="small"
                >
                  {showUnlockPin ? <VisibilityOff sx={{ fontSize: 18 }} /> : <Visibility sx={{ fontSize: 18 }} />}
                </IconButton>
              ),
            }}
          />
          <Button
            variant="contained"
            onClick={handleUnlockProfile}
            disabled={unlockPin.length !== 4}
            fullWidth
            sx={{
              background: 'rgba(139, 92, 246, 0.1)',
              backdropFilter: 'blur(8px)',
              color: '#6B7280',
              fontWeight: 600,
              py: 1.25,
              fontSize: '0.875rem',
              boxShadow: 'none',
              border: '1px solid rgba(139, 92, 246, 0.2)',
              '&:hover': {
                background: 'rgba(139, 92, 246, 0.15)',
                boxShadow: 'none',
              },
              '&.Mui-disabled': {
                background: 'rgba(156, 163, 175, 0.1)',
                color: '#D1D5DB',
                border: '1px solid rgba(156, 163, 175, 0.2)',
              },
            }}
          >
            {t.profile.unlock}
          </Button>
        </Box>
      </Box>
    );
  }


  return (
    <Box sx={{ minHeight: '100vh', bgcolor: 'background.default' }}>
      <Container
        maxWidth="md"
        sx={{
          py: { xs: 0, sm: 3, md: 4 },
          px: { xs: 0, sm: 2, md: 3 },
        }}
      >
        {/* Header Section */}
        <Box sx={{ mb: { xs: 2, sm: 3, md: 4 }, px: { xs: 2, sm: 0 }, pt: { xs: 3, sm: 0 } }}>
          <Typography
            variant="h4"
            fontWeight={700}
            gutterBottom
            sx={{
              background: gradients.primary,
              backgroundClip: 'text',
              WebkitBackgroundClip: 'text',
              WebkitTextFillColor: 'transparent',
              fontSize: { xs: '1.5rem', sm: '1.75rem', md: '2rem' },
            }}
          >
            {t.profile.title}
          </Typography>
          <Typography variant="body1" color="text.secondary" sx={{ fontSize: { xs: '0.875rem', sm: '1rem' } }}>
            {t.profile.subtitle}
          </Typography>
        </Box>

        <Grid container spacing={{ xs: 0, sm: 3 }}>
          {/* Email Card */}
          <Grid item xs={12} sx={{ px: { xs: 0, sm: 'inherit' }, width: '100%' }}>
            <Paper
              elevation={0}
              sx={{
                p: { xs: 2.5, sm: 3, md: 4 },
                borderRadius: { xs: 0, sm: 3 },
                border: { xs: 'none', sm: '1px solid rgba(0, 0, 0, 0.06)' },
                borderBottom: { xs: '1px solid rgba(0,0,0,0.06)', sm: 'none' },
                width: '100%',
                mx: { xs: 0, sm: 'inherit' },
              }}
            >
              <Box sx={{ display: 'flex', alignItems: 'center', mb: { xs: 2, sm: 3 } }}>
                <Box
                  sx={{
                    width: { xs: 36, sm: 40 },
                    height: { xs: 36, sm: 40 },
                    borderRadius: 2,
                    background: gradients.primary,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    mr: 1.5,
                  }}
                >
                  <Email sx={{ color: 'white', fontSize: { xs: 20, sm: 22 } }} />
                </Box>
                <Typography variant="h6" fontWeight={600} sx={{ fontSize: { xs: '1rem', sm: '1.125rem' } }}>
                  {t.profile.emailAddress}
                </Typography>
              </Box>

              <TextField
                fullWidth
                label={t.profile.email}
                value={userEmail}
                disabled
                size={isMobile ? 'small' : 'medium'}
                sx={{
                  '& .MuiOutlinedInput-root': {
                    background: 'rgba(0, 0, 0, 0.02)',
                  },
                }}
                InputProps={{
                  startAdornment: (
                    <Email sx={{ mr: 1.5, color: 'text.secondary', fontSize: { xs: 18, sm: 20 } }} />
                  ),
                }}
              />
            </Paper>
          </Grid>

          {/* Parent PIN Settings Card */}
          <Grid item xs={12} sx={{ px: { xs: 0, sm: 'inherit' }, width: '100%' }}>
            <Paper
              elevation={0}
              sx={{
                p: { xs: 2.5, sm: 3, md: 4 },
                borderRadius: { xs: 0, sm: 3 },
                border: { xs: 'none', sm: '1px solid rgba(0, 0, 0, 0.06)' },
                borderTop: { xs: '1px solid rgba(0,0,0,0.06)', sm: 'none' },
                width: '100%',
                mx: { xs: 0, sm: 'inherit' },
              }}
            >
              <Box sx={{
                display: 'flex',
                alignItems: { xs: 'flex-start', sm: 'center' },
                justifyContent: 'space-between',
                flexDirection: { xs: 'column', sm: 'row' },
                gap: { xs: 2, sm: 0 },
                mb: { xs: 2, sm: 3 }
              }}>
                <Box sx={{ display: 'flex', alignItems: 'center', flex: 1 }}>
                  <Box
                    sx={{
                      width: { xs: 36, sm: 40 },
                      height: { xs: 36, sm: 40 },
                      borderRadius: 2,
                      background: gradients.primary,
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      mr: 1.5,
                    }}
                  >
                    <Lock sx={{ color: 'white', fontSize: { xs: 20, sm: 22 } }} />
                  </Box>
                  <Box>
                    <Typography variant="h6" fontWeight={600} sx={{ fontSize: { xs: '1rem', sm: '1.125rem' } }}>
                      {t.profile.parentDashboardPin}
                    </Typography>
                    <Typography variant="body2" color="text.secondary" sx={{ fontSize: { xs: '0.8rem', sm: '0.875rem' } }}>
                      {t.profile.parentDashboardPinDescription}
                    </Typography>
                  </Box>
                </Box>
                <Button
                  variant="outlined"
                  startIcon={<Edit />}
                  onClick={handleOpenPinDialog}
                  size={isMobile ? 'small' : 'medium'}
                  sx={{
                    borderWidth: 2,
                    fontWeight: 600,
                    width: { xs: '100%', sm: 'auto' },
                    '&:hover': {
                      borderWidth: 2,
                    },
                  }}
                >
                  {currentPin ? t.profile.changePin : t.profile.setPin}
                </Button>
              </Box>

              <Box
                sx={{
                  p: { xs: 2, sm: 2.5 },
                  borderRadius: 2,
                  background: 'rgba(99, 102, 241, 0.05)',
                  border: '1px solid rgba(99, 102, 241, 0.1)',
                  display: 'flex',
                  alignItems: 'center',
                  gap: { xs: 1.5, sm: 2 },
                }}
              >
                <Lock sx={{ color: 'primary.main', fontSize: { xs: 20, sm: 24 } }} />
                <Box sx={{ flex: 1 }}>
                  <Typography variant="caption" color="text.secondary" fontWeight={600} sx={{ textTransform: 'uppercase', letterSpacing: '0.5px', display: 'block', mb: 0.5, fontSize: { xs: '0.65rem', sm: '0.7rem' } }}>
                    {t.profile.currentPin}
                  </Typography>
                  <Typography variant="body1" fontWeight={600} sx={{ fontFamily: 'monospace', fontSize: { xs: '1rem', sm: '1.25rem' }, letterSpacing: { xs: '0.3em', sm: '0.5em' } }}>
                    {currentPin ? '••••' : t.profile.notSet}
                  </Typography>
                </Box>
              </Box>

              <Box sx={{ mt: { xs: 1.5, sm: 2 }, p: { xs: 1.5, sm: 2 }, borderRadius: 2, background: 'rgba(16, 185, 129, 0.05)', border: '1px solid rgba(16, 185, 129, 0.1)' }}>
                <Typography variant="body2" color="text.secondary" sx={{ display: 'flex', alignItems: 'flex-start', gap: 1, fontSize: { xs: '0.8rem', sm: '0.875rem' } }}>
                  <Lock sx={{ fontSize: { xs: 14, sm: 16 }, color: 'success.main', mt: 0.25 }} />
                  {t.profile.pinSecurityNote}
                </Typography>
              </Box>
            </Paper>
          </Grid>

          {/* Language Settings Card */}
          <Grid item xs={12} sx={{ px: { xs: 0, sm: 'inherit' }, width: '100%' }}>
            <Paper
              elevation={0}
              sx={{
                p: { xs: 2.5, sm: 3, md: 4 },
                borderRadius: { xs: 0, sm: 3 },
                border: { xs: 'none', sm: '1px solid rgba(0, 0, 0, 0.06)' },
                borderTop: { xs: '1px solid rgba(0,0,0,0.06)', sm: 'none' },
                width: '100%',
                mx: { xs: 0, sm: 'inherit' },
              }}
            >
              <Box sx={{
                display: 'flex',
                alignItems: { xs: 'flex-start', sm: 'center' },
                justifyContent: 'space-between',
                flexDirection: { xs: 'column', sm: 'row' },
                gap: { xs: 2, sm: 0 },
                mb: { xs: 2, sm: 3 }
              }}>
                <Box sx={{ display: 'flex', alignItems: 'center', flex: 1 }}>
                  <Box
                    sx={{
                      width: { xs: 36, sm: 40 },
                      height: { xs: 36, sm: 40 },
                      borderRadius: 2,
                      background: gradients.primary,
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      mr: 1.5,
                    }}
                  >
                    <LanguageIcon sx={{ color: 'white', fontSize: { xs: 20, sm: 22 } }} />
                  </Box>
                  <Box>
                    <Typography variant="h6" fontWeight={600} sx={{ fontSize: { xs: '1rem', sm: '1.125rem' } }}>
                      {t.profile.languageSettings}
                    </Typography>
                    <Typography variant="body2" color="text.secondary" sx={{ fontSize: { xs: '0.8rem', sm: '0.875rem' } }}>
                      {t.profile.languageSettingsDescription}
                    </Typography>
                  </Box>
                </Box>
              </Box>

              <Box
                sx={{
                  p: { xs: 2, sm: 2.5 },
                  borderRadius: 2,
                  background: 'rgba(99, 102, 241, 0.05)',
                  border: '1px solid rgba(99, 102, 241, 0.1)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  gap: { xs: 1.5, sm: 2 },
                }}
              >
                <Box sx={{ flex: 1 }}>
                  <Typography variant="caption" color="text.secondary" fontWeight={600} sx={{ textTransform: 'uppercase', letterSpacing: '0.5px', display: 'block', mb: 0.5, fontSize: { xs: '0.65rem', sm: '0.7rem' } }}>
                    {t.profile.currentLanguage}
                  </Typography>
                  <Typography variant="body1" fontWeight={600} sx={{ fontSize: { xs: '1rem', sm: '1.125rem' } }}>
                    {getCurrentLanguageName()}
                  </Typography>
                </Box>
                <LanguageSelector variant="chip" showIcon={true} size="medium" />
              </Box>
            </Paper>
          </Grid>

          {/* Learner Profiles Section */}
          {learners.length > 0 && (
            <Grid item xs={12} sx={{ px: { xs: 0, sm: 'inherit' }, width: '100%' }}>
              <Paper
                elevation={0}
                sx={{
                  p: { xs: 2.5, sm: 3, md: 4 },
                  borderRadius: { xs: 0, sm: 3 },
                  border: { xs: 'none', sm: '1px solid rgba(0, 0, 0, 0.06)' },
                  borderTop: { xs: '1px solid rgba(0,0,0,0.06)', sm: 'none' },
                  width: '100%',
                  mx: { xs: 0, sm: 'inherit' },
                }}
              >
                <Box sx={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  mb: { xs: 3, sm: 4 },
                  pb: { xs: 2, sm: 2.5 },
                  borderBottom: '2px solid rgba(99, 102, 241, 0.1)',
                }}>
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                    <Box
                      sx={{
                        width: { xs: 44, sm: 48 },
                        height: { xs: 44, sm: 48 },
                        borderRadius: 2.5,
                        background: gradients.primary,
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        boxShadow: '0 4px 12px rgba(99, 102, 241, 0.25)',
                      }}
                    >
                      <School sx={{ color: 'white', fontSize: { xs: 22, sm: 24 } }} />
                    </Box>
                    <Box>
                      <Typography
                        variant="h5"
                        fontWeight={700}
                        sx={{
                          fontSize: { xs: '1.25rem', sm: '1.5rem' },
                          mb: 0.5,
                          background: gradients.primary,
                          backgroundClip: 'text',
                          WebkitBackgroundClip: 'text',
                          WebkitTextFillColor: 'transparent',
                        }}
                      >
                        {t.profile.learnerProfiles}
                      </Typography>
                      <Typography
                        variant="body2"
                        color="text.secondary"
                        sx={{ fontSize: { xs: '0.8rem', sm: '0.875rem' } }}
                      >
                        {t.profile.learnerProfilesDescription}
                      </Typography>
                    </Box>
                  </Box>
                  <Typography
                    variant="caption"
                    sx={{
                      color: 'text.secondary',
                      fontSize: { xs: '0.75rem', sm: '0.8125rem' },
                      fontWeight: 600,
                      px: 1.5,
                      py: 0.5,
                      borderRadius: 2,
                      bgcolor: 'rgba(99, 102, 241, 0.08)',
                      display: { xs: 'none', sm: 'block' },
                    }}
                  >
                    {learners.length} {learners.length === 1 ? t.profile.profile : t.profile.profiles}
                  </Typography>
                </Box>

                {isLoadingLearners ? (
                  <Box sx={{ textAlign: 'center', py: 4 }}>
                    <Typography variant="body2" color="text.secondary">
                      {t.profile.loadingLearners}
                    </Typography>
                  </Box>
                ) : (
                  <Grid
                    container
                    spacing={{ xs: 1.5, sm: 2.5, md: 3 }}
                    sx={{
                      width: '100%',
                      margin: 0,
                      // Ensure full width at 412px
                      '@media (min-width: 412px) and (max-width: 599px)': {
                        width: '100%',
                        maxWidth: '100%',
                      },
                    }}
                  >
                    {learners.map((learner) => {
                      // Get focus area labels
                      const FOCUS_AREAS_CONFIG = {
                        'social-skills': { label: t.profile.skills.socialSkills, icon: '🤝', color: '#6366F1' },
                        'emotion-intelligence': { label: t.profile.skills.emotionIntelligence, icon: '❤️', color: '#EC4899' },
                        'thought-expression': { label: t.profile.skills.thoughtExpression, icon: '🗣️', color: '#059669' },
                        'cognitive-growth': { label: t.profile.skills.cognitiveGrowth, icon: '🧠', color: '#F59E0B' },
                        'life-skills': { label: t.profile.skills.lifeSkills, icon: '🌟', color: '#8B5CF6' },
                      };

                      const focusAreasList = learner.focus_areas?.map(id => FOCUS_AREAS_CONFIG[id])
                        .filter(Boolean) || [];
                      const primaryFocusArea = focusAreasList[0];

                      return (
                        <Grid
                          item
                          xs={12}
                          sm={6}
                          md={4}
                          lg={3}
                          key={learner.id}
                          sx={{
                            display: 'flex',
                            // Below 412px: 1 column (full width)
                            width: '100%',
                            maxWidth: '100%',
                            flexBasis: '100%',
                            // At 412px and above (but below 600px): 2 columns
                            // Spacing is 1.5 (12px), so each item: calc(50% - 6px)
                            '@media (min-width: 412px) and (max-width: 599px)': {
                              flexBasis: 'calc(50% - 6px)',
                              maxWidth: 'calc(50% - 6px)',
                              width: 'calc(50% - 6px)',
                              flexGrow: 0,
                              flexShrink: 0,
                            },
                            // At sm breakpoint (600px) and above, use default Grid behavior
                            '@media (min-width: 600px)': {
                              width: 'auto',
                              maxWidth: 'none',
                              flexBasis: 'auto',
                              flexGrow: 1,
                              flexShrink: 1,
                            },
                          }}
                        >
                          <Paper
                            elevation={2}
                            sx={{
                              p: { xs: 2, sm: 2.5, md: 3 },
                              borderRadius: { xs: 2, sm: 3 },
                              border: '1px solid rgba(0, 0, 0, 0.08)',
                              background: '#FFFFFF',
                              transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
                              position: 'relative',
                              width: '100%',
                              height: '100%',
                              display: 'flex',
                              flexDirection: 'column',
                              '&:hover': {
                                boxShadow: '0 12px 32px rgba(0, 0, 0, 0.12)',
                                transform: 'translateY(-4px)',
                                borderColor: 'primary.main',
                              },
                            }}
                          >
                            {/* Top Delete Icon */}
                            <Box sx={{
                              position: 'absolute',
                              top: { xs: 8, sm: 12 },
                              right: { xs: 8, sm: 12 },
                              zIndex: 1,
                            }}>
                              <IconButton
                                size="small"
                                onClick={() => handleDeleteClick(learner)}
                                sx={{
                                  width: { xs: 28, sm: 32 },
                                  height: { xs: 28, sm: 32 },
                                  bgcolor: 'rgba(0, 0, 0, 0.04)',
                                  '&:hover': {
                                    bgcolor: 'rgba(239, 68, 68, 0.1)',
                                  },
                                }}
                              >
                                <Delete
                                  sx={{ fontSize: { xs: 16, sm: 18 }, color: 'text.secondary' }}
                                />
                              </IconButton>
                            </Box>

                            {/* Avatar - Centered at top */}
                            <Box sx={{
                              display: 'flex',
                              justifyContent: 'center',
                              mb: { xs: 2, sm: 2.5 },
                              mt: { xs: 0.5, sm: 1 },
                            }}>
                              <LearnerAvatar
                                learner={learner}
                                size={80}
                                sx={{
                                  width: { xs: 70, sm: 80 },
                                  height: { xs: 70, sm: 80 },
                                  fontSize: { xs: '1.75rem', sm: '2rem' },
                                  border: '3px solid',
                                  borderColor: 'rgba(99, 102, 241, 0.15)',
                                  boxShadow: '0 4px 16px rgba(0, 0, 0, 0.1)',
                                }}
                              />
                            </Box>

                            {/* Name */}
                            <Typography
                              variant="h6"
                              fontWeight={700}
                              align="center"
                              sx={{
                                fontSize: { xs: '1.125rem', sm: '1.25rem' },
                                mb: 1,
                                color: 'text.primary',
                                lineHeight: 1.3,
                                minHeight: { xs: '2.5rem', sm: '3rem' },
                                display: 'flex',
                                alignItems: 'center',
                                justifyContent: 'center',
                              }}
                            >
                              {learner.name}
                            </Typography>

                            {/* Focus Area Type */}
                            {primaryFocusArea && (
                              <Typography
                                variant="body2"
                                color="text.secondary"
                                align="center"
                                sx={{
                                  mb: 2,
                                  fontSize: { xs: '0.8125rem', sm: '0.875rem' },
                                  fontWeight: 500,
                                }}
                              >
                                {primaryFocusArea.label}
                              </Typography>
                            )}

                            {/* Age and Focus Areas Info */}
                            <Box sx={{
                              display: 'flex',
                              justifyContent: 'space-between',
                              alignItems: 'center',
                              mb: { xs: 2, sm: 2.5 },
                              px: { xs: 0.5, sm: 1 },
                              flex: 1,
                            }}>
                              <Box sx={{ textAlign: 'left', flex: 1 }}>
                                <Typography
                                  variant="caption"
                                  color="text.secondary"
                                  sx={{
                                    display: 'block',
                                    fontSize: { xs: '0.7rem', sm: '0.75rem' },
                                    fontWeight: 600,
                                    textTransform: 'uppercase',
                                    letterSpacing: '0.5px',
                                    mb: 0.5,
                                  }}
                                >
                                  {t.profile.age}
                                </Typography>
                                <Typography
                                  variant="body2"
                                  fontWeight={600}
                                  sx={{ fontSize: { xs: '0.8125rem', sm: '0.875rem', md: '0.9375rem' } }}
                                >
                                  {learner.age || 'N/A'} {t.profile.years}
                                </Typography>
                              </Box>
                              <Box sx={{ textAlign: 'right', flex: 1 }}>
                                <Typography
                                  variant="caption"
                                  color="text.secondary"
                                  sx={{
                                    display: 'block',
                                    fontSize: { xs: '0.7rem', sm: '0.75rem' },
                                    fontWeight: 600,
                                    textTransform: 'uppercase',
                                    letterSpacing: '0.5px',
                                    mb: 0.5,
                                  }}
                                >
                                  {t.profile.focusAreas}
                                </Typography>
                                <Typography
                                  variant="body2"
                                  fontWeight={600}
                                  sx={{ fontSize: { xs: '0.8125rem', sm: '0.875rem', md: '0.9375rem' } }}
                                >
                                  {focusAreasList.length}
                                </Typography>
                              </Box>
                            </Box>

                            {/* Action Button */}
                            <Button
                              variant="contained"
                              fullWidth
                              startIcon={<Edit />}
                              onClick={() => navigate(`/profile/edit-learner/${learner.id}`)}
                              sx={{
                                py: { xs: 1.25, sm: 1.5 },
                                fontWeight: 600,
                                fontSize: { xs: '0.8125rem', sm: '0.875rem', md: '0.9375rem' },
                                background: gradients.primary,
                                borderRadius: { xs: 1.5, sm: 2 },
                                textTransform: 'none',
                                boxShadow: '0 4px 12px rgba(99, 102, 241, 0.25)',
                                mt: 'auto',
                                '&:hover': {
                                  background: 'linear-gradient(135deg, #4F46E5 0%, #7C3AED 100%)',
                                  boxShadow: '0 6px 16px rgba(99, 102, 241, 0.35)',
                                  transform: 'translateY(-1px)',
                                },
                                transition: 'all 0.2s ease',
                              }}
                            >
                              {t.profile.viewDetails}
                            </Button>
                          </Paper>
                        </Grid>
                      );
                    })}
                  </Grid>
                )}

                {learners.length === 0 && !isLoadingLearners && (
                  <Box sx={{
                    textAlign: 'center',
                    py: { xs: 4, sm: 6 },
                    px: 2,
                  }}>
                    <Box
                      sx={{
                        width: 80,
                        height: 80,
                        borderRadius: '50%',
                        background: 'linear-gradient(135deg, rgba(99, 102, 241, 0.1) 0%, rgba(139, 92, 246, 0.1) 100%)',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        mx: 'auto',
                        mb: 2,
                      }}
                    >
                      <Person sx={{ fontSize: 40, color: 'primary.main' }} />
                    </Box>
                    <Typography
                      variant="h6"
                      fontWeight={600}
                      sx={{
                        mb: 1,
                        fontSize: { xs: '1rem', sm: '1.125rem' },
                      }}
                    >
                      {t.profile.noLearnerProfiles}
                    </Typography>
                    <Typography
                      variant="body2"
                      color="text.secondary"
                      sx={{
                        fontSize: { xs: '0.875rem', sm: '0.9375rem' },
                        maxWidth: 400,
                        mx: 'auto',
                        mb: 3,
                      }}
                    >
                      {t.profile.noLearnerProfilesDescription}
                    </Typography>
                    <Button
                      variant="contained"
                      startIcon={<Add />}
                      onClick={() => navigate('/create-profile')}
                      sx={{
                        background: gradients.primary,
                        fontWeight: 600,
                        px: 3,
                        py: 1.25,
                        fontSize: { xs: '0.875rem', sm: '0.9375rem' },
                        '&:hover': {
                          background: 'linear-gradient(135deg, #4F46E5 0%, #7C3AED 100%)',
                          transform: 'translateY(-2px)',
                          boxShadow: '0 8px 16px rgba(99, 102, 241, 0.3)',
                        },
                        transition: 'all 0.2s ease',
                      }}
                    >
                      {t.profile.createNewProfile}
                    </Button>
                  </Box>
                )}
              </Paper>
            </Grid>
          )}
        </Grid>

        {/* PIN Dialog */}
        <Dialog
          open={pinDialogOpen}
          onClose={handleClosePinDialog}
          maxWidth="sm"
          fullWidth
          PaperProps={{
            sx: {
              m: { xs: 1, sm: 2 },
              borderRadius: { xs: 2, sm: 3 },
            }
          }}
        >
          <DialogTitle sx={{ pb: { xs: 1.5, sm: 2 }, px: { xs: 2, sm: 3 }, pt: { xs: 2.5, sm: 3 } }}>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: { xs: 1, sm: 1.5 }, flexWrap: { xs: 'wrap', sm: 'nowrap' } }}>
              <Box
                sx={{
                  width: { xs: 36, sm: 40 },
                  height: { xs: 36, sm: 40 },
                  borderRadius: 2,
                  background: gradients.primary,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  flexShrink: 0,
                }}
              >
                <Lock sx={{ color: 'white', fontSize: { xs: 20, sm: 22 } }} />
              </Box>
              <Typography
                variant="h6"
                fontWeight={600}
                sx={{
                  fontSize: { xs: '1rem', sm: '1.125rem', md: '1.25rem' },
                  lineHeight: 1.3,
                }}
              >
                {currentPin ? (isMobile ? t.profile.changePin : t.profile.changeParentDashboardPin) : (isMobile ? t.profile.setPin : t.profile.setParentDashboardPin)}
              </Typography>
            </Box>
          </DialogTitle>
          <DialogContent sx={{ px: { xs: 2, sm: 3 }, pb: { xs: 2, sm: 3 } }}>
            {pinSuccess && (
              <Alert severity="success" sx={{ mb: 2, fontSize: { xs: '0.875rem', sm: '1rem' } }}>
                {t.profile.pinUpdatedSuccessfully}
              </Alert>
            )}
            {pinError && (
              <Alert severity="error" sx={{ mb: 2, fontSize: { xs: '0.875rem', sm: '1rem' } }}>
                {pinError}
              </Alert>
            )}

            <Box sx={{ mb: { xs: 2.5, sm: 3 } }}>
              <Typography
                variant="caption"
                sx={{
                  display: 'block',
                  mb: 1,
                  fontWeight: 600,
                  color: 'text.secondary',
                  fontSize: { xs: '0.75rem', sm: '0.875rem' },
                  textTransform: 'uppercase',
                  letterSpacing: '0.5px',
                }}
              >
                {t.profile.newPin}
              </Typography>
              <TextField
                fullWidth
                type={showNewPin ? 'text' : 'password'}
                value={newPin}
                onChange={(e) => {
                  const value = e.target.value.replace(/\D/g, '').slice(0, 4);
                  setNewPin(value);
                  setPinError('');
                }}
                placeholder={t.profile.enter4DigitPin}
                size={isMobile ? 'small' : 'medium'}
                sx={{
                  '& .MuiOutlinedInput-root': {
                    fontSize: { xs: '1rem', sm: '1.125rem' },
                  },
                }}
                InputProps={{
                  startAdornment: <Lock sx={{ mr: 1.5, color: 'text.secondary', fontSize: { xs: 18, sm: 20 } }} />,
                  endAdornment: (
                    <IconButton
                      onClick={() => setShowNewPin(!showNewPin)}
                      edge="end"
                      size="small"
                      sx={{ mr: 0.5 }}
                    >
                      {showNewPin ? <VisibilityOff sx={{ fontSize: { xs: 18, sm: 20 } }} /> : <Visibility sx={{ fontSize: { xs: 18, sm: 20 } }} />}
                    </IconButton>
                  ),
                }}
                helperText={t.profile.enter4DigitPinHelper}
                FormHelperTextProps={{
                  sx: { fontSize: { xs: '0.75rem', sm: '0.875rem' }, mx: 0, mt: 1 }
                }}
              />
            </Box>

            <Box>
              <Typography
                variant="caption"
                sx={{
                  display: 'block',
                  mb: 1,
                  fontWeight: 600,
                  color: 'text.secondary',
                  fontSize: { xs: '0.75rem', sm: '0.875rem' },
                  textTransform: 'uppercase',
                  letterSpacing: '0.5px',
                }}
              >
                {t.profile.confirmPin}
              </Typography>
              <TextField
                fullWidth
                type={showConfirmPin ? 'text' : 'password'}
                value={confirmPin}
                onChange={(e) => {
                  const value = e.target.value.replace(/\D/g, '').slice(0, 4);
                  setConfirmPin(value);
                  setPinError('');
                }}
                placeholder={t.profile.reEnter4DigitPin}
                size={isMobile ? 'small' : 'medium'}
                sx={{
                  '& .MuiOutlinedInput-root': {
                    fontSize: { xs: '1rem', sm: '1.125rem' },
                  },
                }}
                InputProps={{
                  startAdornment: <Lock sx={{ mr: 1.5, color: 'text.secondary', fontSize: { xs: 18, sm: 20 } }} />,
                  endAdornment: (
                    <IconButton
                      onClick={() => setShowConfirmPin(!showConfirmPin)}
                      edge="end"
                      size="small"
                      sx={{ mr: 0.5 }}
                    >
                      {showConfirmPin ? <VisibilityOff sx={{ fontSize: { xs: 18, sm: 20 } }} /> : <Visibility sx={{ fontSize: { xs: 18, sm: 20 } }} />}
                    </IconButton>
                  ),
                }}
                helperText={t.profile.reEnterPinHelper}
                FormHelperTextProps={{
                  sx: { fontSize: { xs: '0.75rem', sm: '0.875rem' }, mx: 0, mt: 1 }
                }}
              />
            </Box>
          </DialogContent>
          <DialogActions
            sx={{
              px: { xs: 2, sm: 3 },
              pb: { xs: 2.5, sm: 3 },
              pt: { xs: 1, sm: 2 },
              flexDirection: { xs: 'column-reverse', sm: 'row' },
              gap: { xs: 1.5, sm: 1 },
            }}
          >
            <Button
              onClick={handleClosePinDialog}
              disabled={isSaving}
              fullWidth={isMobile}
              sx={{
                fontSize: { xs: '0.875rem', sm: '1rem' },
                py: { xs: 1.25, sm: 1 },
                order: { xs: 2, sm: 1 },
              }}
            >
              {t.buttons.cancel}
            </Button>
            <Button
              onClick={handleSavePin}
              variant="contained"
              disabled={newPin.length !== 4 || confirmPin.length !== 4 || isSaving}
              fullWidth={isMobile}
              sx={{
                background: gradients.primary,
                fontWeight: 600,
                fontSize: { xs: '0.875rem', sm: '1rem' },
                py: { xs: 1.25, sm: 1 },
                order: { xs: 1, sm: 2 },
                '&:hover': {
                  background: 'linear-gradient(135deg, #4F46E5 0%, #7C3AED 100%)',
                },
                '&:disabled': {
                  background: 'rgba(0, 0, 0, 0.12)',
                },
              }}
            >
              {isSaving ? t.profile.saving : t.profile.savePin}
            </Button>
          </DialogActions>
        </Dialog>

        {/* Delete Confirmation Dialog */}
        <Dialog
          open={deleteConfirmDialogOpen}
          onClose={handleDeleteCancel}
          maxWidth="sm"
          fullWidth
          PaperProps={{
            sx: {
              m: { xs: 1, sm: 2 },
              borderRadius: { xs: 2, sm: 3 },
            }
          }}
        >
          <DialogTitle sx={{ pb: { xs: 1.5, sm: 2 }, px: { xs: 2, sm: 3 }, pt: { xs: 2.5, sm: 3 } }}>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: { xs: 1, sm: 1.5 } }}>
              <Box
                sx={{
                  width: { xs: 36, sm: 40 },
                  height: { xs: 36, sm: 40 },
                  borderRadius: 2,
                  background: 'linear-gradient(135deg, #EF4444 0%, #DC2626 100%)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  flexShrink: 0,
                }}
              >
                <Warning sx={{ color: 'white', fontSize: { xs: 20, sm: 22 } }} />
              </Box>
              <Typography
                variant="h6"
                fontWeight={600}
                sx={{
                  fontSize: { xs: '1rem', sm: '1.125rem', md: '1.25rem' },
                  lineHeight: 1.3,
                }}
              >
                {t.profile.deleteLearnerProfile}
              </Typography>
            </Box>
          </DialogTitle>
          <DialogContent sx={{ px: { xs: 2, sm: 3 }, pb: { xs: 2, sm: 3 } }}>
            <Alert severity="warning" sx={{ mb: 2, fontSize: { xs: '0.875rem', sm: '1rem' } }}>
              {t.profile.deleteWarning}
            </Alert>
            <Typography variant="body1" sx={{ fontSize: { xs: '0.875rem', sm: '1rem' } }}>
              {t.profile.deleteConfirmation.replace('{name}', learnerToDelete?.name || '')}
            </Typography>
          </DialogContent>
          <DialogActions
            sx={{
              px: { xs: 2, sm: 3 },
              pb: { xs: 2.5, sm: 3 },
              pt: { xs: 1, sm: 2 },
              flexDirection: { xs: 'column-reverse', sm: 'row' },
              gap: { xs: 1.5, sm: 1 },
            }}
          >
            <Button
              onClick={handleDeleteCancel}
              fullWidth={isMobile}
              sx={{
                fontSize: { xs: '0.875rem', sm: '1rem' },
                py: { xs: 1.25, sm: 1 },
                order: { xs: 2, sm: 1 },
              }}
            >
              {t.buttons.cancel}
            </Button>
            <Button
              onClick={handleDeleteConfirm}
              variant="contained"
              color="error"
              fullWidth={isMobile}
              sx={{
                fontWeight: 600,
                fontSize: { xs: '0.875rem', sm: '1rem' },
                py: { xs: 1.25, sm: 1 },
                order: { xs: 1, sm: 2 },
                '&:hover': {
                  bgcolor: 'error.dark',
                },
              }}
            >
              {t.profile.yesDelete}
            </Button>
          </DialogActions>
        </Dialog>

        {/* Delete PIN Verification Dialog */}
        <Dialog
          open={deletePinDialogOpen}
          onClose={handleCloseDeletePinDialog}
          maxWidth="sm"
          fullWidth
          PaperProps={{
            sx: {
              m: { xs: 1, sm: 2 },
              borderRadius: { xs: 2, sm: 3 },
            }
          }}
        >
          <DialogTitle sx={{ pb: { xs: 1.5, sm: 2 }, px: { xs: 2, sm: 3 }, pt: { xs: 2.5, sm: 3 } }}>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: { xs: 1, sm: 1.5 } }}>
              <Box
                sx={{
                  width: { xs: 36, sm: 40 },
                  height: { xs: 36, sm: 40 },
                  borderRadius: 2,
                  background: gradients.primary,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  flexShrink: 0,
                }}
              >
                <Lock sx={{ color: 'white', fontSize: { xs: 20, sm: 22 } }} />
              </Box>
              <Typography
                variant="h6"
                fontWeight={600}
                sx={{
                  fontSize: { xs: '1rem', sm: '1.125rem', md: '1.25rem' },
                  lineHeight: 1.3,
                }}
              >
                {t.profile.verifyPinToDelete}
              </Typography>
            </Box>
          </DialogTitle>
          <DialogContent sx={{ px: { xs: 2, sm: 3 }, pb: { xs: 2, sm: 3 } }}>
            {deletePinError && (
              <Alert severity="error" sx={{ mb: 2, fontSize: { xs: '0.875rem', sm: '1rem' } }}>
                {deletePinError}
              </Alert>
            )}
            <Typography variant="body2" color="text.secondary" sx={{ mb: 2, fontSize: { xs: '0.875rem', sm: '1rem' } }}>
              {t.profile.enterPinToConfirmDeletion.replace('{name}', learnerToDelete?.name || '')}
            </Typography>
            <TextField
              fullWidth
              type={showDeletePin ? 'text' : 'password'}
              value={deletePin}
              onChange={handleDeletePinChange}
              onKeyPress={(e) => {
                if (e.key === 'Enter' && deletePin.length === 4) {
                  handleDeletePinSubmit();
                }
              }}
              placeholder={t.profile.enter4DigitPin}
              size={isMobile ? 'small' : 'medium'}
              error={!!deletePinError}
              sx={{
                '& .MuiOutlinedInput-root': {
                  fontSize: { xs: '1rem', sm: '1.125rem' },
                },
              }}
              InputProps={{
                startAdornment: <Lock sx={{ mr: 1.5, color: 'text.secondary', fontSize: { xs: 18, sm: 20 } }} />,
                endAdornment: (
                  <IconButton
                    onClick={() => setShowDeletePin(!showDeletePin)}
                    edge="end"
                    size="small"
                    sx={{ mr: 0.5 }}
                  >
                    {showDeletePin ? <VisibilityOff sx={{ fontSize: { xs: 18, sm: 20 } }} /> : <Visibility sx={{ fontSize: { xs: 18, sm: 20 } }} />}
                  </IconButton>
                ),
              }}
              helperText={t.profile.enterPinToConfirmDeletion.replace('{name}', '')}
              FormHelperTextProps={{
                sx: { fontSize: { xs: '0.75rem', sm: '0.875rem' }, mx: 0, mt: 1 }
              }}
            />
          </DialogContent>
          <DialogActions
            sx={{
              px: { xs: 2, sm: 3 },
              pb: { xs: 2.5, sm: 3 },
              pt: { xs: 1, sm: 2 },
              flexDirection: { xs: 'column-reverse', sm: 'row' },
              gap: { xs: 1.5, sm: 1 },
            }}
          >
            <Button
              onClick={handleCloseDeletePinDialog}
              disabled={isDeleting}
              fullWidth={isMobile}
              sx={{
                fontSize: { xs: '0.875rem', sm: '1rem' },
                py: { xs: 1.25, sm: 1 },
                order: { xs: 2, sm: 1 },
              }}
            >
              {t.buttons.cancel}
            </Button>
            <Button
              onClick={handleDeletePinSubmit}
              variant="contained"
              color="error"
              disabled={deletePin.length !== 4 || isDeleting}
              fullWidth={isMobile}
              sx={{
                fontWeight: 600,
                fontSize: { xs: '0.875rem', sm: '1rem' },
                py: { xs: 1.25, sm: 1 },
                order: { xs: 1, sm: 2 },
                '&:hover': {
                  bgcolor: 'error.dark',
                },
                '&:disabled': {
                  background: 'rgba(0, 0, 0, 0.12)',
                },
              }}
            >
              {isDeleting ? t.buttons.delete + '...' : t.buttons.delete + ' ' + t.profile.profile}
            </Button>
          </DialogActions>
        </Dialog>
      </Container>
    </Box>
  );
};

export default Profile;

