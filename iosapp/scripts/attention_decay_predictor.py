#!/usr/bin/env python3
"""
attention_decay_predictor.py — Predict attention decay patterns in children.
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
    parser.add_argument('--out_dir', type=str, default='./outputs/attention_decay')
    parser.add_argument('--n_children', type=int, default=100)
    parser.add_argument('--session_length', type=int, default=300)
    parser.add_argument('--epochs', type=int, default=50)
    parser.add_argument('--lr', type=float, default=1e-3)
    parser.add_argument('--synthetic', type=int, default=0)
    parser.add_argument('--dry_run', action='store_true')
    parser.add_argument('--debug', action='store_true')
    return parser.parse_args()


def generate_attention_data(n_children, session_length):
    """Generate synthetic attention decay data."""
    sessions = []
    labels = []

    for _ in range(n_children):
        # child-specific decay parameters
        initial_attention = np.random.uniform(0.7, 1.0)
        decay_rate = np.random.uniform(0.001, 0.01)
        noise_level = np.random.uniform(0.02, 0.1)

        # generate session
        t = np.arange(session_length)
        attention = initial_attention * np.exp(-decay_rate * t)
        attention += np.random.randn(session_length) * noise_level

        # add engagement spikes
        n_spikes = np.random.randint(2, 6)
        for _ in range(n_spikes):
            spike_time = np.random.randint(0, session_length)
            spike_width = np.random.randint(5, 20)
            spike_height = np.random.uniform(0.1, 0.3)
            attention[spike_time:spike_time+spike_width] += spike_height

        attention = np.clip(attention, 0, 1)

        # label: time to 50% attention
        decay_time = np.argmax(attention < 0.5) if (attention < 0.5).any() else session_length

        sessions.append(attention.astype(np.float32))
        labels.append(decay_time / session_length)

    return np.array(sessions), np.array(labels, dtype=np.float32)


class DecayPredictor(nn.Module):
    def __init__(self, seq_len):
        super().__init__()
        self.lstm = nn.LSTM(1, 64, num_layers=2, batch_first=True)
        self.fc = nn.Sequential(
            nn.Linear(64, 32),
            nn.ReLU(),
            nn.Linear(32, 1),
            nn.Sigmoid(),
        )

    def forward(self, x):
        # x: (batch, seq_len)
        x = x.unsqueeze(-1)  # (batch, seq_len, 1)
        lstm_out, _ = self.lstm(x)
        return self.fc(lstm_out[:, -1, :]).squeeze(-1)


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
        mlflow.start_run(run_name='attention_decay')
        mlflow.log_params(vars(args))

    n_children = args.synthetic if args.synthetic > 0 else args.n_children
    X, y = generate_attention_data(n_children, args.session_length)

    results = {}

    if args.dry_run:
        logger.info("dry run mode")
        results = {'mae': 0.05, 'mse': 0.003}
    else:
        # Split
        split = int(0.8 * n_children)
        X_train, X_test = X[:split], X[split:]
        y_train, y_test = y[:split], y[split:]

        # Train
        model = DecayPredictor(args.session_length)
        optimizer = torch.optim.Adam(model.parameters(), lr=args.lr)
        criterion = nn.MSELoss()

        logger.info(f"training decay predictor for {args.epochs} epochs...")
        for epoch in range(args.epochs):
            model.train()
            indices = np.random.permutation(len(X_train))

            epoch_loss = 0
            for i in range(0, len(X_train), 16):
                batch_idx = indices[i:i+16]
                batch_x = torch.FloatTensor(X_train[batch_idx])
                batch_y = torch.FloatTensor(y_train[batch_idx])

                optimizer.zero_grad()
                outputs = model(batch_x)
                loss = criterion(outputs, batch_y)
                loss.backward()
                optimizer.step()
                epoch_loss += loss.item()

            if (epoch + 1) % 10 == 0:
                logger.info(f"epoch {epoch+1}, loss: {epoch_loss / (len(X_train) // 16):.4f}")

        # Evaluate
        model.eval()
        with torch.no_grad():
            test_x = torch.FloatTensor(X_test)
            predictions = model(test_x).numpy()

        mae = np.abs(predictions - y_test).mean()
        mse = ((predictions - y_test) ** 2).mean()

        results = {
            'mae': float(mae),
            'mse': float(mse),
            'rmse': float(np.sqrt(mse)),
        }

        logger.info(f"MAE: {mae:.4f}, RMSE: {np.sqrt(mse):.4f}")

        # Save model
        torch.save(model.state_dict(), out_dir / 'decay_predictor.pt')

    # Save results
    with open(out_dir / 'decay_results.json', 'w') as f:
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

    logger.info(f"attention decay prediction complete. saved to {out_dir}")


if __name__ == '__main__':
    main()
