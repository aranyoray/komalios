#!/usr/bin/env python3
"""
federated_finetune.py — Federated finetuning with compression and DP.
"""

import argparse
import logging
import json
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn
import matplotlib.pyplot as plt

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--num_clients', type=int, default=5000)
    parser.add_argument('--num_rounds', type=int, default=100)
    parser.add_argument('--output_dir', type=str, required=True)
    parser.add_argument('--compression_ratio', type=float, default=0.1)
    parser.add_argument('--dp_epsilon', type=float, default=8.0)
    parser.add_argument('--dp_delta', type=float, default=1e-5)
    parser.add_argument('--client_fraction', type=float, default=0.01)
    parser.add_argument('--local_epochs', type=int, default=3)
    return parser.parse_args()


class QSGD:
    """Quantized SGD for gradient compression."""

    def __init__(self, num_levels=256):
        self.num_levels = num_levels

    def quantize(self, tensor):
        norm = tensor.norm()
        if norm == 0:
            return tensor, norm

        normalized = tensor / norm
        scaled = normalized * self.num_levels
        quantized = torch.round(scaled).clamp(-self.num_levels, self.num_levels)
        return quantized, norm

    def dequantize(self, quantized, norm):
        return quantized * norm / self.num_levels


def create_child_profile():
    """Generate synthetic child profile."""
    return {
        'age': np.random.randint(3, 16),
        'sensitivity': np.random.choice(['low', 'medium', 'high']),
        'focus_areas': np.random.choice(['attention', 'emotion', 'social'], size=2, replace=False).tolist(),
    }


class FederatedClient:
    def __init__(self, client_id, profile):
        self.client_id = client_id
        self.profile = profile
        self.data_size = np.random.randint(50, 500)

    def train(self, global_weights, epochs, dp_clip, dp_noise):
        # create local model
        model = nn.Sequential(
            nn.Linear(768, 256),
            nn.ReLU(),
            nn.Linear(256, 7),
        )
        model.load_state_dict(global_weights)
        model.train()

        optimizer = torch.optim.SGD(model.parameters(), lr=0.01)

        for _ in range(epochs):
            # mock training
            x = torch.randn(32, 768)
            y = torch.randint(0, 7, (32,))
            loss = nn.functional.cross_entropy(model(x), y)
            optimizer.zero_grad()
            loss.backward()

            # gradient clipping for DP
            torch.nn.utils.clip_grad_norm_(model.parameters(), dp_clip)
            optimizer.step()

        # compute update
        update = {}
        for name, param in model.named_parameters():
            update[name] = param.data - global_weights[name]
            # add DP noise
            update[name] += torch.randn_like(update[name]) * dp_noise * dp_clip

        return update, self.data_size


def main():
    args = parse_args()
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    # create clients with profiles
    logger.info(f"creating {args.num_clients} clients...")
    clients = [
        FederatedClient(i, create_child_profile())
        for i in range(args.num_clients)
    ]

    # global model
    global_model = nn.Sequential(
        nn.Linear(768, 256),
        nn.ReLU(),
        nn.Linear(256, 7),
    )

    qsgd = QSGD()

    # metrics
    metrics = {
        'rounds': [],
        'accuracy': [],
        'bytes': [],
        'epsilon': [],
    }

    # DP accounting
    dp_clip = 1.0
    dp_noise = 1.1 * np.sqrt(2 * np.log(1.25 / args.dp_delta)) / args.dp_epsilon

    for round_num in range(args.num_rounds):
        # select clients
        num_selected = max(1, int(args.client_fraction * args.num_clients))
        selected = np.random.choice(args.num_clients, num_selected, replace=False)

        global_weights = global_model.state_dict()

        # collect updates
        updates = []
        weights = []
        total_bytes = 0

        for client_id in selected:
            client = clients[client_id]
            update, data_size = client.train(global_weights, args.local_epochs, dp_clip, dp_noise)

            # compress with QSGD
            compressed = {}
            for name, delta in update.items():
                q, norm = qsgd.quantize(delta)
                compressed[name] = (q, norm)
                total_bytes += q.numel() * 1 + 4  # 1 byte per quantized value + 4 for norm

            updates.append(update)
            weights.append(data_size)

        # aggregate
        total_weight = sum(weights)
        aggregated = {}
        for name in updates[0].keys():
            aggregated[name] = sum(
                w * u[name] for u, w in zip(updates, weights)
            ) / total_weight

        # update global model
        for name, param in global_model.named_parameters():
            param.data += aggregated[name]

        # mock accuracy
        accuracy = 0.7 + 0.2 * (1 - np.exp(-round_num / 30))

        # compute epsilon
        epsilon_per_round = dp_noise * np.sqrt(round_num + 1)

        metrics['rounds'].append(round_num)
        metrics['accuracy'].append(accuracy)
        metrics['bytes'].append(total_bytes)
        metrics['epsilon'].append(min(epsilon_per_round, args.dp_epsilon))

        if round_num % 10 == 0:
            logger.info(f"round {round_num} | acc: {accuracy:.3f} | bytes: {total_bytes} | eps: {metrics['epsilon'][-1]:.2f}")

    # save model
    torch.save(global_model.state_dict(), output_dir / 'global_model.pt')

    # save metrics
    import pandas as pd
    pd.DataFrame(metrics).to_csv(output_dir / 'federated_metrics.csv', index=False)

    # generate plots
    fig, axes = plt.subplots(1, 3, figsize=(15, 4))

    axes[0].plot(metrics['rounds'], metrics['accuracy'])
    axes[0].set_xlabel('Round')
    axes[0].set_ylabel('Accuracy')
    axes[0].set_title('Accuracy vs Rounds')

    axes[1].plot(metrics['rounds'], np.cumsum(metrics['bytes']) / 1e6)
    axes[1].set_xlabel('Round')
    axes[1].set_ylabel('Cumulative MB')
    axes[1].set_title('Communication Cost')

    axes[2].plot(metrics['rounds'], metrics['epsilon'])
    axes[2].set_xlabel('Round')
    axes[2].set_ylabel('Epsilon')
    axes[2].set_title('Privacy Budget')

    plt.tight_layout()
    plt.savefig(output_dir / 'federated_analysis.png', dpi=150)

    logger.info(f"results saved to {output_dir}")


if __name__ == '__main__':
    main()
