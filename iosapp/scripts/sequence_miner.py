#!/usr/bin/env python3
"""
sequence_miner.py — PrefixSpan/FP-Growth over interaction logs to find SEL patterns.
"""

import argparse
import json
import logging
import hashlib
from pathlib import Path
from datetime import datetime
from collections import defaultdict

import numpy as np
import pandas as pd

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out_dir', type=str, default='./outputs/sequence_mining')
    parser.add_argument('--n_sessions', type=int, default=1000)
    parser.add_argument('--min_support', type=float, default=0.05)
    parser.add_argument('--max_pattern_len', type=int, default=5)
    parser.add_argument('--algorithm', type=str, default='prefixspan', choices=['prefixspan', 'fpgrowth'])
    parser.add_argument('--synthetic', type=int, default=0)
    parser.add_argument('--dry_run', action='store_true')
    return parser.parse_args()


def generate_synthetic_logs(n_sessions):
    """Generate synthetic interaction logs."""
    # Event types
    events = [
        'gaze_left', 'gaze_right', 'gaze_center', 'gaze_away',
        'touch_tap', 'touch_swipe', 'touch_hold', 'touch_erratic',
        'latency_fast', 'latency_medium', 'latency_slow',
        'emotion_happy', 'emotion_sad', 'emotion_frustrated', 'emotion_neutral',
    ]

    # Difficulty patterns (inject these)
    difficulty_patterns = [
        ['gaze_away', 'latency_slow', 'touch_erratic', 'emotion_frustrated'],
        ['latency_slow', 'emotion_sad', 'gaze_away'],
        ['touch_erratic', 'gaze_away', 'emotion_frustrated'],
        ['emotion_frustrated', 'touch_hold', 'latency_slow'],
    ]

    sessions = []
    for _ in range(n_sessions):
        seq_len = np.random.randint(20, 50)
        sequence = []

        # Generate random events
        for _ in range(seq_len):
            event = np.random.choice(events)
            sequence.append(event)

        # Inject difficulty pattern with some probability
        if np.random.rand() < 0.3:
            pattern = difficulty_patterns[np.random.randint(len(difficulty_patterns))]
            insert_pos = np.random.randint(0, seq_len - len(pattern))
            for i, event in enumerate(pattern):
                sequence[insert_pos + i] = event

        sessions.append(sequence)

    return sessions


class PrefixSpan:
    """PrefixSpan sequential pattern mining."""

    def __init__(self, min_support, max_len):
        self.min_support = min_support
        self.max_len = max_len
        self.patterns = []

    def fit(self, sequences):
        self.n_sequences = len(sequences)
        self.min_count = int(self.min_support * self.n_sequences)

        # Find frequent 1-sequences
        item_counts = defaultdict(int)
        for seq in sequences:
            seen = set()
            for item in seq:
                if item not in seen:
                    item_counts[item] += 1
                    seen.add(item)

        # Start mining
        for item, count in item_counts.items():
            if count >= self.min_count:
                self._mine([item], sequences, count)

        return self.patterns

    def _mine(self, prefix, sequences, support):
        self.patterns.append({
            'pattern': prefix.copy(),
            'support': support / self.n_sequences,
            'count': support,
        })

        if len(prefix) >= self.max_len:
            return

        # Project database
        projected = []
        for seq in sequences:
            # Find prefix in sequence
            found = False
            suffix_start = 0
            for i, item in enumerate(seq):
                if item == prefix[-1]:
                    suffix_start = i + 1
                    found = True
                    break

            if found and suffix_start < len(seq):
                projected.append(seq[suffix_start:])

        # Find frequent items in projection
        item_counts = defaultdict(int)
        for seq in projected:
            seen = set()
            for item in seq:
                if item not in seen:
                    item_counts[item] += 1
                    seen.add(item)

        # Extend prefix
        for item, count in item_counts.items():
            if count >= self.min_count:
                new_prefix = prefix + [item]
                self._mine(new_prefix, projected, count)


class FPGrowth:
    """Simplified FP-Growth for sequential patterns."""

    def __init__(self, min_support, max_len):
        self.min_support = min_support
        self.max_len = max_len

    def fit(self, sequences):
        n_sequences = len(sequences)
        min_count = int(self.min_support * n_sequences)

        # Convert sequences to itemsets (for FP-Growth)
        # Use sliding windows
        itemsets = []
        for seq in sequences:
            for window_size in range(2, min(len(seq), self.max_len) + 1):
                for i in range(len(seq) - window_size + 1):
                    itemsets.append(tuple(seq[i:i+window_size]))

        # Count patterns
        pattern_counts = defaultdict(int)
        for itemset in itemsets:
            pattern_counts[itemset] += 1

        # Filter by support
        patterns = []
        for pattern, count in pattern_counts.items():
            support = count / n_sequences
            if support >= self.min_support:
                patterns.append({
                    'pattern': list(pattern),
                    'support': support,
                    'count': count,
                })

        return sorted(patterns, key=lambda x: -x['support'])


def compute_sha256(filepath):
    sha256_hash = hashlib.sha256()
    with open(filepath, 'rb') as f:
        for chunk in iter(lambda: f.read(4096), b''):
            sha256_hash.update(chunk)
    return sha256_hash.hexdigest()


def main():
    args = parse_args()
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    n_sessions = args.synthetic if args.synthetic > 0 else args.n_sessions
    sessions = generate_synthetic_logs(n_sessions)

    if args.dry_run:
        logger.info("dry run mode")
        patterns = [
            {'pattern': ['gaze_away', 'emotion_frustrated'], 'support': 0.15, 'count': 150},
            {'pattern': ['latency_slow', 'touch_erratic'], 'support': 0.12, 'count': 120},
        ]
        results = {'n_patterns': 2, 'algorithm': args.algorithm}
    else:
        logger.info(f"mining patterns with {args.algorithm}...")

        if args.algorithm == 'prefixspan':
            miner = PrefixSpan(args.min_support, args.max_pattern_len)
        else:
            miner = FPGrowth(args.min_support, args.max_pattern_len)

        patterns = miner.fit(sessions)

        # Sort by support
        patterns = sorted(patterns, key=lambda x: -x['support'])

        logger.info(f"found {len(patterns)} frequent patterns")

        # Show top patterns
        logger.info("top difficulty patterns:")
        for p in patterns[:10]:
            logger.info(f"  {p['pattern']} (support: {p['support']:.3f})")

        results = {
            'n_patterns': len(patterns),
            'algorithm': args.algorithm,
            'min_support': args.min_support,
            'n_sessions': n_sessions,
        }

        # Save patterns to JSON
        with open(out_dir / 'patterns.json', 'w') as f:
            json.dump(patterns, f, indent=2)

        # Save as CSV too
        patterns_df = pd.DataFrame([
            {
                'pattern': ' -> '.join(p['pattern']),
                'support': p['support'],
                'count': p['count'],
                'length': len(p['pattern']),
            }
            for p in patterns
        ])
        patterns_df.to_csv(out_dir / 'patterns.csv', index=False)

    # Save results
    with open(out_dir / 'mining_results.json', 'w') as f:
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

    logger.info(f"sequence mining complete. saved to {out_dir}")


if __name__ == '__main__':
    main()
