/**
 * ParentControlsButton.jsx
 * Button to access parent controls and dashboard
 */

import React, { useState, useEffect } from 'react';
import {
  IconButton,
  Menu,
  MenuItem,
  ListItemIcon,
  ListItemText,
  Badge,
  Divider,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogContentText,
  DialogActions,
  Button,
  Typography
} from '@mui/material';
import {
  Shield as ShieldIcon,
  Dashboard as DashboardIcon,
  Settings as SettingsIcon,
  School as SchoolIcon,
  Block as BlockIcon,
  FileDownload as DownloadIcon
} from '@mui/icons-material';
import { useContentFilter } from '../hooks/useContentFilter';

const ParentControlsButton = () => {
  const {
    isAvailable,
    needsOnboarding,
    stats,
    showOnboarding,
    showDashboard,
    refreshStats
  } = useContentFilter();

  const [anchorEl, setAnchorEl] = useState(null);
  const [onboardingDialog, setOnboardingDialog] = useState(false);

  // Refresh stats on mount and when menu opens
  useEffect(() => {
    if (isAvailable) {
      refreshStats();
    }
  }, [isAvailable, refreshStats]);

  // Show onboarding prompt if needed
  useEffect(() => {
    if (needsOnboarding) {
      setTimeout(() => {
        setOnboardingDialog(true);
      }, 2000); // Show after 2 seconds
    }
  }, [needsOnboarding]);

  const handleClick = (event) => {
    setAnchorEl(event.currentTarget);
    refreshStats(); // Refresh stats when opening menu
  };

  const handleClose = () => {
    setAnchorEl(null);
  };

  const handleShowDashboard = async () => {
    handleClose();
    await showDashboard();
  };

  const handleShowOnboarding = async () => {
    setOnboardingDialog(false);
    await showOnboarding();
  };

  const handleCloseOnboarding = () => {
    setOnboardingDialog(false);
  };

  // Don't show button if not available
  if (!isAvailable) {
    return null;
  }

  const blockedCount = stats?.blocked || 0;
  const open = Boolean(anchorEl);

  return (
    <>
      <IconButton
        color="inherit"
        onClick={handleClick}
        aria-label="Parent Controls"
        sx={{ ml: 1 }}
      >
        <Badge badgeContent={blockedCount} color="error" max={99}>
          <ShieldIcon />
        </Badge>
      </IconButton>

      <Menu
        anchorEl={anchorEl}
        open={open}
        onClose={handleClose}
        transformOrigin={{ horizontal: 'right', vertical: 'top' }}
        anchorOrigin={{ horizontal: 'right', vertical: 'bottom' }}
      >
        <MenuItem disabled>
          <ListItemText
            primary="Content Filtering"
            secondary="Active"
            primaryTypographyProps={{ variant: 'subtitle2', fontWeight: 600 }}
            secondaryTypographyProps={{ variant: 'caption', color: 'success.main' }}
          />
        </MenuItem>

        <Divider />

        {stats && (
          <>
            <MenuItem disabled>
              <ListItemText
                primary="Today's Activity"
                primaryTypographyProps={{ variant: 'caption', color: 'text.secondary' }}
              />
            </MenuItem>
            <MenuItem disabled sx={{ pl: 4 }}>
              <BlockIcon fontSize="small" color="error" sx={{ mr: 1 }} />
              <Typography variant="body2">
                {stats.blocked} Blocked
              </Typography>
            </MenuItem>
            <MenuItem disabled sx={{ pl: 4 }}>
              <ShieldIcon fontSize="small" color="warning" sx={{ mr: 1 }} />
              <Typography variant="body2">
                {stats.gated} Gated
              </Typography>
            </MenuItem>
            <MenuItem disabled sx={{ pl: 4 }}>
              <SchoolIcon fontSize="small" color="success" sx={{ mr: 1 }} />
              <Typography variant="body2">
                {stats.allowed} Allowed
              </Typography>
            </MenuItem>

            <Divider />
          </>
        )}

        <MenuItem onClick={handleShowDashboard}>
          <ListItemIcon>
            <DashboardIcon fontSize="small" />
          </ListItemIcon>
          <ListItemText>Parent Dashboard</ListItemText>
        </MenuItem>

        {needsOnboarding && (
          <MenuItem onClick={handleShowOnboarding}>
            <ListItemIcon>
              <SettingsIcon fontSize="small" />
            </ListItemIcon>
            <ListItemText>Complete Setup</ListItemText>
          </MenuItem>
        )}
      </Menu>

      {/* Onboarding Dialog */}
      <Dialog open={onboardingDialog} onClose={handleCloseOnboarding}>
        <DialogTitle>Welcome to Komal Content Filtering</DialogTitle>
        <DialogContent>
          <DialogContentText>
            To keep your child safe online, please complete the parent setup survey.
            This will help us understand your child's needs and configure age-appropriate content filtering.
          </DialogContentText>
          <DialogContentText sx={{ mt: 2 }}>
            The survey takes about 5-10 minutes to complete.
          </DialogContentText>
        </DialogContent>
        <DialogActions>
          <Button onClick={handleCloseOnboarding}>Later</Button>
          <Button onClick={handleShowOnboarding} variant="contained" autoFocus>
            Start Setup
          </Button>
        </DialogActions>
      </Dialog>
    </>
  );
};

export default ParentControlsButton;
