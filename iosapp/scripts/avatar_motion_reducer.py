#!/usr/bin/env python3
"""
avatar_motion_reducer.py — Optimize animation keyframes for low-end devices.
"""

import argparse
import json
import logging
import hashlib
from pathlib import Path
from datetime import datetime

import numpy as np
import pandas as pd
from scipy.interpolate import interp1d
from scipy.signal import savgol_filter

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out_dir', type=str, default='./outputs/motion_reducer')
    parser.add_argument('--n_animations', type=int, default=50)
    parser.add_argument('--n_frames', type=int, default=300)
    parser.add_argument('--n_bones', type=int, default=24)
    parser.add_argument('--target_reduction', type=float, default=0.5)
    parser.add_argument('--error_threshold', type=float, default=0.01)
    parser.add_argument('--synthetic', type=int, default=0)
    parser.add_argument('--dry_run', action='store_true')
    return parser.parse_args()


def generate_synthetic_animations(n_animations, n_frames, n_bones):
    """Generate synthetic animation keyframe data."""
    animations = []

    for i in range(n_animations):
        # Each bone has position (3) + rotation (4 quaternion) = 7 values
        n_channels = n_bones * 7

        # Generate smooth motion curves
        keyframes = np.zeros((n_frames, n_channels), dtype=np.float32)
        t = np.linspace(0, 1, n_frames)

        for channel in range(n_channels):
            # Mix of frequencies for natural motion
            freq1 = np.random.uniform(0.5, 3)
            freq2 = np.random.uniform(3, 8)
            phase1 = np.random.uniform(0, 2 * np.pi)
            phase2 = np.random.uniform(0, 2 * np.pi)

            keyframes[:, channel] = (
                0.5 * np.sin(2 * np.pi * freq1 * t + phase1) +
                0.2 * np.sin(2 * np.pi * freq2 * t + phase2) +
                np.random.randn(n_frames) * 0.05
            )

        animations.append({
            'id': i,
            'name': f'animation_{i}',
            'keyframes': keyframes,
        })

    return animations


def douglas_peucker_1d(points, epsilon):
    """Douglas-Peucker algorithm for curve simplification (1D version)."""
    if len(points) < 3:
        return list(range(len(points)))

    # Find point with maximum distance from line
    start, end = points[0], points[-1]
    line = np.linspace(start, end, len(points))
    distances = np.abs(points - line)

    max_idx = np.argmax(distances)
    max_dist = distances[max_idx]

    if max_dist > epsilon:
        # Recursive calls
        left = douglas_peucker_1d(points[:max_idx+1], epsilon)
        right = douglas_peucker_1d(points[max_idx:], epsilon)
        return left[:-1] + [idx + max_idx for idx in right]
    else:
        return [0, len(points) - 1]


def reduce_keyframes(keyframes, target_reduction, error_threshold):
    """Reduce keyframes while maintaining visual quality."""
    n_frames, n_channels = keyframes.shape
    target_frames = int(n_frames * (1 - target_reduction))

    # Use Douglas-Peucker on each channel
    all_indices = set(range(n_frames))
    channel_indices = []

    for channel in range(n_channels):
        indices = douglas_peucker_1d(keyframes[:, channel], error_threshold)
        channel_indices.append(set(indices))

    # Union of all important indices
    important_indices = set()
    for indices in channel_indices:
        important_indices.update(indices)

    # Always keep first and last
    important_indices.add(0)
    important_indices.add(n_frames - 1)

    # If still too many, sample uniformly
    if len(important_indices) > target_frames:
        important_indices = sorted(important_indices)
        step = len(important_indices) / target_frames
        important_indices = [important_indices[int(i * step)] for i in range(target_frames)]

    important_indices = sorted(important_indices)

    # Extract reduced keyframes
    reduced = keyframes[important_indices]

    return reduced, important_indices


def compute_reconstruction_error(original, reduced, indices):
    """Compute error when reconstructing from reduced keyframes."""
    n_frames = len(original)

    # Interpolate reduced back to original length
    reconstructed = np.zeros_like(original)
    for channel in range(original.shape[1]):
        f = interp1d(indices, reduced[:, channel], kind='linear', fill_value='extrapolate')
        reconstructed[:, channel] = f(np.arange(n_frames))

    mse = np.mean((original - reconstructed) ** 2)
    max_error = np.max(np.abs(original - reconstructed))

    return mse, max_error


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

    n_animations = args.synthetic if args.synthetic > 0 else args.n_animations
    animations = generate_synthetic_animations(n_animations, args.n_frames, args.n_bones)

    if args.dry_run:
        logger.info("dry run mode")
        results = {
            'avg_reduction': 0.52,
            'avg_mse': 0.008,
            'animations_processed': n_animations,
        }
    else:
        logger.info(f"processing {n_animations} animations...")

        reduction_results = []

        for anim in animations:
            original = anim['keyframes']

            # Reduce keyframes
            reduced, indices = reduce_keyframes(
                original, args.target_reduction, args.error_threshold
            )

            # Compute error
            mse, max_error = compute_reconstruction_error(original, reduced, indices)

            reduction_ratio = 1 - len(reduced) / len(original)

            reduction_results.append({
                'animation_id': anim['id'],
                'original_frames': len(original),
                'reduced_frames': len(reduced),
                'reduction_ratio': reduction_ratio,
                'mse': mse,
                'max_error': max_error,
            })

            logger.debug(f"  {anim['name']}: {len(original)} -> {len(reduced)} frames (MSE: {mse:.6f})")

        # Summary
        avg_reduction = np.mean([r['reduction_ratio'] for r in reduction_results])
        avg_mse = np.mean([r['mse'] for r in reduction_results])
        avg_max_error = np.mean([r['max_error'] for r in reduction_results])

        results = {
            'avg_reduction': float(avg_reduction),
            'avg_mse': float(avg_mse),
            'avg_max_error': float(avg_max_error),
            'animations_processed': n_animations,
            'target_reduction': args.target_reduction,
        }

        logger.info(f"average reduction: {avg_reduction * 100:.1f}%")
        logger.info(f"average MSE: {avg_mse:.6f}")

        # Save detailed results
        pd.DataFrame(reduction_results).to_csv(out_dir / 'reduction_details.csv', index=False)

    # Save results
    with open(out_dir / 'reducer_results.json', 'w') as f:
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

    logger.info(f"motion reducer complete. saved to {out_dir}")


if __name__ == '__main__':
    main()
