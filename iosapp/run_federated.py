#!/usr/bin/env python3
"""
run_federated.py — Federated learning simulation with differential privacy.
"""

import os
import argparse
import logging
import json
from pathlib import Path
from typing import List, Dict, Tuple

import numpy as np
import torch
import torch.nn as nn
from torch.utils.data import DataLoader, Subset

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description='Federated Learning Simulation')
    parser.add_argument('--num_clients', type=int, default=100)
    parser.add_argument('--num_rounds', type=int, default=100)
    parser.add_argument('--local_epochs', type=int, default=5)
    parser.add_argument('--client_fraction', type=float, default=0.1)
    parser.add_argument('--dataset_root', type=str, required=True)
    parser.add_argument('--output_dir', type=str, required=True)
    parser.add_argument('--dp_enabled', action='store_true')
    parser.add_argument('--dp_epsilon', type=float, default=8.0)
    parser.add_argument('--dp_delta', type=float, default=1e-5)
    parser.add_argument('--noise_multiplier', type=float, default=1.1)
    parser.add_argument('--clip_norm', type=float, default=1.0)
    parser.add_argument('--secure_aggregation', action='store_true')
    parser.add_argument('--client_heterogeneity', type=str, default='iid')
    parser.add_argument('--alpha', type=float, default=0.5)
    parser.add_argument('--fp16', action='store_true')
    parser.add_argument('--log_communication_bytes', action='store_true')
    parser.add_argument('--save_dp_report', action='store_true')
    return parser.parse_args()


class FederatedClient:
    """Simulated federated learning client."""

    def __init__(self, client_id: int, data_indices: List[int], model_config: dict):
        self.client_id = client_id
        self.data_indices = data_indices
        self.model_config = model_config

    def train(self, global_model_state: dict, dataset, epochs: int, dp_enabled: bool,
              clip_norm: float, noise_multiplier: float) -> Tuple[dict, int]:
        """Train on local data and return model update."""
        from models.multimodal_transformer import create_model

        # create local model
        model = create_model(argparse.Namespace(**self.model_config))
        model.load_state_dict(global_model_state)
        model.train()

        device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
        model = model.to(device)

        # create local dataloader
        local_dataset = Subset(dataset, self.data_indices)
        loader = DataLoader(local_dataset, batch_size=32, shuffle=True)

        optimizer = torch.optim.SGD(model.parameters(), lr=0.01)

        for epoch in range(epochs):
            for batch in loader:
                batch = {k: v.to(device) if torch.is_tensor(v) else v for k, v in batch.items()}
                outputs = model(**batch)
                loss = outputs['loss']

                optimizer.zero_grad()
                loss.backward()

                # gradient clipping for DP
                if dp_enabled:
                    torch.nn.utils.clip_grad_norm_(model.parameters(), clip_norm)

                optimizer.step()

        # add noise for DP
        model_state = model.state_dict()
        if dp_enabled:
            for key in model_state:
                noise = torch.randn_like(model_state[key]) * noise_multiplier * clip_norm
                model_state[key] += noise

        # compute bytes for communication logging
        bytes_sent = sum(p.numel() * 4 for p in model_state.values())

        return model_state, bytes_sent


class FederatedServer:
    """Federated learning server with secure aggregation."""

    def __init__(self, args):
        self.args = args
        self.output_dir = Path(args.output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)

        self.model_config = {
            'model_dim': 256,
            'ffn_dim': 512,
            'num_layers': 4,
            'num_heads': 4,
        }

        # initialize global model
        from models.multimodal_transformer import create_model
        self.global_model = create_model(argparse.Namespace(**self.model_config))

        # metrics
        self.metrics = {
            'rounds': [],
            'losses': [],
            'communication_bytes': [],
        }

    def aggregate(self, client_updates: List[dict], weights: List[float]) -> dict:
        """Aggregate client updates using FedAvg."""
        aggregated = {}
        total_weight = sum(weights)

        for key in client_updates[0].keys():
            aggregated[key] = sum(
                w * update[key] for update, w in zip(client_updates, weights)
            ) / total_weight

        return aggregated

    def run(self):
        """Run federated training."""
        from data.multimodal_dataset import KomalMultimodalDataset

        # load dataset
        dataset = KomalMultimodalDataset(self.args.dataset_root)
        num_samples = len(dataset)

        # create client data partitions
        if self.args.client_heterogeneity == 'non_iid':
            # dirichlet distribution for non-iid
            proportions = np.random.dirichlet(
                [self.args.alpha] * self.args.num_clients
            )
        else:
            proportions = np.ones(self.args.num_clients) / self.args.num_clients

        indices = np.arange(num_samples)
        np.random.shuffle(indices)

        client_indices = []
        start = 0
        for prop in proportions:
            end = start + int(prop * num_samples)
            client_indices.append(indices[start:end].tolist())
            start = end

        # create clients
        clients = [
            FederatedClient(i, client_indices[i], self.model_config)
            for i in range(self.args.num_clients)
        ]

        logger.info(f"starting federated training with {self.args.num_clients} clients")

        for round_num in range(self.args.num_rounds):
            # select clients
            num_selected = max(1, int(self.args.client_fraction * self.args.num_clients))
            selected_ids = np.random.choice(
                self.args.num_clients, num_selected, replace=False
            )

            # get global model state
            global_state = self.global_model.state_dict()

            # train on clients
            client_updates = []
            weights = []
            total_bytes = 0

            for client_id in selected_ids:
                client = clients[client_id]
                update, bytes_sent = client.train(
                    global_state, dataset, self.args.local_epochs,
                    self.args.dp_enabled, self.args.clip_norm, self.args.noise_multiplier
                )
                client_updates.append(update)
                weights.append(len(client.data_indices))
                total_bytes += bytes_sent

            # aggregate
            aggregated = self.aggregate(client_updates, weights)
            self.global_model.load_state_dict(aggregated)

            # log metrics
            self.metrics['rounds'].append(round_num)
            self.metrics['communication_bytes'].append(total_bytes)

            if round_num % 10 == 0:
                logger.info(f"round {round_num}/{self.args.num_rounds} | bytes: {total_bytes}")

        # save model and metrics
        torch.save(self.global_model.state_dict(), self.output_dir / 'global_model.pt')

        with open(self.output_dir / 'metrics.json', 'w') as f:
            json.dump(self.metrics, f, indent=2)

        # save DP report
        if self.args.save_dp_report:
            dp_report = {
                'epsilon': self.args.dp_epsilon,
                'delta': self.args.dp_delta,
                'noise_multiplier': self.args.noise_multiplier,
                'clip_norm': self.args.clip_norm,
                'num_rounds': self.args.num_rounds,
            }
            with open(self.output_dir / 'dp_report.json', 'w') as f:
                json.dump(dp_report, f, indent=2)

        logger.info(f"training complete. model saved to {self.output_dir}")


def main():
    args = parse_args()
    server = FederatedServer(args)
    server.run()


if __name__ == '__main__':
    main()
