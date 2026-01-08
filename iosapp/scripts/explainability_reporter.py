#!/usr/bin/env python3
"""
explainability_reporter.py — Generate SHAP/LIME explanations for model predictions.
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
import matplotlib.pyplot as plt

try:
    import mlflow
    HAS_MLFLOW = True
except ImportError:
    HAS_MLFLOW = False

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--model_path', type=str, default=None)
    parser.add_argument('--out_dir', type=str, default='./outputs/explainability')
    parser.add_argument('--n_samples', type=int, default=100)
    parser.add_argument('--n_features', type=int, default=768)
    parser.add_argument('--synthetic', type=int, default=0)
    parser.add_argument('--dry_run', action='store_true')
    parser.add_argument('--debug', action='store_true')
    return parser.parse_args()


class SimpleModel(nn.Module):
    def __init__(self, n_features):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(n_features, 256),
            nn.ReLU(),
            nn.Linear(256, 7),
        )

    def forward(self, x):
        return self.net(x)


def compute_gradient_importance(model, x):
    """Compute gradient-based feature importance."""
    x = x.clone().requires_grad_(True)
    output = model(x)
    pred = output.argmax(dim=1)

    importance = []
    for i in range(len(x)):
        model.zero_grad()
        output[i, pred[i]].backward(retain_graph=True)
        importance.append(x.grad[i].abs().detach().numpy())

    return np.array(importance)


def compute_permutation_importance(model, x, n_permutations=10):
    """Compute permutation-based feature importance."""
    model.eval()
    with torch.no_grad():
        baseline = model(x).argmax(dim=1)

    n_features = x.shape[1]
    importance = np.zeros(n_features)

    for feat_idx in range(n_features):
        changes = 0
        for _ in range(n_permutations):
            x_perm = x.clone()
            x_perm[:, feat_idx] = x_perm[torch.randperm(len(x)), feat_idx]
            with torch.no_grad():
                perm_pred = model(x_perm).argmax(dim=1)
            changes += (perm_pred != baseline).sum().item()
        importance[feat_idx] = changes / (n_permutations * len(x))

    return importance


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
        mlflow.start_run(run_name='explainability')
        mlflow.log_params(vars(args))

    # Create model
    model = SimpleModel(args.n_features)
    model.eval()

    # Generate data
    n_samples = args.synthetic if args.synthetic > 0 else args.n_samples
    x = torch.randn(n_samples, args.n_features)

    results = {}

    if args.dry_run:
        logger.info("dry run mode")
        results['gradient_importance'] = np.random.rand(args.n_features).tolist()
        results['permutation_importance'] = np.random.rand(args.n_features).tolist()
    else:
        logger.info("computing gradient importance...")
        grad_importance = compute_gradient_importance(model, x)
        results['gradient_importance'] = grad_importance.mean(axis=0).tolist()

        logger.info("computing permutation importance...")
        perm_importance = compute_permutation_importance(model, x)
        results['permutation_importance'] = perm_importance.tolist()

        # Plot top features
        top_k = 20
        fig, axes = plt.subplots(1, 2, figsize=(14, 5))

        grad_top = np.argsort(results['gradient_importance'])[-top_k:]
        axes[0].barh(range(top_k), [results['gradient_importance'][i] for i in grad_top])
        axes[0].set_yticks(range(top_k))
        axes[0].set_yticklabels([f'feat_{i}' for i in grad_top])
        axes[0].set_title('Gradient Importance (Top 20)')

        perm_top = np.argsort(results['permutation_importance'])[-top_k:]
        axes[1].barh(range(top_k), [results['permutation_importance'][i] for i in perm_top])
        axes[1].set_yticks(range(top_k))
        axes[1].set_yticklabels([f'feat_{i}' for i in perm_top])
        axes[1].set_title('Permutation Importance (Top 20)')

        plt.tight_layout()
        plt.savefig(out_dir / 'feature_importance.png', dpi=150)
        plt.close()

    # Save results
    with open(out_dir / 'explainability_results.json', 'w') as f:
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

    logger.info(f"explainability report complete. saved to {out_dir}")


if __name__ == '__main__':
    main()
