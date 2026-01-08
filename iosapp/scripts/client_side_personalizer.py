#!/usr/bin/env python3
"""
client_side_personalizer.py — LoRA/Adapter fine-tuning on quantized student model.

Requirements:
torch>=2.0.0, numpy, pandas, pyRAPL, mlflow, tqdm, argparse
"""

import os
import sys
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
import torch.nn.functional as F
from torch.utils.data import DataLoader, TensorDataset
from tqdm import tqdm

try:
    import pyRAPL
    HAS_PYRAPL = True
except ImportError:
    HAS_PYRAPL = False

try:
    import mlflow
    HAS_MLFLOW = True
except ImportError:
    HAS_MLFLOW = False

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description='Client-side LoRA personalizer')
    parser.add_argument('--data_dir', type=str, default='./data')
    parser.add_argument('--out_dir', type=str, default='./outputs/personalizer')
    parser.add_argument('--device', type=str, default='cuda' if torch.cuda.is_available() else 'cpu')
    parser.add_argument('--batch_size', type=int, default=16)
    parser.add_argument('--max_steps', type=int, default=100)
    parser.add_argument('--lr', type=float, default=1e-3)
    parser.add_argument('--lora_rank', type=int, default=4)
    parser.add_argument('--synthetic', type=int, default=0, help='Generate N synthetic samples')
    parser.add_argument('--dry_run', action='store_true')
    parser.add_argument('--debug', action='store_true')
    parser.add_argument('--n_workers', type=int, default=2)
    return parser.parse_args()


class LoRALayer(nn.Module):
    """Low-Rank Adaptation layer."""
    def __init__(self, in_features, out_features, rank=4):
        super().__init__()
        self.lora_A = nn.Parameter(torch.randn(in_features, rank) * 0.01)
        self.lora_B = nn.Parameter(torch.zeros(rank, out_features))
        self.scaling = 0.1

    def forward(self, x):
        return (x @ self.lora_A @ self.lora_B) * self.scaling


class StudentWithLoRA(nn.Module):
    """Quantized student model with LoRA adapters."""
    def __init__(self, input_dim=768, hidden_dim=256, output_dim=7, lora_rank=4):
        super().__init__()
        self.fc1 = nn.Linear(input_dim, hidden_dim)
        self.fc2 = nn.Linear(hidden_dim, hidden_dim)
        self.fc3 = nn.Linear(hidden_dim, output_dim)

        # LoRA adapters
        self.lora1 = LoRALayer(input_dim, hidden_dim, lora_rank)
        self.lora2 = LoRALayer(hidden_dim, hidden_dim, lora_rank)

        # Freeze base weights
        for param in [self.fc1.weight, self.fc1.bias, self.fc2.weight, self.fc2.bias]:
            param.requires_grad = False

    def forward(self, x):
        h = F.relu(self.fc1(x) + self.lora1(x))
        h = F.relu(self.fc2(h) + self.lora2(h))
        return self.fc3(h)

    def get_lora_params(self):
        return {
            'lora1_A': self.lora1.lora_A.detach().cpu().numpy(),
            'lora1_B': self.lora1.lora_B.detach().cpu().numpy(),
            'lora2_A': self.lora2.lora_A.detach().cpu().numpy(),
            'lora2_B': self.lora2.lora_B.detach().cpu().numpy(),
        }


def generate_synthetic_data(n_samples):
    """Generate synthetic personalization data."""
    X = torch.randn(n_samples, 768)
    y = torch.randint(0, 7, (n_samples,))
    return X, y


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

    # Initialize energy measurement
    if HAS_PYRAPL:
        pyRAPL.setup()
        meter = pyRAPL.Measurement('training')
    else:
        meter = None

    # MLflow
    if HAS_MLFLOW:
        mlflow.start_run(run_name='client_personalizer')
        mlflow.log_params(vars(args))

    # Load or generate data
    if args.synthetic > 0:
        logger.info(f"generating {args.synthetic} synthetic samples")
        X, y = generate_synthetic_data(args.synthetic)
    else:
        data_path = Path(args.data_dir) / 'personalization_data.pt'
        if data_path.exists():
            data = torch.load(data_path)
            X, y = data['X'], data['y']
        else:
            logger.warning("no data found, generating 100 synthetic samples")
            X, y = generate_synthetic_data(100)

    dataset = TensorDataset(X, y)
    loader = DataLoader(dataset, batch_size=args.batch_size, shuffle=True, num_workers=args.n_workers)

    # Create model
    model = StudentWithLoRA(lora_rank=args.lora_rank).to(device)
    optimizer = torch.optim.AdamW(
        [p for p in model.parameters() if p.requires_grad],
        lr=args.lr
    )

    # Training loop
    energy_per_step = []
    losses = []

    logger.info(f"starting personalization for {args.max_steps} steps")

    step = 0
    for epoch in range(100):
        for batch_x, batch_y in loader:
            if step >= args.max_steps:
                break

            batch_x = batch_x.to(device)
            batch_y = batch_y.to(device)

            if meter:
                meter.begin()

            if args.dry_run:
                loss = torch.tensor(1.0 / (step + 1))
            else:
                logits = model(batch_x)
                loss = F.cross_entropy(logits, batch_y)

                optimizer.zero_grad()
                loss.backward()
                optimizer.step()

            if meter:
                meter.end()
                energy = meter.result.pkg[0] if meter.result.pkg else 0
                energy_per_step.append(energy)

            losses.append(loss.item())
            step += 1

            if step % 10 == 0:
                logger.info(f"step {step}/{args.max_steps} | loss: {loss.item():.4f}")

        if step >= args.max_steps:
            break

    # Save LoRA adapters
    lora_params = model.get_lora_params()
    adapter_path = out_dir / 'lora_adapters.npz'
    np.savez_compressed(adapter_path, **lora_params)
    logger.info(f"saved LoRA adapters to {adapter_path}")

    # Save metrics
    metrics = {
        'final_loss': losses[-1] if losses else 0,
        'total_steps': step,
        'mean_energy_per_step': np.mean(energy_per_step) if energy_per_step else 0,
        'total_energy': sum(energy_per_step) if energy_per_step else 0,
    }

    metrics_path = out_dir / 'metrics.json'
    with open(metrics_path, 'w') as f:
        json.dump(metrics, f, indent=2)

    # Create manifest
    artifacts = []
    for path in [adapter_path, metrics_path]:
        if path.exists():
            artifacts.append({
                'path': str(path),
                'sha256': compute_sha256(path),
                'size': path.stat().st_size,
                'created_at': datetime.now().isoformat(),
            })

    manifest_path = out_dir / 'artifacts_manifest.csv'
    pd.DataFrame(artifacts).to_csv(manifest_path, index=False)

    if HAS_MLFLOW:
        mlflow.log_metrics(metrics)
        mlflow.log_artifact(str(adapter_path))
        mlflow.end_run()

    logger.info(f"personalization complete. artifacts saved to {out_dir}")


if __name__ == '__main__':
    main()
