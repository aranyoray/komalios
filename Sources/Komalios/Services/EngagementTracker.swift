//
//  EngagementTracker.swift
//  Komalios
//
//  Digital Guardian Enhancement - Manages engagement tracking and JS bridge
//

#if os(iOS)
import Foundation
import WebKit
import Combine

/// Manages engagement tracking via JavaScript injection in WebViews
@MainActor
final class EngagementTracker: ObservableObject {
    static let shared = EngagementTracker()
    
    // MARK: - Published Properties
    @Published private(set) var currentEngagement: PageEngagement?
    @Published private(set) var engagementHistory: [PageEngagement] = []
    
    // MARK: - Private Properties
    private var engagementScript: String?
    private var imageScannerScript: String?
    private var viewportTrackerScript: String?
    private var navigationDepth = 0
    private var lastURL: URL?
    
    // MARK: - Initialization
    
    private init() {
        loadScripts()
    }
    
    // MARK: - Script Loading
    
    private func loadScripts() {
        // Load engagement tracker script
        if let engagementURL = Bundle.main.url(forResource: "engagement_tracker", withExtension: "js"),
           let script = try? String(contentsOf: engagementURL) {
            engagementScript = script
            print("📊 EngagementTracker: Loaded engagement_tracker.js")
        } else {
            // Fallback to embedded script
            engagementScript = createEmbeddedEngagementScript()
            print("📊 EngagementTracker: Using embedded engagement script")
        }
        
        let trustedJSON = Constants.trustedDomainRootsJSON

        // Load image scanner script
        if let imageScannerURL = Bundle.main.url(forResource: "image_scanner", withExtension: "js"),
           var script = try? String(contentsOf: imageScannerURL) {
            // Inject Komal logo
            if let logoBase64 = ImageFilterService.shared.getKomalLogoBase64() {
                script = script.replacingOccurrences(of: "KOMAL_LOGO_BASE64", with: logoBase64)
            }
            // Inject canonical trusted domain list from Constants.swift
            script = script.replacingOccurrences(of: "TRUSTED_DOMAINS_PLACEHOLDER", with: trustedJSON)
            imageScannerScript = script
            print("📊 EngagementTracker: Loaded image_scanner.js")
        } else {
            // Fallback to embedded script
            imageScannerScript = createEmbeddedImageScannerScript()
            print("📊 EngagementTracker: Using embedded image scanner script")
        }

        // Load viewport tracker script
        if let viewportURL = Bundle.main.url(forResource: "viewport_tracker", withExtension: "js"),
           var script = try? String(contentsOf: viewportURL) {
            // Inject canonical trusted domain list from Constants.swift
            script = script.replacingOccurrences(of: "TRUSTED_DOMAINS_PLACEHOLDER", with: trustedJSON)
            viewportTrackerScript = script
            print("📊 EngagementTracker: Loaded viewport_tracker.js")
        } else {
            // Fallback to embedded script
            viewportTrackerScript = createEmbeddedViewportTrackerScript()
            print("📊 EngagementTracker: Using embedded viewport tracker script")
        }
    }
    
    // MARK: - Public API
    
