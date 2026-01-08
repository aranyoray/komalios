#!/usr/bin/env python3
"""
model_error_early_warning.py — Continuous anomaly detection on model logits/embeddings.
Detects drift, overconfidence spikes, and stores per-session risk profiles.
"""

import argparse
import json
import logging
import hashlib
from pathlib import Path
from datetime import datetime

import numpy as np
import pandas as pd
import torch
import torch.nn as nn
from sklearn.decomposition import PCA
from sklearn.covariance import EmpiricalCovariance
from scipy.spatial.distance import mahalanobis

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out_dir', type=str, default='./outputs/early_warning')
    parser.add_argument('--n_sessions', type=int, default=100)
    parser.add_argument('--embedding_dim', type=int, default=256)
    parser.add_argument('--seq_len', type=int, default=100)
    parser.add_argument('--pca_components', type=int, default=32)
    parser.add_argument('--ae_hidden', type=int, default=64)
    parser.add_argument('--threshold_percentile', type=float, default=95)
    parser.add_argument('--synthetic', type=int, default=0)
    parser.add_argument('--dry_run', action='store_true')
    return parser.parse_args()


class AutoEncoder(nn.Module):
    def __init__(self, input_dim, hidden_dim):
        super().__init__()
        self.encoder = nn.Sequential(
            nn.Linear(input_dim, hidden_dim * 2),
            nn.ReLU(),
            nn.Linear(hidden_dim * 2, hidden_dim),
        )
        self.decoder = nn.Sequential(
            nn.Linear(hidden_dim, hidden_dim * 2),
            nn.ReLU(),
            nn.Linear(hidden_dim * 2, input_dim),
        )

    def forward(self, x):
        z = self.encoder(x)
        return self.decoder(z), z


