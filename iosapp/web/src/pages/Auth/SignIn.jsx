/**
 * Sign In / Sign Up Page for Komal
 * Modern auth flow with welcome screen and form views
 */

import React, { useState } from 'react';
import {
  Container,
  Typography,
  TextField,
  Button,
  Box,
  Alert,
  CircularProgress,
  IconButton,
  Fade
} from '@mui/material';
import { ArrowBack } from '@mui/icons-material';
import { useAuth } from '../../contexts/AuthContext';
import { useNavigate } from 'react-router-dom';
import { supabase } from '../../services/supabase';
import { useLanguage } from '../../i18n/LanguageContext';
import { useEffect } from 'react';

const SignIn = () => {
  const { t } = useLanguage();
  // View states: 'welcome', 'signin', 'signup'
  const [view, setView] = useState('welcome');
  const [email, setEmail] = useState('');

  // Clear body background on mount and restore on unmount
  useEffect(() => {
    const originalBg = document.body.style.backgroundColor;
    document.body.style.backgroundColor = 'transparent';
    return () => {
      document.body.style.backgroundColor = originalBg;
    };
  }, []);
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState('');
  const [info, setInfo] = useState('');

  const { login, signup, devLogin, isDevMode } = useAuth();
  const navigate = useNavigate();

  const validateEmail = (email) => {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  };

  const handleSignIn = async () => {
    setError('');
    setInfo('');

    if (!email || !password) {
      setError(t.auth.signInPage.enterEmailAndPassword);
      return;
    }

    if (!validateEmail(email)) {
      setError(t.auth.signInPage.enterValidEmail);
      return;
    }

    setIsLoading(true);

    try {
      await login(email, password);
      navigate('/profile-select');
    } catch (err) {
      const errorMessage = err.message || t.auth.signInPage.signInFailed;

      // Check if user doesn't exist
      if (errorMessage.includes('Invalid login credentials') ||
        errorMessage.includes('User not found')) {
        setError('');
        setInfo(t.auth.signInPage.noAccountFound);
        // Switch to sign up view with email pre-filled
        setView('signup');
      } else {
        setError(errorMessage);
      }
    } finally {
      setIsLoading(false);
    }
  };

  const handleSignUp = async () => {
    setError('');
    setInfo('');

    if (!email || !password || !confirmPassword) {
      setError(t.auth.signInPage.fillAllFields);
      return;
    }

    if (!validateEmail(email)) {
      setError(t.auth.signInPage.enterValidEmail);
      return;
    }

    if (password.length < 6) {
      setError(t.auth.signInPage.passwordMinLength);
      return;
    }

    if (password !== confirmPassword) {
      setError(t.auth.signInPage.passwordsDoNotMatch);
      return;
    }

    setIsLoading(true);

    try {
      const result = await signup({ email, password, authMethod: 'email', language: 'en' });

      // If email confirmation is required, redirect to login with message
      if (result?.needsEmailConfirmation) {
        setError('');
        setInfo(t.auth.signInPage.checkEmailVerify);
        setView('signin'); // Switch to sign in view
        setPassword('');
        setConfirmPassword('');
        return;
      }

      // If user is immediately authenticated (no email confirmation required)
      if (result?.session) {
        navigate('/profile-select');
      } else {
        // Fallback: redirect to login
        setError('');
        setInfo(t.auth.signInPage.accountCreated);
        setView('signin');
        setPassword('');
        setConfirmPassword('');
      }
    } catch (err) {
      const errorMessage = err.message || t.auth.signInPage.signUpFailed;

      // Check if user already exists
      if (errorMessage.includes('User already registered') ||
        errorMessage.includes('already exists')) {
        setError('');
        setInfo(t.auth.signInPage.accountAlreadyExists);
        setView('signin');
        setConfirmPassword('');
      } else {
        setError(errorMessage);
      }
    } finally {
      setIsLoading(false);
    }
  };

  const handleBack = () => {
    setView('welcome');
    setError('');
    setInfo('');
    setPassword('');
    setConfirmPassword('');
  };

  const handleKeyPress = (e) => {
    if (e.key === 'Enter') {
      if (view === 'signin') {
        handleSignIn();
      } else if (view === 'signup') {
        handleSignUp();
      }
    }
  };

  // Welcome View - Two buttons
  const WelcomeView = () => (
    <Fade in={view === 'welcome'} timeout={300}>
      <Box
        sx={{
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'space-between',
          minHeight: '100vh',
          pb: 8,
          px: 3,
          pt: 8,
        }}
      >
        {/* Welcome Text */}
        <Box sx={{ textAlign: 'center', mt: 4 }}>
          <Typography
            variant="h3"
            sx={{
              fontWeight: 800,
              color: '#fff',
              mb: 2,
              fontSize: { xs: '2.8rem', sm: '4rem' },
              textShadow: '0 2px 10px rgba(0,0,0,0.3)',
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
            }}
          >
            <Box component="span" sx={{ fontSize: '0.6em', fontWeight: 600, mb: 1 }}>
              Welcome to
            </Box>
            <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 2 }}>
              <img
                src="/assets/finalstrokemonkey.png"
                alt="Logo"
                style={{ width: '100px', height: 'auto', filter: 'drop-shadow(0 4px 12px rgba(0,0,0,0.3))' }}
              />
              Komal
            </Box>
          </Typography>
          <Typography
            variant="body1"
            sx={{
              color: '#fff',
              fontSize: { xs: '0.85rem', sm: '1.1rem' },
              maxWidth: 400,
              mx: 'auto',
              fontWeight: 500,
              whiteSpace: 'nowrap',
            }}
          >
            {t.auth.signInPage.tagline}
          </Typography>
        </Box>

        {/* Bottom Section - Buttons + Terms */}
        <Box sx={{ width: '100%', maxWidth: 400, display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
          {/* Buttons */}
          <Button
            fullWidth
            variant="contained"
            size="large"
            onClick={() => setView('signin')}
            sx={{
              py: 2,
              mb: 2,
              borderRadius: '50px',
              fontSize: '1.1rem',
              fontWeight: 700,
              textTransform: 'none',
              backgroundColor: '#fff',
              color: '#000',
              '&:hover': {
                backgroundColor: '#f0f0f0',
              },
            }}
          >
            Sign In
          </Button>
          <Button
            fullWidth
            variant="outlined"
            size="large"
            onClick={() => setView('signup')}
            sx={{
              py: 2,
              mb: 4,
              borderRadius: '50px',
              fontSize: '1.1rem',
              fontWeight: 700,
              textTransform: 'none',
              borderColor: '#fff',
              borderWidth: 2,
              color: '#fff',
              '&:hover': {
                borderWidth: 2,
                borderColor: '#eee',
                backgroundColor: 'rgba(255, 255, 255, 0.1)',
              },
            }}
          >
            Create Account
          </Button>

          {/* Terms */}
          <Typography
            variant="caption"
            sx={{
              color: '#fff',
              textAlign: 'center',
              maxWidth: 320,
              fontWeight: 500,
            }}
          >
            By continuing, you agree to our Terms of Service and{' '}
            <a
              href="https://www.komalkids.com/privacypolicy"
              target="_blank"
              rel="noopener noreferrer"
              style={{ color: '#fff', textDecoration: 'underline' }}
            >
              Privacy Policy
            </a>
          </Typography>
        </Box>

      </Box>
    </Fade>
  );

  // Sign In Form View
  const SignInView = () => (
    <Fade in={view === 'signin'} timeout={300}>
      <Box
        sx={{
          display: 'flex',
          flexDirection: 'column',
          minHeight: '100vh',
          position: 'relative',

          '& > *': {
            position: 'relative',
            zIndex: 1,
          },
        }}
      >
        {/* Header - Back Button & Logo */}
        <Box sx={{ px: 3, pt: 3, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <IconButton
            onClick={handleBack}
            sx={{
              backgroundColor: 'rgba(255, 255, 255, 0.1)',
              color: '#fff',
              '&:hover': {
                backgroundColor: 'rgba(255, 255, 255, 0.2)',
              },
            }}
          >
            <ArrowBack />
          </IconButton>
          <img
            src="/assets/finalstrokemonkey.png"
            alt="Logo"
            style={{ width: '60px', height: 'auto', filter: 'drop-shadow(0 2px 8px rgba(0,0,0,0.2))' }}
          />
        </Box>

        {/* Main Content - Centered */}
        <Box
          sx={{
            flex: 1,
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            px: 3,
            pb: 2,
          }}
        >
          {/* Title - Centered */}
          <Typography
            variant="h4"
            sx={{
              fontWeight: 800,
              color: '#fff',
              mb: 1,
              textAlign: 'center',
            }}
          >
            Sign In
          </Typography>
          <Typography
            variant="body1"
            sx={{
              color: 'rgba(255, 255, 255, 0.8)',
              mb: 4,
              textAlign: 'center',
            }}
          >
            Welcome back! Enter your details.
          </Typography>

          {/* Info Alert */}
          {info && (
            <Alert severity="info" sx={{ mb: 3, borderRadius: 2, width: '100%', maxWidth: 400 }}>
              {info}
            </Alert>
          )}

          {/* Error Alert */}
          {error && (
            <Alert severity="error" sx={{ mb: 3, borderRadius: 2, width: '100%', maxWidth: 400 }}>
              {error}
            </Alert>
          )}

          {/* Form Fields */}
          <Box sx={{ width: '100%', maxWidth: 400 }}>
            {/* Email Field */}
            <TextField
              fullWidth
              label={t.auth.email}
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              onKeyDown={handleKeyPress}
              sx={{
                mb: 3,
                '& .MuiOutlinedInput-root': {
                  borderRadius: '16px',
                  backgroundColor: 'rgba(255, 255, 255, 0.1)',
                  color: '#fff',
                  '& fieldset': { borderColor: 'rgba(255, 255, 255, 0.3)' },
                  '&:hover fieldset': { borderColor: 'rgba(255, 255, 255, 0.5)' },
                  '&.Mui-focused fieldset': { borderColor: '#fff' },
                },
                '& .MuiInputLabel-root': { color: 'rgba(255, 255, 255, 0.7)' },
                '& .MuiInputLabel-root.Mui-focused': { color: '#fff' },
              }}
              autoComplete="email"
              disabled={isLoading}
            />

            {/* Password Field */}
            <TextField
              fullWidth
              label={t.auth.password}
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              onKeyDown={handleKeyPress}
              sx={{
                mb: 2,
                '& .MuiOutlinedInput-root': {
                  borderRadius: '16px',
                  backgroundColor: 'rgba(255, 255, 255, 0.1)',
                  color: '#fff',
                  '& fieldset': { borderColor: 'rgba(255, 255, 255, 0.3)' },
                  '&:hover fieldset': { borderColor: 'rgba(255, 255, 255, 0.5)' },
                  '&.Mui-focused fieldset': { borderColor: '#fff' },
                },
                '& .MuiInputLabel-root': { color: 'rgba(255, 255, 255, 0.7)' },
                '& .MuiInputLabel-root.Mui-focused': { color: '#fff' },
              }}
              autoComplete="current-password"
              disabled={isLoading}
            />

            {/* Forgot Password - Centered */}
            <Box sx={{ textAlign: 'center', mb: 2 }}>
              <Button
                variant="text"
                size="small"
                onClick={() => navigate('/auth/forgot-password')}
                sx={{
                  color: 'rgba(255, 255, 255, 0.7)',
                  textTransform: 'none',
                }}
                disabled={isLoading}
              >
                {t.auth.forgotPassword}
              </Button>
            </Box>
          </Box>
        </Box>

        {/* Bottom Section - Fixed at bottom */}
        <Box
          sx={{
            px: 3,
            pb: 4,
            pt: 2,
          }}
        >
          <Box sx={{ maxWidth: 400, mx: 'auto', width: '100%' }}>
            {/* Sign In Button */}
            <Button
              fullWidth
              variant="contained"
              size="large"
              onClick={handleSignIn}
              disabled={isLoading}
              sx={{
                py: 2,
                borderRadius: '50px',
                fontSize: '1.1rem',
                fontWeight: 700,
                textTransform: 'none',
                backgroundColor: '#fff',
                color: '#000',
                '&:hover': {
                  backgroundColor: '#f0f0f0',
                },
              }}
            >
              {isLoading ? (
                <CircularProgress size={24} color="inherit" />
              ) : (
                'Sign In'
              )}
            </Button>



            {/* Switch to Sign Up */}
            <Box sx={{ textAlign: 'center', mt: 3 }}>
              <Typography variant="body2" sx={{ color: 'rgba(255, 255, 255, 0.8)' }}>
                Don't have an account?{' '}
                <Button
                  variant="text"
                  onClick={() => {
                    setView('signup');
                    setError('');
                    setInfo('');
                  }}
                  sx={{
                    textTransform: 'none',
                    fontWeight: 700,
                    fontSize: '0.875rem',
                    color: '#fff',
                    p: 0,
                    minWidth: 'auto',
                    verticalAlign: 'baseline',
                    '&:hover': { backgroundColor: 'transparent', textDecoration: 'underline' }
                  }}
                >
                  Create Account
                </Button>
              </Typography>
            </Box>
          </Box>
        </Box>
      </Box>
    </Fade>
  );

  // Sign Up Form View
  const SignUpView = () => (
    <Fade in={view === 'signup'} timeout={300}>
      <Box
        sx={{
          display: 'flex',
          flexDirection: 'column',
          minHeight: '100vh',

          '& > *': {
            position: 'relative',
            zIndex: 1,
          },
        }}
      >
        {/* Header - Back Button & Logo */}
        <Box sx={{ px: 3, pt: 3, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <IconButton
            onClick={handleBack}
            sx={{
              backgroundColor: 'rgba(255, 255, 255, 0.1)',
              color: '#fff',
              '&:hover': {
                backgroundColor: 'rgba(255, 255, 255, 0.2)',
              },
            }}
          >
            <ArrowBack />
          </IconButton>
          <img
            src="/assets/finalstrokemonkey.png"
            alt="Logo"
            style={{ width: '60px', height: 'auto', filter: 'drop-shadow(0 2px 8px rgba(0,0,0,0.2))' }}
          />
        </Box>

        {/* Main Content - Centered */}
        <Box
          sx={{
            flex: 1,
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            px: 3,
            pb: 2,
          }}
        >
          {/* Title - Centered */}
          <Typography
            variant="h4"
            sx={{
              fontWeight: 800,
              color: '#fff',
              mb: 1,
              textAlign: 'center',
            }}
          >
            Create Account
          </Typography>
          <Typography
            variant="body1"
            sx={{
              color: 'rgba(255, 255, 255, 0.8)',
              mb: 4,
              textAlign: 'center',
            }}
          >
            Start your journey with Komal.
          </Typography>

          {/* Info Alert */}
          {info && (
            <Alert severity="info" sx={{ mb: 3, borderRadius: 2, width: '100%', maxWidth: 400 }}>
              {info}
            </Alert>
          )}

          {/* Error Alert */}
          {error && (
            <Alert severity="error" sx={{ mb: 3, borderRadius: 2, width: '100%', maxWidth: 400 }}>
              {error}
            </Alert>
          )}

          {/* Form Fields */}
          <Box sx={{ width: '100%', maxWidth: 400 }}>
            {/* Email Field */}
            <TextField
              fullWidth
              label={t.auth.email}
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              onKeyDown={handleKeyPress}
              sx={{
                mb: 3,
                '& .MuiOutlinedInput-root': {
                  borderRadius: '16px',
                  backgroundColor: 'rgba(255, 255, 255, 0.1)',
                  color: '#fff',
                  '& fieldset': { borderColor: 'rgba(255, 255, 255, 0.3)' },
                  '&:hover fieldset': { borderColor: 'rgba(255, 255, 255, 0.5)' },
                  '&.Mui-focused fieldset': { borderColor: '#fff' },
                },
                '& .MuiInputLabel-root': { color: 'rgba(255, 255, 255, 0.7)' },
                '& .MuiInputLabel-root.Mui-focused': { color: '#fff' },
              }}
              autoComplete="email"
              disabled={isLoading}
            />

            {/* Password Field */}
            <TextField
              fullWidth
              label={t.auth.password}
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              onKeyDown={handleKeyPress}
              sx={{
                mb: 3,
                '& .MuiOutlinedInput-root': {
                  borderRadius: '16px',
                  backgroundColor: 'rgba(255, 255, 255, 0.1)',
                  color: '#fff',
                  '& fieldset': { borderColor: 'rgba(255, 255, 255, 0.3)' },
                  '&:hover fieldset': { borderColor: 'rgba(255, 255, 255, 0.5)' },
                  '&.Mui-focused fieldset': { borderColor: '#fff' },
                },
                '& .MuiInputLabel-root': { color: 'rgba(255, 255, 255, 0.7)' },
                '& .MuiInputLabel-root.Mui-focused': { color: '#fff' },
                '& .MuiFormHelperText-root': { color: 'rgba(255, 255, 255, 0.6)' },
              }}
              autoComplete="new-password"
              disabled={isLoading}
              helperText={t.auth.signInPage.atLeast6Characters}
            />

            {/* Confirm Password Field */}
            <TextField
              fullWidth
              label={t.auth.confirmPassword}
              type="password"
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              onKeyDown={handleKeyPress}
              sx={{
                mb: 2,
                '& .MuiOutlinedInput-root': {
                  borderRadius: '16px',
                  backgroundColor: 'rgba(255, 255, 255, 0.1)',
                  color: '#fff',
                  '& fieldset': { borderColor: 'rgba(255, 255, 255, 0.3)' },
                  '&:hover fieldset': { borderColor: 'rgba(255, 255, 255, 0.5)' },
                  '&.Mui-focused fieldset': { borderColor: '#fff' },
                },
                '& .MuiInputLabel-root': { color: 'rgba(255, 255, 255, 0.7)' },
                '& .MuiInputLabel-root.Mui-focused': { color: '#fff' },
                '& .MuiFormHelperText-root': { color: 'rgba(255, 255, 255, 0.6)' },
              }}
              autoComplete="new-password"
              disabled={isLoading}
              error={confirmPassword && password !== confirmPassword}
              helperText={confirmPassword && password !== confirmPassword ? t.auth.signInPage.passwordsDoNotMatch : ''}
            />
          </Box>
        </Box>

        {/* Bottom Section - Fixed at bottom */}
        <Box
          sx={{
            px: 3,
            pb: 4,
            pt: 2,
          }}
        >
          <Box sx={{ maxWidth: 400, mx: 'auto', width: '100%' }}>
            {/* Create Account Button */}
            <Button
              fullWidth
              variant="contained"
              size="large"
              onClick={handleSignUp}
              disabled={isLoading}
              sx={{
                py: 2,
                borderRadius: '50px',
                fontSize: '1.1rem',
                fontWeight: 700,
                textTransform: 'none',
                backgroundColor: '#fff',
                color: '#000',
                '&:hover': {
                  backgroundColor: '#f0f0f0',
                },
              }}
            >
              {isLoading ? (
                <CircularProgress size={24} color="inherit" />
              ) : (
                'Create Account'
              )}
            </Button>



            {/* Switch to Sign In */}
            <Box sx={{ textAlign: 'center', mt: 3 }}>
              <Typography variant="body2" sx={{ color: 'rgba(255, 255, 255, 0.8)' }}>
                Already have an account?{' '}
                <Button
                  variant="text"
                  onClick={() => {
                    setView('signin');
                    setError('');
                    setInfo('');
                  }}
                  sx={{
                    textTransform: 'none',
                    fontWeight: 700,
                    fontSize: '0.875rem',
                    color: '#fff',
                    p: 0,
                    minWidth: 'auto',
                    verticalAlign: 'baseline',
                    '&:hover': { backgroundColor: 'transparent', textDecoration: 'underline' }
                  }}
                >
                  Sign In
                </Button>
              </Typography>
            </Box>

            {/* Terms */}
            <Typography
              variant="caption"
              sx={{
                color: 'rgba(255, 255, 255, 0.7)',
                textAlign: 'center',
                mt: 3,
                display: 'block',
              }}
            >
              By continuing, you agree to our Terms of Service and{' '}
              <a
                href="https://www.komalkids.com/privacypolicy"
                target="_blank"
                rel="noopener noreferrer"
                style={{ color: 'rgba(255, 255, 255, 0.7)', textDecoration: 'underline' }}
              >
                Privacy Policy
              </a>
            </Typography>
          </Box>
        </Box>
      </Box>
    </Fade>
  );

  // Background Media Component
  const BackgroundMedia = () => (
    <Box
      sx={{
        position: 'fixed',
        top: 0,
        left: 0,
        width: '100vw',
        height: '100vh',
        zIndex: 0,
        overflow: 'hidden',
        '&::after': {
          content: '""',
          position: 'absolute',
          top: 0,
          left: 0,
          width: '100%',
          height: '100%',
          backgroundColor: 'rgba(0, 0, 0, 0.4)',
          zIndex: 1,
        }
      }}
    >
      {view === 'welcome' ? (
        <video
          autoPlay
          loop
          muted
          playsInline
          preload="auto"
          key="welcome-video"
          style={{
            position: 'absolute',
            top: 0,
            left: 0,
            width: '100%',
            height: '100%',
            objectFit: 'cover',
            zIndex: 0,
          }}
        >
          <source src="/assets/splashsignin.mp4" type="video/mp4" />
        </video>
      ) : (
        <Box
          sx={{
            position: 'absolute',
            top: 0,
            left: 0,
            width: '100%',
            height: '100%',
            backgroundImage: 'url(/assets/signin.png)',
            backgroundSize: 'cover',
            backgroundPosition: 'center',
            zIndex: 0,
          }}
        />
      )}
    </Box>
  );

  return (
    <Box
      sx={{
        minHeight: '100vh',
        backgroundColor: 'transparent',
        position: 'relative',
        zIndex: 0,
      }}
    >
      <BackgroundMedia />
      <Box sx={{ position: 'relative', zIndex: 2 }}>
        {view === 'welcome' && <WelcomeView />}
        {view === 'signin' && <SignInView />}
        {view === 'signup' && <SignUpView />}
      </Box>
    </Box>
  );
};

export default SignIn;
