#!/usr/bin/env python3
"""
low_ram_model_runner.py - Run models in low memory conditions

Runs models in micro-batches, uses memory-mapped weights, and swaps
layers to disk during bursts, keeping RAM < specified limit.
"""

import argparse
import json
import mmap
import os
import gc
import time
import logging
import numpy as np
from pathlib import Path
from typing import Dict, List, Optional, Any

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class MemoryMonitor:
    """Monitor and manage memory usage."""

    def __init__(self, limit_mb: float):
        self.limit_bytes = limit_mb * 1024 * 1024
        self.peak_usage = 0

    def get_usage(self) -> int:
        """Get current memory usage in bytes."""
        try:
            import resource
            usage = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss * 1024
        except:
            # Fallback estimation
            usage = 0
            for obj in gc.get_objects():
                try:
                    if hasattr(obj, '__sizeof__'):
                        usage += obj.__sizeof__()
                except:
                    pass

        self.peak_usage = max(self.peak_usage, usage)
        return usage

    def get_available(self) -> int:
        """Get available memory within limit."""
        return max(0, self.limit_bytes - self.get_usage())

    def is_within_limit(self) -> bool:
        """Check if within memory limit."""
        return self.get_usage() < self.limit_bytes

    def force_gc(self):
        """Force garbage collection."""
        gc.collect()
        logger.debug("Forced garbage collection")


class MemmapWeightLoader:
    """Load model weights using memory mapping."""

    def __init__(self, cache_dir: str = '.weight_cache'):
        self.cache_dir = Path(cache_dir)
        self.cache_dir.mkdir(exist_ok=True)
        self.loaded_layers = {}

    def save_layer(self, name: str, weights: np.ndarray):
        """Save layer weights to disk for mmap access."""
        path = self.cache_dir / f"{name}.npy"
        np.save(path, weights)
        return path

    def load_layer(self, name: str) -> Optional[np.ndarray]:
        """Load layer weights with memory mapping."""
        path = self.cache_dir / f"{name}.npy"

        if not path.exists():
            return None

        # Load with mmap for memory efficiency
        weights = np.load(path, mmap_mode='r')
        self.loaded_layers[name] = weights
        return weights

    def unload_layer(self, name: str):
        """Unload layer to free memory."""
        if name in self.loaded_layers:
            del self.loaded_layers[name]
            gc.collect()

    def get_loaded_size(self) -> int:
        """Get total size of loaded layers."""
        total = 0
        for weights in self.loaded_layers.values():
            if hasattr(weights, 'nbytes'):
                total += weights.nbytes
        return total


class LayerSwapper:
    """Swap layers to/from disk."""

    def __init__(self, swap_dir: str = '.layer_swap'):
        self.swap_dir = Path(swap_dir)
        self.swap_dir.mkdir(exist_ok=True)
        self.swapped_layers = set()

    def swap_out(self, name: str, data: np.ndarray):
        """Swap layer data to disk."""
        path = self.swap_dir / f"{name}.swap.npy"
        np.save(path, data)
        self.swapped_layers.add(name)
        logger.debug(f"Swapped out layer {name} ({data.nbytes} bytes)")

    def swap_in(self, name: str) -> Optional[np.ndarray]:
        """Swap layer data back from disk."""
        path = self.swap_dir / f"{name}.swap.npy"

        if not path.exists():
            return None

        data = np.load(path)
        self.swapped_layers.discard(name)
        logger.debug(f"Swapped in layer {name}")
        return data

    def is_swapped(self, name: str) -> bool:
        """Check if layer is currently swapped out."""
        return name in self.swapped_layers


