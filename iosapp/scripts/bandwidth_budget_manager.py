#!/usr/bin/env python3
"""
bandwidth_budget_manager.py - Enforce bandwidth caps and optimize uploads

Enforces per-day/month bandwidth caps, delays heavy uploads to WiFi,
compresses JSONs, and uses efficient protocols for uploads.
"""

import argparse
import json
import gzip
import time
import os
import logging
from datetime import datetime, date
from pathlib import Path
from typing import Dict, List, Optional
import hashlib

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class NetworkDetector:
    """Detect current network type."""

    def get_network_type(self) -> str:
        """Get current network type: wifi, cellular, or offline."""
        # Try to detect via platform-specific methods
        # For demo, check if we can resolve DNS quickly

        try:
            import socket
            socket.setdefaulttimeout(1)
            socket.socket(socket.AF_INET, socket.SOCK_STREAM).connect(("8.8.8.8", 53))

            # In real implementation, would check NetworkManager, iOS/Android APIs
            # For demo, assume wifi
            return 'wifi'
        except:
            return 'offline'

    def get_bandwidth_estimate(self) -> float:
        """Estimate available bandwidth in Mbps."""
        network = self.get_network_type()

        estimates = {
            'wifi': 50.0,
            'cellular': 5.0,
            'offline': 0.0
        }

        return estimates.get(network, 1.0)


class BandwidthBudgetManager:
    """Manage bandwidth usage with budgets and optimization."""

    def __init__(self, config: Dict, state_path: str = 'bandwidth_state.json'):
        self.config = config
        self.state_path = state_path
        self.network = NetworkDetector()

        # Budgets
        self.daily_budget_mb = config.get('daily_budget_mb', 100)
        self.monthly_budget_mb = config.get('monthly_budget_mb', 2000)

        # Load state
        self.state = self._load_state()

        # Pending uploads
        self.pending_uploads = []

    def _load_state(self) -> Dict:
        """Load usage state from disk."""
        if os.path.exists(self.state_path):
            with open(self.state_path, 'r') as f:
                return json.load(f)

        return {
            'daily_usage': {},
            'monthly_usage': {},
            'total_uploaded': 0,
            'total_compressed_saved': 0
        }

    def _save_state(self):
        """Save usage state to disk."""
        with open(self.state_path, 'w') as f:
            json.dump(self.state, f, indent=2)

    def _get_today(self) -> str:
        return date.today().isoformat()

    def _get_month(self) -> str:
        return date.today().strftime('%Y-%m')

    def get_daily_usage(self) -> float:
        """Get today's usage in MB."""
        return self.state['daily_usage'].get(self._get_today(), 0)

    def get_monthly_usage(self) -> float:
        """Get this month's usage in MB."""
        return self.state['monthly_usage'].get(self._get_month(), 0)

    def get_remaining_budget(self) -> Dict:
        """Get remaining bandwidth budget."""
        daily_remaining = self.daily_budget_mb - self.get_daily_usage()
        monthly_remaining = self.monthly_budget_mb - self.get_monthly_usage()

        return {
            'daily_remaining_mb': max(0, daily_remaining),
            'monthly_remaining_mb': max(0, monthly_remaining),
            'daily_usage_percent': (self.get_daily_usage() / self.daily_budget_mb) * 100,
            'monthly_usage_percent': (self.get_monthly_usage() / self.monthly_budget_mb) * 100
        }

    def record_usage(self, bytes_used: int):
        """Record bandwidth usage."""
        mb_used = bytes_used / (1024 * 1024)

        today = self._get_today()
        month = self._get_month()

        self.state['daily_usage'][today] = self.state['daily_usage'].get(today, 0) + mb_used
        self.state['monthly_usage'][month] = self.state['monthly_usage'].get(month, 0) + mb_used
        self.state['total_uploaded'] += bytes_used

        self._save_state()

    def can_upload(self, size_bytes: int, priority: str = 'normal') -> Dict:
        """Check if upload is allowed within budget."""
        size_mb = size_bytes / (1024 * 1024)
        budget = self.get_remaining_budget()
        network = self.network.get_network_type()

        # Priority thresholds
        priority_limits = {
            'critical': {'daily_min': 0.1, 'require_wifi': False},
            'high': {'daily_min': 0.2, 'require_wifi': False},
            'normal': {'daily_min': 0.3, 'require_wifi': True},
            'low': {'daily_min': 0.5, 'require_wifi': True}
        }

        limits = priority_limits.get(priority, priority_limits['normal'])

        # Check network
        if network == 'offline':
            return {
                'allowed': False,
                'reason': 'No network connection',
                'should_queue': True
            }

        if limits['require_wifi'] and network != 'wifi':
            return {
                'allowed': False,
                'reason': 'Waiting for WiFi',
                'should_queue': True
            }

        # Check daily budget
        daily_threshold = self.daily_budget_mb * limits['daily_min']
        if budget['daily_remaining_mb'] < size_mb and budget['daily_remaining_mb'] < daily_threshold:
            return {
                'allowed': False,
                'reason': f'Daily budget exceeded ({budget["daily_remaining_mb"]:.1f}MB remaining)',
                'should_queue': True
            }

        # Check monthly budget
        if budget['monthly_remaining_mb'] < size_mb:
            return {
                'allowed': False,
                'reason': f'Monthly budget exceeded ({budget["monthly_remaining_mb"]:.1f}MB remaining)',
                'should_queue': False
            }

        return {
            'allowed': True,
            'reason': 'Within budget',
            'should_queue': False
        }

    def compress_json(self, data: Dict) -> bytes:
        """Compress JSON data."""
        json_str = json.dumps(data, separators=(',', ':'))
        compressed = gzip.compress(json_str.encode('utf-8'))

        original_size = len(json_str.encode('utf-8'))
        compressed_size = len(compressed)
        saved = original_size - compressed_size

        self.state['total_compressed_saved'] += saved

        logger.debug(f"Compressed {original_size} -> {compressed_size} bytes ({saved} saved)")

        return compressed

    def queue_upload(self, data: Dict, endpoint: str, priority: str = 'normal'):
        """Queue data for upload."""
        compressed = self.compress_json(data)

        upload = {
            'id': hashlib.md5(compressed).hexdigest()[:8],
            'data': compressed,
            'endpoint': endpoint,
            'priority': priority,
            'size': len(compressed),
            'queued_at': time.time()
        }

        self.pending_uploads.append(upload)
        logger.info(f"Queued upload {upload['id']} ({len(compressed)} bytes, {priority})")

        return upload['id']

    def process_queue(self) -> List[Dict]:
        """Process pending uploads."""
        results = []

        # Sort by priority
        priority_order = {'critical': 0, 'high': 1, 'normal': 2, 'low': 3}
        self.pending_uploads.sort(key=lambda x: priority_order.get(x['priority'], 2))

        completed = []

        for upload in self.pending_uploads:
            check = self.can_upload(upload['size'], upload['priority'])

            if check['allowed']:
                # Simulate upload
                result = self._do_upload(upload)
                results.append(result)

                if result['success']:
                    completed.append(upload)
                    self.record_usage(upload['size'])
            elif not check['should_queue']:
                # Remove from queue if shouldn't retry
                completed.append(upload)
                results.append({
                    'id': upload['id'],
                    'success': False,
                    'reason': check['reason']
                })

        # Remove completed uploads
        for upload in completed:
            if upload in self.pending_uploads:
                self.pending_uploads.remove(upload)

        return results

    def _do_upload(self, upload: Dict) -> Dict:
        """Perform the actual upload (simulated)."""
        # In real implementation, would use aiohttp/requests
        # with retries, exponential backoff, etc.

        # Simulate network delay
        bandwidth = self.network.get_bandwidth_estimate()
        time_seconds = (upload['size'] / 1024 / 1024) / bandwidth * 8

        logger.info(f"Uploading {upload['id']} to {upload['endpoint']} "
                   f"({upload['size']} bytes, ~{time_seconds:.2f}s)")

        return {
            'id': upload['id'],
            'success': True,
            'size': upload['size'],
            'endpoint': upload['endpoint'],
            'duration': time_seconds
        }

    def get_stats(self) -> Dict:
        """Get bandwidth usage statistics."""
        return {
            'daily_usage_mb': self.get_daily_usage(),
            'monthly_usage_mb': self.get_monthly_usage(),
            'budget': self.get_remaining_budget(),
            'total_uploaded_bytes': self.state['total_uploaded'],
            'total_compressed_saved_bytes': self.state['total_compressed_saved'],
            'pending_uploads': len(self.pending_uploads),
            'network_type': self.network.get_network_type()
        }


