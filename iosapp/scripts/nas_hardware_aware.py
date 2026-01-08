#!/usr/bin/env python3
"""
nas_hardware_aware.py — Hardware-aware neural architecture search.
"""

import argparse
import logging
import json
import random
from pathlib import Path
from typing import Dict, List, Tuple

import numpy as np
import torch
import torch.nn as nn

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output_dir', type=str, required=True)
    parser.add_argument('--num_candidates', type=int, default=2000)
    parser.add_argument('--latency_constraint', type=float, default=10.0)
    parser.add_argument('--memory_constraint', type=float, default=50.0)
    parser.add_argument('--energy_constraint', type=float, default=5.0)
    parser.add_argument('--num_generations', type=int, default=50)
    parser.add_argument('--population_size', type=int, default=100)
    return parser.parse_args()


class SubNetwork(nn.Module):
    """Configurable sub-network."""

    def __init__(self, config: Dict):
        super().__init__()
        self.config = config

        layers = []
        in_dim = 768

        for i in range(config['depth']):
            out_dim = config['widths'][i] if i < len(config['widths']) else config['widths'][-1]
            layers.append(nn.Linear(in_dim, out_dim))
            layers.append(nn.ReLU())
            in_dim = out_dim

        layers.append(nn.Linear(in_dim, 7))
        self.network = nn.Sequential(*layers)

    def forward(self, x):
        if x.dim() == 3:
            x = x.mean(1)
        return self.network(x)


def sample_architecture() -> Dict:
    """Sample random architecture configuration."""
    depth = random.randint(2, 8)
    widths = [random.choice([64, 128, 192, 256, 320, 384]) for _ in range(depth)]
    return {
        'depth': depth,
        'widths': widths,
        'heads': random.choice([2, 4, 8]),
        'use_attention': random.random() > 0.5,
    }


def estimate_latency(config: Dict) -> float:
    """Estimate inference latency (ms)."""
    flops = sum(config['widths']) * 768 * 2 / 1e6
    return flops * 0.1


def estimate_memory(config: Dict) -> float:
    """Estimate memory usage (MB)."""
    params = sum(w * 768 + w for w in config['widths']) + config['widths'][-1] * 7
    return params * 4 / 1e6


def estimate_energy(config: Dict) -> float:
    """Estimate energy consumption (mJ)."""
    return estimate_latency(config) * 0.5


def evaluate_candidate(config: Dict, constraints: Dict) -> Tuple[float, bool]:
    """Evaluate architecture candidate."""
    latency = estimate_latency(config)
    memory = estimate_memory(config)
    energy = estimate_energy(config)

    # check constraints
    valid = (
        latency <= constraints['latency'] and
        memory <= constraints['memory'] and
        energy <= constraints['energy']
    )

    if not valid:
        return -1, False

    # mock accuracy evaluation
    model = SubNetwork(config)
    model.eval()

    with torch.no_grad():
        x = torch.randn(100, 256, 768)
        y = torch.randint(0, 7, (100,))
        logits = model(x)
        accuracy = (logits.argmax(1) == y).float().mean().item()

    # composite score (higher is better)
    score = accuracy - 0.01 * latency - 0.001 * memory - 0.01 * energy

    return score, True


def evolutionary_search(args) -> List[Dict]:
    """Evolutionary architecture search."""
    constraints = {
        'latency': args.latency_constraint,
        'memory': args.memory_constraint,
        'energy': args.energy_constraint,
    }

    # initialize population
    population = []
    for _ in range(args.population_size):
        config = sample_architecture()
        score, valid = evaluate_candidate(config, constraints)
        if valid:
            population.append((score, config))

    logger.info(f"initial population: {len(population)}")

    # evolution
    for gen in range(args.num_generations):
        # sort by score
        population.sort(key=lambda x: x[0], reverse=True)

        # select top half
        survivors = population[:len(population) // 2]

        # generate offspring
        offspring = []
        while len(offspring) < args.population_size - len(survivors):
            # crossover
            p1 = random.choice(survivors)[1]
            p2 = random.choice(survivors)[1]

            child = {
                'depth': random.choice([p1['depth'], p2['depth']]),
                'widths': [],
                'heads': random.choice([p1['heads'], p2['heads']]),
                'use_attention': random.choice([p1['use_attention'], p2['use_attention']]),
            }

            for i in range(child['depth']):
                if i < len(p1['widths']) and i < len(p2['widths']):
                    child['widths'].append(random.choice([p1['widths'][i], p2['widths'][i]]))
                else:
                    child['widths'].append(random.choice([128, 256]))

            # mutation
            if random.random() < 0.3:
                idx = random.randint(0, len(child['widths']) - 1)
                child['widths'][idx] = random.choice([64, 128, 192, 256, 320, 384])

            score, valid = evaluate_candidate(child, constraints)
            if valid:
                offspring.append((score, child))

        population = survivors + offspring

        if gen % 10 == 0:
            best_score = population[0][0]
            logger.info(f"generation {gen} | best score: {best_score:.4f}")

    # return pareto front (top candidates)
    population.sort(key=lambda x: x[0], reverse=True)
    return [p[1] for p in population[:5]]


def main():
    args = parse_args()
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    logger.info("starting NAS...")
    best_configs = evolutionary_search(args)

    # save and export models
    manifest = []
    for i, config in enumerate(best_configs):
        model = SubNetwork(config)

        # save PyTorch
        model_path = output_dir / f'nas_model_{i}.pt'
        torch.save(model.state_dict(), model_path)

        # export ONNX
        onnx_path = output_dir / f'nas_model_{i}.onnx'
        dummy = torch.randn(1, 256, 768)
        torch.onnx.export(model, dummy, onnx_path, input_names=['input'], output_names=['output'])

        manifest.append({
            'rank': i,
            'config': config,
            'latency_ms': estimate_latency(config),
            'memory_mb': estimate_memory(config),
            'energy_mj': estimate_energy(config),
            'model_path': str(model_path),
            'onnx_path': str(onnx_path),
        })

    # save manifest
    with open(output_dir / 'nas_manifest.json', 'w') as f:
        json.dump(manifest, f, indent=2)

    import pandas as pd
    pd.DataFrame(manifest).to_csv(output_dir / 'nas_results.csv', index=False)

    logger.info(f"saved {len(best_configs)} models to {output_dir}")


if __name__ == '__main__':
    main()
