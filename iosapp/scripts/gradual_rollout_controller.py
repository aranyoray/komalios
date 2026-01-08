#!/usr/bin/env python3
"""
gradual_rollout_controller.py — Cost-aware progressive rollout.
Deploys to small %, measures impact, auto-scales if thresholds ok.
"""

import argparse
import json
import logging
import time
from datetime import datetime
import numpy as np

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description='Gradual rollout controller')
    parser.add_argument('--model_name', type=str, required=True)
    parser.add_argument('--initial_percent', type=float, default=5.0)
    parser.add_argument('--max_percent', type=float, default=100.0)
    parser.add_argument('--step_percent', type=float, default=10.0)
    parser.add_argument('--cost_threshold', type=float, default=1.2, help='Max cost increase ratio')
    parser.add_argument('--latency_threshold_ms', type=float, default=200)
    parser.add_argument('--check_interval', type=int, default=60, help='Seconds between checks')
    parser.add_argument('--output', type=str, default='./rollout_state.json')
    parser.add_argument('--simulate', action='store_true')
    return parser.parse_args()


class RolloutController:
    """Manages gradual model rollout."""

    def __init__(self, model_name, initial_percent, max_percent, step_percent):
        self.model_name = model_name
        self.current_percent = initial_percent
        self.max_percent = max_percent
        self.step_percent = step_percent
        self.history = []
        self.status = 'running'

    def get_metrics(self, simulate=False):
        """Get current metrics (GPU cost, latency)."""
        if simulate:
            # Simulate metrics with some variance
            base_cost = 1.0 + self.current_percent / 200
            cost_ratio = base_cost + np.random.uniform(-0.1, 0.1)
            latency = 100 + self.current_percent * 0.5 + np.random.uniform(-10, 20)
            error_rate = 0.01 + np.random.uniform(0, 0.02)
        else:
            # Would fetch from monitoring system
            cost_ratio = 1.0
            latency = 100
            error_rate = 0.01

        return {
            'timestamp': datetime.now().isoformat(),
            'rollout_percent': self.current_percent,
            'cost_ratio': cost_ratio,
            'p95_latency_ms': latency,
            'error_rate': error_rate
        }

    def should_advance(self, metrics, cost_threshold, latency_threshold):
        """Check if rollout should advance."""
        if metrics['cost_ratio'] > cost_threshold:
            return False, f"Cost ratio {metrics['cost_ratio']:.2f} > {cost_threshold}"

        if metrics['p95_latency_ms'] > latency_threshold:
            return False, f"Latency {metrics['p95_latency_ms']:.0f}ms > {latency_threshold}ms"

        if metrics['error_rate'] > 0.05:
            return False, f"Error rate {metrics['error_rate']:.2%} too high"

        return True, "OK"

    def advance_rollout(self):
        """Increase rollout percentage."""
        old_percent = self.current_percent
        self.current_percent = min(self.max_percent, self.current_percent + self.step_percent)
        logger.info(f"Advanced rollout: {old_percent}% -> {self.current_percent}%")
        return self.current_percent

    def rollback(self):
        """Rollback to previous percentage."""
        old_percent = self.current_percent
        self.current_percent = max(0, self.current_percent - self.step_percent * 2)
        self.status = 'rolled_back'
        logger.warning(f"Rolled back: {old_percent}% -> {self.current_percent}%")

    def is_complete(self):
        """Check if rollout is complete."""
        return self.current_percent >= self.max_percent

    def get_state(self):
        """Get current rollout state."""
        return {
            'model_name': self.model_name,
            'current_percent': self.current_percent,
            'max_percent': self.max_percent,
            'status': self.status,
            'history': self.history
        }


def main():
    args = parse_args()

    controller = RolloutController(
        args.model_name,
        args.initial_percent,
        args.max_percent,
        args.step_percent
    )

    logger.info(f"Starting rollout for: {args.model_name}")
    logger.info(f"Initial: {args.initial_percent}%, Target: {args.max_percent}%")

    consecutive_failures = 0
    max_failures = 3

    while not controller.is_complete() and controller.status == 'running':
        # Get metrics
        metrics = controller.get_metrics(args.simulate)
        controller.history.append(metrics)

        # Check thresholds
        should_advance, reason = controller.should_advance(
            metrics, args.cost_threshold, args.latency_threshold_ms
        )

        if should_advance:
            controller.advance_rollout()
            consecutive_failures = 0

            if controller.is_complete():
                controller.status = 'complete'
                logger.info("Rollout complete!")
        else:
            consecutive_failures += 1
            logger.warning(f"Cannot advance: {reason} (failure {consecutive_failures}/{max_failures})")

            if consecutive_failures >= max_failures:
                controller.rollback()
                break

        # Save state
        with open(args.output, 'w') as f:
            json.dump(controller.get_state(), f, indent=2)

        if args.simulate:
            time.sleep(1)  # Short delay for simulation
        else:
            time.sleep(args.check_interval)

    # Final state
    final_state = controller.get_state()

    logger.info(f"Rollout ended: {final_state['status']} at {final_state['current_percent']}%")
    print(json.dumps(final_state, indent=2))


if __name__ == '__main__':
    main()
