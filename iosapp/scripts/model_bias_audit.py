#!/usr/bin/env python3
"""
model_bias_audit.py — Test model fairness across age, skin tone, lighting, and device cameras.
"""

import argparse
import json
import logging
import hashlib
from pathlib import Path
from datetime import datetime

import numpy as np
import pandas as pd
import torch
import torch.nn as nn

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out_dir', type=str, default='./outputs/bias_audit')
    parser.add_argument('--n_samples_per_group', type=int, default=500)
    parser.add_argument('--synthetic', type=int, default=0)
    parser.add_argument('--dry_run', action='store_true')
    return parser.parse_args()


# Demographic groups
AGE_GROUPS = ['3-5', '6-8', '9-11', '12-15']
SKIN_TONES = ['I-II', 'III-IV', 'V-VI']  # Fitzpatrick scale
LIGHTING = ['bright', 'normal', 'dim', 'backlit']
CAMERAS = ['high_res', 'mid_res', 'low_res', 'front_facing']


class DummyModel(nn.Module):
    def __init__(self):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(768, 256),
            nn.ReLU(),
            nn.Linear(256, 7),
        )

    def forward(self, x):
        return self.net(x)


def generate_synthetic_data(n_per_group):
    """Generate synthetic test data for each demographic group."""
    data = []

    for age in AGE_GROUPS:
        for skin in SKIN_TONES:
            for light in LIGHTING:
                for camera in CAMERAS:
                    for _ in range(n_per_group):
                        # Base embedding
                        embedding = np.random.randn(768).astype(np.float32)

                        # True label
                        label = np.random.randint(0, 7)

                        # Add group-specific biases (to simulate real-world issues)
                        bias = 0
                        if skin == 'V-VI' and light == 'dim':
                            bias = 0.1  # harder to detect
                        if camera == 'low_res':
                            bias = 0.05
                        if age == '3-5':
                            bias += 0.03  # smaller faces

                        data.append({
                            'embedding': embedding,
                            'label': label,
                            'age_group': age,
                            'skin_tone': skin,
                            'lighting': light,
                            'camera': camera,
                            'bias': bias,
                        })

    return data


def compute_group_metrics(predictions, labels, groups, group_col):
    """Compute accuracy for each group."""
    metrics = {}

    unique_groups = sorted(set(groups))
    for group in unique_groups:
        mask = np.array(groups) == group
        if mask.sum() > 0:
            acc = (predictions[mask] == labels[mask]).mean()
            metrics[group] = float(acc)

    return metrics


def compute_bias_indices(group_metrics):
    """Compute bias indices from group metrics."""
    values = list(group_metrics.values())
    if len(values) < 2:
        return {'disparity': 0, 'min_max_ratio': 1}

    return {
        'disparity': float(max(values) - min(values)),
        'min_max_ratio': float(min(values) / (max(values) + 1e-8)),
        'std': float(np.std(values)),
    }


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

    n_per_group = args.synthetic if args.synthetic > 0 else args.n_samples_per_group
    data = generate_synthetic_data(n_per_group)

    if args.dry_run:
        logger.info("dry run mode")
        results = {
            'overall_accuracy': 0.85,
            'bias_indices': {
                'age': {'disparity': 0.05},
                'skin_tone': {'disparity': 0.08},
                'lighting': {'disparity': 0.12},
                'camera': {'disparity': 0.06},
            },
        }
    else:
        # Create model
        model = DummyModel()
        model.eval()

        # Get predictions
        embeddings = np.array([d['embedding'] for d in data])
        labels = np.array([d['label'] for d in data])

        with torch.no_grad():
            outputs = model(torch.FloatTensor(embeddings))
            predictions = outputs.argmax(1).numpy()

        # Simulate bias effects
        for i, d in enumerate(data):
            if np.random.rand() < d['bias']:
                predictions[i] = (predictions[i] + 1) % 7  # wrong prediction

        # Compute overall accuracy
        overall_acc = (predictions == labels).mean()

        # Compute per-group metrics
        logger.info("computing bias metrics...")

        age_metrics = compute_group_metrics(
            predictions, labels,
            [d['age_group'] for d in data], 'age_group'
        )
        skin_metrics = compute_group_metrics(
            predictions, labels,
            [d['skin_tone'] for d in data], 'skin_tone'
        )
        light_metrics = compute_group_metrics(
            predictions, labels,
            [d['lighting'] for d in data], 'lighting'
        )
        camera_metrics = compute_group_metrics(
            predictions, labels,
            [d['camera'] for d in data], 'camera'
        )

        # Compute bias indices
        results = {
            'overall_accuracy': float(overall_acc),
            'group_metrics': {
                'age': age_metrics,
                'skin_tone': skin_metrics,
                'lighting': light_metrics,
                'camera': camera_metrics,
            },
            'bias_indices': {
                'age': compute_bias_indices(age_metrics),
                'skin_tone': compute_bias_indices(skin_metrics),
                'lighting': compute_bias_indices(light_metrics),
                'camera': compute_bias_indices(camera_metrics),
            },
        }

        # Mitigation suggestions
        suggestions = []
        if results['bias_indices']['skin_tone']['disparity'] > 0.05:
            suggestions.append("Collect more training data for underrepresented skin tones")
            suggestions.append("Apply histogram equalization for darker skin tones")
        if results['bias_indices']['lighting']['disparity'] > 0.1:
            suggestions.append("Add synthetic lighting augmentation during training")
            suggestions.append("Use adaptive exposure compensation")
        if results['bias_indices']['camera']['disparity'] > 0.05:
            suggestions.append("Train with multi-resolution inputs")
            suggestions.append("Add camera-specific normalization")

        results['mitigation_suggestions'] = suggestions

        logger.info(f"overall accuracy: {overall_acc:.3f}")
        for category, idx in results['bias_indices'].items():
            logger.info(f"  {category} disparity: {idx['disparity']:.3f}")

    with open(out_dir / 'audit_results.json', 'w') as f:
        json.dump(results, f, indent=2)

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

    logger.info(f"bias audit complete. saved to {out_dir}")


if __name__ == '__main__':
    main()
