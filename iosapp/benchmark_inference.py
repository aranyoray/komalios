#!/usr/bin/env python3
"""
benchmark_inference.py — Latency benchmarks across device types.
"""

import argparse
import json
import time
import logging
from pathlib import Path

import numpy as np
import torch

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description='Inference Benchmark')
    parser.add_argument('--model_path', type=str, required=True)
    parser.add_argument('--device', type=str, default='cuda', choices=['cuda', 'cpu', 'mobile_cpu', 'webgpu', 'edge_tpu'])
    parser.add_argument('--batch_size', type=int, default=1)
    parser.add_argument('--num_runs', type=int, default=100)
    parser.add_argument('--warmup_runs', type=int, default=10)
    parser.add_argument('--output_json', type=str, required=True)
    return parser.parse_args()


def benchmark(args):
    from models.multimodal_transformer import create_model

    # setup device
    if args.device in ['cuda']:
        device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    else:
        device = torch.device('cpu')

    # load model
    model_config = {
        'model_dim': 768,
        'ffn_dim': 3072,
        'num_layers': 12,
        'num_heads': 12,
    }
    model = create_model(argparse.Namespace(**model_config))

    if Path(args.model_path).exists():
        state = torch.load(args.model_path, map_location='cpu')
        if 'model_state_dict' in state:
            model.load_state_dict(state['model_state_dict'])
        else:
            model.load_state_dict(state)

    model = model.to(device).eval()

    # create dummy input
    seq_len = 256
    dummy_input = {
        'gaze': torch.randn(args.batch_size, seq_len, 5).to(device),
        'audio': torch.randn(args.batch_size, seq_len, 80).to(device),
        'face': torch.randn(args.batch_size, seq_len, 768).to(device),
        'touch': torch.randn(args.batch_size, seq_len, 5).to(device),
    }

    # warmup
    logger.info(f'warming up ({args.warmup_runs} runs)...')
    with torch.no_grad():
        for _ in range(args.warmup_runs):
            _ = model.model(**dummy_input)

    if device.type == 'cuda':
        torch.cuda.synchronize()

    # benchmark
    logger.info(f'benchmarking ({args.num_runs} runs)...')
    latencies = []

    with torch.no_grad():
        for _ in range(args.num_runs):
            if device.type == 'cuda':
                torch.cuda.synchronize()

            start = time.perf_counter()
            _ = model.model(**dummy_input)

            if device.type == 'cuda':
                torch.cuda.synchronize()

            end = time.perf_counter()
            latencies.append((end - start) * 1000)  # ms

    # compute stats
    latencies = np.array(latencies)
    results = {
        'device': args.device,
        'batch_size': args.batch_size,
        'num_runs': args.num_runs,
        'mean_ms': float(np.mean(latencies)),
        'std_ms': float(np.std(latencies)),
        'p50_ms': float(np.percentile(latencies, 50)),
        'p95_ms': float(np.percentile(latencies, 95)),
        'p99_ms': float(np.percentile(latencies, 99)),
        'min_ms': float(np.min(latencies)),
        'max_ms': float(np.max(latencies)),
    }

    # memory
    if device.type == 'cuda':
        results['memory_mb'] = torch.cuda.max_memory_allocated() / 1e6
    else:
        import psutil
        results['memory_mb'] = psutil.Process().memory_info().rss / 1e6

    # save results
    output_path = Path(args.output_json)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, 'w') as f:
        json.dump(results, f, indent=2)

    logger.info(f'results saved to {output_path}')
    logger.info(f'p50: {results["p50_ms"]:.2f}ms | p95: {results["p95_ms"]:.2f}ms | p99: {results["p99_ms"]:.2f}ms')


if __name__ == '__main__':
    args = parse_args()
    benchmark(args)
