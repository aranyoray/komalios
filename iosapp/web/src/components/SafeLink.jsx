/**
 * SafeLink.jsx
 * Content-filtered link component
 *
 * Automatically checks URLs before opening them
 */

import React, { useState } from 'react';
import { Dialog, DialogTitle, DialogContent, DialogActions, Button, Typography } from '@mui/material';
import { Shield as ShieldIcon } from '@mui/icons-material';
import contentFilterService from '../services/ContentFilterService';

const SafeLink = ({ href, children, className, style, target = '_blank', ...props }) => {
  const [blocked, setBlocked] = useState(false);
  const [blockReason, setBlockReason] = useState('');
  const [blockCategory, setBlockCategory] = useState('');

  const handleClick = async (e) => {
    e.preventDefault();

    // Check if content filtering is available
    if (!contentFilterService.isAvailable) {
      // No filtering available, open link normally
      if (target === '_blank') {
        window.open(href, '_blank', 'noopener,noreferrer');
      } else {
        window.location.href = href;
      }
      return;
    }

    // Check URL with content filter
    const result = await contentFilterService.checkURL(href);

    if (result.shouldAllow) {
      // URL is safe, open it
      if (target === '_blank') {
        window.open(href, '_blank', 'noopener,noreferrer');
      } else {
        window.location.href = href;
      }
    } else {
      // URL is blocked, show modal
      setBlockReason(result.reason || 'This content may not be appropriate.');
      setBlockCategory(result.category || 'unknown');
      setBlocked(true);
    }
  };

  const handleCloseBlockDialog = () => {
    setBlocked(false);
  };

  return (
    <>
      <a
        href={href}
        onClick={handleClick}
        className={className}
        style={style}
        {...props}
      >
        {children}
      </a>

      <Dialog open={blocked} onClose={handleCloseBlockDialog} maxWidth="sm" fullWidth>
        <DialogTitle sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
          <ShieldIcon color="error" />
          Content Blocked
        </DialogTitle>
        <DialogContent>
          <Typography variant="body1" gutterBottom>
            {blockReason}
          </Typography>
          <Typography variant="caption" color="text.secondary" sx={{ mt: 2, display: 'block' }}>
            Category: {blockCategory}
          </Typography>
          <Typography variant="caption" color="text.secondary" sx={{ mt: 1, display: 'block' }}>
            If you think this is a mistake, ask your parent or guardian to adjust the settings.
          </Typography>
        </DialogContent>
        <DialogActions>
          <Button onClick={handleCloseBlockDialog} variant="contained">
            Go Back
          </Button>
        </DialogActions>
      </Dialog>
    </>
  );
};

export default SafeLink;
