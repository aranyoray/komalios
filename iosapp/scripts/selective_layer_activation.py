#!/usr/bin/env python3
"""
selective_layer_activation.py - Activate subset of model layers based on input difficulty

Reduces compute cost by only running necessary layers for simple inputs.
"""

import argparse
import json
import numpy as np
import logging
from typing import Dict, List, Optional
from datetime import datetime

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class InputComplexityEstimator:
    """Estimate input complexity to determine needed layers."""

    def estimate(self, x: np.ndarray) -> Dict:
        """Estimate complexity of input."""
        # Features for complexity estimation
        variance = float(np.var(x))
        entropy = float(-np.sum(np.abs(x) * np.log(np.abs(x) + 1e-10)) / x.size)
        edge_density = float(np.mean(np.abs(np.diff(x.flatten()))))

        # Combine into score (0-1)
        score = min(1.0, (variance * 0.3 + entropy * 0.1 + edge_density * 0.6))

        if score < 0.3:
            level = 'simple'
        elif score < 0.6:
            level = 'medium'
        else:
            level = 'complex'

        return {
            'score': score,
            'level': level,
            'variance': variance,
            'entropy': entropy,
            'edge_density': edge_density
        }


class SelectiveLayerActivation:
    """Activate only needed layers based on input difficulty."""

    def __init__(self, config: Dict):
        self.config = config
        self.estimator = InputComplexityEstimator()

        # Layer groups by complexity
        self.layer_groups = {
            'simple': ['conv1', 'fc_out'],
            'medium': ['conv1', 'conv2', 'fc1', 'fc_out'],
            'complex': ['conv1', 'conv2', 'conv3', 'conv4', 'fc1', 'fc2', 'fc_out']
        }

        # Stats
        self.stats = {'simple': 0, 'medium': 0, 'complex': 0}
        self.compute_saved = 0

    def get_active_layers(self, x: np.ndarray) -> List[str]:
        """Get list of layers to activate for input."""
        complexity = self.estimator.estimate(x)
        active = self.layer_groups[complexity['level']]

        self.stats[complexity['level']] += 1

        # Estimate compute savings
        all_layers = len(self.layer_groups['complex'])
        active_layers = len(active)
        self.compute_saved += (1 - active_layers / all_layers)

        return active

    def forward(self, x: np.ndarray, layers: Dict[str, np.ndarray]) -> np.ndarray:
        """Forward pass with selective activation."""
        active = self.get_active_layers(x)

        result = x
        for layer_name in active:
            if layer_name in layers:
                # Simplified forward
                w = layers[layer_name]
                if len(w.shape) == 4:  # Conv
                    result = np.mean(result) * np.mean(w) + result
                else:  # FC
                    result = result.flatten()[:w.shape[0]] @ w if result.size >= w.shape[0] else result

        return result

    def get_stats(self) -> Dict:
        """Get activation statistics."""
        total = sum(self.stats.values())
        return {
            'distribution': self.stats,
            'total_inferences': total,
            'avg_compute_saved': self.compute_saved / total if total > 0 else 0
        }


def main():
    parser = argparse.ArgumentParser(description='Selective layer activation')
    parser.add_argument('--demo', action='store_true', help='Run demo')
    parser.add_argument('--iterations', type=int, default=100, help='Demo iterations')

    args = parser.parse_args()

    if args.demo:
        activator = SelectiveLayerActivation({})

        # Create fake layers
        layers = {
            'conv1': np.random.randn(32, 3, 3, 3).astype(np.float32),
            'conv2': np.random.randn(64, 32, 3, 3).astype(np.float32),
            'conv3': np.random.randn(128, 64, 3, 3).astype(np.float32),
            'conv4': np.random.randn(256, 128, 3, 3).astype(np.float32),
            'fc1': np.random.randn(256, 128).astype(np.float32),
            'fc2': np.random.randn(128, 64).astype(np.float32),
            'fc_out': np.random.randn(64, 7).astype(np.float32)
        }

        for i in range(args.iterations):
            # Generate inputs of varying complexity
            if i % 3 == 0:
                x = np.ones((64, 64)) * 0.5  # Simple
            elif i % 3 == 1:
                x = np.random.randn(64, 64) * 0.5  # Medium
            else:
                x = np.random.randn(64, 64) * 2  # Complex

            result = activator.forward(x, layers)

        stats = activator.get_stats()
        logger.info(f"\n=== Selective Activation Stats ===")
        logger.info(f"Simple: {stats['distribution']['simple']}")
        logger.info(f"Medium: {stats['distribution']['medium']}")
        logger.info(f"Complex: {stats['distribution']['complex']}")
        logger.info(f"Avg compute saved: {stats['avg_compute_saved']*100:.1f}%")


if __name__ == '__main__':
    main()
