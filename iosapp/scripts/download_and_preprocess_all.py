#!/usr/bin/env python3
"""
download_and_preprocess_all.py — Complete dataset ingestion pipeline for Komal SEL project.

Downloads, preprocesses, and extracts features from 10 multimodal datasets for
child emotion recognition, eye-tracking analysis, and SEL assessment.

Usage:
    python download_and_preprocess_all.py --data_root /path/to/data
    python download_and_preprocess_all.py --download_only
    python download_and_preprocess_all.py --preprocess_only
    python download_and_preprocess_all.py --features_only
"""

import os
import sys
import json
import hashlib
import logging
import argparse
import subprocess
import requests
import zipfile
import tarfile
import shutil
from pathlib import Path
from datetime import datetime
from concurrent.futures import ProcessPoolExecutor, ThreadPoolExecutor, as_completed
from functools import partial
from typing import Dict, List, Optional, Tuple, Any

import numpy as np
import pandas as pd
import cv2
from tqdm import tqdm
from PIL import Image

import torch
import torch.nn as nn
from torchvision import transforms
from torchvision.models import vit_b_16, ViT_B_16_Weights

try:
    import mediapipe as mp
    HAS_MEDIAPIPE = True
except ImportError:
    HAS_MEDIAPIPE = False
    logging.warning("mediapipe not installed; AU extraction will be limited")

try:
    from facenet_pytorch import MTCNN
    HAS_MTCNN = True
except ImportError:
    HAS_MTCNN = False
    logging.warning("facenet_pytorch not installed; using opencv cascade for face detection")

# configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler('pipeline.log')
    ]
)
logger = logging.getLogger(__name__)

# dataset configurations
DATASETS = {
    'cafe': {
        'name': 'CAFE - Child Affective Facial Expressions',
        'url': 'https://libguides.princeton.edu/facedatabases',
        'type': 'image',
        'restricted': True,
        'license': 'Academic use only, requires approval',
        'description': '~1,200 labeled photos (ages 2-8), 7 emotions'
    },
    'childefes': {
        'name': 'ChildEFES - Child Emotion Facial Expression Set',
        'url': 'https://pmc.ncbi.nlm.nih.gov/articles/PMC8116652',
        'type': 'video',
        'restricted': True,
        'license': 'Research approval required',
        'description': 'Photo + video expressions of children (ages 4-6)'
    },
    'asd_eyetracking': {
        'name': 'ASD Eye-Tracking Dataset',
        'url': 'https://www.mdpi.com/2306-5729/8/11/168',
        'type': 'eyetracking',
        'restricted': False,
        'download_url': 'https://zenodo.org/records/8337375/files/ASD_Eye_Tracking.zip',
        'license': 'CC BY 4.0',
        'description': '29 ASD + 30 TD children; 2.16M gaze rows'
    },
    'adhd_eyetracking': {
        'name': 'ADHD Eye-tracking + Pupil Dataset',
        'url': 'https://www.nature.com/articles/s41597-019-0037-2',
        'type': 'eyetracking',
        'restricted': False,
        'download_url': 'https://figshare.com/ndownloader/files/14027217',
        'license': 'CC BY 4.0',
        'description': 'Gaze + pupil dilation from visuospatial tasks'
    },
    'babyexp': {
        'name': 'BabyExp Dataset',
        'url': 'https://www.mdpi.com/2079-9292/12/11/2416',
        'type': 'image',
        'restricted': True,
        'license': 'Contact authors',
        'description': '~12k labeled images (Happy/Normal/Sad)'
    },
    'teyed': {
        'name': 'TEyeD - Twenty-One Eye Tracking Dataset',
        'url': 'https://arxiv.org/abs/2102.02115',
        'type': 'eyetracking',
        'restricted': False,
        'download_url': 'https://github.com/MikhailKulyabin/TEyeD',
        'license': 'MIT',
        'description': '20M+ eye images, gaze vectors, segmentation'
    },
    'fer2013': {
        'name': 'FER-2013',
        'url': 'https://www.kaggle.com/datasets/msambare/fer2013',
        'type': 'image',
        'restricted': False,
        'kaggle_dataset': 'msambare/fer2013',
        'license': 'Public domain',
        'description': '35k+ facial emotion images'
    },
    'affectnet': {
        'name': 'AffectNet',
        'url': 'http://mohammadmahoor.com/affectnet',
        'type': 'image',
        'restricted': True,
        'license': 'Academic use, requires approval',
        'description': '1M facial emotion images + valence/arousal'
    },
    'omg_emotion': {
        'name': 'OMG-Emotion Dataset',
        'url': 'https://github.com/knowledgetechnologyuhh/OMG',
        'type': 'video',
        'restricted': False,
        'download_url': 'https://github.com/knowledgetechnologyuhh/OMG',
        'license': 'Research use',
        'description': 'Video clips with temporal emotion annotations'
    },
    'sewa': {
        'name': 'SEWA Dataset',
        'url': 'https://sewadataset.eu',
        'type': 'multimodal',
        'restricted': True,
        'license': 'EULA required',
        'description': 'Audiovisual emotion under naturalistic conditions'
    }
}


