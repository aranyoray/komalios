#!/usr/bin/env python3
"""
slow_network_mode.py - Reduce resolution and defer analytics on slow networks

Detects network quality, reduces data usage, defers analytics until fast
network is detected, and provides UI hooks for offline mode.
"""

import argparse
import json
import time
import socket
import logging
from datetime import datetime
from typing import Dict, List, Optional
from collections import deque

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class NetworkQualityDetector:
    """Detect network quality and type."""

    def __init__(self):
        self.latency_history = deque(maxlen=10)
        self.bandwidth_history = deque(maxlen=5)

    def measure_latency(self, host: str = '8.8.8.8', port: int = 53) -> float:
        """Measure network latency in ms."""
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(5)

            start = time.time()
            sock.connect((host, port))
            latency = (time.time() - start) * 1000

            sock.close()

            self.latency_history.append(latency)
            return latency
        except:
            return float('inf')

    def estimate_bandwidth(self) -> float:
        """Estimate bandwidth based on latency patterns (simplified)."""
        if not self.latency_history:
            return 0.0

        avg_latency = sum(self.latency_history) / len(self.latency_history)

        # Rough estimation based on latency
        if avg_latency < 50:
            return 50.0  # Fast WiFi
        elif avg_latency < 100:
            return 20.0  # Good connection
        elif avg_latency < 300:
            return 5.0   # Slow connection
        elif avg_latency < 1000:
            return 1.0   # Very slow
        else:
            return 0.1   # Near offline

    def get_network_quality(self) -> Dict:
        """Get overall network quality assessment."""
        latency = self.measure_latency()
        bandwidth = self.estimate_bandwidth()

        if latency == float('inf'):
            quality = 'offline'
            level = 0
        elif latency < 50 and bandwidth > 20:
            quality = 'excellent'
            level = 5
        elif latency < 100 and bandwidth > 10:
            quality = 'good'
            level = 4
        elif latency < 200 and bandwidth > 5:
            quality = 'fair'
            level = 3
        elif latency < 500:
            quality = 'poor'
            level = 2
        else:
            quality = 'very_poor'
            level = 1

        return {
            'quality': quality,
            'level': level,
            'latency_ms': latency if latency != float('inf') else -1,
            'bandwidth_mbps': bandwidth
        }


class DeferredAnalyticsQueue:
    """Queue analytics for deferred upload."""

    def __init__(self, max_size: int = 1000):
        self.queue = deque(maxlen=max_size)
        self.uploaded_count = 0

    def enqueue(self, data: Dict):
        """Add analytics to queue."""
        entry = {
            'data': data,
            'timestamp': time.time(),
            'attempts': 0
        }
        self.queue.append(entry)
        logger.debug(f"Queued analytics, total: {len(self.queue)}")

    def get_pending(self, max_items: int = 100) -> List[Dict]:
        """Get pending items for upload."""
        items = []
        for i, entry in enumerate(self.queue):
            if i >= max_items:
                break
            items.append(entry)
        return items

    def mark_uploaded(self, count: int):
        """Mark items as uploaded."""
        for _ in range(min(count, len(self.queue))):
            self.queue.popleft()
            self.uploaded_count += 1

    def get_stats(self) -> Dict:
        """Get queue statistics."""
        return {
            'pending': len(self.queue),
            'uploaded': self.uploaded_count,
            'oldest_age_s': time.time() - self.queue[0]['timestamp'] if self.queue else 0
        }


