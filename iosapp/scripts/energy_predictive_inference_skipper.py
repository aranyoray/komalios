#!/usr/bin/env python3
"""
energy_predictive_inference_skipper.py - Predict when to skip inference frames to save battery

Uses LSTM forecasting of attention state to determine when inference can be safely
skipped. Guarantees maximum skip length, evaluates energy savings vs accuracy trade-off.
"""

import argparse
import json
import numpy as np
import logging
from datetime import datetime
from typing import List, Dict, Tuple, Optional
from collections import deque

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class AttentionStatePredictor:
    """LSTM-based predictor for attention state forecasting."""

    def __init__(self, hidden_size: int = 32, sequence_length: int = 10):
        self.hidden_size = hidden_size
        self.sequence_length = sequence_length
        self.history = deque(maxlen=sequence_length)

        # Initialize simple LSTM-like weights (simplified for demo)
        np.random.seed(42)
        self.Wf = np.random.randn(hidden_size, 2) * 0.1
        self.Wi = np.random.randn(hidden_size, 2) * 0.1
        self.Wo = np.random.randn(hidden_size, 2) * 0.1
        self.Wc = np.random.randn(hidden_size, 2) * 0.1

        self.h = np.zeros(hidden_size)
        self.c = np.zeros(hidden_size)

    def _sigmoid(self, x):
        return 1 / (1 + np.exp(-np.clip(x, -10, 10)))

    def _tanh(self, x):
        return np.tanh(np.clip(x, -10, 10))

    def update(self, attention_score: float, variance: float = 0.0):
        """Update model with new attention observation."""
        self.history.append({
            'attention': attention_score,
            'variance': variance
        })

        # Simple LSTM step
        x = np.array([attention_score, variance])

        f = self._sigmoid(self.Wf @ x)
        i = self._sigmoid(self.Wi @ x)
        o = self._sigmoid(self.Wo @ x)
        c_candidate = self._tanh(self.Wc @ x)

        self.c = f * self.c + i * c_candidate
        self.h = o * self._tanh(self.c)

    def predict_next(self, steps: int = 5) -> List[float]:
        """Predict attention scores for next N frames."""
        if len(self.history) < 3:
            return [0.5] * steps

        # Use hidden state to predict
        predictions = []
        h_temp = self.h.copy()

        recent = [h['attention'] for h in list(self.history)[-3:]]
        trend = recent[-1] - recent[0] if len(recent) >= 2 else 0

        for i in range(steps):
            # Simple autoregressive prediction
            base = recent[-1] if recent else 0.5
            pred = base + trend * 0.3 + np.mean(h_temp[:4]) * 0.1
            pred = np.clip(pred, 0, 1)
            predictions.append(pred)

            # Decay trend
            trend *= 0.8

        return predictions

    def get_stability_score(self) -> float:
        """Get score indicating how stable attention is (higher = more stable)."""
        if len(self.history) < 3:
            return 0.5

        recent = [h['attention'] for h in list(self.history)[-5:]]
        variance = np.var(recent)

        # Low variance = high stability
        return np.exp(-variance * 5)


class InferenceSkipper:
    """Decide when to skip inference frames."""

    def __init__(self, config: Dict):
        self.max_skip = config.get('max_skip_frames', 5)
        self.stability_threshold = config.get('stability_threshold', 0.7)
        self.attention_threshold = config.get('attention_threshold', 0.3)
        self.energy_per_inference = config.get('energy_per_inference_mj', 10.0)

        self.predictor = AttentionStatePredictor(
            hidden_size=config.get('hidden_size', 32),
            sequence_length=config.get('sequence_length', 10)
        )

        self.current_skip_count = 0
        self.last_inference_result = None

        # Stats
        self.total_frames = 0
        self.skipped_frames = 0
        self.energy_saved = 0.0
        self.accuracy_impacts = []

    def should_skip(self, frame_idx: int) -> Tuple[bool, str]:
        """Decide whether to skip inference for this frame."""
        self.total_frames += 1

        # Never skip if we've hit max
        if self.current_skip_count >= self.max_skip:
            self.current_skip_count = 0
            return False, "max_skip_reached"

        # Need minimum history
        if len(self.predictor.history) < 5:
            return False, "insufficient_history"

        stability = self.predictor.get_stability_score()
        predictions = self.predictor.predict_next(3)

        # Skip if attention is stable and predicted to stay high/low
        if stability > self.stability_threshold:
            pred_variance = np.var(predictions)

            if pred_variance < 0.05:  # Predictions are stable
                self.current_skip_count += 1
                self.skipped_frames += 1
                self.energy_saved += self.energy_per_inference
                return True, f"stable_prediction (stability={stability:.2f})"

        # Skip if attention consistently low (child not engaged)
        recent_attention = [h['attention'] for h in list(self.predictor.history)[-3:]]
        if all(a < self.attention_threshold for a in recent_attention):
            self.current_skip_count += 1
            self.skipped_frames += 1
            self.energy_saved += self.energy_per_inference
            return True, "low_attention"

        self.current_skip_count = 0
        return False, "inference_required"

    def record_inference(self, attention_score: float, variance: float = 0.0):
        """Record result of an inference."""
        self.predictor.update(attention_score, variance)
        self.last_inference_result = attention_score

    def record_skip_accuracy(self, actual_attention: float):
        """Record accuracy impact when we skipped and later got ground truth."""
        if self.last_inference_result is not None:
            error = abs(actual_attention - self.last_inference_result)
            self.accuracy_impacts.append(error)

    def get_interpolated_result(self) -> Optional[float]:
        """Get interpolated result when skipping."""
        if self.last_inference_result is not None:
            predictions = self.predictor.predict_next(1)
            # Blend last result with prediction
            return 0.7 * self.last_inference_result + 0.3 * predictions[0]
        return None

    def get_stats(self) -> Dict:
        """Get energy savings statistics."""
        skip_rate = self.skipped_frames / self.total_frames if self.total_frames > 0 else 0
        avg_error = np.mean(self.accuracy_impacts) if self.accuracy_impacts else 0

        return {
            'total_frames': self.total_frames,
            'skipped_frames': self.skipped_frames,
            'skip_rate': skip_rate,
            'energy_saved_mj': self.energy_saved,
            'avg_accuracy_error': avg_error,
            'max_accuracy_error': max(self.accuracy_impacts) if self.accuracy_impacts else 0
        }