class LowRAMModelRunner:
    """Run models with low RAM constraints."""

    def __init__(self, config: Dict):
        self.config = config
        self.ram_limit_mb = config.get('ram_limit_mb', 256)

        self.memory = MemoryMonitor(self.ram_limit_mb)
        self.weight_loader = MemmapWeightLoader(config.get('weight_cache', '.weight_cache'))
        self.swapper = LayerSwapper(config.get('swap_dir', '.layer_swap'))

        # Model state
        self.layer_names = []
        self.layer_sizes = {}
        self.active_layers = set()

        # Stats
        self.inference_count = 0
        self.swap_count = 0
        self.batch_splits = 0

    def load_model(self, model_path: str) -> bool:
        """Load model with memory-efficient techniques."""
        # Simulate loading a model
        # In real implementation, would load PyTorch/TF model

        # Create fake layers for demo
        layer_configs = [
            ('conv1', (64, 3, 3, 3)),
            ('conv2', (128, 64, 3, 3)),
            ('conv3', (256, 128, 3, 3)),
            ('fc1', (256, 1024)),
            ('fc2', (1024, 7))
        ]

        for name, shape in layer_configs:
            # Create weights
            weights = np.random.randn(*shape).astype(np.float32)

            # Save for mmap loading
            self.weight_loader.save_layer(name, weights)
            self.layer_names.append(name)
            self.layer_sizes[name] = weights.nbytes

            logger.debug(f"Prepared layer {name}: {weights.nbytes} bytes")

        logger.info(f"Loaded model with {len(self.layer_names)} layers")
        return True

    def _ensure_layer_loaded(self, name: str):
        """Ensure a layer is loaded in memory."""
        if name in self.active_layers:
            return

        # Check memory
        layer_size = self.layer_sizes.get(name, 0)

        while self.memory.get_available() < layer_size * 1.5:
            # Need to free memory - swap out LRU layer
            if not self._swap_out_lru():
                break

        # Load the layer
        if self.swapper.is_swapped(name):
            self.swapper.swap_in(name)
            self.swap_count += 1

        self.weight_loader.load_layer(name)
        self.active_layers.add(name)

    def _swap_out_lru(self) -> bool:
        """Swap out least recently used layer."""
        if not self.active_layers:
            return False

        # Simple LRU: swap out first active layer
        layer = next(iter(self.active_layers))

        weights = self.weight_loader.loaded_layers.get(layer)
        if weights is not None:
            # Copy if read-only mmap
            data = np.array(weights)
            self.swapper.swap_out(layer, data)

        self.weight_loader.unload_layer(layer)
        self.active_layers.discard(layer)
        self.memory.force_gc()

        self.swap_count += 1
        return True

    def _compute_micro_batch_size(self, input_size: int) -> int:
        """Compute optimal micro-batch size for available memory."""
        available = self.memory.get_available()

        # Estimate memory per sample (rough)
        # Activations + gradients roughly 10x input
        mem_per_sample = input_size * 10

        if mem_per_sample <= 0:
            return 1

        batch_size = max(1, int(available / mem_per_sample / 2))
        return min(batch_size, self.config.get('max_batch_size', 32))

    def run_inference(self, inputs: np.ndarray) -> np.ndarray:
        """Run inference with memory management."""
        batch_size = inputs.shape[0]
        input_size = inputs[0].nbytes

        # Compute micro-batch size
        micro_batch = self._compute_micro_batch_size(input_size)

        if micro_batch < batch_size:
            self.batch_splits += 1
            logger.debug(f"Splitting batch {batch_size} into micro-batches of {micro_batch}")

        results = []

        for i in range(0, batch_size, micro_batch):
            batch = inputs[i:i + micro_batch]

            # Process through layers
            x = batch

            for layer_name in self.layer_names:
                self._ensure_layer_loaded(layer_name)

                # Simulate layer computation
                weights = self.weight_loader.loaded_layers.get(layer_name)
                if weights is not None:
                    # Fake forward pass
                    if len(weights.shape) == 4:  # Conv
                        x = x  # Simplified
                    else:  # FC
                        if x.shape[-1] == weights.shape[0]:
                            x = x @ weights
                        else:
                            x = x

            results.append(x)

            # Check memory after each micro-batch
            if not self.memory.is_within_limit():
                self.memory.force_gc()

        self.inference_count += 1

        # Combine results
        return np.vstack(results) if results else np.array([])

    def get_stats(self) -> Dict:
        """Get runner statistics."""
        return {
            'ram_limit_mb': self.ram_limit_mb,
            'current_usage_mb': self.memory.get_usage() / (1024 * 1024),
            'peak_usage_mb': self.memory.peak_usage / (1024 * 1024),
            'inference_count': self.inference_count,
            'swap_count': self.swap_count,
            'batch_splits': self.batch_splits,
            'active_layers': len(self.active_layers),
            'swapped_layers': len(self.swapper.swapped_layers)
        }


def main():
    parser = argparse.ArgumentParser(description='Low RAM model runner')
    parser.add_argument('--ram-limit', type=float, default=256, help='RAM limit in MB')
    parser.add_argument('--batch-size', type=int, default=16, help='Input batch size')
    parser.add_argument('--iterations', type=int, default=5, help='Number of inferences')
    parser.add_argument('--demo', action='store_true', help='Run demo')

    args = parser.parse_args()

    config = {
        'ram_limit_mb': args.ram_limit,
        'max_batch_size': 32
    }

    runner = LowRAMModelRunner(config)

    if args.demo:
        # Load model
        runner.load_model('demo_model')

        # Run inferences
        for i in range(args.iterations):
            # Create fake input
            inputs = np.random.randn(args.batch_size, 3, 64, 64).astype(np.float32)

            start = time.time()
            outputs = runner.run_inference(inputs)
            elapsed = time.time() - start

            stats = runner.get_stats()
            logger.info(
                f"Inference {i+1}: {elapsed*1000:.1f}ms | "
                f"RAM: {stats['current_usage_mb']:.1f}MB | "
                f"Swaps: {stats['swap_count']}"
            )

        # Final stats
        stats = runner.get_stats()
        logger.info(f"\n=== Final Stats ===")
        logger.info(f"Peak RAM: {stats['peak_usage_mb']:.1f} MB (limit: {stats['ram_limit_mb']} MB)")
        logger.info(f"Total swaps: {stats['swap_count']}")
        logger.info(f"Batch splits: {stats['batch_splits']}")
    else:
        logger.info("Use --demo to run demonstration")


if __name__ == '__main__':
    main()
