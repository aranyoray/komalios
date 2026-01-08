#!/usr/bin/env python3
"""
generate_interventions.py — Generate synthetic interventional data.
"""

import argparse
import json
import numpy as np
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--data_root', type=str, required=True)
    parser.add_argument('--output_dir', type=str, required=True)
    parser.add_argument('--num_interventions', type=int, default=100)
    parser.add_argument('--intervention_types', type=str, default='do,soft,hard')
    args = parser.parse_args()

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    np.random.seed(42)
    n_vars = 10
    n_samples = 100

    types = args.intervention_types.split(',')

    for i in range(args.num_interventions):
        int_type = types[i % len(types)]
        target_var = i % n_vars

        # generate interventional data
        data = np.random.randn(n_samples, n_vars)

        if int_type == 'do':
            data[:, target_var] = 1.0
        elif int_type == 'soft':
            data[:, target_var] = 0.5 * data[:, target_var] + 0.5
        elif int_type == 'hard':
            data[:, target_var] = np.random.choice([0, 1], n_samples)

        np.savez(
            output_dir / f'intervention_{i}.npz',
            data=data,
            intervention_type=int_type,
            target_variable=target_var,
        )

    print(f"generated {args.num_interventions} interventions")


if __name__ == '__main__':
    main()
