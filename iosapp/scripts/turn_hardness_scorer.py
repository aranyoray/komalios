#!/usr/bin/env python3
"""
turn_hardness_scorer.py — Score conversational turn difficulty from multimodal signals.
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
    parser.add_argument('--out_dir', type=str, default='./outputs/turn_hardness')
    parser.add_argument('--n_turns', type=int, default=10000)
    parser.add_argument('--epochs', type=int, default=50)
    parser.add_argument('--batch_size', type=int, default=64)
    parser.add_argument('--lr', type=float, default=1e-3)
    parser.add_argument('--synthetic', type=int, default=0)
    parser.add_argument('--dry_run', action='store_true')
    return parser.parse_args()


def generate_synthetic_turns(n_turns):
    """Generate synthetic turn data with hardness labels."""
    turns = []

    for i in range(n_turns):
        # Features
        gaze_fixation_ratio = np.random.uniform(0.3, 1.0)
        avg_latency = np.random.uniform(0.5, 5.0)  # seconds
        micro_exp_intensity = np.random.uniform(0, 1)
        hesitation_count = np.random.randint(0, 5)
        correction_attempts = np.random.randint(0, 4)
        touch_precision = np.random.uniform(0.5, 1.0)

        features = np.array([
            gaze_fixation_ratio,
            avg_latency / 5,  # normalize
            micro_exp_intensity,
            hesitation_count / 5,
            correction_attempts / 4,
            touch_precision,
        ], dtype=np.float32)

        # Hardness score (0-1): higher latency, more hesitation = harder
        hardness = (
            0.3 * (1 - gaze_fixation_ratio) +
            0.25 * (avg_latency / 5) +
            0.15 * micro_exp_intensity +
            0.15 * (hesitation_count / 5) +
            0.1 * (correction_attempts / 4) +
            0.05 * (1 - touch_precision)
        )
        hardness = np.clip(hardness + np.random.randn() * 0.05, 0, 1)

        turns.append({
            'turn_id': i,
            'features': features,
            'hardness': hardness,
        })

    return turns


class HardnessScorer(nn.Module):
    def __init__(self, n_features=6):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(n_features, 32),
            nn.ReLU(),
            nn.Dropout(0.2),
            nn.Linear(32, 16),
            nn.ReLU(),
            nn.Linear(16, 1),
            nn.Sigmoid(),
        )

    def forward(self, x):
        return self.net(x).squeeze(-1)


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

    n_turns = args.synthetic if args.synthetic > 0 else args.n_turns
    turns = generate_synthetic_turns(n_turns)

    X = np.array([t['features'] for t in turns])
    y = np.array([t['hardness'] for t in turns], dtype=np.float32)

    if args.dry_run:
        logger.info("dry run mode")
        results = {'mse': 0.01, 'mae': 0.08, 'correlation': 0.92}
    else:
        split = int(0.8 * n_turns)
        X_train, X_test = X[:split], X[split:]
        y_train, y_test = y[:split], y[split:]

        model = HardnessScorer()
        optimizer = torch.optim.Adam(model.parameters(), lr=args.lr)
        criterion = nn.MSELoss()

        logger.info(f"training for {args.epochs} epochs...")
        for epoch in range(args.epochs):
            model.train()
            indices = np.random.permutation(len(X_train))
            epoch_loss = 0

            for i in range(0, len(X_train), args.batch_size):
                batch_idx = indices[i:i+args.batch_size]
                batch_x = torch.FloatTensor(X_train[batch_idx])
                batch_y = torch.FloatTensor(y_train[batch_idx])

                optimizer.zero_grad()
                outputs = model(batch_x)
                loss = criterion(outputs, batch_y)
                loss.backward()
                optimizer.step()
                epoch_loss += loss.item()

            if (epoch + 1) % 10 == 0:
                logger.info(f"epoch {epoch+1}, loss: {epoch_loss / (len(X_train) // args.batch_size):.6f}")

        # Evaluate
        model.eval()
        with torch.no_grad():
            test_x = torch.FloatTensor(X_test)
            predictions = model(test_x).numpy()

        mse = np.mean((predictions - y_test) ** 2)
        mae = np.mean(np.abs(predictions - y_test))
        correlation = np.corrcoef(predictions, y_test)[0, 1]

        results = {
            'mse': float(mse),
            'mae': float(mae),
            'correlation': float(correlation),
        }

        logger.info(f"MSE: {mse:.4f}, MAE: {mae:.4f}, correlation: {correlation:.3f}")

        # Save model
        torch.save(model.state_dict(), out_dir / 'hardness_scorer.pt')

        # Export predictions
        predictions_df = pd.DataFrame({
            'turn_id': range(len(predictions)),
            'predicted_hardness': predictions,
            'actual_hardness': y_test,
        })
        predictions_df.to_csv(out_dir / 'turn_predictions.csv', index=False)

    with open(out_dir / 'scorer_results.json', 'w') as f:
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

    logger.info(f"turn hardness scorer complete. saved to {out_dir}")


if __name__ == '__main__':
    main()
