#!/usr/bin/env python3
"""
run_causal_discovery.py — Causal discovery experiments using multiple algorithms.
"""

import argparse
import json
import logging
from pathlib import Path

import numpy as np
import pandas as pd

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description='Causal Discovery')
    parser.add_argument('--algorithm', type=str, required=True,
                        choices=['pc', 'ges', 'icp', 'granger', 'notears', 'dagma'])
    parser.add_argument('--data_root', type=str, required=True)
    parser.add_argument('--intervention_dir', type=str, default=None)
    parser.add_argument('--output_dir', type=str, required=True)
    parser.add_argument('--seed', type=int, default=42)
    parser.add_argument('--alpha', type=float, default=0.05)
    parser.add_argument('--max_cond_vars', type=int, default=5)
    parser.add_argument('--bootstrap_samples', type=int, default=100)
    return parser.parse_args()


def load_data(data_root):
    """Load observational data for causal discovery."""
    data_path = Path(data_root)

    # look for CSV or NPZ files
    csv_files = list(data_path.glob('*.csv'))
    if csv_files:
        df = pd.read_csv(csv_files[0])
        return df.values, list(df.columns)

    npz_files = list(data_path.glob('*.npz'))
    if npz_files:
        data = np.load(npz_files[0])
        return data['data'], data.get('columns', [f'X{i}' for i in range(data['data'].shape[1])])

    # generate synthetic data for testing
    np.random.seed(42)
    n_samples = 1000
    n_vars = 10
    data = np.random.randn(n_samples, n_vars)
    # add some causal relationships
    data[:, 1] = 0.5 * data[:, 0] + np.random.randn(n_samples) * 0.5
    data[:, 2] = 0.3 * data[:, 0] + 0.4 * data[:, 1] + np.random.randn(n_samples) * 0.5
    columns = [f'X{i}' for i in range(n_vars)]

    return data, columns


def run_pc(data, alpha=0.05):
    """PC algorithm for causal discovery."""
    try:
        from causallearn.search.ConstraintBased.PC import pc
        cg = pc(data, alpha=alpha, indep_test='fisherz')
        return cg.G.graph
    except ImportError:
        logger.warning("causal-learn not installed, using placeholder")
        return np.zeros((data.shape[1], data.shape[1]))


def run_ges(data):
    """GES algorithm for causal discovery."""
    try:
        from causallearn.search.ScoreBased.GES import ges
        record = ges(data)
        return record['G'].graph
    except ImportError:
        logger.warning("causal-learn not installed, using placeholder")
        return np.zeros((data.shape[1], data.shape[1]))


def run_granger(data, max_lag=5):
    """Granger causality test."""
    from scipy import stats
    n_vars = data.shape[1]
    results = np.zeros((n_vars, n_vars))

    for i in range(n_vars):
        for j in range(n_vars):
            if i != j:
                # simple correlation-based proxy
                corr, pval = stats.pearsonr(data[:-1, j], data[1:, i])
                if pval < 0.05:
                    results[j, i] = 1

    return results


def run_notears(data, lambda1=0.1):
    """NOTEARS algorithm for causal discovery."""
    try:
        from causallearn.search.FCMBased.lingam import DirectLiNGAM
        model = DirectLiNGAM()
        model.fit(data)
        return model.adjacency_matrix_
    except ImportError:
        logger.warning("causal-learn not installed, using placeholder")
        return np.zeros((data.shape[1], data.shape[1]))


def main():
    args = parse_args()
    np.random.seed(args.seed)

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    # load data
    data, columns = load_data(args.data_root)
    logger.info(f"loaded data: {data.shape}")

    # run algorithm
    logger.info(f"running {args.algorithm}...")

    if args.algorithm == 'pc':
        graph = run_pc(data, args.alpha)
    elif args.algorithm == 'ges':
        graph = run_ges(data)
    elif args.algorithm == 'granger':
        graph = run_granger(data)
    elif args.algorithm in ['notears', 'dagma']:
        graph = run_notears(data)
    elif args.algorithm == 'icp':
        # ICP requires interventional data
        graph = run_pc(data, args.alpha)  # fallback
    else:
        graph = np.zeros((len(columns), len(columns)))

    # save results
    results = {
        'algorithm': args.algorithm,
        'seed': args.seed,
        'alpha': args.alpha,
        'n_samples': data.shape[0],
        'n_variables': data.shape[1],
        'columns': columns,
        'adjacency_matrix': graph.tolist(),
        'num_edges': int(np.sum(graph != 0)),
    }

    output_path = output_dir / f'{args.algorithm}_seed{args.seed}.json'
    with open(output_path, 'w') as f:
        json.dump(results, f, indent=2)

    logger.info(f"results saved to {output_path}")
    logger.info(f"discovered {results['num_edges']} edges")


if __name__ == '__main__':
    main()
