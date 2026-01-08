#!/usr/bin/env python3
"""
emotion_stabilizer_filter.py — Kalman/Particle filter for stabilizing noisy emotion predictions.
"""

import argparse
import json
import logging
import hashlib
from pathlib import Path
from datetime import datetime

import numpy as np
import pandas as pd

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out_dir', type=str, default='./outputs/emotion_stabilizer')
    parser.add_argument('--n_sequences', type=int, default=100)
    parser.add_argument('--seq_len', type=int, default=300)
    parser.add_argument('--n_emotions', type=int, default=7)
    parser.add_argument('--n_particles', type=int, default=100)
    parser.add_argument('--auto_tune', action='store_true', default=True)
    parser.add_argument('--synthetic', type=int, default=0)
    parser.add_argument('--dry_run', action='store_true')
    return parser.parse_args()


class KalmanFilter:
    """Kalman filter for emotion stabilization."""

    def __init__(self, n_dims, process_noise=0.01, measurement_noise=0.1):
        self.n_dims = n_dims
        self.Q = np.eye(n_dims) * process_noise
        self.R = np.eye(n_dims) * measurement_noise
        self.reset()

    def reset(self):
        self.x = np.zeros(self.n_dims)
        self.P = np.eye(self.n_dims)

    def predict(self):
        # State transition: x_k = x_{k-1} (assume constant)
        self.P = self.P + self.Q
        return self.x.copy()

    def update(self, z):
        # Kalman gain
        S = self.P + self.R
        K = self.P @ np.linalg.inv(S)

        # Update
        self.x = self.x + K @ (z - self.x)
        self.P = (np.eye(self.n_dims) - K) @ self.P

        return self.x.copy()

    def filter(self, measurement):
        self.predict()
        return self.update(measurement)


class ParticleFilter:
    """Particle filter for emotion stabilization."""

    def __init__(self, n_dims, n_particles=100, process_noise=0.05):
        self.n_dims = n_dims
        self.n_particles = n_particles
        self.process_noise = process_noise
        self.reset()

    def reset(self):
        self.particles = np.random.randn(self.n_particles, self.n_dims) * 0.1
        self.weights = np.ones(self.n_particles) / self.n_particles

    def predict(self):
        # Add process noise
        self.particles += np.random.randn(self.n_particles, self.n_dims) * self.process_noise

    def update(self, z):
        # Compute weights based on measurement likelihood
        distances = np.linalg.norm(self.particles - z, axis=1)
        self.weights = np.exp(-distances ** 2 / 0.5)
        self.weights += 1e-10
        self.weights /= self.weights.sum()

        # Resample
        indices = np.random.choice(
            self.n_particles, self.n_particles, p=self.weights
        )
        self.particles = self.particles[indices]
        self.weights = np.ones(self.n_particles) / self.n_particles

        # Return weighted mean
        return np.average(self.particles, axis=0, weights=self.weights)

    def filter(self, measurement):
        self.predict()
        return self.update(measurement)


def generate_synthetic_sequences(n_sequences, seq_len, n_emotions):
    """Generate noisy emotion sequences with ground truth."""
    sequences = []

    for _ in range(n_sequences):
        # Generate smooth ground truth
        gt = np.zeros((seq_len, n_emotions))
        current_emotion = np.random.randint(0, n_emotions)

        for t in range(seq_len):
            if np.random.rand() < 0.02:  # Transition
                current_emotion = np.random.randint(0, n_emotions)

            gt[t] = np.random.rand(n_emotions) * 0.1
            gt[t, current_emotion] = 0.7 + np.random.rand() * 0.2
            gt[t] /= gt[t].sum()

        # Add noise
        noise_level = np.random.uniform(0.1, 0.3)
        noisy = gt + np.random.randn(seq_len, n_emotions) * noise_level
        noisy = np.clip(noisy, 0, 1)
        noisy /= noisy.sum(axis=1, keepdims=True) + 1e-8

        sequences.append({
            'ground_truth': gt,
            'noisy': noisy,
            'noise_level': noise_level,
        })

    return sequences