class FaceDetector:
    """Face detection and alignment using MTCNN or OpenCV cascade."""

    def __init__(self, device='cuda' if torch.cuda.is_available() else 'cpu'):
        self.device = device
        if HAS_MTCNN:
            self.detector = MTCNN(
                image_size=224,
                margin=20,
                device=device,
                post_process=False
            )
            self.use_mtcnn = True
        else:
            cascade_path = cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'
            self.detector = cv2.CascadeClassifier(cascade_path)
            self.use_mtcnn = False

    def detect_and_align(self, image: np.ndarray) -> Optional[np.ndarray]:
        """Detect face, crop, and align to 224x224."""
        try:
            if self.use_mtcnn:
                # convert to PIL for MTCNN
                if isinstance(image, np.ndarray):
                    image_pil = Image.fromarray(cv2.cvtColor(image, cv2.COLOR_BGR2RGB))
                else:
                    image_pil = image

                face = self.detector(image_pil)
                if face is not None:
                    # convert back to numpy
                    face_np = face.permute(1, 2, 0).cpu().numpy()
                    face_np = ((face_np + 1) * 127.5).astype(np.uint8)
                    return face_np
            else:
                # opencv cascade fallback
                gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
                faces = self.detector.detectMultiScale(gray, 1.1, 4)
                if len(faces) > 0:
                    x, y, w, h = faces[0]
                    face = image[y:y+h, x:x+w]
                    face = cv2.resize(face, (224, 224))
                    return cv2.cvtColor(face, cv2.COLOR_BGR2RGB)
        except Exception as e:
            logger.debug(f"face detection failed: {e}")

        return None


class FeatureExtractor:
    """Extract ViT embeddings and AU features."""

    def __init__(self, device='cuda' if torch.cuda.is_available() else 'cpu'):
        self.device = device

        # load ViT
        logger.info("loading ViT-B/16 for feature extraction...")
        self.vit = vit_b_16(weights=ViT_B_16_Weights.IMAGENET1K_V1)
        self.vit.heads = nn.Identity()  # remove classification head
        self.vit = self.vit.to(device).eval()

        self.transform = transforms.Compose([
            transforms.ToPILImage(),
            transforms.Resize((224, 224)),
            transforms.ToTensor(),
            transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
        ])

        # mediapipe face mesh for AU extraction
        if HAS_MEDIAPIPE:
            self.mp_face_mesh = mp.solutions.face_mesh.FaceMesh(
                static_image_mode=True,
                max_num_faces=1,
                refine_landmarks=True,
                min_detection_confidence=0.5
            )
        else:
            self.mp_face_mesh = None

    @torch.no_grad()
    def extract_vit_embedding(self, image: np.ndarray) -> np.ndarray:
        """Extract 768-dim ViT embedding from image."""
        try:
            tensor = self.transform(image).unsqueeze(0).to(self.device)
            embedding = self.vit(tensor).cpu().numpy().flatten()
            return embedding
        except Exception as e:
            logger.debug(f"ViT extraction failed: {e}")
            return np.zeros(768)

    def extract_action_units(self, image: np.ndarray) -> Dict[str, float]:
        """Extract facial action units using MediaPipe landmarks."""
        aus = {}
        if self.mp_face_mesh is None:
            return aus

        try:
            results = self.mp_face_mesh.process(cv2.cvtColor(image, cv2.COLOR_BGR2RGB))
            if results.multi_face_landmarks:
                landmarks = results.multi_face_landmarks[0].landmark

                # compute AU approximations from landmarks
                # AU1: inner brow raiser
                aus['AU1'] = abs(landmarks[21].y - landmarks[159].y) * 10
                # AU2: outer brow raiser
                aus['AU2'] = abs(landmarks[22].y - landmarks[145].y) * 10
                # AU4: brow lowerer
                aus['AU4'] = 1 - abs(landmarks[21].y - landmarks[22].y) * 5
                # AU6: cheek raiser
                aus['AU6'] = abs(landmarks[234].y - landmarks[93].y) * 10
                # AU12: lip corner puller (smile)
                aus['AU12'] = abs(landmarks[61].x - landmarks[291].x) * 5
                # AU15: lip corner depressor
                aus['AU15'] = abs(landmarks[17].y - landmarks[0].y) * 10
                # AU20: lip stretcher
                aus['AU20'] = abs(landmarks[61].y - landmarks[291].y) * 10
                # AU25: lips part
                aus['AU25'] = abs(landmarks[13].y - landmarks[14].y) * 20

        except Exception as e:
            logger.debug(f"AU extraction failed: {e}")

        return aus


