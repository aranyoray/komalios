#!/usr/bin/env python3
"""
aggregate_benchmarks.py — Aggregate inference benchmark results.
"""

import argparse
import json
import pandas as pd
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--input_dir', type=str, required=True)
    parser.add_argument('--output_csv', type=str, required=True)
    parser.add_argument('--metrics', type=str, default='p50,p95,p99,memory_mb')
    args = parser.parse_args()

    input_dir = Path(args.input_dir)
    metrics = args.metrics.split(',')
    results = []

    for json_file in input_dir.glob('*.json'):
        with open(json_file) as f:
            data = json.load(f)

        row = {
            'device': data.get('device', ''),
            'batch_size': data.get('batch_size', 0),
        }
        for metric in metrics:
            row[metric] = data.get(f'{metric}_ms' if 'ms' not in metric else metric, data.get(metric, 0))

        results.append(row)

    df = pd.DataFrame(results)
    df.to_csv(args.output_csv, index=False)
    print(f"saved {len(results)} results to {args.output_csv}")


if __name__ == '__main__':
    main()
