//
//  BrowserService.swift
//  Komal - Protected Browser Management
//
//  Manages WKWebView with content filtering
//

import Foundation
import WebKit

class BrowserService: NSObject {
    static let shared = BrowserService()

    private var webView: WKWebView?
    private let filterService = ContentFilterService.shared
    private let notificationCenter = NotificationCenter.default

    var onContentBlocked: ((FilterDecision) -> Void)?
    var onContentGated: ((FilterDecision, @escaping (Bool) -> Void) -> Void)?

    private override init() {
        super.init()
    }

    // MARK: - WebView Setup
    func createProtectedWebView(frame: CGRect) -> WKWebView {
        let config = WKWebViewConfiguration()

        // Content rules
        config.preferences.javaScriptEnabled = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = false

        // Create web view
        let webView = WKWebView(frame: frame, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self

        self.webView = webView
        return webView
    }

    // MARK: - Navigation
    func navigate(to urlString: String) {
        guard let url = URL(string: urlString) else { return }

        // Check filter before loading
        filterService.shouldAllowURL(urlString) { [weak self] decision in
            guard let self = self else { return }

            switch decision.action {
            case .allow:
                self.webView?.load(URLRequest(url: url))

            case .gate:
                // Ask parent for approval
                self.onContentGated?(decision) { approved in
                    if approved {
                        self.webView?.load(URLRequest(url: url))
                    } else {
                        self.showBlockPage(decision: decision)
                    }
                }

            case .block:
                self.showBlockPage(decision: decision)
                self.onContentBlocked?(decision)
            }
        }
    }

    private func showBlockPage(decision: FilterDecision) {
        let html = generateBlockPageHTML(decision: decision)
        webView?.loadHTMLString(html, baseURL: nil)
    }

    private func generateBlockPageHTML(decision: FilterDecision) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    min-height: 100vh;
                    margin: 0;
                    padding: 20px;
                    box-sizing: border-box;
                }
                .container {
                    background: rgba(255, 255, 255, 0.95);
                    border-radius: 20px;
                    padding: 40px;
                    max-width: 500px;
                    text-align: center;
                    box-shadow: 0 20px 60px rgba(0,0,0,0.3);
                    color: #333;
                }
                .icon {
                    font-size: 64px;
                    margin-bottom: 20px;
                }
                h1 {
                    color: #764ba2;
                    margin: 0 0 10px 0;
                    font-size: 28px;
                }
                .category {
                    display: inline-block;
                    background: #f0f0f0;
                    padding: 8px 16px;
                    border-radius: 20px;
                    font-size: 14px;
                    color: #666;
                    margin: 10px 0 20px 0;
                }
                p {
                    color: #666;
                    line-height: 1.6;
                    margin: 15px 0;
                }
                .back-button {
                    display: inline-block;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    padding: 12px 30px;
                    border-radius: 25px;
                    text-decoration: none;
                    margin-top: 20px;
                    font-weight: 600;
                    box-shadow: 0 4px 15px rgba(0,0,0,0.2);
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="icon">🛡️</div>
                <h1>Content Blocked</h1>
                <div class="category">\(decision.category.displayName)</div>
                <p><strong>This content has been blocked to keep you safe.</strong></p>
                <p>\(decision.reason ?? "This content may not be appropriate for your age.")</p>
                <p style="font-size: 14px; color: #999; margin-top: 30px;">
                    If you think this is a mistake, ask your parent or guardian to adjust the settings.
                </p>
                <a href="#" onclick="history.back(); return false;" class="back-button">← Go Back</a>
            </div>
        </body>
        </html>
        """
    }

    // MARK: - Monitoring
    func injectContentMonitor() {
        let script = """
        // Monitor for dynamic content changes
        const observer = new MutationObserver((mutations) => {
            // Check for risky content added dynamically
            for (const mutation of mutations) {
                if (mutation.addedNodes.length > 0) {
                    window.webkit.messageHandlers.contentChanged.postMessage({
                        type: 'contentAdded',
                        html: mutation.addedNodes[0].outerHTML || ''
                    });
                }
            }
        });

        observer.observe(document.body, {
            childList: true,
            subtree: true
        });
        """

        let userScript = WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        webView?.configuration.userContentController.addUserScript(userScript)
    }
}

// MARK: - WKNavigationDelegate
extension BrowserService: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url?.absoluteString else {
            decisionHandler(.cancel)
            return
        }

        // Check filter
        filterService.shouldAllowURL(url) { decision in
            switch decision.action {
            case .allow:
                decisionHandler(.allow)

            case .gate:
                self.onContentGated?(decision) { approved in
                    decisionHandler(approved ? .allow : .cancel)
                }

            case .block:
                decisionHandler(.cancel)
                self.showBlockPage(decision: decision)
                self.onContentBlocked?(decision)
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Inject monitoring script
        injectContentMonitor()
    }
}

// MARK: - WKUIDelegate
extension BrowserService: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        // Block pop-ups by default
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
}