class SlowNetworkMode:
    """Main slow network mode manager."""

    def __init__(self, config: Dict):
        self.config = config
        self.detector = NetworkQualityDetector()
        self.analytics_queue = DeferredAnalyticsQueue()

        # Settings by network quality
        self.quality_settings = {
            'offline': {
                'resolution': 'minimal',
                'sync_enabled': False,
                'defer_analytics': True,
                'cache_models': True,
                'ui_mode': 'offline'
            },
            'very_poor': {
                'resolution': 'low',
                'sync_enabled': False,
                'defer_analytics': True,
                'cache_models': True,
                'ui_mode': 'limited'
            },
            'poor': {
                'resolution': 'low',
                'sync_enabled': True,
                'sync_interval': 300,
                'defer_analytics': True,
                'cache_models': True,
                'ui_mode': 'limited'
            },
            'fair': {
                'resolution': 'medium',
                'sync_enabled': True,
                'sync_interval': 120,
                'defer_analytics': False,
                'cache_models': False,
                'ui_mode': 'normal'
            },
            'good': {
                'resolution': 'high',
                'sync_enabled': True,
                'sync_interval': 60,
                'defer_analytics': False,
                'cache_models': False,
                'ui_mode': 'normal'
            },
            'excellent': {
                'resolution': 'high',
                'sync_enabled': True,
                'sync_interval': 30,
                'defer_analytics': False,
                'cache_models': False,
                'ui_mode': 'full'
            }
        }

        self.current_quality = None
        self.mode_changes = []

    def get_settings(self) -> Dict:
        """Get current recommended settings based on network."""
        quality = self.detector.get_network_quality()
        settings = self.quality_settings.get(quality['quality'],
                                             self.quality_settings['poor'])

        # Track mode changes
        if self.current_quality != quality['quality']:
            self.mode_changes.append({
                'from': self.current_quality,
                'to': quality['quality'],
                'timestamp': datetime.now().isoformat()
            })
            self.current_quality = quality['quality']
            logger.info(f"Network quality: {quality['quality']} "
                       f"(latency: {quality['latency_ms']:.0f}ms)")

        return {
            'network': quality,
            'settings': settings
        }

    def submit_analytics(self, data: Dict) -> Dict:
        """Submit analytics, deferring if needed."""
        state = self.get_settings()

        if state['settings']['defer_analytics']:
            self.analytics_queue.enqueue(data)
            return {
                'deferred': True,
                'queue_size': len(self.analytics_queue.queue),
                'reason': f"Network quality: {state['network']['quality']}"
            }
        else:
            # Would upload immediately
            return {
                'deferred': False,
                'uploaded': True
            }

    def process_deferred_analytics(self) -> Dict:
        """Process deferred analytics if network is good."""
        state = self.get_settings()

        if state['settings']['defer_analytics']:
            return {
                'processed': 0,
                'reason': 'Still in defer mode'
            }

        pending = self.analytics_queue.get_pending()

        if not pending:
            return {'processed': 0, 'reason': 'Queue empty'}

        # Simulate upload
        uploaded = len(pending)
        self.analytics_queue.mark_uploaded(uploaded)

        logger.info(f"Uploaded {uploaded} deferred analytics items")

        return {
            'processed': uploaded,
            'remaining': len(self.analytics_queue.queue)
        }

    def get_ui_hooks(self) -> Dict:
        """Get UI configuration hooks for current network state."""
        state = self.get_settings()

        hooks = {
            'show_offline_banner': state['settings']['ui_mode'] == 'offline',
            'show_limited_banner': state['settings']['ui_mode'] == 'limited',
            'enable_cloud_features': state['settings']['sync_enabled'],
            'asset_quality': state['settings']['resolution'],
            'sync_status': {
                'enabled': state['settings']['sync_enabled'],
                'last_sync': None,
                'next_sync_in': state['settings'].get('sync_interval', 0)
            },
            'deferred_count': len(self.analytics_queue.queue)
        }

        # Offline mode messaging
        if state['settings']['ui_mode'] == 'offline':
            hooks['message'] = "You're offline. Activities are saved and will sync when connected."
            hooks['icon'] = 'cloud_off'
        elif state['settings']['ui_mode'] == 'limited':
            hooks['message'] = "Slow connection. Some features are limited."
            hooks['icon'] = 'signal_cellular_1_bar'

        return hooks

    def get_stats(self) -> Dict:
        """Get network mode statistics."""
        return {
            'current_quality': self.current_quality,
            'mode_changes': len(self.mode_changes),
            'analytics_queue': self.analytics_queue.get_stats(),
            'recent_latency': list(self.detector.latency_history)
        }


def run_demo(mode_manager: SlowNetworkMode, duration: int = 30):
    """Run demo of slow network mode."""
    logger.info(f"Running slow network mode demo for {duration}s")

    start = time.time()

    while time.time() - start < duration:
        # Get current settings
        state = mode_manager.get_settings()

        # Simulate analytics submission
        analytics = {
            'type': 'session_metric',
            'attention': 0.85,
            'timestamp': datetime.now().isoformat()
        }

        result = mode_manager.submit_analytics(analytics)

        # Try to process deferred
        processed = mode_manager.process_deferred_analytics()

        # Get UI hooks
        hooks = mode_manager.get_ui_hooks()

        logger.info(
            f"Quality: {state['network']['quality']} | "
            f"Resolution: {state['settings']['resolution']} | "
            f"Deferred: {hooks['deferred_count']} | "
            f"UI: {hooks.get('message', 'Normal')}"
        )

        time.sleep(3)

    # Final stats
    stats = mode_manager.get_stats()
    logger.info(f"\n=== Final Stats ===")
    logger.info(f"Mode changes: {stats['mode_changes']}")
    logger.info(f"Analytics queued: {stats['analytics_queue']['pending']}")
    logger.info(f"Analytics uploaded: {stats['analytics_queue']['uploaded']}")


def main():
    parser = argparse.ArgumentParser(description='Slow network mode manager')
    parser.add_argument('--duration', type=int, default=30, help='Demo duration seconds')
    parser.add_argument('--demo', action='store_true', help='Run demo')

    args = parser.parse_args()

    config = {}
    mode_manager = SlowNetworkMode(config)

    if args.demo:
        run_demo(mode_manager, args.duration)
    else:
        # Single check
        state = mode_manager.get_settings()
        hooks = mode_manager.get_ui_hooks()

        logger.info(f"Network quality: {state['network']['quality']}")
        logger.info(f"Latency: {state['network']['latency_ms']}ms")
        logger.info(f"Resolution: {state['settings']['resolution']}")
        logger.info(f"Sync enabled: {state['settings']['sync_enabled']}")
        logger.info(f"UI mode: {state['settings']['ui_mode']}")

        if hooks.get('message'):
            logger.info(f"Message: {hooks['message']}")


if __name__ == '__main__':
    main()
