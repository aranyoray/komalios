#!/usr/bin/env python3
"""
model_size_monitoring_agent.py — Alert on model bloat across releases.
Scans models, compares to baseline, rejects PRs if size exceeds threshold.
"""

import argparse
import json
import logging
import os
from pathlib import Path
from datetime import datetime

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description='Model size monitoring')
    parser.add_argument('--model_dir', type=str, default='./models')
    parser.add_argument('--baseline_file', type=str, default='./model_baseline.json')
    parser.add_argument('--max_increase_percent', type=float, default=10.0)
    parser.add_argument('--update_baseline', action='store_true')
    parser.add_argument('--ci_mode', action='store_true')
    return parser.parse_args()


def scan_models(model_dir):
    """Scan directory for model files and their sizes."""
    model_dir = Path(model_dir)
    models = {}

    patterns = ['*.pt', '*.pth', '*.onnx', '*.tflite', '*.pb']
    for pattern in patterns:
        for path in model_dir.rglob(pattern):
            rel_path = str(path.relative_to(model_dir))
            models[rel_path] = {
                'size_bytes': path.stat().st_size,
                'size_mb': round(path.stat().st_size / (1024 * 1024), 2)
            }

    return models


def load_baseline(baseline_file):
    """Load baseline sizes."""
    if Path(baseline_file).exists():
        with open(baseline_file) as f:
            return json.load(f)
    return {}


def save_baseline(baseline_file, models):
    """Save new baseline."""
    baseline = {
        'timestamp': datetime.now().isoformat(),
        'models': models
    }
    with open(baseline_file, 'w') as f:
        json.dump(baseline, f, indent=2)


def compare_to_baseline(current, baseline, max_increase):
    """Compare current sizes to baseline."""
    issues = []
    stats = {
        'total_current_mb': 0,
        'total_baseline_mb': 0,
        'new_models': [],
        'removed_models': [],
        'size_changes': []
    }

    baseline_models = baseline.get('models', {})

    for name, info in current.items():
        stats['total_current_mb'] += info['size_mb']

        if name not in baseline_models:
            stats['new_models'].append(name)
            continue

        baseline_size = baseline_models[name]['size_bytes']
        current_size = info['size_bytes']
        stats['total_baseline_mb'] += baseline_models[name]['size_mb']

        if baseline_size > 0:
            change_percent = ((current_size - baseline_size) / baseline_size) * 100

            if abs(change_percent) > 1:  # Only report significant changes
                stats['size_changes'].append({
                    'model': name,
                    'baseline_mb': baseline_models[name]['size_mb'],
                    'current_mb': info['size_mb'],
                    'change_percent': round(change_percent, 1)
                })

            if change_percent > max_increase:
                issues.append({
                    'model': name,
                    'baseline_mb': baseline_models[name]['size_mb'],
                    'current_mb': info['size_mb'],
                    'change_percent': round(change_percent, 1),
                    'threshold': max_increase
                })

    # Check for removed models
    for name in baseline_models:
        if name not in current:
            stats['removed_models'].append(name)

    return issues, stats


def suggest_compression(model_name, size_mb):
    """Suggest compression steps for oversized model."""
    suggestions = []

    if size_mb > 100:
        suggestions.append("Apply structured pruning (30-50% sparsity)")
        suggestions.append("Use INT8 quantization")

    if size_mb > 50:
        suggestions.append("Apply knowledge distillation to smaller architecture")
        suggestions.append("Use FP16 weights")

    suggestions.append(f"Run: python scripts/quant_profile_generator.py --model {model_name}")

    return suggestions


def main():
    args = parse_args()

    # Scan current models
    current = scan_models(args.model_dir)
    logger.info(f"Found {len(current)} models in {args.model_dir}")

    # Update baseline if requested
    if args.update_baseline:
        save_baseline(args.baseline_file, current)
        logger.info(f"Updated baseline: {args.baseline_file}")
        return 0

    # Load and compare to baseline
    baseline = load_baseline(args.baseline_file)
    issues, stats = compare_to_baseline(current, baseline, args.max_increase_percent)

    # Report
    print("\nModel Size Report")
    print("=" * 50)
    print(f"Total current: {stats['total_current_mb']:.2f} MB")
    print(f"Total baseline: {stats['total_baseline_mb']:.2f} MB")

    if stats['new_models']:
        print(f"\nNew models: {len(stats['new_models'])}")
        for name in stats['new_models']:
            print(f"  + {name}")

    if stats['size_changes']:
        print(f"\nSize changes:")
        for change in stats['size_changes']:
            direction = "+" if change['change_percent'] > 0 else ""
            print(f"  {change['model']}: {change['baseline_mb']} -> {change['current_mb']} MB ({direction}{change['change_percent']}%)")

    # Report issues
    if issues:
        print(f"\n⚠️  ISSUES: {len(issues)} models exceed {args.max_increase_percent}% increase")
        for issue in issues:
            print(f"\n  {issue['model']}:")
            print(f"    {issue['baseline_mb']} -> {issue['current_mb']} MB (+{issue['change_percent']}%)")
            print(f"    Suggestions:")
            for suggestion in suggest_compression(issue['model'], issue['current_mb']):
                print(f"      - {suggestion}")

        if args.ci_mode:
            logger.error("CI check failed: model size increase exceeds threshold")
            return 1

    else:
        print("\n✓ All models within size limits")

    return 0


if __name__ == '__main__':
    exit(main())
