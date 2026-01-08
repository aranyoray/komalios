#!/usr/bin/env python3
"""
delta_checkpointing.py — Incremental checkpoints storing only changed tensors.
Reduces storage IO, reconstructs full checkpoints, integrates with MLflow.
"""

import argparse
import json
import logging
import hashlib
import pickle
from pathlib import Path
from datetime import datetime
import numpy as np

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)

try:
    import torch
    TORCH_AVAILABLE = True
except ImportError:
    TORCH_AVAILABLE = False


def parse_args():
    parser = argparse.ArgumentParser(description='Delta checkpointing')
    parser.add_argument('--save', type=str, help='Save checkpoint from model')
    parser.add_argument('--restore', type=str, help='Restore full checkpoint')
    parser.add_argument('--checkpoint_dir', type=str, default='./delta_checkpoints')
    parser.add_argument('--base_checkpoint', type=str, help='Base checkpoint for delta')
    parser.add_argument('--mlflow_tracking', action='store_true')
    return parser.parse_args()


def compute_tensor_hash(tensor):
    """Compute hash of tensor for change detection."""
    if TORCH_AVAILABLE and isinstance(tensor, torch.Tensor):
        data = tensor.detach().cpu().numpy().tobytes()
    else:
        data = np.asarray(tensor).tobytes()
    return hashlib.md5(data).hexdigest()


def save_delta_checkpoint(state_dict, checkpoint_dir, base_checkpoint=None):
    """Save only changed tensors as delta."""
    checkpoint_dir = Path(checkpoint_dir)
    checkpoint_dir.mkdir(parents=True, exist_ok=True)

    # Load base checkpoint hashes
    base_hashes = {}
    if base_checkpoint:
        base_path = checkpoint_dir / base_checkpoint
        if base_path.exists():
            with open(base_path / 'hashes.json') as f:
                base_hashes = json.load(f)

    # Compute current hashes and find changes
    current_hashes = {}
    changed_tensors = {}

    for key, tensor in state_dict.items():
        tensor_hash = compute_tensor_hash(tensor)
        current_hashes[key] = tensor_hash

        if key not in base_hashes or base_hashes[key] != tensor_hash:
            changed_tensors[key] = tensor

    # Create checkpoint directory
    checkpoint_id = datetime.now().strftime('%Y%m%d_%H%M%S')
    ckpt_path = checkpoint_dir / checkpoint_id
    ckpt_path.mkdir(parents=True, exist_ok=True)

    # Save changed tensors
    if TORCH_AVAILABLE:
        torch.save(changed_tensors, ckpt_path / 'delta.pt')
    else:
        with open(ckpt_path / 'delta.pkl', 'wb') as f:
            pickle.dump(changed_tensors, f)

    # Save metadata
    metadata = {
        'checkpoint_id': checkpoint_id,
        'base_checkpoint': base_checkpoint,
        'total_keys': len(state_dict),
        'changed_keys': len(changed_tensors),
        'timestamp': datetime.now().isoformat()
    }

    with open(ckpt_path / 'metadata.json', 'w') as f:
        json.dump(metadata, f, indent=2)

    with open(ckpt_path / 'hashes.json', 'w') as f:
        json.dump(current_hashes, f)

    # Calculate savings
    if TORCH_AVAILABLE:
        full_size = sum(t.numel() * t.element_size() for t in state_dict.values())
        delta_size = sum(t.numel() * t.element_size() for t in changed_tensors.values())
    else:
        full_size = sum(np.asarray(t).nbytes for t in state_dict.values())
        delta_size = sum(np.asarray(t).nbytes for t in changed_tensors.values())

    savings = {
        'full_size_mb': full_size / (1024 * 1024),
        'delta_size_mb': delta_size / (1024 * 1024),
        'savings_percent': round((1 - delta_size / full_size) * 100, 1) if full_size > 0 else 0
    }

    logger.info(f"Saved delta checkpoint: {checkpoint_id}")
    logger.info(f"Changed {len(changed_tensors)}/{len(state_dict)} tensors")
    logger.info(f"Savings: {savings['savings_percent']}%")

    return checkpoint_id, savings


def restore_full_checkpoint(checkpoint_id, checkpoint_dir):
    """Reconstruct full checkpoint from deltas."""
    checkpoint_dir = Path(checkpoint_dir)
    ckpt_path = checkpoint_dir / checkpoint_id

    # Load metadata
    with open(ckpt_path / 'metadata.json') as f:
        metadata = json.load(f)

    # Build chain of checkpoints
    chain = [checkpoint_id]
    current = metadata.get('base_checkpoint')
    while current:
        chain.append(current)
        base_path = checkpoint_dir / current
        if (base_path / 'metadata.json').exists():
            with open(base_path / 'metadata.json') as f:
                meta = json.load(f)
            current = meta.get('base_checkpoint')
        else:
            break

    # Apply deltas in reverse order (oldest first)
    state_dict = {}
    for ckpt_id in reversed(chain):
        ckpt_path = checkpoint_dir / ckpt_id

        if TORCH_AVAILABLE and (ckpt_path / 'delta.pt').exists():
            delta = torch.load(ckpt_path / 'delta.pt')
        elif (ckpt_path / 'delta.pkl').exists():
            with open(ckpt_path / 'delta.pkl', 'rb') as f:
                delta = pickle.load(f)
        else:
            continue

        state_dict.update(delta)

    logger.info(f"Restored checkpoint: {checkpoint_id}")
    logger.info(f"Applied {len(chain)} deltas, {len(state_dict)} total keys")

    return state_dict


def main():
    args = parse_args()

    if args.save:
        # Demo: create synthetic state dict
        if TORCH_AVAILABLE:
            state_dict = {
                f'layer_{i}': torch.randn(100, 100)
                for i in range(10)
            }
        else:
            state_dict = {
                f'layer_{i}': np.random.randn(100, 100)
                for i in range(10)
            }

        checkpoint_id, savings = save_delta_checkpoint(
            state_dict, args.checkpoint_dir, args.base_checkpoint
        )

        # Log to MLflow
        if args.mlflow_tracking:
            try:
                import mlflow
                mlflow.log_metric('checkpoint_savings_percent', savings['savings_percent'])
            except:
                pass

        print(json.dumps(savings, indent=2))

    elif args.restore:
        state_dict = restore_full_checkpoint(args.restore, args.checkpoint_dir)
        print(f"Restored {len(state_dict)} tensors")

    else:
        logger.error("Specify --save or --restore")


if __name__ == '__main__':
    main()
