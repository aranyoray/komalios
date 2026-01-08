#!/usr/bin/env python3
"""
cost_simulator_for_planning.py — Simulate costs for infrastructure choices.
Simulates monthly costs under different configs, produces confidence intervals.
"""

import argparse
import json
import logging
from datetime import datetime
import numpy as np

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description='Cost simulator for planning')
    parser.add_argument('--workload', type=str, default='medium',
                        choices=['low', 'medium', 'high'])
    parser.add_argument('--simulations', type=int, default=1000)
    parser.add_argument('--output', type=str, default='./cost_simulation.json')
    return parser.parse_args()


# Pricing (simplified, USD)
PRICING = {
    'gpu': {
        'on_demand': {'p3.2xlarge': 3.06, 'g4dn.xlarge': 0.526},
        'spot': {'p3.2xlarge': 0.92, 'g4dn.xlarge': 0.158}
    },
    'compute': {
        'on_demand': {'m5.large': 0.096, 'm5.xlarge': 0.192},
        'spot': {'m5.large': 0.029, 'm5.xlarge': 0.058}
    },
    'storage': {
        's3': 0.023,  # per GB
        'ebs': 0.10   # per GB
    }
}

# Workload profiles (hours/month)
WORKLOADS = {
    'low': {'gpu_hours': 100, 'compute_hours': 500, 'storage_gb': 100},
    'medium': {'gpu_hours': 500, 'compute_hours': 2000, 'storage_gb': 500},
    'high': {'gpu_hours': 2000, 'compute_hours': 8000, 'storage_gb': 2000}
}


def simulate_spot_availability(hours_needed, preemption_rate=0.15):
    """Simulate spot instance availability with preemption."""
    available_hours = 0
    preempted_hours = 0

    remaining = hours_needed
    while remaining > 0:
        # Simulate a spot run
        run_duration = min(remaining, np.random.exponential(10))

        if np.random.random() < preemption_rate:
            # Preempted
            preempted_hours += run_duration * 0.5  # Partial work lost
            available_hours += run_duration * 0.5
        else:
            available_hours += run_duration

        remaining -= run_duration

    return available_hours, preempted_hours


def simulate_config(config, workload, n_simulations):
    """Simulate monthly costs for a configuration."""
    costs = []

    for _ in range(n_simulations):
        monthly_cost = 0

        # GPU costs
        gpu_hours = workload['gpu_hours']
        if config.get('gpu_spot_ratio', 0) > 0:
            spot_hours = gpu_hours * config['gpu_spot_ratio']
            ondemand_hours = gpu_hours * (1 - config['gpu_spot_ratio'])

            # Simulate spot availability
            actual_spot, preempted = simulate_spot_availability(spot_hours)

            # Need to cover preempted with on-demand
            ondemand_hours += preempted

            gpu_cost = (actual_spot * PRICING['gpu']['spot'][config['gpu_type']] +
                       ondemand_hours * PRICING['gpu']['on_demand'][config['gpu_type']])
        else:
            gpu_cost = gpu_hours * PRICING['gpu']['on_demand'][config['gpu_type']]

        monthly_cost += gpu_cost

        # Compute costs
        compute_hours = workload['compute_hours']
        if config.get('compute_spot_ratio', 0) > 0:
            spot_hours = compute_hours * config['compute_spot_ratio']
            actual_spot, _ = simulate_spot_availability(spot_hours)

            compute_cost = (actual_spot * PRICING['compute']['spot'][config['compute_type']] +
                          (compute_hours - actual_spot) * PRICING['compute']['on_demand'][config['compute_type']])
        else:
            compute_cost = compute_hours * PRICING['compute']['on_demand'][config['compute_type']]

        monthly_cost += compute_cost

        # Storage costs
        storage_cost = workload['storage_gb'] * PRICING['storage']['s3']
        monthly_cost += storage_cost

        costs.append(monthly_cost)

    return np.array(costs)


def main():
    args = parse_args()

    workload = WORKLOADS[args.workload]

    # Define configurations to simulate
    configs = [
        {
            'name': 'all_on_demand',
            'gpu_type': 'g4dn.xlarge',
            'compute_type': 'm5.large',
            'gpu_spot_ratio': 0,
            'compute_spot_ratio': 0
        },
        {
            'name': 'moderate_spot',
            'gpu_type': 'g4dn.xlarge',
            'compute_type': 'm5.large',
            'gpu_spot_ratio': 0.5,
            'compute_spot_ratio': 0.7
        },
        {
            'name': 'aggressive_spot',
            'gpu_type': 'g4dn.xlarge',
            'compute_type': 'm5.large',
            'gpu_spot_ratio': 0.8,
            'compute_spot_ratio': 0.9
        },
        {
            'name': 'larger_gpu_spot',
            'gpu_type': 'p3.2xlarge',
            'compute_type': 'm5.xlarge',
            'gpu_spot_ratio': 0.7,
            'compute_spot_ratio': 0.8
        }
    ]

    results = []

    for config in configs:
        logger.info(f"Simulating: {config['name']}")
        costs = simulate_config(config, workload, args.simulations)

        result = {
            'config': config['name'],
            'mean_cost': float(np.mean(costs)),
            'std_cost': float(np.std(costs)),
            'p5': float(np.percentile(costs, 5)),
            'p50': float(np.percentile(costs, 50)),
            'p95': float(np.percentile(costs, 95)),
            'confidence_interval_95': [
                float(np.percentile(costs, 2.5)),
                float(np.percentile(costs, 97.5))
            ]
        }
        results.append(result)

        logger.info(f"  Mean: ${result['mean_cost']:.2f} (95% CI: ${result['confidence_interval_95'][0]:.2f}-${result['confidence_interval_95'][1]:.2f})")

    # Find recommendation
    sorted_results = sorted(results, key=lambda x: x['mean_cost'])
    recommended = sorted_results[0]

    baseline = next(r for r in results if r['config'] == 'all_on_demand')
    savings = ((baseline['mean_cost'] - recommended['mean_cost']) / baseline['mean_cost']) * 100

    output = {
        'workload': args.workload,
        'simulations': args.simulations,
        'generated_at': datetime.now().isoformat(),
        'results': results,
        'recommendation': {
            'config': recommended['config'],
            'expected_monthly_cost': recommended['mean_cost'],
            'vs_on_demand_savings_percent': round(savings, 1)
        }
    }

    with open(args.output, 'w') as f:
        json.dump(output, f, indent=2)

    logger.info(f"\nRecommendation: {recommended['config']}")
    logger.info(f"Expected cost: ${recommended['mean_cost']:.2f}/month")
    logger.info(f"Savings vs on-demand: {savings:.1f}%")

    print(json.dumps(output['recommendation'], indent=2))


if __name__ == '__main__':
    main()
