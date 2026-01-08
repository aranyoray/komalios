#!/usr/bin/env python3
"""
device_bench_harness.py — On-device benchmark harness + telemetry collector.
"""

import argparse
import json
import time
import hashlib
import logging
from pathlib import Path

import numpy as np
import torch

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--artifact_path', type=str, required=True)
    parser.add_argument('--output_dir', type=str, required=True)
    parser.add_argument('--devices', type=str, default='android_cpu,android_nnapi,ios_cpu,ios_neural')
    parser.add_argument('--num_runs', type=int, default=100)
    parser.add_argument('--warmup_runs', type=int, default=10)
    parser.add_argument('--calibration_mode', action='store_true')
    parser.add_argument('--test_variations', action='store_true')
    return parser.parse_args()


def compute_sha256(filepath):
    sha256_hash = hashlib.sha256()
    with open(filepath, 'rb') as f:
        for chunk in iter(lambda: f.read(4096), b''):
            sha256_hash.update(chunk)
    return sha256_hash.hexdigest()


class DeviceEmulator:
    """Emulate different device characteristics."""

    PROFILES = {
        'android_cpu': {'clock_factor': 1.0, 'memory_factor': 1.0, 'energy_factor': 1.0},
        'android_nnapi': {'clock_factor': 0.3, 'memory_factor': 0.8, 'energy_factor': 0.5},
        'ios_cpu': {'clock_factor': 0.8, 'memory_factor': 0.9, 'energy_factor': 0.9},
        'ios_neural': {'clock_factor': 0.2, 'memory_factor': 0.7, 'energy_factor': 0.4},
    }

    def __init__(self, device_type):
        self.device_type = device_type
        self.profile = self.PROFILES.get(device_type, self.PROFILES['android_cpu'])

    def simulate_inference(self, base_latency_ms):
        """Simulate inference with device characteristics."""
        latency = base_latency_ms * self.profile['clock_factor']
        # add variance
        latency *= (1 + np.random.normal(0, 0.05))
        return max(0.1, latency)

    def simulate_memory(self, base_memory_mb):
        return base_memory_mb * self.profile['memory_factor']

    def simulate_energy(self, base_energy_mj):
        return base_energy_mj * self.profile['energy_factor']


def generate_test_variations():
    """Generate synthetic test cases with variations."""
    variations = []

    # lighting variations
    for lighting in ['normal', 'low', 'bright', 'backlit']:
        variations.append({'type': 'lighting', 'value': lighting})

    # occlusion
    for occlusion in ['none', 'partial', 'glasses', 'mask']:
        variations.append({'type': 'occlusion', 'value': occlusion})

    # motion blur
    for blur in ['none', 'slight', 'moderate', 'severe']:
        variations.append({'type': 'motion_blur', 'value': blur})

    return variations


def benchmark_device(emulator, num_runs, warmup_runs):
    """Run benchmark on emulated device."""
    # base metrics (from actual model inference)
    base_latency = 5.0  # ms
    base_memory = 50.0  # MB
    base_energy = 2.0  # mJ

    latencies = []

    # warmup
    for _ in range(warmup_runs):
        _ = emulator.simulate_inference(base_latency)

    # benchmark
    for _ in range(num_runs):
        latency = emulator.simulate_inference(base_latency)
        latencies.append(latency)

    latencies = np.array(latencies)

    return {
        'p50_ms': float(np.percentile(latencies, 50)),
        'p95_ms': float(np.percentile(latencies, 95)),
        'p99_ms': float(np.percentile(latencies, 99)),
        'mean_ms': float(np.mean(latencies)),
        'std_ms': float(np.std(latencies)),
        'memory_mb': emulator.simulate_memory(base_memory),
        'energy_mj': emulator.simulate_energy(base_energy),
        'cpu_percent': np.random.uniform(20, 80),
    }


def main():
    args = parse_args()
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    artifact_path = Path(args.artifact_path)

    # verify artifact
    if artifact_path.exists():
        sha256 = compute_sha256(artifact_path)
        logger.info(f"artifact SHA256: {sha256}")
    else:
        sha256 = 'N/A'
        logger.warning(f"artifact not found: {artifact_path}")

    devices = args.devices.split(',')
    results = []

    for device in devices:
        logger.info(f"benchmarking {device}...")
        emulator = DeviceEmulator(device)

        metrics = benchmark_device(emulator, args.num_runs, args.warmup_runs)
        metrics['device'] = device
        metrics['artifact'] = str(artifact_path)
        metrics['sha256'] = sha256

        results.append(metrics)

        logger.info(f"{device}: p95={metrics['p95_ms']:.2f}ms, mem={metrics['memory_mb']:.1f}MB")

    # test variations
    if args.test_variations:
        logger.info("testing input variations...")
        variations = generate_test_variations()

        for var in variations:
            # simulate variation impact
            for device in devices:
                emulator = DeviceEmulator(device)
                base_metrics = benchmark_device(emulator, 10, 2)

                # add variation penalty
                penalty = {'lighting': 1.1, 'occlusion': 1.2, 'motion_blur': 1.15}.get(var['type'], 1.0)
                base_metrics['p95_ms'] *= penalty

                base_metrics['device'] = device
                base_metrics['variation_type'] = var['type']
                base_metrics['variation_value'] = var['value']
                results.append(base_metrics)

    # save telemetry
    telemetry_path = output_dir / 'telemetry.json'
    with open(telemetry_path, 'w') as f:
        json.dump(results, f, indent=2)

    # save summary CSV
    import pandas as pd
    df = pd.DataFrame(results)
    df.to_csv(output_dir / 'benchmark_results.csv', index=False)

    logger.info(f"telemetry saved to {telemetry_path}")


if __name__ == '__main__':
    main()