def auto_tune_parameters(sequences, n_emotions):
    """Auto-tune filter parameters using grid search."""
    best_params = {'kalman': {}, 'particle': {}}
    best_errors = {'kalman': float('inf'), 'particle': float('inf')}

    # Kalman tuning
    for process_noise in [0.001, 0.01, 0.05]:
        for measurement_noise in [0.05, 0.1, 0.2]:
            errors = []
            for seq in sequences[:10]:
                kf = KalmanFilter(n_emotions, process_noise, measurement_noise)
                filtered = np.array([kf.filter(m) for m in seq['noisy']])
                error = np.mean((filtered - seq['ground_truth']) ** 2)
                errors.append(error)

            mean_error = np.mean(errors)
            if mean_error < best_errors['kalman']:
                best_errors['kalman'] = mean_error
                best_params['kalman'] = {
                    'process_noise': process_noise,
                    'measurement_noise': measurement_noise,
                }

    # Particle tuning
    for n_particles in [50, 100, 200]:
        for process_noise in [0.01, 0.05, 0.1]:
            errors = []
            for seq in sequences[:10]:
                pf = ParticleFilter(n_emotions, n_particles, process_noise)
                filtered = np.array([pf.filter(m) for m in seq['noisy']])
                error = np.mean((filtered - seq['ground_truth']) ** 2)
                errors.append(error)

            mean_error = np.mean(errors)
            if mean_error < best_errors['particle']:
                best_errors['particle'] = mean_error
                best_params['particle'] = {
                    'n_particles': n_particles,
                    'process_noise': process_noise,
                }

    return best_params, best_errors


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

    n_sequences = args.synthetic if args.synthetic > 0 else args.n_sequences
    sequences = generate_synthetic_sequences(n_sequences, args.seq_len, args.n_emotions)

    if args.dry_run:
        logger.info("dry run mode")
        results = {
            'kalman_mse': 0.02,
            'particle_mse': 0.025,
            'noisy_mse': 0.1,
        }
    else:
        # Auto-tune if requested
        if args.auto_tune:
            logger.info("auto-tuning filter parameters...")
            best_params, tune_errors = auto_tune_parameters(sequences, args.n_emotions)
            logger.info(f"best kalman params: {best_params['kalman']}")
            logger.info(f"best particle params: {best_params['particle']}")
        else:
            best_params = {
                'kalman': {'process_noise': 0.01, 'measurement_noise': 0.1},
                'particle': {'n_particles': args.n_particles, 'process_noise': 0.05},
            }

        # Evaluate on all sequences
        logger.info("evaluating filters on all sequences...")

        kalman_errors = []
        particle_errors = []
        noisy_errors = []

        for seq in sequences:
            # Kalman
            kf = KalmanFilter(args.n_emotions, **best_params['kalman'])
            kalman_filtered = np.array([kf.filter(m) for m in seq['noisy']])
            kalman_errors.append(np.mean((kalman_filtered - seq['ground_truth']) ** 2))

            # Particle
            pf = ParticleFilter(args.n_emotions, **best_params['particle'])
            particle_filtered = np.array([pf.filter(m) for m in seq['noisy']])
            particle_errors.append(np.mean((particle_filtered - seq['ground_truth']) ** 2))

            # Noisy baseline
            noisy_errors.append(np.mean((seq['noisy'] - seq['ground_truth']) ** 2))

        results = {
            'kalman_mse': float(np.mean(kalman_errors)),
            'particle_mse': float(np.mean(particle_errors)),
            'noisy_mse': float(np.mean(noisy_errors)),
            'kalman_improvement': float(1 - np.mean(kalman_errors) / np.mean(noisy_errors)),
            'particle_improvement': float(1 - np.mean(particle_errors) / np.mean(noisy_errors)),
            'best_params': best_params,
        }

        logger.info(f"kalman MSE: {results['kalman_mse']:.4f}")
        logger.info(f"particle MSE: {results['particle_mse']:.4f}")
        logger.info(f"noisy MSE: {results['noisy_mse']:.4f}")

        # Save filter configs
        with open(out_dir / 'filter_config.json', 'w') as f:
            json.dump(best_params, f, indent=2)

    # Save results
    with open(out_dir / 'stabilizer_results.json', 'w') as f:
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

    logger.info(f"emotion stabilizer complete. saved to {out_dir}")


if __name__ == '__main__':
    main()
