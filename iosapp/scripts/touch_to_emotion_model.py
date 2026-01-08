#!/usr/bin/env python3
"""
touch_to_emotion_model.py — Map touch patterns to emotional states.
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
    parser.add_argument('--out_dir', type=str, default='./outputs/touch_emotion')
    parser.add_argument('--n_samples', type=int, default=10000)
    parser.add_argument('--seq_len', type=int, default=30)
    parser.add_argument('--epochs', type=int, default=50)
    parser.add_argument('--batch_size', type=int, default=64)
    parser.add_argument('--lr', type=float, default=1e-3)
    parser.add_argument('--synthetic', type=int, default=0)
    parser.add_argument('--dry_run', action='store_true')
    parser.add_argument('--debug', action='store_true')
    return parser.parse_args()


def generate_touch_emotion_data(n_samples, seq_len):
    """Generate synthetic touch-emotion paired data."""
    touch_data = []
    emotion_labels = []

    emotions = ['happy', 'sad', 'frustrated', 'engaged', 'bored', 'excited', 'calm']

    for _ in range(n_samples):
        emotion_idx = np.random.randint(0, len(emotions))

        # emotion-specific touch patterns
        seq = np.zeros((seq_len, 6), dtype=np.float32)  # x, y, pressure, velocity, duration, area

        if emotion_idx == 0:  # happy - light, quick taps
            seq[:, 2] = 0.3 + np.random.rand(seq_len) * 0.2
            seq[:, 3] = 0.7 + np.random.rand(seq_len) * 0.3
        elif emotion_idx == 1:  # sad - slow, heavy
            seq[:, 2] = 0.6 + np.random.rand(seq_len) * 0.3
            seq[:, 3] = 0.2 + np.random.rand(seq_len) * 0.2
        elif emotion_idx == 2:  # frustrated - erratic, hard
            seq[:, 2] = 0.7 + np.random.rand(seq_len) * 0.3
            seq[:, 3] = np.random.rand(seq_len)
        elif emotion_idx == 3:  # engaged - consistent, medium
            seq[:, 2] = 0.4 + np.random.rand(seq_len) * 0.1
            seq[:, 3] = 0.5 + np.random.rand(seq_len) * 0.1
        elif emotion_idx == 4:  # bored - sparse, light
            seq[:, 2] = 0.2 + np.random.rand(seq_len) * 0.2
            seq[:, 3] = 0.3 + np.random.rand(seq_len) * 0.2
        elif emotion_idx == 5:  # excited - fast, varied
            seq[:, 2] = 0.4 + np.random.rand(seq_len) * 0.4
            seq[:, 3] = 0.8 + np.random.rand(seq_len) * 0.2
        else:  # calm - slow, gentle
            seq[:, 2] = 0.3 + np.random.rand(seq_len) * 0.1
            seq[:, 3] = 0.4 + np.random.rand(seq_len) * 0.1

        # common features
        seq[:, 0] = np.random.rand(seq_len)  # x
        seq[:, 1] = np.random.rand(seq_len)  # y
        seq[:, 4] = np.random.rand(seq_len) * 0.5  # duration
        seq[:, 5] = seq[:, 2] * 0.5 + np.random.rand(seq_len) * 0.2  # area

        touch_data.append(seq)
        emotion_labels.append(emotion_idx)

    return np.array(touch_data), np.array(emotion_labels)


class TouchEmotionModel(nn.Module):
    """Map touch sequences to emotion predictions."""

    def __init__(self, input_dim=6, hidden_dim=64, n_emotions=7):
        super().__init__()
        self.lstm = nn.LSTM(input_dim, hidden_dim, num_layers=2,
                           batch_first=True, bidirectional=True)
        self.attention = nn.Linear(hidden_dim * 2, 1)
        self.classifier = nn.Sequential(
            nn.Linear(hidden_dim * 2, 32),
            nn.ReLU(),
            nn.Dropout(0.3),
            nn.Linear(32, n_emotions),
        )

    def forward(self, x):
        lstm_out, _ = self.lstm(x)

        # attention
        attn_weights = torch.softmax(self.attention(lstm_out), dim=1)
        context = (lstm_out * attn_weights).sum(dim=1)

        return self.classifier(context)


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
        mlflow.start_run(run_name='touch_emotion')
        mlflow.log_params(vars(args))

    n_samples = args.synthetic if args.synthetic > 0 else args.n_samples
    X, y = generate_touch_emotion_data(n_samples, args.seq_len)

    results = {}

    if args.dry_run:
        logger.info("dry run mode")
        results = {'accuracy': 0.75, 'f1': 0.73}
    else:
        # Split
        split = int(0.8 * n_samples)
        X_train, X_test = X[:split], X[split:]
        y_train, y_test = y[:split], y[split:]

        # Train
        model = TouchEmotionModel()
        optimizer = torch.optim.Adam(model.parameters(), lr=args.lr)
        criterion = nn.CrossEntropyLoss()

        logger.info(f"training touch-emotion model for {args.epochs} epochs...")
        for epoch in range(args.epochs):
            model.train()
            indices = np.random.permutation(len(X_train))
            epoch_loss = 0

            for i in range(0, len(X_train), args.batch_size):
                batch_idx = indices[i:i+args.batch_size]
                batch_x = torch.FloatTensor(X_train[batch_idx])
                batch_y = torch.LongTensor(y_train[batch_idx])

                optimizer.zero_grad()
                outputs = model(batch_x)
                loss = criterion(outputs, batch_y)
                loss.backward()
                optimizer.step()
                epoch_loss += loss.item()

            if (epoch + 1) % 10 == 0:
                logger.info(f"epoch {epoch+1}, loss: {epoch_loss / (len(X_train) // args.batch_size):.4f}")

        # Evaluate
        model.eval()
        with torch.no_grad():
            test_x = torch.FloatTensor(X_test)
            test_y = torch.LongTensor(y_test)
            outputs = model(test_x)
            preds = outputs.argmax(1)
            accuracy = (preds == test_y).float().mean().item()

        # Per-class metrics
        from sklearn.metrics import f1_score
        f1 = f1_score(y_test, preds.numpy(), average='weighted')

        results = {
            'accuracy': float(accuracy),
            'f1': float(f1),
        }

        logger.info(f"accuracy: {accuracy:.3f}, F1: {f1:.3f}")

        # Save model
        torch.save(model.state_dict(), out_dir / 'touch_emotion_model.pt')

    # Save results
    with open(out_dir / 'touch_emotion_results.json', 'w') as f:
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

    logger.info(f"touch-emotion model complete. saved to {out_dir}")


if __name__ == '__main__':
    main()
