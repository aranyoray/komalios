#!/usr/bin/env python3
"""
adaptive_model_resolution.py — Auto downgrade model resolution per input.
Classifies input complexity, routes to appropriate model size.
"""

import argparse
import json
import logging
import time
import numpy as np

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description='Adaptive model resolution')
    parser.add_argument('--complexity_threshold_low', type=float, default=0.3)
    parser.add_argument('--complexity_threshold_high', type=float, default=0.7)
    parser.add_argument('--demo', action='store_true')
    return parser.parse_args()


class AdaptiveResolutionRouter:
    """Routes inputs to appropriately sized models."""

    def __init__(self, low_threshold=0.3, high_threshold=0.7):
        self.low_threshold = low_threshold
        self.high_threshold = high_threshold

        # Track stats
        self.route_counts = {'tiny': 0, 'small': 0, 'large': 0}
        self.total_inference_time = 0
        self.total_samples = 0

        # Model costs (relative)
        self.model_costs = {
            'tiny': 1,
            'small': 5,
            'large': 20
        }

    def compute_complexity(self, frame):
        """Compute input frame complexity score."""
        # Multiple complexity metrics

        # Edge density (gradient magnitude)
        if frame.ndim == 3:
            gray = frame.mean(axis=2)
        else:
            gray = frame

        gy = np.diff(gray, axis=0)
        gx = np.diff(gray, axis=1)
        gradient_mag = np.sqrt(gy[:, :-1]**2 + gx[:-1, :]**2)
        edge_density = gradient_mag.mean() / 255

        # Texture (local variance)
        from scipy.ndimage import uniform_filter
        local_mean = uniform_filter(gray, size=8)
        local_sqr_mean = uniform_filter(gray**2, size=8)
        variance = local_sqr_mean - local_mean**2
        texture = np.sqrt(variance.mean()) / 255

        # Combine metrics
        complexity = 0.6 * edge_density + 0.4 * texture

        return min(1.0, complexity * 5)  # Scale to [0, 1]

    def route(self, frame):
        """Route frame to appropriate model."""
        complexity = self.compute_complexity(frame)

        if complexity < self.low_threshold:
            model = 'tiny'
        elif complexity < self.high_threshold:
            model = 'small'
        else:
            model = 'large'

        self.route_counts[model] += 1
        return model, complexity

    def run_inference(self, frame, model):
        """Simulate running inference on selected model."""
        # Simulate inference time based on model size
        base_time = 5  # ms
        time_ms = base_time * self.model_costs[model]

        # Add variance
        time_ms *= np.random.uniform(0.8, 1.2)

        # Simulate
        time.sleep(time_ms / 1000)

        self.total_inference_time += time_ms
        self.total_samples += 1

        return {'latency_ms': time_ms, 'model': model}

    def get_stats(self):
        """Get routing statistics."""
        total_routes = sum(self.route_counts.values())

        # Calculate theoretical cost vs baseline
        baseline_cost = total_routes * self.model_costs['large']
        actual_cost = sum(
            count * self.model_costs[model]
            for model, count in self.route_counts.items()
        )

        return {
            'total_samples': total_routes,
            'route_distribution': {
                k: f"{v/total_routes*100:.1f}%" if total_routes > 0 else "0%"
                for k, v in self.route_counts.items()
            },
            'avg_latency_ms': self.total_inference_time / self.total_samples if self.total_samples > 0 else 0,
            'cost_savings': f"{(1 - actual_cost/baseline_cost)*100:.1f}%" if baseline_cost > 0 else "0%"
        }


def main():
    args = parse_args()

    router = AdaptiveResolutionRouter(
        args.complexity_threshold_low,
        args.complexity_threshold_high
    )

    if args.demo:
        logger.info("Running demo...")

        # Generate test frames with varying complexity
        for i in range(100):
            # Create frame with random complexity
            if i % 3 == 0:
                # Simple frame (uniform regions)
                frame = np.ones((224, 224, 3)) * np.random.randint(0, 255)
            elif i % 3 == 1:
                # Medium complexity
                frame = np.random.randint(0, 128, (224, 224, 3))
            else:
                # Complex frame (high texture)
                frame = np.random.randint(0, 255, (224, 224, 3))

            # Route and run
            model, complexity = router.route(frame)
            result = router.run_inference(frame, model)

            if (i + 1) % 20 == 0:
                logger.info(f"Processed {i+1} frames")

        stats = router.get_stats()
        print(json.dumps(stats, indent=2))

    else:
        print("Use --demo to run demonstration")


if __name__ == '__main__':
    main()
