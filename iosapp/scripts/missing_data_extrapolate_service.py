#!/usr/bin/env python3
"""
missing_data_extrapolate_service.py — Hybrid imputation for session time series data.
Uses interpolation, Kalman smoothing, and Transformer model for gap filling.
"""

import argparse
import json
import logging
import os
import hashlib
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Tuple, Optional
import numpy as np

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)

# PyTorch imports
try:
    import torch
    import torch.nn as nn
    TORCH_AVAILABLE = True
except ImportError:
    TORCH_AVAILABLE = False
    logger.warning("PyTorch not available, Transformer imputation disabled")

# Scipy for interpolation and Kalman
try:
    from scipy.interpolate import interp1d, Akima1DInterpolator
    from scipy.linalg import solve_discrete_are
    SCIPY_AVAILABLE = True
except ImportError:
    SCIPY_AVAILABLE = False
    logger.warning("SciPy not available, advanced interpolation disabled")


def parse_args():
    parser = argparse.ArgumentParser(description='Impute missing data in session JSONs')
    parser.add_argument('--input', type=str, help='Input session JSON file')
    parser.add_argument('--output', type=str, help='Output imputed JSON file')
    parser.add_argument('--batch_dir', type=str, help='Directory with raw sessions')
    parser.add_argument('--out_dir', type=str, default='./data/imputed_sessions', help='Output directory for batch')
    parser.add_argument('--report_dir', type=str, default='./impute_reports', help='Directory for QA plots')
    parser.add_argument('--heavy_impute', action='store_true', help='Use Transformer model (GPU)')
    parser.add_argument('--fast_impute', action='store_true', help='Only use interpolation/Kalman')
    parser.add_argument('--model_path', type=str, default='./models/impute_transformer.pt', help='Pretrained model')
    parser.add_argument('--dry_run', action='store_true', help='Preview without saving')
    return parser.parse_args()


# Lightweight Transformer for time series imputation
if TORCH_AVAILABLE:
    class TimeSeriesTransformer(nn.Module):
        """Small Transformer for time series gap imputation."""

        def __init__(self, input_dim=32, d_model=64, nhead=4, num_layers=2, dropout=0.1):
            super().__init__()
            self.input_projection = nn.Linear(input_dim, d_model)

            encoder_layer = nn.TransformerEncoderLayer(
                d_model=d_model, nhead=nhead, dim_feedforward=128,
                dropout=dropout, batch_first=True
            )
            self.transformer = nn.TransformerEncoder(encoder_layer, num_layers=num_layers)

            self.output_projection = nn.Linear(d_model, input_dim)

        def forward(self, x, mask=None):
            # x: (batch, seq_len, input_dim)
            x = self.input_projection(x)
            x = self.transformer(x, src_key_padding_mask=mask)
            x = self.output_projection(x)
            return x


    def create_synthetic_training_data(n_samples=1000, seq_len=128, n_features=32):
        """Create synthetic time series with gaps for pretraining."""
        data = []
        targets = []
        masks = []

        for _ in range(n_samples):
            # Generate smooth time series
            t = np.linspace(0, 4 * np.pi, seq_len)
            series = np.zeros((seq_len, n_features))

            for f in range(n_features):
                freq = np.random.uniform(0.5, 2.0)
                phase = np.random.uniform(0, 2 * np.pi)
                series[:, f] = np.sin(freq * t + phase) + np.random.randn(seq_len) * 0.1

            # Create gaps
            mask = np.zeros(seq_len, dtype=bool)
            n_gaps = np.random.randint(1, 4)
            for _ in range(n_gaps):
                gap_start = np.random.randint(10, seq_len - 20)
                gap_len = np.random.randint(5, 15)
                mask[gap_start:gap_start + gap_len] = True

            # Create input with masked values set to 0
            masked_series = series.copy()
            masked_series[mask] = 0

            data.append(masked_series)
            targets.append(series)
            masks.append(mask)

        return (torch.FloatTensor(np.array(data)),
                torch.FloatTensor(np.array(targets)),
                torch.BoolTensor(np.array(masks)))


    def train_imputation_model(model, n_epochs=50, batch_size=32):
        """Pretrain the imputation model on synthetic data."""
        data, targets, masks = create_synthetic_training_data()

        optimizer = torch.optim.Adam(model.parameters(), lr=1e-3)
        criterion = nn.MSELoss()

        n_samples = len(data)

        for epoch in range(n_epochs):
            indices = torch.randperm(n_samples)
            epoch_loss = 0

            for i in range(0, n_samples, batch_size):
                batch_idx = indices[i:i + batch_size]
                batch_data = data[batch_idx]
                batch_targets = targets[batch_idx]
                batch_masks = masks[batch_idx]

                optimizer.zero_grad()
                outputs = model(batch_data)

                # Only compute loss on masked positions
                loss = 0
                for j in range(len(batch_idx)):
                    mask = batch_masks[j]
                    if mask.any():
                        loss += criterion(outputs[j, mask], batch_targets[j, mask])

                if loss > 0:
                    loss.backward()
                    optimizer.step()
                    epoch_loss += loss.item()

            if (epoch + 1) % 10 == 0:
                logger.info(f"Epoch {epoch + 1}, Loss: {epoch_loss:.4f}")

        return model