class GazeAnalyzer:
    """Analyze eye-tracking data: fixations, saccades, metrics."""

    def __init__(self, screen_width=1920, screen_height=1080):
        self.screen_width = screen_width
        self.screen_height = screen_height

    def compute_fixations_idt(
        self,
        gaze_x: np.ndarray,
        gaze_y: np.ndarray,
        timestamps: np.ndarray,
        dispersion_threshold: float = 50,
        duration_threshold: float = 100
    ) -> List[Dict]:
        """I-DT algorithm for fixation detection."""
        fixations = []
        i = 0
        n = len(gaze_x)

        while i < n:
            # find window that satisfies dispersion threshold
            j = i
            while j < n:
                window_x = gaze_x[i:j+1]
                window_y = gaze_y[i:j+1]
                dispersion = (window_x.max() - window_x.min()) + (window_y.max() - window_y.min())

                if dispersion > dispersion_threshold:
                    break
                j += 1

            # check duration
            if j > i:
                duration = timestamps[j-1] - timestamps[i]
                if duration >= duration_threshold:
                    fixations.append({
                        'start_idx': i,
                        'end_idx': j - 1,
                        'x': float(np.mean(gaze_x[i:j])),
                        'y': float(np.mean(gaze_y[i:j])),
                        'duration': float(duration),
                        'dispersion': float(dispersion)
                    })
                i = j
            else:
                i += 1

        return fixations

    def detect_microsaccades_engbert(
        self,
        gaze_x: np.ndarray,
        gaze_y: np.ndarray,
        sampling_rate: float = 500,
        velocity_threshold: float = 6
    ) -> List[Dict]:
        """Engbert algorithm for microsaccade detection."""
        # compute velocities
        vx = np.gradient(gaze_x) * sampling_rate
        vy = np.gradient(gaze_y) * sampling_rate

        # compute threshold based on median absolute deviation
        sigma_x = np.sqrt(np.median(vx**2) - np.median(vx)**2)
        sigma_y = np.sqrt(np.median(vy**2) - np.median(vy)**2)

        # detect microsaccades
        microsaccades = []
        threshold_x = velocity_threshold * sigma_x
        threshold_y = velocity_threshold * sigma_y

        # ellipse criterion
        is_saccade = (vx / threshold_x)**2 + (vy / threshold_y)**2 > 1

        # find contiguous regions
        changes = np.diff(is_saccade.astype(int))
        starts = np.where(changes == 1)[0] + 1
        ends = np.where(changes == -1)[0] + 1

        for start, end in zip(starts, ends):
            if end - start >= 3:  # minimum duration
                microsaccades.append({
                    'start_idx': int(start),
                    'end_idx': int(end),
                    'amplitude': float(np.sqrt(
                        (gaze_x[end] - gaze_x[start])**2 +
                        (gaze_y[end] - gaze_y[start])**2
                    )),
                    'peak_velocity': float(np.max(np.sqrt(vx[start:end]**2 + vy[start:end]**2)))
                })

        return microsaccades

    def compute_gaze_heatmap(
        self,
        gaze_x: np.ndarray,
        gaze_y: np.ndarray,
        bins: int = 50
    ) -> np.ndarray:
        """Compute 2D histogram heatmap of gaze positions."""
        heatmap, _, _ = np.histogram2d(
            gaze_x, gaze_y,
            bins=bins,
            range=[[0, self.screen_width], [0, self.screen_height]]
        )
        return heatmap / (heatmap.sum() + 1e-8)

    def compute_scanpath_entropy(self, gaze_x: np.ndarray, gaze_y: np.ndarray) -> float:
        """Compute entropy of scanpath (gaze exploration measure)."""
        heatmap = self.compute_gaze_heatmap(gaze_x, gaze_y, bins=20)
        heatmap_flat = heatmap.flatten()
        heatmap_flat = heatmap_flat[heatmap_flat > 0]
        entropy = -np.sum(heatmap_flat * np.log2(heatmap_flat))
        return float(entropy)

    def compute_metrics(
        self,
        gaze_x: np.ndarray,
        gaze_y: np.ndarray,
        timestamps: np.ndarray
    ) -> Dict[str, float]:
        """Compute comprehensive gaze metrics."""
        fixations = self.compute_fixations_idt(gaze_x, gaze_y, timestamps)
        microsaccades = self.detect_microsaccades_engbert(gaze_x, gaze_y)

        metrics = {
            'num_fixations': len(fixations),
            'mean_fixation_duration': np.mean([f['duration'] for f in fixations]) if fixations else 0,
            'num_microsaccades': len(microsaccades),
            'saccade_rate': len(microsaccades) / ((timestamps[-1] - timestamps[0]) / 1000) if len(timestamps) > 1 else 0,
            'scanpath_entropy': self.compute_scanpath_entropy(gaze_x, gaze_y),
            'gaze_dispersion': float(np.std(gaze_x) + np.std(gaze_y))
        }

        return metrics


