/**
 * Create Learner Profile Page
 * Set up a child's profile with their information and focus areas
 */

import React, { useState } from 'react';
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
  IconButton
} from '@mui/material';
import ArrowBackIcon from '@mui/icons-material/ArrowBack';
import PeopleIcon from '@mui/icons-material/People';
import FavoriteIcon from '@mui/icons-material/Favorite';
import ChatBubbleIcon from '@mui/icons-material/ChatBubble';
import PsychologyIcon from '@mui/icons-material/Psychology';
import EmojiObjectsIcon from '@mui/icons-material/EmojiObjects';
import { useAuth } from '../../contexts/AuthContext';
import { useLanguage } from '../../i18n/LanguageContext';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { supabase } from '../../services/supabase';
import AvatarSelector, { DEFAULT_AVATAR } from '../../components/common/AvatarSelector';

const CreateProfile = () => {
  const { user, selectProfile, signup } = useAuth();
  const { t } = useLanguage();
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const isGuest = searchParams.get('guest') === 'true';

  // Skills mapping with letters and colors
  // Keys are generated from labels (lowercase, spaces to hyphens)
  const SKILLS_CONFIG = {
    'social-skills': {
      id: 'social-skills',
      icon: PeopleIcon,
      label: t.createProfile.skills.socialSkills,
      color: '#6366F1', // Indigo
      bgColor: '#EEF2FF',
    },
    'emotion-intelligence': {
      id: 'emotion-intelligence',
      icon: FavoriteIcon,
      label: t.createProfile.skills.emotionIntelligence,
      color: '#EC4899', // Pink
      bgColor: '#FCE7F3',
    },
    'thought-expression': {
      id: 'thought-expression',
      icon: ChatBubbleIcon,
      label: t.createProfile.skills.thoughtExpression,
      color: '#059669', // Dark Green
      bgColor: '#A7F3D0',
    },
    'cognitive-growth': {
      id: 'cognitive-growth',
      icon: PsychologyIcon,
      label: t.createProfile.skills.cognitiveGrowth,
      color: '#F59E0B', // Amber
      bgColor: '#FEF3C7',
    },
    'life-skills': {
      id: 'life-skills',
      icon: EmojiObjectsIcon,
      label: t.createProfile.skills.lifeSkills,
      color: '#8B5CF6', // Purple
      bgColor: '#EDE9FE',
    },
  };

  const focusAreaOptions = Object.values(SKILLS_CONFIG);

  const diagnosisOptions = [
    { id: 'autism', label: t.createProfile.diagnoses.autism },
    { id: 'adhd', label: t.createProfile.diagnoses.adhd },
    { id: 'anxiety', label: t.createProfile.diagnoses.anxiety },
    { id: 'developmental-delay', label: t.createProfile.diagnoses.developmentalDelay },
    { id: 'sensory-processing', label: t.createProfile.diagnoses.sensoryProcessing },
    { id: 'learning-disability', label: t.createProfile.diagnoses.learningDisability },
    { id: 'speech-delay', label: t.createProfile.diagnoses.speechDelay },
    { id: 'other', label: t.createProfile.diagnoses.other },
  ];

  const [name, setName] = useState('');
  const [age, setAge] = useState('3'); // Default to minimum age
  const [focusAreas, setFocusAreas] = useState([]);
  const [diagnoses, setDiagnoses] = useState([]);
  const [selectedAvatar, setSelectedAvatar] = useState(DEFAULT_AVATAR); // Default avatar
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState('');

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
      setError(t.createProfile.fillRequiredFields);
      return;
    }

    setIsLoading(true);
    setError('');

    try {
      // Get the users.id from public.users table (not auth.users.id)
      // The RLS policy requires user_id to match users.id where auth_id = auth.uid()
      let userId = null;

      if (user?.id) {
        // user.id is from Supabase auth (auth.users.id), we need public.users.id
        const { data: userRecord, error: userError } = await supabase
          .from('users')
          .select('id')
          .eq('auth_id', user.id)
          .single();

        if (userError) {
          console.error('Failed to get user record:', userError);
          throw new Error(t.createProfile.userNotFound);
        }

        userId = userRecord.id;
      }

      // If guest mode, create a guest user first
      if (isGuest && !user) {
        const guestUser = await signup({
          email: `guest_${Date.now()}@komal.app`,
          password: crypto.randomUUID(),
          authMethod: 'guest',
          language: 'en'
        });
        // After signup, get the users.id
        const { data: userRecord } = await supabase
          .from('users')
          .select('id')
          .eq('auth_id', guestUser.id)
          .single();
        userId = userRecord?.id;
      }

      if (!userId) {
        throw new Error(t.createProfile.unableToDetermineUserId);
      }

      // Create learner profile in Supabase
      // NOTE: Insert into 'learners' table, not 'profiles' table
      // 'profiles' is for parent/user info, 'learners' is for child profiles
      const learnerData = {
        user_id: userId,
        name,
        age: parseInt(age),
        focus_areas: focusAreas,
        diagnoses: diagnoses.length > 0 ? diagnoses : null,
        profile_image: `/avatars/${selectedAvatar}`, // Save avatar path
        settings: {
          sessionDuration: 15,
          difficulty: 'adaptive',
          rewards: true
        }
      };

      const { data, error: insertError } = await supabase
        .from('learners')
        .insert(learnerData)
        .select()
        .single();

      if (insertError) throw insertError;

      // Use the data returned from insert directly to avoid timing issues
      // This ensures profile_image and all other fields are immediately available
      console.log('[CreateProfile] Created learner profile:', data);

      // Select this profile using the data returned from insert
      // This avoids a second database query which might not have the latest data
      await selectProfile(data.id, 'learner', null, data);
      navigate('/learner');
    } catch (err) {
      console.error('Failed to create profile:', err);
      setError(err.message || t.createProfile.failedToCreate);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <Container maxWidth="sm" sx={{ py: 0, px: 0, minHeight: '100vh' }}>
      {/* Back Button */}
      <IconButton
        onClick={() => navigate('/learner')}
        sx={{
          position: 'absolute',
          top: 8,
          left: 8,
          color: 'white',
          zIndex: 10
        }}
      >
        <ArrowBackIcon />
      </IconButton>

      {/* Header with Sunset Background */}
      <Box
        sx={{
          backgroundImage: 'url(/assets/sunset.png)',
          backgroundSize: 'cover',
          backgroundPosition: 'center',
          py: 3,
          px: 2,
          textAlign: 'center',
          borderBottomLeftRadius: 24,
          borderBottomRightRadius: 24,
        }}
      >
        <Typography variant="h5" fontWeight="bold" color="white" gutterBottom sx={{ textShadow: '0 2px 4px rgba(0,0,0,0.3)' }}>
          {t.createProfile.title}
        </Typography>
        <Typography variant="body2" color="rgba(255,255,255,0.9)" sx={{ textShadow: '0 1px 2px rgba(0,0,0,0.3)' }}>
          {t.createProfile.subtitle}
        </Typography>
      </Box>

      <Card sx={{ boxShadow: 'none', mt: -2, borderTopLeftRadius: 24, borderTopRightRadius: 24, borderBottomLeftRadius: 0, borderBottomRightRadius: 0, position: 'relative', zIndex: 1 }}>
        <CardContent sx={{ px: 3, py: 2 }}>
          {/* Name */}
          <TextField
            fullWidth
            label={t.createProfile.childName}
            value={name}
            onChange={(e) => setName(e.target.value)}
            sx={{ mb: 2 }}
            required
          />

          {/* Avatar Selection */}
          <Box sx={{ mb: 1 }}>
            <AvatarSelector
              selectedAvatar={selectedAvatar}
              onAvatarSelect={setSelectedAvatar}
              defaultAvatar={DEFAULT_AVATAR}
            />
          </Box>

          {/* Age - Slider */}
          <Box sx={{ mb: 2 }}>
            <Typography variant="subtitle2" fontWeight="bold" gutterBottom>
              {t.createProfile.ageRequired}
            </Typography>
            <Box sx={{ px: 1, py: 0 }}>
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
                  if (value === 3) return t.createProfile.ageLabel.lessThan3.split(' ')[0];
                  if (value === 15) return t.createProfile.ageLabel.moreThan15.split(' ')[0];
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
                mt: 1,
                textAlign: 'center',
                fontWeight: 600,
                fontSize: '0.875rem',
              }}
            >
              {age === '3'
                ? t.createProfile.ageLabel.lessThan3
                : age === '15'
                  ? t.createProfile.ageLabel.moreThan15
                  : `${age} ${t.createProfile.ageLabel.yearsOld}`}
            </Typography>
          </Box>

          {/* Focus Areas */}
          <Typography variant="subtitle2" fontWeight="bold" gutterBottom>
            {t.createProfile.focusAreasRequired}
          </Typography>
          <Typography variant="caption" color="text.secondary" sx={{ mb: 1, display: 'block' }}>
            {t.createProfile.focusAreasDescription}
          </Typography>

          <Box sx={{
            display: 'grid',
            gridTemplateColumns: 'repeat(2, 1fr)',
            gap: 1.5,
            mb: 2
          }}>
            {focusAreaOptions.map((skill) => {
              const isSelected = focusAreas.includes(skill.id);
              const IconComponent = skill.icon;
              return (
                <Box
                  key={skill.id}
                  onClick={() => handleFocusAreaToggle(skill.id)}
                  sx={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: 1.5,
                    p: 1.5,
                    borderRadius: 3,
                    border: `2px solid ${isSelected ? skill.color : '#E5E7EB'}`,
                    bgcolor: isSelected ? skill.bgColor : 'transparent',
                    cursor: 'pointer',
                    transition: 'all 0.2s ease',
                    minHeight: 56,
                    '&:hover': {
                      borderColor: skill.color,
                      bgcolor: skill.bgColor,
                      transform: 'translateY(-2px)',
                      boxShadow: `0 4px 12px ${skill.color}20`,
                    },
                  }}
                >
                  {/* Colored Circle with SVG Icon */}
                  <Box
                    sx={{
                      width: 40,
                      height: 40,
                      borderRadius: '50%',
                      bgcolor: skill.bgColor,
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      flexShrink: 0,
                      border: `2px solid ${skill.color}40`,
                    }}
                  >
                    <IconComponent sx={{ fontSize: 20, color: skill.color }} />
                  </Box>
                  {/* Label */}
                  <Typography
                    variant="body2"
                    fontWeight={isSelected ? 600 : 500}
                    sx={{
                      color: isSelected ? skill.color : 'text.primary',
                      flex: 1,
                      fontSize: '0.8rem',
                      lineHeight: 1.3,
                    }}
                  >
                    {skill.label}
                  </Typography>
                </Box>
              );
            })}
          </Box>

          {/* Diagnosis (Optional, Multi-select) */}
          <Typography variant="subtitle2" fontWeight="bold" gutterBottom>
            {t.createProfile.diagnosisOptional}
          </Typography>
          <Typography variant="caption" color="text.secondary" sx={{ mb: 1, display: 'block' }}>
            {t.createProfile.diagnosisDescription}
          </Typography>

          <Grid container spacing={1} sx={{ mb: 2 }}>
            {diagnosisOptions.map((diag) => (
              <Grid item xs={6} key={diag.id}>
                <Chip
                  label={diag.label}
                  onClick={() => handleDiagnosisToggle(diag.id)}
                  color={diagnoses.includes(diag.id) ? 'secondary' : 'default'}
                  variant={diagnoses.includes(diag.id) ? 'filled' : 'outlined'}
                  sx={{
                    width: '100%',
                    height: 32,
                    '& .MuiChip-label': { fontSize: '0.7rem' }
                  }}
                />
              </Grid>
            ))}
          </Grid>

          {error && (
            <Typography color="error" variant="body2" sx={{ mb: 2 }}>
              {error}
            </Typography>
          )}

          {/* Submit */}
          <Button
            fullWidth
            variant="contained"
            size="medium"
            onClick={handleSubmit}
            disabled={isLoading}
            sx={{ py: 1 }}
          >
            {isLoading ? t.createProfile.creating : t.createProfile.createProfile}
          </Button>
        </CardContent>
      </Card>
    </Container>
  );
};

export default CreateProfile;
