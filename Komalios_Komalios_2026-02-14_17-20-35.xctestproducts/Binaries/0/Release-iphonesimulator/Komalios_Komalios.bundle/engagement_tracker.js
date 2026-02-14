// Komal Digital Guardian - Engagement Tracker
// Tracks scroll depth, dwell time, and user engagement metrics
(function() {
    'use strict';
    
    // Prevent double initialization
    if (window.komalTracker) {
        return;
    }
    
    const komalTracker = {
        startTime: Date.now(),
        maxScrollDepth: 0,
        scrollEvents: 0,
        lastScrollTime: Date.now(),
        isActive: true,
        visibilityChanges: 0,
        
        // Track scroll depth and events
        trackScroll: function() {
            if (!this.isActive) return;
            
            const scrollTop = window.scrollY || window.pageYOffset;
            const docHeight = Math.max(
                document.body.scrollHeight,
                document.documentElement.scrollHeight
            ) - window.innerHeight;
            
            // Prevent division by zero for short pages
            const scrollPercent = docHeight > 0 
                ? Math.round((scrollTop / docHeight) * 100) 
                : 100;
            
            this.maxScrollDepth = Math.max(this.maxScrollDepth, Math.min(scrollPercent, 100));
            this.scrollEvents++;
            this.lastScrollTime = Date.now();
        },
        
        // Track visibility changes (tab switching)
        trackVisibility: function() {
            this.isActive = !document.hidden;
            this.visibilityChanges++;
        },
        
        // Get current engagement data
        getEngagement: function() {
            return {
                dwellTimeMs: Date.now() - this.startTime,
                scrollDepthPercent: this.maxScrollDepth,
                scrollEvents: this.scrollEvents,
                isActive: this.isActive,
                visibilityChanges: this.visibilityChanges,
                pageTitle: document.title || '',
                url: window.location.href
            };
        },
        
        // Send engagement data to native app
        sendEngagement: function() {
            try {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.komalEngagement) {
                    window.webkit.messageHandlers.komalEngagement.postMessage(this.getEngagement());
                }
            } catch (e) {
                console.log('Komal: Could not send engagement data');
            }
        },
        
        // Initialize tracking
        init: function() {
            const self = this;
            
            // Throttled scroll handler
            let scrollTimeout = null;
            window.addEventListener('scroll', function() {
                self.trackScroll();
                
                // Debounced send to native
                if (scrollTimeout) clearTimeout(scrollTimeout);
                scrollTimeout = setTimeout(function() {
                    self.sendEngagement();
                }, 500);
            }, { passive: true });
            
            // Visibility change tracking
            document.addEventListener('visibilitychange', function() {
                self.trackVisibility();
                self.sendEngagement();
            });
            
            // Send engagement on page unload
            window.addEventListener('beforeunload', function() {
                self.sendEngagement();
            });
            
            // Periodic engagement updates (every 10 seconds)
            setInterval(function() {
                if (self.isActive) {
                    self.sendEngagement();
                }
            }, 10000);
            
            // Initial engagement report after page load
            if (document.readyState === 'complete') {
                setTimeout(function() { self.sendEngagement(); }, 1000);
            } else {
                window.addEventListener('load', function() {
                    setTimeout(function() { self.sendEngagement(); }, 1000);
                });
            }
        }
    };
    
    // Initialize and expose
    komalTracker.init();
    window.komalTracker = komalTracker;
})();