class DatasetDownloader:
    """Handle downloading datasets."""

    def __init__(self, data_root: Path):
        self.data_root = data_root
        self.raw_dir = data_root / 'raw'
        self.raw_dir.mkdir(parents=True, exist_ok=True)

    def download_with_retry(self, url: str, output_path: Path, max_retries: int = 3) -> bool:
        """Download file with retry logic."""
        for attempt in range(max_retries):
            try:
                logger.info(f"downloading {url} (attempt {attempt + 1}/{max_retries})")
                response = requests.get(url, stream=True, timeout=60)
                response.raise_for_status()

                total_size = int(response.headers.get('content-length', 0))
                with open(output_path, 'wb') as f:
                    with tqdm(total=total_size, unit='B', unit_scale=True, desc=output_path.name) as pbar:
                        for chunk in response.iter_content(chunk_size=8192):
                            f.write(chunk)
                            pbar.update(len(chunk))

                return True
            except Exception as e:
                logger.warning(f"download failed: {e}")
                if attempt < max_retries - 1:
                    import time
                    time.sleep(2 ** attempt)

        return False

    def download_kaggle(self, dataset_name: str, output_dir: Path) -> bool:
        """Download dataset from Kaggle."""
        try:
            output_dir.mkdir(parents=True, exist_ok=True)
            cmd = ['kaggle', 'datasets', 'download', '-d', dataset_name, '-p', str(output_dir), '--unzip']
            result = subprocess.run(cmd, capture_output=True, text=True)
            if result.returncode == 0:
                logger.info(f"kaggle download complete: {dataset_name}")
                return True
            else:
                logger.error(f"kaggle download failed: {result.stderr}")
        except Exception as e:
            logger.error(f"kaggle download error: {e}")

        return False

    def create_restricted_placeholder(self, dataset_key: str, config: Dict) -> None:
        """Create placeholder for restricted datasets."""
        dataset_dir = self.raw_dir / dataset_key
        dataset_dir.mkdir(parents=True, exist_ok=True)

        readme_content = f"""# {config['name']}

## Access Information
- **URL**: {config['url']}
- **License**: {config['license']}
- **Description**: {config['description']}

## Download Instructions
This dataset requires manual download due to access restrictions.

1. Visit: {config['url']}
2. Follow the registration/approval process
3. Download the dataset files
4. Extract to this directory: {dataset_dir}

## Expected Structure
Place raw data files in this directory after download.
"""

        readme_path = dataset_dir / 'README_DOWNLOAD.md'
        with open(readme_path, 'w') as f:
            f.write(readme_content)

        logger.info(f"created placeholder for restricted dataset: {dataset_key}")

    def download_dataset(self, dataset_key: str, config: Dict) -> bool:
        """Download a single dataset."""
        dataset_dir = self.raw_dir / dataset_key

        if config.get('restricted', False):
            self.create_restricted_placeholder(dataset_key, config)
            return False

        dataset_dir.mkdir(parents=True, exist_ok=True)

        # kaggle datasets
        if 'kaggle_dataset' in config:
            return self.download_kaggle(config['kaggle_dataset'], dataset_dir)

        # direct download
        if 'download_url' in config:
            url = config['download_url']
            filename = url.split('/')[-1]
            if not filename or '.' not in filename:
                filename = f"{dataset_key}.zip"

            output_path = dataset_dir / filename
            success = self.download_with_retry(url, output_path)

            if success:
                # extract if archive
                if filename.endswith('.zip'):
                    with zipfile.ZipFile(output_path, 'r') as zf:
                        zf.extractall(dataset_dir)
                elif filename.endswith('.tar.gz') or filename.endswith('.tgz'):
                    with tarfile.open(output_path, 'r:gz') as tf:
                        tf.extractall(dataset_dir)

                return True

        return False


