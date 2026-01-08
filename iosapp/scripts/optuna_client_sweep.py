#!/usr/bin/env python3
"""
optuna_client_sweep.py — Optuna hyperparameter sweep for lightweight models.
"""

import os
import argparse
import logging
import json
from pathlib import Path

import numpy as np
import optuna
from optuna.integration import MLflowCallback

import torch
import torch.nn as nn

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--n_trials', type=int, default=1500)
    parser.add_argument('--output_dir', type=str, required=True)
    parser.add_argument('--max_gflops', type=float, default=1.0)
    parser.add_argument('--train_steps', type=int, default=2000)
    parser.add_argument('--n_jobs', type=int, default=4)
    parser.add_argument('--storage', type=str, default=None)
    parser.add_argument('--study_name', type=str, default='komal_client_sweep')
    parser.add_argument('--s3_bucket', type=str, default=None)
    return parser.parse_args()


def estimate_gflops(depth, width, heads):
    """Estimate model GFLOPs."""
    seq_len = 256
    # attention: 4 * seq^2 * dim
    # ffn: 2 * seq * dim * 4dim
    attn_flops = 4 * seq_len ** 2 * width * depth
    ffn_flops = 2 * seq_len * width * width * 4 * depth
    return (attn_flops + ffn_flops) / 1e9


def create_model(depth, width, heads):
    """Create student model with given config."""
    encoder_layer = nn.TransformerEncoderLayer(width, heads, width * 4, batch_first=True)
    model = nn.Sequential(
        nn.Linear(768, width),
        nn.TransformerEncoder(encoder_layer, depth),
        nn.Linear(width, 7),
    )
    return model


def objective(trial, args):
    """Optuna objective function."""
    # sample hyperparameters
    depth = trial.suggest_int('depth', 2, 8)
    width = trial.suggest_categorical('width', [128, 256, 384, 512])
    heads = trial.suggest_categorical('heads', [2, 4, 8])
    lr = trial.suggest_float('lr', 1e-5, 1e-3, log=True)
    temperature = trial.suggest_float('temperature', 1.0, 10.0)
    qat_epochs = trial.suggest_int('qat_epochs', 0, 5)

    # check resource constraints
    gflops = estimate_gflops(depth, width, heads)
    if gflops > args.max_gflops:
        raise optuna.TrialPruned(f"GFLOPs {gflops:.2f} > {args.max_gflops}")

    # create model
    model = create_model(depth, width, heads)
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    model = model.to(device)

    optimizer = torch.optim.AdamW(model.parameters(), lr=lr)

    # mock training
    model.train()
    for step in range(args.train_steps):
        x = torch.randn(32, 256, 768).to(device)
        y = torch.randint(0, 7, (32,)).to(device)

        logits = model(x).mean(1)
        loss = nn.functional.cross_entropy(logits, y)

        optimizer.zero_grad()
        loss.backward()
        optimizer.step()

        # report intermediate
        if step % 500 == 0:
            trial.report(loss.item(), step)
            if trial.should_prune():
                raise optuna.TrialPruned()

    # evaluate
    model.eval()
    with torch.no_grad():
        x = torch.randn(100, 256, 768).to(device)
        y = torch.randint(0, 7, (100,)).to(device)
        logits = model(x).mean(1)
        accuracy = (logits.argmax(1) == y).float().mean().item()

    # mock latency and energy
    latency = 0.001 * depth * width / 128  # ms
    energy = 0.1 * gflops  # mJ

    # composite score
    score = 0.6 * accuracy - 0.3 * latency - 0.1 * energy

    return score


def main():
    args = parse_args()
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    # create study
    storage = args.storage or f"sqlite:///{output_dir / 'optuna.db'}"
    study = optuna.create_study(
        study_name=args.study_name,
        storage=storage,
        direction='maximize',
        load_if_exists=True,
        pruner=optuna.pruners.MedianPruner(),
    )

    # MLflow callback
    mlflow_callback = MLflowCallback(
        tracking_uri=str(output_dir / 'mlruns'),
        metric_name='score',
    )

    # run optimization
    logger.info(f"starting {args.n_trials} trials...")
    study.optimize(
        lambda trial: objective(trial, args),
        n_trials=args.n_trials,
        n_jobs=args.n_jobs,
        callbacks=[mlflow_callback],
        show_progress_bar=True,
    )

    # save best trials
    best_trials = study.trials_dataframe().nlargest(20, 'value')
    best_trials.to_csv(output_dir / 'best_trials.csv', index=False)

    # save all trials
    study.trials_dataframe().to_csv(output_dir / 'all_trials.csv', index=False)

    logger.info(f"best score: {study.best_value:.4f}")
    logger.info(f"best params: {study.best_params}")


if __name__ == '__main__':
    main()
