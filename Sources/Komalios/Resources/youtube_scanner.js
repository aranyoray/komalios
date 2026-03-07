/**
 * youtube_scanner.js — Komal YouTube Video-Level Content Filter
 *
 * Detects YouTube video pages, pre-hides the video player,
 * extracts metadata, and communicates with native for per-video analysis.
 *
 * Key design decisions (senior dev rationale):
 * 1. CSS pre-hide injected IMMEDIATELY — video is hidden before it renders
 * 2. Uses yt-navigate-finish (YouTube's own SPA event) + pushState + polling
 * 3. MutationObserver catches dynamically added <video> elements
 * 4. Audio enforcer re-queries <video> each tick (YouTube recreates elements)
 * 5. Metadata extraction uses ytInitialPlayerResponse + DOM fallbacks
 * 6. Supports both desktop (ytd-*) and mobile (ytm-*) YouTube selectors
 */
(function() {
    'use strict';

    // Only activate on YouTube domains (exact or subdomain match)
    var host = window.location.hostname.toLowerCase();
    var isYouTube = (host === 'youtube.com' || host.substr(-(('.youtube.com').length)) === '.youtube.com' ||
                     host === 'youtu.be' || host.substr(-(('.youtu.be').length)) === '.youtu.be');
    if (!isYouTube) {
        return;
    }

    if (window.komalYouTubeScanner) return;

    // =========================================================================
    // CSS Pre-Hide — injected IMMEDIATELY, before any video can render
    // =========================================================================
    var preHideStyle = document.createElement('style');
    preHideStyle.id = 'komal-yt-prehide';
    preHideStyle.textContent = '';
    (document.head || document.documentElement).appendChild(preHideStyle);

    function setVideoPreHide(hide) {
        if (hide) {
            preHideStyle.textContent =
                '#movie_player, .html5-video-player, ytm-player, video { ' +
                'visibility: hidden !important; opacity: 0 !important; pointer-events: none !important; }';
        } else {
            preHideStyle.textContent = '';
        }
    }

    // If we're already on a video page, pre-hide immediately
    if (window.location.pathname === '/watch' || window.location.hostname.indexOf('youtu.be') !== -1) {
        setVideoPreHide(true);
    }

    // =========================================================================
    // State
    // =========================================================================
    var currentVideoId = null;
    var pendingVideoId = null;
    var blockedVideoIds = {};
    var blockedOrder = [];
    var MAX_CACHE_SIZE = 200;
    var lastCheckedUrl = '';
    var overlayElement = null;
    var urlPollInterval = null;
    var audioEnforcerInterval = null;
    var playerObserver = null;

    // Komal logo — injected at runtime by EngagementTracker, falls back to SVG shield
    var KOMAL_LOGO = 'KOMAL_YT_LOGO_BASE64';

    // Security nonce — injected at runtime by EngagementTracker.
    // Required for allowVideo/blockVideo calls to prevent page JS from bypassing the filter.
    var SECURITY_NONCE = 'KOMAL_YT_NONCE';

    // =========================================================================
    // Cache Helpers
    // =========================================================================

    function addToBlocked(videoId, reason) {
        if (!blockedVideoIds[videoId]) {
            blockedOrder.push(videoId);
        }
        blockedVideoIds[videoId] = reason;
        while (blockedOrder.length > MAX_CACHE_SIZE) {
            delete blockedVideoIds[blockedOrder.shift()];
        }
    }

    // =========================================================================
    // Video ID Extraction
    // =========================================================================

    function extractVideoId(urlStr) {
        try {
            var url = new URL(urlStr);
            if (url.pathname === '/watch') {
                return url.searchParams.get('v') || null;
            }
            // Shorts
            var shortsMatch = url.pathname.match(/^\/shorts\/([a-zA-Z0-9_-]+)/);
            if (shortsMatch) {
                return shortsMatch[1];
            }
            // Short URL: youtu.be/VIDEO_ID
            if (url.hostname.indexOf('youtu.be') !== -1) {
                var path = url.pathname.replace(/^\//, '');
                return path.length > 0 ? path.split('/')[0] : null;
            }
        } catch (e) {}
        return null;
    }

    // =========================================================================
    // Audio Control — queries <video> EVERY tick (YouTube recreates elements)
    // =========================================================================

    function muteAllVideos() {
        var videos = document.querySelectorAll('video');
        for (var i = 0; i < videos.length; i++) {
            try {
                videos[i].muted = true;
                videos[i].volume = 0;
                videos[i].pause();
            } catch (e) {}
        }
    }

    function startAudioEnforcer() {
        stopAudioEnforcer();
        muteAllVideos();
        audioEnforcerInterval = setInterval(muteAllVideos, 150);
    }

    function stopAudioEnforcer() {
        if (audioEnforcerInterval) {
            clearInterval(audioEnforcerInterval);
            audioEnforcerInterval = null;
        }
    }

    function restoreAudio() {
        stopAudioEnforcer();
        var videos = document.querySelectorAll('video');
        for (var i = 0; i < videos.length; i++) {
            try {
                videos[i].muted = false;
                videos[i].volume = 1;
            } catch (e) {}
        }
    }

    // =========================================================================
    // Player Selectors (desktop + mobile)
    // =========================================================================

    function getPlayer() {
        return document.querySelector('#movie_player') ||
               document.querySelector('.html5-video-player') ||
               document.querySelector('ytm-player') ||
               document.querySelector('video');
    }

    function getPlayerContainer() {
        return document.querySelector('#player-container-outer') ||
               document.querySelector('#player-container-inner') ||
               document.querySelector('#player') ||
               document.querySelector('ytm-player') ||
               document.querySelector('#movie_player');
    }

    // =========================================================================
    // Video Player Hide / Reveal
    // =========================================================================

    function hideVideoPlayer() {
        setVideoPreHide(true);
        var player = getPlayer();
        if (player) {
            player.style.setProperty('visibility', 'hidden', 'important');
            player.style.setProperty('opacity', '0', 'important');
            player.style.setProperty('pointer-events', 'none', 'important');
        }
        muteAllVideos();
        startAudioEnforcer();
        startPlayerObserver();
    }

    function revealVideoPlayer() {
        setVideoPreHide(false);
        var player = getPlayer();
        if (player) {
            player.style.removeProperty('visibility');
            player.style.removeProperty('opacity');
            player.style.removeProperty('pointer-events');
        }
        restoreAudio();
        removeOverlay();
        stopPlayerObserver();
    }

    // MutationObserver: catch dynamically added <video> elements and hide/mute them
    function startPlayerObserver() {
        stopPlayerObserver();
        playerObserver = new MutationObserver(function(mutations) {
            for (var i = 0; i < mutations.length; i++) {
                var nodes = mutations[i].addedNodes;
                for (var j = 0; j < nodes.length; j++) {
                    var node = nodes[j];
                    if (node.nodeType !== 1) continue;
                    if (node.tagName === 'VIDEO') {
                        try { node.muted = true; node.volume = 0; node.pause(); } catch (e) {}
                        node.style.setProperty('visibility', 'hidden', 'important');
                        node.style.setProperty('opacity', '0', 'important');
                    }
                    if (node.querySelectorAll) {
                        var vids = node.querySelectorAll('video');
                        for (var k = 0; k < vids.length; k++) {
                            try { vids[k].muted = true; vids[k].volume = 0; vids[k].pause(); } catch (e) {}
                            vids[k].style.setProperty('visibility', 'hidden', 'important');
                            vids[k].style.setProperty('opacity', '0', 'important');
                        }
                    }
                }
            }
        });
        playerObserver.observe(document.documentElement, { childList: true, subtree: true });
    }

    function stopPlayerObserver() {
        if (playerObserver) {
            playerObserver.disconnect();
            playerObserver = null;
        }
    }

    // =========================================================================
    // Overlays
    // =========================================================================

    function getLogoHtml(size) {
        if (KOMAL_LOGO !== 'KOMAL_YT_LOGO_BASE64' && KOMAL_LOGO.length > 30) {
            return '<img src="' + KOMAL_LOGO + '" style="width:' + size + 'px;height:' + size + 'px;object-fit:contain;margin-bottom:12px" />';
        }
        return '<div style="font-size:' + Math.round(size * 0.75) + 'px;margin-bottom:12px">&#x1F6E1;&#xFE0F;</div>';
    }

    function showOverlay() {
        removeOverlay();
        var container = getPlayerContainer();
        if (!container) return;

        overlayElement = document.createElement('div');
        overlayElement.id = 'komal-yt-overlay';
        overlayElement.style.cssText = [
            'position: absolute',
            'top: 0', 'left: 0', 'right: 0', 'bottom: 0',
            'z-index: 99999',
            'display: flex', 'align-items: center', 'justify-content: center', 'flex-direction: column',
            'background: #FFF5F8',
            'border-radius: 12px', 'border: 2px solid #FFB6C1',
            'font-family: -apple-system, BlinkMacSystemFont, sans-serif'
        ].join(';');

        overlayElement.innerHTML = [
            getLogoHtml(60),
            '<div style="font-weight:600;font-size:15px;color:#8B4560;margin-bottom:6px">Komal is checking this video...</div>',
            '<div style="font-size:12px;color:#B07090">Making sure it\'s safe for you</div>'
        ].join('');

        container.style.position = 'relative';
        container.appendChild(overlayElement);
    }

    function showBlockedOverlay(reason) {
        removeOverlay();
        var container = getPlayerContainer();
        if (!container) return;

        overlayElement = document.createElement('div');
        overlayElement.id = 'komal-yt-overlay';
        overlayElement.style.cssText = [
            'position: absolute',
            'top: 0', 'left: 0', 'right: 0', 'bottom: 0',
            'z-index: 99999',
            'display: flex', 'align-items: center', 'justify-content: center', 'flex-direction: column',
            'background: #FFF5F8',
            'border-radius: 12px', 'border: 2px solid #FFB6C1',
            'font-family: -apple-system, BlinkMacSystemFont, sans-serif'
        ].join(';');

        overlayElement.innerHTML = [
            getLogoHtml(80),
            '<div style="font-weight:600;font-size:15px;color:#8B4560;margin-bottom:6px">This video isn\'t safe right now</div>',
            '<div style="font-size:12px;color:#B07090;margin-bottom:16px">' + escapeHtml(reason) + '</div>',
            '<div style="font-size:12px;color:#C8A0B0">Going back...</div>'
        ].join('');

        container.style.position = 'relative';
        container.appendChild(overlayElement);
    }

    function removeOverlay() {
        var existing = document.querySelector('#komal-yt-overlay');
        if (existing) existing.remove();
        overlayElement = null;
    }

    function escapeHtml(str) {
        if (!str) return '';
        var div = document.createElement('div');
        div.textContent = str;
        return div.innerHTML;
    }

    // =========================================================================
    // Metadata Extraction — uses ytInitialPlayerResponse + DOM fallbacks
    // =========================================================================

    function extractMetadata(videoId) {
        var title = '';
        var description = '';
        var channelName = '';
        var thumbnailUrl = '';

        // Strategy 1: ytInitialPlayerResponse (YouTube's own data, most reliable on SPA nav)
        try {
            var playerResp = window.ytInitialPlayerResponse;
            if (playerResp && playerResp.videoDetails) {
                var vd = playerResp.videoDetails;
                if (vd.videoId === videoId) {
                    title = vd.title || '';
                    description = (vd.shortDescription || '').substring(0, 2000);
                    channelName = vd.author || '';
                    thumbnailUrl = (vd.thumbnail && vd.thumbnail.thumbnails && vd.thumbnail.thumbnails.length > 0)
                        ? vd.thumbnail.thumbnails[vd.thumbnail.thumbnails.length - 1].url : '';
                }
            }
        } catch (e) {}

        // Strategy 2: ytInitialData (contains video metadata on watch pages)
        if (!title) {
            try {
                var initData = window.ytInitialData;
                if (initData) {
                    var contents = initData.contents;
                    if (contents && contents.twoColumnWatchNextResults) {
                        var primary = contents.twoColumnWatchNextResults.results &&
                                      contents.twoColumnWatchNextResults.results.results &&
                                      contents.twoColumnWatchNextResults.results.results.contents;
                        if (primary) {
                            for (var i = 0; i < primary.length; i++) {
                                var vpm = primary[i].videoPrimaryInfoRenderer;
                                if (vpm && vpm.title && vpm.title.runs) {
                                    title = vpm.title.runs.map(function(r) { return r.text; }).join('');
                                }
                                var vsm = primary[i].videoSecondaryInfoRenderer;
                                if (vsm && vsm.owner && vsm.owner.videoOwnerRenderer) {
                                    var ownerTitle = vsm.owner.videoOwnerRenderer.title;
                                    if (ownerTitle && ownerTitle.runs) {
                                        channelName = ownerTitle.runs.map(function(r) { return r.text; }).join('');
                                    }
                                }
                            }
                        }
                    }
                }
            } catch (e) {}
        }

        // Strategy 3: DOM selectors (desktop ytd-* + mobile ytm-*)
        if (!title) {
            var titleEl = document.querySelector('meta[property="og:title"]');
            if (titleEl) title = titleEl.getAttribute('content') || '';
        }
        if (!title) {
            // Desktop
            var h1 = document.querySelector('ytd-watch-metadata h1 yt-formatted-string') ||
                     document.querySelector('h1.ytd-video-primary-info-renderer') ||
                     // Mobile
                     document.querySelector('ytm-slim-video-metadata-section-renderer h2');
            if (h1) title = h1.textContent.trim();
        }
        if (!title) {
            title = document.title.replace(/ - YouTube$/, '').trim();
        }

        if (!description) {
            var descMeta = document.querySelector('meta[property="og:description"]');
            if (descMeta) description = descMeta.getAttribute('content') || '';
        }
        if (!description) {
            var descEl = document.querySelector('#description-text') ||
                         document.querySelector('ytd-text-inline-expander #plain-snippet-text') ||
                         document.querySelector('ytm-expandable-video-description-body-renderer');
            if (descEl) description = descEl.textContent.trim().substring(0, 2000);
        }

        if (!channelName) {
            var chEl = document.querySelector('ytd-channel-name a') ||
                       document.querySelector('#channel-name a') ||
                       document.querySelector('ytm-slim-owner-renderer .yt-core-attributed-string') ||
                       document.querySelector('link[itemprop="name"]');
            if (chEl) {
                channelName = chEl.textContent ? chEl.textContent.trim() :
                             (chEl.getAttribute('content') || '');
            }
        }

        if (!thumbnailUrl) {
            var ogImage = document.querySelector('meta[property="og:image"]');
            if (ogImage) thumbnailUrl = ogImage.getAttribute('content') || '';
        }
        if (!thumbnailUrl) {
            thumbnailUrl = 'https://i.ytimg.com/vi/' + videoId + '/maxresdefault.jpg';
        }

        return {
            videoId: videoId,
            title: title,
            description: description,
            channelName: channelName,
            thumbnailUrl: thumbnailUrl,
            pageUrl: window.location.href
        };
    }

    // =========================================================================
    // Native Communication
    // =========================================================================

    function sendToNative(data) {
        try {
            if (window.webkit && window.webkit.messageHandlers &&
                window.webkit.messageHandlers.komalYouTubeScanner) {
                window.webkit.messageHandlers.komalYouTubeScanner.postMessage(data);
            }
        } catch (e) {
            console.error('[KomalYT] Failed to send to native:', e);
        }
    }

    // =========================================================================
    // Core Video Check Logic
    // =========================================================================

    function checkCurrentPage() {
        var urlStr = window.location.href;
        if (urlStr === lastCheckedUrl) return;
        lastCheckedUrl = urlStr;

        var videoId = extractVideoId(urlStr);

        if (!videoId) {
            // Non-video page — clean up
            if (currentVideoId) {
                currentVideoId = null;
                pendingVideoId = null;
                revealVideoPlayer();
            }
            return;
        }

        // Same video — skip
        if (videoId === currentVideoId) return;

        currentVideoId = videoId;

        // Check block cache — instant block for previously-blocked videos
        if (blockedVideoIds[videoId]) {
            hideVideoPlayer();
            showBlockedOverlay(blockedVideoIds[videoId]);
            navigateBack();
            return;
        }

        // Every video is re-analyzed fresh (no allow cache) to ensure
        // content decisions stay current and aren't blindly carried forward
        pendingVideoId = videoId;
        hideVideoPlayer();

        // Attempt metadata extraction with retries
        // YouTube SPA updates ytInitialPlayerResponse async, so we try multiple times
        var metadataAttempt = 0;
        var maxAttempts = 4;
        var capturedVideoId = videoId;

        function tryExtractAndSend() {
            if (pendingVideoId !== capturedVideoId) return; // User navigated away
            metadataAttempt++;

            var metadata = extractMetadata(capturedVideoId);

            // If we got a title, send it. Otherwise retry (up to maxAttempts)
            if (metadata.title || metadataAttempt >= maxAttempts) {
                sendToNative({
                    type: 'videoDetected',
                    videoId: metadata.videoId,
                    title: metadata.title,
                    description: metadata.description,
                    channelName: metadata.channelName,
                    thumbnailUrl: metadata.thumbnailUrl,
                    pageUrl: metadata.pageUrl
                });
            } else {
                setTimeout(tryExtractAndSend, 500);
            }
        }

        setTimeout(tryExtractAndSend, 300);

        // Timeout: fail-closed after 12 seconds
        setTimeout(function() {
            if (pendingVideoId === capturedVideoId) {
                pendingVideoId = null;
                if (!blockedVideoIds[capturedVideoId]) {
                    addToBlocked(capturedVideoId, 'Analysis timed out');
                }
                showBlockedOverlay('Could not verify this video');
                navigateBack();
            }
        }, 12000);
    }

    function navigateBack() {
        setTimeout(function() {
            if (window.history.length > 1) {
                window.history.back();
            } else {
                window.location.href = 'https://www.youtube.com';
            }
        }, 2000);
    }

    // =========================================================================
    // SPA Navigation Detection — 3 complementary strategies
    // =========================================================================

    // Strategy 1: YouTube's own SPA events (most reliable)
    document.addEventListener('yt-navigate-finish', function() {
        setTimeout(checkCurrentPage, 50);
    });
    document.addEventListener('yt-page-data-updated', function() {
        setTimeout(checkCurrentPage, 50);
    });

    // Strategy 2: history.pushState/replaceState override (non-configurable to resist re-override)
    var originalPushState = history.pushState;
    var originalReplaceState = history.replaceState;

    try {
        Object.defineProperty(history, 'pushState', {
            configurable: false,
            writable: false,
            value: function() {
                originalPushState.apply(this, arguments);
                setTimeout(checkCurrentPage, 100);
            }
        });
    } catch (e) {
        // Fallback if defineProperty fails
        history.pushState = function() {
            originalPushState.apply(this, arguments);
            setTimeout(checkCurrentPage, 100);
        };
    }

    try {
        Object.defineProperty(history, 'replaceState', {
            configurable: false,
            writable: false,
            value: function() {
                originalReplaceState.apply(this, arguments);
                setTimeout(checkCurrentPage, 100);
            }
        });
    } catch (e) {
        history.replaceState = function() {
            originalReplaceState.apply(this, arguments);
            setTimeout(checkCurrentPage, 100);
        };
    }

    window.addEventListener('popstate', function() {
        setTimeout(checkCurrentPage, 100);
    });

    // Strategy 3: URL polling fallback (catches anything else)
    urlPollInterval = setInterval(function() {
        if (window.location.href !== lastCheckedUrl) {
            checkCurrentPage();
        }
    }, 500);

    // =========================================================================
    // Public API (called from native via evaluateJavaScript)
    // =========================================================================

    window.komalYouTubeScanner = {
        allowVideo: function(videoId, nonce) {
            if (nonce !== SECURITY_NONCE) return; // Reject calls without valid nonce
            delete blockedVideoIds[videoId]; // Clear any stale block
            if (pendingVideoId === videoId) {
                pendingVideoId = null;
            }
            if (currentVideoId === videoId) {
                revealVideoPlayer();
            }
        },

        blockVideo: function(videoId, reason, nonce) {
            if (nonce !== SECURITY_NONCE) return; // Reject calls without valid nonce
            addToBlocked(videoId, reason || 'Blocked by Komal');
            if (pendingVideoId === videoId) {
                pendingVideoId = null;
            }
            if (currentVideoId === videoId) {
                hideVideoPlayer();
                showBlockedOverlay(blockedVideoIds[videoId]);
                navigateBack();
            }
        },

        getState: function() {
            return {
                currentVideoId: currentVideoId,
                pendingVideoId: pendingVideoId,
                blockedCount: Object.keys(blockedVideoIds).length,
                lastCheckedUrl: lastCheckedUrl
            };
        }
    };

    // =========================================================================
    // Restricted Mode Cookie Enforcer
    // YouTube may overwrite the PREF cookie during SPA navigation.
    // Re-set the restricted mode flag (f2=8000000) every 30 seconds.
    // =========================================================================

    function enforceRestrictedMode() {
        try {
            var cookies = document.cookie.split(';');
            var prefFound = false;
            for (var i = 0; i < cookies.length; i++) {
                var c = cookies[i].trim();
                if (c.indexOf('PREF=') === 0) {
                    prefFound = true;
                    if (c.indexOf('f2=8000000') === -1) {
                        // PREF exists but restricted mode flag is missing — re-set it
                        document.cookie = 'PREF=f2=8000000; domain=.youtube.com; path=/; max-age=31536000; secure';
                    }
                    break;
                }
            }
            if (!prefFound) {
                document.cookie = 'PREF=f2=8000000; domain=.youtube.com; path=/; max-age=31536000; secure';
            }
        } catch (e) {}
    }

    enforceRestrictedMode();
    setInterval(enforceRestrictedMode, 30000);

    // =========================================================================
    // Initialization
    // =========================================================================

    // Run immediately — don't wait
    checkCurrentPage();

    // Also run on DOMContentLoaded and load as safety nets
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', checkCurrentPage);
    }
    window.addEventListener('load', function() {
        setTimeout(checkCurrentPage, 200);
    });

})();
