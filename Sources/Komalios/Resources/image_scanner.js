// Komal Digital Guardian - Image Scanner
// Scans images on page and communicates with native app for filtering
(function() {
    'use strict';

    // Prevent double initialization
    if (window.komalImageScanner) {
        return;
    }

    // Trusted domains — skip pre-hiding but still scan images
    var TRUSTED_DOMAINS = (typeof TRUSTED_DOMAINS_PLACEHOLDER !== 'undefined') ? TRUSTED_DOMAINS_PLACEHOLDER : [];
    var currentHost = (window.location.hostname || '').toLowerCase();
    var isTrustedDomain = TRUSTED_DOMAINS.some(function(d) { return currentHost === d || currentHost === 'www.' + d || currentHost.endsWith('.' + d); });

    // Pre-hide ALL images on ALL domains during analysis.
    // This eliminates the window where inappropriate images are visible
    // before CoreML classification completes.
    var skipPreHide = isTrustedDomain;

    // Placeholder that will be replaced with actual base64 logo at runtime
    const KOMAL_LOGO_PLACEHOLDER = 'KOMAL_LOGO_BASE64';

    // Inject global CSS for replacement protection (pre-hide is handled by document-start CSS)
    var komalStyle = document.createElement('style');
    komalStyle.textContent =
        '[data-komal-pending] { visibility: hidden !important; opacity: 0 !important; pointer-events: none !important; }' +
        '[data-komal-replaced] { visibility: visible !important; opacity: 1 !important; object-fit: contain !important; background-color: #FFF5F8 !important; border-radius: 8px !important; border: 2px solid #FFB6C1 !important; }';
    (document.head || document.documentElement).appendChild(komalStyle);

    const komalImageScanner = {
        scannedCount: 0,
        filteredCount: 0,
        processedImages: new Set(),
        pendingImages: new Map(),
        pendingTimestamps: new Map(), // imageId -> Date.now() when sent for analysis
        replacementSrcs: new Map(),  // imageId -> replacement src for enforcement
        blockedURLs: new Map(),      // src URL -> category (cache for instant re-block)
        safeURLs: new Set(),         // src URLs confirmed safe (skip re-analysis)
        minImageSize: 50,  // Minimum size to analyze (skip icons)
        batchSize: 5,      // Process images in batches
        pendingTimeoutMs: 10000, // Fail-safe: block image after 10s without response
        processTimeout: null, // Debounce timer for MutationObserver processing

        // Check if image should be scanned
        shouldScanImage: function(img) {
            // Skip if already processed
            if (img.hasAttribute('data-komal-scanned')) {
                return false;
            }

            // Skip data URLs that are our replacement
            if (img.src && img.src.startsWith('data:image') && img.hasAttribute('data-komal-replaced')) {
                return false;
            }

            // Skip very small images (likely icons)
            var width = img.naturalWidth || img.width || 0;
            var height = img.naturalHeight || img.height || 0;
            if (width < this.minImageSize || height < this.minImageSize) {
                return false;
            }

            // Skip SVGs (vector graphics, not photographic)
            if (!img.src || img.src.startsWith('data:image/svg')) {
                return false;
            }

            // Allow data: URLs (base64 images) — native side will decode and analyze
            // Only skip if it's a tiny placeholder (< 200 chars base64)
            if (img.src.startsWith('data:image')) {
                return img.src.length > 200;
            }

            return true;
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

        // Scan all images on page
        scanImages: function() {
            var images = document.querySelectorAll('img');
            var imageData = [];
            var self = this;

            images.forEach(function(img) {
                if (!self.shouldScanImage(img)) {
                    // Images we don't need to scan (icons, SVGs, already processed)
                    // must be marked safe so the document-start CSS pre-hide reveals them
                    if (!img.hasAttribute('data-komal-safe') && !img.hasAttribute('data-komal-replaced') && !img.hasAttribute('data-komal-pending')) {
                        self.markElementSafe(img);
                    }
                    return;
                }

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
                    self.replaceImage(cachedId, self.blockedURLs.get(analyzeSrc));
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
                    self.replaceImage(cachedId, self.blockedURLs.get(posterUrl));
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

        // Replace image with Komal shield placeholder
        replaceImage: function(imageId, category) {
            var el = this.pendingImages.get(imageId) || document.querySelector('[data-komal-id="' + imageId + '"]');

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

            // Handle <img> elements
            if (!el.hasAttribute('data-komal-original')) {
                el.setAttribute('data-komal-original', el.src);
            }

            el.setAttribute('data-komal-replaced', 'true');
            el.setAttribute('data-komal-category', category || 'unknown');

            // Clear srcset to prevent browser from using alternative sources
            if (el.hasAttribute('srcset')) {
                el.setAttribute('data-komal-original-srcset', el.getAttribute('srcset'));
                el.removeAttribute('srcset');
            }

            // Disable <source> elements in parent <picture>
            var picture = el.closest('picture');
            if (picture) {
                var sources = picture.querySelectorAll('source');
                sources.forEach(function(source) {
                    if (!source.hasAttribute('data-komal-original-srcset')) {
                        source.setAttribute('data-komal-original-srcset', source.getAttribute('srcset') || '');
                    }
                    source.removeAttribute('srcset');
                    source.removeAttribute('media');
                    source.removeAttribute('type');
                });
            }

            // Generate replacement src
            var replacementSrc;
            if (KOMAL_LOGO_PLACEHOLDER !== 'KOMAL_LOGO_BASE64') {
                replacementSrc = KOMAL_LOGO_PLACEHOLDER;
            } else {
                replacementSrc = this.generatePlaceholderDataURL(el, category);
            }

            el.src = replacementSrc;

            // Store replacement src for periodic enforcement
            this.replacementSrcs.set(imageId, replacementSrc);

            // Remove pre-hide and make replacement visible
            el.removeAttribute('data-komal-pending');
            el.style.setProperty('visibility', 'visible', 'important');
            el.style.setProperty('opacity', '1', 'important');

            this.filteredCount++;
            this.pendingImages.delete(imageId);
            this.pendingTimestamps.delete(imageId);

            return true;
        },

        // Generate a shield placeholder as data URL
        generatePlaceholderDataURL: function(img, category) {
            var canvas = document.createElement('canvas');
            var w = parseInt(img.width) || parseInt(img.naturalWidth) || 200;
            var h = parseInt(img.height) || parseInt(img.naturalHeight) || 200;
            canvas.width = w;
            canvas.height = h;
            var ctx = canvas.getContext('2d');
            // Draw solid placeholder background - don't touch original image (cross-origin safe)
            ctx.fillStyle = '#f0f0f0';
            ctx.fillRect(0, 0, w, h);
            ctx.fillStyle = '#999';
            ctx.font = Math.max(12, Math.min(w, h) / 8) + 'px sans-serif';
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            ctx.fillText('🛡️', w / 2, h / 2 - 10);
            ctx.font = Math.max(10, Math.min(w, h) / 12) + 'px sans-serif';
            ctx.fillText('Komal', w / 2, h / 2 + 15);
            return canvas.toDataURL('image/png');
        },

        // Mark image as safe (no replacement needed)
        markSafe: function(imageId) {
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
                        self.replaceImage(cachedId, self.blockedURLs.get(bgUrl));
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

        // Replace a CSS background image element
        replaceBackgroundImage: function(el, category) {
            if (!el.hasAttribute('data-komal-original-bg')) {
                el.setAttribute('data-komal-original-bg', el.style.backgroundImage || '');
            }
            el.setAttribute('data-komal-replaced', 'true');
            el.setAttribute('data-komal-category', category || 'unknown');
            el.removeAttribute('data-komal-pending');
            el.style.setProperty('visibility', 'visible', 'important');
            el.style.setProperty('opacity', '1', 'important');
            el.style.setProperty('background-image', 'none', 'important');
            el.style.setProperty('background-color', '#FFF5F8', 'important');
            el.style.setProperty('border-radius', '8px', 'important');
            el.style.setProperty('border', '2px solid #FFB6C1', 'important');
        },

        // Enforce that all replaced images stay replaced (guards against page JS reverting)
        // Also handles pending image timeout — blocks images that never got a response
        enforceReplacements: function() {
            var self = this;
            var now = Date.now();

            // Check for timed-out pending images
            // Trusted domains: fail-open (keep image visible) to avoid false positives on cultural/educational content
            // Untrusted domains: fail-closed (replace for safety)
            self.pendingTimestamps.forEach(function(timestamp, imageId) {
                if (now - timestamp > self.pendingTimeoutMs) {
                    if (isTrustedDomain) {
                        self.markSafe(imageId);
                    } else {
                        self.replaceImage(imageId, 'timeout');
                    }
                }
            });

            var replaced = document.querySelectorAll('[data-komal-replaced]');

            replaced.forEach(function(el) {
                var imageId = el.getAttribute('data-komal-id');

                if (el.nodeName === 'IMG') {
                    // Re-apply replacement src if page JS changed it
                    var expectedSrc = self.replacementSrcs.get(imageId);
                    if (expectedSrc && el.src !== expectedSrc) {
                        el.src = expectedSrc;
                    }
                    // Ensure srcset stays cleared
                    if (el.hasAttribute('srcset')) {
                        el.removeAttribute('srcset');
                    }
                    // Ensure opacity is visible (not hidden)
                    el.style.setProperty('opacity', '1', 'important');
                    // Re-disable <source> elements in parent <picture>
                    var picture = el.closest('picture');
                    if (picture) {
                        var sources = picture.querySelectorAll('source[srcset]');
                        sources.forEach(function(source) {
                            source.removeAttribute('srcset');
                        });
                    }
                } else if (el.nodeName === 'VIDEO') {
                    // Re-clear poster if page JS restored it
                    if (el.hasAttribute('poster')) {
                        el.removeAttribute('poster');
                    }
                } else {
                    // Background element — ensure background-image stays none
                    var computed = window.getComputedStyle(el);
                    if (computed.backgroundImage !== 'none') {
                        el.style.setProperty('background-image', 'none', 'important');
                    }
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

                        // Guard replaced elements: if page JS changed src/srcset/poster, revert immediately
                        if (target.hasAttribute('data-komal-replaced')) {
                            if (mutation.attributeName === 'src' && target.nodeName === 'IMG') {
                                var imgId = target.getAttribute('data-komal-id');
                                var expectedSrc = self.replacementSrcs.get(imgId);
                                if (expectedSrc && target.src !== expectedSrc) {
                                    target.src = expectedSrc;
                                }
                            }
                            if (mutation.attributeName === 'srcset') {
                                target.removeAttribute('srcset');
                            }
                            if (mutation.attributeName === 'poster' && target.nodeName === 'VIDEO') {
                                target.removeAttribute('poster');
                            }
                            // Also re-enforce opacity on replaced images
                            // Guard: only set if not already correct to avoid infinite MutationObserver loop
                            if (mutation.attributeName === 'style' && target.nodeName === 'IMG') {
                                if (target.style.getPropertyValue('opacity') !== '1' || target.style.getPropertyPriority('opacity') !== 'important') {
                                    target.style.setProperty('opacity', '1', 'important');
                                }
                            }
                            return; // Don't trigger rescan for replaced elements
                        }

                        // New/changed src on unscanned image — trigger rescan
                        if (target.nodeName === 'IMG' && mutation.attributeName === 'src') {
                            // Immediately hide while waiting for rescan (skip on trusted domains)
                            if (!skipPreHide && !target.hasAttribute('data-komal-safe')) {
                                target.style.setProperty('visibility', 'hidden', 'important');
                                target.style.setProperty('opacity', '0', 'important');
                                target.style.setProperty('pointer-events', 'none', 'important');
                            }
                            target.removeAttribute('data-komal-scanned');
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

    // Initialize and expose
    komalImageScanner.init();
    window.komalImageScanner = komalImageScanner;
})();
