/**
 * Email Confirmation Page
 * Handles email confirmation via deep link or web URL
 */

import React, { useEffect, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import {
  Container,
  Box,
  Typography,
  CircularProgress,
  Alert,
  Button,
  Card,
  CardContent
} from '@mui/material';
import { CheckCircle, Error as ErrorIcon } from '@mui/icons-material';
import { supabase } from '../../services/supabase';
import { useAuth } from '../../contexts/AuthContext';
import { useLanguage } from '../../i18n/LanguageContext';

const EmailConfirm = () => {
  const { t } = useLanguage();
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const { checkSession } = useAuth();
  const [status, setStatus] = useState('verifying'); // 'verifying', 'success', 'error'
  const [message, setMessage] = useState(t.auth.emailConfirmPage.verifyingYourEmail);
  const [error, setError] = useState('');

  useEffect(() => {
    const verifyEmail = async () => {
      try {
        // Supabase email confirmation links contain hash fragments (#access_token=...&type=...)
        // Check URL hash for Supabase auth tokens
        const hashParams = new URLSearchParams(window.location.hash.substring(1));
        const accessToken = hashParams.get('access_token');
        const refreshToken = hashParams.get('refresh_token');
        const type = hashParams.get('type') || searchParams.get('type') || 'signup';
        
        // Also check query parameters (for deep links)
        const token = searchParams.get('token');
        const tokenHash = searchParams.get('token_hash');

        console.log('[EmailConfirm] Verification params:', { 
          accessToken: !!accessToken, 
          refreshToken: !!refreshToken,
          token, 
          tokenHash,
          type 
        });

        // If we have access token in hash, Supabase has already confirmed the email
        if (accessToken) {
          // Set the session using the tokens from the hash
          const { data: sessionData, error: sessionError } = await supabase.auth.setSession({
            access_token: accessToken,
            refresh_token: refreshToken || ''
          });

          if (sessionError) {
            throw sessionError;
          }

          if (sessionData?.session?.user?.email_confirmed_at) {
            console.log('[EmailConfirm] Email confirmed via hash tokens');
            setStatus('success');
            setMessage(t.auth.emailConfirmPage.emailConfirmedSuccess);
            
            // Refresh session to get updated user data (if checkSession is available)
            if (checkSession && typeof checkSession === 'function') {
              await checkSession();
            }

            // Redirect to sign in after 2 seconds
            setTimeout(() => {
              navigate('/signin');
            }, 2000);
            return;
          }
        }

        // If we have token_hash, verify using OTP
        if (tokenHash || token) {
          const { data, error: verifyError } = await supabase.auth.verifyOtp({
            token_hash: tokenHash || token,
            type: type === 'recovery' ? 'recovery' : 'signup'
          });

          if (verifyError) {
            console.error('[EmailConfirm] Verification error:', verifyError);
            
            // Check if email is already confirmed
            if (verifyError.message.includes('already confirmed') || 
                verifyError.message.includes('already verified')) {
              setStatus('success');
              setMessage(t.auth.emailConfirmPage.emailAlreadyConfirmed);
              setTimeout(() => navigate('/signin'), 3000);
              return;
            }

            // Check if token is expired
            if (verifyError.message.includes('expired') || verifyError.message.includes('invalid')) {
              setStatus('error');
              setError(t.auth.emailConfirmPage.linkExpired);
              return;
            }

            throw verifyError;
          }

          // Success - email confirmed
          console.log('[EmailConfirm] Email confirmed via OTP:', data);
          setStatus('success');
          setMessage(t.auth.emailConfirmPage.emailConfirmedSuccess);

          // Refresh session to get updated user data (if checkSession is available)
          if (checkSession && typeof checkSession === 'function') {
            await checkSession();
          }

          // Redirect to sign in after 2 seconds
          setTimeout(() => {
            navigate('/signin');
          }, 2000);
          return;
        }

        // Check if user is already confirmed (might have been confirmed via another method)
        const { data: { session } } = await supabase.auth.getSession();
        if (session?.user?.email_confirmed_at) {
          setStatus('success');
          setMessage(t.auth.emailConfirmPage.emailAlreadyConfirmed);
          setTimeout(() => navigate('/signin'), 3000);
          return;
        }

        // No tokens found
        setStatus('error');
        setError(t.auth.emailConfirmPage.missingToken);

      } catch (err) {
        console.error('[EmailConfirm] Error:', err);
        setStatus('error');
        setError(err.message || t.auth.emailConfirmPage.failedToVerify);
      }
    };

    verifyEmail();
  }, [searchParams, navigate, checkSession]);

  return (
    <Container maxWidth="sm" sx={{ py: 8, minHeight: '100vh', display: 'flex', alignItems: 'center' }}>
      <Card elevation={3} sx={{ width: '100%' }}>
        <CardContent sx={{ p: 4, textAlign: 'center' }}>
          {status === 'verifying' && (
            <>
              <CircularProgress size={48} sx={{ mb: 3 }} />
              <Typography variant="h5" gutterBottom>
                {t.auth.emailConfirmPage.verifyingEmail}
              </Typography>
              <Typography variant="body1" color="text.secondary">
                {message}
              </Typography>
            </>
          )}

          {status === 'success' && (
            <>
              <CheckCircle sx={{ fontSize: 64, color: 'success.main', mb: 2 }} />
              <Typography variant="h5" gutterBottom color="success.main">
                {t.auth.emailConfirmPage.emailConfirmed}
              </Typography>
              <Typography variant="body1" color="text.secondary" sx={{ mb: 3 }}>
                {message}
              </Typography>
              <Typography variant="body2" color="text.secondary">
                {t.auth.emailConfirmPage.redirectingToSignIn}
              </Typography>
            </>
          )}

          {status === 'error' && (
            <>
              <ErrorIcon sx={{ fontSize: 64, color: 'error.main', mb: 2 }} />
              <Typography variant="h5" gutterBottom color="error.main">
                {t.auth.emailConfirmPage.verificationFailed}
              </Typography>
              <Alert severity="error" sx={{ mb: 3, textAlign: 'left' }}>
                {error}
              </Alert>
              <Button
                variant="contained"
                onClick={() => navigate('/signin')}
                sx={{ mr: 2 }}
              >
                {t.auth.emailConfirmPage.goToSignIn}
              </Button>
              <Button
                variant="outlined"
                onClick={() => navigate('/')}
              >
                {t.auth.emailConfirmPage.goHome}
              </Button>
            </>
          )}
        </CardContent>
      </Card>
    </Container>
  );
};

export default EmailConfirm;

