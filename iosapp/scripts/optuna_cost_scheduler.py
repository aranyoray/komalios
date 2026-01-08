#!/usr/bin/env python3
"""
optuna_cost_scheduler.py — Massive Optuna + RayTune cost-aware scheduler.
"""

import argparse
import logging
import json
from pathlib import Path

import numpy as np
import optuna
from optuna.integration import MLflowCallback

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output_dir', type=str, required=True)
    parser.add_argument('--n_trials', type=int, default=3000)
    parser.add_argument('--budget_gpu_hours', type=float, default=1000)
    parser.add_argument('--max_concurrent', type=int, default=10)
    parser.add_argument('--cost_per_gpu_hour', type=float, default=3.0)
    return parser.parse_args()


class CostModel:
    """Estimate GPU-hours and cost for training configs."""

    def estimate_gpu_hours(self, config):
        base_hours = 0.5

        # model size factor
        depth_factor = config.get('depth', 4) / 4
        width_factor = config.get('width', 256) / 256

        # training factor
        steps_factor = config.get('steps', 2000) / 2000
        batch_factor = 32 / config.get('batch_size', 32)

        return base_hours * depth_factor * width_factor * steps_factor * batch_factor

    def estimate_cost(self, config, rate_per_hour):
        return self.estimate_gpu_hours(config) * rate_per_hour


class BudgetAwareScheduler:
    """Schedule trials within GPU-hour budget."""

    def __init__(self, total_budget, rate_per_hour):
        self.total_budget = total_budget
        self.rate_per_hour = rate_per_hour
        self.consumed_hours = 0
        self.cost_model = CostModel()

    def can_schedule(self, config):
        estimated = self.cost_model.estimate_gpu_hours(config)
        return self.consumed_hours + estimated <= self.total_budget

    def record_completion(self, config):
        self.consumed_hours += self.cost_model.estimate_gpu_hours(config)

    def remaining_budget(self):
        return self.total_budget - self.consumed_hours


def objective(trial, scheduler, args):
    """Trial objective with cost awareness."""
    # sample configuration
    config = {
        'task': trial.suggest_categorical('task', ['distillation', 'qat', 'pruning', 'rl']),
        'depth': trial.suggest_int('depth', 2, 12),
        'width': trial.suggest_categorical('width', [128, 256, 384, 512]),
        'lr': trial.suggest_float('lr', 1e-5, 1e-3, log=True),
        'batch_size': trial.suggest_categorical('batch_size', [16, 32, 64]),
        'steps': trial.suggest_int('steps', 1000, 5000),
    }

    # check budget
    if not scheduler.can_schedule(config):
        raise optuna.TrialPruned("budget exceeded")

    # mock training
    import torch
    import torch.nn as nn

    model = nn.Sequential(
        nn.Linear(768, config['width']),
        *[nn.Sequential(nn.ReLU(), nn.Linear(config['width'], config['width']))
          for _ in range(config['depth'] - 1)],
        nn.ReLU(),
        nn.Linear(config['width'], 7),
    )

    optimizer = torch.optim.Adam(model.parameters(), lr=config['lr'])

    for step in range(min(config['steps'], 100)):  # shortened for demo
        x = torch.randn(config['batch_size'], 768)
        y = torch.randint(0, 7, (config['batch_size'],))
        loss = nn.functional.cross_entropy(model(x), y)
        optimizer.zero_grad()
        loss.backward()
        optimizer.step()

    # evaluate
    model.eval()
    with torch.no_grad():
        x = torch.randn(100, 768)
        y = torch.randint(0, 7, (100,))
        accuracy = (model(x).argmax(1) == y).float().mean().item()

    # record completion
    scheduler.record_completion(config)

    return accuracy


def main():
    args = parse_args()
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    # create scheduler
    scheduler = BudgetAwareScheduler(args.budget_gpu_hours, args.cost_per_gpu_hour)

    # create study
    storage = f"sqlite:///{output_dir / 'optuna.db'}"
    study = optuna.create_study(
        study_name='komal_cost_aware',
        storage=storage,
        direction='maximize',
        load_if_exists=True,
    )

    # MLflow callback
    mlflow_callback = MLflowCallback(
        tracking_uri=str(output_dir / 'mlruns'),
        metric_name='accuracy',
    )

    # run optimization
    logger.info(f"starting {args.n_trials} trials with {args.budget_gpu_hours} GPU-hour budget...")

    completed = 0
    while completed < args.n_trials and scheduler.remaining_budget() > 0:
        try:
            study.optimize(
                lambda trial: objective(trial, scheduler, args),
                n_trials=1,
                callbacks=[mlflow_callback],
            )
            completed += 1
        except optuna.TrialPruned:
            logger.info("budget exhausted")
            break

        if completed % 100 == 0:
            logger.info(f"completed {completed} trials, remaining budget: {scheduler.remaining_budget():.1f} GPU-hours")

    # save results
    df = study.trials_dataframe()
    df.to_csv(output_dir / 'trial_results.csv', index=False)

    # generate summary
    summary = {
        'total_trials': completed,
        'consumed_gpu_hours': scheduler.consumed_hours,
        'total_cost': scheduler.consumed_hours * args.cost_per_gpu_hour,
        'best_accuracy': study.best_value,
        'best_params': study.best_params,
    }

    with open(output_dir / 'summary.json', 'w') as f:
        json.dump(summary, f, indent=2)

    logger.info(f"completed {completed} trials")
    logger.info(f"consumed {scheduler.consumed_hours:.1f} GPU-hours (${scheduler.consumed_hours * args.cost_per_gpu_hour:.2f})")
    logger.info(f"best accuracy: {study.best_value:.3f}")


if __name__ == '__main__':
    main()
