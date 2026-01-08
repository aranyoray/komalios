#!/usr/bin/env python3
"""
imputation_confidence_calibrator.py — Calibrate imputation confidence estimates.
Uses isotonic regression / Platt scaling on held-out synthetic data.
"""

import argparse
import json
import logging
import pickle
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Tuple
import numpy as np

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description='Calibrate imputation confidence estimates')
    parser.add_argument('--input_dir', type=str, default='./data/imputed_sessions',
                        help='Directory with imputed sessions')
    parser.add_argument('--output_model', type=str, default='./models/confidence_calibration_model.pkl',
                        help='Output calibration model')
    parser.add_argument('--apply', action='store_true',
                        help='Apply calibration to sessions instead of training')
    parser.add_argument('--n_synthetic', type=int, default=1000,
                        help='Number of synthetic samples for calibration')
    parser.add_argument('--report_dir', type=str, default='./calibration_reports',
                        help='Directory for reports and plots')
    parser.add_argument('--dry_run', action='store_true')
    return parser.parse_args()


def generate_synthetic_calibration_data(n_samples: int) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Generate synthetic data with known ground truth for calibration."""

    # Generate ground truth time series
    seq_len = 128
    n_features = 8

    predicted_confidences = []
    actual_errors = []
    raw_confidences = []

    for _ in range(n_samples):
        # Create ground truth
        t = np.linspace(0, 4 * np.pi, seq_len)
        ground_truth = np.sin(t) + 0.1 * np.random.randn(seq_len)

        # Create gap
        gap_start = np.random.randint(20, seq_len - 30)
        gap_len = np.random.randint(5, 20)

        # Simulate imputation with some error
        imputed = ground_truth.copy()
        imputation_error = np.random.uniform(0.05, 0.5)
        imputed[gap_start:gap_start + gap_len] += np.random.randn(gap_len) * imputation_error

        # Raw model confidence (uncalibrated)
        raw_conf = 1.0 - imputation_error + np.random.uniform(-0.1, 0.1)
        raw_conf = np.clip(raw_conf, 0.0, 1.0)

        # Actual error
        actual_error = np.mean(np.abs(imputed[gap_start:gap_start + gap_len] -
                                     ground_truth[gap_start:gap_start + gap_len]))

        raw_confidences.append(raw_conf)
        actual_errors.append(actual_error)
        predicted_confidences.append(raw_conf)

    return (np.array(raw_confidences),
            np.array(actual_errors),
            np.array(predicted_confidences))


class IsotonicCalibrator:
    """Isotonic regression calibrator."""

    def __init__(self):
        self.calibrator = None

    def fit(self, confidences: np.ndarray, errors: np.ndarray):
        """Fit isotonic regression mapping confidence to accuracy."""
        from sklearn.isotonic import IsotonicRegression

        # Convert errors to accuracy (1 - normalized error)
        max_error = np.max(errors) + 1e-6
        accuracies = 1.0 - errors / max_error

        # Fit isotonic regression
        self.calibrator = IsotonicRegression(out_of_bounds='clip')
        self.calibrator.fit(confidences, accuracies)

        logger.info("Fitted isotonic calibrator")

    def calibrate(self, confidences: np.ndarray) -> np.ndarray:
        """Apply calibration to confidences."""
        if self.calibrator is None:
            return confidences

        return self.calibrator.predict(confidences)


class PlattCalibrator:
    """Platt scaling (sigmoid) calibrator."""

    def __init__(self):
        self.a = 1.0
        self.b = 0.0

    def fit(self, confidences: np.ndarray, errors: np.ndarray):
        """Fit Platt scaling parameters."""
        from scipy.optimize import minimize

        # Convert to binary accuracy
        max_error = np.max(errors) + 1e-6
        accuracies = 1.0 - errors / max_error

        def sigmoid(x, a, b):
            return 1.0 / (1.0 + np.exp(-a * x - b))

        def loss(params):
            a, b = params
            pred = sigmoid(confidences, a, b)
            return -np.mean(accuracies * np.log(pred + 1e-10) +
                          (1 - accuracies) * np.log(1 - pred + 1e-10))

        result = minimize(loss, [1.0, 0.0], method='L-BFGS-B')
        self.a, self.b = result.x

        logger.info(f"Fitted Platt calibrator: a={self.a:.4f}, b={self.b:.4f}")

    def calibrate(self, confidences: np.ndarray) -> np.ndarray:
        """Apply Platt scaling."""
        return 1.0 / (1.0 + np.exp(-self.a * confidences - self.b))


def compute_brier_score(confidences: np.ndarray, errors: np.ndarray) -> float:
    """Compute Brier score for calibration quality."""
    max_error = np.max(errors) + 1e-6
    accuracies = 1.0 - errors / max_error
    return np.mean((confidences - accuracies) ** 2)


def generate_reliability_diagram(confidences: np.ndarray, errors: np.ndarray,
                                  calibrated_confidences: np.ndarray,
                                  output_path: Path):
    """Generate reliability diagram."""
    try:
        import matplotlib.pyplot as plt
    except ImportError:
        logger.warning("Matplotlib not available, skipping reliability diagram")
        return

    # Convert errors to accuracies
    max_error = np.max(errors) + 1e-6
    accuracies = 1.0 - errors / max_error

    # Bin confidences
    n_bins = 10
    bin_edges = np.linspace(0, 1, n_bins + 1)

    fig, axes = plt.subplots(1, 2, figsize=(12, 5))

    for ax, conf, title in [(axes[0], confidences, 'Before Calibration'),
                            (axes[1], calibrated_confidences, 'After Calibration')]:
        bin_means = []
        bin_accs = []
        bin_counts = []

        for i in range(n_bins):
            mask = (conf >= bin_edges[i]) & (conf < bin_edges[i + 1])
            if mask.sum() > 0:
                bin_means.append(conf[mask].mean())
                bin_accs.append(accuracies[mask].mean())
                bin_counts.append(mask.sum())
            else:
                bin_means.append((bin_edges[i] + bin_edges[i + 1]) / 2)
                bin_accs.append(0)
                bin_counts.append(0)

        # Plot
        ax.bar(bin_means, bin_accs, width=0.08, alpha=0.7, label='Empirical')
        ax.plot([0, 1], [0, 1], 'k--', label='Perfect calibration')
        ax.set_xlabel('Mean Predicted Confidence')
        ax.set_ylabel('Fraction of Accurate')
        ax.set_title(title)
        ax.legend()
        ax.set_xlim(0, 1)
        ax.set_ylim(0, 1)

    plt.tight_layout()
    plt.savefig(output_path, dpi=100, bbox_inches='tight')
    plt.close()

    logger.info(f"Saved reliability diagram: {output_path}")


def apply_calibration_to_sessions(input_dir: Path, model_path: Path):
    """Apply calibration model to imputed sessions."""

    with open(model_path, 'rb') as f:
        calibrator = pickle.load(f)

    for json_file in input_dir.glob('*_imputed.json'):
        with open(json_file, 'r') as f:
            session = json.load(f)

        # Update confidence values
        if 'imputation_log' in session:
            for entry in session['imputation_log']:
                if 'confidence' in entry:
                    raw_conf = entry['confidence']
                    calibrated = calibrator.calibrate(np.array([raw_conf]))[0]
                    entry['raw_confidence'] = raw_conf
                    entry['confidence'] = float(calibrated)

        # Update metadata
        if 'imputation_metadata' in session:
            if 'avg_confidence' in session['imputation_metadata']:
                raw_avg = session['imputation_metadata']['avg_confidence']
                session['imputation_metadata']['raw_avg_confidence'] = raw_avg
                session['imputation_metadata']['avg_confidence'] = float(
                    calibrator.calibrate(np.array([raw_avg]))[0]
                )

        # Save calibrated session
        output_path = json_file.with_suffix('.calibrated.json')
        with open(output_path, 'w') as f:
            json.dump(session, f, indent=2)

        logger.info(f"Calibrated: {output_path}")


def main():
    args = parse_args()

    input_dir = Path(args.input_dir)
    model_path = Path(args.output_model)
    report_dir = Path(args.report_dir)
    report_dir.mkdir(parents=True, exist_ok=True)

    if args.apply:
        # Apply existing calibration model
        if not model_path.exists():
            logger.error(f"Calibration model not found: {model_path}")
            return 1

        apply_calibration_to_sessions(input_dir, model_path)
        return 0

    # Train calibration model
    logger.info(f"Generating {args.n_synthetic} synthetic samples for calibration...")
    raw_confs, errors, _ = generate_synthetic_calibration_data(args.n_synthetic)

    # Compute initial Brier score
    initial_brier = compute_brier_score(raw_confs, errors)
    logger.info(f"Initial Brier score: {initial_brier:.4f}")

    # Fit calibrators
    isotonic = IsotonicCalibrator()
    isotonic.fit(raw_confs, errors)

    platt = PlattCalibrator()
    platt.fit(raw_confs, errors)

    # Evaluate calibrators
    isotonic_calibrated = isotonic.calibrate(raw_confs)
    platt_calibrated = platt.calibrate(raw_confs)

    isotonic_brier = compute_brier_score(isotonic_calibrated, errors)
    platt_brier = compute_brier_score(platt_calibrated, errors)

    logger.info(f"Isotonic Brier score: {isotonic_brier:.4f}")
    logger.info(f"Platt Brier score: {platt_brier:.4f}")

    # Select best calibrator
    if isotonic_brier < platt_brier:
        best_calibrator = isotonic
        best_name = 'isotonic'
        best_brier = isotonic_brier
        calibrated_confs = isotonic_calibrated
    else:
        best_calibrator = platt
        best_name = 'platt'
        best_brier = platt_brier
        calibrated_confs = platt_calibrated

    logger.info(f"Selected calibrator: {best_name}")

    # Save model
    if not args.dry_run:
        model_path.parent.mkdir(parents=True, exist_ok=True)
        with open(model_path, 'wb') as f:
            pickle.dump(best_calibrator, f)
        logger.info(f"Saved calibration model: {model_path}")

    # Generate reliability diagram
    generate_reliability_diagram(
        raw_confs, errors, calibrated_confs,
        report_dir / 'reliability_diagram.png'
    )

    # Save report
    report = {
        'timestamp': datetime.now().isoformat(),
        'n_synthetic_samples': args.n_synthetic,
        'initial_brier_score': float(initial_brier),
        'isotonic_brier_score': float(isotonic_brier),
        'platt_brier_score': float(platt_brier),
        'selected_calibrator': best_name,
        'final_brier_score': float(best_brier),
        'improvement': float(initial_brier - best_brier)
    }

    report_path = report_dir / 'calibration_report.json'
    with open(report_path, 'w') as f:
        json.dump(report, f, indent=2)
    logger.info(f"Saved report: {report_path}")

    # Log to MLflow
    try:
        import mlflow
        with mlflow.start_run(run_name='confidence_calibration'):
            mlflow.log_param('calibrator', best_name)
            mlflow.log_metric('initial_brier', initial_brier)
            mlflow.log_metric('final_brier', best_brier)
            mlflow.log_artifact(str(model_path))
    except:
        pass

    return 0


if __name__ == '__main__':
    exit(main())