class DatasetPreprocessor:
    """Preprocess datasets into unified format."""

    def __init__(self, data_root: Path, num_workers: int = 4):
        self.data_root = data_root
        self.raw_dir = data_root / 'raw'
        self.processed_dir = data_root / 'processed'
        self.processed_dir.mkdir(parents=True, exist_ok=True)
        self.num_workers = num_workers

        self.face_detector = FaceDetector()
        self.gaze_analyzer = GazeAnalyzer()

    def process_image_dataset(self, dataset_key: str) -> Dict:
        """Process image dataset: detect faces, crop, align."""
        raw_dir = self.raw_dir / dataset_key
        processed_dir = self.processed_dir / dataset_key
        processed_dir.mkdir(parents=True, exist_ok=True)

        stats = {'processed': 0, 'failed': 0}

        # find all images
        image_extensions = ['.jpg', '.jpeg', '.png', '.bmp']
        image_files = []
        for ext in image_extensions:
            image_files.extend(raw_dir.rglob(f'*{ext}'))
            image_files.extend(raw_dir.rglob(f'*{ext.upper()}'))

        logger.info(f"processing {len(image_files)} images from {dataset_key}")

        for img_path in tqdm(image_files, desc=f"processing {dataset_key}"):
            try:
                # load image
                image = cv2.imread(str(img_path))
                if image is None:
                    stats['failed'] += 1
                    continue

                # detect and align face
                face = self.face_detector.detect_and_align(image)
                if face is None:
                    stats['failed'] += 1
                    continue

                # save processed image
                rel_path = img_path.relative_to(raw_dir)
                output_path = processed_dir / rel_path.with_suffix('.png')
                output_path.parent.mkdir(parents=True, exist_ok=True)

                cv2.imwrite(str(output_path), cv2.cvtColor(face, cv2.COLOR_RGB2BGR))

                # save metadata
                metadata = {
                    'original_path': str(img_path),
                    'processed_path': str(output_path),
                    'size': [224, 224],
                    'timestamp': datetime.now().isoformat()
                }

                meta_path = output_path.with_suffix('.json')
                with open(meta_path, 'w') as f:
                    json.dump(metadata, f, indent=2)

                stats['processed'] += 1

            except Exception as e:
                logger.debug(f"failed to process {img_path}: {e}")
                stats['failed'] += 1

        return stats

    def process_video_dataset(self, dataset_key: str, fps: int = 25) -> Dict:
        """Process video dataset: extract frames, track faces."""
        raw_dir = self.raw_dir / dataset_key
        processed_dir = self.processed_dir / dataset_key
        processed_dir.mkdir(parents=True, exist_ok=True)

        stats = {'videos': 0, 'frames': 0, 'failed': 0}

        # find videos
        video_extensions = ['.mp4', '.avi', '.mov', '.mkv']
        video_files = []
        for ext in video_extensions:
            video_files.extend(raw_dir.rglob(f'*{ext}'))
            video_files.extend(raw_dir.rglob(f'*{ext.upper()}'))

        logger.info(f"processing {len(video_files)} videos from {dataset_key}")

        for video_path in tqdm(video_files, desc=f"processing {dataset_key}"):
            try:
                cap = cv2.VideoCapture(str(video_path))
                video_fps = cap.get(cv2.CAP_PROP_FPS)
                frame_interval = max(1, int(video_fps / fps))

                # output directory for this video
                rel_path = video_path.relative_to(raw_dir)
                video_output_dir = processed_dir / rel_path.stem
                video_output_dir.mkdir(parents=True, exist_ok=True)

                frame_idx = 0
                saved_frames = 0

                while True:
                    ret, frame = cap.read()
                    if not ret:
                        break

                    if frame_idx % frame_interval == 0:
                        # detect face
                        face = self.face_detector.detect_and_align(frame)
                        if face is not None:
                            frame_path = video_output_dir / f'frame_{saved_frames:06d}.png'
                            cv2.imwrite(str(frame_path), cv2.cvtColor(face, cv2.COLOR_RGB2BGR))
                            saved_frames += 1

                    frame_idx += 1

                cap.release()
                stats['videos'] += 1
                stats['frames'] += saved_frames

                # save video metadata
                meta = {
                    'original_path': str(video_path),
                    'num_frames': saved_frames,
                    'target_fps': fps,
                    'original_fps': video_fps
                }
                with open(video_output_dir / 'metadata.json', 'w') as f:
                    json.dump(meta, f, indent=2)

            except Exception as e:
                logger.debug(f"failed to process {video_path}: {e}")
                stats['failed'] += 1

        return stats

    def process_eyetracking_dataset(self, dataset_key: str) -> Dict:
        """Process eye-tracking CSV data."""
        raw_dir = self.raw_dir / dataset_key
        processed_dir = self.processed_dir / dataset_key
        processed_dir.mkdir(parents=True, exist_ok=True)

        stats = {'files': 0, 'samples': 0, 'failed': 0}

        # find CSV files
        csv_files = list(raw_dir.rglob('*.csv'))

        logger.info(f"processing {len(csv_files)} eye-tracking files from {dataset_key}")

        for csv_path in tqdm(csv_files, desc=f"processing {dataset_key}"):
            try:
                df = pd.read_csv(csv_path)

                # try to find gaze columns
                gaze_x_col = None
                gaze_y_col = None
                time_col = None

                for col in df.columns:
                    col_lower = col.lower()
                    if 'gaze' in col_lower and 'x' in col_lower:
                        gaze_x_col = col
                    elif 'gaze' in col_lower and 'y' in col_lower:
                        gaze_y_col = col
                    elif 'time' in col_lower or 'timestamp' in col_lower:
                        time_col = col

                if gaze_x_col is None or gaze_y_col is None:
                    stats['failed'] += 1
                    continue

                gaze_x = df[gaze_x_col].values.astype(float)
                gaze_y = df[gaze_y_col].values.astype(float)

                if time_col:
                    timestamps = df[time_col].values.astype(float)
                else:
                    timestamps = np.arange(len(gaze_x)) * 2  # assume 500Hz

                # remove NaN values
                valid = ~(np.isnan(gaze_x) | np.isnan(gaze_y))
                gaze_x = gaze_x[valid]
                gaze_y = gaze_y[valid]
                timestamps = timestamps[valid]

                if len(gaze_x) < 10:
                    stats['failed'] += 1
                    continue

                # compute metrics
                metrics = self.gaze_analyzer.compute_metrics(gaze_x, gaze_y, timestamps)
                fixations = self.gaze_analyzer.compute_fixations_idt(gaze_x, gaze_y, timestamps)
                microsaccades = self.gaze_analyzer.detect_microsaccades_engbert(gaze_x, gaze_y)
                heatmap = self.gaze_analyzer.compute_gaze_heatmap(gaze_x, gaze_y)

                # save processed data
                rel_path = csv_path.relative_to(raw_dir)
                output_path = processed_dir / rel_path.stem
                output_path.mkdir(parents=True, exist_ok=True)

                np.savez_compressed(
                    output_path / 'gaze_data.npz',
                    gaze_x=gaze_x,
                    gaze_y=gaze_y,
                    timestamps=timestamps,
                    heatmap=heatmap
                )

                with open(output_path / 'metrics.json', 'w') as f:
                    json.dump(metrics, f, indent=2)

                with open(output_path / 'fixations.json', 'w') as f:
                    json.dump(fixations, f, indent=2)

                with open(output_path / 'microsaccades.json', 'w') as f:
                    json.dump(microsaccades, f, indent=2)

                stats['files'] += 1
                stats['samples'] += len(gaze_x)

            except Exception as e:
                logger.debug(f"failed to process {csv_path}: {e}")
                stats['failed'] += 1

        return stats

    def preprocess_dataset(self, dataset_key: str, config: Dict) -> Dict:
        """Preprocess a single dataset based on type."""
        dtype = config.get('type', 'image')

        if dtype == 'image':
            return self.process_image_dataset(dataset_key)
        elif dtype == 'video':
            return self.process_video_dataset(dataset_key)
        elif dtype == 'eyetracking':
            return self.process_eyetracking_dataset(dataset_key)
        elif dtype == 'multimodal':
            # process all modalities
            stats = {}
            stats.update(self.process_image_dataset(dataset_key))
            stats.update(self.process_video_dataset(dataset_key))
            stats.update(self.process_eyetracking_dataset(dataset_key))
            return stats

        return {}


