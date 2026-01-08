/**
 * Profile Selection Page
 * Choose between learner profiles or parent mode
 */

import React, { useState, useEffect } from 'react';
import {
  Container,
  Typography,
  Card,
  CardContent,
  Grid,
  Box,
  Button,
  Avatar,
  TextField,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  CircularProgress,
  Tooltip,
  Popover,
  Alert,
} from '@mui/material';
import { Add, Person, SupervisorAccount } from '@mui/icons-material';
import { useAuth } from '../../contexts/AuthContext';
import { useNavigate } from 'react-router-dom';
import { useLanguage } from '../../i18n/LanguageContext';
import { supabase } from '../../services/supabase';
import { verifyParentPin } from '../../utils/parentPin';
import { gradients } from '../../theme';
import LearnerAvatar from '../../components/common/LearnerAvatar';

// Skill Icon Component with Tooltip
const SkillIcon = ({ skill, sizeMultiplier = 1 }) => {
  const [anchorEl, setAnchorEl] = useState(null);

  const handleClick = (event) => {
    event.stopPropagation(); // Prevent card click
    setAnchorEl(event.currentTarget);
  };

  const handleClose = () => {
    setAnchorEl(null);
  };

  const open = Boolean(anchorEl);

  return (
    <>
      <Tooltip title={skill.label} arrow placement="top">
        <Box
          onClick={(e) => {
            e.stopPropagation(); // Prevent card click
            handleClick(e);
          }}
          sx={{
            width: { xs: 32 * sizeMultiplier, sm: 34 * sizeMultiplier, md: 36 * sizeMultiplier },
            height: { xs: 32 * sizeMultiplier, sm: 34 * sizeMultiplier, md: 36 * sizeMultiplier },
            borderRadius: '50%',
            bgcolor: skill.color,
            color: 'white',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontWeight: 700,
            fontSize: skill.letter === 'Li'
              ? { xs: `${0.65 * sizeMultiplier}rem`, sm: `${0.7 * sizeMultiplier}rem`, md: `${0.75 * sizeMultiplier}rem` }
              : { xs: `${0.85 * sizeMultiplier}rem`, sm: `${0.9 * sizeMultiplier}rem`, md: `${0.95 * sizeMultiplier}rem` },
            boxShadow: `0 2px 8px ${skill.color}40`,
            border: '2px solid white',
            transition: 'transform 0.2s ease',
            flexShrink: 0,
            cursor: 'pointer',
            position: 'relative',
            zIndex: 2,
            '&:hover': {
              transform: 'scale(1.1)',
            },
          }}
        >
          {skill.letter}
        </Box>
      </Tooltip>
      <Popover
        open={open}
        anchorEl={anchorEl}
        onClose={handleClose}
        anchorOrigin={{
          vertical: 'top',
          horizontal: 'center',
        }}
        transformOrigin={{
          vertical: 'bottom',
          horizontal: 'center',
        }}
        onClick={(e) => e.stopPropagation()}
      >
        <Box sx={{ p: 1.5, textAlign: 'center', minWidth: 120 }}>
          <Typography variant="body2" fontWeight="bold" sx={{ fontSize: '0.875rem' }}>
            {skill.label}
          </Typography>
        </Box>
      </Popover>
    </>
  );
};

