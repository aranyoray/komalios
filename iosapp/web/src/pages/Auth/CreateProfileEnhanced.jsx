/**
 * Enhanced Profile Creation for Komal
 * All fields: DOB, Gender, Focus Areas, Sensitivity Settings
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
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  Chip,
  Grid,
  Slider,
  Switch,
  FormControlLabel,
  Alert,
  Stepper,
  Step,
  StepLabel,
} from '@mui/material';
import {
  Person,
  Cake,
  VolumeUp,
  Animation,
  Camera,
  Mic,
} from '@mui/icons-material';
import { useAuth } from '../../contexts/AuthContext';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { supabase } from '../../services/supabase';
import { Haptics, ImpactStyle } from '@capacitor/haptics';
import { Camera as CapCamera } from '@capacitor/camera';

const focusAreaOptions = [
  { id: 'social-skills', label: 'Social Skills', emoji: '🤝', description: 'Communication & friendship' },
  { id: 'language-skills', label: 'Language Skills', emoji: '🗣️', description: 'Speech & comprehension' },
  { id: 'cognitive-development', label: 'Cognitive Development', emoji: '🧠', description: 'Attention & memory' },
  { id: 'emotional-intelligence', label: 'Emotional Intelligence', emoji: '❤️', description: 'Understanding feelings' },
  { id: 'life-skills', label: 'Life Skills', emoji: '🌟', description: 'Daily independence' },
];

const diagnosisOptions = [
  { id: 'autism', label: 'Autism Spectrum Disorder' },
  { id: 'adhd', label: 'ADHD' },
  { id: 'anxiety', label: 'Anxiety' },
  { id: 'developmental-delay', label: 'Developmental Delay' },
  { id: 'sensory-processing', label: 'Sensory Processing' },
  { id: 'learning-disability', label: 'Learning Disability' },
  { id: 'speech-delay', label: 'Speech/Language Delay' },
  { id: 'other', label: 'Other' },
];

const CreateProfileEnhanced = () => {
  const { user, selectProfile } = useAuth();
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const isGuest = searchParams.get('guest') === 'true';

  const [activeStep, setActiveStep] = useState(0);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState('');

  // Basic Info
  const [name, setName] = useState('');
  const [dob, setDob] = useState('');
  const [gender, setGender] = useState('');

  // Focus Areas & Diagnosis
  const [focusAreas, setFocusAreas] = useState([]);
  const [diagnoses, setDiagnoses] = useState([]);

  // Sensitivity Settings
  const [soundLevel, setSoundLevel] = useState(50);
  const [animationLevel, setAnimationLevel] = useState('medium');

  // Permissions
  const [cameraPermission, setCameraPermission] = useState(false);
  const [micPermission, setMicPermission] = useState(false);

  const steps = ['Basic Info', 'Focus Areas', 'Sensitivity', 'Permissions'];

  const calculateAge = (dateString) => {
    if (!dateString) return '';
    const today = new Date();
    const birthDate = new Date(dateString);
    let age = today.getFullYear() - birthDate.getFullYear();
    const monthDiff = today.getMonth() - birthDate.getMonth();
    if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDate.getDate())) {
      age--;
    }
    return age;
  };

  const handleFocusAreaToggle = (areaId) => {
    setFocusAreas(prev =>
      prev.includes(areaId)
        ? prev.filter(id => id !== areaId)
        : [...prev, areaId]
    );
    // Haptic feedback on mobile
    try {
      Haptics.impact({ style: ImpactStyle.Light });
    } catch (e) {}
  };

  const handleDiagnosisToggle = (diagId) => {
    setDiagnoses(prev =>
      prev.includes(diagId)
        ? prev.filter(id => id !== diagId)
        : [...prev, diagId]
    );
  };

  const requestCameraPermission = async () => {
    try {
      const permission = await CapCamera.requestPermissions();
      setCameraPermission(permission.camera === 'granted');
    } catch (e) {
      // Web fallback
      try {
        await navigator.mediaDevices.getUserMedia({ video: true });
        setCameraPermission(true);
      } catch (err) {
        setCameraPermission(false);
      }
    }
  };

  const requestMicPermission = async () => {
    try {
      await navigator.mediaDevices.getUserMedia({ audio: true });
      setMicPermission(true);
    } catch (e) {
      setMicPermission(false);
    }
  };

  const handleNext = () => {
    if (activeStep === 0 && (!name || !dob)) {
      setError('Please fill in name and date of birth');
      return;
    }
    if (activeStep === 1 && focusAreas.length === 0) {
      setError('Please select at least one focus area');
      return;
    }
    setError('');
    setActiveStep(prev => prev + 1);
  };

  const handleBack = () => {
    setActiveStep(prev => prev - 1);
  };

  const handleSubmit = async () => {
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
          throw new Error('User record not found. Please ensure you are logged in.');
        }
        
        userId = userRecord.id;
      }

      if (!userId) {
        throw new Error('Unable to determine user ID. Please log in again.');
      }

      const age = calculateAge(dob);
      const learnerData = {
        user_id: userId,
        name,
        date_of_birth: dob,
        age,
        gender: gender || null,
        focus_areas: focusAreas,
        diagnoses: diagnoses.length > 0 ? diagnoses : null,
        settings: {
          soundLevel,
          animationLevel,
          sessionDuration: 15,
          difficulty: 'adaptive',
          rewards: true,
        },
        permissions: {
          camera: cameraPermission,
          microphone: micPermission,
        },
      };

      // Insert into 'learners' table, not 'profiles' table
      // 'profiles' is for parent/user info, 'learners' is for child profiles
      const { data, error: insertError } = await supabase
        .from('learners')
        .insert(learnerData)
        .select()
        .single();

      if (insertError) throw insertError;

      await selectProfile(data.id, 'learner');
      navigate('/learner');
    } catch (err) {
      console.error('Failed to create profile:', err);
      setError(err.message || 'Failed to create profile');
    } finally {
      setIsLoading(false);
    }
  };

  const renderStepContent = () => {
    switch (activeStep) {
      case 0:
        return (
          <Box>
            <TextField
              fullWidth
              label="Child's Name"
              value={name}
              onChange={(e) => setName(e.target.value)}
              sx={{ mb: 3 }}
              required
            />

            <TextField
              fullWidth
              label="Date of Birth"
              type="date"
              value={dob}
              onChange={(e) => setDob(e.target.value)}
              InputLabelProps={{ shrink: true }}
              sx={{ mb: 2 }}
              required
            />
            {dob && (
              <Typography variant="body2" color="primary" sx={{ mb: 3 }}>
                Age: {calculateAge(dob)} years old
              </Typography>
            )}

            <FormControl fullWidth sx={{ mb: 3 }}>
              <InputLabel>Gender (Optional)</InputLabel>
              <Select value={gender} onChange={(e) => setGender(e.target.value)}>
                <MenuItem value="">Prefer not to say</MenuItem>
                <MenuItem value="male">Male</MenuItem>
                <MenuItem value="female">Female</MenuItem>
                <MenuItem value="other">Other</MenuItem>
              </Select>
            </FormControl>
          </Box>
        );

      case 1:
        return (
          <Box>
            <Typography variant="subtitle1" fontWeight={600} gutterBottom>
              Focus Areas *
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
              Select areas to work on (will determine session order)
            </Typography>

            <Grid container spacing={2} sx={{ mb: 4 }}>
              {focusAreaOptions.map((area) => (
                <Grid item xs={12} sm={6} key={area.id}>
                  <Card
                    onClick={() => handleFocusAreaToggle(area.id)}
                    sx={{
                      cursor: 'pointer',
                      border: '2px solid',
                      borderColor: focusAreas.includes(area.id) ? 'primary.main' : 'grey.200',
                      bgcolor: focusAreas.includes(area.id) ? 'primary.50' : 'white',
                      transition: 'all 0.2s',
                      '&:hover': { transform: 'scale(1.02)' },
                    }}
                  >
                    <CardContent sx={{ textAlign: 'center', py: 2 }}>
                      <Typography variant="h4" sx={{ mb: 1 }}>{area.emoji}</Typography>
                      <Typography variant="subtitle2" fontWeight={600}>{area.label}</Typography>
                      <Typography variant="caption" color="text.secondary">
                        {area.description}
                      </Typography>
                    </CardContent>
                  </Card>
                </Grid>
              ))}
            </Grid>

            <Typography variant="subtitle1" fontWeight={600} gutterBottom>
              Diagnosis (Optional)
            </Typography>
            <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1 }}>
              {diagnosisOptions.map((diag) => (
                <Chip
                  key={diag.id}
                  label={diag.label}
                  onClick={() => handleDiagnosisToggle(diag.id)}
                  color={diagnoses.includes(diag.id) ? 'secondary' : 'default'}
                  variant={diagnoses.includes(diag.id) ? 'filled' : 'outlined'}
                />
              ))}
            </Box>
          </Box>
        );

      case 2:
        return (
          <Box>
            <Typography variant="subtitle1" fontWeight={600} gutterBottom>
              <VolumeUp sx={{ mr: 1, verticalAlign: 'middle' }} />
              Sound Level
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
              Adjust according to learner's sensitivity
            </Typography>
            <Slider
              value={soundLevel}
              onChange={(e, v) => setSoundLevel(v)}
              marks={[
                { value: 0, label: 'Off' },
                { value: 50, label: 'Medium' },
                { value: 100, label: 'Full' },
              ]}
              sx={{ mb: 4 }}
            />

            <Typography variant="subtitle1" fontWeight={600} gutterBottom>
              <Animation sx={{ mr: 1, verticalAlign: 'middle' }} />
              Animation Level
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
              Select according to learner's sensitivity
            </Typography>
            <Box sx={{ display: 'flex', gap: 1, mb: 4 }}>
              {['off', 'medium', 'high'].map((level) => (
                <Chip
                  key={level}
                  label={level.toUpperCase()}
                  onClick={() => setAnimationLevel(level)}
                  color={animationLevel === level ? 'primary' : 'default'}
                  variant={animationLevel === level ? 'filled' : 'outlined'}
                  sx={{ flex: 1, py: 2 }}
                />
              ))}
            </Box>
          </Box>
        );

      case 3:
        return (
          <Box>
            <Typography variant="subtitle1" fontWeight={600} gutterBottom>
              App Permissions
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
              Required for eye-tracking and biomarker analysis
            </Typography>

            <Card sx={{ mb: 2 }}>
              <CardContent sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                  <Camera color={cameraPermission ? 'success' : 'action'} />
                  <Box>
                    <Typography fontWeight={500}>Camera</Typography>
                    <Typography variant="caption" color="text.secondary">
                      For eye tracking & face detection
                    </Typography>
                  </Box>
                </Box>
                <Button
                  variant={cameraPermission ? 'contained' : 'outlined'}
                  color={cameraPermission ? 'success' : 'primary'}
                  onClick={requestCameraPermission}
                  size="small"
                >
                  {cameraPermission ? 'Granted' : 'Allow'}
                </Button>
              </CardContent>
            </Card>

            <Card>
              <CardContent sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                  <Mic color={micPermission ? 'success' : 'action'} />
                  <Box>
                    <Typography fontWeight={500}>Microphone</Typography>
                    <Typography variant="caption" color="text.secondary">
                      For voice interaction with avatar
                    </Typography>
                  </Box>
                </Box>
                <Button
                  variant={micPermission ? 'contained' : 'outlined'}
                  color={micPermission ? 'success' : 'primary'}
                  onClick={requestMicPermission}
                  size="small"
                >
                  {micPermission ? 'Granted' : 'Allow'}
                </Button>
              </CardContent>
            </Card>
          </Box>
        );

      default:
        return null;
    }
  };

  return (
    <Container maxWidth="sm" sx={{ py: 4 }}>
      <Box textAlign="center" mb={4}>
        <Typography variant="h4" fontWeight={700} color="primary" gutterBottom>
          Create Learner Profile
        </Typography>
        <Typography variant="body1" color="text.secondary">
          Personalize {name || "your child"}'s experience
        </Typography>
      </Box>

      <Stepper activeStep={activeStep} sx={{ mb: 4 }}>
        {steps.map((label) => (
          <Step key={label}>
            <StepLabel>{label}</StepLabel>
          </Step>
        ))}
      </Stepper>

      <Card>
        <CardContent sx={{ p: 4 }}>
          {error && (
            <Alert severity="error" sx={{ mb: 3 }}>
              {error}
            </Alert>
          )}

          {renderStepContent()}

          <Box sx={{ display: 'flex', justifyContent: 'space-between', mt: 4 }}>
            <Button
              onClick={handleBack}
              disabled={activeStep === 0}
            >
              Back
            </Button>

            {activeStep === steps.length - 1 ? (
              <Button
                variant="contained"
                onClick={handleSubmit}
                disabled={isLoading}
              >
                {isLoading ? 'Creating...' : 'Create Profile'}
              </Button>
            ) : (
              <Button
                variant="contained"
                onClick={handleNext}
              >
                Next
              </Button>
            )}
          </Box>
        </CardContent>
      </Card>
    </Container>
  );
};

export default CreateProfileEnhanced;
