#!/usr/bin/env python3
"""
synth_generator_scaleup.py — Large synthetic multimodal generator.
"""

import argparse
import json
import logging
from pathlib import Path
from concurrent.futures import ProcessPoolExecutor

import numpy as np
import torch
from tqdm import tqdm

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output_dir', type=str, required=True)
    parser.add_argument('--num_sessions', type=int, default=1000000)
    parser.add_argument('--shard_size', type=int, default=10000)
    parser.add_argument('--seed', type=int, default=42)
    parser.add_argument('--num_workers', type=int, default=8)
    parser.add_argument('--augmentation_intensity', type=float, default=1.0)
    return parser.parse_args()


def create_child_profile(seed):
    """Generate parametric child profile."""
    np.random.seed(seed)
    return {
        'age': np.random.randint(3, 16),
        'gender': np.random.choice(['M', 'F']),
        'sensory_sensitivity': {
            'audio': np.random.choice(['low', 'medium', 'high']),
            'visual': np.random.choice(['low', 'medium', 'high']),
        },
        'focus_areas': np.random.choice(
            ['attention', 'emotion', 'social', 'language', 'cognitive'],
            size=np.random.randint(1, 4),
            replace=False
        ).tolist(),
        'baseline_attention': np.random.uniform(0.3, 0.8),
    }


def generate_gaze_sequence(duration_ms, sampling_rate=500):
    """Generate gaze vectors with micro-saccade modeling."""
    num_samples = int(duration_ms * sampling_rate / 1000)

    # base gaze position (smooth pursuit)
    t = np.linspace(0, duration_ms / 1000, num_samples)
    base_x = 960 + 200 * np.sin(0.5 * t)
    base_y = 540 + 100 * np.cos(0.3 * t)

    # add fixations
    gaze_x = base_x + np.random.randn(num_samples) * 10
    gaze_y = base_y + np.random.randn(num_samples) * 10

    # add micro-saccades
    saccade_times = np.random.choice(num_samples, size=num_samples // 50, replace=False)
    for t in saccade_times:
        if t < num_samples - 5:
            gaze_x[t:t+5] += np.random.randn(5) * 50
            gaze_y[t:t+5] += np.random.randn(5) * 50

    timestamps = np.arange(num_samples) * (1000 / sampling_rate)

    return np.stack([gaze_x, gaze_y, timestamps], axis=1).astype(np.float32)


def generate_touch_trace(duration_ms, screen_size=(1920, 1080)):
    """Generate touch traces with physics-aware simulation."""
    num_touches = np.random.randint(5, 30)

    touches = []
    for _ in range(num_touches):
        # random touch point
        x = np.random.randint(0, screen_size[0])
        y = np.random.randint(0, screen_size[1])
        timestamp = np.random.uniform(0, duration_ms)
        pressure = np.random.uniform(0.3, 1.0)
        duration = np.random.uniform(50, 500)

        touches.append([x, y, timestamp, pressure, duration])

    return np.array(touches, dtype=np.float32) if touches else np.zeros((1, 5), dtype=np.float32)


def generate_frame_features(num_frames, profile):
    """Generate image frame features (mock ViT embeddings)."""
    # base features
    features = np.random.randn(num_frames, 768).astype(np.float32)

    # add temporal coherence
    for i in range(1, num_frames):
        features[i] = 0.8 * features[i-1] + 0.2 * features[i]

    # add AU trajectories based on profile
    aus = np.random.randn(num_frames, 8).astype(np.float32) * 0.3

    return features, aus


def generate_transcript(profile):
    """Generate short transcript."""
    prompts = [
        "How are you feeling today?",
        "Can you show me happy?",
        "Let's practice taking turns.",
        "What emotion is this?",
        "Great job! You're doing well.",
    ]
    response_templates = [
        "I feel {emotion}",
        "This is {emotion}",
        "I want to {action}",
        "Can we {action}?",
    ]

    prompt = np.random.choice(prompts)
    response = np.random.choice(response_templates).format(
        emotion=np.random.choice(['happy', 'sad', 'calm', 'excited']),
        action=np.random.choice(['play', 'rest', 'talk', 'try again'])
    )

    return {'prompt': prompt, 'response': response, 'tokens': len(response.split())}


def generate_session(session_id, seed, augmentation_intensity):
    """Generate a single multimodal session."""
    np.random.seed(seed + session_id)

    profile = create_child_profile(seed + session_id)

    # session parameters
    duration_ms = np.random.randint(60000, 900000)  # 1-15 minutes
    num_frames = int(duration_ms / 1000 * 30)  # 30 fps

    session = {
        'session_id': session_id,
        'profile': profile,
        'duration_ms': duration_ms,
        'gaze': generate_gaze_sequence(duration_ms),
        'touch': generate_touch_trace(duration_ms),
        'frames': generate_frame_features(num_frames, profile)[0],
        'aus': generate_frame_features(num_frames, profile)[1],
        'transcript': generate_transcript(profile),
        'labels': {
            'attention_score': np.random.uniform(0.3, 0.9),
            'emotion_label': np.random.randint(0, 7),
            'engagement': np.random.uniform(0.4, 1.0),
        }
    }

    # apply augmentation
    if augmentation_intensity > 0:
        noise_scale = 0.1 * augmentation_intensity
        session['gaze'] += np.random.randn(*session['gaze'].shape).astype(np.float32) * noise_scale
        session['frames'] += np.random.randn(*session['frames'].shape).astype(np.float32) * noise_scale

    return session


def generate_shard(shard_id, start_idx, shard_size, seed, augmentation_intensity, output_dir):
    """Generate a shard of sessions."""
    sessions = []

    for i in range(shard_size):
        session = generate_session(start_idx + i, seed, augmentation_intensity)
        sessions.append(session)

    # save shard
    shard_path = output_dir / f'shard_{shard_id:05d}.npz'

    # convert to arrays
    np.savez_compressed(
        shard_path,
        session_ids=np.array([s['session_id'] for s in sessions]),
        gaze=np.array([s['gaze'][:1000] for s in sessions]),  # truncate for storage
        touch=np.array([s['touch'][:50] for s in sessions]),
        frames=np.array([s['frames'][:100] for s in sessions]),
        aus=np.array([s['aus'][:100] for s in sessions]),
        attention_scores=np.array([s['labels']['attention_score'] for s in sessions]),
        emotion_labels=np.array([s['labels']['emotion_label'] for s in sessions]),
    )

    return shard_id


def main():
    args = parse_args()
    np.random.seed(args.seed)

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    num_shards = args.num_sessions // args.shard_size

    logger.info(f"generating {args.num_sessions} sessions in {num_shards} shards...")

    # generate shards in parallel
    with ProcessPoolExecutor(max_workers=args.num_workers) as executor:
        futures = []
        for shard_id in range(num_shards):
            start_idx = shard_id * args.shard_size
            future = executor.submit(
                generate_shard,
                shard_id, start_idx, args.shard_size,
                args.seed, args.augmentation_intensity, output_dir
            )
            futures.append(future)

        for future in tqdm(futures, desc='generating shards'):
            future.result()

    # save metadata
    metadata = {
        'num_sessions': args.num_sessions,
        'num_shards': num_shards,
        'shard_size': args.shard_size,
        'seed': args.seed,
        'augmentation_intensity': args.augmentation_intensity,
    }

    with open(output_dir / 'metadata.json', 'w') as f:
        json.dump(metadata, f, indent=2)

    logger.info(f"generated {args.num_sessions} sessions to {output_dir}")


if __name__ == '__main__':
    main()