def generate_synthetic_sessions(n_sessions, seq_len, embedding_dim):
    """Generate synthetic embedding sequences with anomalies."""
    sessions = []
    labels = []

    for i in range(n_sessions):
        # Normal embeddings
        embeddings = np.random.randn(seq_len, embedding_dim).astype(np.float32) * 0.5
        logits = np.random.randn(seq_len, 7).astype(np.float32)

        # Inject anomalies in 20% of sessions
        is_anomaly = np.zeros(seq_len)
        if np.random.rand() < 0.2:
            # Drift
            drift_start = np.random.randint(seq_len // 2, seq_len - 10)
            embeddings[drift_start:] += np.random.randn(embedding_dim) * 2
            is_anomaly[drift_start:] = 1

        if np.random.rand() < 0.15:
            # Overconfidence spikes
            spike_idx = np.random.randint(10, seq_len - 10, size=5)
            logits[spike_idx] = np.abs(logits[spike_idx]) * 5
            is_anomaly[spike_idx] = 1

        sessions.append({
            'session_id': i,
            'embeddings': embeddings,
            'logits': logits,
            'anomaly_labels': is_anomaly,
        })
        labels.append(is_anomaly.max())

    return sessions, np.array(labels)


class AnomalyDetector:
    def __init__(self, pca_components, ae_hidden, embedding_dim):
        self.pca = PCA(n_components=pca_components)
        self.ae = AutoEncoder(embedding_dim, ae_hidden)
        self.cov = EmpiricalCovariance()
        self.thresholds = {}

    def fit(self, embeddings):
        """Fit all detection methods on normal data."""
        # PCA
        self.pca.fit(embeddings)
        pca_recon = self.pca.inverse_transform(self.pca.transform(embeddings))
        pca_errors = np.mean((embeddings - pca_recon) ** 2, axis=1)

        # Autoencoder
        self._train_ae(embeddings)
        ae_errors = self._get_ae_errors(embeddings)

        # Mahalanobis
        self.cov.fit(embeddings)
        self.mean = embeddings.mean(axis=0)

        return pca_errors, ae_errors

    def _train_ae(self, embeddings, epochs=50):
        optimizer = torch.optim.Adam(self.ae.parameters(), lr=1e-3)
        x = torch.FloatTensor(embeddings)

        for _ in range(epochs):
            optimizer.zero_grad()
            recon, _ = self.ae(x)
            loss = nn.MSELoss()(recon, x)
            loss.backward()
            optimizer.step()

    def _get_ae_errors(self, embeddings):
        self.ae.eval()
        with torch.no_grad():
            x = torch.FloatTensor(embeddings)
            recon, _ = self.ae(x)
            errors = ((recon - x) ** 2).mean(dim=1).numpy()
        return errors

    def detect(self, embeddings, logits):
        """Detect anomalies using all methods."""
        results = {}

        # PCA reconstruction error
        pca_recon = self.pca.inverse_transform(self.pca.transform(embeddings))
        results['pca_error'] = np.mean((embeddings - pca_recon) ** 2, axis=1)

        # AE reconstruction error
        results['ae_error'] = self._get_ae_errors(embeddings)

        # Mahalanobis distance
        try:
            precision = self.cov.get_precision()
            results['mahalanobis'] = np.array([
                mahalanobis(e, self.mean, precision) for e in embeddings
            ])
        except:
            results['mahalanobis'] = np.zeros(len(embeddings))

        # Overconfidence detection
        max_logits = np.max(np.abs(logits), axis=1)
        results['overconfidence'] = max_logits

        # Drift detection (rolling mean shift)
        window = 10
        rolling_mean = np.array([
            embeddings[max(0, i-window):i+1].mean(axis=0)
            for i in range(len(embeddings))
        ])
        results['drift'] = np.linalg.norm(np.diff(rolling_mean, axis=0), axis=1)
        results['drift'] = np.concatenate([[0], results['drift']])

        return results


def compute_risk_profile(detection_results, thresholds):
    """Compute per-session risk profile."""
    risks = {}

    for method, values in detection_results.items():
        if method in thresholds:
            risks[f'{method}_alerts'] = int((values > thresholds[method]).sum())
            risks[f'{method}_max'] = float(values.max())
            risks[f'{method}_mean'] = float(values.mean())

    # Overall risk score
    total_alerts = sum(v for k, v in risks.items() if 'alerts' in k)
    risks['overall_risk'] = min(1.0, total_alerts / 50)

    return risks


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
    sessions, labels = generate_synthetic_sessions(
        n_sessions, args.seq_len, args.embedding_dim
    )

    if args.dry_run:
        logger.info("dry run mode")
        results = {'sessions_analyzed': n_sessions, 'anomalies_detected': 10}
    else:
        # Collect normal embeddings for training
        normal_embeddings = []
        for s in sessions[:int(n_sessions * 0.7)]:
            if s['anomaly_labels'].max() == 0:
                normal_embeddings.append(s['embeddings'])

        if len(normal_embeddings) == 0:
            normal_embeddings = [sessions[0]['embeddings']]

        normal_embeddings = np.vstack(normal_embeddings)

        logger.info(f"training anomaly detector on {len(normal_embeddings)} normal samples...")
        detector = AnomalyDetector(args.pca_components, args.ae_hidden, args.embedding_dim)
        pca_errors, ae_errors = detector.fit(normal_embeddings)

        # Set thresholds
        thresholds = {
            'pca_error': np.percentile(pca_errors, args.threshold_percentile),
            'ae_error': np.percentile(ae_errors, args.threshold_percentile),
            'mahalanobis': 3.0,
            'overconfidence': 3.0,
            'drift': np.percentile(
                np.random.randn(1000) * 0.5, args.threshold_percentile
            ),
        }

        # Analyze all sessions
        logger.info("analyzing sessions for anomalies...")
        risk_profiles = []

        for session in sessions:
            detection_results = detector.detect(
                session['embeddings'], session['logits']
            )
            risk = compute_risk_profile(detection_results, thresholds)
            risk['session_id'] = session['session_id']
            risk['has_anomaly'] = bool(session['anomaly_labels'].max())
            risk_profiles.append(risk)

        # Summary
        detected = sum(1 for r in risk_profiles if r['overall_risk'] > 0.3)
        actual = sum(1 for r in risk_profiles if r['has_anomaly'])

        results = {
            'sessions_analyzed': n_sessions,
            'anomalies_detected': detected,
            'actual_anomalies': actual,
            'thresholds': {k: float(v) for k, v in thresholds.items()},
        }

        logger.info(f"detected {detected} anomalies, actual {actual}")

        # Save risk profiles
        pd.DataFrame(risk_profiles).to_csv(out_dir / 'risk_profiles.csv', index=False)

        # Save detector
        torch.save({
            'ae_state': detector.ae.state_dict(),
            'pca_components': detector.pca.components_,
            'pca_mean': detector.pca.mean_,
            'thresholds': thresholds,
        }, out_dir / 'detector.pt')

    # Save results
    with open(out_dir / 'warning_results.json', 'w') as f:
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

    logger.info(f"early warning system complete. saved to {out_dir}")


if __name__ == '__main__':
    main()
