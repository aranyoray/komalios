#!/usr/bin/env python3
"""
lazy_model_loader.py — Lazy load model shards to lower memory.
Splits model into shards, loads only required shards per task, async prefetch.
"""

import argparse
import json
import logging
import os
import gc
import threading
from pathlib import Path
from typing import Dict, List, Optional
import numpy as np

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)

try:
    import torch
    TORCH_AVAILABLE = True
except ImportError:
    TORCH_AVAILABLE = False


def parse_args():
    parser = argparse.ArgumentParser(description='Lazy model loader with sharding')
    parser.add_argument('--model_path', type=str, help='Full model path')
    parser.add_argument('--shard_dir', type=str, default='./model_shards', help='Shard output directory')
    parser.add_argument('--task', type=str, choices=['vision', 'gaze', 'text', 'all'], default='all')
    parser.add_argument('--split', action='store_true', help='Split model into shards')
    parser.add_argument('--load', action='store_true', help='Load shards for task')
    parser.add_argument('--prefetch', type=str, help='Prefetch shards for tasks (comma-separated)')
    parser.add_argument('--max_memory_mb', type=int, default=512, help='Max memory budget')
    return parser.parse_args()


# Task to shard mapping
TASK_SHARDS = {
    'vision': ['backbone', 'vision_head'],
    'gaze': ['backbone', 'gaze_head', 'attention'],
    'text': ['text_encoder', 'text_head'],
    'all': ['backbone', 'vision_head', 'gaze_head', 'attention', 'text_encoder', 'text_head']
}


class LazyModelLoader:
    """Manages lazy loading of model shards."""

    def __init__(self, shard_dir: str, max_memory_mb: int = 512):
        self.shard_dir = Path(shard_dir)
        self.max_memory_bytes = max_memory_mb * 1024 * 1024
        self.loaded_shards: Dict[str, dict] = {}
        self.shard_sizes: Dict[str, int] = {}
        self.current_memory = 0
        self.lock = threading.Lock()
        self.prefetch_threads: List[threading.Thread] = []

        self._load_manifest()

    def _load_manifest(self):
        """Load shard manifest."""
        manifest_path = self.shard_dir / 'manifest.json'
        if manifest_path.exists():
            with open(manifest_path) as f:
                manifest = json.load(f)
                self.shard_sizes = {s['name']: s['size'] for s in manifest['shards']}

    def _get_memory_usage(self) -> int:
        """Get current memory usage."""
        if TORCH_AVAILABLE:
            return torch.cuda.memory_allocated() if torch.cuda.is_available() else 0
        return self.current_memory

    def load_shard(self, shard_name: str) -> Optional[dict]:
        """Load a single shard."""
        with self.lock:
            if shard_name in self.loaded_shards:
                return self.loaded_shards[shard_name]

            shard_path = self.shard_dir / f'{shard_name}.pt'
            if not shard_path.exists():
                logger.warning(f"Shard not found: {shard_path}")
                return None

            shard_size = shard_path.stat().st_size

            # Check memory budget
            if self.current_memory + shard_size > self.max_memory_bytes:
                self._evict_lru(shard_size)

            # Load shard
            if TORCH_AVAILABLE:
                shard_data = torch.load(shard_path, map_location='cpu')
            else:
                import pickle
                with open(shard_path, 'rb') as f:
                    shard_data = pickle.load(f)

            self.loaded_shards[shard_name] = shard_data
            self.current_memory += shard_size

            logger.info(f"Loaded shard: {shard_name} ({shard_size / 1024 / 1024:.1f} MB)")
            return shard_data

    def _evict_lru(self, needed_size: int):
        """Evict least recently used shards to free memory."""
        while self.loaded_shards and self.current_memory + needed_size > self.max_memory_bytes:
            # Simple FIFO eviction (could be improved with LRU tracking)
            shard_name = next(iter(self.loaded_shards))
            shard_size = self.shard_sizes.get(shard_name, 0)

            del self.loaded_shards[shard_name]
            self.current_memory -= shard_size
            gc.collect()

            logger.info(f"Evicted shard: {shard_name}")

    def load_for_task(self, task: str) -> Dict[str, dict]:
        """Load all shards needed for a task."""
        shard_names = TASK_SHARDS.get(task, [])
        loaded = {}

        for shard_name in shard_names:
            shard_data = self.load_shard(shard_name)
            if shard_data:
                loaded[shard_name] = shard_data

        return loaded

    def prefetch_async(self, tasks: List[str]):
        """Prefetch shards for tasks asynchronously."""
        shard_names = set()
        for task in tasks:
            shard_names.update(TASK_SHARDS.get(task, []))

        def prefetch_worker():
            for shard_name in shard_names:
                if shard_name not in self.loaded_shards:
                    self.load_shard(shard_name)

        thread = threading.Thread(target=prefetch_worker, daemon=True)
        thread.start()
        self.prefetch_threads.append(thread)
        logger.info(f"Started prefetch for: {tasks}")

    def get_stats(self) -> dict:
        """Get loader statistics."""
        return {
            'loaded_shards': list(self.loaded_shards.keys()),
            'current_memory_mb': self.current_memory / (1024 * 1024),
            'max_memory_mb': self.max_memory_bytes / (1024 * 1024),
            'utilization': self.current_memory / self.max_memory_bytes if self.max_memory_bytes > 0 else 0
        }


