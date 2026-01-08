#!/usr/bin/env python3
"""
lite_model_ab_test.py — Cheap A/B testing harness for client models.
Randomized assignment, aggregated metrics only, statistical tests, auto-retirement.
"""

import argparse
import json
import logging
import random
import hashlib
from pathlib import Path
from datetime import datetime
from collections import defaultdict
import numpy as np

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description='Lite model A/B testing')
    parser.add_argument('--experiment_config', type=str, help='Experiment config JSON')
    parser.add_argument('--results_dir', type=str, default='./ab_results')
    parser.add_argument('--min_samples', type=int, default=100)
    parser.add_argument('--significance_level', type=float, default=0.05)
    parser.add_argument('--simulate', type=int, default=0, help='Simulate N samples')
    return parser.parse_args()


def assign_variant(user_id, variants, weights=None):
    """Deterministically assign user to variant."""
    # Hash user ID for consistent assignment
    hash_val = int(hashlib.md5(user_id.encode()).hexdigest(), 16)
    rand_val = (hash_val % 10000) / 10000

    if weights is None:
        weights = [1 / len(variants)] * len(variants)

    cumsum = 0
    for variant, weight in zip(variants, weights):
        cumsum += weight
        if rand_val < cumsum:
            return variant

    return variants[-1]


def welch_t_test(a, b):
    """Welch's t-test for unequal variances."""
    n_a, n_b = len(a), len(b)
    mean_a, mean_b = np.mean(a), np.mean(b)
    var_a, var_b = np.var(a, ddof=1), np.var(b, ddof=1)

    t_stat = (mean_a - mean_b) / np.sqrt(var_a / n_a + var_b / n_b)

    # Degrees of freedom (Welch-Satterthwaite)
    df = ((var_a / n_a + var_b / n_b) ** 2 /
          ((var_a / n_a) ** 2 / (n_a - 1) + (var_b / n_b) ** 2 / (n_b - 1)))

    # Two-tailed p-value (approximation)
    from scipy import stats
    p_value = 2 * (1 - stats.t.cdf(abs(t_stat), df))

    return t_stat, p_value


def analyze_experiment(results, control_name, significance_level):
    """Analyze experiment results."""
    analysis = {
        'variants': {},
        'comparisons': []
    }

    control_data = results.get(control_name, [])

    for variant, data in results.items():
        analysis['variants'][variant] = {
            'n': len(data),
            'mean': float(np.mean(data)) if data else 0,
            'std': float(np.std(data)) if data else 0
        }

        # Compare to control
        if variant != control_name and len(data) > 10 and len(control_data) > 10:
            try:
                t_stat, p_value = welch_t_test(data, control_data)

                comparison = {
                    'variant': variant,
                    'vs': control_name,
                    't_statistic': float(t_stat),
                    'p_value': float(p_value),
                    'significant': p_value < significance_level,
                    'effect_size': float((np.mean(data) - np.mean(control_data)) / np.std(control_data))
                        if np.std(control_data) > 0 else 0
                }

                analysis['comparisons'].append(comparison)
            except:
                pass

    return analysis


def decide_winner(analysis, min_improvement=0.05):
    """Decide winning variant."""
    for comparison in analysis['comparisons']:
        if comparison['significant'] and comparison['effect_size'] > min_improvement:
            return comparison['variant'], 'winner'
        elif comparison['significant'] and comparison['effect_size'] < -min_improvement:
            return comparison['variant'], 'loser'

    return None, 'inconclusive'


def simulate_experiment(n_samples, variants, true_effects):
    """Simulate experiment data."""
    results = defaultdict(list)

    for i in range(n_samples):
        user_id = f"user_{i}"
        variant = assign_variant(user_id, variants)

        # Simulate metric with true effect
        base_metric = 0.5
        effect = true_effects.get(variant, 0)
        metric = base_metric + effect + np.random.randn() * 0.1

        results[variant].append(metric)

    return dict(results)


def main():
    args = parse_args()

    results_dir = Path(args.results_dir)
    results_dir.mkdir(parents=True, exist_ok=True)

    # Load or simulate experiment
    if args.simulate > 0:
        variants = ['control', 'treatment_a', 'treatment_b']
        true_effects = {'control': 0, 'treatment_a': 0.05, 'treatment_b': -0.02}

        results = simulate_experiment(args.simulate, variants, true_effects)
        logger.info(f"Simulated {args.simulate} samples")
    elif args.experiment_config:
        with open(args.experiment_config) as f:
            config = json.load(f)
        results = config.get('results', {})
        variants = list(results.keys())
    else:
        logger.error("Specify --experiment_config or --simulate")
        return 1

    # Check minimum samples
    for variant, data in results.items():
        if len(data) < args.min_samples:
            logger.warning(f"{variant}: only {len(data)} samples (need {args.min_samples})")

    # Analyze
    analysis = analyze_experiment(results, 'control', args.significance_level)

    # Decide winner
    winner, decision = decide_winner(analysis)

    # Output
    output = {
        'timestamp': datetime.now().isoformat(),
        'min_samples': args.min_samples,
        'significance_level': args.significance_level,
        'analysis': analysis,
        'decision': {
            'winner': winner,
            'status': decision
        }
    }

    # Recommend retirement
    if decision == 'loser':
        output['recommendation'] = f"Retire variant: {winner}"
        logger.info(f"Recommendation: Retire {winner}")
    elif decision == 'winner':
        output['recommendation'] = f"Promote variant: {winner}"
        logger.info(f"Recommendation: Promote {winner}")
    else:
        output['recommendation'] = "Continue experiment"

    output_path = results_dir / f"ab_analysis_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    with open(output_path, 'w') as f:
        json.dump(output, f, indent=2)

    print(json.dumps(output['decision'], indent=2))
    return 0


if __name__ == '__main__':
    exit(main())