def detect_gaps(timestamps: np.ndarray, values: np.ndarray) -> List[Dict]:
    """Detect missing data regions based on timestamps and NaN values."""
    gaps = []

    # Calculate expected sample interval
    diffs = np.diff(timestamps)
    median_interval = np.median(diffs)

    # Find large gaps in timestamps
    gap_threshold = median_interval * 2

    i = 0
    while i < len(timestamps) - 1:
        if diffs[i] > gap_threshold or np.isnan(values[i]).any():
            gap_start = i
            gap_duration = 0

            while i < len(timestamps) - 1 and (diffs[i] > gap_threshold or np.isnan(values[i]).any()):
                gap_duration += diffs[i]
                i += 1

            gaps.append({
                'start_idx': gap_start,
                'end_idx': i,
                'duration_ms': float(gap_duration * 1000),
                'start_time': float(timestamps[gap_start]),
                'end_time': float(timestamps[i])
            })
        else:
            i += 1

    return gaps


def interpolate_short_gap(timestamps: np.ndarray, values: np.ndarray,
                          start_idx: int, end_idx: int, method='akima') -> Tuple[np.ndarray, float]:
    """Interpolate short gaps (<500ms) using linear or Akima interpolation."""

    # Get surrounding valid points
    n_context = 5
    left_idx = max(0, start_idx - n_context)
    right_idx = min(len(timestamps), end_idx + n_context)

    # Create interpolator
    valid_mask = ~np.isnan(values[left_idx:right_idx]).any(axis=1) if values.ndim > 1 else ~np.isnan(values[left_idx:right_idx])

    if valid_mask.sum() < 2:
        return values[start_idx:end_idx], 0.0

    t_valid = timestamps[left_idx:right_idx][valid_mask]
    v_valid = values[left_idx:right_idx][valid_mask]

    if method == 'akima' and SCIPY_AVAILABLE and len(t_valid) >= 4:
        if v_valid.ndim == 1:
            interp = Akima1DInterpolator(t_valid, v_valid)
        else:
            # Interpolate each feature
            result = np.zeros_like(values[start_idx:end_idx])
            for f in range(v_valid.shape[1]):
                interp = Akima1DInterpolator(t_valid, v_valid[:, f])
                result[:, f] = interp(timestamps[start_idx:end_idx])
            return result, 0.9
    else:
        # Linear interpolation
        if v_valid.ndim == 1:
            interp = interp1d(t_valid, v_valid, kind='linear', fill_value='extrapolate')
        else:
            result = np.zeros_like(values[start_idx:end_idx])
            for f in range(v_valid.shape[1]):
                interp = interp1d(t_valid, v_valid[:, f], kind='linear', fill_value='extrapolate')
                result[:, f] = interp(timestamps[start_idx:end_idx])
            return result, 0.85

    t_gap = timestamps[start_idx:end_idx]
    return interp(t_gap), 0.9


