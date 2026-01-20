// Komal Digital Guardian - Viewport Content Tracker
// Tracks what content is actually visible on screen as user scrolls
(function() {
    'use strict';
    
    // Prevent double initialization
    if (window.komalViewportTracker) {
        return;
    }
    
    const komalViewportTracker = {
        lastSnapshotTime: 0,
        snapshotInterval: 2000,      // Capture every 2 seconds while scrolling
        idleSnapshotInterval: 5000,  // Capture every 5 seconds when idle
        isScrolling: false,
        scrollTimeout: null,
        visibleElements: new Map(),  // Track time elements are visible
        totalSnapshots: 0,
        
        // Keywords to flag (will be extended by native code)
        flaggedKeywords: [
            // Violence
            'kill', 'murder', 'death', 'blood', 'gore', 'violent', 'attack', 'weapon',
            // Adult
            'xxx', 'porn', 'nude', 'naked', 'sex', 'adult only', 'nsfw', '18+',
            // Drugs
            'cocaine', 'heroin', 'meth', 'drugs', 'weed', 'marijuana',
            // Self-harm
            'suicide', 'self-harm', 'cutting', 'kill myself',
            // Gambling
            'bet now', 'casino', 'gambling', 'poker', 'slots',
            // Scams
            'get rich quick', 'make money fast', 'crypto invest', 'guaranteed returns'
        ],
        
        // Check if element is in viewport
        isInViewport: function(element) {
            const rect = element.getBoundingClientRect();
            const windowHeight = window.innerHeight || document.documentElement.clientHeight;
            const windowWidth = window.innerWidth || document.documentElement.clientWidth;
            
            // Element is at least partially visible
            return (
                rect.top < windowHeight &&
                rect.bottom > 0 &&
                rect.left < windowWidth &&
                rect.right > 0
            );
        },
        
        // Get viewport position of element
        getViewportPosition: function(element) {
            const rect = element.getBoundingClientRect();
            const windowHeight = window.innerHeight;
            const centerY = rect.top + rect.height / 2;
            
            if (centerY < windowHeight * 0.33) return 'top';
            if (centerY > windowHeight * 0.66) return 'bottom';
            return 'middle';
        },
        
        // Determine content type from element
        getContentType: function(element) {
            const tag = element.tagName.toLowerCase();
            
            // Headings
            if (/^h[1-6]$/.test(tag)) return 'heading';
            
            // Text content
            if (tag === 'p' || tag === 'article' || tag === 'section') return 'paragraph';
            
            // Media
            if (tag === 'img') return 'image';
            if (tag === 'video' || tag === 'iframe') {
                const src = element.src || element.getAttribute('src') || '';
                if (src.includes('youtube') || src.includes('vimeo') || src.includes('video')) {
                    return 'video';
                }
            }
            
            // Interactive
            if (tag === 'a') return 'link';
            if (tag === 'button' || (tag === 'input' && element.type === 'button')) return 'button';
            if (tag === 'form' || tag === 'input' || tag === 'textarea') return 'form';
            
            // Ads (common patterns)
            const classAndId = (element.className + ' ' + element.id).toLowerCase();
            if (classAndId.includes('ad') || classAndId.includes('sponsor') || 
                classAndId.includes('banner') || classAndId.includes('promo')) {
                return 'ad';
            }
            
            // Social embeds
            if (classAndId.includes('twitter') || classAndId.includes('facebook') ||
                classAndId.includes('instagram') || classAndId.includes('tiktok')) {
                return 'social';
            }
            
            // Comments
            if (classAndId.includes('comment') || classAndId.includes('reply')) {
                return 'comment';
            }
            
            return 'unknown';
        },
        
        // Extract text content safely (truncated for privacy)
        extractText: function(element, maxLength) {
            maxLength = maxLength || 200;
            let text = '';
            
            // Get text content
            if (element.textContent) {
                text = element.textContent.trim();
            }
            
            // Clean up whitespace
            text = text.replace(/\s+/g, ' ');
            
            // Truncate
            if (text.length > maxLength) {
                text = text.substring(0, maxLength) + '...';
            }
            
            return text || null;
        },
        
        // Check text for flagged keywords
        checkForFlaggedKeywords: function(text) {
            if (!text) return [];
            
            const lowerText = text.toLowerCase();
            const found = [];
            
            for (const keyword of this.flaggedKeywords) {
                if (lowerText.includes(keyword.toLowerCase())) {
                    found.push(keyword);
                }
            }
            
            return found;
        },
        
        // Get all visible content elements
        getVisibleContent: function() {
            const content = [];
            const now = Date.now();
            
            // Selectors for content we want to track
            const selectors = [
                'h1', 'h2', 'h3', 'h4', 'h5', 'h6',  // Headings
                'p', 'article', 'section',            // Text
                'img', 'video', 'iframe',             // Media
                'a[href]',                            // Links
                'button', 'input[type="button"]',     // Buttons
                'form',                               // Forms
                '[class*="ad"]', '[id*="ad"]',        // Ads
                '[class*="comment"]'                  // Comments
            ];
            
            const elements = document.querySelectorAll(selectors.join(','));
            
            elements.forEach((element, index) => {
                if (!this.isInViewport(element)) return;
                
                // Skip very small or hidden elements
                const rect = element.getBoundingClientRect();
                if (rect.width < 20 || rect.height < 20) return;
                
                const contentType = this.getContentType(element);
                const text = this.extractText(element, 200);
                
                // Skip empty elements (except images/videos)
                if (!text && contentType !== 'image' && contentType !== 'video') return;
                
                // Track time in view
                const elementId = element.getAttribute('data-komal-track-id') || 
                                  ('komal_' + index + '_' + element.tagName);
                element.setAttribute('data-komal-track-id', elementId);
                
                let timeInView = 0;
                if (this.visibleElements.has(elementId)) {
                    const startTime = this.visibleElements.get(elementId);
                    timeInView = (now - startTime) / 1000;
                } else {
                    this.visibleElements.set(elementId, now);
                }
                
                // Check for flagged keywords
                const flaggedKeywords = this.checkForFlaggedKeywords(text);
                
                // Determine risk level
                let riskLevel = 'safe';
                if (flaggedKeywords.length > 2) riskLevel = 'high';
                else if (flaggedKeywords.length > 0) riskLevel = 'medium';
                
                content.push({
                    contentType: contentType,
                    text: text,
                    elementTag: element.tagName.toLowerCase(),
                    viewportPosition: this.getViewportPosition(element),
                    timeInViewSeconds: timeInView,
                    isInteractive: contentType === 'link' || contentType === 'button' || contentType === 'form',
                    hasMedia: contentType === 'image' || contentType === 'video',
                    wordCount: text ? text.split(/\s+/).length : 0,
                    flaggedKeywords: flaggedKeywords.length > 0 ? flaggedKeywords : null,
                    riskLevel: riskLevel
                });
            });
            
            // Clean up elements no longer in view
            for (const [elementId, startTime] of this.visibleElements) {
                const element = document.querySelector(`[data-komal-track-id="${elementId}"]`);
                if (!element || !this.isInViewport(element)) {
                    this.visibleElements.delete(elementId);
                }
            }
            
            return content;
        },
        
        // Create a viewport snapshot
        createSnapshot: function() {
            const visibleContent = this.getVisibleContent();
            
            // Extract headings
            const visibleHeadings = visibleContent
                .filter(c => c.contentType === 'heading' && c.text)
                .map(c => c.text);
            
            // Count media
            const imageCount = visibleContent.filter(c => c.contentType === 'image').length;
            const videoCount = visibleContent.filter(c => c.contentType === 'video').length;
            const hasAds = visibleContent.some(c => c.contentType === 'ad');
            
            // Collect all flagged keywords
            const allFlagged = [];
            visibleContent.forEach(c => {
                if (c.flaggedKeywords) {
                    allFlagged.push(...c.flaggedKeywords);
                }
            });
            const uniqueFlagged = [...new Set(allFlagged)];
            
            // Get primary visible text (first substantial paragraph)
            const primaryText = visibleContent
                .filter(c => c.contentType === 'paragraph' && c.text && c.text.length > 50)
                .map(c => c.text)[0] || null;
            
            // Calculate scroll position
            const scrollTop = window.scrollY || window.pageYOffset;
            const docHeight = Math.max(
                document.body.scrollHeight,
                document.documentElement.scrollHeight
            ) - window.innerHeight;
            const scrollPercent = docHeight > 0 ? Math.round((scrollTop / docHeight) * 100) : 0;
            
            this.totalSnapshots++;
            
            return {
                timestamp: Date.now(),
                pageUrl: window.location.href,
                pageTitle: document.title || '',
                scrollPosition: scrollTop,
                scrollDepthPercent: Math.min(scrollPercent, 100),
                visibleContent: visibleContent,
                primaryContent: primaryText,
                visibleHeadings: visibleHeadings,
                visibleImageCount: imageCount,
                visibleVideoCount: videoCount,
                hasVisibleAds: hasAds,
                flaggedKeywords: uniqueFlagged
            };
        },
        
        // Send snapshot to native app
        sendSnapshot: function() {
            const now = Date.now();
            
            // Throttle snapshots
            if (now - this.lastSnapshotTime < this.snapshotInterval) {
                return;
            }
            
            this.lastSnapshotTime = now;
            
            try {
                const snapshot = this.createSnapshot();
                
                if (window.webkit && window.webkit.messageHandlers && 
                    window.webkit.messageHandlers.komalViewport) {
                    window.webkit.messageHandlers.komalViewport.postMessage({
                        type: 'snapshot',
                        data: snapshot
                    });
                }
            } catch (e) {
                console.log('Komal: Could not send viewport snapshot');
            }
        },
        
        // Handle scroll events
        onScroll: function() {
            this.isScrolling = true;
            
            // Clear existing timeout
            if (this.scrollTimeout) {
                clearTimeout(this.scrollTimeout);
            }
            
            // Send snapshot while scrolling (throttled)
            this.sendSnapshot();
            
            // Mark scrolling as stopped after delay
            this.scrollTimeout = setTimeout(() => {
                this.isScrolling = false;
                // Send final snapshot when scrolling stops
                this.sendSnapshot();
            }, 500);
        },
        
        // Get current stats
        getStats: function() {
            return {
                totalSnapshots: this.totalSnapshots,
                trackedElements: this.visibleElements.size,
                isScrolling: this.isScrolling
            };
        },
        
        // Initialize tracker
        init: function() {
            const self = this;
            
            // Track scrolling
            window.addEventListener('scroll', function() {
                self.onScroll();
            }, { passive: true });
            
            // Initial snapshot after page load
            if (document.readyState === 'complete') {
                setTimeout(function() { self.sendSnapshot(); }, 1000);
            } else {
                window.addEventListener('load', function() {
                    setTimeout(function() { self.sendSnapshot(); }, 1000);
                });
            }
            
            // Periodic snapshots when idle
            setInterval(function() {
                if (!self.isScrolling) {
                    self.sendSnapshot();
                }
            }, self.idleSnapshotInterval);
            
            // Snapshot on visibility change (tab switch)
            document.addEventListener('visibilitychange', function() {
                if (!document.hidden) {
                    self.sendSnapshot();
                }
            });
            
            // Snapshot before page unload
            window.addEventListener('beforeunload', function() {
                self.sendSnapshot();
            });
            
            console.log('Komal Viewport Tracker initialized');
        }
    };
    
    // Initialize and expose
    komalViewportTracker.init();
    window.komalViewportTracker = komalViewportTracker;
})();
