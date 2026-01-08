/**
 * LinkInterceptor.jsx
 * Global link interception for content filtering
 *
 * Intercepts all link clicks in the app and applies content filtering
 */

import { useEffect } from 'react';
import contentFilterService from '../services/ContentFilterService';

const LinkInterceptor = () => {
  useEffect(() => {
    // Only intercept on iOS native platform
    if (!contentFilterService.isAvailable) {
      return;
    }

    const handleClick = async (e) => {
      // Find the closest anchor tag
      const link = e.target.closest('a');

      if (!link) return;

      const href = link.getAttribute('href');

      // Ignore internal navigation links
      if (!href || href.startsWith('#') || href.startsWith('/') || href.startsWith('javascript:')) {
        return;
      }

      // Ignore if it's already a SafeLink (has data-safe-link attribute)
      if (link.hasAttribute('data-safe-link')) {
        return;
      }

      // Intercept external links
      e.preventDefault();
      e.stopPropagation();

      try {
        // Check URL with content filter
        const result = await contentFilterService.checkURL(href);

        if (result.shouldAllow) {
          // URL is safe, open it
          const target = link.getAttribute('target');
          if (target === '_blank') {
            window.open(href, '_blank', 'noopener,noreferrer');
          } else {
            window.location.href = href;
          }
        } else {
          // URL is blocked, show alert
          const message = result.reason || 'This content has been blocked for your safety.';
          alert(`🛡️ Content Blocked\n\n${message}\n\nIf you think this is a mistake, ask your parent or guardian to adjust the settings.`);
        }
      } catch (error) {
        console.error('Link interception error:', error);
        // On error, allow the link (fail open)
        const target = link.getAttribute('target');
        if (target === '_blank') {
          window.open(href, '_blank', 'noopener,noreferrer');
        } else {
          window.location.href = href;
        }
      }
    };

    // Add click listener to document
    document.addEventListener('click', handleClick, true);

    // Cleanup
    return () => {
      document.removeEventListener('click', handleClick, true);
    };
  }, []);

  // This component doesn't render anything
  return null;
};

export default LinkInterceptor;
