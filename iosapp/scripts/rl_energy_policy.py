#!/usr/bin/env python3
"""
rl_energy_policy.py — RL reward shaping & energy-aware policy training.
"""

import argparse
import logging
import json
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.distributions import Categorical
from tqdm import tqdm

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output_dir', type=str, required=True)
    parser.add_argument('--num_envs', type=int, default=10000)
    parser.add_argument('--total_steps', type=int, default=50000000)
    parser.add_argument('--energy_lambda', type=float, default=0.1)
    parser.add_argument('--lr', type=float, default=3e-4)
    parser.add_argument('--gamma', type=float, default=0.99)
    parser.add_argument('--gae_lambda', type=float, default=0.95)
    parser.add_argument('--clip_epsilon', type=float, default=0.2)
    parser.add_argument('--entropy_coef', type=float, default=0.01)
    return parser.parse_args()


class ChildEnvironment:
    """Simulated child interaction environment."""

    def __init__(self, sensitivity='medium'):
        self.sensitivity = sensitivity
        self.state_dim = 32
        self.action_dim = 8
        self.reset()

    def reset(self):
        self.attention = np.random.uniform(0.3, 0.7)
        self.affect = np.random.uniform(-0.5, 0.5)
        self.frustration = 0.0
        self.step_count = 0
        return self._get_state()

    def _get_state(self):
        state = np.zeros(self.state_dim, dtype=np.float32)
        state[0] = self.attention
        state[1] = self.affect
        state[2] = self.frustration
        state[3] = self.step_count / 100
        state[4:] = np.random.randn(self.state_dim - 4) * 0.1
        return state

    def step(self, action):
        # action effects
        action_effects = {
            0: (0.1, 0.05, -0.05),   # encourage
            1: (-0.05, 0.1, -0.1),   # comfort
            2: (0.05, 0.0, 0.1),     # challenge
            3: (0.0, -0.1, -0.05),   # pause
            4: (0.15, 0.0, 0.15),    # reward
            5: (-0.1, 0.05, -0.1),   # simplify
            6: (0.0, 0.15, 0.0),     # celebrate
            7: (0.05, 0.05, 0.05),   # neutral
        }

        d_att, d_aff, d_frust = action_effects.get(action, (0, 0, 0))

        # apply sensitivity modifier
        if self.sensitivity == 'high':
            d_att *= 1.5
            d_frust *= 1.5
        elif self.sensitivity == 'low':
            d_att *= 0.7
            d_frust *= 0.5

        self.attention = np.clip(self.attention + d_att + np.random.randn() * 0.05, 0, 1)
        self.affect = np.clip(self.affect + d_aff + np.random.randn() * 0.05, -1, 1)
        self.frustration = np.clip(self.frustration + d_frust + np.random.randn() * 0.05, 0, 1)
        self.step_count += 1

        # reward: attention recovery + affect regulation - frustration
        sel_reward = (self.attention - 0.5) + (self.affect + 0.5) * 0.5 - self.frustration

        # energy cost per action
        energy_costs = [0.5, 0.3, 0.8, 0.1, 1.0, 0.4, 0.9, 0.2]
        energy_cost = energy_costs[action]

        done = self.step_count >= 100 or self.frustration > 0.9

        return self._get_state(), sel_reward, energy_cost, done


class PPOPolicy(nn.Module):
    """PPO policy network."""

    def __init__(self, state_dim, action_dim):
        super().__init__()
        self.shared = nn.Sequential(
            nn.Linear(state_dim, 128),
            nn.ReLU(),
            nn.Linear(128, 128),
            nn.ReLU(),
        )
        self.actor = nn.Linear(128, action_dim)
        self.critic = nn.Linear(128, 1)

    def forward(self, x):
        features = self.shared(x)
        return self.actor(features), self.critic(features)

    def get_action(self, state):
        logits, value = self.forward(state)
        dist = Categorical(logits=logits)
        action = dist.sample()
        return action, dist.log_prob(action), value


def compute_gae(rewards, values, dones, gamma, gae_lambda):
    """Compute generalized advantage estimation."""
    advantages = []
    gae = 0

    for t in reversed(range(len(rewards))):
        if t == len(rewards) - 1:
            next_value = 0
        else:
            next_value = values[t + 1]

        delta = rewards[t] + gamma * next_value * (1 - dones[t]) - values[t]
        gae = delta + gamma * gae_lambda * (1 - dones[t]) * gae
        advantages.insert(0, gae)

    return torch.tensor(advantages, dtype=torch.float32)


