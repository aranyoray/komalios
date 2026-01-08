#!/usr/bin/env python3
"""
collect_metrics.py — Collect metrics from all experiments.
"""

import argparse
import json
import pandas as pd
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--sweep_dir', type=str, default='')
    parser.add_argument('--pretrain_dir', type=str, default='')
    parser.add_argument('--federated_dir', type=str, default='')
    parser.add_argument('--xgen_dir', type=str, default='')
    parser.add_argument('--output_csv', type=str, required=True)
    args = parser.parse_args()

    metrics = []

    # collect from each source
    for name, dir_path in [
        ('sweep', args.sweep_dir),
        ('pretrain', args.pretrain_dir),
        ('federated', args.federated_dir),
        ('xgen', args.xgen_dir),
    ]:
        if not dir_path:
            continue

        path = Path(dir_path)
        if not path.exists():
            continue

        for json_file in path.rglob('*.json'):
            try:
                with open(json_file) as f:
                    data = json.load(f)
                data['source'] = name
                data['file'] = str(json_file)
                metrics.append(data)
            except:
                pass

    df = pd.DataFrame(metrics)
    df.to_csv(args.output_csv, index=False)
    print(f"collected {len(metrics)} metric entries")


if __name__ == '__main__':
    main()
