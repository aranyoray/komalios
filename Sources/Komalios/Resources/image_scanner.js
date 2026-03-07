// Komal Digital Guardian - Image Scanner
// Scans images on page and communicates with native app for filtering
(function() {
    'use strict';

    // Prevent double initialization
    if (window.komalImageScanner) {
        return;
    }

    // Security nonce — injected at runtime by EngagementTracker.
    // Required for replaceImage/markSafe calls to prevent page JS from bypassing the filter.
    var SECURITY_NONCE = 'KOMAL_IMAGE_NONCE';

    // Trusted domains — skip pre-hiding but still scan images
    var TRUSTED_DOMAINS = (typeof TRUSTED_DOMAINS_PLACEHOLDER !== 'undefined') ? TRUSTED_DOMAINS_PLACEHOLDER : [];
    var currentHost = (window.location.hostname || '').toLowerCase();
    var isTrustedDomain = TRUSTED_DOMAINS.some(function(d) { return currentHost === d || currentHost === 'www.' + d || currentHost.endsWith('.' + d); });

    // Pre-hide ALL images on ALL domains during analysis (v2 §4).
    // No trusted-domain bypass — every image starts hidden until classified.
    var skipPreHide = false;

    // Inject global CSS for pre-hide (document-start CSS also handles initial hiding)
    var komalStyle = document.createElement('style');
    komalStyle.textContent =
        '[data-komal-pending] { visibility: hidden !important; opacity: 0 !important; pointer-events: none !important; }';
    (document.head || document.documentElement).appendChild(komalStyle);

    const komalImageScanner = {
        scannedCount: 0,
        filteredCount: 0,
        processedImages: new Set(),
        pendingImages: new Map(),
        pendingTimestamps: new Map(), // imageId -> Date.now() when sent for analysis
        blockedURLs: new Map(),      // src URL -> category (cache for instant re-block)
        safeURLs: new Set(),         // src URLs confirmed safe (skip re-analysis)
        minImageSize: 50,  // Minimum size to analyze (skip icons)
        batchSize: 5,      // Process images in batches
        pendingTimeoutMs: 5000, // Fail-safe: block image after 5s without response
        processTimeout: null, // Debounce timer for MutationObserver processing

        // Check if image should be scanned
        // Returns: 'scan' | 'safe' | 'pending' | 'skip'
        //   scan    = ready to analyze
        //   safe    = genuinely small icon / SVG / already processed — reveal immediately
        //   pending = has src but hasn't loaded yet — keep hidden, attach load listener
        //   skip    = already processed (scanned/replaced) — no action needed
        classifyImage: function(img) {
            // Skip if already processed
            if (img.hasAttribute('data-komal-scanned')) {
                return 'skip';
            }

            // Skip data URLs that are our replacement
            if (img.src && img.src.startsWith('data:image') && img.hasAttribute('data-komal-replaced')) {
                return 'skip';
            }

            // Skip SVGs (vector graphics, not photographic)
            if (!img.src || img.src.startsWith('data:image/svg')) {
                return 'safe';
            }

            // Allow data: URLs (base64 images) — native side will decode and analyze
            // Only skip if it's a tiny placeholder (< 200 chars base64)
            if (img.src.startsWith('data:image')) {
                return img.src.length > 200 ? 'scan' : 'safe';
            }

            var natW = img.naturalWidth || 0;
            var natH = img.naturalHeight || 0;

            // Image hasn't loaded yet (has src but no natural dimensions)
            // Keep it hidden and attach a load listener for deferred scanning
            if (natW === 0 || natH === 0) {
                return 'pending';
            }

            // Genuinely small images (loaded, confirmed small) — safe to reveal
            if (natW < this.minImageSize && natH < this.minImageSize) {
                return 'safe';
            }

            return 'scan';
        },

        // Backward-compatible wrapper used by other code paths
        shouldScanImage: function(img) {
            return this.classifyImage(img) === 'scan';
        },

        // Pre-hide an element pending analysis using INLINE styles
        // Inline !important beats any page CSS including Google's inline styles
        // On trusted domains, skip pre-hiding (images stay visible during analysis)
        preHideElement: function(el) {
            if (skipPreHide) {
                el.setAttribute('data-komal-pending', 'true');
                return;
            }
            el.setAttribute('data-komal-pending', 'true');
            el.style.setProperty('visibility', 'hidden', 'important');
            el.style.setProperty('opacity', '0', 'important');
            el.style.setProperty('pointer-events', 'none', 'important');
        },

        // Reveal a safe element after analysis completes
        revealElement: function(el) {
            el.removeAttribute('data-komal-pending');
            el.style.setProperty('visibility', 'visible', 'important');
            el.style.setProperty('opacity', '1', 'important');
            el.style.removeProperty('pointer-events');
        },

        // Mark an image as safe so CSS pre-hide reveals it
        markElementSafe: function(el) {
            el.setAttribute('data-komal-safe', 'true');
            // Override inline + CSS pre-hide styles
            el.style.setProperty('visibility', 'visible', 'important');
            el.style.setProperty('opacity', '1', 'important');
            el.style.removeProperty('pointer-events');
        },

        // Immediately hide a raw DOM node (called from MutationObserver, before debounce)
        // On trusted domains, skip hiding (images stay visible during analysis)
        immediateHideNode: function(node) {
            if (skipPreHide) return;
            if (node.nodeType !== 1) return;
            if (node.nodeName === 'IMG' && !node.hasAttribute('data-komal-safe') && !node.hasAttribute('data-komal-replaced')) {
                node.style.setProperty('visibility', 'hidden', 'important');
                node.style.setProperty('opacity', '0', 'important');
                node.style.setProperty('pointer-events', 'none', 'important');
            }
            // Also hide child images
            if (node.querySelectorAll) {
                var imgs = node.querySelectorAll('img:not([data-komal-safe]):not([data-komal-replaced])');
                for (var i = 0; i < imgs.length; i++) {
                    imgs[i].style.setProperty('visibility', 'hidden', 'important');
                    imgs[i].style.setProperty('opacity', '0', 'important');
                    imgs[i].style.setProperty('pointer-events', 'none', 'important');
                }
            }
        },

        // Attach a one-shot load listener so unloaded images get scanned once ready
        attachLoadListener: function(img) {
            if (img.hasAttribute('data-komal-load-listener')) return;
            img.setAttribute('data-komal-load-listener', 'true');
            var self = this;
            img.addEventListener('load', function onLoad() {
                img.removeEventListener('load', onLoad);
                img.removeAttribute('data-komal-load-listener');
                // Re-classify now that dimensions are available
                var cls = self.classifyImage(img);
                if (cls === 'scan') {
                    img.setAttribute('data-komal-scanned', 'true');
                    var imageId = 'komal_img_' + self.scannedCount;
                    img.setAttribute('data-komal-id', imageId);
                    self.scannedCount++;
                    self.preHideElement(img);
                    var analyzeSrc = img.currentSrc || img.src;

                    // Check caches
                    if (self.blockedURLs.has(analyzeSrc)) {
                        self.pendingImages.set(imageId, img);
                        self.replaceImage(imageId, self.blockedURLs.get(analyzeSrc), SECURITY_NONCE);
                        return;
                    }
                    if (self.safeURLs.has(analyzeSrc)) {
                        self.markElementSafe(img);
                        return;
                    }

                    self.pendingImages.set(imageId, img);
                    var picture = img.closest('picture');
                    if (picture) picture.setAttribute('data-komal-picture-for', imageId);
                    self.sendForAnalysis([{
                        id: imageId,
                        src: analyzeSrc,
                        width: img.naturalWidth || img.width,
                        height: img.naturalHeight || img.height
                    }]);
                } else if (cls === 'safe') {
                    self.markElementSafe(img);
                }
                // else 'skip' or still 'pending' (shouldn't happen after load) — leave hidden
            }, { once: true });

            // Also handle broken images — if load fails, mark safe (no image to filter)
            img.addEventListener('error', function onError() {
                img.removeEventListener('error', onError);
                img.removeAttribute('data-komal-load-listener');
                self.markElementSafe(img);
            }, { once: true });
        },

        // Scan all images on page
        scanImages: function() {
            var images = document.querySelectorAll('img');
            var imageData = [];
            var self = this;

            images.forEach(function(img) {
                var classification = self.classifyImage(img);

                if (classification === 'skip') {
                    return;
                }

                if (classification === 'safe') {
                    // Genuinely small icons, SVGs, tiny placeholders — reveal
                    if (!img.hasAttribute('data-komal-safe') && !img.hasAttribute('data-komal-replaced')) {
                        self.markElementSafe(img);
                    }
                    return;
                }

                if (classification === 'pending') {
                    // Image hasn't loaded yet — keep hidden, attach load listener
                    self.preHideElement(img);
                    self.attachLoadListener(img);
                    return;
                }

                // classification === 'scan' — proceed with analysis

                // Get the actual source URL for cache lookup
                var analyzeSrc = img.currentSrc || img.src;

                // CHECK BLOCKED URL CACHE — instant block without waiting for native
                if (self.blockedURLs.has(analyzeSrc)) {
                    img.setAttribute('data-komal-scanned', 'true');
                    var cachedId = 'komal_cache_' + self.scannedCount;
                    img.setAttribute('data-komal-id', cachedId);
                    self.scannedCount++;
                    // Immediately replace — no need to send to native
                    self.pendingImages.set(cachedId, img);
                    self.replaceImage(cachedId, self.blockedURLs.get(analyzeSrc), SECURITY_NONCE);
                    return;
                }

                // CHECK SAFE URL CACHE — instant reveal
                if (self.safeURLs.has(analyzeSrc)) {
                    img.setAttribute('data-komal-scanned', 'true');
                    self.markElementSafe(img);
                    return;
                }

                // Mark as scanned
                img.setAttribute('data-komal-scanned', 'true');
                var imageId = 'komal_img_' + self.scannedCount;
                img.setAttribute('data-komal-id', imageId);
                self.scannedCount++;

                // IMMEDIATELY hide image while pending analysis (inline style beats page CSS)
                self.preHideElement(img);

                // Collect image data for native analysis
                imageData.push({
                    id: imageId,
                    src: analyzeSrc,
                    width: img.naturalWidth || img.width,
                    height: img.naturalHeight || img.height
                });

                // Store reference for replacement
                self.pendingImages.set(imageId, img);

                // Track <picture> parent for source disabling on replacement
                var picture = img.closest('picture');
                if (picture) {
                    picture.setAttribute('data-komal-picture-for', imageId);
                }
            });

            // Scan <video poster> attributes
            var videos = document.querySelectorAll('video[poster]');
            videos.forEach(function(video) {
                if (video.hasAttribute('data-komal-scanned')) return;
                var posterUrl = video.getAttribute('poster');
                if (!posterUrl || posterUrl.length < 10) return;

                var rect = video.getBoundingClientRect();
                if (rect.width < self.minImageSize || rect.height < self.minImageSize) return;

                // Check blocked cache for poster
                if (self.blockedURLs.has(posterUrl)) {
                    video.setAttribute('data-komal-scanned', 'true');
                    var cachedId = 'komal_cache_' + self.scannedCount;
                    video.setAttribute('data-komal-id', cachedId);
                    self.scannedCount++;
                    self.pendingImages.set(cachedId, video);
                    self.replaceImage(cachedId, self.blockedURLs.get(posterUrl), SECURITY_NONCE);
                    return;
                }

                video.setAttribute('data-komal-scanned', 'true');
                var imageId = 'komal_poster_' + self.scannedCount;
                video.setAttribute('data-komal-id', imageId);
                self.scannedCount++;

                // Pre-hide video while poster is analyzed
                self.preHideElement(video);

                imageData.push({
                    id: imageId,
                    src: posterUrl,
                    width: Math.round(rect.width),
                    height: Math.round(rect.height),
                    isPoster: true
                });

                self.pendingImages.set(imageId, video);
            });

            return imageData;
        },

        // Block image — remove from DOM (or clear background/poster)
        replaceImage: function(imageId, category, nonce) {
            if (nonce !== SECURITY_NONCE) return false;
            // Use Map lookup only — no querySelector fallback to prevent CSS selector injection
            var el = this.pendingImages.get(imageId);

            if (!el) {
                return false;
            }

            // Cache the blocked URL for instant re-block of same image
            var originalSrc = el.getAttribute('data-komal-original') || el.currentSrc || el.src || el.getAttribute('poster') || '';
            if (originalSrc && !originalSrc.startsWith('data:')) {
                this.blockedURLs.set(originalSrc, category || 'unknown');
            }

            // Handle CSS background-image elements
            if (el.nodeName !== 'IMG' && el.nodeName !== 'VIDEO') {
                this.replaceBackgroundImage(el, category);
                this.filteredCount++;
                this.pendingImages.delete(imageId);
                this.pendingTimestamps.delete(imageId);
                return true;
            }

            // Handle <video poster>
            if (el.nodeName === 'VIDEO') {
                if (!el.hasAttribute('data-komal-original')) {
                    el.setAttribute('data-komal-original', el.getAttribute('poster') || '');
                }
                el.setAttribute('data-komal-replaced', 'true');
                el.setAttribute('data-komal-category', category || 'unknown');
                el.removeAttribute('poster');
                el.removeAttribute('data-komal-pending');
                el.style.setProperty('visibility', 'visible', 'important');
                el.style.setProperty('opacity', '1', 'important');
                this.filteredCount++;
                this.pendingImages.delete(imageId);
                this.pendingTimestamps.delete(imageId);
                return true;
            }

            // Handle <img> elements — remove from DOM entirely
            var picture = el.closest('picture');
            if (picture) {
                // Remove the entire <picture> element
                picture.setAttribute('data-komal-replaced', 'true');
                picture.setAttribute('data-komal-category', category || 'unknown');
                picture.remove();
            } else {
                el.setAttribute('data-komal-replaced', 'true');
                el.setAttribute('data-komal-category', category || 'unknown');
                el.remove();
            }

            this.filteredCount++;
            this.pendingImages.delete(imageId);
            this.pendingTimestamps.delete(imageId);

            return true;
        },

        // Mark image as safe (no replacement needed)
        markSafe: function(imageId, nonce) {
            if (nonce !== SECURITY_NONCE) return;
            var el = this.pendingImages.get(imageId);
            if (el) {
                // Cache this URL as safe
                var src = el.getAttribute('data-komal-original') || el.currentSrc || el.src || '';
                if (src && !src.startsWith('data:')) {
                    this.safeURLs.add(src);
                }
                el.setAttribute('data-komal-safe', 'true');
                // Reveal the image — it passed analysis
                this.revealElement(el);
                this.pendingImages.delete(imageId);
                this.pendingTimestamps.delete(imageId);
            }
        },

        // Get current stats
        getStats: function() {
            return {
                scanned: this.scannedCount,
                filtered: this.filteredCount,
                pending: this.pendingImages.size
            };
        },

        // Send images to native for analysis
        sendForAnalysis: function(imageData) {
            var self = this;
            var now = Date.now();
            // Record timestamps for pending timeout detection
            imageData.forEach(function(img) {
                self.pendingTimestamps.set(img.id, now);
            });
            try {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.komalImageScanner) {
                    window.webkit.messageHandlers.komalImageScanner.postMessage({
                        type: 'scan',
                        images: imageData,
                        pageUrl: window.location.href
                    });
                }
            } catch (e) {
                console.log('Komal: Could not send images for analysis');
            }
        },

        // Send stats to native
        sendStats: function() {
            try {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.komalImageScanner) {
                    window.webkit.messageHandlers.komalImageScanner.postMessage({
                        type: 'stats',
                        stats: this.getStats()
                    });
                }
            } catch (e) {
                console.log('Komal: Could not send stats');
            }
        },

        // Scan CSS background images on elements
        scanBackgroundImages: function() {
            var imageData = [];
            var self = this;
            // Check elements that commonly have background images
            var selectors = 'div, section, article, header, figure, span, a';
            var elements = document.querySelectorAll(selectors);

            elements.forEach(function(el) {
                if (el.hasAttribute('data-komal-bg-scanned')) return;

                var style = window.getComputedStyle(el);
                var bgImage = style.backgroundImage;
                if (!bgImage || bgImage === 'none') return;

                // Extract all URLs from background-image (may contain multiple)
                var bgMatches = bgImage.matchAll(/url\(["']?(.*?)["']?\)/g);
                var bgUrls = [];
                for (var m of bgMatches) {
                    if (m[1]) bgUrls.push(m[1]);
                }
                if (bgUrls.length === 0) return;

                // Skip very small elements (icons)
                var rect = el.getBoundingClientRect();
                if (rect.width < self.minImageSize || rect.height < self.minImageSize) return;

                // Process each background URL found
                bgUrls.forEach(function(bgUrl) {
                    // Skip tiny placeholders, gradients, SVGs
                    if (bgUrl.startsWith('data:image/svg')) return;
                    if (bgUrl.length < 20 && bgUrl.startsWith('data:')) return;

                    // Check blocked cache
                    if (self.blockedURLs.has(bgUrl)) {
                        el.setAttribute('data-komal-bg-scanned', 'true');
                        var cachedId = 'komal_cache_' + self.scannedCount;
                        el.setAttribute('data-komal-id', cachedId);
                        self.scannedCount++;
                        self.pendingImages.set(cachedId, el);
                        self.replaceImage(cachedId, self.blockedURLs.get(bgUrl), SECURITY_NONCE);
                        return;
                    }

                    el.setAttribute('data-komal-bg-scanned', 'true');
                    var imageId = 'komal_bg_' + self.scannedCount;
                    el.setAttribute('data-komal-id', imageId);
                    self.scannedCount++;

                    // Pre-hide background images too
                    self.preHideElement(el);

                    imageData.push({
                        id: imageId,
                        src: bgUrl,
                        width: Math.round(rect.width),
                        height: Math.round(rect.height),
                        isBackground: true
                    });

                    self.pendingImages.set(imageId, el);
                });
            });

            return imageData;
        },

        // Replace a CSS background image element — clear the background image and collapse
        replaceBackgroundImage: function(el, category) {
            el.setAttribute('data-komal-replaced', 'true');
            el.setAttribute('data-komal-category', category || 'unknown');
            el.removeAttribute('data-komal-pending');
            el.style.setProperty('background-image', 'none', 'important');
            el.style.setProperty('visibility', 'visible', 'important');
            el.style.setProperty('opacity', '1', 'important');
        },

        // Enforce that all replaced images stay replaced (guards against page JS reverting)
        // Also handles pending image timeout — blocks images that never got a response
        enforceReplacements: function() {
            var self = this;
            var now = Date.now();

            // Check for timed-out pending images — fail-closed on ALL domains (v2 §4)
            self.pendingTimestamps.forEach(function(timestamp, imageId) {
                if (now - timestamp > self.pendingTimeoutMs) {
                    self.replaceImage(imageId, 'timeout', SECURITY_NONCE);
                }
            });

            // Enforce background-image elements that are still in DOM
            var replaced = document.querySelectorAll('[data-komal-replaced]');
            replaced.forEach(function(el) {
                if (el.nodeName === 'VIDEO') {
                    if (el.hasAttribute('poster')) {
                        el.removeAttribute('poster');
                    }
                } else if (el.nodeName !== 'IMG' && el.nodeName !== 'PICTURE') {
                    var computed = window.getComputedStyle(el);
                    if (computed.backgroundImage !== 'none') {
                        el.style.setProperty('background-image', 'none', 'important');
                    }
                }
            });

            // Re-check for blocked URLs that page JS may have re-inserted
            var allImages = document.querySelectorAll('img:not([data-komal-replaced]):not([data-komal-scanned])');
            allImages.forEach(function(img) {
                var src = img.currentSrc || img.src || '';
                if (src && self.blockedURLs.has(src)) {
                    img.remove();
                }
            });
        },

        // Reveal all elements that don't need scanning (called after each scan pass)
        // This ensures the document-start CSS pre-hide doesn't permanently hide safe content
        revealSkippedElements: function() {
            var self = this;
            // Reveal all videos without poster (they have no image to scan)
            var videos = document.querySelectorAll('video:not([poster]):not([data-komal-safe])');
            videos.forEach(function(v) { self.markElementSafe(v); });
            // Reveal videos with tiny/empty poster
            var allVideos = document.querySelectorAll('video[poster]:not([data-komal-safe]):not([data-komal-scanned])');
            allVideos.forEach(function(v) {
                var poster = v.getAttribute('poster');
                if (!poster || poster.length < 10) { self.markElementSafe(v); }
            });
        },

        // Process and send images in batches
        processNewImages: function() {
            var imageData = this.scanImages();

            // Also scan CSS background images
            var bgData = this.scanBackgroundImages();
            imageData = imageData.concat(bgData);

            // Reveal elements that don't need scanning (icons, SVGs, videos without poster)
            this.revealSkippedElements();

            if (imageData.length > 0) {
                // Send in batches
                for (var i = 0; i < imageData.length; i += this.batchSize) {
                    var batch = imageData.slice(i, i + this.batchSize);
                    this.sendForAnalysis(batch);
                }
            }
        },

        // Initialize scanner
        init: function() {
            var self = this;

            // Initial scan — start immediately since document-start CSS already pre-hides images.
            // No delay needed; faster scan = faster reveal of safe images.
            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', function() { self.processNewImages(); });
            } else {
                self.processNewImages();
            }

            // Watch for dynamically added images
            var observer = new MutationObserver(function(mutations) {
                var hasNewImages = false;

                mutations.forEach(function(mutation) {
                    if (mutation.type === 'childList') {
                        mutation.addedNodes.forEach(function(node) {
                            if (node.nodeType !== 1) return; // skip text nodes

                            // IMMEDIATELY hide new images inline BEFORE debounced scan
                            // This eliminates the 100ms debounce window where images are visible
                            self.immediateHideNode(node);

                            if (node.nodeName === 'IMG' || node.nodeName === 'VIDEO' || node.nodeName === 'PICTURE' ||
                                (node.querySelectorAll && (
                                    node.querySelectorAll('img').length > 0 ||
                                    node.querySelectorAll('video[poster]').length > 0 ||
                                    node.querySelectorAll('picture').length > 0
                                ))) {
                                hasNewImages = true;
                            }
                        });
                    } else if (mutation.type === 'attributes') {
                        var target = mutation.target;

                        // Guard replaced elements still in DOM (videos, bg elements)
                        if (target.hasAttribute('data-komal-replaced')) {
                            if (mutation.attributeName === 'poster' && target.nodeName === 'VIDEO') {
                                target.removeAttribute('poster');
                            }
                            return; // Don't trigger rescan for replaced elements
                        }

                        // New/changed src on unscanned image — trigger rescan
                        if (target.nodeName === 'IMG' && mutation.attributeName === 'src') {
                            // Immediately hide while waiting for rescan (skip on trusted domains)
                            if (!skipPreHide) {
                                target.style.setProperty('visibility', 'hidden', 'important');
                                target.style.setProperty('opacity', '0', 'important');
                                target.style.setProperty('pointer-events', 'none', 'important');
                            }
                            // Clear previous classification — new src needs fresh analysis
                            target.removeAttribute('data-komal-scanned');
                            target.removeAttribute('data-komal-safe');
                            target.removeAttribute('data-komal-load-listener');
                            hasNewImages = true;
                        }
                        if (target.nodeName === 'VIDEO' && mutation.attributeName === 'poster') {
                            target.removeAttribute('data-komal-scanned');
                            hasNewImages = true;
                        }
                    }
                });

                if (hasNewImages) {
                    // Debounce processing
                    clearTimeout(self.processTimeout);
                    self.processTimeout = setTimeout(function() {
                        self.processNewImages();
                    }, 50); // Reduced from 100ms to 50ms
                }
            });

            // Start observing — watch src, srcset, poster, and style attributes
            var observeTarget = document.body || document.documentElement;
            if (observeTarget) {
                observer.observe(observeTarget, {
                    childList: true,
                    subtree: true,
                    attributes: true,
                    attributeFilter: ['src', 'srcset', 'poster', 'style']
                });
            }

            // Re-scan on scroll (catches lazy-loaded images that appear on scroll)
            var scrollTimeout;
            window.addEventListener('scroll', function() {
                clearTimeout(scrollTimeout);
                scrollTimeout = setTimeout(function() {
                    self.processNewImages();
                }, 200);
            }, { passive: true });

            // Periodic enforcement — guard replaced images (every 500ms for faster protection)
            setInterval(function() {
                self.enforceReplacements();
            }, 500);

            // Periodic stats update
            setInterval(function() {
                self.sendStats();
            }, 15000);
        }
    };

    // Initialize and expose (non-writable to prevent page JS from overwriting)
    komalImageScanner.init();
    Object.defineProperty(window, 'komalImageScanner', {
        value: komalImageScanner,
        writable: false,
        configurable: false
    });
})();
