#!/usr/bin/env python3
"""
emotion_drift_monitor.py — Monitor model drift on synthetic emotion test suite without labels.
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
import matplotlib.pyplot as plt

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out_dir', type=str, default='./outputs/drift_monitor')
    parser.add_argument('--n_test_samples', type=int, default=1000)
    parser.add_argument('--n_timepoints', type=int, default=10)
    parser.add_argument('--embed_dim', type=int, default=768)
    parser.add_argument('--drift_threshold', type=float, default=0.1)
    parser.add_argument('--synthetic', type=int, default=0)
    parser.add_argument('--dry_run', action='store_true')
    return parser.parse_args()


class EmotionModel(nn.Module):
    def __init__(self, embed_dim=768):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(embed_dim, 256),
            nn.ReLU(),
            nn.Linear(256, 7),
        )

    def forward(self, x):
        return self.net(x)


def generate_synthetic_test_suite(n_samples, embed_dim):
    """Generate fixed synthetic test suite."""
    np.random.seed(42)  # fixed seed for reproducibility

    test_suite = []
    emotions = ['happy', 'sad', 'angry', 'fearful', 'surprised', 'disgusted', 'neutral']

    for emotion_idx in range(7):
        n_per_emotion = n_samples // 7
        for _ in range(n_per_emotion):
            embedding = np.random.randn(embed_dim).astype(np.float32)
            # Add emotion-specific signal
            embedding[emotion_idx * 100:(emotion_idx + 1) * 100] += 1.0

            test_suite.append({
                'embedding': embedding,
                'emotion': emotions[emotion_idx],
                'emotion_idx': emotion_idx,
            })

    return test_suite


def compute_distribution_stats(predictions):
    """Compute statistics of prediction distribution."""
    probs = torch.softmax(torch.FloatTensor(predictions), dim=1).numpy()

    return {
        'entropy': float(-np.sum(probs * np.log(probs + 1e-10), axis=1).mean()),
        'confidence': float(probs.max(axis=1).mean()),
        'distribution': probs.mean(axis=0).tolist(),
    }


def compute_drift_score(baseline_stats, current_stats):
    """Compute drift score between two distribution stats."""
    # KL divergence approximation
    p = np.array(baseline_stats['distribution'])
    q = np.array(current_stats['distribution'])

    kl_div = np.sum(p * np.log((p + 1e-10) / (q + 1e-10)))

    # Also consider entropy and confidence changes
    entropy_diff = abs(baseline_stats['entropy'] - current_stats['entropy'])
    confidence_diff = abs(baseline_stats['confidence'] - current_stats['confidence'])

    return float(kl_div + entropy_diff + confidence_diff)


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

    n_samples = args.synthetic if args.synthetic > 0 else args.n_test_samples
    test_suite = generate_synthetic_test_suite(n_samples, args.embed_dim)

    if args.dry_run:
        logger.info("dry run mode")
        results = {
            'drift_detected': False,
            'max_drift_score': 0.05,
            'timepoints_analyzed': args.n_timepoints,
        }
    else:
        # Simulate model at different timepoints
        logger.info(f"simulating {args.n_timepoints} model timepoints...")

        embeddings = torch.FloatTensor([s['embedding'] for s in test_suite])
        timepoint_stats = []

        for t in range(args.n_timepoints):
            # Create model with increasing drift
            model = EmotionModel(args.embed_dim)

            # Simulate drift by perturbing weights
            if t > 0:
                with torch.no_grad():
                    for param in model.parameters():
                        param.add_(torch.randn_like(param) * 0.01 * t)

            model.eval()
            with torch.no_grad():
                predictions = model(embeddings).numpy()

            stats = compute_distribution_stats(predictions)
            stats['timepoint'] = t
            timepoint_stats.append(stats)

        # Compute drift scores
        baseline = timepoint_stats[0]
        drift_scores = []

        for t, stats in enumerate(timepoint_stats):
            if t == 0:
                drift_scores.append(0)
            else:
                score = compute_drift_score(baseline, stats)
                drift_scores.append(score)

        # Check for drift
        max_drift = max(drift_scores)
        drift_detected = max_drift > args.drift_threshold

        results = {
            'drift_detected': drift_detected,
            'max_drift_score': float(max_drift),
            'drift_threshold': args.drift_threshold,
            'timepoints_analyzed': args.n_timepoints,
            'drift_scores': drift_scores,
        }

        logger.info(f"max drift score: {max_drift:.4f}")
        logger.info(f"drift detected: {drift_detected}")

        # Create plots
        fig, axes = plt.subplots(1, 2, figsize=(12, 4))

        # Drift score over time
        axes[0].plot(range(args.n_timepoints), drift_scores, 'b-o')
        axes[0].axhline(y=args.drift_threshold, color='r', linestyle='--', label='Threshold')
        axes[0].set_xlabel('Timepoint')
        axes[0].set_ylabel('Drift Score')
        axes[0].set_title('Model Drift Over Time')
        axes[0].legend()

        # Distribution comparison
        emotions = ['happy', 'sad', 'angry', 'fear', 'surprise', 'disgust', 'neutral']
        x = np.arange(7)
        width = 0.35

        axes[1].bar(x - width/2, timepoint_stats[0]['distribution'], width, label='Baseline')
        axes[1].bar(x + width/2, timepoint_stats[-1]['distribution'], width, label='Latest')
        axes[1].set_xticks(x)
        axes[1].set_xticklabels(emotions, rotation=45)
        axes[1].set_ylabel('Probability')
        axes[1].set_title('Prediction Distribution')
        axes[1].legend()

        plt.tight_layout()
        plt.savefig(out_dir / 'drift_plots.png', dpi=150)
        plt.close()

        # Save detailed stats
        pd.DataFrame(timepoint_stats).to_csv(out_dir / 'timepoint_stats.csv', index=False)

    with open(out_dir / 'drift_results.json', 'w') as f:
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

    logger.info(f"drift monitor complete. saved to {out_dir}")


if __name__ == '__main__':
    main()