def kalman_smooth_gap(timestamps: np.ndarray, values: np.ndarray,
                      start_idx: int, end_idx: int) -> Tuple[np.ndarray, float]:
    """Kalman smoothing for medium gaps (500ms-5s)."""

    if not SCIPY_AVAILABLE:
        return interpolate_short_gap(timestamps, values, start_idx, end_idx, 'linear')

    # Simple state-space model: position + velocity
    n_features = values.shape[1] if values.ndim > 1 else 1

    # Get context before and after gap
    n_context = 20
    left_idx = max(0, start_idx - n_context)
    right_idx = min(len(timestamps), end_idx + n_context)

    context_t = timestamps[left_idx:right_idx]
    context_v = values[left_idx:right_idx]

    if values.ndim == 1:
        context_v = context_v.reshape(-1, 1)

    # Simple Kalman filter implementation
    dt = np.median(np.diff(context_t))

    # State transition matrix [position, velocity]
    A = np.array([[1, dt], [0, 1]])

    # Observation matrix
    H = np.array([[1, 0]])

    # Process and measurement noise
    Q = np.array([[dt**3/3, dt**2/2], [dt**2/2, dt]]) * 0.1
    R = np.array([[0.5]])

    results = []
    confidences = []

    for f in range(n_features):
        # Forward pass
        x = np.array([context_v[0, f], 0])  # Initial state
        P = np.eye(2) * 1.0

        filtered_states = []
        filtered_covs = []

        for i in range(len(context_t)):
            # Predict
            x = A @ x
            P = A @ P @ A.T + Q

            # Update if not in gap
            if i < (start_idx - left_idx) or i >= (end_idx - left_idx):
                if not np.isnan(context_v[i, f]):
                    y = context_v[i, f] - H @ x
                    S = H @ P @ H.T + R
                    K = P @ H.T @ np.linalg.inv(S)
                    x = x + K @ y
                    P = (np.eye(2) - K @ H) @ P

            filtered_states.append(x.copy())
            filtered_covs.append(P.copy())

        # Extract gap values
        gap_states = filtered_states[start_idx - left_idx:end_idx - left_idx]
        gap_covs = filtered_covs[start_idx - left_idx:end_idx - left_idx]

        gap_values = np.array([s[0] for s in gap_states])
        gap_conf = np.array([1.0 / (1.0 + c[0, 0]) for c in gap_covs])

        results.append(gap_values)
        confidences.append(gap_conf.mean())

    result = np.column_stack(results) if n_features > 1 else results[0]
    confidence = np.mean(confidences)

    return result, confidence


def transformer_impute_gap(model, timestamps: np.ndarray, values: np.ndarray,
                           start_idx: int, end_idx: int) -> Tuple[np.ndarray, float]:
    """Use Transformer model for long gaps (>5s)."""

    if not TORCH_AVAILABLE or model is None:
        return kalman_smooth_gap(timestamps, values, start_idx, end_idx)

    # Prepare input sequence
    seq_len = 128
    n_features = values.shape[1] if values.ndim > 1 else 1

    # Center around gap
    center = (start_idx + end_idx) // 2
    half_len = seq_len // 2

    left = max(0, center - half_len)
    right = min(len(timestamps), center + half_len)

    # Pad if necessary
    input_seq = np.zeros((seq_len, n_features))
    actual_len = right - left

    if values.ndim == 1:
        input_seq[:actual_len, 0] = values[left:right]
    else:
        input_seq[:actual_len] = values[left:right]

    # Mark gap positions
    gap_mask = np.zeros(seq_len, dtype=bool)
    local_start = start_idx - left
    local_end = end_idx - left
    gap_mask[local_start:local_end] = True
    input_seq[gap_mask] = 0

    # Run model
    with torch.no_grad():
        input_tensor = torch.FloatTensor(input_seq).unsqueeze(0)
        output = model(input_tensor).squeeze(0).numpy()

    # Extract imputed values
    imputed = output[local_start:local_end]

    return imputed, 0.7  # Lower confidence for model-based imputation


def impute_session(session_data: Dict, args) -> Dict:
    """Impute missing data in a session."""

    imputed_data = session_data.copy()
    imputation_log = []

    # Load or create Transformer model
    model = None
    if TORCH_AVAILABLE and args.heavy_impute:
        model = TimeSeriesTransformer()
        if os.path.exists(args.model_path):
            model.load_state_dict(torch.load(args.model_path))
            model.eval()
        else:
            logger.info("Training imputation model...")
            model = train_imputation_model(model)
            os.makedirs(os.path.dirname(args.model_path), exist_ok=True)
            torch.save(model.state_dict(), args.model_path)

    # Process each time series in session
    series_keys = ['gaze_series', 'au_series', 'touch_events']

    for key in series_keys:
        if key not in session_data:
            continue

        series = session_data[key]
        if not series:
            continue

        # Extract timestamps and values
        if isinstance(series[0], dict):
            timestamps = np.array([s.get('timestamp', i) for i, s in enumerate(series)])
            values = np.array([s.get('value', s.get('values', [0])) for s in series])
        else:
            timestamps = np.arange(len(series))
            values = np.array(series)

        if values.ndim == 1:
            values = values.reshape(-1, 1)

        # Detect gaps
        gaps = detect_gaps(timestamps, values)

        if not gaps:
            continue

        # Impute each gap
        for gap in gaps:
            duration_ms = gap['duration_ms']
            start_idx = gap['start_idx']
            end_idx = gap['end_idx']

            # Choose imputation method
            if duration_ms < 500 or args.fast_impute:
                method = 'interpolation'
                imputed_values, confidence = interpolate_short_gap(
                    timestamps, values, start_idx, end_idx
                )
            elif duration_ms < 5000 or args.fast_impute:
                method = 'kalman'
                imputed_values, confidence = kalman_smooth_gap(
                    timestamps, values, start_idx, end_idx
                )
            else:
                method = 'transformer'
                imputed_values, confidence = transformer_impute_gap(
                    model, timestamps, values, start_idx, end_idx
                )

            # Apply imputation
            values[start_idx:end_idx] = imputed_values

            imputation_log.append({
                'series': key,
                'gap_start': gap['start_time'],
                'gap_end': gap['end_time'],
                'duration_ms': duration_ms,
                'method': method,
                'confidence': float(confidence)
            })

        # Update series with imputed values
        if isinstance(series[0], dict):
            for i, s in enumerate(series):
                if 'value' in s:
                    s['value'] = values[i].tolist() if values[i].ndim > 0 else float(values[i])
                elif 'values' in s:
                    s['values'] = values[i].tolist()
                s['imputed'] = any(
                    log['gap_start'] <= timestamps[i] <= log['gap_end']
                    for log in imputation_log if log['series'] == key
                )
        else:
            imputed_data[key] = values.squeeze().tolist()

    imputed_data['imputation_log'] = imputation_log
    imputed_data['imputation_metadata'] = {
        'timestamp': datetime.now().isoformat(),
        'method_used': 'heavy' if args.heavy_impute else ('fast' if args.fast_impute else 'hybrid'),
        'total_gaps': len(imputation_log),
        'avg_confidence': np.mean([log['confidence'] for log in imputation_log]) if imputation_log else 1.0
    }

    return imputed_data