    /// Get user scripts to inject into WKWebView
    func getUserScripts() -> [WKUserScript] {
        #if DEBUG
        print("🔎 SCRIPT-DEBUG: engagementScript=\(engagementScript != nil ? "loaded" : "nil") imageScannerScript=\(imageScannerScript != nil ? "loaded(\(imageScannerScript!.count) chars)" : "nil") viewportTracker=\(viewportTrackerScript != nil ? "loaded" : "nil")")
        if let ims = imageScannerScript {
            let hasTrusted = ims.contains("google.com")
            print("🔎 SCRIPT-DEBUG: imageScannerScript contains 'google.com'=\(hasTrusted) (should be true if file-loaded, false if embedded fallback)")
        }
        #endif
        var scripts: [WKUserScript] = []

        // CRITICAL: Inject pre-hide CSS at DOCUMENT START so images are hidden
        // BEFORE they render. The image scanner JS (at document end) will reveal
        // safe images and replace unsafe ones. Without this, images flash visible
        // during the entire page load before the scanner runs.
        let trustedJSON = Constants.trustedDomainRootsJSON
        let preHideCSS = """
        (function() {
            var host = (window.location.hostname || '').toLowerCase();
            var trusted = \(trustedJSON);
            if (trusted.some(function(d) { return host === d || host === 'www.' + d || host.endsWith('.' + d); })) return;
            var s = document.createElement('style');
            s.id = 'komal-prehide';
            s.textContent = 'img:not([data-komal-safe]):not([data-komal-replaced]) { opacity: 0 !important; pointer-events: none !important; } video:not([data-komal-safe]):not([data-komal-replaced]) { opacity: 0 !important; pointer-events: none !important; }';
            (document.head || document.documentElement).appendChild(s);
        })();
        """
        scripts.append(WKUserScript(
            source: preHideCSS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true  // Must match image scanner's scope (also mainFrame-only)
        ))

        if let engagementScript = engagementScript {
            let script = WKUserScript(
                source: engagementScript,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
            scripts.append(script)
        }

        if let imageScannerScript = imageScannerScript {
            let script = WKUserScript(
                source: imageScannerScript,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
            scripts.append(script)
        }

        if let viewportTrackerScript = viewportTrackerScript {
            let script = WKUserScript(
                source: viewportTrackerScript,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
            scripts.append(script)
        }

        return scripts
    }
    
    /// Configure message handlers for a WKUserContentController
    func configureMessageHandlers(
        for controller: WKUserContentController,
        handler: WKScriptMessageHandler
    ) {
        // Remove existing handlers first (in case of reconfiguration)
        controller.removeScriptMessageHandler(forName: "komalEngagement")
        controller.removeScriptMessageHandler(forName: "komalImageScanner")
        controller.removeScriptMessageHandler(forName: "komalViewport")
        
        // Add our handlers
        controller.add(handler, name: "komalEngagement")
        controller.add(handler, name: "komalImageScanner")
        controller.add(handler, name: "komalViewport")
        
        // Add user scripts
        for script in getUserScripts() {
            controller.addUserScript(script)
        }
    }
    
    /// Start tracking engagement for a new page
    func startEngagement(
        url: URL,
        pageTitle: String? = nil,
        wasBackNavigation: Bool = false,
        wasForwardNavigation: Bool = false
    ) {
        // End previous engagement
        endCurrentEngagement(exitURL: url)
        
        // Update navigation depth
        if wasBackNavigation {
            navigationDepth = max(0, navigationDepth - 1)
        } else if !wasForwardNavigation {
            navigationDepth += 1
        }
        
        // Create new engagement
        currentEngagement = PageEngagement(
            url: url,
            pageTitle: pageTitle,
            referrerURL: lastURL,
            navigationDepth: navigationDepth,
            wasBackNavigation: wasBackNavigation,
            wasForwardNavigation: wasForwardNavigation
        )
        
        lastURL = url
        
        print("📊 Started engagement tracking for: \(url.host ?? url.absoluteString)")
    }
    
    /// Update engagement with scroll data from JavaScript
    func updateEngagement(scrollDepth: Int, scrollEvents: Int) {
        guard currentEngagement != nil else { return }

        currentEngagement?.updateScroll(depthPercent: scrollDepth, eventCount: scrollEvents)

        print("📊 Engagement update - Scroll: \(scrollDepth)%, Events: \(scrollEvents)")
    }
    
    /// Record a filtered image
    func recordFilteredImage(category: String) {
        currentEngagement?.recordFilteredImage(category: category)
    }
    
    /// Record scanned images
    func recordScannedImages(count: Int) {
        currentEngagement?.recordScannedImages(count: count)
    }
    
    /// End current engagement and save to history
    func endCurrentEngagement(exitURL: URL? = nil) {
        guard var engagement = currentEngagement else { return }
        
        engagement.end(exitURL: exitURL)
        
        // Only save meaningful engagements (more than 1 second)
        if engagement.dwellTime >= 1 {
            engagementHistory.insert(engagement, at: 0)
            
            // Keep only last 100 engagements
            if engagementHistory.count > 100 {
                engagementHistory = Array(engagementHistory.prefix(100))
            }
            
            print("📊 Ended engagement: \(engagement.domain) - \(engagement.dwellTimeFormatted), \(engagement.scrollDepthPercent)% scroll")
        }
        
        currentEngagement = nil
    }
    
    /// Get current engagement or create one for URL
    func getOrCreateEngagement(for url: URL) -> PageEngagement {
        if let current = currentEngagement, current.url == url {
            return current
        }

        startEngagement(url: url)
        return currentEngagement ?? PageEngagement(url: url)
    }
    
    /// Reset tracking for new session
    func resetSession() {
        endCurrentEngagement()
        navigationDepth = 0
        lastURL = nil
    }
    
    /// Get engagement insights
    func getEngagementInsights() -> EngagementInsights {
        let engagements = engagementHistory
        
        guard !engagements.isEmpty else {
            return .empty
        }
        
        // Calculate domain engagement
        let domainGroups = Dictionary(grouping: engagements, by: { $0.domain })
        let domainEngagements = domainGroups.map { domain, engagements in
            DomainEngagement(
                domain: domain,
                avgDwellTimeSeconds: engagements.averageDwellTime,
                visitCount: engagements.count,
                avgScrollDepth: engagements.averageScrollDepth,
                imagesFiltered: engagements.totalImagesFiltered
            )
        }
        .sorted { $0.avgDwellTimeSeconds > $1.avgDwellTimeSeconds }
        .prefix(10)
        .map { $0 }
        
        // Calculate navigation patterns
        let totalNavigations = engagements.count
        let backNavs = engagements.filter { $0.wasBackNavigation }.count
        let forwardNavs = engagements.filter { $0.wasForwardNavigation }.count
        let rapidSwitching = engagements.filter { $0.dwellTime < 10 && $0.endTime != nil }.count
        
        let patterns = NavigationPatterns(
            averageSessionDepth: engagements.map { $0.navigationDepth }.max() ?? 0,
            backNavigationRate: totalNavigations > 0 ? Double(backNavs) / Double(totalNavigations) : 0,
            forwardNavigationRate: totalNavigations > 0 ? Double(forwardNavs) / Double(totalNavigations) : 0,
            rapidSwitchingCount: rapidSwitching,
            averageNavigationsPerSession: Double(totalNavigations)
        )
        
        // Calculate meaningful engagement rate
        let meaningfulCount = engagements.filter { $0.hadMeaningfulEngagement }.count
        let meaningfulRate = totalNavigations > 0 ? Double(meaningfulCount) / Double(totalNavigations) : 0
        
        return EngagementInsights(
            averageDwellTimeSeconds: engagements.averageDwellTime,
            averageScrollDepthPercent: engagements.averageScrollDepth,
            totalImagesScanned: engagements.totalImagesScanned,
            totalImagesFiltered: engagements.totalImagesFiltered,
            filteredByCategory: [:], // Will be populated from image filter events
            mostEngagedDomains: domainEngagements,
            navigationPatterns: patterns,
            totalPageViews: totalNavigations,
            meaningfulEngagementRate: meaningfulRate
        )
    }
    
    // MARK: - Embedded Script Fallbacks
    
    private func createEmbeddedEngagementScript() -> String {
        return """
        (function() {
            'use strict';
            if (window.komalTracker) return;
            
            const komalTracker = {
                startTime: Date.now(),
                maxScrollDepth: 0,
                scrollEvents: 0,
                
                trackScroll: function() {
                    const scrollTop = window.scrollY || window.pageYOffset;
                    const docHeight = Math.max(document.body.scrollHeight, document.documentElement.scrollHeight) - window.innerHeight;
                    const scrollPercent = docHeight > 0 ? Math.round((scrollTop / docHeight) * 100) : 100;
                    this.maxScrollDepth = Math.max(this.maxScrollDepth, Math.min(scrollPercent, 100));
                    this.scrollEvents++;
                },
                
                getEngagement: function() {
                    return {
                        dwellTimeMs: Date.now() - this.startTime,
                        scrollDepthPercent: this.maxScrollDepth,
                        scrollEvents: this.scrollEvents,
                        pageTitle: document.title || '',
                        url: window.location.href
                    };
                },
                
                sendEngagement: function() {
                    try {
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.komalEngagement) {
                            window.webkit.messageHandlers.komalEngagement.postMessage(this.getEngagement());
                        }
                    } catch (e) {}
                }
            };
            
            window.addEventListener('scroll', function() { komalTracker.trackScroll(); }, { passive: true });
            setInterval(function() { komalTracker.sendEngagement(); }, 10000);
            window.addEventListener('beforeunload', function() { komalTracker.sendEngagement(); });
            
            window.komalTracker = komalTracker;
        })();
        """
    }
    
    private func createEmbeddedImageScannerScript() -> String {
        let logoBase64 = ImageFilterService.shared.getKomalLogoBase64() ?? ""
        
        return """
        (function() {
            'use strict';
            if (window.komalImageScanner) return;
            
            const KOMAL_LOGO = '\(logoBase64)';
            
            const komalImageScanner = {
                scannedCount: 0,
                filteredCount: 0,
                
                scanImages: function() {
                    const images = document.querySelectorAll('img:not([data-komal-scanned])');
                    const imageData = [];
                    const self = this;
                    
                    images.forEach(function(img) {
                        if (img.naturalWidth < 50 || img.naturalHeight < 50) return;
                        
                        img.setAttribute('data-komal-scanned', 'true');
                        const imageId = 'komal_img_' + self.scannedCount++;
                        img.setAttribute('data-komal-id', imageId);
                        
                        imageData.push({
                            id: imageId,
                            src: img.src,
                            width: img.naturalWidth,
                            height: img.naturalHeight
                        });
                    });
                    
                    return imageData;
                },
                
                replaceImage: function(imageId) {
                    const img = document.querySelector('[data-komal-id="' + imageId + '"]');
                    if (img && KOMAL_LOGO) {
                        img.setAttribute('data-komal-original', img.src);
                        img.src = KOMAL_LOGO;
                        img.style.objectFit = 'contain';
                        img.style.backgroundColor = '#FFF5F8';
                        this.filteredCount++;
                    }
                },
                
                sendForAnalysis: function(imageData) {
                    try {
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.komalImageScanner) {
                            window.webkit.messageHandlers.komalImageScanner.postMessage({
                                type: 'scan',
                                images: imageData,
                                pageUrl: window.location.href
                            });
                        }
                    } catch (e) {}
                }
            };
            
            window.addEventListener('load', function() {
                setTimeout(function() {
                    const images = komalImageScanner.scanImages();
                    if (images.length > 0) komalImageScanner.sendForAnalysis(images);
                }, 500);
            });
            
            window.komalImageScanner = komalImageScanner;
        })();
        """
    }
    
    private func createEmbeddedViewportTrackerScript() -> String {
        return """
        (function() {
            'use strict';
            if (window.komalViewportTracker) return;
            
            const komalViewportTracker = {
                lastSnapshotTime: 0,
                snapshotInterval: 2000,
                
                isInViewport: function(element) {
                    const rect = element.getBoundingClientRect();
                    return rect.top < window.innerHeight && rect.bottom > 0;
                },
                
                getVisibleContent: function() {
                    const content = [];
                    const elements = document.querySelectorAll('h1,h2,h3,h4,p,article,img,video');
                    
                    elements.forEach(function(el) {
                        if (!komalViewportTracker.isInViewport(el)) return;
                        
                        const tag = el.tagName.toLowerCase();
                        let type = 'unknown';
                        if (/^h[1-6]$/.test(tag)) type = 'heading';
                        else if (tag === 'p' || tag === 'article') type = 'paragraph';
                        else if (tag === 'img') type = 'image';
                        else if (tag === 'video') type = 'video';
                        
                        let text = el.textContent ? el.textContent.trim().substring(0, 200) : null;
                        
                        content.push({
                            contentType: type,
                            text: text,
                            elementTag: tag,
                            wordCount: text ? text.split(/\\s+/).length : 0
                        });
                    });
                    
                    return content;
                },
                
                createSnapshot: function() {
                    const content = this.getVisibleContent();
                    const headings = content.filter(c => c.contentType === 'heading').map(c => c.text);
                    const scrollTop = window.scrollY || 0;
                    const docHeight = Math.max(document.body.scrollHeight, document.documentElement.scrollHeight) - window.innerHeight;
                    const scrollPercent = docHeight > 0 ? Math.round((scrollTop / docHeight) * 100) : 0;
                    
                    return {
                        timestamp: Date.now(),
                        pageUrl: window.location.href,
                        pageTitle: document.title,
                        scrollPosition: scrollTop,
                        scrollDepthPercent: scrollPercent,
                        visibleContent: content,
                        visibleHeadings: headings,
                        visibleImageCount: content.filter(c => c.contentType === 'image').length,
                        visibleVideoCount: content.filter(c => c.contentType === 'video').length
                    };
                },
                
                sendSnapshot: function() {
                    const now = Date.now();
                    if (now - this.lastSnapshotTime < this.snapshotInterval) return;
                    this.lastSnapshotTime = now;
                    
                    try {
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.komalViewport) {
                            window.webkit.messageHandlers.komalViewport.postMessage({
                                type: 'snapshot',
                                data: this.createSnapshot()
                            });
                        }
                    } catch (e) {}
                }
            };
            
            window.addEventListener('scroll', function() { komalViewportTracker.sendSnapshot(); }, { passive: true });
            setInterval(function() { komalViewportTracker.sendSnapshot(); }, 5000);
            window.addEventListener('load', function() { setTimeout(function() { komalViewportTracker.sendSnapshot(); }, 1000); });
            
            window.komalViewportTracker = komalViewportTracker;
        })();
        """
    }
}
#endif

