/**
 * Edit Learner Profile Page
 * Edit a child's profile information including name, avatar, age, focus areas, and diagnoses
 */

import React, { useState, useEffect } from 'react';
import {
  Container,
  Typography,
  Card,
  CardContent,
  TextField,
  Button,
  Box,
  Chip,
  Grid,
  Slider,
  Alert,
} from '@mui/material';
import { useAuth } from '../../contexts/AuthContext';
import { useLanguage } from '../../i18n/LanguageContext';
import { useNavigate, useParams } from 'react-router-dom';
import { supabase } from '../../services/supabase';
import AvatarSelector, { DEFAULT_AVATAR, AVATAR_LIST } from '../../components/common/AvatarSelector';
import ArrowBackIcon from '@mui/icons-material/ArrowBack';

const EditLearnerProfile = () => {
  const { user, currentProfile, selectProfile } = useAuth();
  const { t } = useLanguage();
  const navigate = useNavigate();
  const { learnerId } = useParams();

  // Skills mapping with letters and colors
  const SKILLS_CONFIG = {
    'social-skills': {
      id: 'social-skills',
      letter: 'S',
      label: t.editLearnerProfile.skills.socialSkills,
      color: '#6366F1',
      bgColor: '#EEF2FF',
    },
    'emotion-intelligence': {
      id: 'emotion-intelligence',
      letter: 'E',
      label: t.editLearnerProfile.skills.emotionIntelligence,
      color: '#EC4899',
      bgColor: '#FCE7F3',
    },
    'thought-expression': {
      id: 'thought-expression',
      letter: 'T',
      label: t.editLearnerProfile.skills.thoughtExpression,
      color: '#059669',
      bgColor: '#A7F3D0',
    },
    'cognitive-growth': {
      id: 'cognitive-growth',
      letter: 'C',
      label: t.editLearnerProfile.skills.cognitiveGrowth,
      color: '#F59E0B',
      bgColor: '#FEF3C7',
    },
    'life-skills': {
      id: 'life-skills',
      letter: 'Li',
      label: t.editLearnerProfile.skills.lifeSkills,
      color: '#8B5CF6',
      bgColor: '#EDE9FE',
    },
  };

  const focusAreaOptions = Object.values(SKILLS_CONFIG);

  const diagnosisOptions = [
    { id: 'autism', label: t.editLearnerProfile.diagnoses.autism },
    { id: 'adhd', label: t.editLearnerProfile.diagnoses.adhd },
    { id: 'anxiety', label: t.editLearnerProfile.diagnoses.anxiety },
    { id: 'developmental-delay', label: t.editLearnerProfile.diagnoses.developmentalDelay },
    { id: 'sensory-processing', label: t.editLearnerProfile.diagnoses.sensoryProcessing },
    { id: 'learning-disability', label: t.editLearnerProfile.diagnoses.learningDisability },
    { id: 'speech-delay', label: t.editLearnerProfile.diagnoses.speechDelay },
    { id: 'other', label: t.editLearnerProfile.diagnoses.other },
  ];

  const [name, setName] = useState('');
  const [age, setAge] = useState('3');
  const [focusAreas, setFocusAreas] = useState([]);
  const [diagnoses, setDiagnoses] = useState([]);
  const [selectedAvatar, setSelectedAvatar] = useState(DEFAULT_AVATAR);
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);

  // Extract avatar filename from profile_image path
  const extractAvatarFromPath = (profileImage) => {
    if (!profileImage) return DEFAULT_AVATAR;
    if (profileImage.startsWith('/avatars/')) {
      const filename = profileImage.replace('/avatars/', '');
      return AVATAR_LIST.includes(filename) ? filename : DEFAULT_AVATAR;
    }
    return DEFAULT_AVATAR;
  };

  // Load learner data
  useEffect(() => {
    const loadLearnerData = async () => {
      try {
        setIsLoading(true);
        const profileId = learnerId || currentProfile?.id;
        
        if (!profileId) {
          throw new Error(t.editLearnerProfile.learnerProfileNotFound);
        }

        // Get user record ID
        const { data: userRecord } = await supabase
          .from('users')
          .select('id')
          .eq('auth_id', user.id)
          .single();

        if (!userRecord) {
          throw new Error(t.editLearnerProfile.userRecordNotFound);
        }

        // Fetch learner data
        const { data: learnerData, error: fetchError } = await supabase
          .from('learners')
          .select('*')
          .eq('id', profileId)
          .eq('user_id', userRecord.id)
          .single();

        if (fetchError) throw fetchError;
        if (!learnerData) throw new Error(t.editLearnerProfile.learnerProfileNotFound);

        // Populate form with existing data
        setName(learnerData.name || '');
        setAge(learnerData.age?.toString() || '3');
        setFocusAreas(learnerData.focus_areas || []);
        setDiagnoses(learnerData.diagnoses || []);
        
        // Extract avatar from profile_image
        const avatar = extractAvatarFromPath(learnerData.profile_image);
        setSelectedAvatar(avatar);

      } catch (err) {
        console.error('Failed to load learner data:', err);
        setError(err.message || t.editLearnerProfile.failedToLoadProfile);
      } finally {
        setIsLoading(false);
      }
    };

    if (user) {
      loadLearnerData();
    }
  }, [user, learnerId, currentProfile]);

  const handleFocusAreaToggle = (areaId) => {
    setFocusAreas(prev =>
      prev.includes(areaId)
        ? prev.filter(id => id !== areaId)
        : [...prev, areaId]
    );
  };

  const handleDiagnosisToggle = (diagId) => {
    setDiagnoses(prev =>
      prev.includes(diagId)
        ? prev.filter(id => id !== diagId)
        : [...prev, diagId]
    );
  };

  const handleSubmit = async () => {
    if (!name || !age || focusAreas.length === 0) {
      setError(t.editLearnerProfile.fillRequiredFields);
      return;
    }

    setIsSaving(true);
    setError('');
    setSuccess(false);

    try {
      const profileId = learnerId || currentProfile?.id;
      
      if (!profileId) {
        throw new Error(t.editLearnerProfile.learnerProfileIdNotFound);
      }

      // Get user record ID
      const { data: userRecord } = await supabase
        .from('users')
        .select('id')
        .eq('auth_id', user.id)
        .single();

      if (!userRecord) {
        throw new Error(t.editLearnerProfile.userRecordNotFound);
      }

      // Update learner profile
      const updateData = {
        name,
        age: parseInt(age),
        focus_areas: focusAreas,
        diagnoses: diagnoses.length > 0 ? diagnoses : null,
        profile_image: `/avatars/${selectedAvatar}`,
        updated_at: new Date().toISOString(),
      };

      const { data, error: updateError } = await supabase
        .from('learners')
        .update(updateData)
        .eq('id', profileId)
        .eq('user_id', userRecord.id)
        .select()
        .single();

      if (updateError) throw updateError;

      // Update current profile in context if it's the active one
      if (currentProfile?.id === profileId) {
        await selectProfile(profileId, 'learner', null, data);
      }

      setSuccess(true);
      
      // Navigate back after a short delay
      setTimeout(() => {
        navigate('/profile');
      }, 1500);

    } catch (err) {
      console.error('Failed to update profile:', err);
      setError(err.message || t.editLearnerProfile.failedToUpdateProfile);
    } finally {
      setIsSaving(false);
    }
  };

  if (isLoading) {
    return (
      <Container maxWidth="sm" sx={{ py: 4 }}>
        <Box textAlign="center">
          <Typography>{t.editLearnerProfile.loadingProfile}</Typography>
        </Box>
      </Container>
    );
  }

  return (
    <Container maxWidth="sm" sx={{ py: 4, position: 'relative' }}>
      <Button
        startIcon={<ArrowBackIcon />}
        onClick={() => navigate('/profile')}
        sx={{ 
          mb: 2,
          position: { xs: 'relative', sm: 'absolute' },
          left: { sm: 16 },
          top: { sm: 16 },
        }}
      >
        {t.buttons.back}
      </Button>
      <Box textAlign="center" mb={4} sx={{ mt: { xs: 0, sm: 0 } }}>
        <Typography variant="h4" fontWeight="bold" color="primary" gutterBottom>
          {t.editLearnerProfile.title}
        </Typography>
        <Typography variant="body1" color="text.secondary">
          {t.editLearnerProfile.subtitle}
        </Typography>
      </Box>

      <Card>
        <CardContent sx={{ p: 3 }}>
          {success && (
            <Alert severity="success" sx={{ mb: 2 }}>
              {t.editLearnerProfile.profileUpdatedSuccessfully}
            </Alert>
          )}
          {error && (
            <Alert severity="error" sx={{ mb: 2 }}>
              {error}
            </Alert>
          )}

          {/* Name */}
          <TextField
            fullWidth
            label={t.editLearnerProfile.childName}
            value={name}
            onChange={(e) => setName(e.target.value)}
            sx={{ mb: 3 }}
            required
          />

          {/* Avatar Selection */}
          <Box sx={{ mb: 3 }}>
            <AvatarSelector
              selectedAvatar={selectedAvatar}
              onAvatarSelect={setSelectedAvatar}
              defaultAvatar={selectedAvatar}
            />
          </Box>

          {/* Age - Slider */}
          <Box sx={{ mb: 3 }}>
            <Typography variant="subtitle1" fontWeight="bold" gutterBottom>
              {t.editLearnerProfile.ageRequired}
            </Typography>
            <Box sx={{ px: 2, py: 1 }}>
              <Slider
                value={age ? parseInt(age) : 3}
                onChange={(e, newValue) => setAge(newValue.toString())}
                min={3}
                max={15}
                step={1}
                marks={[
                  { value: 3, label: '<3' },
                  { value: 6, label: '6' },
                  { value: 9, label: '9' },
                  { value: 12, label: '12' },
                  { value: 15, label: '>15' },
                ]}
                valueLabelDisplay="auto"
                valueLabelFormat={(value) => {
                  if (value === 3) return t.editLearnerProfile.ageLabel.lessThan3.split(' ')[0];
                  if (value === 15) return t.editLearnerProfile.ageLabel.moreThan15.split(' ')[0];
                  return `${value}`;
                }}
                sx={{
                  '& .MuiSlider-thumb': {
                    width: 24,
                    height: 24,
                    '&:hover': {
                      boxShadow: '0 0 0 8px rgba(99, 102, 241, 0.16)',
                    },
                  },
                  '& .MuiSlider-valueLabel': {
                    backgroundColor: 'primary.main',
                    fontSize: '0.75rem',
                    fontWeight: 600,
                  },
                  '& .MuiSlider-markLabel': {
                    fontSize: '0.75rem',
                    fontWeight: 500,
                  },
                }}
              />
            </Box>
            <Typography 
              variant="body1" 
              color="primary" 
              sx={{ 
                mt: 2, 
                textAlign: 'center',
                fontWeight: 600,
                fontSize: '1rem',
              }}
            >
              {age === '3' 
                ? t.editLearnerProfile.ageLabel.lessThan3 
                : age === '15' 
                ? t.editLearnerProfile.ageLabel.moreThan15 
                : `${age} ${t.editLearnerProfile.ageLabel.yearsOld}`}
            </Typography>
          </Box>

          {/* Focus Areas */}
          <Typography variant="subtitle1" fontWeight="bold" gutterBottom>
            {t.editLearnerProfile.focusAreasRequired}
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
            {t.editLearnerProfile.focusAreasDescription}
          </Typography>

          <Grid container spacing={2} sx={{ mb: 3 }}>
            {focusAreaOptions.map((skill) => {
              const isSelected = focusAreas.includes(skill.id);
              return (
                <Grid item xs={6} key={skill.id}>
                  <Box
                    onClick={() => handleFocusAreaToggle(skill.id)}
                    sx={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: 1.5,
                      p: 2,
                      borderRadius: 2,
                      border: `2px solid ${isSelected ? skill.color : '#E5E7EB'}`,
                      bgcolor: isSelected ? skill.bgColor : 'transparent',
                      cursor: 'pointer',
                      transition: 'all 0.2s ease',
                      '&:hover': {
                        borderColor: skill.color,
                        bgcolor: skill.bgColor,
                        transform: 'translateY(-2px)',
                        boxShadow: `0 4px 12px ${skill.color}20`,
                      },
                    }}
                  >
                    <Box
                      sx={{
                        width: 48,
                        height: 48,
                        borderRadius: '50%',
                        bgcolor: skill.color,
                        color: 'white',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        fontWeight: 700,
                        fontSize: skill.letter === 'Li' ? '0.9rem' : '1.25rem',
                        flexShrink: 0,
                        boxShadow: `0 2px 8px ${skill.color}40`,
                      }}
                    >
                      {skill.letter}
                    </Box>
                    <Typography
                      variant="body2"
                      fontWeight={isSelected ? 600 : 500}
                      sx={{
                        color: isSelected ? skill.color : 'text.primary',
                        flex: 1,
                      }}
                    >
                      {skill.label}
                    </Typography>
                  </Box>
                </Grid>
              );
            })}
          </Grid>

          {/* Diagnosis (Optional, Multi-select) */}
          <Typography variant="subtitle1" fontWeight="bold" gutterBottom>
            {t.editLearnerProfile.diagnosisOptional}
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
            {t.editLearnerProfile.diagnosisDescription}
          </Typography>

          <Grid container spacing={1} sx={{ mb: 3 }}>
            {diagnosisOptions.map((diag) => (
              <Grid item xs={6} key={diag.id}>
                <Chip
                  label={diag.label}
                  onClick={() => handleDiagnosisToggle(diag.id)}
                  color={diagnoses.includes(diag.id) ? 'secondary' : 'default'}
                  variant={diagnoses.includes(diag.id) ? 'filled' : 'outlined'}
                  sx={{
                    width: '100%',
                    height: 40,
                    '& .MuiChip-label': { fontSize: '0.75rem' }
                  }}
                />
              </Grid>
            ))}
          </Grid>

          {/* Submit */}
          <Button
            fullWidth
            variant="contained"
            size="large"
            onClick={handleSubmit}
            disabled={isSaving}
            sx={{ py: 1.5 }}
          >
            {isSaving ? t.editLearnerProfile.saving : t.editLearnerProfile.saveChanges}
          </Button>

          {/* Cancel */}
          <Button
            fullWidth
            variant="text"
            onClick={() => navigate('/profile')}
            sx={{ mt: 1 }}
          >
            {t.buttons.cancel}
          </Button>
        </CardContent>
      </Card>
    </Container>
  );
};

export default EditLearnerProfile;