class FeatureGenerator:
    """Generate compute-heavy features for all datasets."""

    def __init__(self, data_root: Path, batch_size: int = 32):
        self.data_root = data_root
        self.processed_dir = data_root / 'processed'
        self.features_dir = data_root / 'features'
        self.features_dir.mkdir(parents=True, exist_ok=True)
        self.batch_size = batch_size

        self.feature_extractor = FeatureExtractor()

    def extract_image_features(self, dataset_key: str) -> Dict:
        """Extract ViT embeddings and AUs for all images."""
        processed_dir = self.processed_dir / dataset_key
        features_dir = self.features_dir / dataset_key
        features_dir.mkdir(parents=True, exist_ok=True)

        stats = {'processed': 0, 'failed': 0}

        # find all processed images
        image_files = list(processed_dir.rglob('*.png'))

        if not image_files:
            return stats

        logger.info(f"extracting features from {len(image_files)} images in {dataset_key}")

        all_embeddings = []
        all_aus = []
        all_paths = []

        for img_path in tqdm(image_files, desc=f"features {dataset_key}"):
            try:
                image = cv2.imread(str(img_path))
                if image is None:
                    stats['failed'] += 1
                    continue

                # extract ViT embedding
                embedding = self.feature_extractor.extract_vit_embedding(image)

                # extract action units
                aus = self.feature_extractor.extract_action_units(image)

                all_embeddings.append(embedding)
                all_aus.append(aus)
                all_paths.append(str(img_path.relative_to(processed_dir)))

                stats['processed'] += 1

            except Exception as e:
                logger.debug(f"failed to extract features from {img_path}: {e}")
                stats['failed'] += 1

        # save features as npz shards
        if all_embeddings:
            embeddings_array = np.stack(all_embeddings)

            # convert AUs to array
            au_keys = sorted(set(k for aus in all_aus for k in aus.keys()))
            aus_array = np.zeros((len(all_aus), len(au_keys)))
            for i, aus in enumerate(all_aus):
                for j, key in enumerate(au_keys):
                    aus_array[i, j] = aus.get(key, 0)

            np.savez_compressed(
                features_dir / 'image_features.npz',
                embeddings=embeddings_array,
                action_units=aus_array,
                au_keys=au_keys,
                paths=all_paths
            )

            logger.info(f"saved {len(all_embeddings)} embeddings to {features_dir}")

        return stats

    def extract_video_features(self, dataset_key: str) -> Dict:
        """Extract temporal features from video frames."""
        processed_dir = self.processed_dir / dataset_key
        features_dir = self.features_dir / dataset_key
        features_dir.mkdir(parents=True, exist_ok=True)

        stats = {'videos': 0, 'frames': 0}

        # find video directories
        video_dirs = [d for d in processed_dir.iterdir() if d.is_dir()]

        logger.info(f"extracting video features from {len(video_dirs)} videos in {dataset_key}")

        for video_dir in tqdm(video_dirs, desc=f"video features {dataset_key}"):
            try:
                frames = sorted(video_dir.glob('frame_*.png'))
                if not frames:
                    continue

                embeddings = []
                aus_sequence = []

                for frame_path in frames:
                    image = cv2.imread(str(frame_path))
                    if image is None:
                        continue

                    embedding = self.feature_extractor.extract_vit_embedding(image)
                    aus = self.feature_extractor.extract_action_units(image)

                    embeddings.append(embedding)
                    aus_sequence.append(list(aus.values()) if aus else [0] * 8)

                if embeddings:
                    # save video features
                    output_dir = features_dir / video_dir.name
                    output_dir.mkdir(parents=True, exist_ok=True)

                    np.savez_compressed(
                        output_dir / 'video_features.npz',
                        embeddings=np.stack(embeddings),
                        aus_sequence=np.array(aus_sequence)
                    )

                    stats['videos'] += 1
                    stats['frames'] += len(embeddings)

            except Exception as e:
                logger.debug(f"failed to extract features from {video_dir}: {e}")

        return stats

    def generate_features(self, dataset_key: str, config: Dict) -> Dict:
        """Generate all features for a dataset."""
        dtype = config.get('type', 'image')
        stats = {}

        if dtype in ['image', 'multimodal']:
            stats.update(self.extract_image_features(dataset_key))

        if dtype in ['video', 'multimodal']:
            stats.update(self.extract_video_features(dataset_key))

        return stats