def generate_qa_plots(session_data: Dict, imputed_data: Dict, output_path: Path):
    """Generate QA plots for imputation results."""
    try:
        import matplotlib.pyplot as plt
    except ImportError:
        logger.warning("Matplotlib not available, skipping QA plots")
        return

    output_path.mkdir(parents=True, exist_ok=True)

    # Plot gap map
    fig, axes = plt.subplots(2, 1, figsize=(12, 8))

    # Before/after comparison
    for key in ['gaze_series', 'au_series']:
        if key not in session_data:
            continue

        original = session_data[key]
        imputed = imputed_data[key]

        if isinstance(original, list) and len(original) > 0:
            if isinstance(original[0], dict):
                orig_vals = [s.get('value', s.get('values', [0]))[0] if isinstance(s.get('value', s.get('values', [0])), list) else s.get('value', 0) for s in original]
                imp_vals = [s.get('value', s.get('values', [0]))[0] if isinstance(s.get('value', s.get('values', [0])), list) else s.get('value', 0) for s in imputed]
            else:
                orig_vals = original
                imp_vals = imputed

            axes[0].plot(orig_vals, alpha=0.7, label=f'{key} (original)')
            axes[1].plot(imp_vals, alpha=0.7, label=f'{key} (imputed)')

    axes[0].set_title('Before Imputation')
    axes[0].legend()
    axes[1].set_title('After Imputation')
    axes[1].legend()

    session_id = session_data.get('session_id', 'unknown')
    plt.savefig(output_path / f'{session_id}_qa_plot.png', dpi=100, bbox_inches='tight')
    plt.close()


def main():
    args = parse_args()

    # Create output directories
    Path(args.out_dir).mkdir(parents=True, exist_ok=True)
    Path(args.report_dir).mkdir(parents=True, exist_ok=True)

    # Process single file or batch
    if args.input:
        with open(args.input, 'r') as f:
            session_data = json.load(f)

        imputed_data = impute_session(session_data, args)

        output_path = args.output or args.input.replace('.json', '_imputed.json')

        if not args.dry_run:
            with open(output_path, 'w') as f:
                json.dump(imputed_data, f, indent=2)
            logger.info(f"Saved imputed session to: {output_path}")

            generate_qa_plots(session_data, imputed_data, Path(args.report_dir))

    elif args.batch_dir:
        batch_path = Path(args.batch_dir)

        for json_file in batch_path.glob('*.json'):
            logger.info(f"Processing: {json_file}")

            with open(json_file, 'r') as f:
                session_data = json.load(f)

            imputed_data = impute_session(session_data, args)

            output_path = Path(args.out_dir) / f"{json_file.stem}_imputed.json"

            if not args.dry_run:
                with open(output_path, 'w') as f:
                    json.dump(imputed_data, f, indent=2)

                generate_qa_plots(session_data, imputed_data, Path(args.report_dir))

        logger.info(f"Batch processing complete. Output in: {args.out_dir}")

    else:
        logger.error("Either --input or --batch_dir must be specified")


if __name__ == '__main__':
    main()
