#!/usr/bin/env python3
"""
quantized_adapter_selector.py - Download and switch LoRA adapters dynamically

Downloads only needed adapters for device profile and switches them at runtime.
"""

import argparse
import json
import hashlib
import numpy as np
import logging
from pathlib import Path
from typing import Dict, List, Optional

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class AdapterRegistry:
    """Registry of available adapters."""

    def __init__(self):
        self.adapters = {
            'emotion_basic': {
                'size_mb': 2,
                'rank': 4,
                'accuracy': 0.85,
                'tasks': ['emotion'],
                'device_tier': 'low'
            },
            'emotion_full': {
                'size_mb': 8,
                'rank': 16,
                'accuracy': 0.92,
                'tasks': ['emotion'],
                'device_tier': 'high'
            },
            'attention_basic': {
                'size_mb': 1.5,
                'rank': 4,
                'accuracy': 0.82,
                'tasks': ['attention'],
                'device_tier': 'low'
            },
            'attention_full': {
                'size_mb': 6,
                'rank': 16,
                'accuracy': 0.90,
                'tasks': ['attention'],
                'device_tier': 'high'
            },
            'multimodal': {
                'size_mb': 15,
                'rank': 32,
                'accuracy': 0.94,
                'tasks': ['emotion', 'attention', 'voice'],
                'device_tier': 'high'
            }
        }


class QuantizedAdapterSelector:
    """Select and manage LoRA adapters."""

    def __init__(self, config: Dict):
        self.config = config
        self.registry = AdapterRegistry()
        self.cache_dir = Path(config.get('cache_dir', '.adapter_cache'))
        self.cache_dir.mkdir(exist_ok=True)

        self.loaded_adapter = None
        self.download_log = []

    def get_device_tier(self) -> str:
        """Detect device tier."""
        import os
        cores = os.cpu_count() or 2
        return 'high' if cores >= 4 else 'low'

    def select_adapter(self, task: str, device_tier: Optional[str] = None) -> str:
        """Select best adapter for task and device."""
        if device_tier is None:
            device_tier = self.get_device_tier()

        candidates = []

        for name, info in self.registry.adapters.items():
            if task in info['tasks']:
                # Check device compatibility
                if device_tier == 'low' and info['device_tier'] == 'high':
                    if info['size_mb'] > 5:  # Too big for low-tier
                        continue

                candidates.append((name, info))

        if not candidates:
            return None

        # Select best by accuracy for device
        candidates.sort(key=lambda x: x[1]['accuracy'], reverse=True)

        # For low-tier, prefer smaller
        if device_tier == 'low':
            candidates.sort(key=lambda x: x[1]['size_mb'])

        return candidates[0][0]

    def download_adapter(self, name: str) -> bool:
        """Download adapter to cache (simulated)."""
        if name not in self.registry.adapters:
            return False

        info = self.registry.adapters[name]
        cache_path = self.cache_dir / f"{name}.bin"

        if cache_path.exists():
            logger.debug(f"Adapter {name} already cached")
            return True

        # Simulate download
        logger.info(f"Downloading adapter {name} ({info['size_mb']} MB)")

        # Create fake adapter weights
        rank = info['rank']
        weights = np.random.randn(1000, rank).astype(np.float16)
        np.save(cache_path.with_suffix('.npy'), weights)

        self.download_log.append({
            'adapter': name,
            'size_mb': info['size_mb']
        })

        return True

    def load_adapter(self, name: str) -> bool:
        """Load adapter into memory."""
        if name not in self.registry.adapters:
            return False

        # Download if needed
        if not self.download_adapter(name):
            return False

        cache_path = self.cache_dir / f"{name}.npy"

        if cache_path.exists():
            # Would load weights here
            self.loaded_adapter = name
            logger.info(f"Loaded adapter: {name}")
            return True

        return False

    def switch_adapter(self, task: str) -> str:
        """Switch to best adapter for task."""
        best = self.select_adapter(task)

        if best and best != self.loaded_adapter:
            self.load_adapter(best)

        return self.loaded_adapter

    def get_stats(self) -> Dict:
        """Get adapter statistics."""
        cached = list(self.cache_dir.glob('*.npy'))
        cached_size = sum(f.stat().st_size for f in cached) / (1024**2)

        return {
            'loaded': self.loaded_adapter,
            'cached_count': len(cached),
            'cached_size_mb': cached_size,
            'downloads': len(self.download_log),
            'total_downloaded_mb': sum(d['size_mb'] for d in self.download_log)
        }


def main():
    parser = argparse.ArgumentParser(description='Quantized adapter selector')
    parser.add_argument('--task', type=str, default='emotion', help='Task to select adapter for')
    parser.add_argument('--device-tier', type=str, choices=['low', 'high'])
    parser.add_argument('--demo', action='store_true')

    args = parser.parse_args()

    selector = QuantizedAdapterSelector({})

    if args.demo:
        tasks = ['emotion', 'attention', 'emotion', 'attention']

        for task in tasks:
            adapter = selector.switch_adapter(task)
            logger.info(f"Task: {task} -> Adapter: {adapter}")

        stats = selector.get_stats()
        logger.info(f"\n=== Adapter Stats ===")
        logger.info(f"Currently loaded: {stats['loaded']}")
        logger.info(f"Cached: {stats['cached_count']} ({stats['cached_size_mb']:.1f} MB)")
        logger.info(f"Downloaded: {stats['total_downloaded_mb']:.1f} MB")
    else:
        adapter = selector.select_adapter(args.task, args.device_tier)
        logger.info(f"Selected adapter for {args.task}: {adapter}")

        if adapter:
            selector.load_adapter(adapter)


if __name__ == '__main__':
    main()
