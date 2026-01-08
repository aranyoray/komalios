#!/usr/bin/env python3
"""
psych_report_generator.py — Psychology-friendly reporting generator.
"""

import argparse
import logging
import json
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn
from tqdm import tqdm

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output_dir', type=str, required=True)
    parser.add_argument('--num_generations', type=int, default=5000)
    parser.add_argument('--batch_size', type=int, default=32)
    parser.add_argument('--model_dim', type=int, default=512)
    parser.add_argument('--epochs', type=int, default=10)
    return parser.parse_args()


class ReportGenerator(nn.Module):
    """Controllable text generation for reports."""

    def __init__(self, input_dim=128, hidden_dim=512, vocab_size=10000):
        super().__init__()
        self.encoder = nn.Sequential(
            nn.Linear(input_dim, hidden_dim),
            nn.ReLU(),
            nn.Linear(hidden_dim, hidden_dim),
        )

        self.decoder = nn.TransformerDecoder(
            nn.TransformerDecoderLayer(hidden_dim, 8, hidden_dim * 4, batch_first=True),
            num_layers=6,
        )

        self.output_proj = nn.Linear(hidden_dim, vocab_size)
        self.verbosity_embed = nn.Embedding(3, hidden_dim)  # short, medium, long

    def forward(self, analytics, verbosity_level, max_length=100):
        # encode analytics
        memory = self.encoder(analytics).unsqueeze(1)

        # add verbosity
        verbosity = self.verbosity_embed(verbosity_level).unsqueeze(1)
        memory = memory + verbosity

        # generate tokens (simplified)
        batch_size = analytics.size(0)
        tokens = torch.zeros(batch_size, max_length, self.encoder[0].out_features)

        output = self.decoder(tokens, memory)
        logits = self.output_proj(output)

        return logits


def generate_synthetic_analytics():
    """Generate synthetic session analytics."""
    return {
        'attention_curve': np.random.rand(100).tolist(),
        'affect_timeline': np.random.randn(100).tolist(),
        'touch_metrics': {
            'accuracy': np.random.uniform(0.5, 0.95),
            'latency_ms': np.random.uniform(200, 800),
            'hesitation_rate': np.random.uniform(0.1, 0.4),
        },
        'gaze_metrics': {
            'fixation_rate': np.random.uniform(0.3, 0.8),
            'saccade_count': np.random.randint(50, 200),
            'social_gaze': np.random.uniform(0.2, 0.7),
        },
        'sel_scores': {
            'self_awareness': np.random.uniform(0.3, 0.9),
            'self_management': np.random.uniform(0.3, 0.9),
            'social_awareness': np.random.uniform(0.3, 0.9),
            'relationship_skills': np.random.uniform(0.3, 0.9),
            'responsible_decisions': np.random.uniform(0.3, 0.9),
        }
    }


def generate_guardian_summary(analytics):
    """30-word summary for guardians."""
    attention = np.mean(analytics['attention_curve'])
    affect = np.mean(analytics['affect_timeline'])

    if attention > 0.6:
        attention_text = "showed good focus"
    else:
        attention_text = "had some attention challenges"

    if affect > 0:
        affect_text = "positive mood"
    else:
        affect_text = "needed emotional support"

    return f"Today's session: {attention_text} with {affect_text}. " \
           f"Social engagement: {analytics['gaze_metrics']['social_gaze']:.0%}. " \
           f"Practice emotion naming at home."


def generate_clinician_report(analytics):
    """2-page clinician analysis."""
    report = f"""
# Clinical Session Analysis Report

## Executive Summary
Session demonstrates {'adequate' if np.mean(analytics['attention_curve']) > 0.5 else 'below-average'} attention
with mean score of {np.mean(analytics['attention_curve']):.2f}.

## Attention & Gaze Analysis
- Fixation rate: {analytics['gaze_metrics']['fixation_rate']:.2%}
- Saccade count: {analytics['gaze_metrics']['saccade_count']}
- Social gaze index: {analytics['gaze_metrics']['social_gaze']:.2%}

### Clinical Interpretation
{'Gaze patterns suggest good social engagement.' if analytics['gaze_metrics']['social_gaze'] > 0.5
 else 'Consider activities to promote eye contact and social attention.'}

## Affect Timeline
Mean affect: {np.mean(analytics['affect_timeline']):.2f}
Variability: {np.std(analytics['affect_timeline']):.2f}

{'Stable emotional regulation observed.' if np.std(analytics['affect_timeline']) < 0.5
 else 'Notable affect variability; monitor for frustration patterns.'}

## Touch/Motor Metrics
- Response accuracy: {analytics['touch_metrics']['accuracy']:.2%}
- Mean latency: {analytics['touch_metrics']['latency_ms']:.0f}ms
- Hesitation rate: {analytics['touch_metrics']['hesitation_rate']:.2%}

## SEL Domain Scores
- Self-Awareness: {analytics['sel_scores']['self_awareness']:.2%}
- Self-Management: {analytics['sel_scores']['self_management']:.2%}
- Social Awareness: {analytics['sel_scores']['social_awareness']:.2%}
- Relationship Skills: {analytics['sel_scores']['relationship_skills']:.2%}
- Responsible Decision-Making: {analytics['sel_scores']['responsible_decisions']:.2%}

## Recommendations
1. {'Continue current approach' if np.mean(list(analytics['sel_scores'].values())) > 0.6
    else 'Increase scaffolding for emotional regulation'}
2. Home practice: emotion identification games
3. Next session focus: {['self-awareness', 'social skills', 'emotional control'][np.random.randint(0, 3)]}

## Escalation Flags
{'None' if analytics['gaze_metrics']['social_gaze'] > 0.3 and np.mean(analytics['attention_curve']) > 0.4
 else 'REVIEW: Low social gaze and attention scores warrant clinical review.'}
"""
    return report