def main():
    args = parse_args()
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')

    # create environments
    envs = [
        ChildEnvironment(sensitivity=np.random.choice(['low', 'medium', 'high']))
        for _ in range(args.num_envs)
    ]

    # create policy
    policy = PPOPolicy(state_dim=32, action_dim=8).to(device)
    optimizer = torch.optim.Adam(policy.parameters(), lr=args.lr)

    # metrics
    metrics = {
        'steps': [],
        'sel_reward': [],
        'energy_cost': [],
        'entropy': [],
    }

    # training loop
    total_steps = 0
    checkpoint_interval = args.total_steps // 10

    # curriculum difficulty
    difficulty = 0.0

    logger.info(f"starting PPO training for {args.total_steps} steps...")

    while total_steps < args.total_steps:
        # collect rollouts
        states, actions, rewards, values, log_probs, dones = [], [], [], [], [], []

        for env in envs[:100]:  # sample subset
            state = env.reset()
            done = False

            while not done:
                state_tensor = torch.FloatTensor(state).unsqueeze(0).to(device)
                with torch.no_grad():
                    action, log_prob, value = policy.get_action(state_tensor)

                next_state, sel_reward, energy_cost, done = env.step(action.item())

                # compound reward
                reward = sel_reward - args.energy_lambda * energy_cost

                # curriculum bonus
                if sel_reward > 0.5:
                    reward += difficulty * 0.1

                states.append(state)
                actions.append(action.item())
                rewards.append(reward)
                values.append(value.item())
                log_probs.append(log_prob.item())
                dones.append(float(done))

                state = next_state
                total_steps += 1

        # convert to tensors
        states_t = torch.FloatTensor(np.array(states)).to(device)
        actions_t = torch.LongTensor(actions).to(device)
        old_log_probs_t = torch.FloatTensor(log_probs).to(device)
        values_t = torch.FloatTensor(values)
        rewards_t = torch.FloatTensor(rewards)
        dones_t = torch.FloatTensor(dones)

        # compute advantages
        advantages = compute_gae(rewards_t, values_t, dones_t, args.gamma, args.gae_lambda)
        returns = advantages + values_t

        # normalize advantages
        advantages = (advantages - advantages.mean()) / (advantages.std() + 1e-8)

        # PPO update
        for _ in range(4):
            logits, values_new = policy(states_t)
            dist = Categorical(logits=logits)
            log_probs_new = dist.log_prob(actions_t)

            # policy loss
            ratio = torch.exp(log_probs_new - old_log_probs_t)
            surr1 = ratio * advantages.to(device)
            surr2 = torch.clamp(ratio, 1 - args.clip_epsilon, 1 + args.clip_epsilon) * advantages.to(device)
            policy_loss = -torch.min(surr1, surr2).mean()

            # value loss
            value_loss = F.mse_loss(values_new.squeeze(), returns.to(device))

            # entropy bonus
            entropy = dist.entropy().mean()

            loss = policy_loss + 0.5 * value_loss - args.entropy_coef * entropy

            optimizer.zero_grad()
            loss.backward()
            optimizer.step()

        # update metrics
        avg_reward = np.mean(rewards)
        avg_energy = args.energy_lambda * np.mean([r for r in rewards])

        metrics['steps'].append(total_steps)
        metrics['sel_reward'].append(avg_reward)
        metrics['energy_cost'].append(avg_energy)
        metrics['entropy'].append(entropy.item())

        # update curriculum
        if avg_reward > 0.3:
            difficulty = min(1.0, difficulty + 0.01)

        # logging
        if total_steps % 100000 < 1000:
            logger.info(f"steps: {total_steps} | reward: {avg_reward:.3f} | entropy: {entropy.item():.3f}")

        # checkpoint
        if total_steps % checkpoint_interval < 1000:
            ckpt_path = output_dir / f'policy_{total_steps}.pt'
            torch.save(policy.state_dict(), ckpt_path)
            logger.info(f"saved checkpoint to {ckpt_path}")

    # save final policy
    torch.save(policy.state_dict(), output_dir / 'policy_final.pt')

    # save metrics
    import pandas as pd
    pd.DataFrame(metrics).to_csv(output_dir / 'training_metrics.csv', index=False)

    logger.info(f"training complete. saved to {output_dir}")


if __name__ == '__main__':
    main()
