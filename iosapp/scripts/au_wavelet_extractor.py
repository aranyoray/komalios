#!/usr/bin/env python3
"""
au_wavelet_extractor.py — Wavelet-based micro-expression feature extraction.
"""

import argparse
import json
import logging
import hashlib
import time
from pathlib import Path
from datetime import datetime

import numpy as np
import pandas as pd
from scipy.fft import fft, ifft

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out_dir', type=str, default='./outputs/wavelet_extractor')
    parser.add_argument('--n_sequences', type=int, default=1000)
    parser.add_argument('--seq_len', type=int, default=128)
    parser.add_argument('--n_aus', type=int, default=17)
    parser.add_argument('--wavelet', type=str, default='morlet')
    parser.add_argument('--n_scales', type=int, default=8)
    parser.add_argument('--synthetic', type=int, default=0)
    parser.add_argument('--dry_run', action='store_true')
    return parser.parse_args()


def generate_synthetic_au_sequences(n_sequences, seq_len, n_aus):
    """Generate synthetic AU sequences with micro-expressions."""
    sequences = []

    for _ in range(n_sequences):
        seq = np.zeros((seq_len, n_aus), dtype=np.float32)

        for au in range(n_aus):
            # Base signal
            freq = np.random.uniform(1, 5)
            t = np.linspace(0, 1, seq_len)
            seq[:, au] = 0.3 + 0.2 * np.sin(2 * np.pi * freq * t)

            # Add micro-expressions (high frequency bursts)
            n_micro = np.random.randint(1, 4)
            for _ in range(n_micro):
                center = np.random.randint(10, seq_len - 10)
                width = np.random.randint(3, 8)
                intensity = np.random.uniform(0.3, 0.7)
                gaussian = np.exp(-((np.arange(seq_len) - center) ** 2) / (2 * width ** 2))
                seq[:, au] += gaussian * intensity

        sequences.append(seq)

    return np.array(sequences)


def morlet_wavelet(n, w0=6):
    """Generate Morlet wavelet."""
    t = np.linspace(-4, 4, n)
    return np.exp(1j * w0 * t) * np.exp(-t**2 / 2)


def cwt_morlet(signal, scales, wavelet_fn):
    """Continuous Wavelet Transform with Morlet wavelet."""
    n = len(signal)
    coefficients = np.zeros((len(scales), n), dtype=complex)

    for i, scale in enumerate(scales):
        wavelet_len = min(int(8 * scale), n)
        wavelet = wavelet_fn(wavelet_len) / np.sqrt(scale)

        # Pad signal
        padded = np.pad(signal, (wavelet_len // 2, wavelet_len // 2), mode='reflect')

        # Convolution via FFT
        fft_signal = fft(padded)
        fft_wavelet = fft(wavelet, len(padded))
        conv = ifft(fft_signal * np.conj(fft_wavelet))

        coefficients[i] = conv[wavelet_len // 2:wavelet_len // 2 + n]

    return coefficients


def extract_wavelet_features(sequence, scales):
    """Extract wavelet features from AU sequence."""
    n_frames, n_aus = sequence.shape
    features = []

    for au in range(n_aus):
        coeffs = cwt_morlet(sequence[:, au], scales, morlet_wavelet)

        # Extract features from coefficients
        power = np.abs(coeffs) ** 2

        # Mean power at each scale
        scale_means = power.mean(axis=1)

        # Peak locations (micro-expression signatures)
        peak_counts = np.sum(power > power.mean() * 2, axis=1)

        # Energy ratio (high vs low frequencies)
        energy_ratio = power[:len(scales)//2].sum() / (power[len(scales)//2:].sum() + 1e-10)

        features.extend(scale_means)
        features.extend(peak_counts)
        features.append(energy_ratio)

    return np.array(features, dtype=np.float32)


def fft_features(sequence):
    """Extract FFT features for comparison."""
    n_frames, n_aus = sequence.shape
    features = []

    for au in range(n_aus):
        fft_coeffs = fft(sequence[:, au])
        power = np.abs(fft_coeffs[:n_frames // 2]) ** 2

        # Bin into 8 frequency bands
        n_bins = 8
        bin_size = len(power) // n_bins
        for i in range(n_bins):
            features.append(power[i*bin_size:(i+1)*bin_size].mean())

    return np.array(features, dtype=np.float32)


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
    sequences = generate_synthetic_au_sequences(n_sequences, args.seq_len, args.n_aus)

    scales = 2 ** np.linspace(0, 4, args.n_scales)

    if args.dry_run:
        logger.info("dry run mode")
        results = {
            'wavelet_time_ms': 5.0,
            'fft_time_ms': 1.0,
            'wavelet_feature_dim': 200,
        }
    else:
        logger.info(f"extracting features from {n_sequences} sequences...")

        # Wavelet extraction
        start = time.time()
        wavelet_features = []
        for seq in sequences:
            features = extract_wavelet_features(seq, scales)
            wavelet_features.append(features)
        wavelet_time = (time.time() - start) / n_sequences * 1000

        # FFT extraction
        start = time.time()
        fft_feats = []
        for seq in sequences:
            features = fft_features(seq)
            fft_feats.append(features)
        fft_time = (time.time() - start) / n_sequences * 1000

        wavelet_features = np.array(wavelet_features)
        fft_feats = np.array(fft_feats)

        results = {
            'n_sequences': n_sequences,
            'wavelet_time_ms': float(wavelet_time),
            'fft_time_ms': float(fft_time),
            'wavelet_feature_dim': wavelet_features.shape[1],
            'fft_feature_dim': fft_feats.shape[1],
            'scales_used': scales.tolist(),
        }

        logger.info(f"wavelet: {wavelet_time:.2f}ms/seq, {wavelet_features.shape[1]} features")
        logger.info(f"FFT: {fft_time:.2f}ms/seq, {fft_feats.shape[1]} features")

        # Save sample coefficients
        np.save(out_dir / 'wavelet_features.npy', wavelet_features[:100])
        np.save(out_dir / 'fft_features.npy', fft_feats[:100])

    with open(out_dir / 'extractor_results.json', 'w') as f:
        json.dump(results, f, indent=2)

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

    logger.info(f"wavelet extractor complete. saved to {out_dir}")


if __name__ == '__main__':
    main()
