/**
 * Forgot Password Page for Komal
 * Allows users to request a password reset email
 */

import React, { useState } from 'react';
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
  Link
} from '@mui/material';
import { ArrowBack } from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import { generatePasswordResetCode } from '../../auth/supabaseAuth';
import { useLanguage } from '../../i18n/LanguageContext';

const ForgotPassword = () => {
  const { t } = useLanguage();
  const [email, setEmail] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);
  const navigate = useNavigate();

  const validateEmail = (email) => {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setSuccess(false);

    if (!email) {
      setError(t.auth.forgotPasswordPage.enterEmailAddress);
      return;
    }

    if (!validateEmail(email)) {
      setError(t.auth.signInPage.enterValidEmail);
      return;
    }

    setIsLoading(true);

    try {
      await generatePasswordResetCode(email);
      setSuccess(true);
    } catch (err) {
      const errorMessage = err.message || t.auth.forgotPasswordPage.failedToSendCode;
      setError(errorMessage);
    } finally {
      setIsLoading(false);
    }
  };

  const handleKeyPress = (e) => {
    if (e.key === 'Enter') {
      handleSubmit(e);
    }
  };

  return (
    <Container maxWidth="sm" sx={{ py: 4, minHeight: '100vh', display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
      <Box textAlign="center" mb={4}>
        <Typography variant="h3" fontWeight="bold" color="primary" gutterBottom>
          Komal
        </Typography>
        <Typography variant="subtitle1" color="text.secondary">
          {t.auth.forgotPasswordPage.subtitle}
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
            {t.auth.forgotPasswordPage.backToSignIn}
          </Button>

          {success ? (
            <>
              <Alert severity="success" sx={{ mb: 3 }}>
                <Typography variant="body1" fontWeight="medium" gutterBottom>
                  {t.auth.forgotPasswordPage.checkEmail}
                </Typography>
                <Typography variant="body2">
                  {t.auth.forgotPasswordPage.resetCodeSent.replace('{email}', email)}
                </Typography>
              </Alert>
              <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                {t.auth.forgotPasswordPage.didntReceiveCode}
              </Typography>
              <Button
                fullWidth
                variant="contained"
                onClick={() => navigate('/auth/reset-password', { state: { email } })}
                sx={{ mb: 2 }}
              >
                {t.auth.forgotPasswordPage.enterResetCode}
              </Button>
              <Button
                fullWidth
                variant="outlined"
                onClick={() => {
                  setSuccess(false);
                  setEmail('');
                }}
                sx={{ mb: 2 }}
              >
                {t.auth.forgotPasswordPage.tryAgain}
              </Button>
              <Button
                fullWidth
                variant="text"
                onClick={() => navigate('/signin')}
              >
                {t.auth.forgotPasswordPage.backToSignIn}
              </Button>
            </>
          ) : (
            <>
              <Typography variant="body1" color="text.secondary" sx={{ mb: 3 }}>
                {t.auth.forgotPasswordPage.enterEmailDescription}
              </Typography>

              {/* Error Alert */}
              {error && (
                <Alert severity="error" sx={{ mb: 2 }}>
                  {error}
                </Alert>
              )}

              <form onSubmit={handleSubmit}>
                {/* Email Field */}
                <TextField
                  fullWidth
                  label={t.auth.email}
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  onKeyPress={handleKeyPress}
                  sx={{ mb: 3 }}
                  autoComplete="email"
                  disabled={isLoading}
                  autoFocus
                />

                {/* Submit Button */}
                <Button
                  fullWidth
                  type="submit"
                  variant="contained"
                  size="large"
                  disabled={isLoading}
                  sx={{ py: 1.5, mb: 2 }}
                >
                  {isLoading ? (
                    <CircularProgress size={24} color="inherit" />
                  ) : (
                    t.auth.forgotPasswordPage.sendResetLink
                  )}
                </Button>
              </form>

              {/* Back to Sign In Link */}
              <Box textAlign="center">
                <Link
                  component="button"
                  variant="body2"
                  onClick={() => navigate('/signin')}
                  sx={{ cursor: 'pointer' }}
                >
                  {t.auth.forgotPasswordPage.rememberPassword}
                </Link>
              </Box>
            </>
          )}
        </CardContent>
      </Card>
    </Container>
  );
};

export default ForgotPassword;

