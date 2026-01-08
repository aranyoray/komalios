/**
 * Reset Password Page for Komal
 * Code-based password reset for mobile app
 */

import React, { useState, useEffect } from 'react';
import {
  Container,
  Card,
  CardContent,
  Typography,
  TextField,
  Button,
  Box,
  Alert,
  CircularProgress,
  InputAdornment,
  IconButton,
  Stepper,
  Step,
  StepLabel
} from '@mui/material';
import { Visibility, VisibilityOff, ArrowBack } from '@mui/icons-material';
import { useNavigate, useLocation } from 'react-router-dom';
import { resetPasswordWithCode, verifyPasswordResetCode } from '../../auth/supabaseAuth';
import { useLanguage } from '../../i18n/LanguageContext';

const ResetPassword = () => {
  const { t } = useLanguage();
  const location = useLocation();
  const navigate = useNavigate();
  
  // Get email from navigation state or allow user to enter it
  const [email, setEmail] = useState(location.state?.email || '');
  const [resetCode, setResetCode] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);
  const [activeStep, setActiveStep] = useState(0); // 0: email/code, 1: password
  const [codeVerified, setCodeVerified] = useState(false);

  useEffect(() => {
    // If email is provided from previous page, start at step 0 (code entry)
    // Otherwise, user needs to enter email first
    if (email) {
      setActiveStep(0);
    }
  }, [email]);

  const validateEmail = (email) => {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  };

  const validatePassword = (pwd) => {
    if (pwd.length < 6) {
      return t.auth.signInPage.passwordMinLength;
    }
    return null;
  };

  const handleCodeSubmit = async (e) => {
    e.preventDefault();
    setError('');

    if (!email) {
      setError(t.auth.forgotPasswordPage.enterEmailAddress);
      return;
    }

    if (!validateEmail(email)) {
      setError(t.auth.signInPage.enterValidEmail);
      return;
    }

    if (!resetCode || resetCode.length !== 6) {
      setError(t.auth.resetPasswordPage.enterValidCode);
      return;
    }

    setIsLoading(true);

    try {
      // Verify the code (this will create a session if valid)
      const result = await verifyPasswordResetCode(email, resetCode);
      
      if (result.success) {
        setCodeVerified(true);
        setActiveStep(1); // Move to password step
        setError('');
      } else {
        setError(t.auth.resetPasswordPage.invalidOrExpiredCode);
      }
    } catch (err) {
      const errorMessage = err.message || t.auth.resetPasswordPage.failedToVerifyCode;
      setError(errorMessage);
    } finally {
      setIsLoading(false);
    }
  };

  const handlePasswordSubmit = async (e) => {
    e.preventDefault();
    setError('');

    if (!password || !confirmPassword) {
      setError(t.auth.resetPasswordPage.fillAllFields);
      return;
    }

    const passwordError = validatePassword(password);
    if (passwordError) {
      setError(passwordError);
      return;
    }

    if (password !== confirmPassword) {
      setError(t.auth.signInPage.passwordsDoNotMatch);
      return;
    }

    setIsLoading(true);

    try {
      await resetPasswordWithCode(email, resetCode, password);
      setSuccess(true);
      
      // Redirect to sign in after a short delay
      setTimeout(() => {
        navigate('/signin', { 
          state: { message: t.auth.resetPasswordPage.passwordResetSuccessMessage }
        });
      }, 2000);
    } catch (err) {
      const errorMessage = err.message || t.auth.resetPasswordPage.passwordResetSuccess;
      
      if (errorMessage.includes('expired') || errorMessage.includes('invalid')) {
        setError(t.auth.resetPasswordPage.codeExpired);
        setActiveStep(0);
        setCodeVerified(false);
        setResetCode('');
      } else {
        setError(errorMessage);
      }
    } finally {
      setIsLoading(false);
    }
  };

  const handleKeyPress = (e, step) => {
    if (e.key === 'Enter') {
      if (step === 0) {
        handleCodeSubmit(e);
      } else {
        handlePasswordSubmit(e);
      }
    }
  };

  const steps = [t.auth.resetPasswordPage.enterResetCode, t.auth.resetPasswordPage.setNewPassword];

  return (
    <Container maxWidth="sm" sx={{ py: 4, minHeight: '100vh', display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
      <Box textAlign="center" mb={4}>
        <Typography variant="h3" fontWeight="bold" color="primary" gutterBottom>
          Komal
        </Typography>
        <Typography variant="subtitle1" color="text.secondary">
          {t.auth.resetPasswordPage.subtitle}
        </Typography>
      </Box>

      <Card elevation={3}>
        <CardContent sx={{ p: 4 }}>
          {/* Back to Sign In */}
          <Button
            startIcon={<ArrowBack />}
            onClick={() => navigate('/signin')}
            sx={{ mb: 3 }}
            size="small"
          >
            {t.auth.resetPasswordPage.backToSignIn}
          </Button>

          {/* Stepper */}
          <Stepper activeStep={activeStep} sx={{ mb: 4 }}>
            {steps.map((label) => (
              <Step key={label}>
                <StepLabel>{label}</StepLabel>
              </Step>
            ))}
          </Stepper>

          {success ? (
            <Alert severity="success" sx={{ mb: 2 }}>
              <Typography variant="body1" fontWeight="medium" gutterBottom>
                {t.auth.resetPasswordPage.passwordResetSuccess}
              </Typography>
              <Typography variant="body2">
                {t.auth.emailConfirmPage.redirectingToSignIn}
              </Typography>
            </Alert>
          ) : activeStep === 0 ? (
            <>
              <Typography variant="body1" color="text.secondary" sx={{ mb: 3 }}>
                {t.auth.resetPasswordPage.enterValidCode}
              </Typography>

              {/* Error Alert */}
              {error && (
                <Alert severity="error" sx={{ mb: 2 }}>
                  {error}
                </Alert>
              )}

              <form onSubmit={handleCodeSubmit}>
                {/* Email Field (if not provided from previous page) */}
                {!location.state?.email && (
                  <TextField
                    fullWidth
                    label={t.auth.email}
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    onKeyPress={(e) => handleKeyPress(e, 0)}
                    sx={{ mb: 2 }}
                    autoComplete="email"
                    disabled={isLoading}
                    autoFocus
                  />
                )}

                {/* Reset Code Field */}
                <TextField
                  fullWidth
                  label={t.auth.resetPasswordPage.enterResetCode}
                  type="text"
                  value={resetCode}
                  onChange={(e) => {
                    // Only allow digits and limit to 6 characters
                    const value = e.target.value.replace(/\D/g, '').slice(0, 6);
                    setResetCode(value);
                  }}
                  onKeyPress={(e) => handleKeyPress(e, 0)}
                  sx={{ mb: 3 }}
                  disabled={isLoading}
                  autoFocus={!!location.state?.email}
                  placeholder="000000"
                  inputProps={{
                    maxLength: 6,
                    style: { textAlign: 'center', fontSize: '24px', letterSpacing: '8px' }
                  }}
                  helperText={t.auth.resetPasswordPage.enterValidCode}
                />

                {/* Submit Button */}
                <Button
                  fullWidth
                  type="submit"
                  variant="contained"
                  size="large"
                  disabled={isLoading || !email || resetCode.length !== 6}
                  sx={{ py: 1.5 }}
                >
                  {isLoading ? (
                    <CircularProgress size={24} color="inherit" />
                  ) : (
                    t.auth.verifyOTP
                  )}
                </Button>
              </form>

              {/* Resend Code Link */}
              <Box textAlign="center" mt={2}>
                <Button
                  variant="text"
                  size="small"
                  onClick={() => navigate('/auth/forgot-password')}
                  disabled={isLoading}
                >
                  {t.auth.forgotPasswordPage.didntReceiveCode}
                </Button>
              </Box>
            </>
          ) : (
            <>
              <Typography variant="body1" color="text.secondary" sx={{ mb: 3 }}>
                {t.auth.resetPasswordPage.setNewPassword}
              </Typography>

              {/* Error Alert */}
              {error && (
                <Alert severity="error" sx={{ mb: 2 }}>
                  {error}
                </Alert>
              )}

              <form onSubmit={handlePasswordSubmit}>
                {/* New Password Field */}
                <TextField
                  fullWidth
                  label={t.auth.resetPasswordPage.newPassword}
                  type={showPassword ? 'text' : 'password'}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  onKeyPress={(e) => handleKeyPress(e, 1)}
                  sx={{ mb: 2 }}
                  autoComplete="new-password"
                  disabled={isLoading}
                  autoFocus
                  helperText={t.auth.signInPage.atLeast6Characters}
                  InputProps={{
                    endAdornment: (
                      <InputAdornment position="end">
                        <IconButton
                          onClick={() => setShowPassword(!showPassword)}
                          edge="end"
                          size="small"
                        >
                          {showPassword ? <VisibilityOff /> : <Visibility />}
                        </IconButton>
                      </InputAdornment>
                    ),
                  }}
                />

                {/* Confirm Password Field */}
                <TextField
                  fullWidth
                  label={t.auth.resetPasswordPage.confirmNewPassword}
                  type={showConfirmPassword ? 'text' : 'password'}
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                  onKeyPress={(e) => handleKeyPress(e, 1)}
                  sx={{ mb: 3 }}
                  autoComplete="new-password"
                  disabled={isLoading}
                  error={confirmPassword && password !== confirmPassword}
                  helperText={confirmPassword && password !== confirmPassword ? t.auth.signInPage.passwordsDoNotMatch : ''}
                  InputProps={{
                    endAdornment: (
                      <InputAdornment position="end">
                        <IconButton
                          onClick={() => setShowConfirmPassword(!showConfirmPassword)}
                          edge="end"
                          size="small"
                        >
                          {showConfirmPassword ? <VisibilityOff /> : <Visibility />}
                        </IconButton>
                      </InputAdornment>
                    ),
                  }}
                />

                {/* Submit Button */}
                <Button
                  fullWidth
                  type="submit"
                  variant="contained"
                  size="large"
                  disabled={isLoading}
                  sx={{ py: 1.5 }}
                >
                  {isLoading ? (
                    <CircularProgress size={24} color="inherit" />
                  ) : (
                    t.auth.resetPassword
                  )}
                </Button>
              </form>

              {/* Back to Code Entry */}
              <Box textAlign="center" mt={2}>
                <Button
                  variant="text"
                  size="small"
                  onClick={() => {
                    setActiveStep(0);
                    setCodeVerified(false);
                    setPassword('');
                    setConfirmPassword('');
                  }}
                  disabled={isLoading}
                >
                  {t.common.back}
                </Button>
              </Box>
            </>
          )}
        </CardContent>
      </Card>
    </Container>
  );
};

export default ResetPassword;