const ProfileSelect = () => {
  const { user, selectProfile, profileType, switchProfile } = useAuth();
  const navigate = useNavigate();
  const { t } = useLanguage();

  // Skills mapping with letters and colors (same as CreateProfile)
  // Keys are generated from labels (lowercase, spaces to hyphens)
  const SKILLS_CONFIG = {
    'social-skills': {
      letter: 'S',
      label: t.profileSelect.skills.socialSkills,
      color: '#6366F1', // Indigo
      bgColor: '#EEF2FF',
    },
    'emotion-intelligence': {
      letter: 'E',
      label: t.profileSelect.skills.emotionIntelligence,
      color: '#EC4899', // Pink
      bgColor: '#FCE7F3',
    },
    'thought-expression': {
      letter: 'T',
      label: t.profileSelect.skills.thoughtExpression,
      color: '#059669', // Dark Green
      bgColor: '#A7F3D0',
    },
    'cognitive-growth': {
      letter: 'C',
      label: t.profileSelect.skills.cognitiveGrowth,
      color: '#F59E0B', // Amber
      bgColor: '#FEF3C7',
    },
    'life-skills': {
      letter: 'Li',
      label: t.profileSelect.skills.lifeSkills,
      color: '#8B5CF6', // Purple
      bgColor: '#EDE9FE',
    },
  };
  const [learners, setLearners] = useState([]);
  const [pinDialog, setPinDialog] = useState(false);
  const [selectedProfile, setSelectedProfile] = useState(null);
  const [pin, setPin] = useState('');
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    loadLearners();
  }, [user]);

  const loadLearners = async () => {
    if (!user) {
      setIsLoading(false);
      return;
    }

    setIsLoading(true);
    try {
      // Get the users.id from public.users table (not auth.users.id)
      // user.id is from Supabase auth (auth.users.id), we need public.users.id
      const { data: userRecord, error: userError } = await supabase
        .from('users')
        .select('id')
        .eq('auth_id', user.id)
        .single();

      if (userError) {
        console.error('Failed to get user record:', userError);
        setError(t.profileSelect.loadError);
        setIsLoading(false);
        return;
      }

      if (!userRecord) {
        setError(t.profileSelect.userNotFound);
        setIsLoading(false);
        return;
      }

      // Query 'learners' table using the correct users.id
      const { data, error } = await supabase
        .from('learners')
        .select('*')
        .eq('user_id', userRecord.id)
        .order('created_at', { ascending: false });

      if (error) throw error;
      setLearners(data || []);
    } catch (err) {
      console.error('Failed to load learners:', err);
      setError(t.profileSelect.loadError);
    } finally {
      setIsLoading(false);
    }
  };

  const handleSelectLearner = async (learner) => {
    try {
      // Require PIN to switch learner (parent protection)
      setSelectedProfile({ type: 'learner', learner });
      setPinDialog(true);
    } catch (err) {
      setError(err.message);
    }
  };

  const handleExitParentMode = () => {
    // Exit parent mode and redirect to mode selection
    navigate('/mode-selection');
  };

  const handlePinSubmit = async () => {
    setError(''); // Clear previous errors

    // Validate PIN format
    if (!pin || pin.length !== 4 || !/^\d{4}$/.test(pin)) {
      setError(t.profileSelect.pinError);
      return;
    }

    try {
      // Verify PIN
      const isValidPin = await verifyParentPin(user, pin);
      if (!isValidPin) {
        setError(t.profileSelect.pinIncorrect);
        setPin('');
        return;
      }

      if (selectedProfile.type === 'learner' && selectedProfile.learner) {
        // Switch to learner after PIN verification
        await selectProfile(selectedProfile.learner.id, 'learner');
        navigate('/learner');
      }

      setPinDialog(false);
      setPin('');
      setError('');
    } catch (err) {
      setError(err.message || t.profileSelect.pinRequired);
      setPin('');
    }
  };

  const handlePinChange = (e) => {
    // Only allow digits and limit to 4 characters
    const value = e.target.value.replace(/\D/g, '').slice(0, 4);
    setPin(value);
    setError(''); // Clear error when user starts typing
  };

  const handlePinKeyPress = (e) => {
    if (e.key === 'Enter' && pin.length === 4) {
      handlePinSubmit();
    }
  };

  const handleAddLearner = () => {
    navigate('/create-profile');
  };

  const getAvatarColor = (name) => {
    const colors = ['#6366F1', '#EC4899', '#10B981', '#F59E0B', '#8B5CF6'];
    return colors[name.charCodeAt(0) % colors.length];
  };

  return (
    <Box
      sx={{
        height: 'calc(100vh - 64px)',
        backgroundImage: 'url(/assets/sunset.png)',
        backgroundSize: 'cover',
        backgroundPosition: 'center',
        backgroundRepeat: 'no-repeat',
        display: 'flex',
        flexDirection: 'column',
        overflow: 'hidden',
      }}
    >
      <Container
        maxWidth="lg"
        sx={{
          py: { xs: 2, sm: 3 },
          px: { xs: 1, sm: 2, md: 3 },
          width: '100%',
          flex: 1,
          display: 'flex',
          flexDirection: 'column',
          overflow: 'auto',
        }}
      >
        <Box textAlign="center" mb={4} pt={3}>
          <Typography
            variant="h4"
            fontWeight="bold"
            gutterBottom
            sx={{
              fontSize: { xs: '1.75rem', sm: '2rem', md: '2.25rem' },
              color: '#fff',
              mb: 0.5,
            }}
          >
            {t.profileSelect.title}
          </Typography>
          <Typography
            variant="body1"
            sx={{
              fontSize: { xs: '0.9rem', sm: '1rem' },
              color: '#fff',
            }}
          >
            {t.profileSelect.subtitle}
          </Typography>
        </Box>

        {isLoading ? (
          <Box sx={{ display: 'flex', justifyContent: 'center', py: 8 }}>
            <CircularProgress />
          </Box>
        ) : (
          <Grid
            container
            spacing={0}
            sx={{
              justifyContent: {
                xs: 'space-between',  // Mobile: space-between for 4% gap
                sm: 'space-between',  // Tablet: space-between for ~5.5% gap
                md: 'space-between',  // Tablet landscape: space-between for ~6% gap
                lg: 'space-between',  // Laptop: space-between for ~5% gap
                xl: 'space-between'   // Large screen: space-between for ~7% gap
              },
              width: '100%',
              margin: 0,
            }}
          >
            {/* Learner Profiles - Horizontal Row Layout */}
            {learners.length > 0 ? (
              learners.map((learner) => (
                <Grid
                  key={learner.id}
                  sx={{
                    display: 'flex',
                    width: '100%',
                    maxWidth: '100%',
                    flexBasis: '100%',
                    mb: 1,
                  }}
                >
                  <Card
                    onClick={() => handleSelectLearner(learner)}
                    sx={{
                      width: '100%',
                      maxWidth: '100%',
                      transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
                      border: '1px solid',
                      borderColor: 'grey.200',
                      borderRadius: { xs: 2, sm: 3 },
                      display: 'flex',
                      flexDirection: 'row',
                      overflow: 'hidden',
                      boxSizing: 'border-box',
                      cursor: 'pointer',
                      '&:hover': {
                        transform: 'translateY(-4px)',
                        boxShadow: '0 8px 20px rgba(0,0,0,0.12)',
                        borderColor: 'primary.main',
                      },
                    }}
                  >
                    <CardContent
                      sx={{
                        py: { xs: 1.25, sm: 1.5 },
                        px: { xs: 1.5, sm: 2 },
                        width: '100%',
                        display: 'flex',
                        flexDirection: 'row',
                        alignItems: 'center',
                        gap: { xs: 2, sm: 2.5 },
                        overflow: 'hidden',
                        boxSizing: 'border-box',
                        '&:last-child': { pb: { xs: 1.25, sm: 1.5 } },
                      }}
                    >
                      {/* Left side - Avatar */}
                      <Box
                        onClick={(e) => {
                          e.stopPropagation();
                          handleSelectLearner(learner);
                        }}
                        sx={{
                          flexShrink: 0,
                          cursor: 'pointer',
                          transition: 'transform 0.2s ease',
                          '&:hover': {
                            transform: 'scale(1.05)',
                          },
                        }}
                      >
                        <LearnerAvatar
                          learner={learner}
                          size={80}
                          onClick={(e) => {
                            e.stopPropagation();
                            handleSelectLearner(learner);
                          }}
                          sx={{
                            width: { xs: 70, sm: 80 },
                            height: { xs: 70, sm: 80 },
                            fontSize: { xs: '1.75rem', sm: '2rem' },
                          }}
                        />
                      </Box>

                      {/* Right side - Name, Age, Skills */}
                      <Box
                        sx={{
                          flex: 1,
                          display: 'flex',
                          flexDirection: 'column',
                          alignItems: 'center',
                          justifyContent: 'center',
                          minWidth: 0,
                        }}
                      >
                        <Typography
                          variant="h6"
                          fontWeight="bold"
                          onClick={(e) => {
                            e.stopPropagation();
                            handleSelectLearner(learner);
                          }}
                          sx={{
                            fontSize: { xs: '1.1rem', sm: '1.2rem' },
                            mb: 0.25,
                            overflow: 'hidden',
                            textOverflow: 'ellipsis',
                            whiteSpace: 'nowrap',
                            cursor: 'pointer',
                            transition: 'color 0.2s ease',
                            width: '100%',
                            textAlign: 'center',
                            '&:hover': {
                              color: 'primary.main',
                            },
                          }}
                        >
                          {learner.name}
                        </Typography>
                        {learner.age && (
                          <Typography
                            variant="body2"
                            color="text.secondary"
                            sx={{
                              fontSize: { xs: '0.8rem', sm: '0.85rem' },
                              mb: 0.5,
                            }}
                          >
                            {t.profileSelect.age} {learner.age}
                          </Typography>
                        )}

                        {/* Skills circles */}
                        <Box
                          sx={{
                            display: 'flex',
                            flexWrap: 'wrap',
                            gap: { xs: 0.5, sm: 0.75 },
                            alignItems: 'center',
                          }}
                        >
                          {learner.focus_areas && learner.focus_areas.length > 0 ? (
                            learner.focus_areas.map((areaId) => {
                              const skill = SKILLS_CONFIG[areaId];
                              if (!skill) return null;
                              const skillCount = learner.focus_areas.length;
                              const sizeMultiplier = skillCount > 4 ? 0.8 : 0.9;
                              return (
                                <SkillIcon
                                  key={areaId}
                                  skill={skill}
                                  sizeMultiplier={sizeMultiplier}
                                />
                              );
                            })
                          ) : null}
                        </Box>
                      </Box>
                    </CardContent>
                  </Card>
                </Grid>
              ))
            ) : (
              <Grid sx={{ width: '100%', display: 'flex', justifyContent: 'center', alignItems: 'center', minHeight: '50vh' }}>
                <Card
                  sx={{
                    textAlign: 'center',
                    py: { xs: 4, sm: 5, md: 6 },
                    border: '2px dashed',
                    borderColor: 'grey.300',
                    bgcolor: 'rgba(255, 255, 255, 0.95)',
                    borderRadius: { xs: 2, sm: 3 },
                    maxWidth: 400,
                    width: '100%',
                  }}
                >
                  <CardContent>
                    <Person sx={{ fontSize: { xs: 50, sm: 60 }, color: 'grey.400', mb: 2 }} />
                    <Typography
                      variant="h6"
                      gutterBottom
                      sx={{
                        fontSize: { xs: '1.1rem', sm: '1.25rem' },
                        color: '#333',
                      }}
                    >
                      {t.profileSelect.noProfiles}
                    </Typography>
                    <Typography
                      variant="body2"
                      sx={{ mb: 3, color: '#555' }}
                    >
                      {t.profileSelect.noProfilesDescription}
                    </Typography>
                    <Button
                      variant="contained"
                      startIcon={<Add />}
                      onClick={handleAddLearner}
                      size="large"
                      sx={{ bgcolor: '#1a1a2e', '&:hover': { bgcolor: '#2a2a4e' } }}
                    >
                      {t.profileSelect.createFirstProfile}
                    </Button>
                  </CardContent>
                </Card>
              </Grid>
            )}

            {/* Add New Learner - Horizontal Card Matching Profile Structure */}
            {learners.length > 0 && (
              <Box
                sx={{
                  width: '100%',
                  display: 'flex',
                  justifyContent: 'center',
                  mt: 0,
                }}
              >
                <Card
                  onClick={handleAddLearner}
                  sx={{
                    width: '100%',
                    maxWidth: '100%',
                    transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
                    border: '2px dashed',
                    borderColor: 'grey.300',
                    borderRadius: { xs: 2, sm: 3 },
                    display: 'flex',
                    flexDirection: 'row',
                    overflow: 'hidden',
                    boxSizing: 'border-box',
                    cursor: 'pointer',
                    '&:hover': {
                      transform: 'translateY(-4px)',
                      boxShadow: '0 8px 20px rgba(0,0,0,0.12)',
                      borderColor: 'primary.main',
                      bgcolor: 'rgba(255, 255, 255, 0.95)',
                    },
                    bgcolor: 'rgba(255, 255, 255, 0.9)',
                  }}
                >
                  <CardContent
                    sx={{
                      py: { xs: 1.25, sm: 1.5 },
                      px: { xs: 1.5, sm: 2 },
                      width: '100%',
                      display: 'flex',
                      flexDirection: 'row',
                      alignItems: 'center',
                      gap: { xs: 2, sm: 2.5 },
                      overflow: 'hidden',
                      boxSizing: 'border-box',
                      '&:last-child': { pb: { xs: 1.25, sm: 1.5 } },
                    }}
                  >
                    {/* Left side - Avatar Placeholder */}
                    <Box
                      sx={{
                        flexShrink: 0,
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                      }}
                    >
                      <Avatar
                        sx={{
                          width: { xs: 70, sm: 80 },
                          height: { xs: 70, sm: 80 },
                          bgcolor: 'transparent',
                          color: 'grey.400',
                          border: '2px dashed',
                          borderColor: 'grey.300',
                        }}
                      >
                        <Add sx={{ fontSize: { xs: 32, sm: 40 } }} />
                      </Avatar>
                    </Box>

                    {/* Right side - Text */}
                    <Box
                      sx={{
                        flex: 1,
                        display: 'flex',
                        flexDirection: 'column',
                        alignItems: 'center',
                        justifyContent: 'center',
                        minWidth: 0,
                      }}
                    >
                      <Typography
                        variant="h6"
                        fontWeight="bold"
                        color="text.secondary"
                        sx={{
                          fontSize: { xs: '1.1rem', sm: '1.2rem' },
                          mb: 0.25,
                          width: '100%',
                          textAlign: 'center',
                        }}
                      >
                        {t.profileSelect.addChild}
                      </Typography>
                      <Typography
                        variant="body2"
                        color="text.secondary"
                        sx={{
                          fontSize: { xs: '0.8rem', sm: '0.85rem' },
                          textAlign: 'center',
                        }}
                      >
                        {t.profileSelect.addChildDescription}
                      </Typography>
                    </Box>
                  </CardContent>
                </Card>
              </Box>
            )}
          </Grid>
        )}

        {error && (
          <Typography variant="body2" sx={{ mt: 2, textAlign: 'center', color: '#ff6b6b' }}>
            {error}
          </Typography>
        )}

        {/* PIN Dialog */}
        <Dialog
          open={pinDialog}
          onClose={() => {
            setPinDialog(false);
            setPin('');
            setError('');
          }}
          maxWidth="sm"
          fullWidth
        >
          <DialogTitle>
            {t.profileSelect.enterPinForLearner}
          </DialogTitle>
          <DialogContent>
            {error && (
              <Alert severity="error" sx={{ mb: 2 }}>
                {error}
              </Alert>
            )}
            <TextField
              autoFocus
              fullWidth
              type="password"
              label={t.profileSelect.pin}
              placeholder={t.profileSelect.pinPlaceholder}
              value={pin}
              onChange={handlePinChange}
              onKeyPress={handlePinKeyPress}
              error={!!error}
              helperText={error ? '' : t.profileSelect.pinHelper}
              inputProps={{
                maxLength: 4,
                inputMode: 'numeric',
                pattern: '[0-9]*',
              }}
              sx={{ mt: 1 }}
            />
          </DialogContent>
          <DialogActions sx={{ px: 3, pb: 2 }}>
            <Button
              onClick={() => {
                setPinDialog(false);
                setPin('');
                setError('');
              }}
            >
              {t.buttons.cancel}
            </Button>
            <Button
              onClick={handlePinSubmit}
              variant="contained"
              disabled={pin.length !== 4}
              sx={{
                background: gradients.primary,
                fontWeight: 600,
                '&:hover': {
                  background: 'linear-gradient(135deg, #4F46E5 0%, #7C3AED 100%)',
                },
              }}
            >
              {t.profileSelect.continue}
            </Button>
          </DialogActions>
        </Dialog>
      </Container>

      {/* Exit Parent Mode - Fixed at Bottom */}
      <Box sx={{
        px: { xs: 2, sm: 3 },
        pb: { xs: 3, sm: 4 },
        pt: 2,
        width: '100%',
        display: 'flex',
        justifyContent: 'center',
      }}>
        <Button
          variant="contained"
          startIcon={<SupervisorAccount />}
          onClick={handleExitParentMode}
          sx={{
            py: 1.5,
            px: 4,
            maxWidth: 400,
            width: '100%',
            borderRadius: '50px',
            backgroundColor: '#ffb3b3',
            color: '#1a1a2e',
            fontWeight: 600,
            '&:hover': {
              backgroundColor: '#ff9999',
            },
          }}
        >
          {t.profileSelect.exitParentMode}
        </Button>
      </Box>
    </Box>
  );
};

export default ProfileSelect;
