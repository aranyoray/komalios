#!/usr/bin/env python3
"""
fuse_and_compress.py — SVD/PCA/OPQ compression on multimodal embeddings.

Requirements:
torch, numpy, pandas, scikit-learn, matplotlib, mlflow, tqdm
"""

import os
import json
import hashlib
import logging
import argparse
from pathlib import Path
from datetime import datetime

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from sklearn.decomposition import PCA
from tqdm import tqdm

import torch

try:
    import mlflow
    HAS_MLFLOW = True
except ImportError:
    HAS_MLFLOW = False

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description='Fuse and compress embeddings')
    parser.add_argument('--data_dir', type=str, default='./data')
    parser.add_argument('--out_dir', type=str, default='./outputs/fuse_compress')
    parser.add_argument('--device', type=str, default='cpu')
    parser.add_argument('--n_components', type=int, default=128)
    parser.add_argument('--batch_size', type=int, default=1000)
    parser.add_argument('--synthetic', type=int, default=0)
    parser.add_argument('--dry_run', action='store_true')
    parser.add_argument('--debug', action='store_true')
    parser.add_argument('--n_workers', type=int, default=4)
    parser.add_argument('--max_steps', type=int, default=1000)
    return parser.parse_args()


def generate_synthetic_embeddings(n_samples):
    """Generate synthetic multimodal embeddings."""
    vision = np.random.randn(n_samples, 768).astype(np.float32)
    gaze = np.random.randn(n_samples, 64).astype(np.float32)
    audio = np.random.randn(n_samples, 256).astype(np.float32)
    touch = np.random.randn(n_samples, 32).astype(np.float32)
    return {'vision': vision, 'gaze': gaze, 'audio': audio, 'touch': touch}


def svd_compress(embeddings, n_components):
    """Compress using truncated SVD."""
    U, S, Vt = np.linalg.svd(embeddings, full_matrices=False)
    compressed = U[:, :n_components] @ np.diag(S[:n_components])
    reconstructed = compressed @ Vt[:n_components, :]
    error = np.mean((embeddings - reconstructed) ** 2)
    return compressed, error


def pca_compress(embeddings, n_components):
    """Compress using PCA."""
    pca = PCA(n_components=n_components)
    compressed = pca.fit_transform(embeddings)
    reconstructed = pca.inverse_transform(compressed)
    error = np.mean((embeddings - reconstructed) ** 2)
    return compressed, error, pca


def opq_compress(embeddings, n_components, n_subvectors=8):
    """Optimized Product Quantization compression."""
    # simplified OPQ: rotate then quantize
    pca = PCA(n_components=n_components)
    rotated = pca.fit_transform(embeddings)

    # quantize to centroids
    n_per_sub = n_components // n_subvectors
    quantized = np.zeros_like(rotated)

    for i in range(n_subvectors):
        start = i * n_per_sub
        end = start + n_per_sub
        subvec = rotated[:, start:end]
        # simple k-means quantization (256 centroids)
        centroids = subvec[np.random.choice(len(subvec), 256, replace=False)]
        distances = np.linalg.norm(subvec[:, None] - centroids[None, :], axis=2)
        indices = np.argmin(distances, axis=1)
        quantized[:, start:end] = centroids[indices]

    reconstructed = pca.inverse_transform(quantized)
    error = np.mean((embeddings - reconstructed) ** 2)
    return quantized, error


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
        mlflow.start_run(run_name='fuse_compress')
        mlflow.log_params(vars(args))

    # Load or generate data
    n_samples = args.synthetic if args.synthetic > 0 else 100000
    logger.info(f"processing {n_samples} embeddings")

    embeddings_dict = generate_synthetic_embeddings(n_samples)

    # Fuse multimodal embeddings
    logger.info("fusing multimodal embeddings...")
    fused = np.concatenate([
        embeddings_dict['vision'],
        embeddings_dict['gaze'],
        embeddings_dict['audio'],
        embeddings_dict['touch']
    ], axis=1)

    logger.info(f"fused shape: {fused.shape}")

    results = {}

    if args.dry_run:
        logger.info("dry run mode - skipping compression")
        results = {'svd': 0.1, 'pca': 0.1, 'opq': 0.1}
    else:
        # SVD compression
        logger.info("applying SVD compression...")
        svd_compressed, svd_error = svd_compress(fused, args.n_components)
        results['svd_error'] = float(svd_error)
        np.save(out_dir / 'svd_compressed.npy', svd_compressed)

        # PCA compression
        logger.info("applying PCA compression...")
        pca_compressed, pca_error, pca_model = pca_compress(fused, args.n_components)
        results['pca_error'] = float(pca_error)
        np.save(out_dir / 'pca_compressed.npy', pca_compressed)

        # OPQ compression
        logger.info("applying OPQ compression...")
        opq_compressed, opq_error = opq_compress(fused, args.n_components)
        results['opq_error'] = float(opq_error)
        np.save(out_dir / 'opq_compressed.npy', opq_compressed)

        # Plot reconstruction errors
        fig, ax = plt.subplots(figsize=(10, 6))
        methods = ['SVD', 'PCA', 'OPQ']
        errors = [results['svd_error'], results['pca_error'], results['opq_error']]
        ax.bar(methods, errors, color=['#6366F1', '#8B5CF6', '#EC4899'])
        ax.set_ylabel('Reconstruction MSE')
        ax.set_title('Compression Method Comparison')
        plt.tight_layout()
        plt.savefig(out_dir / 'reconstruction_errors.png', dpi=150)
        plt.close()

    # Save results
    results['n_samples'] = n_samples
    results['original_dim'] = fused.shape[1]
    results['compressed_dim'] = args.n_components

    with open(out_dir / 'compression_results.json', 'w') as f:
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
        mlflow.log_metrics({k: v for k, v in results.items() if isinstance(v, (int, float))})
        mlflow.end_run()

    logger.info(f"compression complete. artifacts saved to {out_dir}")


if __name__ == '__main__':
    main()
