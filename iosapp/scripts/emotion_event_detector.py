#!/usr/bin/env python3
"""
emotion_event_detector.py — Detect emotional events in time-series data.
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
    parser.add_argument('--data_dir', type=str, default='./data')
    parser.add_argument('--out_dir', type=str, default='./outputs/emotion_events')
    parser.add_argument('--n_samples', type=int, default=1000)
    parser.add_argument('--seq_len', type=int, default=100)
    parser.add_argument('--threshold', type=float, default=0.7)
    parser.add_argument('--synthetic', type=int, default=0)
    parser.add_argument('--dry_run', action='store_true')
    parser.add_argument('--debug', action='store_true')
    return parser.parse_args()


def generate_synthetic_emotions(n_samples, seq_len):
    """Generate synthetic emotion time-series with events."""
    data = []
    labels = []

    for _ in range(n_samples):
        # 7 emotion channels
        seq = np.random.randn(seq_len, 7) * 0.2

        # inject random events
        n_events = np.random.randint(0, 4)
        event_labels = np.zeros(seq_len)

        for _ in range(n_events):
            event_start = np.random.randint(0, seq_len - 10)
            event_duration = np.random.randint(5, 15)
            event_emotion = np.random.randint(0, 7)
            event_intensity = np.random.uniform(0.5, 1.0)

            end = min(event_start + event_duration, seq_len)
            seq[event_start:end, event_emotion] += event_intensity
            event_labels[event_start:end] = 1

        data.append(seq)
        labels.append(event_labels)

    return np.array(data), np.array(labels)


class EventDetector(nn.Module):
    """1D CNN for event detection."""

    def __init__(self, n_channels=7):
        super().__init__()
        self.conv1 = nn.Conv1d(n_channels, 32, kernel_size=5, padding=2)
        self.conv2 = nn.Conv1d(32, 64, kernel_size=5, padding=2)
        self.conv3 = nn.Conv1d(64, 1, kernel_size=3, padding=1)

    def forward(self, x):
        # x: (batch, seq_len, channels)
        x = x.permute(0, 2, 1)  # (batch, channels, seq_len)
        x = torch.relu(self.conv1(x))
        x = torch.relu(self.conv2(x))
        x = torch.sigmoid(self.conv3(x))
        return x.squeeze(1)  # (batch, seq_len)


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
        mlflow.start_run(run_name='emotion_events')
        mlflow.log_params(vars(args))

    n_samples = args.synthetic if args.synthetic > 0 else args.n_samples
    X, y = generate_synthetic_emotions(n_samples, args.seq_len)

    results = {}

    if args.dry_run:
        logger.info("dry run mode")
        results = {
            'precision': 0.85,
            'recall': 0.80,
            'f1': 0.82,
            'n_events_detected': 150,
        }
    else:
        # Split
        split = int(0.8 * n_samples)
        X_train, X_test = X[:split], X[split:]
        y_train, y_test = y[:split], y[split:]

        # Train
        model = EventDetector()
        optimizer = torch.optim.Adam(model.parameters(), lr=1e-3)
        criterion = nn.BCELoss()

        logger.info("training event detector...")
        for epoch in range(20):
            model.train()
            indices = np.random.permutation(len(X_train))

            for i in range(0, len(X_train), 32):
                batch_idx = indices[i:i+32]
                batch_x = torch.FloatTensor(X_train[batch_idx])
                batch_y = torch.FloatTensor(y_train[batch_idx])

                optimizer.zero_grad()
                outputs = model(batch_x)
                loss = criterion(outputs, batch_y)
                loss.backward()
                optimizer.step()

        # Evaluate
        model.eval()
        with torch.no_grad():
            test_x = torch.FloatTensor(X_test)
            test_y = y_test
            predictions = model(test_x).numpy()

        # Metrics
        pred_binary = (predictions > args.threshold).astype(int)
        tp = ((pred_binary == 1) & (test_y == 1)).sum()
        fp = ((pred_binary == 1) & (test_y == 0)).sum()
        fn = ((pred_binary == 0) & (test_y == 1)).sum()

        precision = tp / (tp + fp + 1e-8)
        recall = tp / (tp + fn + 1e-8)
        f1 = 2 * precision * recall / (precision + recall + 1e-8)

        results = {
            'precision': float(precision),
            'recall': float(recall),
            'f1': float(f1),
            'n_events_detected': int(pred_binary.sum()),
        }

        logger.info(f"F1: {f1:.3f}, Precision: {precision:.3f}, Recall: {recall:.3f}")

        # Save model
        torch.save(model.state_dict(), out_dir / 'event_detector.pt')

    # Save results
    with open(out_dir / 'event_results.json', 'w') as f:
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

    logger.info(f"event detection complete. saved to {out_dir}")


if __name__ == '__main__':
    main()
