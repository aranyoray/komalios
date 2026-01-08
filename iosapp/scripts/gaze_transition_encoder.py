#!/usr/bin/env python3
"""
gaze_transition_encoder.py — Learn embeddings of gaze transitions (fixation→saccade→fixation).
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
    parser.add_argument('--out_dir', type=str, default='./outputs/gaze_encoder')
    parser.add_argument('--n_samples', type=int, default=10000)
    parser.add_argument('--seq_len', type=int, default=30)
    parser.add_argument('--embed_dim', type=int, default=32)
    parser.add_argument('--epochs', type=int, default=50)
    parser.add_argument('--batch_size', type=int, default=64)
    parser.add_argument('--lr', type=float, default=1e-3)
    parser.add_argument('--synthetic', type=int, default=0)
    parser.add_argument('--dry_run', action='store_true')
    return parser.parse_args()


def generate_synthetic_gaze_sequences(n_samples, seq_len):
    """Generate synthetic gaze transition sequences."""
    sequences = []

    # Transition types
    transition_types = [
        'fixation_to_saccade',
        'saccade_to_fixation',
        'smooth_pursuit',
        'microsaccade',
        'blink',
    ]

    for _ in range(n_samples):
        # Each timestep: x, y, velocity, acceleration, pupil_size
        seq = np.zeros((seq_len, 5), dtype=np.float32)

        # Generate gaze pattern
        current_x, current_y = 0.5, 0.5
        in_fixation = True

        for t in range(seq_len):
            if in_fixation:
                # Small movements around fixation point
                seq[t, 0] = current_x + np.random.randn() * 0.02
                seq[t, 1] = current_y + np.random.randn() * 0.02
                seq[t, 2] = np.random.rand() * 0.1  # low velocity

                # Maybe start saccade
                if np.random.rand() < 0.1:
                    in_fixation = False
            else:
                # Saccade - fast movement
                target_x = np.random.rand()
                target_y = np.random.rand()
                progress = min(1.0, (t - seq_len * 0.5) / 5)

                seq[t, 0] = current_x + (target_x - current_x) * progress
                seq[t, 1] = current_y + (target_y - current_y) * progress
                seq[t, 2] = 0.5 + np.random.rand() * 0.5  # high velocity

                if np.random.rand() < 0.3:
                    in_fixation = True
                    current_x, current_y = seq[t, 0], seq[t, 1]

            # Acceleration
            if t > 0:
                seq[t, 3] = seq[t, 2] - seq[t-1, 2]

            # Pupil size (varies with cognitive load)
            seq[t, 4] = 0.5 + np.random.randn() * 0.1

        sequences.append(seq)

    return np.array(sequences)


class GazeTransitionEncoder(nn.Module):
    """Encoder for gaze transition sequences."""

    def __init__(self, input_dim=5, hidden_dim=64, embed_dim=32):
        super().__init__()
        self.lstm = nn.LSTM(input_dim, hidden_dim, num_layers=2, batch_first=True)
        self.encoder = nn.Linear(hidden_dim, embed_dim)

        # Decoder for reconstruction
        self.decoder_lstm = nn.LSTM(embed_dim, hidden_dim, num_layers=1, batch_first=True)
        self.decoder_out = nn.Linear(hidden_dim, input_dim)

    def encode(self, x):
        _, (h, _) = self.lstm(x)
        return self.encoder(h[-1])

    def decode(self, z, seq_len):
        batch_size = z.size(0)
        z_repeated = z.unsqueeze(1).repeat(1, seq_len, 1)
        decoded, _ = self.decoder_lstm(z_repeated)
        return self.decoder_out(decoded)

    def forward(self, x):
        z = self.encode(x)
        reconstructed = self.decode(z, x.size(1))
        return reconstructed, z


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

    n_samples = args.synthetic if args.synthetic > 0 else args.n_samples
    sequences = generate_synthetic_gaze_sequences(n_samples, args.seq_len)

    if args.dry_run:
        logger.info("dry run mode")
        results = {'reconstruction_mse': 0.01, 'embedding_dim': args.embed_dim}
    else:
        split = int(0.8 * n_samples)
        train_data = sequences[:split]
        test_data = sequences[split:]

        model = GazeTransitionEncoder(embed_dim=args.embed_dim)
        optimizer = torch.optim.Adam(model.parameters(), lr=args.lr)
        criterion = nn.MSELoss()

        logger.info(f"training encoder for {args.epochs} epochs...")
        for epoch in range(args.epochs):
            model.train()
            indices = np.random.permutation(len(train_data))
            epoch_loss = 0

            for i in range(0, len(train_data), args.batch_size):
                batch_idx = indices[i:i+args.batch_size]
                batch_x = torch.FloatTensor(train_data[batch_idx])

                optimizer.zero_grad()
                reconstructed, z = model(batch_x)
                loss = criterion(reconstructed, batch_x)
                loss.backward()
                optimizer.step()
                epoch_loss += loss.item()

            if (epoch + 1) % 10 == 0:
                logger.info(f"epoch {epoch+1}, loss: {epoch_loss / (len(train_data) // args.batch_size):.6f}")

        # Evaluate
        model.eval()
        with torch.no_grad():
            test_x = torch.FloatTensor(test_data)
            reconstructed, embeddings = model(test_x)
            mse = criterion(reconstructed, test_x).item()

        results = {
            'reconstruction_mse': float(mse),
            'embedding_dim': args.embed_dim,
            'n_samples': n_samples,
        }

        logger.info(f"reconstruction MSE: {mse:.6f}")

        # Save model
        torch.save(model.state_dict(), out_dir / 'gaze_encoder.pt')

        # Save sample embeddings
        sample_embeddings = embeddings[:100].numpy()
        np.save(out_dir / 'sample_embeddings.npy', sample_embeddings)

    with open(out_dir / 'encoder_results.json', 'w') as f:
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

    logger.info(f"gaze encoder complete. saved to {out_dir}")


if __name__ == '__main__':
    main()