def main():
    parser = argparse.ArgumentParser(description='Bandwidth budget manager')
    parser.add_argument('--daily-budget', type=float, default=100, help='Daily budget in MB')
    parser.add_argument('--monthly-budget', type=float, default=2000, help='Monthly budget in MB')
    parser.add_argument('--state-path', type=str, default='bandwidth_state.json', help='State file')
    parser.add_argument('--demo', action='store_true', help='Run demo')

    args = parser.parse_args()

    config = {
        'daily_budget_mb': args.daily_budget,
        'monthly_budget_mb': args.monthly_budget
    }

    manager = BandwidthBudgetManager(config, args.state_path)

    if args.demo:
        # Demo: queue some uploads
        for i in range(5):
            data = {
                'session_id': f'session_{i}',
                'metrics': {'attention': 0.8, 'engagement': 0.7},
                'timestamp': datetime.now().isoformat()
            }

            priorities = ['critical', 'high', 'normal', 'low', 'normal']
            manager.queue_upload(data, '/api/metrics', priorities[i])

        # Process queue
        results = manager.process_queue()

        logger.info(f"\n=== Upload Results ===")
        for r in results:
            status = "OK" if r['success'] else f"FAILED: {r.get('reason', 'unknown')}"
            logger.info(f"{r['id']}: {status}")

    # Show stats
    stats = manager.get_stats()
    logger.info(f"\n=== Bandwidth Stats ===")
    logger.info(f"Network: {stats['network_type']}")
    logger.info(f"Daily usage: {stats['daily_usage_mb']:.2f} MB")
    logger.info(f"Monthly usage: {stats['monthly_usage_mb']:.2f} MB")
    logger.info(f"Daily remaining: {stats['budget']['daily_remaining_mb']:.2f} MB")
    logger.info(f"Compression saved: {stats['total_compressed_saved_bytes']} bytes")
    logger.info(f"Pending uploads: {stats['pending_uploads']}")


if __name__ == '__main__':
    main()
