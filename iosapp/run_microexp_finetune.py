#!/usr/bin/env python3
"""
run_microexp_finetune.py — Micro-expression detection finetuning.
"""

import os
import argparse
import logging
from pathlib import Path

import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.data import DataLoader
from torch.cuda.amp import GradScaler, autocast
import numpy as np
from tqdm import tqdm

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description='Micro-expression Finetuning')
    parser.add_argument('--model_type', type=str, default='spatiotemporal_transformer')
    parser.add_argument('--backbone', type=str, default='r2plus1d_18')
    parser.add_argument('--pretrained_path', type=str, default=None)
    parser.add_argument('--dataset_root', type=str, required=True)
    parser.add_argument('--output_dir', type=str, required=True)
    parser.add_argument('--frame_rate', type=int, default=200)
    parser.add_argument('--clip_length', type=int, default=64)
    parser.add_argument('--num_classes', type=int, default=7)
    parser.add_argument('--batch_size', type=int, default=16)
    parser.add_argument('--epochs', type=int, default=100)
    parser.add_argument('--lr', type=float, default=1e-4)
    parser.add_argument('--weight_decay', type=float, default=0.01)
    parser.add_argument('--fp16', action='store_true')
    parser.add_argument('--balanced_sampler', action='store_true')
    parser.add_argument('--focal_loss', action='store_true')
    parser.add_argument('--focal_gamma', type=float, default=2.0)
    parser.add_argument('--class_weights', type=str, default=None)
    parser.add_argument('--temporal_augment', action='store_true')
    parser.add_argument('--mixup_alpha', type=float, default=0.0)
    parser.add_argument('--label_smoothing', type=float, default=0.0)
    parser.add_argument('--early_stopping_patience', type=int, default=10)
    return parser.parse_args()


class FocalLoss(nn.Module):
    """Focal loss for class imbalance."""

    def __init__(self, gamma=2.0, weight=None):
        super().__init__()
        self.gamma = gamma
        self.weight = weight

    def forward(self, inputs, targets):
        ce_loss = F.cross_entropy(inputs, targets, weight=self.weight, reduction='none')
        pt = torch.exp(-ce_loss)
        focal_loss = ((1 - pt) ** self.gamma) * ce_loss
        return focal_loss.mean()