def split_model_into_shards(model_path: str, shard_dir: str):
    """Split a model into task-specific shards."""
    if not TORCH_AVAILABLE:
        logger.error("PyTorch required for model splitting")
        return

    shard_dir = Path(shard_dir)
    shard_dir.mkdir(parents=True, exist_ok=True)

    # Load full model
    state_dict = torch.load(model_path, map_location='cpu')

    # Define shard mappings (customize based on model architecture)
    shard_mappings = {
        'backbone': ['backbone', 'encoder', 'features'],
        'vision_head': ['vision_head', 'vision_classifier'],
        'gaze_head': ['gaze_head', 'gaze_predictor'],
        'attention': ['attention', 'attn'],
        'text_encoder': ['text_encoder', 'bert', 'roberta'],
        'text_head': ['text_head', 'text_classifier']
    }

    manifest = {'shards': []}

    for shard_name, prefixes in shard_mappings.items():
        shard_data = {}

        for key, value in state_dict.items():
            if any(prefix in key.lower() for prefix in prefixes):
                shard_data[key] = value

        if shard_data:
            shard_path = shard_dir / f'{shard_name}.pt'
            torch.save(shard_data, shard_path)

            size = shard_path.stat().st_size
            manifest['shards'].append({
                'name': shard_name,
                'size': size,
                'keys': len(shard_data)
            })

            logger.info(f"Created shard: {shard_name} ({size / 1024 / 1024:.1f} MB, {len(shard_data)} keys)")

    # Save manifest
    with open(shard_dir / 'manifest.json', 'w') as f:
        json.dump(manifest, f, indent=2)

    logger.info(f"Split complete: {len(manifest['shards'])} shards")


def main():
    args = parse_args()

    if args.split:
        if not args.model_path:
            logger.error("--model_path required for --split")
            return 1
        split_model_into_shards(args.model_path, args.shard_dir)

    elif args.load:
        loader = LazyModelLoader(args.shard_dir, args.max_memory_mb)

        # Prefetch if requested
        if args.prefetch:
            tasks = args.prefetch.split(',')
            loader.prefetch_async(tasks)

        # Load for task
        shards = loader.load_for_task(args.task)

        stats = loader.get_stats()
        print(json.dumps(stats, indent=2))
        print(f"\nPeak memory: {stats['current_memory_mb']:.1f} MB")

    else:
        logger.error("Specify --split or --load")
        return 1

    return 0


if __name__ == '__main__':
    exit(main())
