#!/usr/bin/env python3
"""
low_power_inference_mode.py — Energy-preserving inference wrapper.
Mixed precision, lower batch sizes, adaptive frame skipping, energy budget meter.
"""

import argparse
import json
import logging
import time
from typing import Callable
import numpy as np

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description='Low power inference mode')
    parser.add_argument('--energy_budget', type=float, default=100.0, help='Energy budget units')
    parser.add_argument('--skip_threshold', type=float, default=0.3, help='Similarity threshold to skip')
    parser.add_argument('--precision', type=str, choices=['fp32', 'fp16', 'int8'], default='fp16')
    parser.add_argument('--demo', action='store_true')
    return parser.parse_args()


class LowPowerInferenceWrapper:
    """Wraps inference for energy-efficient execution."""

    def __init__(self, energy_budget=100.0, skip_threshold=0.3, precision='fp16'):
        self.energy_budget = energy_budget
        self.energy_used = 0.0
        self.skip_threshold = skip_threshold
        self.precision = precision

        self.last_input = None
        self.last_output = None
        self.frames_processed = 0
        self.frames_skipped = 0

        # Energy costs per operation type
        self.costs = {
            'fp32': 1.0,
            'fp16': 0.5,
            'int8': 0.25,
            'skip': 0.01
        }

    def get_energy_remaining(self):
        """Get remaining energy budget."""
        return max(0, self.energy_budget - self.energy_used)

    def get_energy_percent(self):
        """Get energy used as percentage."""
        return (self.energy_used / self.energy_budget * 100) if self.energy_budget > 0 else 100

    def should_skip_frame(self, input_data):
        """Determine if frame is similar enough to skip."""
        if self.last_input is None:
            return False

        # Compute similarity
        diff = np.abs(input_data - self.last_input).mean()
        return diff < self.skip_threshold

    def convert_precision(self, data):
        """Convert data to target precision."""
        if self.precision == 'fp16':
            return data.astype(np.float16)
        elif self.precision == 'int8':
            # Quantize to int8
            scale = 127.0 / (np.abs(data).max() + 1e-8)
            return (data * scale).astype(np.int8)
        return data

    def run_inference(self, model_fn: Callable, input_data: np.ndarray):
        """Run inference with energy optimizations."""
        # Check budget
        if self.get_energy_remaining() <= 0:
            logger.warning("Energy budget exhausted")
            return self.last_output

        # Check if we can skip
        if self.should_skip_frame(input_data):
            self.energy_used += self.costs['skip']
            self.frames_skipped += 1
            return self.last_output

        # Convert precision
        input_converted = self.convert_precision(input_data)

        # Run inference
        start_time = time.perf_counter()
        output = model_fn(input_converted)
        inference_time = time.perf_counter() - start_time

        # Track energy
        energy_cost = self.costs[self.precision] * (1 + inference_time * 10)
        self.energy_used += energy_cost

        # Update state
        self.last_input = input_data.copy()
        self.last_output = output
        self.frames_processed += 1

        return output

    def get_stats(self):
        """Get wrapper statistics."""
        total_frames = self.frames_processed + self.frames_skipped
        skip_rate = self.frames_skipped / total_frames if total_frames > 0 else 0

        return {
            'frames_processed': self.frames_processed,
            'frames_skipped': self.frames_skipped,
            'skip_rate': round(skip_rate, 3),
            'energy_used': round(self.energy_used, 2),
            'energy_remaining': round(self.get_energy_remaining(), 2),
            'energy_percent': round(self.get_energy_percent(), 1),
            'precision': self.precision
        }


def demo_model(input_data):
    """Demo model function."""
    # Simulate inference
    time.sleep(0.01)
    return np.random.randn(128)


def main():
    args = parse_args()

    wrapper = LowPowerInferenceWrapper(
        energy_budget=args.energy_budget,
        skip_threshold=args.skip_threshold,
        precision=args.precision
    )

    if args.demo:
        logger.info("Running demo...")

        # Simulate video frames
        for i in range(100):
            # Generate frame with some temporal coherence
            if i == 0:
                frame = np.random.randn(224, 224, 3)
            else:
                # Small changes most of the time
                if np.random.rand() < 0.7:
                    frame = frame + np.random.randn(224, 224, 3) * 0.1
                else:
                    frame = np.random.randn(224, 224, 3)

            output = wrapper.run_inference(demo_model, frame)

            if (i + 1) % 20 == 0:
                stats = wrapper.get_stats()
                logger.info(f"Frame {i+1}: energy={stats['energy_percent']:.1f}%")

        print(json.dumps(wrapper.get_stats(), indent=2))

    else:
        print("Use --demo to run demonstration")
        print(json.dumps({
            'energy_budget': args.energy_budget,
            'skip_threshold': args.skip_threshold,
            'precision': args.precision
        }, indent=2))


if __name__ == '__main__':
    main()
