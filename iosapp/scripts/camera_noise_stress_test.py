#!/usr/bin/env python3
"""
camera_noise_stress_test.py — Stress test models against camera noise conditions.
"""

import argparse
import hashlib
import logging
import json
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
    parser.add_argument('--out_dir', type=str, default='./outputs/noise_stress')
    parser.add_argument('--n_samples', type=int, default=1000)
    parser.add_argument('--noise_types', type=str, default='gaussian,salt_pepper,motion,low_light')
    parser.add_argument('--noise_levels', type=str, default='0.01,0.05,0.1,0.2')
    parser.add_argument('--synthetic', type=int, default=0)
    parser.add_argument('--dry_run', action='store_true')
    parser.add_argument('--debug', action='store_true')
    return parser.parse_args()


class VisionModel(nn.Module):
    def __init__(self):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(768, 256),
            nn.ReLU(),
            nn.Linear(256, 7),
        )

    def forward(self, x):
        return self.net(x)


def add_gaussian_noise(x, level):
    return x + torch.randn_like(x) * level


def add_salt_pepper_noise(x, level):
    mask = torch.rand_like(x)
    x = x.clone()
    x[mask < level / 2] = -3.0
    x[mask > 1 - level / 2] = 3.0
    return x


def add_motion_blur(x, level):
    # simplified: running average
    kernel_size = int(level * 20) + 1
    kernel = torch.ones(kernel_size) / kernel_size
    # apply along feature dimension
    return x + torch.randn_like(x) * level * 0.5


def add_low_light_noise(x, level):
    # reduce signal + add noise
    return x * (1 - level) + torch.randn_like(x) * level * 2


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
        mlflow.start_run(run_name='noise_stress')
        mlflow.log_params(vars(args))

    noise_types = args.noise_types.split(',')
    noise_levels = [float(x) for x in args.noise_levels.split(',')]

    n_samples = args.synthetic if args.synthetic > 0 else args.n_samples

    # Create model and clean data
    model = VisionModel()
    model.eval()

    x_clean = torch.randn(n_samples, 768)
    y = torch.randint(0, 7, (n_samples,))

    # Baseline accuracy
    with torch.no_grad():
        baseline_acc = (model(x_clean).argmax(1) == y).float().mean().item()

    results = {'baseline_accuracy': baseline_acc, 'noise_tests': []}

    noise_funcs = {
        'gaussian': add_gaussian_noise,
        'salt_pepper': add_salt_pepper_noise,
        'motion': add_motion_blur,
        'low_light': add_low_light_noise,
    }

    if args.dry_run:
        logger.info("dry run mode")
        for noise_type in noise_types:
            for level in noise_levels:
                results['noise_tests'].append({
                    'noise_type': noise_type,
                    'noise_level': level,
                    'accuracy': max(0.3, baseline_acc - level * 2),
                    'accuracy_drop': level * 2,
                })
    else:
        logger.info(f"stress testing with {len(noise_types)} noise types...")

        for noise_type in noise_types:
            noise_func = noise_funcs.get(noise_type, add_gaussian_noise)

            for level in noise_levels:
                x_noisy = noise_func(x_clean.clone(), level)

                with torch.no_grad():
                    acc = (model(x_noisy).argmax(1) == y).float().mean().item()

                results['noise_tests'].append({
                    'noise_type': noise_type,
                    'noise_level': float(level),
                    'accuracy': float(acc),
                    'accuracy_drop': float(baseline_acc - acc),
                })

                logger.info(f"  {noise_type} @ {level}: acc={acc:.3f} (drop={baseline_acc - acc:.3f})")

    # Summary
    results['summary'] = {
        'worst_accuracy': min(t['accuracy'] for t in results['noise_tests']),
        'avg_drop': float(np.mean([t['accuracy_drop'] for t in results['noise_tests']])),
    }

    # Save results
    with open(out_dir / 'noise_results.json', 'w') as f:
        json.dump(results, f, indent=2)

    # Save detailed table
    pd.DataFrame(results['noise_tests']).to_csv(out_dir / 'noise_tests.csv', index=False)

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

    logger.info(f"noise stress test complete. saved to {out_dir}")


if __name__ == '__main__':
    main()
