import React from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { BottomNavigation, BottomNavigationAction, Paper } from '@mui/material';
import { Home, School, PlayArrow, Assessment } from '@mui/icons-material';

const NavigationBar = () => {
  const navigate = useNavigate();
  const location = useLocation();
  
  const getValueFromPath = (pathname) => {
    switch(pathname) {
      case '/': return 0;
      case '/learn': return 1;
      case '/practice': return 2;
      case '/progress': return 3;
      default: return 0;
    }
  };

  const handleChange = (event, newValue) => {
    const paths = ['/', '/learn', '/practice', '/progress'];
    navigate(paths[newValue]);
  };

  return (
    <Paper sx={{ position: 'fixed', bottom: 0, left: 0, right: 0 }} elevation={3}>
      <BottomNavigation
        value={getValueFromPath(location.pathname)}
        onChange={handleChange}
        showLabels
      >
        <BottomNavigationAction label="Home" icon={<Home />} />
        <BottomNavigationAction label="Learn" icon={<School />} />
        <BottomNavigationAction label="Practice" icon={<PlayArrow />} />
        <BottomNavigationAction label="Progress" icon={<Assessment />} />
      </BottomNavigation>
    </Paper>
  );
};

export default NavigationBar;
