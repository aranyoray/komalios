#!/usr/bin/env python3
"""
distill_and_quantize.py — Client-side distillation + quantization pipeline.
"""

import os
import argparse
import logging
import hashlib
import json
from pathlib import Path
from datetime import datetime

import numpy as np
import pandas as pd
import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.data import DataLoader, TensorDataset
from torch.cuda.amp import GradScaler, autocast
from tqdm import tqdm

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description='Distillation and Quantization')
    parser.add_argument('--teacher_checkpoint', type=str, required=True)
    parser.add_argument('--output_dir', type=str, required=True)
    parser.add_argument('--num_synthetic_samples', type=int, default=200000)
    parser.add_argument('--student_dim', type=int, default=256)
    parser.add_argument('--student_layers', type=int, default=4)
    parser.add_argument('--batch_size', type=int, default=64)
    parser.add_argument('--epochs', type=int, default=20)
    parser.add_argument('--lr', type=float, default=1e-4)
    parser.add_argument('--temperature', type=float, default=4.0)
    parser.add_argument('--alpha', type=float, default=0.7)
    parser.add_argument('--fp16', action='store_true')
    parser.add_argument('--gradient_accumulation', type=int, default=1)
    parser.add_argument('--mlflow_tracking', action='store_true')
    parser.add_argument('--seed', type=int, default=42)
    return parser.parse_args()


class TinyStudent(nn.Module):
    """Tiny student model (≤20M params)."""

    def __init__(self, dim=256, num_layers=4, num_heads=4):
        super().__init__()
        self.embed = nn.Linear(768 + 5 + 128, dim)  # vision + gaze + text
        encoder_layer = nn.TransformerEncoderLayer(dim, num_heads, dim * 4, batch_first=True)
        self.encoder = nn.TransformerEncoder(encoder_layer, num_layers)
        self.gaze_head = nn.Linear(dim, 2)
        self.cls_head = nn.Linear(dim, 7)
        self.feature_proj = nn.Linear(dim, 768)

    def forward(self, x):
        x = self.embed(x)
        x = self.encoder(x)
        pooled = x.mean(1)
        return {
            'gaze': self.gaze_head(pooled),
            'logits': self.cls_head(pooled),
            'features': self.feature_proj(pooled),
        }


def generate_synthetic_data(num_samples):
    """Generate synthetic multimodal samples."""
    logger.info(f"generating {num_samples} synthetic samples...")
    vision = torch.randn(num_samples, 768)
    gaze = torch.randn(num_samples, 5)
    text = torch.randn(num_samples, 128)
    labels = torch.randint(0, 7, (num_samples,))
    gaze_targets = torch.randn(num_samples, 2)
    return torch.cat([vision, gaze, text], dim=1), labels, gaze_targets


def distill(student, teacher_outputs, inputs, labels, gaze_targets, temperature, alpha):
    """Knowledge distillation loss."""
    outputs = student(inputs.unsqueeze(1))

    # soft labels
    soft_loss = F.kl_div(
        F.log_softmax(outputs['logits'] / temperature, dim=1),
        F.softmax(teacher_outputs['logits'] / temperature, dim=1),
        reduction='batchmean'
    ) * (temperature ** 2)

    # hard labels
    hard_loss = F.cross_entropy(outputs['logits'], labels)

    # feature matching
    feature_loss = F.mse_loss(outputs['features'], teacher_outputs['features'])

    # gaze regression
    gaze_loss = F.mse_loss(outputs['gaze'], gaze_targets)

    return alpha * soft_loss + (1 - alpha) * hard_loss + 0.1 * feature_loss + 0.1 * gaze_loss


def quantize_static(model, calibration_data):
    """Post-training static quantization."""
    model.eval()
    model.qconfig = torch.quantization.get_default_qconfig('fbgemm')
    torch.quantization.prepare(model, inplace=True)

    # calibration
    with torch.no_grad():
        for data in calibration_data[:100]:
            model(data.unsqueeze(0).unsqueeze(1))

    torch.quantization.convert(model, inplace=True)
    return model


