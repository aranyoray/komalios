#!/usr/bin/env python3
"""
cross_model_router.py - Route inputs to appropriate model size

Selects between tiny, small, medium models based on device capability,
predicted difficulty, and battery constraints.
"""

import argparse
import json
import numpy as np
import time
import logging
from typing import Dict, List, Optional

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class DeviceCapability:
    """Assess device capabilities."""

    def __init__(self):
        self.capabilities = self._detect()

    def _detect(self) -> Dict:
        """Detect device capabilities."""
        import os

        # Simplified detection
        cpu_count = os.cpu_count() or 2

        # Estimate RAM (would use psutil in production)
        ram_gb = 4  # Default assumption

        # Estimate GPU
        has_gpu = False

        return {
            'cpu_cores': cpu_count,
            'ram_gb': ram_gb,
            'has_gpu': has_gpu,
            'tier': 'high' if cpu_count >= 4 and ram_gb >= 4 else 'low'
        }


class CrossModelRouter:
    """Route inputs to appropriate model based on constraints."""

    def __init__(self, config: Dict):
        self.config = config
        self.device = DeviceCapability()

        # Model registry
        self.models = {
            'tiny': {
                'params': 0.5e6,
                'latency_ms': 10,
                'accuracy': 0.85,
                'memory_mb': 20,
                'battery_cost': 0.1
            },
            'small': {
                'params': 2e6,
                'latency_ms': 30,
                'accuracy': 0.90,
                'memory_mb': 50,
                'battery_cost': 0.3
            },
            'medium': {
                'params': 8e6,
                'latency_ms': 100,
                'accuracy': 0.95,
                'memory_mb': 150,
                'battery_cost': 1.0
            }
        }

        # Routing stats
        self.routing_stats = {name: 0 for name in self.models}
        self.total_routed = 0

    def estimate_difficulty(self, x: np.ndarray) -> float:
        """Estimate input difficulty (0-1)."""
        # Simple heuristics
        variance = np.var(x)
        complexity = min(1.0, variance * 2)
        return complexity

    def get_constraints(self, battery_level: float, latency_budget_ms: float) -> Dict:
        """Get current constraints."""
        return {
            'max_memory_mb': 100 if self.device.capabilities['tier'] == 'low' else 200,
            'max_latency_ms': latency_budget_ms,
            'max_battery_cost': 0.3 if battery_level < 20 else (0.6 if battery_level < 50 else 1.0),
            'min_accuracy': self.config.get('min_accuracy', 0.80)
        }

    def route(self, x: np.ndarray, battery_level: float = 100, latency_budget_ms: float = 100) -> str:
        """Route input to best model."""
        difficulty = self.estimate_difficulty(x)
        constraints = self.get_constraints(battery_level, latency_budget_ms)

        # Score each model
        best_model = 'tiny'
        best_score = -float('inf')

        for name, specs in self.models.items():
            # Check constraints
            if specs['memory_mb'] > constraints['max_memory_mb']:
                continue
            if specs['latency_ms'] > constraints['max_latency_ms']:
                continue
            if specs['battery_cost'] > constraints['max_battery_cost']:
                continue
            if specs['accuracy'] < constraints['min_accuracy']:
                continue

            # Score: balance accuracy and efficiency
            # Higher difficulty -> prefer more accurate model
            accuracy_need = 0.5 + difficulty * 0.5
            score = specs['accuracy'] * accuracy_need - specs['battery_cost'] * 0.2

            if score > best_score:
                best_score = score
                best_model = name

        self.routing_stats[best_model] += 1
        self.total_routed += 1

        return best_model

    def get_stats(self) -> Dict:
        """Get routing statistics."""
        distribution = {}
        for name, count in self.routing_stats.items():
            distribution[name] = count / self.total_routed if self.total_routed > 0 else 0

        # Estimate savings
        baseline_cost = self.models['medium']['battery_cost']
        actual_cost = sum(
            self.models[name]['battery_cost'] * count
            for name, count in self.routing_stats.items()
        ) / (self.total_routed or 1)

        return {
            'total_routed': self.total_routed,
            'distribution': distribution,
            'routing_counts': self.routing_stats,
            'cost_savings': 1 - actual_cost / baseline_cost
        }


def main():
    parser = argparse.ArgumentParser(description='Cross model router')
    parser.add_argument('--demo', action='store_true', help='Run demo')
    parser.add_argument('--iterations', type=int, default=100)

    args = parser.parse_args()

    if args.demo:
        router = CrossModelRouter({'min_accuracy': 0.82})

        for i in range(args.iterations):
            # Vary inputs and conditions
            x = np.random.randn(64, 64) * (0.5 + i % 3)
            battery = 100 - (i % 100)
            latency = [50, 100, 200][i % 3]

            model = router.route(x, battery, latency)

            if i % 20 == 0:
                logger.info(f"Iter {i}: battery={battery}%, latency={latency}ms -> {model}")

        stats = router.get_stats()
        logger.info(f"\n=== Routing Stats ===")
        for name, pct in stats['distribution'].items():
            logger.info(f"{name}: {pct*100:.1f}%")
        logger.info(f"Cost savings: {stats['cost_savings']*100:.1f}%")


if __name__ == '__main__':
    main()