def compute_sha256(filepath: Path) -> str:
    """Compute SHA256 hash of file."""
    sha256_hash = hashlib.sha256()
    with open(filepath, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            sha256_hash.update(chunk)
    return sha256_hash.hexdigest()


def generate_manifest(data_root: Path) -> None:
    """Generate dataset manifest CSV."""
    manifest_data = []

    processed_dir = data_root / 'processed'
    features_dir = data_root / 'features'

    for dataset_key, config in DATASETS.items():
        dataset_processed = processed_dir / dataset_key
        dataset_features = features_dir / dataset_key

        # count samples
        num_samples = 0
        sha256 = ''

        if dataset_processed.exists():
            files = list(dataset_processed.rglob('*'))
            num_samples = len([f for f in files if f.is_file() and f.suffix in ['.png', '.npz', '.json']])

            # compute hash of first file for verification
            data_files = [f for f in files if f.suffix in ['.png', '.npz']]
            if data_files:
                sha256 = compute_sha256(data_files[0])[:16] + '...'

        manifest_data.append({
            'dataset_name': dataset_key,
            'display_name': config['name'],
            'original_url': config['url'],
            'processed_path': str(dataset_processed) if dataset_processed.exists() else '',
            'features_path': str(dataset_features) if dataset_features.exists() else '',
            'num_samples': num_samples,
            'sha256_sample': sha256,
            'license': config['license'],
            'restricted': config.get('restricted', False)
        })

    # save manifest
    manifest_df = pd.DataFrame(manifest_data)
    manifest_path = data_root / 'dataset_manifest.csv'
    manifest_df.to_csv(manifest_path, index=False)
    logger.info(f"manifest saved to {manifest_path}")


def main():
    parser = argparse.ArgumentParser(description='Komal Dataset Ingestion Pipeline')
    parser.add_argument('--data_root', type=str, default='./data', help='Root directory for data')
    parser.add_argument('--download_only', action='store_true', help='Only download datasets')
    parser.add_argument('--preprocess_only', action='store_true', help='Only preprocess datasets')
    parser.add_argument('--features_only', action='store_true', help='Only extract features')
    parser.add_argument('--datasets', type=str, nargs='+', default=None, help='Specific datasets to process')
    parser.add_argument('--num_workers', type=int, default=4, help='Number of parallel workers')
    parser.add_argument('--batch_size', type=int, default=32, help='Batch size for feature extraction')

    args = parser.parse_args()

    data_root = Path(args.data_root)
    data_root.mkdir(parents=True, exist_ok=True)

    # filter datasets if specified
    datasets_to_process = args.datasets if args.datasets else list(DATASETS.keys())

    logger.info(f"processing datasets: {datasets_to_process}")

    # determine what to run
    run_download = not args.preprocess_only and not args.features_only
    run_preprocess = not args.download_only and not args.features_only
    run_features = not args.download_only and not args.preprocess_only

    # download phase
    if run_download:
        logger.info("=== DOWNLOAD PHASE ===")
        downloader = DatasetDownloader(data_root)

        for dataset_key in datasets_to_process:
            if dataset_key not in DATASETS:
                logger.warning(f"unknown dataset: {dataset_key}")
                continue

            config = DATASETS[dataset_key]
            logger.info(f"downloading {config['name']}...")
            success = downloader.download_dataset(dataset_key, config)

            if success:
                logger.info(f"downloaded {dataset_key}")
            else:
                logger.info(f"skipped {dataset_key} (restricted or failed)")

    # preprocess phase
    if run_preprocess:
        logger.info("=== PREPROCESS PHASE ===")
        preprocessor = DatasetPreprocessor(data_root, num_workers=args.num_workers)

        for dataset_key in datasets_to_process:
            if dataset_key not in DATASETS:
                continue

            config = DATASETS[dataset_key]
            raw_dir = data_root / 'raw' / dataset_key

            if not raw_dir.exists() or not any(raw_dir.iterdir()):
                logger.info(f"skipping {dataset_key} (no raw data)")
                continue

            logger.info(f"preprocessing {config['name']}...")
            stats = preprocessor.preprocess_dataset(dataset_key, config)
            logger.info(f"preprocessing stats for {dataset_key}: {stats}")

    # feature extraction phase
    if run_features:
        logger.info("=== FEATURE EXTRACTION PHASE ===")
        generator = FeatureGenerator(data_root, batch_size=args.batch_size)

        for dataset_key in datasets_to_process:
            if dataset_key not in DATASETS:
                continue

            config = DATASETS[dataset_key]
            processed_dir = data_root / 'processed' / dataset_key

            if not processed_dir.exists():
                logger.info(f"skipping {dataset_key} (no processed data)")
                continue

            logger.info(f"extracting features for {config['name']}...")
            stats = generator.generate_features(dataset_key, config)
            logger.info(f"feature extraction stats for {dataset_key}: {stats}")

    # generate manifest
    logger.info("=== GENERATING MANIFEST ===")
    generate_manifest(data_root)

    logger.info("pipeline complete!")


if __name__ == '__main__':
    main()
