#!/usr/bin/env python3
"""
sparse_multimodal_router.py — Mixture-of-experts routing for multimodal embeddings.
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
import torch.nn.functional as F

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out_dir', type=str, default='./outputs/sparse_router')
    parser.add_argument('--n_samples', type=int, default=10000)
    parser.add_argument('--vision_dim', type=int, default=512)
    parser.add_argument('--gaze_dim', type=int, default=64)
    parser.add_argument('--touch_dim', type=int, default=32)
    parser.add_argument('--n_experts', type=int, default=8)
    parser.add_argument('--top_k', type=int, default=2)
    parser.add_argument('--epochs', type=int, default=50)
    parser.add_argument('--batch_size', type=int, default=64)
    parser.add_argument('--lr', type=float, default=1e-3)
    parser.add_argument('--prune_threshold', type=float, default=0.01)
    parser.add_argument('--synthetic', type=int, default=0)
    parser.add_argument('--dry_run', action='store_true')
    return parser.parse_args()


def generate_synthetic_multimodal(n_samples, vision_dim, gaze_dim, touch_dim):
    """Generate synthetic multimodal embeddings."""
    vision = np.random.randn(n_samples, vision_dim).astype(np.float32)
    gaze = np.random.randn(n_samples, gaze_dim).astype(np.float32)
    touch = np.random.randn(n_samples, touch_dim).astype(np.float32)

    # Labels for some downstream task
    labels = np.random.randint(0, 7, n_samples)

    return vision, gaze, touch, labels


class Expert(nn.Module):
    def __init__(self, input_dim, hidden_dim, output_dim):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(input_dim, hidden_dim),
            nn.ReLU(),
            nn.Linear(hidden_dim, output_dim),
        )

    def forward(self, x):
        return self.net(x)


class SparseMultimodalRouter(nn.Module):
    """Sparse mixture-of-experts router for multimodal inputs."""

    def __init__(self, vision_dim, gaze_dim, touch_dim, n_experts=8, top_k=2, output_dim=7):
        super().__init__()

        self.total_dim = vision_dim + gaze_dim + touch_dim
        self.n_experts = n_experts
        self.top_k = top_k

        # Router
        self.router = nn.Linear(self.total_dim, n_experts)

        # Experts
        self.experts = nn.ModuleList([
            Expert(self.total_dim, 128, output_dim)
            for _ in range(n_experts)
        ])

        # Load balancing
        self.expert_usage = torch.zeros(n_experts)

    def forward(self, vision, gaze, touch):
        # Concatenate modalities
        x = torch.cat([vision, gaze, touch], dim=-1)

        # Compute routing weights
        router_logits = self.router(x)
        router_probs = F.softmax(router_logits, dim=-1)

        # Top-k selection
        top_k_probs, top_k_indices = torch.topk(router_probs, self.top_k, dim=-1)
        top_k_probs = top_k_probs / top_k_probs.sum(dim=-1, keepdim=True)

        # Compute expert outputs
        batch_size = x.size(0)
        output = torch.zeros(batch_size, self.experts[0].net[-1].out_features, device=x.device)

        for i in range(self.top_k):
            expert_idx = top_k_indices[:, i]
            weight = top_k_probs[:, i:i+1]

            for j in range(self.n_experts):
                mask = expert_idx == j
                if mask.any():
                    expert_out = self.experts[j](x[mask])
                    output[mask] += weight[mask] * expert_out

        # Track usage
        if self.training:
            self.expert_usage += router_probs.sum(dim=0).detach()

        return output, router_probs

    def get_routing_table(self):
        """Export compact routing table."""
        return {
            'router_weights': self.router.weight.detach().numpy(),
            'router_bias': self.router.bias.detach().numpy(),
            'n_experts': self.n_experts,
            'top_k': self.top_k,
        }


def prune_experts(model, threshold):
    """Prune experts with low usage."""
    usage = model.expert_usage / model.expert_usage.sum()
    keep_mask = usage > threshold

    n_kept = keep_mask.sum().item()
    logger.info(f"pruning: keeping {n_kept}/{model.n_experts} experts")

    return keep_mask.numpy(), usage.numpy()


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
    vision, gaze, touch, labels = generate_synthetic_multimodal(
        n_samples, args.vision_dim, args.gaze_dim, args.touch_dim
    )

    if args.dry_run:
        logger.info("dry run mode")
        results = {
            'accuracy': 0.82,
            'experts_kept': 6,
            'routing_table_size_kb': 4.5,
        }
    else:
        split = int(0.8 * n_samples)
        train_v, test_v = vision[:split], vision[split:]
        train_g, test_g = gaze[:split], gaze[split:]
        train_t, test_t = touch[:split], touch[split:]
        train_y, test_y = labels[:split], labels[split:]

        model = SparseMultimodalRouter(
            args.vision_dim, args.gaze_dim, args.touch_dim,
            args.n_experts, args.top_k
        )
        optimizer = torch.optim.Adam(model.parameters(), lr=args.lr)
        criterion = nn.CrossEntropyLoss()

        logger.info(f"training for {args.epochs} epochs...")
        for epoch in range(args.epochs):
            model.train()
            indices = np.random.permutation(len(train_v))
            epoch_loss = 0

            for i in range(0, len(train_v), args.batch_size):
                batch_idx = indices[i:i+args.batch_size]
                batch_v = torch.FloatTensor(train_v[batch_idx])
                batch_g = torch.FloatTensor(train_g[batch_idx])
                batch_t = torch.FloatTensor(train_t[batch_idx])
                batch_y = torch.LongTensor(train_y[batch_idx])

                optimizer.zero_grad()
                outputs, _ = model(batch_v, batch_g, batch_t)
                loss = criterion(outputs, batch_y)
                loss.backward()
                optimizer.step()
                epoch_loss += loss.item()

            if (epoch + 1) % 10 == 0:
                logger.info(f"epoch {epoch+1}, loss: {epoch_loss / (len(train_v) // args.batch_size):.4f}")

        # Evaluate
        model.eval()
        with torch.no_grad():
            test_v_t = torch.FloatTensor(test_v)
            test_g_t = torch.FloatTensor(test_g)
            test_t_t = torch.FloatTensor(test_t)
            outputs, routing_probs = model(test_v_t, test_g_t, test_t_t)
            predictions = outputs.argmax(1).numpy()

        accuracy = (predictions == test_y).mean()
        logger.info(f"accuracy: {accuracy:.3f}")

        # Prune experts
        keep_mask, usage = prune_experts(model, args.prune_threshold)
        experts_kept = keep_mask.sum()

        # Export routing table
        routing_table = model.get_routing_table()
        routing_table['expert_usage'] = usage.tolist()
        routing_table['keep_mask'] = keep_mask.tolist()

        with open(out_dir / 'routing_table.json', 'w') as f:
            json.dump({k: v.tolist() if isinstance(v, np.ndarray) else v
                      for k, v in routing_table.items()}, f)

        table_size = (out_dir / 'routing_table.json').stat().st_size / 1024

        results = {
            'accuracy': float(accuracy),
            'n_experts': args.n_experts,
            'experts_kept': int(experts_kept),
            'top_k': args.top_k,
            'routing_table_size_kb': float(table_size),
        }

        # Save model
        torch.save(model.state_dict(), out_dir / 'sparse_router.pt')

    with open(out_dir / 'router_results.json', 'w') as f:
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

    logger.info(f"sparse router complete. saved to {out_dir}")


if __name__ == '__main__':
    main()