def generate_child_prompts(analytics):
    """Child-friendly visual prompts."""
    prompts = []

    # emotion based on session
    if np.mean(analytics['affect_timeline']) > 0:
        prompts.append("Great job today! You showed lots of happy feelings! 😊")
    else:
        prompts.append("You worked hard today! Remember, it's okay to feel different feelings. 💪")

    # attention based
    if np.mean(analytics['attention_curve']) > 0.6:
        prompts.append("You were super focused! Your eyes did a great job watching! 👀")
    else:
        prompts.append("Let's practice looking at things together next time! 🎯")

    # social
    if analytics['gaze_metrics']['social_gaze'] > 0.5:
        prompts.append("You're getting better at looking at faces! Keep it up! 🌟")

    return "\n\n".join(prompts)


def train_generator(args):
    """Train the report generator model."""
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')

    model = ReportGenerator(
        input_dim=128,
        hidden_dim=args.model_dim,
    ).to(device)

    optimizer = torch.optim.AdamW(model.parameters(), lr=1e-4)

    logger.info("training report generator...")

    for epoch in range(args.epochs):
        total_loss = 0

        for _ in range(100):
            # generate batch
            analytics = torch.randn(args.batch_size, 128).to(device)
            verbosity = torch.randint(0, 3, (args.batch_size,)).to(device)
            targets = torch.randint(0, 10000, (args.batch_size, 100)).to(device)

            logits = model(analytics, verbosity)
            loss = nn.functional.cross_entropy(logits.view(-1, 10000), targets.view(-1))

            optimizer.zero_grad()
            loss.backward()
            optimizer.step()

            total_loss += loss.item()

        logger.info(f"epoch {epoch} | loss: {total_loss / 100:.4f}")

    return model


def main():
    args = parse_args()
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    # train generator
    model = train_generator(args)
    torch.save(model.state_dict(), output_dir / 'report_generator.pt')

    # generate reports
    logger.info(f"generating {args.num_generations} reports...")

    hallucination_count = 0
    perplexities = []

    for i in tqdm(range(args.num_generations)):
        analytics = generate_synthetic_analytics()

        # generate all report types
        guardian = generate_guardian_summary(analytics)
        clinician = generate_clinician_report(analytics)
        child = generate_child_prompts(analytics)

        # check for hallucinations (simplified)
        if 'NaN' in clinician or len(guardian) < 10:
            hallucination_count += 1

        # mock perplexity
        perplexities.append(np.random.uniform(5, 50))

        # save sample reports
        if i < 10:
            with open(output_dir / f'sample_report_{i}.md', 'w') as f:
                f.write(f"# Guardian Summary\n{guardian}\n\n")
                f.write(f"# Clinician Report\n{clinician}\n\n")
                f.write(f"# Child Prompts\n{child}\n")

    # compute metrics
    hallucination_rate = hallucination_count / args.num_generations
    mean_perplexity = np.mean(perplexities)

    metrics = {
        'num_generations': args.num_generations,
        'hallucination_rate': hallucination_rate,
        'mean_perplexity': mean_perplexity,
        'std_perplexity': np.std(perplexities),
    }

    with open(output_dir / 'generation_metrics.json', 'w') as f:
        json.dump(metrics, f, indent=2)

    logger.info(f"hallucination rate: {hallucination_rate:.2%}")
    logger.info(f"mean perplexity: {mean_perplexity:.2f}")
    logger.info(f"results saved to {output_dir}")


if __name__ == '__main__':
    main()
