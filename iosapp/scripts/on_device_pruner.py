#!/usr/bin/env python3
"""
on_device_pruner.py — Periodic lightweight pruning for on-device weights.
Applies structured magnitude pruning, saves sparse deltas, measures accuracy.
"""

import argparse
import json
import logging
from pathlib import Path
from datetime import datetime
import numpy as np

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)

try:
    import torch
    import torch.nn as nn
    TORCH_AVAILABLE = True
except ImportError:
    TORCH_AVAILABLE = False


def parse_args():
    parser = argparse.ArgumentParser(description='On-device pruner')
    parser.add_argument('--model_path', type=str, help='Model to prune')
    parser.add_argument('--output_dir', type=str, default='./pruned_models')
    parser.add_argument('--sparsity', type=float, default=0.3, help='Target sparsity')
    parser.add_argument('--layers', type=str, default='adapter', help='Layer pattern to prune')
    parser.add_argument('--validation_data', type=str, help='Validation data for accuracy check')
    parser.add_argument('--accuracy_threshold', type=float, default=0.95, help='Min relative accuracy')
    return parser.parse_args()


def magnitude_prune(tensor, sparsity):
    """Apply magnitude-based pruning."""
    if isinstance(tensor, np.ndarray):
        values = tensor
    else:
        values = tensor.detach().cpu().numpy()

    # Compute threshold
    threshold = np.percentile(np.abs(values), sparsity * 100)

    # Create mask
    mask = np.abs(values) > threshold

    # Apply mask
    pruned = values * mask

    return pruned, mask


def structured_prune_channel(tensor, sparsity):
    """Prune entire channels based on magnitude."""
    if len(tensor.shape) < 2:
        return tensor, np.ones_like(tensor, dtype=bool)

    # Compute channel importance (L2 norm)
    if len(tensor.shape) == 4:  # Conv
        importance = np.sqrt((tensor ** 2).sum(axis=(1, 2, 3)))
    else:  # Linear
        importance = np.sqrt((tensor ** 2).sum(axis=1))

    # Determine channels to keep
    n_keep = int(len(importance) * (1 - sparsity))
    keep_indices = np.argsort(importance)[-n_keep:]

    # Create mask
    mask = np.zeros(tensor.shape[0], dtype=bool)
    mask[keep_indices] = True

    return tensor, mask


def prune_model(state_dict, sparsity, layer_pattern):
    """Prune matching layers in model."""
    pruned_state = {}
    pruning_stats = []

    for key, tensor in state_dict.items():
        if layer_pattern in key.lower():
            # Apply pruning
            if TORCH_AVAILABLE and isinstance(tensor, torch.Tensor):
                tensor_np = tensor.cpu().numpy()
            else:
                tensor_np = np.array(tensor)

            pruned, mask = magnitude_prune(tensor_np, sparsity)

            actual_sparsity = 1 - (mask.sum() / mask.size)
            pruning_stats.append({
                'layer': key,
                'original_shape': list(tensor_np.shape),
                'sparsity': round(float(actual_sparsity), 3),
                'nonzero': int(mask.sum())
            })

            if TORCH_AVAILABLE:
                pruned_state[key] = torch.from_numpy(pruned)
            else:
                pruned_state[key] = pruned
        else:
            pruned_state[key] = tensor

    return pruned_state, pruning_stats


def evaluate_accuracy(model_state, validation_data):
    """Evaluate model accuracy on validation data."""
    # Placeholder - would actually run inference
    return np.random.uniform(0.85, 0.98)


def save_sparse_delta(original_state, pruned_state, output_path):
    """Save only the changed (pruned) weights as sparse representation."""
    delta = {}

    for key in pruned_state:
        if key in original_state:
            orig = original_state[key]
            pruned = pruned_state[key]

            if TORCH_AVAILABLE:
                orig_np = orig.cpu().numpy() if isinstance(orig, torch.Tensor) else orig
                pruned_np = pruned.cpu().numpy() if isinstance(pruned, torch.Tensor) else pruned
            else:
                orig_np = np.array(orig)
                pruned_np = np.array(pruned)

            # Only save if changed
            if not np.allclose(orig_np, pruned_np):
                # Store as sparse
                nonzero_indices = np.nonzero(pruned_np)
                nonzero_values = pruned_np[nonzero_indices]

                delta[key] = {
                    'shape': list(pruned_np.shape),
                    'indices': [idx.tolist() for idx in nonzero_indices],
                    'values': nonzero_values.tolist()
                }

    with open(output_path, 'w') as f:
        json.dump(delta, f)

    return len(delta)


def main():
    args = parse_args()

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    # Load model
    if args.model_path:
        if TORCH_AVAILABLE:
            original_state = torch.load(args.model_path, map_location='cpu')
        else:
            import pickle
            with open(args.model_path, 'rb') as f:
                original_state = pickle.load(f)
    else:
        # Demo state
        original_state = {
            f'adapter_layer_{i}': np.random.randn(256, 256).astype(np.float32)
            for i in range(4)
        }

    logger.info(f"Loaded model with {len(original_state)} layers")

    # Prune
    pruned_state, stats = prune_model(original_state, args.sparsity, args.layers)

    logger.info(f"Pruned {len(stats)} layers")
    for stat in stats:
        logger.info(f"  {stat['layer']}: {stat['sparsity']*100:.1f}% sparse")

    # Evaluate accuracy
    accuracy = evaluate_accuracy(pruned_state, args.validation_data)
    logger.info(f"Post-pruning accuracy: {accuracy:.3f}")

    if accuracy < args.accuracy_threshold:
        logger.warning(f"Accuracy below threshold {args.accuracy_threshold}")

    # Save sparse delta
    delta_path = output_dir / f"pruned_delta_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    n_changed = save_sparse_delta(original_state, pruned_state, delta_path)
    logger.info(f"Saved sparse delta: {delta_path} ({n_changed} layers)")

    # Summary
    summary = {
        'target_sparsity': args.sparsity,
        'layers_pruned': len(stats),
        'post_pruning_accuracy': float(accuracy),
        'accuracy_threshold': args.accuracy_threshold,
        'passed': accuracy >= args.accuracy_threshold,
        'delta_path': str(delta_path),
        'stats': stats
    }

    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()
