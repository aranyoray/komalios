#!/usr/bin/env python3
"""
mm_fusion_distill.py — Multi-modal fusion distillation with token-cost optimization.
"""

import argparse
import logging
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.cuda.amp import GradScaler, autocast
from tqdm import tqdm

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output_dir', type=str, required=True)
    parser.add_argument('--num_dialogues', type=int, default=500000)
    parser.add_argument('--batch_size', type=int, default=64)
    parser.add_argument('--epochs', type=int, default=10)
    parser.add_argument('--lr', type=float, default=1e-4)
    parser.add_argument('--token_cost_lambda', type=float, default=0.1)
    parser.add_argument('--ppo_epochs', type=int, default=4)
    parser.add_argument('--fp16', action='store_true')
    parser.add_argument('--num_gpus', type=int, default=1)
    return parser.parse_args()


class CrossModalFusion(nn.Module):
    """Cross-modal fusion student model."""

    def __init__(self, visual_dim=768, gaze_dim=5, text_dim=256, hidden_dim=256):
        super().__init__()
        self.visual_proj = nn.Linear(visual_dim, hidden_dim)
        self.gaze_proj = nn.Linear(gaze_dim, hidden_dim)
        self.text_proj = nn.Linear(text_dim, hidden_dim)

        self.fusion = nn.TransformerEncoder(
            nn.TransformerEncoderLayer(hidden_dim, 4, hidden_dim * 4, batch_first=True),
            num_layers=4
        )

        self.output_proj = nn.Linear(hidden_dim, 128)
        self.token_predictor = nn.Linear(hidden_dim, 1)

    def forward(self, visual, gaze, text):
        v = self.visual_proj(visual)
        g = self.gaze_proj(gaze)
        t = self.text_proj(text)

        # concatenate modalities
        x = torch.stack([v, g, t], dim=1)
        x = self.fusion(x)

        pooled = x.mean(1)
        embedding = self.output_proj(pooled)
        token_count = F.softplus(self.token_predictor(pooled))

        return embedding, token_count


class PPOAgent:
    """PPO for token-cost optimization."""

    def __init__(self, model, lr=3e-4, clip_epsilon=0.2):
        self.model = model
        self.optimizer = torch.optim.Adam(model.parameters(), lr=lr)
        self.clip_epsilon = clip_epsilon

    def compute_returns(self, rewards, gamma=0.99):
        returns = []
        R = 0
        for r in reversed(rewards):
            R = r + gamma * R
            returns.insert(0, R)
        return torch.tensor(returns)

    def update(self, states, actions, old_log_probs, returns, advantages):
        # simplified PPO update
        for _ in range(4):
            # forward pass
            _, token_counts = self.model(*states)
            log_probs = -token_counts.squeeze()

            # PPO loss
            ratio = torch.exp(log_probs - old_log_probs)
            surr1 = ratio * advantages
            surr2 = torch.clamp(ratio, 1 - self.clip_epsilon, 1 + self.clip_epsilon) * advantages
            policy_loss = -torch.min(surr1, surr2).mean()

            self.optimizer.zero_grad()
            policy_loss.backward()
            self.optimizer.step()


def generate_synthetic_dialogues(num_dialogues):
    """Generate synthetic multimodal dialogue data."""
    visual = torch.randn(num_dialogues, 768)
    gaze = torch.randn(num_dialogues, 5)
    text = torch.randn(num_dialogues, 256)
    target_embeddings = torch.randn(num_dialogues, 128)
    target_tokens = torch.randint(10, 100, (num_dialogues, 1)).float()
    return visual, gaze, text, target_embeddings, target_tokens


def main():
    args = parse_args()
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')

    # create model
    model = CrossModalFusion().to(device)
    ppo_agent = PPOAgent(model, lr=args.lr)

    # generate data
    logger.info(f"generating {args.num_dialogues} dialogues...")
    visual, gaze, text, target_emb, target_tokens = generate_synthetic_dialogues(args.num_dialogues)

    dataset = torch.utils.data.TensorDataset(visual, gaze, text, target_emb, target_tokens)
    loader = torch.utils.data.DataLoader(dataset, batch_size=args.batch_size, shuffle=True)

    scaler = GradScaler() if args.fp16 else None
    optimizer = torch.optim.AdamW(model.parameters(), lr=args.lr)

    # training loop
    token_cost_curve = []

    for epoch in range(args.epochs):
        model.train()
        total_loss = 0
        total_token_cost = 0

        for v, g, t, target_e, target_t in tqdm(loader, desc=f'epoch {epoch}'):
            v, g, t = v.to(device), g.to(device), t.to(device)
            target_e, target_t = target_e.to(device), target_t.to(device)

            with autocast(enabled=args.fp16):
                embedding, token_count = model(v, g, t)

                # embedding loss
                emb_loss = F.mse_loss(embedding, target_e)

                # token cost penalty
                token_loss = F.l1_loss(token_count, target_t)

                loss = emb_loss + args.token_cost_lambda * token_loss

            optimizer.zero_grad()
            if scaler:
                scaler.scale(loss).backward()
                scaler.step(optimizer)
                scaler.update()
            else:
                loss.backward()
                optimizer.step()

            total_loss += loss.item()
            total_token_cost += token_count.mean().item()

        avg_loss = total_loss / len(loader)
        avg_tokens = total_token_cost / len(loader)
        token_cost_curve.append({'epoch': epoch, 'loss': avg_loss, 'avg_tokens': avg_tokens})

        logger.info(f"epoch {epoch} | loss: {avg_loss:.4f} | avg_tokens: {avg_tokens:.1f}")

        # save checkpoint
        if epoch % 5 == 0:
            torch.save(model.state_dict(), output_dir / f'checkpoint_{epoch}.pt')

    # save final model
    torch.save(model.state_dict(), output_dir / 'fusion_model.pt')

    # save token-cost curve
    import pandas as pd
    pd.DataFrame(token_cost_curve).to_csv(output_dir / 'token_cost_curve.csv', index=False)

    logger.info(f"model saved to {output_dir}")


if __name__ == '__main__':
    main()
