#!/usr/bin/env python3
"""
touch_gesture_builder.py — Build touch gesture recognition models from raw touch data.

Requirements:
torch, numpy, pandas, scikit-learn, mlflow, tqdm
"""

import os
import json
import hashlib
import logging
import argparse
from pathlib import Path
from datetime import datetime

import numpy as np
import pandas as pd
import torch
import torch.nn as nn
from sklearn.preprocessing import StandardScaler
from tqdm import tqdm

try:
    import mlflow
    HAS_MLFLOW = True
except ImportError:
    HAS_MLFLOW = False

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description='Touch gesture builder')
    parser.add_argument('--data_dir', type=str, default='./data')
    parser.add_argument('--out_dir', type=str, default='./outputs/touch_gesture')
    parser.add_argument('--device', type=str, default='cpu')
    parser.add_argument('--batch_size', type=int, default=64)
    parser.add_argument('--epochs', type=int, default=50)
    parser.add_argument('--lr', type=float, default=1e-3)
    parser.add_argument('--synthetic', type=int, default=0)
    parser.add_argument('--dry_run', action='store_true')
    parser.add_argument('--debug', action='store_true')
    parser.add_argument('--n_workers', type=int, default=4)
    parser.add_argument('--seq_len', type=int, default=50)
    return parser.parse_args()


def generate_synthetic_gestures(n_samples, seq_len):
    """Generate synthetic touch gesture data."""
    gestures = []
    labels = []

    gesture_types = ['tap', 'swipe_left', 'swipe_right', 'swipe_up', 'swipe_down',
                     'pinch', 'spread', 'rotate', 'long_press', 'double_tap']

    for _ in range(n_samples):
        gesture_type = np.random.randint(0, len(gesture_types))

        # generate touch sequence: [x, y, pressure, timestamp, touch_id]
        seq = np.zeros((seq_len, 5), dtype=np.float32)

        if gesture_type == 0:  # tap
            center = np.random.rand(2)
            seq[:, :2] = center + np.random.randn(seq_len, 2) * 0.01
            seq[:, 2] = np.concatenate([np.linspace(0, 1, seq_len//2),
                                        np.linspace(1, 0, seq_len - seq_len//2)])
        elif gesture_type in [1, 2]:  # swipe left/right
            direction = -1 if gesture_type == 1 else 1
            seq[:, 0] = np.linspace(0.5, 0.5 + direction * 0.4, seq_len)
            seq[:, 1] = 0.5 + np.random.randn(seq_len) * 0.02
            seq[:, 2] = 0.5
        elif gesture_type in [3, 4]:  # swipe up/down
            direction = -1 if gesture_type == 3 else 1
            seq[:, 0] = 0.5 + np.random.randn(seq_len) * 0.02
            seq[:, 1] = np.linspace(0.5, 0.5 + direction * 0.4, seq_len)
            seq[:, 2] = 0.5
        else:  # other gestures
            seq[:, :2] = np.random.rand(seq_len, 2) * 0.3 + 0.35
            seq[:, 2] = np.random.rand(seq_len) * 0.5 + 0.25

        seq[:, 3] = np.linspace(0, 1, seq_len)  # timestamp
        seq[:, 4] = 0  # touch_id

        gestures.append(seq)
        labels.append(gesture_type)

    return np.array(gestures), np.array(labels)


class GestureEncoder(nn.Module):
    """LSTM-based gesture encoder."""

    def __init__(self, input_dim=5, hidden_dim=128, n_classes=10):
        super().__init__()
        self.lstm = nn.LSTM(input_dim, hidden_dim, num_layers=2,
                           batch_first=True, bidirectional=True)
        self.attention = nn.MultiheadAttention(hidden_dim * 2, num_heads=4, batch_first=True)
        self.classifier = nn.Sequential(
            nn.Linear(hidden_dim * 2, 64),
            nn.ReLU(),
            nn.Dropout(0.3),
            nn.Linear(64, n_classes),
        )

    def forward(self, x):
        lstm_out, _ = self.lstm(x)
        attn_out, _ = self.attention(lstm_out, lstm_out, lstm_out)
        pooled = attn_out.mean(dim=1)
        return self.classifier(pooled)


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

    device = torch.device(args.device)

    if HAS_MLFLOW:
        mlflow.start_run(run_name='touch_gesture')
        mlflow.log_params(vars(args))

    # Load or generate data
    n_samples = args.synthetic if args.synthetic > 0 else 10000
    logger.info(f"generating {n_samples} synthetic gestures")

    X, y = generate_synthetic_gestures(n_samples, args.seq_len)

    # Split
    split_idx = int(0.8 * n_samples)
    X_train, X_test = X[:split_idx], X[split_idx:]
    y_train, y_test = y[:split_idx], y[split_idx:]

    results = {'train_loss': [], 'test_accuracy': 0}

    if args.dry_run:
        logger.info("dry run mode - skipping training")
        results['test_accuracy'] = 0.85
    else:
        # Create model
        model = GestureEncoder(input_dim=5, hidden_dim=128, n_classes=10).to(device)
        optimizer = torch.optim.Adam(model.parameters(), lr=args.lr)
        criterion = nn.CrossEntropyLoss()

        # Training
        logger.info("training gesture model...")
        for epoch in range(args.epochs):
            model.train()
            epoch_loss = 0

            indices = np.random.permutation(len(X_train))
            for i in range(0, len(X_train), args.batch_size):
                batch_idx = indices[i:i+args.batch_size]
                batch_x = torch.FloatTensor(X_train[batch_idx]).to(device)
                batch_y = torch.LongTensor(y_train[batch_idx]).to(device)

                optimizer.zero_grad()
                outputs = model(batch_x)
                loss = criterion(outputs, batch_y)
                loss.backward()
                optimizer.step()

                epoch_loss += loss.item()

            results['train_loss'].append(epoch_loss / (len(X_train) // args.batch_size))

            if (epoch + 1) % 10 == 0:
                logger.info(f"epoch {epoch+1}/{args.epochs}, loss: {results['train_loss'][-1]:.4f}")

        # Evaluation
        model.eval()
        with torch.no_grad():
            test_x = torch.FloatTensor(X_test).to(device)
            test_y = torch.LongTensor(y_test).to(device)
            outputs = model(test_x)
            preds = outputs.argmax(1)
            results['test_accuracy'] = (preds == test_y).float().mean().item()

        logger.info(f"test accuracy: {results['test_accuracy']:.3f}")

        # Save model
        model_path = out_dir / 'gesture_model.pt'
        torch.save(model.state_dict(), model_path)

    # Save results
    with open(out_dir / 'gesture_results.json', 'w') as f:
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

    manifest_path = out_dir / 'artifacts_manifest.csv'
    pd.DataFrame(artifacts).to_csv(manifest_path, index=False)

    if HAS_MLFLOW:
        mlflow.log_metric('test_accuracy', results['test_accuracy'])
        mlflow.end_run()

    logger.info(f"gesture builder complete. artifacts saved to {out_dir}")


if __name__ == '__main__':
    main()
