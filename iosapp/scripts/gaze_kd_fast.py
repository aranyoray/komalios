#!/usr/bin/env python3
"""
gaze_kd_fast.py — Fast knowledge distillation for gaze estimation models.
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

try:
    import mlflow
    HAS_MLFLOW = True
except ImportError:
    HAS_MLFLOW = False

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out_dir', type=str, default='./outputs/gaze_kd')
    parser.add_argument('--n_samples', type=int, default=50000)
    parser.add_argument('--epochs', type=int, default=30)
    parser.add_argument('--batch_size', type=int, default=128)
    parser.add_argument('--lr', type=float, default=1e-3)
    parser.add_argument('--temperature', type=float, default=4.0)
    parser.add_argument('--alpha', type=float, default=0.7)
    parser.add_argument('--synthetic', type=int, default=0)
    parser.add_argument('--dry_run', action='store_true')
    parser.add_argument('--debug', action='store_true')
    return parser.parse_args()


class TeacherModel(nn.Module):
    """Large gaze estimation model."""

    def __init__(self):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(768, 512),
            nn.ReLU(),
            nn.Linear(512, 256),
            nn.ReLU(),
            nn.Linear(256, 128),
            nn.ReLU(),
            nn.Linear(128, 2),  # pitch, yaw
        )

    def forward(self, x):
        return self.net(x)


class StudentModel(nn.Module):
    """Compact gaze estimation model."""

    def __init__(self):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(768, 64),
            nn.ReLU(),
            nn.Linear(64, 2),
        )

    def forward(self, x):
        return self.net(x)


def generate_gaze_data(n_samples):
    """Generate synthetic gaze data."""
    X = np.random.randn(n_samples, 768).astype(np.float32)
    # gaze angles in radians
    y = np.random.randn(n_samples, 2).astype(np.float32) * 0.5
    return X, y


def distillation_loss(student_out, teacher_out, labels, temperature, alpha):
    """Combined distillation loss."""
    # soft targets
    soft_loss = F.mse_loss(student_out / temperature, teacher_out / temperature)

    # hard targets
    hard_loss = F.mse_loss(student_out, labels)

    return alpha * soft_loss * (temperature ** 2) + (1 - alpha) * hard_loss


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
        mlflow.start_run(run_name='gaze_kd')
        mlflow.log_params(vars(args))

    n_samples = args.synthetic if args.synthetic > 0 else args.n_samples
    X, y = generate_gaze_data(n_samples)

    results = {}

    if args.dry_run:
        logger.info("dry run mode")
        results = {
            'teacher_mae': 5.0,
            'student_mae': 6.5,
            'compression_ratio': 8.0,
        }
    else:
        # Split
        split = int(0.8 * n_samples)
        X_train, X_test = X[:split], X[split:]
        y_train, y_test = y[:split], y[split:]

        # Create models
        teacher = TeacherModel()
        student = StudentModel()

        # Train teacher
        logger.info("training teacher model...")
        teacher_opt = torch.optim.Adam(teacher.parameters(), lr=args.lr)

        for epoch in range(args.epochs // 2):
            teacher.train()
            indices = np.random.permutation(len(X_train))

            for i in range(0, len(X_train), args.batch_size):
                batch_idx = indices[i:i+args.batch_size]
                batch_x = torch.FloatTensor(X_train[batch_idx])
                batch_y = torch.FloatTensor(y_train[batch_idx])

                teacher_opt.zero_grad()
                outputs = teacher(batch_x)
                loss = F.mse_loss(outputs, batch_y)
                loss.backward()
                teacher_opt.step()

        # Evaluate teacher
        teacher.eval()
        with torch.no_grad():
            teacher_pred = teacher(torch.FloatTensor(X_test)).numpy()
        teacher_mae = np.abs(teacher_pred - y_test).mean() * 180 / np.pi  # degrees

        # Distill to student
        logger.info("distilling to student model...")
        student_opt = torch.optim.Adam(student.parameters(), lr=args.lr)

        for epoch in range(args.epochs):
            student.train()
            teacher.eval()
            indices = np.random.permutation(len(X_train))

            for i in range(0, len(X_train), args.batch_size):
                batch_idx = indices[i:i+args.batch_size]
                batch_x = torch.FloatTensor(X_train[batch_idx])
                batch_y = torch.FloatTensor(y_train[batch_idx])

                with torch.no_grad():
                    teacher_out = teacher(batch_x)

                student_opt.zero_grad()
                student_out = student(batch_x)
                loss = distillation_loss(
                    student_out, teacher_out, batch_y,
                    args.temperature, args.alpha
                )
                loss.backward()
                student_opt.step()

        # Evaluate student
        student.eval()
        with torch.no_grad():
            student_pred = student(torch.FloatTensor(X_test)).numpy()
        student_mae = np.abs(student_pred - y_test).mean() * 180 / np.pi

        # Compression ratio
        teacher_params = sum(p.numel() for p in teacher.parameters())
        student_params = sum(p.numel() for p in student.parameters())

        results = {
            'teacher_mae': float(teacher_mae),
            'student_mae': float(student_mae),
            'teacher_params': teacher_params,
            'student_params': student_params,
            'compression_ratio': float(teacher_params / student_params),
        }

        logger.info(f"teacher MAE: {teacher_mae:.2f}°, student MAE: {student_mae:.2f}°")
        logger.info(f"compression: {teacher_params / student_params:.1f}x")

        # Save models
        torch.save(teacher.state_dict(), out_dir / 'gaze_teacher.pt')
        torch.save(student.state_dict(), out_dir / 'gaze_student.pt')

    # Save results
    with open(out_dir / 'kd_results.json', 'w') as f:
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

    if HAS_MLFLOW:
        mlflow.log_metrics({k: v for k, v in results.items() if isinstance(v, (int, float))})
        mlflow.end_run()

    logger.info(f"gaze KD complete. saved to {out_dir}")


if __name__ == '__main__':
    main()
