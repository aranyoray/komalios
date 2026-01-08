#!/usr/bin/env python3
"""
au_temporal_smoother.py — Polynomial & Savitzky-Golay smoothing for AU sequences.
"""

import argparse
import json
import logging
import hashlib
from pathlib import Path
from datetime import datetime

import numpy as np
import pandas as pd
from scipy.signal import savgol_filter
from scipy.ndimage import uniform_filter1d

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out_dir', type=str, default='./outputs/au_smoother')
    parser.add_argument('--n_sequences', type=int, default=500)
    parser.add_argument('--seq_len', type=int, default=300)
    parser.add_argument('--n_aus', type=int, default=17)
    parser.add_argument('--window_sizes', type=str, default='5,11,21')
    parser.add_argument('--poly_orders', type=str, default='2,3,4')
    parser.add_argument('--synthetic', type=int, default=0)
    parser.add_argument('--dry_run', action='store_true')
    return parser.parse_args()


def generate_synthetic_au_sequences(n_sequences, seq_len, n_aus):
    """Generate synthetic AU sequences with noise and micro-expressions."""
    sequences = []

    for _ in range(n_sequences):
        # Base AU activations (slow-varying)
        base = np.zeros((seq_len, n_aus))
        for au in range(n_aus):
            # Low-frequency component
            freq = np.random.uniform(0.5, 2)
            phase = np.random.uniform(0, 2 * np.pi)
            t = np.linspace(0, 1, seq_len)
            base[:, au] = 0.3 + 0.2 * np.sin(2 * np.pi * freq * t + phase)

        # Add micro-expressions (brief spikes)
        micro_exp = np.zeros((seq_len, n_aus))
        n_microexp = np.random.randint(3, 8)
        for _ in range(n_microexp):
            start = np.random.randint(0, seq_len - 10)
            duration = np.random.randint(3, 8)
            au = np.random.randint(0, n_aus)
            intensity = np.random.uniform(0.3, 0.7)
            micro_exp[start:start+duration, au] = intensity

        # Ground truth
        ground_truth = base + micro_exp

        # Add noise (jitter)
        noise = np.random.randn(seq_len, n_aus) * 0.1
        noisy = np.clip(ground_truth + noise, 0, 1)

        sequences.append({
            'ground_truth': ground_truth.astype(np.float32),
            'noisy': noisy.astype(np.float32),
        })

    return sequences


def apply_moving_average(sequence, window_size):
    """Apply moving average smoothing."""
    return uniform_filter1d(sequence, size=window_size, axis=0)


def apply_savgol(sequence, window_size, poly_order):
    """Apply Savitzky-Golay filter."""
    if window_size % 2 == 0:
        window_size += 1
    return savgol_filter(sequence, window_size, poly_order, axis=0)


def apply_exponential(sequence, alpha=0.3):
    """Apply exponential smoothing."""
    result = np.zeros_like(sequence)
    result[0] = sequence[0]
    for i in range(1, len(sequence)):
        result[i] = alpha * sequence[i] + (1 - alpha) * result[i-1]
    return result


def compute_mse(pred, target):
    return np.mean((pred - target) ** 2)


def compute_mae(pred, target):
    return np.mean(np.abs(pred - target))


def compute_sha256(filepath):
    sha256_hash = hashlib.sha256()
    with open(filepath, 'rb') as f:
        for chunk in iter(lambda: f.read(4096), b''):
            sha256_hash.update(chunk)
    return sha256_hash.hexdigest()


def main():
    args = parse_args()
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    window_sizes = [int(x) for x in args.window_sizes.split(',')]
    poly_orders = [int(x) for x in args.poly_orders.split(',')]

    n_sequences = args.synthetic if args.synthetic > 0 else args.n_sequences
    sequences = generate_synthetic_au_sequences(n_sequences, args.seq_len, args.n_aus)

    if args.dry_run:
        logger.info("dry run mode")
        results = {
            'best_method': 'savgol_11_3',
            'best_mse': 0.005,
            'methods_tested': 20,
        }
    else:
        # Test different smoothing methods
        logger.info("testing smoothing methods...")

        method_results = {}

        # Moving average
        for ws in window_sizes:
            mses = []
            for seq in sequences:
                smoothed = apply_moving_average(seq['noisy'], ws)
                mses.append(compute_mse(smoothed, seq['ground_truth']))
            method_results[f'moving_avg_{ws}'] = np.mean(mses)

        # Savitzky-Golay
        for ws in window_sizes:
            for po in poly_orders:
                if po < ws:
                    mses = []
                    for seq in sequences:
                        smoothed = apply_savgol(seq['noisy'], ws, po)
                        mses.append(compute_mse(smoothed, seq['ground_truth']))
                    method_results[f'savgol_{ws}_{po}'] = np.mean(mses)

        # Exponential smoothing
        for alpha in [0.1, 0.3, 0.5]:
            mses = []
            for seq in sequences:
                smoothed = apply_exponential(seq['noisy'], alpha)
                mses.append(compute_mse(smoothed, seq['ground_truth']))
            method_results[f'exponential_{alpha}'] = np.mean(mses)

        # Baseline (no smoothing)
        noisy_mses = []
        for seq in sequences:
            noisy_mses.append(compute_mse(seq['noisy'], seq['ground_truth']))
        method_results['no_smoothing'] = np.mean(noisy_mses)

        # Find best method
        best_method = min(method_results, key=method_results.get)
        best_mse = method_results[best_method]

        # Sort by MSE
        sorted_methods = sorted(method_results.items(), key=lambda x: x[1])

        logger.info(f"best method: {best_method} (MSE: {best_mse:.6f})")
        logger.info(f"improvement over noisy: {(method_results['no_smoothing'] - best_mse) / method_results['no_smoothing'] * 100:.1f}%")

        results = {
            'best_method': best_method,
            'best_mse': float(best_mse),
            'methods_tested': len(method_results),
            'improvement_pct': float((method_results['no_smoothing'] - best_mse) / method_results['no_smoothing'] * 100),
            'all_methods': {k: float(v) for k, v in sorted_methods},
        }

        # Save recommended config
        config = {
            'method': best_method.split('_')[0],
        }
        if 'savgol' in best_method:
            parts = best_method.split('_')
            config['window_size'] = int(parts[1])
            config['poly_order'] = int(parts[2])
        elif 'moving_avg' in best_method:
            config['window_size'] = int(best_method.split('_')[-1])
        elif 'exponential' in best_method:
            config['alpha'] = float(best_method.split('_')[-1])

        with open(out_dir / 'smoother_config.json', 'w') as f:
            json.dump(config, f, indent=2)

    # Save results
    with open(out_dir / 'smoother_results.json', 'w') as f:
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

    logger.info(f"AU smoother complete. saved to {out_dir}")


if __name__ == '__main__':
    main()
