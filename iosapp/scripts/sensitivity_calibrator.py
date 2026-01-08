#!/usr/bin/env python3
"""
sensitivity_calibrator.py — Calibrate model sensitivity thresholds per-child.
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
from sklearn.metrics import roc_curve, precision_recall_curve

try:
    import mlflow
    HAS_MLFLOW = True
except ImportError:
    HAS_MLFLOW = False

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--data_dir', type=str, default='./data')
    parser.add_argument('--out_dir', type=str, default='./outputs/sensitivity')
    parser.add_argument('--n_children', type=int, default=100)
    parser.add_argument('--n_samples', type=int, default=1000)
    parser.add_argument('--synthetic', type=int, default=0)
    parser.add_argument('--dry_run', action='store_true')
    parser.add_argument('--debug', action='store_true')
    return parser.parse_args()


def generate_synthetic_responses(n_children, n_samples):
    """Generate synthetic child response data."""
    data = []
    for child_id in range(n_children):
        # child-specific sensitivity profile
        base_threshold = np.random.uniform(0.3, 0.7)
        noise_level = np.random.uniform(0.05, 0.2)

        for _ in range(n_samples):
            score = np.random.rand()
            true_label = 1 if score > base_threshold + np.random.randn() * noise_level else 0
            data.append({
                'child_id': child_id,
                'score': score,
                'label': true_label,
                'age': np.random.randint(3, 16),
                'session': np.random.randint(0, 20),
            })
    return pd.DataFrame(data)


def calibrate_threshold(scores, labels, method='f1'):
    """Find optimal threshold for a child."""
    if method == 'f1':
        precision, recall, thresholds = precision_recall_curve(labels, scores)
        f1_scores = 2 * (precision * recall) / (precision + recall + 1e-8)
        best_idx = np.argmax(f1_scores[:-1])
        return thresholds[best_idx], f1_scores[best_idx]
    elif method == 'youden':
        fpr, tpr, thresholds = roc_curve(labels, scores)
        youden = tpr - fpr
        best_idx = np.argmax(youden)
        return thresholds[best_idx], youden[best_idx]
    return 0.5, 0.0


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
        mlflow.start_run(run_name='sensitivity_calibrator')
        mlflow.log_params(vars(args))

    n_samples = args.synthetic if args.synthetic > 0 else args.n_samples
    df = generate_synthetic_responses(args.n_children, n_samples)

    calibrations = []

    if args.dry_run:
        logger.info("dry run mode")
        for child_id in range(args.n_children):
            calibrations.append({
                'child_id': child_id,
                'threshold': 0.5,
                'f1_score': 0.8,
            })
    else:
        logger.info(f"calibrating thresholds for {args.n_children} children...")
        for child_id in range(args.n_children):
            child_data = df[df['child_id'] == child_id]
            threshold, score = calibrate_threshold(
                child_data['score'].values,
                child_data['label'].values
            )
            calibrations.append({
                'child_id': child_id,
                'threshold': float(threshold),
                'f1_score': float(score),
            })

    # Save calibrations
    cal_df = pd.DataFrame(calibrations)
    cal_df.to_csv(out_dir / 'calibrations.csv', index=False)

    results = {
        'mean_threshold': float(cal_df['threshold'].mean()),
        'std_threshold': float(cal_df['threshold'].std()),
        'mean_f1': float(cal_df['f1_score'].mean()),
    }

    with open(out_dir / 'calibration_results.json', 'w') as f:
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
        mlflow.log_metrics(results)
        mlflow.end_run()

    logger.info(f"calibration complete. saved to {out_dir}")


if __name__ == '__main__':
    main()
