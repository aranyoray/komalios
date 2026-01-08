#!/usr/bin/env python3
"""
privacy_feature_hash.py — Hash sensitive features for privacy-preserving ML.
"""

import argparse
import hashlib
import logging
import json
import hmac
from pathlib import Path
from datetime import datetime

import numpy as np
import pandas as pd

try:
    import mlflow
    HAS_MLFLOW = True
except ImportError:
    HAS_MLFLOW = False

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--data_dir', type=str, default='./data')
    parser.add_argument('--out_dir', type=str, default='./outputs/privacy')
    parser.add_argument('--n_samples', type=int, default=10000)
    parser.add_argument('--hash_method', type=str, default='sha256', choices=['sha256', 'blake2b', 'hmac'])
    parser.add_argument('--salt', type=str, default='komal_salt_2024')
    parser.add_argument('--synthetic', type=int, default=0)
    parser.add_argument('--dry_run', action='store_true')
    parser.add_argument('--debug', action='store_true')
    return parser.parse_args()


def generate_synthetic_pii(n_samples):
    """Generate synthetic PII data."""
    data = {
        'child_id': [f'child_{i:06d}' for i in range(n_samples)],
        'name': [f'Name_{i}' for i in range(n_samples)],
        'age': np.random.randint(3, 16, n_samples),
        'school': [f'School_{np.random.randint(0, 100)}' for _ in range(n_samples)],
        'device_id': [f'device_{np.random.randint(0, 1000):04d}' for _ in range(n_samples)],
        'embedding': [np.random.randn(128).tolist() for _ in range(n_samples)],
    }
    return pd.DataFrame(data)


def hash_value(value, method, salt):
    """Hash a single value."""
    value_bytes = str(value).encode('utf-8')
    salt_bytes = salt.encode('utf-8')

    if method == 'sha256':
        return hashlib.sha256(salt_bytes + value_bytes).hexdigest()
    elif method == 'blake2b':
        return hashlib.blake2b(value_bytes, key=salt_bytes[:64].ljust(64, b'\x00')).hexdigest()
    elif method == 'hmac':
        return hmac.new(salt_bytes, value_bytes, hashlib.sha256).hexdigest()

    return hashlib.sha256(value_bytes).hexdigest()


def hash_embedding(embedding, method, salt):
    """Hash embedding vector while preserving similarity."""
    # Use locality-sensitive hashing concept
    embedding = np.array(embedding)
    random_state = np.random.RandomState(int(hashlib.md5(salt.encode()).hexdigest(), 16) % 2**32)

    # random projection
    n_hashes = 64
    projections = random_state.randn(len(embedding), n_hashes)
    projected = np.dot(embedding, projections)

    # sign hash
    return ''.join(['1' if x > 0 else '0' for x in projected])


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
        mlflow.start_run(run_name='privacy_hash')
        mlflow.log_params(vars(args))

    n_samples = args.synthetic if args.synthetic > 0 else args.n_samples
    df = generate_synthetic_pii(n_samples)

    sensitive_columns = ['child_id', 'name', 'school', 'device_id']

    if args.dry_run:
        logger.info("dry run mode")
        hashed_df = df.copy()
        for col in sensitive_columns:
            hashed_df[f'{col}_hashed'] = 'hashed_placeholder'
    else:
        logger.info(f"hashing {len(sensitive_columns)} sensitive columns...")
        hashed_df = df.copy()

        for col in sensitive_columns:
            logger.info(f"  hashing {col}...")
            hashed_df[f'{col}_hashed'] = hashed_df[col].apply(
                lambda x: hash_value(x, args.hash_method, args.salt)
            )
            hashed_df = hashed_df.drop(columns=[col])

        # Hash embeddings
        logger.info("  hashing embeddings...")
        hashed_df['embedding_lsh'] = hashed_df['embedding'].apply(
            lambda x: hash_embedding(x, args.hash_method, args.salt)
        )
        hashed_df = hashed_df.drop(columns=['embedding'])

    # Save hashed data
    hashed_df.to_parquet(out_dir / 'hashed_data.parquet', index=False)

    results = {
        'n_samples': n_samples,
        'hash_method': args.hash_method,
        'columns_hashed': sensitive_columns + ['embedding'],
        'output_columns': list(hashed_df.columns),
    }

    with open(out_dir / 'privacy_results.json', 'w') as f:
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

    logger.info(f"privacy hashing complete. saved to {out_dir}")


if __name__ == '__main__':
    main()
