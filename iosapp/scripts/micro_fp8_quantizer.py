#!/usr/bin/env python3
"""
micro_fp8_quantizer.py - Quantize model layers to FP8

Quantizes selected layers to FP8 (or simulated), tests accuracy impact,
and exports fallback FP16 model if accuracy drop is too high.
"""

import argparse
import json
import logging
import numpy as np
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import struct

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class FP8Converter:
    """Convert between FP32 and FP8 formats."""

    # E4M3 format: 1 sign, 4 exponent, 3 mantissa
    # E5M2 format: 1 sign, 5 exponent, 2 mantissa

    def __init__(self, format_type: str = 'e4m3'):
        self.format_type = format_type

        if format_type == 'e4m3':
            self.exp_bits = 4
            self.man_bits = 3
            self.bias = 7
            self.max_val = 448.0
        else:  # e5m2
            self.exp_bits = 5
            self.man_bits = 2
            self.bias = 15
            self.max_val = 57344.0

    def to_fp8(self, values: np.ndarray) -> np.ndarray:
        """Convert FP32 to simulated FP8."""
        # Clip to FP8 range
        clipped = np.clip(values, -self.max_val, self.max_val)

        # Quantize by reducing precision
        # This simulates FP8 by reducing mantissa precision
        scale = 2 ** self.man_bits

        # Round to nearest representable value
        quantized = np.round(clipped * scale) / scale

        return quantized.astype(np.float32)

    def quantization_error(self, original: np.ndarray, quantized: np.ndarray) -> Dict:
        """Calculate quantization error metrics."""
        diff = original - quantized

        return {
            'mse': float(np.mean(diff ** 2)),
            'max_error': float(np.max(np.abs(diff))),
            'mean_error': float(np.mean(np.abs(diff))),
            'snr_db': float(10 * np.log10(np.var(original) / (np.var(diff) + 1e-10)))
        }


class LayerQuantizer:
    """Quantize individual model layers."""

    def __init__(self, converter: FP8Converter):
        self.converter = converter

    def quantize_weights(self, weights: np.ndarray, layer_name: str) -> Tuple[np.ndarray, Dict]:
        """Quantize layer weights to FP8."""
        # Original stats
        original_min = float(np.min(weights))
        original_max = float(np.max(weights))

        # Quantize
        quantized = self.converter.to_fp8(weights)

        # Calculate error
        error = self.converter.quantization_error(weights, quantized)

        stats = {
            'layer': layer_name,
            'shape': list(weights.shape),
            'original_range': [original_min, original_max],
            'quantization_error': error,
            'size_reduction': 0.5  # FP32 -> FP8 = 4x reduction
        }

        return quantized, stats