def simulate_session(skipper: InferenceSkipper, duration_frames: int = 300) -> Dict:
    """Simulate a session with synthetic attention data."""
    np.random.seed(int(datetime.now().timestamp()) % 10000)

    # Generate synthetic attention pattern
    # Mix of stable periods and transitions
    attention_data = []

    # Phase 1: Engaged (stable high)
    for _ in range(100):
        attention_data.append(0.8 + np.random.randn() * 0.05)

    # Phase 2: Distracted (transition down)
    for i in range(50):
        attention_data.append(0.8 - i * 0.01 + np.random.randn() * 0.08)

    # Phase 3: Re-engaged (transition up)
    for i in range(50):
        attention_data.append(0.3 + i * 0.01 + np.random.randn() * 0.08)

    # Phase 4: Variable attention
    for _ in range(100):
        attention_data.append(0.5 + np.sin(_ * 0.1) * 0.3 + np.random.randn() * 0.1)

    attention_data = [np.clip(a, 0, 1) for a in attention_data]

    # Run simulation
    results = []

    for i, true_attention in enumerate(attention_data[:duration_frames]):
        skip, reason = skipper.should_skip(i)

        if skip:
            interpolated = skipper.get_interpolated_result()
            skipper.record_skip_accuracy(true_attention)

            results.append({
                'frame': i,
                'skipped': True,
                'reason': reason,
                'true_attention': true_attention,
                'interpolated': interpolated
            })
        else:
            # Run inference
            variance = np.random.random() * 0.1
            skipper.record_inference(true_attention, variance)

            results.append({
                'frame': i,
                'skipped': False,
                'reason': reason,
                'true_attention': true_attention,
                'inferred': true_attention
            })

    return {
        'results': results,
        'stats': skipper.get_stats()
    }


def main():
    parser = argparse.ArgumentParser(description='Energy-predictive inference skipper')
    parser.add_argument('--max-skip', type=int, default=5, help='Max consecutive skipped frames')
    parser.add_argument('--stability-threshold', type=float, default=0.7, help='Stability threshold')
    parser.add_argument('--attention-threshold', type=float, default=0.3, help='Low attention threshold')
    parser.add_argument('--energy-per-inference', type=float, default=10.0, help='Energy per inference (mJ)')
    parser.add_argument('--duration', type=int, default=300, help='Simulation duration (frames)')
    parser.add_argument('--output', type=str, default='skip_results.json', help='Output path')

    args = parser.parse_args()

    config = {
        'max_skip_frames': args.max_skip,
        'stability_threshold': args.stability_threshold,
        'attention_threshold': args.attention_threshold,
        'energy_per_inference_mj': args.energy_per_inference
    }

    skipper = InferenceSkipper(config)
    results = simulate_session(skipper, args.duration)

    # Print summary
    stats = results['stats']
    logger.info(f"\n=== Inference Skipper Results ===")
    logger.info(f"Total frames: {stats['total_frames']}")
    logger.info(f"Skipped frames: {stats['skipped_frames']} ({stats['skip_rate']*100:.1f}%)")
    logger.info(f"Energy saved: {stats['energy_saved_mj']:.1f} mJ")
    logger.info(f"Average accuracy error: {stats['avg_accuracy_error']:.4f}")
    logger.info(f"Max accuracy error: {stats['max_accuracy_error']:.4f}")

    # Save results
    with open(args.output, 'w') as f:
        json.dump(results, f, indent=2)

    logger.info(f"Results saved to {args.output}")


if __name__ == '__main__':
    main()
