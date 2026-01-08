"""
multimodal_dataset.py — Dataset classes for Komal multimodal data.
"""

import os
import json
import torch
import numpy as np
from pathlib import Path
from torch.utils.data import Dataset
from typing import Dict, List, Optional


class KomalMultimodalDataset(Dataset):
    """
    Dataset for multimodal SEL data (gaze, audio, face, touch).

    Expects data in format:
        data_root/
            train/
                sample_0.pt
                sample_1.pt
                ...

    Each .pt file contains dict with keys: gaze, audio, face, touch, label
    """

    def __init__(
        self,
        data_root: str,
        split: str = 'train',
        modalities: List[str] = ['gaze', 'audio', 'face', 'touch'],
        max_seq_len: int = 1024,
        transform=None,
    ):
        self.data_root = Path(data_root)
        self.split = split
        self.modalities = modalities
        self.max_seq_len = max_seq_len
        self.transform = transform

        # find all samples
        split_dir = self.data_root / split
        if split_dir.exists():
            self.samples = sorted(split_dir.glob('*.pt'))
        else:
            # fallback: look for samples directly in data_root
            self.samples = sorted(self.data_root.glob('*.pt'))

        if not self.samples:
            # try npz format
            if split_dir.exists():
                self.samples = sorted(split_dir.glob('*.npz'))
            else:
                self.samples = sorted(self.data_root.glob('*.npz'))

    def __len__(self) -> int:
        return len(self.samples)

    def __getitem__(self, idx: int) -> Dict[str, torch.Tensor]:
        sample_path = self.samples[idx]

        # load sample
        if sample_path.suffix == '.pt':
            data = torch.load(sample_path)
        else:  # npz
            npz_data = np.load(sample_path, allow_pickle=True)
            data = {k: torch.from_numpy(npz_data[k]) for k in npz_data.files}

        output = {}

        # process each modality
        if 'gaze' in self.modalities and 'gaze' in data:
            gaze = data['gaze']
            if isinstance(gaze, np.ndarray):
                gaze = torch.from_numpy(gaze)
            gaze = self._pad_or_truncate(gaze, self.max_seq_len)
            output['gaze'] = gaze.float()

        if 'audio' in self.modalities and 'audio' in data:
            audio = data['audio']
            if isinstance(audio, np.ndarray):
                audio = torch.from_numpy(audio)
            # assume audio is spectrogram [T, n_mels]
            if audio.dim() == 1:
                # convert raw audio to simple features
                audio = audio.unfold(0, 80, 40)  # simple framing
            audio = self._pad_or_truncate(audio, self.max_seq_len)
            output['audio'] = audio.float()

        if 'face' in self.modalities and 'face' in data:
            face = data['face']
            if isinstance(face, np.ndarray):
                face = torch.from_numpy(face)
            # face can be [T, C, H, W] or [T, D]
            if face.dim() == 4:
                # flatten spatial dims
                face = face.view(face.size(0), -1)
            face = self._pad_or_truncate(face, self.max_seq_len)
            output['face'] = face.float()

        if 'touch' in self.modalities and 'touch' in data:
            touch = data['touch']
            if isinstance(touch, np.ndarray):
                touch = torch.from_numpy(touch)
            touch = self._pad_or_truncate(touch, self.max_seq_len)
            output['touch'] = touch.float()

        if 'label' in data:
            output['label'] = data['label']

        if self.transform:
            output = self.transform(output)

        return output

    def _pad_or_truncate(self, tensor: torch.Tensor, max_len: int) -> torch.Tensor:
        """Pad or truncate sequence to max_len."""
        if tensor.size(0) > max_len:
            return tensor[:max_len]
        elif tensor.size(0) < max_len:
            pad_size = max_len - tensor.size(0)
            if tensor.dim() == 1:
                padding = torch.zeros(pad_size)
            else:
                padding = torch.zeros(pad_size, *tensor.shape[1:])
            return torch.cat([tensor, padding], dim=0)
        return tensor


class GazeDataset(Dataset):
    """Dataset for eye-tracking data only."""

    def __init__(self, data_root: str, split: str = 'train'):
        self.data_root = Path(data_root)
        self.samples = []

        # find all gaze_data.npz files
        split_dir = self.data_root / split
        search_dir = split_dir if split_dir.exists() else self.data_root

        for gaze_file in search_dir.rglob('gaze_data.npz'):
            self.samples.append(gaze_file)

    def __len__(self):
        return len(self.samples)

    def __getitem__(self, idx):
        gaze_path = self.samples[idx]
        data = np.load(gaze_path)

        gaze_x = torch.from_numpy(data['gaze_x']).float()
        gaze_y = torch.from_numpy(data['gaze_y']).float()
        timestamps = torch.from_numpy(data['timestamps']).float()

        # stack into sequence [T, 3]
        gaze = torch.stack([gaze_x, gaze_y, timestamps], dim=1)

        return {'gaze': gaze}


class ImageDataset(Dataset):
    """Dataset for processed face images."""

    def __init__(self, data_root: str, split: str = 'train', transform=None):
        self.data_root = Path(data_root)
        self.transform = transform

        # find all images
        split_dir = self.data_root / split
        search_dir = split_dir if split_dir.exists() else self.data_root

        self.samples = list(search_dir.rglob('*.png'))

    def __len__(self):
        return len(self.samples)

    def __getitem__(self, idx):
        import cv2
        img_path = self.samples[idx]
        image = cv2.imread(str(img_path))
        image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

        if self.transform:
            image = self.transform(image)
        else:
            image = torch.from_numpy(image).permute(2, 0, 1).float() / 255.0

        return {'image': image, 'path': str(img_path)}
