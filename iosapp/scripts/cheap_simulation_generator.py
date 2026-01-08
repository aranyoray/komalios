#!/usr/bin/env python3
"""
cheap_simulation_generator.py — Low-cost synthetic session generator.
Uses procedural rules (no diffusion), prioritizes edge cases, limits compute.
"""

import argparse
import json
import logging
import time
from pathlib import Path
from datetime import datetime
import numpy as np

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description='Cheap synthetic session generator')
    parser.add_argument('--output_dir', type=str, default='./synthetic_sessions')
    parser.add_argument('--n_sessions', type=int, default=100)
    parser.add_argument('--max_resolution', type=int, default=64, help='Max frame resolution')
    parser.add_argument('--max_jobs_per_minute', type=int, default=60)
    parser.add_argument('--edge_case_ratio', type=float, default=0.3)
    parser.add_argument('--shard_size', type=int, default=50)
    return parser.parse_args()


def generate_procedural_gaze(n_frames, edge_case=False):
    """Generate gaze data using simple rules."""
    t = np.linspace(0, 1, n_frames)

    if edge_case:
        # Edge cases: sudden jumps, boundaries, missing data
        x = np.clip(np.random.randn(n_frames) * 0.3 + 0.5, 0, 1)
        y = np.clip(np.random.randn(n_frames) * 0.3 + 0.5, 0, 1)

        # Add sudden jumps
        for _ in range(np.random.randint(1, 4)):
            idx = np.random.randint(0, n_frames)
            x[idx:] = np.random.rand()
            y[idx:] = np.random.rand()
    else:
        # Normal: smooth movement
        x = 0.5 + 0.3 * np.sin(2 * np.pi * t * np.random.uniform(0.5, 2))
        y = 0.5 + 0.3 * np.cos(2 * np.pi * t * np.random.uniform(0.5, 2))

    return [{'timestamp': i * 0.033, 'x': float(x[i]), 'y': float(y[i])}
            for i in range(n_frames)]


def generate_procedural_au(n_frames, n_aus=17, edge_case=False):
    """Generate AU data using procedural rules."""
    aus = np.zeros((n_frames, n_aus))

    for au in range(n_aus):
        # Base activation
        freq = np.random.uniform(0.5, 3)
        t = np.linspace(0, 4 * np.pi, n_frames)
        aus[:, au] = 0.3 + 0.2 * np.sin(freq * t)

        if edge_case:
            # Add spikes
            spike_idx = np.random.randint(0, n_frames)
            aus[spike_idx, au] = np.random.uniform(3, 5)

    return [{'timestamp': i * 0.033, 'values': aus[i].tolist()}
            for i in range(n_frames)]


def generate_session(session_id, resolution, edge_case=False):
    """Generate a complete synthetic session."""
    n_frames = np.random.randint(100, 500)

    session = {
        'session_id': session_id,
        'timestamp': datetime.now().isoformat(),
        'synthetic': True,
        'edge_case': edge_case,
        'resolution': resolution,
        'child_age_bucket': np.random.choice(['3-5', '6-8', '9-11', '12+']),
        'consent': True,
        'duration': n_frames * 0.033,
        'gaze_series': generate_procedural_gaze(n_frames, edge_case),
        'au_series': generate_procedural_au(n_frames, edge_case=edge_case),
        'metadata': {
            'generator': 'cheap_simulation',
            'version': '1.0'
        }
    }

    return session


def main():
    args = parse_args()

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    # Rate limiting
    min_interval = 60.0 / args.max_jobs_per_minute

    sessions_generated = 0
    shards = []
    current_shard = []

    logger.info(f"Generating {args.n_sessions} sessions...")
    logger.info(f"Edge case ratio: {args.edge_case_ratio}")
    logger.info(f"Max resolution: {args.max_resolution}")

    start_time = time.time()

    for i in range(args.n_sessions):
        session_id = f"synth_{i:06d}"
        edge_case = np.random.rand() < args.edge_case_ratio

        session = generate_session(session_id, args.max_resolution, edge_case)
        current_shard.append(session)

        # Write shard
        if len(current_shard) >= args.shard_size:
            shard_id = len(shards)
            shard_path = output_dir / f'shard_{shard_id:04d}.json'

            with open(shard_path, 'w') as f:
                json.dump(current_shard, f)

            shards.append({
                'shard_id': shard_id,
                'path': str(shard_path),
                'n_sessions': len(current_shard),
                'size_bytes': shard_path.stat().st_size
            })

            current_shard = []
            logger.info(f"Wrote shard {shard_id}")

        sessions_generated += 1

        # Rate limiting
        elapsed = time.time() - start_time
        expected_elapsed = sessions_generated * min_interval
        if elapsed < expected_elapsed:
            time.sleep(expected_elapsed - elapsed)

    # Write final shard
    if current_shard:
        shard_id = len(shards)
        shard_path = output_dir / f'shard_{shard_id:04d}.json'
        with open(shard_path, 'w') as f:
            json.dump(current_shard, f)
        shards.append({
            'shard_id': shard_id,
            'path': str(shard_path),
            'n_sessions': len(current_shard),
            'size_bytes': shard_path.stat().st_size
        })

    # Write manifest
    manifest = {
        'total_sessions': sessions_generated,
        'total_shards': len(shards),
        'edge_case_ratio': args.edge_case_ratio,
        'max_resolution': args.max_resolution,
        'generation_time_s': time.time() - start_time,
        'shards': shards
    }

    manifest_path = output_dir / 'manifest.json'
    with open(manifest_path, 'w') as f:
        json.dump(manifest, f, indent=2)

    logger.info(f"Generated {sessions_generated} sessions in {len(shards)} shards")
    print(json.dumps(manifest, indent=2))


if __name__ == '__main__':
    main()
