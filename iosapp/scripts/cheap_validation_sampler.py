#!/usr/bin/env python3
"""
cheap_validation_sampler.py — Sample validation sets cheaply for on-device checks.
Uses k-center/herding for maximally informative held-out sets.
"""

import argparse
import json
import logging
from pathlib import Path
import numpy as np

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description='Cheap validation sampler')
    parser.add_argument('--input', type=str, required=True, help='Input embeddings/features')
    parser.add_argument('--output', type=str, default='./validation_sample.npy')
    parser.add_argument('--n_samples', type=int, default=50)
    parser.add_argument('--method', type=str, choices=['k_center', 'herding', 'random'], default='k_center')
    return parser.parse_args()


def k_center_greedy(features, n_samples):
    """K-center greedy algorithm for core-set selection."""
    n = len(features)
    if n_samples >= n:
        return list(range(n))

    # Start with random point
    selected = [np.random.randint(n)]

    # Distance to nearest selected
    min_distances = np.full(n, np.inf)

    for _ in range(n_samples - 1):
        # Update distances
        last_selected = selected[-1]
        distances = np.linalg.norm(features - features[last_selected], axis=1)
        min_distances = np.minimum(min_distances, distances)

        # Select point with maximum distance to nearest selected
        next_idx = np.argmax(min_distances)
        selected.append(next_idx)

    return selected


def herding_selection(features, n_samples):
    """Herding algorithm for core-set selection."""
    n = len(features)
    if n_samples >= n:
        return list(range(n))

    # Mean of all features
    mean_features = features.mean(axis=0)

    selected = []
    running_sum = np.zeros(features.shape[1])

    for _ in range(n_samples):
        # Find point that best matches the mean when added
        target = (len(selected) + 1) * mean_features - running_sum
        distances = np.linalg.norm(features - target, axis=1)

        # Exclude already selected
        distances[selected] = np.inf

        next_idx = np.argmin(distances)
        selected.append(next_idx)
        running_sum += features[next_idx]

    return selected


def random_selection(features, n_samples):
    """Random selection baseline."""
    n = len(features)
    return list(np.random.choice(n, min(n_samples, n), replace=False))


def evaluate_coverage(features, selected_indices):
    """Evaluate how well selection covers the space."""
    selected_features = features[selected_indices]

    # Coverage: average distance from each point to nearest selected
    distances = []
    for i, feat in enumerate(features):
        if i not in selected_indices:
            dist = np.min(np.linalg.norm(selected_features - feat, axis=1))
            distances.append(dist)

    return {
        'mean_distance': float(np.mean(distances)) if distances else 0,
        'max_distance': float(np.max(distances)) if distances else 0,
        'coverage_score': 1 / (1 + np.mean(distances)) if distances else 1
    }


def main():
    args = parse_args()

    # Load features
    input_path = Path(args.input)
    if input_path.suffix == '.npy':
        features = np.load(input_path)
    else:
        # Load from JSON
        with open(input_path) as f:
            data = json.load(f)
        features = np.array(data)

    logger.info(f"Loaded {len(features)} samples, shape: {features.shape}")

    # Select samples
    if args.method == 'k_center':
        selected = k_center_greedy(features, args.n_samples)
    elif args.method == 'herding':
        selected = herding_selection(features, args.n_samples)
    else:
        selected = random_selection(features, args.n_samples)

    logger.info(f"Selected {len(selected)} samples using {args.method}")

    # Evaluate coverage
    coverage = evaluate_coverage(features, selected)
    logger.info(f"Coverage score: {coverage['coverage_score']:.3f}")

    # Save selected samples
    selected_features = features[selected]
    np.save(args.output, selected_features)

    # Save indices
    indices_path = args.output.replace('.npy', '_indices.json')
    with open(indices_path, 'w') as f:
        json.dump({
            'method': args.method,
            'n_samples': len(selected),
            'indices': selected,
            'coverage': coverage
        }, f, indent=2)

    logger.info(f"Saved to: {args.output}")
    print(json.dumps(coverage, indent=2))


if __name__ == '__main__':
    main()
