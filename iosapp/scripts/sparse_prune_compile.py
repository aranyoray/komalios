#!/usr/bin/env python3
"""
sparse_prune_compile.py — Structured pruning + sparse compilation.
"""

import argparse
import logging
import json
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn
import torch.nn.utils.prune as prune

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--model_path', type=str, required=True)
    parser.add_argument('--output_dir', type=str, required=True)
    parser.add_argument('--sparsity_targets', type=str, default='0.9,0.8,0.7')
    parser.add_argument('--finetune_epochs', type=int, default=5)
    parser.add_argument('--block_size', type=int, default=4)
    parser.add_argument('--lr', type=float, default=1e-5)
    return parser.parse_args()


def compute_sparsity(model):
    """Compute actual model sparsity."""
    total = 0
    zeros = 0
    for name, param in model.named_parameters():
        if 'weight' in name:
            total += param.numel()
            zeros += (param == 0).sum().item()
    return zeros / total if total > 0 else 0


def compute_flops(model, input_size=(1, 256, 768)):
    """Estimate FLOPs."""
    # simplified estimation
    total_params = sum(p.numel() for p in model.parameters())
    return total_params * 2  # rough approximation


def apply_structured_pruning(model, amount):
    """Apply structured filter pruning."""
    for name, module in model.named_modules():
        if isinstance(module, nn.Linear):
            prune.ln_structured(module, name='weight', amount=amount, n=2, dim=0)
        elif isinstance(module, nn.Conv2d):
            prune.ln_structured(module, name='weight', amount=amount, n=2, dim=0)
    return model


def apply_magnitude_pruning(model, amount):
    """Apply unstructured magnitude pruning."""
    for name, module in model.named_modules():
        if isinstance(module, (nn.Linear, nn.Conv2d)):
            prune.l1_unstructured(module, name='weight', amount=amount)
    return model


def remove_pruning(model):
    """Make pruning permanent."""
    for name, module in model.named_modules():
        if isinstance(module, (nn.Linear, nn.Conv2d)):
            try:
                prune.remove(module, 'weight')
            except:
                pass
    return model


def finetune(model, epochs, lr):
    """Finetune after pruning."""
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    model = model.to(device).train()
    optimizer = torch.optim.AdamW(model.parameters(), lr=lr)

    for epoch in range(epochs):
        # mock training
        for _ in range(100):
            x = torch.randn(32, 256, 768).to(device)
            y = torch.randint(0, 7, (32,)).to(device)

            if hasattr(model, 'forward'):
                out = model(x)
                if isinstance(out, dict):
                    logits = out.get('logits', out.get('output', x))
                else:
                    logits = out
            else:
                logits = x

            if logits.dim() == 3:
                logits = logits.mean(1)

            loss = nn.functional.cross_entropy(logits[:, :7] if logits.size(-1) > 7 else logits, y)

            optimizer.zero_grad()
            loss.backward()
            optimizer.step()

    return model


def benchmark(model, num_runs=100):
    """Benchmark inference."""
    import time
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    model = model.to(device).eval()

    x = torch.randn(1, 256, 768).to(device)

    # warmup
    for _ in range(10):
        with torch.no_grad():
            _ = model(x)

    if device.type == 'cuda':
        torch.cuda.synchronize()

    start = time.perf_counter()
    for _ in range(num_runs):
        with torch.no_grad():
            _ = model(x)
    if device.type == 'cuda':
        torch.cuda.synchronize()
    end = time.perf_counter()

    return (end - start) / num_runs * 1000  # ms


def main():
    args = parse_args()
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    # load model
    model = nn.Sequential(
        nn.Linear(768, 256),
        nn.ReLU(),
        nn.Linear(256, 256),
        nn.ReLU(),
        nn.Linear(256, 7),
    )

    if Path(args.model_path).exists():
        model.load_state_dict(torch.load(args.model_path, map_location='cpu'))

    results = []
    sparsity_targets = [float(s) for s in args.sparsity_targets.split(',')]

    # baseline
    baseline_latency = benchmark(model)
    baseline_flops = compute_flops(model)

    results.append({
        'sparsity_target': 0.0,
        'actual_sparsity': compute_sparsity(model),
        'latency_ms': baseline_latency,
        'flops': baseline_flops,
        'speedup': 1.0,
    })

    for target in sparsity_targets:
        logger.info(f"pruning to {target * 100}% sparsity...")

        # clone model
        pruned_model = nn.Sequential(
            nn.Linear(768, 256),
            nn.ReLU(),
            nn.Linear(256, 256),
            nn.ReLU(),
            nn.Linear(256, 7),
        )
        pruned_model.load_state_dict(model.state_dict())

        # apply pruning
        pruned_model = apply_magnitude_pruning(pruned_model, target)

        # finetune
        pruned_model = finetune(pruned_model, args.finetune_epochs, args.lr)

        # make permanent
        pruned_model = remove_pruning(pruned_model)

        # benchmark
        latency = benchmark(pruned_model)
        actual_sparsity = compute_sparsity(pruned_model)

        results.append({
            'sparsity_target': target,
            'actual_sparsity': actual_sparsity,
            'latency_ms': latency,
            'flops': compute_flops(pruned_model),
            'speedup': baseline_latency / latency,
        })

        # save model
        torch.save(pruned_model.state_dict(), output_dir / f'pruned_{int(target*100)}.pt')

        logger.info(f"sparsity: {actual_sparsity:.2%} | latency: {latency:.2f}ms | speedup: {baseline_latency/latency:.2f}x")

    # save results
    import pandas as pd
    df = pd.DataFrame(results)
    df.to_csv(output_dir / 'pruning_results.csv', index=False)

    logger.info(f"results saved to {output_dir}")


if __name__ == '__main__':
    main()