class MicroFP8Quantizer:
    """Main FP8 quantizer for model optimization."""

    def __init__(self, config: Dict):
        self.config = config

        format_type = config.get('fp8_format', 'e4m3')
        self.converter = FP8Converter(format_type)
        self.layer_quantizer = LayerQuantizer(self.converter)

        # Accuracy thresholds
        self.max_accuracy_drop = config.get('max_accuracy_drop', 0.02)
        self.snr_threshold = config.get('snr_threshold_db', 20)

        # Results
        self.layer_stats = []
        self.quantized_layers = {}

    def load_model(self, model_path: str) -> Dict[str, np.ndarray]:
        """Load model weights (simulated for demo)."""
        # In real implementation, would load PyTorch/TF model
        # Creating demo model

        model = {
            'conv1.weight': np.random.randn(64, 3, 3, 3).astype(np.float32) * 0.1,
            'conv1.bias': np.random.randn(64).astype(np.float32) * 0.01,
            'conv2.weight': np.random.randn(128, 64, 3, 3).astype(np.float32) * 0.1,
            'conv2.bias': np.random.randn(128).astype(np.float32) * 0.01,
            'fc1.weight': np.random.randn(256, 512).astype(np.float32) * 0.1,
            'fc1.bias': np.random.randn(256).astype(np.float32) * 0.01,
            'fc2.weight': np.random.randn(7, 256).astype(np.float32) * 0.1,
            'fc2.bias': np.random.randn(7).astype(np.float32) * 0.01
        }

        logger.info(f"Loaded model with {len(model)} layers")
        return model

    def quantize_model(self, model: Dict[str, np.ndarray],
                      layers_to_quantize: Optional[List[str]] = None) -> Dict[str, np.ndarray]:
        """Quantize specified layers of the model."""
        quantized_model = {}
        failed_layers = []

        for name, weights in model.items():
            # Check if this layer should be quantized
            should_quantize = True

            if layers_to_quantize is not None:
                should_quantize = any(l in name for l in layers_to_quantize)

            # Skip bias layers for FP8 (keep FP32)
            if 'bias' in name:
                should_quantize = False

            if should_quantize:
                quantized, stats = self.layer_quantizer.quantize_weights(weights, name)

                # Check if quantization quality is acceptable
                snr = stats['quantization_error']['snr_db']

                if snr < self.snr_threshold:
                    logger.warning(f"Layer {name} has low SNR ({snr:.1f}dB), keeping FP32")
                    quantized_model[name] = weights
                    failed_layers.append(name)
                else:
                    quantized_model[name] = quantized
                    self.quantized_layers[name] = True
                    logger.info(f"Quantized {name}: SNR={snr:.1f}dB, MSE={stats['quantization_error']['mse']:.6f}")

                self.layer_stats.append(stats)
            else:
                quantized_model[name] = weights

        if failed_layers:
            logger.warning(f"Failed to quantize {len(failed_layers)} layers")

        return quantized_model

    def evaluate_accuracy(self, original_model: Dict, quantized_model: Dict,
                         test_data: Optional[np.ndarray] = None) -> Dict:
        """Evaluate accuracy impact of quantization."""
        # Simulate inference comparison
        # In real implementation, would run actual inference

        if test_data is None:
            test_data = np.random.randn(100, 3, 64, 64).astype(np.float32)

        # Simulate outputs (simplified)
        def forward(model, x):
            # Fake forward pass using first conv weights
            w = model.get('conv1.weight', np.zeros((64, 3, 3, 3)))
            return np.sum(x * np.mean(w)) + np.random.randn() * 0.1

        original_outputs = [forward(original_model, x) for x in test_data]
        quantized_outputs = [forward(quantized_model, x) for x in test_data]

        # Calculate differences
        diffs = np.array(original_outputs) - np.array(quantized_outputs)

        accuracy_drop = np.mean(np.abs(diffs)) / (np.std(original_outputs) + 1e-10)

        return {
            'accuracy_drop': float(accuracy_drop),
            'max_diff': float(np.max(np.abs(diffs))),
            'correlation': float(np.corrcoef(original_outputs, quantized_outputs)[0, 1]),
            'acceptable': accuracy_drop < self.max_accuracy_drop
        }

    def save_model(self, model: Dict[str, np.ndarray], output_path: str, format: str = 'npz'):
        """Save quantized model."""
        output = Path(output_path)

        if format == 'npz':
            np.savez(output, **model)
        elif format == 'npy':
            output.mkdir(parents=True, exist_ok=True)
            for name, weights in model.items():
                np.save(output / f"{name}.npy", weights)

        # Calculate size
        total_size = sum(w.nbytes for w in model.values())
        logger.info(f"Saved model to {output_path} ({total_size / (1024**2):.1f} MB)")

    def get_quantization_report(self) -> Dict:
        """Generate quantization report."""
        total_original = 0
        total_quantized = 0

        for stats in self.layer_stats:
            layer_size = np.prod(stats['shape']) * 4  # FP32
            total_original += layer_size

            if stats['layer'] in self.quantized_layers:
                total_quantized += layer_size * 0.25  # FP8
            else:
                total_quantized += layer_size

        return {
            'layers_quantized': len(self.quantized_layers),
            'total_layers': len(self.layer_stats),
            'original_size_mb': total_original / (1024**2),
            'quantized_size_mb': total_quantized / (1024**2),
            'size_reduction': 1 - (total_quantized / (total_original + 1e-10)),
            'layer_stats': self.layer_stats
        }


def main():
    parser = argparse.ArgumentParser(description='Micro FP8 quantizer')
    parser.add_argument('--input', type=str, help='Input model path')
    parser.add_argument('--output', type=str, default='quantized_model.npz', help='Output path')
    parser.add_argument('--format', type=str, default='e4m3', choices=['e4m3', 'e5m2'])
    parser.add_argument('--max-accuracy-drop', type=float, default=0.02, help='Max allowed accuracy drop')
    parser.add_argument('--snr-threshold', type=float, default=20, help='Min SNR in dB')
    parser.add_argument('--layers', type=str, nargs='+', help='Specific layers to quantize')
    parser.add_argument('--demo', action='store_true', help='Run demo')

    args = parser.parse_args()

    config = {
        'fp8_format': args.format,
        'max_accuracy_drop': args.max_accuracy_drop,
        'snr_threshold_db': args.snr_threshold
    }

    quantizer = MicroFP8Quantizer(config)

    if args.demo:
        # Load demo model
        model = quantizer.load_model('demo')

        # Quantize
        quantized = quantizer.quantize_model(model, args.layers)

        # Evaluate
        eval_result = quantizer.evaluate_accuracy(model, quantized)

        logger.info(f"\n=== Accuracy Evaluation ===")
        logger.info(f"Accuracy drop: {eval_result['accuracy_drop']:.4f}")
        logger.info(f"Correlation: {eval_result['correlation']:.4f}")
        logger.info(f"Acceptable: {eval_result['acceptable']}")

        # Save
        if eval_result['acceptable']:
            quantizer.save_model(quantized, args.output)
        else:
            # Save FP16 fallback
            fp16_model = {k: v.astype(np.float16) for k, v in model.items()}
            quantizer.save_model(fp16_model, args.output.replace('.npz', '_fp16.npz'))
            logger.warning("Accuracy drop too high, saved FP16 fallback instead")

        # Report
        report = quantizer.get_quantization_report()
        logger.info(f"\n=== Quantization Report ===")
        logger.info(f"Layers quantized: {report['layers_quantized']}/{report['total_layers']}")
        logger.info(f"Original size: {report['original_size_mb']:.1f} MB")
        logger.info(f"Quantized size: {report['quantized_size_mb']:.1f} MB")
        logger.info(f"Size reduction: {report['size_reduction']*100:.1f}%")
    else:
        logger.info("Use --demo to run demonstration")


if __name__ == '__main__':
    main()