class SpatioTemporalTransformer(nn.Module):
    """Spatio-temporal transformer for micro-expression detection."""

    def __init__(self, num_classes=7, backbone='r2plus1d_18'):
        super().__init__()

        # 3D CNN backbone
        if backbone == 'r2plus1d_18':
            from torchvision.models.video import r2plus1d_18
            self.backbone = r2plus1d_18(pretrained=True)
            self.backbone.fc = nn.Identity()
            feature_dim = 512
        else:
            # simple 3D conv
            self.backbone = nn.Sequential(
                nn.Conv3d(3, 64, kernel_size=3, padding=1),
                nn.ReLU(),
                nn.MaxPool3d(2),
                nn.Conv3d(64, 128, kernel_size=3, padding=1),
                nn.ReLU(),
                nn.AdaptiveAvgPool3d(1),
                nn.Flatten(),
            )
            feature_dim = 128

        # temporal transformer
        self.temporal_encoder = nn.TransformerEncoder(
            nn.TransformerEncoderLayer(
                d_model=feature_dim,
                nhead=8,
                dim_feedforward=feature_dim * 4,
                dropout=0.1,
                batch_first=True,
            ),
            num_layers=4,
        )

        self.classifier = nn.Sequential(
            nn.Linear(feature_dim, feature_dim // 2),
            nn.ReLU(),
            nn.Dropout(0.1),
            nn.Linear(feature_dim // 2, num_classes),
        )

    def forward(self, x):
        # x: [B, C, T, H, W]
        features = self.backbone(x)  # [B, D]
        if features.dim() == 2:
            features = features.unsqueeze(1)  # [B, 1, D]
        features = self.temporal_encoder(features)
        pooled = features.mean(dim=1)
        return self.classifier(pooled)


class MicroExpressionDataset(torch.utils.data.Dataset):
    """Dataset for micro-expression video clips."""

    def __init__(self, data_root, clip_length=64, transform=None):
        self.data_root = Path(data_root)
        self.clip_length = clip_length
        self.transform = transform

        # find video directories
        self.samples = []
        for video_dir in self.data_root.iterdir():
            if video_dir.is_dir():
                frames = sorted(video_dir.glob('*.png'))
                if len(frames) >= clip_length:
                    # get label from directory name or metadata
                    label = self._get_label(video_dir)
                    self.samples.append((video_dir, label))

    def _get_label(self, video_dir):
        # try to read from metadata
        meta_path = video_dir / 'metadata.json'
        if meta_path.exists():
            import json
            with open(meta_path) as f:
                return json.load(f).get('label', 0)
        return 0

    def __len__(self):
        return len(self.samples)

    def __getitem__(self, idx):
        import cv2
        video_dir, label = self.samples[idx]
        frames = sorted(video_dir.glob('*.png'))

        # sample frames
        if len(frames) > self.clip_length:
            start = np.random.randint(0, len(frames) - self.clip_length)
            frames = frames[start:start + self.clip_length]
        else:
            frames = frames[:self.clip_length]

        # load frames
        clip = []
        for frame_path in frames:
            frame = cv2.imread(str(frame_path))
            frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            frame = cv2.resize(frame, (112, 112))
            clip.append(frame)

        # convert to tensor [C, T, H, W]
        clip = np.stack(clip, axis=0)  # [T, H, W, C]
        clip = torch.from_numpy(clip).permute(3, 0, 1, 2).float() / 255.0

        return {'video': clip, 'label': label}


def train(args):
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    # model
    model = SpatioTemporalTransformer(
        num_classes=args.num_classes,
        backbone=args.backbone
    ).to(device)

    # load pretrained
    if args.pretrained_path:
        state = torch.load(args.pretrained_path, map_location='cpu')
        model.load_state_dict(state, strict=False)

    # dataset
    dataset = MicroExpressionDataset(args.dataset_root, args.clip_length)
    train_size = int(0.8 * len(dataset))
    val_size = len(dataset) - train_size
    train_dataset, val_dataset = torch.utils.data.random_split(dataset, [train_size, val_size])

    train_loader = DataLoader(train_dataset, batch_size=args.batch_size, shuffle=True, num_workers=4)
    val_loader = DataLoader(val_dataset, batch_size=args.batch_size, shuffle=False, num_workers=4)

    # loss
    class_weights = None
    if args.class_weights:
        class_weights = torch.tensor([float(w) for w in args.class_weights.split(',')]).to(device)

    if args.focal_loss:
        criterion = FocalLoss(gamma=args.focal_gamma, weight=class_weights)
    else:
        criterion = nn.CrossEntropyLoss(weight=class_weights, label_smoothing=args.label_smoothing)

    # optimizer
    optimizer = torch.optim.AdamW(model.parameters(), lr=args.lr, weight_decay=args.weight_decay)
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, args.epochs)
    scaler = GradScaler() if args.fp16 else None

    best_val_acc = 0
    patience_counter = 0

    for epoch in range(args.epochs):
        # train
        model.train()
        train_loss = 0
        for batch in tqdm(train_loader, desc=f'epoch {epoch}'):
            video = batch['video'].to(device)
            labels = batch['label'].to(device)

            with autocast(enabled=args.fp16):
                outputs = model(video)
                loss = criterion(outputs, labels)

            optimizer.zero_grad()
            if scaler:
                scaler.scale(loss).backward()
                scaler.step(optimizer)
                scaler.update()
            else:
                loss.backward()
                optimizer.step()

            train_loss += loss.item()

        # validate
        model.eval()
        val_correct = 0
        val_total = 0
        with torch.no_grad():
            for batch in val_loader:
                video = batch['video'].to(device)
                labels = batch['label'].to(device)
                outputs = model(video)
                _, predicted = outputs.max(1)
                val_correct += (predicted == labels).sum().item()
                val_total += labels.size(0)

        val_acc = val_correct / val_total if val_total > 0 else 0
        scheduler.step()

        logger.info(f'epoch {epoch} | train_loss: {train_loss/len(train_loader):.4f} | val_acc: {val_acc:.4f}')

        # early stopping
        if val_acc > best_val_acc:
            best_val_acc = val_acc
            torch.save(model.state_dict(), output_dir / 'best.pt')
            patience_counter = 0
        else:
            patience_counter += 1
            if patience_counter >= args.early_stopping_patience:
                logger.info('early stopping')
                break

    logger.info(f'best val_acc: {best_val_acc:.4f}')


if __name__ == '__main__':
    args = parse_args()
    train(args)
