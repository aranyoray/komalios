#!/usr/bin/env python3
"""
aggregate_xgen.py — Aggregate cross-generalization results into matrix.
"""

import argparse
import json
import pandas as pd
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--input_dir', type=str, required=True)
    parser.add_argument('--output_csv', type=str, required=True)
    args = parser.parse_args()

    input_dir = Path(args.input_dir)
    results = []

    for json_file in input_dir.glob('*.json'):
        with open(json_file) as f:
            data = json.load(f)

        # parse train/eval from filename
        parts = json_file.stem.split('_to_')
        if len(parts) == 2:
            train_ds, eval_ds = parts
        else:
            train_ds = data.get('model_path', '').split('/')[-2] if 'model_path' in data else 'unknown'
            eval_ds = data.get('eval_dataset', 'unknown')

        results.append({
            'train_dataset': train_ds,
            'eval_dataset': eval_ds,
            'accuracy': data.get('accuracy', 0),
            'mmd': data.get('mmd', 0),
            'frechet': data.get('frechet', 0),
        })

    df = pd.DataFrame(results)
    df.to_csv(args.output_csv, index=False)
    print(f"saved {len(results)} results to {args.output_csv}")


if __name__ == '__main__':
    main()
