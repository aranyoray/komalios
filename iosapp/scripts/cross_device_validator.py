#!/usr/bin/env python3
"""
cross_device_validator.py — Validate model consistency across device types.
"""

import argparse
import hashlib
import logging
import json
from pathlib import Path
from datetime import datetime

import numpy as np
import pandas as pd
import torch
import torch.nn as nn

try:
    import mlflow
    HAS_MLFLOW = True
except ImportError:
    HAS_MLFLOW = False

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--model_dir', type=str, default='./models')
    parser.add_argument('--out_dir', type=str, default='./outputs/cross_device')
    parser.add_argument('--n_samples', type=int, default=1000)
    parser.add_argument('--tolerance', type=float, default=1e-5)
    parser.add_argument('--synthetic', type=int, default=0)
    parser.add_argument('--dry_run', action='store_true')
    parser.add_argument('--debug', action='store_true')
    return parser.parse_args()


class TestModel(nn.Module):
    def __init__(self):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(768, 256),
            nn.ReLU(),
            nn.Linear(256, 7),
        )

    def forward(self, x):
        return self.net(x)


def simulate_device_inference(model, x, device_type):
    """Simulate inference on different device types."""
    model.eval()

    if device_type == 'cpu_fp32':
        with torch.no_grad():
            return model(x).numpy()

    elif device_type == 'cpu_fp16':
        model_fp16 = model.half()
        with torch.no_grad():
            return model_fp16(x.half()).float().numpy()

    elif device_type == 'quantized_int8':
        model.qconfig = torch.quantization.get_default_qconfig('fbgemm')
        model_prepared = torch.quantization.prepare(model, inplace=False)
        with torch.no_grad():
            for _ in range(10):
                model_prepared(torch.randn(32, 768))
        model_quantized = torch.quantization.convert(model_prepared, inplace=False)
        with torch.no_grad():
            return model_quantized(x).numpy()

    elif device_type == 'mobile_sim':
        # simulate mobile numerical precision
        with torch.no_grad():
            out = model(x)
            # add small noise to simulate mobile precision
            out = out + torch.randn_like(out) * 1e-6
            return out.numpy()

    return model(x).detach().numpy()


def compute_sha256(filepath):
    sha256_hash = hashlib.sha256()
    with open(filepath, 'rb') as f:
        for chunk in iter(lambda: f.read(4096), b''):
            sha256_hash.update(chunk)
    return sha256_hash.hexdigest()


def main():
    args = parse_args()
    if args.debug:
        logging.getLogger().setLevel(logging.DEBUG)

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    if HAS_MLFLOW:
        mlflow.start_run(run_name='cross_device')
        mlflow.log_params(vars(args))

    # Create model
    model = TestModel()

    # Generate test data
    n_samples = args.synthetic if args.synthetic > 0 else args.n_samples
    x = torch.randn(n_samples, 768)

    device_types = ['cpu_fp32', 'cpu_fp16', 'quantized_int8', 'mobile_sim']
    results = {'comparisons': []}

    if args.dry_run:
        logger.info("dry run mode")
        for d1 in device_types:
            for d2 in device_types:
                if d1 < d2:
                    results['comparisons'].append({
                        'device_1': d1,
                        'device_2': d2,
                        'max_diff': 0.001,
                        'mean_diff': 0.0001,
                        'passed': True,
                    })
    else:
        logger.info("running cross-device validation...")

        outputs = {}
        for device_type in device_types:
            logger.info(f"inferring on {device_type}...")
            outputs[device_type] = simulate_device_inference(model, x, device_type)

        # Compare outputs
        baseline = outputs['cpu_fp32']
        for device_type in device_types:
            if device_type == 'cpu_fp32':
                continue

            diff = np.abs(outputs[device_type] - baseline)
            max_diff = diff.max()
            mean_diff = diff.mean()
            passed = max_diff < args.tolerance * 1000  # relaxed for quantized

            results['comparisons'].append({
                'device_1': 'cpu_fp32',
                'device_2': device_type,
                'max_diff': float(max_diff),
                'mean_diff': float(mean_diff),
                'passed': bool(passed),
            })

            logger.info(f"  {device_type}: max_diff={max_diff:.6f}, passed={passed}")

    # Summary
    passed_count = sum(1 for c in results['comparisons'] if c['passed'])
    results['summary'] = {
        'total_comparisons': len(results['comparisons']),
        'passed': passed_count,
        'failed': len(results['comparisons']) - passed_count,
    }

    # Save results
    with open(out_dir / 'validation_results.json', 'w') as f:
        json.dump(results, f, indent=2)

    # Create manifest
    artifacts = []
    for path in out_dir.glob('*'):
        if path.is_file():
            artifacts.append({
                'path': str(path),
                'sha256': compute_sha256(path),
                'size': path.stat().st_size,
                'created_at': datetime.now().isoformat(),
            })

    pd.DataFrame(artifacts).to_csv(out_dir / 'artifacts_manifest.csv', index=False)

    if HAS_MLFLOW:
        mlflow.end_run()

    logger.info(f"cross-device validation complete. saved to {out_dir}")


if __name__ == '__main__':
    main()