def export_onnx(model, sample_input, output_path):
    """Export to ONNX format."""
    torch.onnx.export(
        model,
        sample_input.unsqueeze(0).unsqueeze(1),
        output_path,
        input_names=['input'],
        output_names=['gaze', 'logits', 'features'],
        dynamic_axes={'input': {0: 'batch'}},
        opset_version=13,
    )


def compute_sha256(filepath):
    """Compute SHA256 hash."""
    sha256_hash = hashlib.sha256()
    with open(filepath, 'rb') as f:
        for chunk in iter(lambda: f.read(4096), b''):
            sha256_hash.update(chunk)
    return sha256_hash.hexdigest()


def main():
    args = parse_args()
    torch.manual_seed(args.seed)
    np.random.seed(args.seed)

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')

    # generate synthetic data
    inputs, labels, gaze_targets = generate_synthetic_data(args.num_synthetic_samples)
    dataset = TensorDataset(inputs, labels, gaze_targets)
    loader = DataLoader(dataset, batch_size=args.batch_size, shuffle=True)

    # create student
    student = TinyStudent(args.student_dim, args.student_layers).to(device)
    logger.info(f"student params: {sum(p.numel() for p in student.parameters()) / 1e6:.2f}M")

    # mock teacher outputs
    teacher_outputs = {
        'logits': torch.randn(args.batch_size, 7).to(device),
        'features': torch.randn(args.batch_size, 768).to(device),
    }

    optimizer = torch.optim.AdamW(student.parameters(), lr=args.lr)
    scaler = GradScaler() if args.fp16 else None

    # MLflow
    if args.mlflow_tracking:
        import mlflow
        mlflow.start_run()
        mlflow.log_params(vars(args))

    # training
    logger.info("starting distillation...")
    for epoch in range(args.epochs):
        student.train()
        total_loss = 0

        for batch_idx, (inp, lbl, gaze) in enumerate(tqdm(loader, desc=f'epoch {epoch}')):
            inp, lbl, gaze = inp.to(device), lbl.to(device), gaze.to(device)

            with autocast(enabled=args.fp16):
                loss = distill(student, teacher_outputs, inp, lbl, gaze, args.temperature, args.alpha)
                loss = loss / args.gradient_accumulation

            if scaler:
                scaler.scale(loss).backward()
            else:
                loss.backward()

            if (batch_idx + 1) % args.gradient_accumulation == 0:
                if scaler:
                    scaler.step(optimizer)
                    scaler.update()
                else:
                    optimizer.step()
                optimizer.zero_grad()

            total_loss += loss.item() * args.gradient_accumulation

        avg_loss = total_loss / len(loader)
        logger.info(f"epoch {epoch} | loss: {avg_loss:.4f}")

        if args.mlflow_tracking:
            mlflow.log_metric('loss', avg_loss, step=epoch)

    # save student
    student_path = output_dir / 'student.pt'
    torch.save(student.state_dict(), student_path)

    # quantization
    logger.info("applying quantization...")
    student_cpu = TinyStudent(args.student_dim, args.student_layers)
    student_cpu.load_state_dict(torch.load(student_path))

    # static quantization
    quantized = quantize_static(student_cpu.cpu(), inputs[:100])
    quantized_path = output_dir / 'student_int8.pt'
    torch.save(quantized.state_dict(), quantized_path)

    # export ONNX
    logger.info("exporting ONNX...")
    onnx_path = output_dir / 'student.onnx'
    student.cpu().eval()
    export_onnx(student, inputs[0], onnx_path)

    # create summary
    artifacts = []
    for path in [student_path, quantized_path, onnx_path]:
        if path.exists():
            artifacts.append({
                'name': path.name,
                'size_mb': path.stat().st_size / 1e6,
                'sha256': compute_sha256(path),
            })

    summary = pd.DataFrame(artifacts)
    summary.to_csv(output_dir / 'artifacts_summary.csv', index=False)

    logger.info(f"artifacts saved to {output_dir}")

    if args.mlflow_tracking:
        mlflow.end_run()


if __name__ == '__main__':
    main()
