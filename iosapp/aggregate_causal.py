#!/usr/bin/env python3
"""
aggregate_causal.py — Aggregate causal discovery results.
"""

import argparse
import json
import numpy as np
import pandas as pd
from pathlib import Path


def compute_shd(pred, true):
    """Structural Hamming Distance."""
    return np.sum(pred != true)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--input_dir', type=str, required=True)
    parser.add_argument('--output_csv', type=str, required=True)
    parser.add_argument('--compute_shd', action='store_true')
    parser.add_argument('--compute_sid', action='store_true')
    args = parser.parse_args()

    input_dir = Path(args.input_dir)
    results = []

    for algo_dir in input_dir.iterdir():
        if not algo_dir.is_dir():
            continue

        for json_file in algo_dir.glob('*.json'):
            with open(json_file) as f:
                data = json.load(f)

            results.append({
                'algorithm': data.get('algorithm', algo_dir.name),
                'seed': data.get('seed', 0),
                'num_edges': data.get('num_edges', 0),
                'n_variables': data.get('n_variables', 0),
            })

    df = pd.DataFrame(results)
    df.to_csv(args.output_csv, index=False)
    print(f"saved {len(results)} results to {args.output_csv}")


if __name__ == '__main__':
    main()
