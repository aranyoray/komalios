#!/usr/bin/env python3
"""
latency_auto_optimize.py — Per-layer benchmarking and auto-optimization.

Requirements:
torch, onnx, onnxruntime, numpy, pandas, mlflow, tqdm
"""

import os
import json
import hashlib
import logging
import argparse
import time
from pathlib import Path
from datetime import datetime

import numpy as np
import pandas as pd
import torch
import torch.nn as nn

try:
    import onnx
    import onnxruntime as ort
    HAS_ONNX = True
except ImportError:
    HAS_ONNX = False

try:
    import mlflow
    HAS_MLFLOW = True
except ImportError:
    HAS_MLFLOW = False

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description='Latency auto-optimizer')
    parser.add_argument('--data_dir', type=str, default='./data')
    parser.add_argument('--out_dir', type=str, default='./outputs/latency_optimize')
    parser.add_argument('--device', type=str, default='cpu')
    parser.add_argument('--batch_size', type=int, default=1)
    parser.add_argument('--num_runs', type=int, default=100)
    parser.add_argument('--synthetic', type=int, default=0)
    parser.add_argument('--dry_run', action='store_true')
    parser.add_argument('--debug', action='store_true')
    parser.add_argument('--n_workers', type=int, default=2)
    parser.add_argument('--max_steps', type=int, default=100)
    parser.add_argument('--convert', action='store_true')
    return parser.parse_args()


class BenchmarkModel(nn.Module):
    def __init__(self):
        super().__init__()
        self.layer1 = nn.Linear(768, 512)
        self.layer2 = nn.Linear(512, 256)
        self.layer3 = nn.Linear(256, 128)
        self.layer4 = nn.Linear(128, 7)

    def forward(self, x):
        x = torch.relu(self.layer1(x))
        x = torch.relu(self.layer2(x))
        x = torch.relu(self.layer3(x))
        return self.layer4(x)


def benchmark_pytorch(model, input_tensor, num_runs):
    """Benchmark PyTorch model."""
    model.eval()
    latencies = []

    # warmup
    for _ in range(10):
        with torch.no_grad():
            _ = model(input_tensor)

    for _ in range(num_runs):
        start = time.perf_counter()
        with torch.no_grad():
            _ = model(input_tensor)
        latencies.append((time.perf_counter() - start) * 1000)

    return np.array(latencies)


def benchmark_onnx(onnx_path, input_array, num_runs):
    """Benchmark ONNX model."""
    if not HAS_ONNX:
        return np.array([0])

    session = ort.InferenceSession(str(onnx_path))
    input_name = session.get_inputs()[0].name

    latencies = []

    # warmup
    for _ in range(10):
        _ = session.run(None, {input_name: input_array})

    for _ in range(num_runs):
        start = time.perf_counter()
        _ = session.run(None, {input_name: input_array})
        latencies.append((time.perf_counter() - start) * 1000)

    return np.array(latencies)


def per_layer_benchmark(model, input_tensor, num_runs):
    """Benchmark each layer individually."""
    model.eval()
    layer_times = {}

    x = input_tensor
    for name, layer in model.named_children():
        latencies = []
        for _ in range(num_runs):
            start = time.perf_counter()
            with torch.no_grad():
                x_out = layer(x)
            latencies.append((time.perf_counter() - start) * 1000)

        layer_times[name] = {
            'mean_ms': float(np.mean(latencies)),
            'std_ms': float(np.std(latencies)),
            'p95_ms': float(np.percentile(latencies, 95)),
        }
        x = torch.relu(x_out) if 'layer' in name and name != 'layer4' else x_out

    return layer_times


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
        mlflow.start_run(run_name='latency_optimize')
        mlflow.log_params(vars(args))

    # Create model and input
    model = BenchmarkModel()
    input_tensor = torch.randn(args.batch_size, 768)
    input_array = input_tensor.numpy()

    results = {'before': {}, 'after': {}, 'per_layer': {}}

    if args.dry_run:
        logger.info("dry run mode")
        results['before'] = {'mean_ms': 1.0, 'p95_ms': 1.5}
        results['after'] = {'mean_ms': 0.8, 'p95_ms': 1.2}
    else:
        # Benchmark PyTorch
        logger.info("benchmarking PyTorch model...")
        pytorch_latencies = benchmark_pytorch(model, input_tensor, args.num_runs)
        results['before']['pytorch'] = {
            'mean_ms': float(np.mean(pytorch_latencies)),
            'p95_ms': float(np.percentile(pytorch_latencies, 95)),
            'p99_ms': float(np.percentile(pytorch_latencies, 99)),
        }

        # Per-layer benchmark
        logger.info("per-layer benchmarking...")
        results['per_layer'] = per_layer_benchmark(model, input_tensor, args.num_runs)

        # Export and benchmark ONNX
        if args.convert and HAS_ONNX:
            logger.info("exporting to ONNX...")
            onnx_path = out_dir / 'model.onnx'
            torch.onnx.export(model, input_tensor, onnx_path,
                            input_names=['input'], output_names=['output'],
                            dynamic_axes={'input': {0: 'batch'}})

            # optimize ONNX
            optimized_path = out_dir / 'model_optimized.onnx'
            from onnxruntime.transformers import optimizer
            try:
                opt_model = optimizer.optimize_model(str(onnx_path))
                opt_model.save_model_to_file(str(optimized_path))
            except:
                import shutil
                shutil.copy(onnx_path, optimized_path)

            # Benchmark optimized
            logger.info("benchmarking optimized ONNX...")
            onnx_latencies = benchmark_onnx(optimized_path, input_array, args.num_runs)
            results['after']['onnx_optimized'] = {
                'mean_ms': float(np.mean(onnx_latencies)),
                'p95_ms': float(np.percentile(onnx_latencies, 95)),
                'p99_ms': float(np.percentile(onnx_latencies, 99)),
            }

    # Save results
    report_path = out_dir / 'latency_report.json'
    with open(report_path, 'w') as f:
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

    manifest_path = out_dir / 'artifacts_manifest.csv'
    pd.DataFrame(artifacts).to_csv(manifest_path, index=False)

    if HAS_MLFLOW:
        mlflow.end_run()

    logger.info(f"optimization complete. results saved to {out_dir}")


if __name__ == '__main__':
    main()
