import { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.komaltech.avatarcustomizer',
  appName: 'Avatar Customizer',
  webDir: 'dist',
  server: {
    androidScheme: 'https'
  },
  plugins: {
    SplashScreen: {
      launchShowDuration: 2000,
      backgroundColor: '#FF6B9D',
      showSpinner: false
    },
    StatusBar: {
      style: 'light',
      backgroundColor: '#FF6B9D'
    }
  }
};

export default config;

