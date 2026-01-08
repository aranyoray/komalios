#!/usr/bin/env python3
"""
battery_simulator.py — Simulate battery drain under various model workloads.
"""

import argparse
import hashlib
import logging
import json
import time
from pathlib import Path
from datetime import datetime

import numpy as np
import pandas as pd
import torch
import torch.nn as nn

try:
    import mlflow
    HAS_MLFLOW = True
except ImportError:
    HAS_MLFLOW = False

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out_dir', type=str, default='./outputs/battery')
    parser.add_argument('--duration_minutes', type=int, default=5)
    parser.add_argument('--sample_interval', type=float, default=1.0)
    parser.add_argument('--workloads', type=str, default='idle,light,medium,heavy')
    parser.add_argument('--synthetic', type=int, default=0)
    parser.add_argument('--dry_run', action='store_true')
    parser.add_argument('--debug', action='store_true')
    return parser.parse_args()


class WorkloadModel(nn.Module):
    def __init__(self, size='medium'):
        super().__init__()
        if size == 'light':
            dims = [768, 128, 7]
        elif size == 'medium':
            dims = [768, 256, 128, 7]
        else:  # heavy
            dims = [768, 512, 256, 128, 7]

        layers = []
        for i in range(len(dims) - 1):
            layers.extend([nn.Linear(dims[i], dims[i+1]), nn.ReLU()])
        self.net = nn.Sequential(*layers[:-1])

    def forward(self, x):
        return self.net(x)


def estimate_power_draw(ops_per_second):
    """Estimate power draw in mW based on ops/s."""
    # simplified model: base + ops-proportional
    base_power = 100  # mW idle
    ops_factor = 0.001  # mW per op/s
    return base_power + ops_per_second * ops_factor


def compute_sha256(filepath):
    sha256_hash = hashlib.sha256()
    with open(filepath, 'rb') as f:
        for chunk in iter(lambda: f.read(4096), b''):
            sha256_hash.update(chunk)
    return sha256_hash.hexdigest()


def main():
    args = parse_args()
    if args.debug:
        logging.getLogger().setLevel(logging.DEBUG)

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    if HAS_MLFLOW:
        mlflow.start_run(run_name='battery_sim')
        mlflow.log_params(vars(args))

    workloads = args.workloads.split(',')
    results = {'workloads': {}}

    if args.dry_run:
        logger.info("dry run mode")
        for workload in workloads:
            results['workloads'][workload] = {
                'avg_power_mw': 150 if workload == 'idle' else 300,
                'total_energy_mwh': 12.5,
                'ops_per_second': 0 if workload == 'idle' else 1000,
            }
    else:
        duration_seconds = args.duration_minutes * 60
        n_samples = int(duration_seconds / args.sample_interval)

        for workload in workloads:
            logger.info(f"simulating {workload} workload...")

            if workload == 'idle':
                model = None
            else:
                model = WorkloadModel(size=workload)
                model.eval()

            power_samples = []
            ops_samples = []

            for _ in range(min(n_samples, 100)):  # limit for demo
                start = time.perf_counter()

                if model is not None:
                    x = torch.randn(32, 768)
                    with torch.no_grad():
                        for _ in range(10):
                            _ = model(x)
                    ops = 10 * 32
                else:
                    time.sleep(0.01)
                    ops = 0

                elapsed = time.perf_counter() - start
                ops_per_second = ops / elapsed if elapsed > 0 else 0

                power = estimate_power_draw(ops_per_second)
                power_samples.append(power)
                ops_samples.append(ops_per_second)

            avg_power = np.mean(power_samples)
            total_energy = avg_power * args.duration_minutes / 60  # mWh

            results['workloads'][workload] = {
                'avg_power_mw': float(avg_power),
                'total_energy_mwh': float(total_energy),
                'ops_per_second': float(np.mean(ops_samples)),
            }

            logger.info(f"  {workload}: {avg_power:.1f}mW, {total_energy:.2f}mWh")

    # Battery life estimation (3000mAh @ 3.7V = 11100mWh)
    battery_capacity = 11100  # mWh
    results['battery_life'] = {}
    for workload, data in results['workloads'].items():
        hours = battery_capacity / data['avg_power_mw'] if data['avg_power_mw'] > 0 else 0
        results['battery_life'][workload] = float(hours)

    # Save results
    with open(out_dir / 'battery_results.json', 'w') as f:
        json.dump(results, f, indent=2)

    # Create manifest
    artifacts = []
    for path in out_dir.glob('*'):
        if path.is_file():
            artifacts.append({
                'path': str(path),
                'sha256': compute_sha256(path),
                'size': path.stat().st_size,
                'created_at': datetime.now().isoformat(),
            })

    pd.DataFrame(artifacts).to_csv(out_dir / 'artifacts_manifest.csv', index=False)

    if HAS_MLFLOW:
        mlflow.end_run()

    logger.info(f"battery simulation complete. saved to {out_dir}")


if __name__ == '__main__':
    main()
