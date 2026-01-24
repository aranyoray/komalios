// Komal Digital Guardian - Image Scanner
// Scans images on page and communicates with native app for filtering
(function() {
    'use strict';
    
    // Prevent double initialization
    if (window.komalImageScanner) {
        return;
    }
    
    // Placeholder that will be replaced with actual base64 logo at runtime
    const KOMAL_LOGO_PLACEHOLDER = 'KOMAL_LOGO_BASE64';
    
    const komalImageScanner = {
        scannedCount: 0,
        filteredCount: 0,
        processedImages: new Set(),
        pendingImages: new Map(),
        minImageSize: 50,  // Minimum size to analyze (skip icons)
        batchSize: 5,      // Process images in batches
        
        // Generate unique ID for an image
        getImageId: function(img) {
            return img.src + '_' + img.getBoundingClientRect().top + '_' + img.getBoundingClientRect().left;
        },
        
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
            const width = img.naturalWidth || img.width || 0;
            const height = img.naturalHeight || img.height || 0;
            if (width < this.minImageSize || height < this.minImageSize) {
                return false;
            }
            
            // Skip SVGs and base64 placeholder images
            if (!img.src || img.src.startsWith('data:image/svg')) {
                return false;
            }
            
            return true;
        },
        
        // Scan all images on page
        scanImages: function() {
            const images = document.querySelectorAll('img');
            const imageData = [];
            const self = this;
            
            images.forEach(function(img, index) {
                if (!self.shouldScanImage(img)) {
                    return;
                }
                
                // Mark as scanned
                img.setAttribute('data-komal-scanned', 'true');
                const imageId = 'komal_img_' + self.scannedCount;
                img.setAttribute('data-komal-id', imageId);
                
                self.scannedCount++;
                
                // Collect image data for native analysis
                imageData.push({
                    id: imageId,
                    src: img.src,
                    width: img.naturalWidth || img.width,
                    height: img.naturalHeight || img.height
                });
                
                // Store reference for replacement
                self.pendingImages.set(imageId, img);
            });
            
            return imageData;
        },
        
        // Replace image with Komal logo
        replaceImage: function(imageId, category) {
            const img = this.pendingImages.get(imageId) || document.querySelector('[data-komal-id="' + imageId + '"]');
            
            if (!img) {
                console.log('Komal: Image not found for replacement:', imageId);
                return false;
            }
            
            // Store original source
            if (!img.hasAttribute('data-komal-original')) {
                img.setAttribute('data-komal-original', img.src);
            }
            
            // Mark as replaced
            img.setAttribute('data-komal-replaced', 'true');
            img.setAttribute('data-komal-category', category || 'unknown');
            
            // Apply Komal logo replacement
            if (KOMAL_LOGO_PLACEHOLDER !== 'KOMAL_LOGO_BASE64') {
                img.src = KOMAL_LOGO_PLACEHOLDER;
            } else {
                // Fallback: Create a colored placeholder
                this.applyPlaceholder(img, category);
            }
            
            // Style the replacement
            img.style.objectFit = 'contain';
            img.style.backgroundColor = '#FFF5F8';
            img.style.borderRadius = '8px';
            img.style.border = '2px solid #FFB6C1';
            
            this.filteredCount++;
            this.pendingImages.delete(imageId);
            
            return true;
        },
        
        // Apply a placeholder when logo is not available
        applyPlaceholder: function(img, category) {
            const canvas = document.createElement('canvas');
            const width = img.width || 200;
            const height = img.height || 200;
            canvas.width = width;
            canvas.height = height;
            
            const ctx = canvas.getContext('2d');
            
            // Soft pink gradient background
            const gradient = ctx.createLinearGradient(0, 0, width, height);
            gradient.addColorStop(0, '#FFF5F8');
            gradient.addColorStop(1, '#FFE4EC');
            ctx.fillStyle = gradient;
            ctx.fillRect(0, 0, width, height);
            
            // Draw shield icon
            ctx.fillStyle = '#FFB6C1';
            ctx.font = Math.min(width, height) * 0.3 + 'px Arial';
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            ctx.fillText('🛡️', width / 2, height / 2 - 10);
            
            // Draw text
            ctx.fillStyle = '#D4A5A5';
            ctx.font = 'bold ' + Math.min(width, height) * 0.08 + 'px Arial';
            ctx.fillText('Protected by Komal', width / 2, height / 2 + Math.min(width, height) * 0.2);
            
            try {
                img.src = canvas.toDataURL('image/png');
            } catch (e) {
                // If canvas fails, use a simple color
                img.style.backgroundColor = '#FFF5F8';
                img.src = 'about:blank';
            }
        },
        
        // Mark image as safe (no replacement needed)
        markSafe: function(imageId) {
            const img = this.pendingImages.get(imageId);
            if (img) {
                img.setAttribute('data-komal-safe', 'true');
                this.pendingImages.delete(imageId);
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
        
        // Process and send images in batches
        processNewImages: function() {
            const imageData = this.scanImages();
            
            if (imageData.length > 0) {
                // Send in batches
                for (let i = 0; i < imageData.length; i += this.batchSize) {
                    const batch = imageData.slice(i, i + this.batchSize);
                    this.sendForAnalysis(batch);
                }
            }
        },
        
        // Initialize scanner
        init: function() {
            const self = this;
            
            // Initial scan after page load
            if (document.readyState === 'complete') {
                setTimeout(function() { self.processNewImages(); }, 500);
            } else {
                window.addEventListener('load', function() {
                    setTimeout(function() { self.processNewImages(); }, 500);
                });
            }
            
            // Watch for dynamically added images
            const observer = new MutationObserver(function(mutations) {
                let hasNewImages = false;
                
                mutations.forEach(function(mutation) {
                    if (mutation.type === 'childList') {
                        mutation.addedNodes.forEach(function(node) {
                            if (node.nodeName === 'IMG' || (node.querySelectorAll && node.querySelectorAll('img').length > 0)) {
                                hasNewImages = true;
                            }
                        });
                    } else if (mutation.type === 'attributes' && mutation.target.nodeName === 'IMG') {
                        if (mutation.attributeName === 'src' && !mutation.target.hasAttribute('data-komal-replaced')) {
                            mutation.target.removeAttribute('data-komal-scanned');
                            hasNewImages = true;
                        }
                    }
                });
                
                if (hasNewImages) {
                    // Debounce processing
                    clearTimeout(self.processTimeout);
                    self.processTimeout = setTimeout(function() {
                        self.processNewImages();
                    }, 300);
                }
            });
            
            // Start observing
            observer.observe(document.body, {
                childList: true,
                subtree: true,
                attributes: true,
                attributeFilter: ['src']
            });
            
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
