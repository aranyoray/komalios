#!/usr/bin/env python3
"""
client_curriculum_rl.py — RL-based curriculum learning for adaptive difficulty.
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
import torch.nn.functional as F
from torch.distributions import Categorical

try:
    import mlflow
    HAS_MLFLOW = True
except ImportError:
    HAS_MLFLOW = False

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out_dir', type=str, default='./outputs/curriculum_rl')
    parser.add_argument('--n_episodes', type=int, default=1000)
    parser.add_argument('--max_steps', type=int, default=100)
    parser.add_argument('--lr', type=float, default=3e-4)
    parser.add_argument('--gamma', type=float, default=0.99)
    parser.add_argument('--synthetic', type=int, default=0)
    parser.add_argument('--dry_run', action='store_true')
    parser.add_argument('--debug', action='store_true')
    return parser.parse_args()


class LearnerEnv:
    """Simulated learner environment."""

    def __init__(self):
        self.ability = np.random.uniform(0.3, 0.7)
        self.frustration = 0.0
        self.engagement = 0.5
        self.reset()

    def reset(self):
        self.step_count = 0
        self.frustration = 0.0
        self.engagement = 0.5
        return self._get_state()

    def _get_state(self):
        return np.array([
            self.ability, self.frustration, self.engagement,
            self.step_count / 100
        ], dtype=np.float32)

    def step(self, difficulty):
        # difficulty: 0-4 (very easy to very hard)
        difficulty_level = difficulty / 4.0

        # success probability
        gap = difficulty_level - self.ability
        success_prob = 1 / (1 + np.exp(5 * gap))
        success = np.random.rand() < success_prob

        # update state
        if success:
            self.ability = min(1.0, self.ability + 0.01)
            self.engagement = min(1.0, self.engagement + 0.05)
            self.frustration = max(0.0, self.frustration - 0.05)
            reward = 1.0
        else:
            self.frustration = min(1.0, self.frustration + 0.1)
            self.engagement = max(0.0, self.engagement - 0.03)
            reward = -0.5

        # zone of proximal development bonus
        if abs(gap) < 0.15:
            reward += 0.5

        self.step_count += 1
        done = self.step_count >= 100 or self.frustration > 0.8

        return self._get_state(), reward, done


class CurriculumPolicy(nn.Module):
    def __init__(self, state_dim=4, n_actions=5):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(state_dim, 64),
            nn.ReLU(),
            nn.Linear(64, 64),
            nn.ReLU(),
        )
        self.actor = nn.Linear(64, n_actions)
        self.critic = nn.Linear(64, 1)

    def forward(self, x):
        features = self.net(x)
        return self.actor(features), self.critic(features)


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
        mlflow.start_run(run_name='curriculum_rl')
        mlflow.log_params(vars(args))

    n_episodes = args.synthetic if args.synthetic > 0 else args.n_episodes

    results = {'episode_rewards': [], 'episode_lengths': []}

    if args.dry_run:
        logger.info("dry run mode")
        results['episode_rewards'] = [10.0] * 100
        results['episode_lengths'] = [50] * 100
        results['final_reward'] = 15.0
    else:
        policy = CurriculumPolicy()
        optimizer = torch.optim.Adam(policy.parameters(), lr=args.lr)

        logger.info(f"training curriculum policy for {n_episodes} episodes...")

        for episode in range(n_episodes):
            env = LearnerEnv()
            state = env.reset()

            states, actions, rewards, log_probs, values = [], [], [], [], []
            done = False

            while not done:
                state_t = torch.FloatTensor(state).unsqueeze(0)
                logits, value = policy(state_t)
                dist = Categorical(logits=logits)
                action = dist.sample()

                next_state, reward, done = env.step(action.item())

                states.append(state)
                actions.append(action.item())
                rewards.append(reward)
                log_probs.append(dist.log_prob(action))
                values.append(value)

                state = next_state

            # compute returns
            returns = []
            R = 0
            for r in reversed(rewards):
                R = r + args.gamma * R
                returns.insert(0, R)
            returns = torch.FloatTensor(returns)

            # normalize
            returns = (returns - returns.mean()) / (returns.std() + 1e-8)

            # update policy
            values_t = torch.cat(values).squeeze()
            log_probs_t = torch.stack(log_probs)
            advantages = returns - values_t.detach()

            policy_loss = -(log_probs_t * advantages).mean()
            value_loss = F.mse_loss(values_t, returns)
            loss = policy_loss + 0.5 * value_loss

            optimizer.zero_grad()
            loss.backward()
            optimizer.step()

            episode_reward = sum(rewards)
            results['episode_rewards'].append(episode_reward)
            results['episode_lengths'].append(len(rewards))

            if (episode + 1) % 100 == 0:
                avg_reward = np.mean(results['episode_rewards'][-100:])
                logger.info(f"episode {episode+1}, avg_reward: {avg_reward:.2f}")

        results['final_reward'] = float(np.mean(results['episode_rewards'][-100:]))

        # Save policy
        torch.save(policy.state_dict(), out_dir / 'curriculum_policy.pt')

    # Save results
    with open(out_dir / 'curriculum_results.json', 'w') as f:
        json.dump({
            'n_episodes': n_episodes,
            'final_reward': results.get('final_reward', 0),
            'avg_length': float(np.mean(results['episode_lengths'])),
        }, f, indent=2)

    # Save training curve
    pd.DataFrame({
        'episode': range(len(results['episode_rewards'])),
        'reward': results['episode_rewards'],
        'length': results['episode_lengths'],
    }).to_csv(out_dir / 'training_curve.csv', index=False)

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
        mlflow.log_metric('final_reward', results.get('final_reward', 0))
        mlflow.end_run()

    logger.info(f"curriculum RL complete. saved to {out_dir}")


if __name__ == '__main__':
    main()
