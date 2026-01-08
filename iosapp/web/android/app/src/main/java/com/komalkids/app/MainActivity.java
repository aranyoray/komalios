package com.komalkids.app;

import android.os.Bundle;
import android.view.Window;
import android.webkit.WebSettings;
import android.webkit.WebView;
import androidx.core.splashscreen.SplashScreen;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsControllerCompat;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        // Android 12+ splash screen API (controls the launch splash theme -> post-splash theme)
        SplashScreen splashScreen = SplashScreen.installSplashScreen(this);

        super.onCreate(savedInstanceState);

        // Explicitly hide any action bar/toolbar that might show app name
        // This ensures no toolbar appears above the WebView content
        if (getSupportActionBar() != null) {
            getSupportActionBar().hide();
        }

        Window window = getWindow();

        // Edge-to-edge without androidx.activity.EdgeToEdge.enable():
        // - Avoids deprecated cutout mode handling paths on Android 15
        // - Capacitor's adjustMarginsForEdgeToEdge handles WebView insets automatically
        WindowCompat.setDecorFitsSystemWindows(window, false);
        
        // Configure status bar appearance using modern WindowInsetsControllerCompat API
        // This is NOT deprecated - only Window.setStatusBarColor() is deprecated
        WindowInsetsControllerCompat windowInsetsController = WindowCompat.getInsetsController(window, window.getDecorView());
        if (windowInsetsController != null) {
            // Use light status bar icons (dark icons) for better visibility on white backgrounds
            windowInsetsController.setAppearanceLightStatusBars(true);
            windowInsetsController.setAppearanceLightNavigationBars(true);
        }

        // Edge-to-edge is handled by:
        // 1. WindowCompat.setDecorFitsSystemWindows(false) above
        // 2. Capacitor's adjustMarginsForEdgeToEdge: 'auto'
        // 3. Theme styles (transparent bars, no action bar)

        // Configure WebView settings for better media support
        WebView webView = getBridge().getWebView();
        if (webView != null) {
            WebSettings webSettings = webView.getSettings();

            // Enable JavaScript (should already be enabled by Capacitor)
            webSettings.setJavaScriptEnabled(true);

            // Enable DOM storage
            webSettings.setDomStorageEnabled(true);

            // Enable media playback without user gesture (autoplay)
            webSettings.setMediaPlaybackRequiresUserGesture(false);

            // Allow mixed content (if needed)
            webSettings.setMixedContentMode(WebSettings.MIXED_CONTENT_ALWAYS_ALLOW);
        }
    }
}

