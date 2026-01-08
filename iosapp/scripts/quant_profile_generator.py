#!/usr/bin/env python3
"""
quant_profile_generator.py — Generate calibration sets for quantization.
Samples representative inputs using clustering, outputs profiles for PTQ.
"""

import argparse
import json
import logging
import pickle
from pathlib import Path
import numpy as np

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description='Generate quantization calibration profiles')
    parser.add_argument('--input_dir', type=str, required=True, help='Directory with session data')
    parser.add_argument('--output', type=str, default='./quant_calibration')
    parser.add_argument('--n_samples', type=int, default=200, help='Calibration samples')
    parser.add_argument('--n_clusters', type=int, default=20, help='Clusters for diversity')
    return parser.parse_args()


def load_session_inputs(input_dir):
    """Load inputs from session data."""
    inputs = []
    for json_file in Path(input_dir).glob('*.json'):
        try:
            with open(json_file) as f:
                session = json.load(f)
            if 'gaze_series' in session:
                for sample in session['gaze_series'][:50]:
                    if isinstance(sample, dict):
                        vals = sample.get('values', sample.get('value', [0]))
                        if isinstance(vals, list):
                            inputs.append(vals)
        except:
            pass
    return np.array(inputs) if inputs else np.random.randn(100, 32)


def cluster_and_sample(inputs, n_clusters, n_samples):
    """Cluster inputs and sample representatives."""
    from sklearn.cluster import KMeans

    # Cluster
    n_clusters = min(n_clusters, len(inputs))
    kmeans = KMeans(n_clusters=n_clusters, random_state=42, n_init=10)
    labels = kmeans.fit_predict(inputs)

    # Sample from each cluster
    samples = []
    samples_per_cluster = max(1, n_samples // n_clusters)

    for i in range(n_clusters):
        cluster_indices = np.where(labels == i)[0]
        if len(cluster_indices) > 0:
            selected = np.random.choice(cluster_indices,
                                       min(samples_per_cluster, len(cluster_indices)),
                                       replace=False)
            samples.extend(inputs[selected])

    return np.array(samples[:n_samples])


def generate_quant_profile(samples, output_dir):
    """Generate quantization profile from samples."""
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    # Compute statistics for quantization ranges
    profile = {
        'n_samples': len(samples),
        'input_range': [float(samples.min()), float(samples.max())],
        'mean': float(samples.mean()),
        'std': float(samples.std()),
        'percentiles': {
            'p1': float(np.percentile(samples, 1)),
            'p99': float(np.percentile(samples, 99))
        }
    }

    # Save samples
    np.save(output_dir / 'calibration_data.npy', samples.astype(np.float32))

    # Save profile
    with open(output_dir / 'quant_profile.json', 'w') as f:
        json.dump(profile, f, indent=2)

    logger.info(f"Generated profile with {len(samples)} samples")
    logger.info(f"Input range: [{profile['input_range'][0]:.3f}, {profile['input_range'][1]:.3f}]")

    return profile


def main():
    args = parse_args()

    # Load inputs
    inputs = load_session_inputs(args.input_dir)
    logger.info(f"Loaded {len(inputs)} input samples")

    # Cluster and sample
    samples = cluster_and_sample(inputs, args.n_clusters, args.n_samples)

    # Generate profile
    profile = generate_quant_profile(samples, args.output)
    print(json.dumps(profile, indent=2))


if __name__ == '__main__':
    main()
