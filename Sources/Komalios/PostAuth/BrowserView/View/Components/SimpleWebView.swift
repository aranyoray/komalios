//
//  SimpleWebView.swift
//  Komalios
//
//  Created on 18/01/26.
//

import SwiftUI

#if canImport(WebKit)
import WebKit

struct SimpleWebView: UIViewRepresentable {
    let url: URL
    @Binding var loading: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.defaultWebpagePreferences.preferredContentMode = .mobile
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = false
        context.coordinator.targetURL = url
        webView.load(URLRequest(url: url))
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Only reload if URL actually changed
        let currentURLString = uiView.url?.absoluteString ?? ""
        let targetURLString = url.absoluteString
        
        // Check if URL changed and we're not already loading this URL
        if currentURLString != targetURLString && context.coordinator.targetURL?.absoluteString != targetURLString {
            context.coordinator.targetURL = url
            // Don't set isLoading here - let the navigation delegate handle it
            uiView.load(URLRequest(url: url))
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(loading: $loading)
    }
    
    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var loading: Bool
        var targetURL: URL? // Track the URL we're trying to load
        private var currentNavigation: WKNavigation? // Track current navigation to avoid duplicate callbacks
        
        init(loading: Binding<Bool>) {
            _loading = loading
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            // Only update loading if this is a new navigation
            if currentNavigation == nil || currentNavigation != navigation {
                currentNavigation = navigation
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    // Only set to true if not already loading (prevent flickering)
                    if !self.loading {
                        self.loading = true
                        print("🌐 WebView started loading")
                    }
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Only process if this is the navigation we're tracking
            guard currentNavigation == navigation else {
                print("⚠️ Ignoring didFinish for old navigation")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.currentNavigation = nil
                self.loading = false
                print("🌐 WebView finished loading - setting loading to false")
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            // Ignore cancelled errors (-999) as they're usually from navigation being cancelled
            if nsError.code == NSURLErrorCancelled {
                print("⚠️ Navigation cancelled (ignoring)")
                return
            }
            
            // Only process if this is the navigation we're tracking
            guard currentNavigation == navigation else {
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.currentNavigation = nil
                self.loading = false
                print("❌ WebView failed to load - setting loading to false: \(error.localizedDescription)")
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            // Ignore cancelled errors (-999) as they're usually from navigation being cancelled
            if nsError.code == NSURLErrorCancelled {
                print("⚠️ Provisional navigation cancelled (ignoring)")
                return
            }
            
            // Only process if this is the navigation we're tracking
            guard currentNavigation == navigation else {
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.currentNavigation = nil
                self.loading = false
                print("❌ WebView provisional navigation failed - setting loading to false: \(error.localizedDescription)")
            }
        }
    }
}
#endif
