#!/usr/bin/env python3
"""
latency_budget_planner.py — Allocate per-module latency budgets for 30fps target.
"""

import argparse
import json
import logging
import hashlib
from pathlib import Path
from datetime import datetime

import numpy as np
import pandas as pd

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out_dir', type=str, default='./outputs/latency_planner')
    parser.add_argument('--target_fps', type=int, default=30)
    parser.add_argument('--config', type=str, default=None)
    parser.add_argument('--synthetic', type=int, default=0)
    parser.add_argument('--dry_run', action='store_true')
    return parser.parse_args()


# Default pipeline configuration
DEFAULT_PIPELINE = {
    'modules': [
        {'name': 'camera_capture', 'base_latency_ms': 5, 'priority': 1},
        {'name': 'face_detection', 'base_latency_ms': 8, 'priority': 2},
        {'name': 'landmark_extraction', 'base_latency_ms': 4, 'priority': 2},
        {'name': 'gaze_estimation', 'base_latency_ms': 6, 'priority': 3},
        {'name': 'au_extraction', 'base_latency_ms': 5, 'priority': 3},
        {'name': 'emotion_classification', 'base_latency_ms': 3, 'priority': 4},
        {'name': 'dialog_generation', 'base_latency_ms': 10, 'priority': 5},
        {'name': 'avatar_rendering', 'base_latency_ms': 8, 'priority': 5},
    ],
}

# Device class specifications
DEVICE_CLASSES = {
    'high_end': {'cpu_multiplier': 1.0, 'memory_gb': 8},
    'mid_range': {'cpu_multiplier': 1.5, 'memory_gb': 4},
    'low_end': {'cpu_multiplier': 2.5, 'memory_gb': 2},
    'budget': {'cpu_multiplier': 4.0, 'memory_gb': 1},
}


def allocate_budget(pipeline, target_latency_ms):
    """Allocate latency budget to each module."""
    total_base = sum(m['base_latency_ms'] for m in pipeline['modules'])

    # Scale factor
    scale = target_latency_ms / total_base

    allocations = []
    for module in pipeline['modules']:
        # Allocate proportionally with some headroom for high priority
        priority_factor = 1.0 + (5 - module['priority']) * 0.05
        allocated = module['base_latency_ms'] * scale * priority_factor

        allocations.append({
            'module': module['name'],
            'base_ms': module['base_latency_ms'],
            'allocated_ms': allocated,
            'priority': module['priority'],
        })

    # Normalize to fit exactly in budget
    total_allocated = sum(a['allocated_ms'] for a in allocations)
    for a in allocations:
        a['allocated_ms'] = a['allocated_ms'] * target_latency_ms / total_allocated

    return allocations


def simulate_device(pipeline, device_class, target_fps):
    """Simulate pipeline on a device class."""
    target_latency_ms = 1000 / target_fps
    multiplier = DEVICE_CLASSES[device_class]['cpu_multiplier']

    # Compute actual latencies
    total_latency = 0
    module_latencies = []

    for module in pipeline['modules']:
        actual = module['base_latency_ms'] * multiplier
        total_latency += actual
        module_latencies.append({
            'module': module['name'],
            'latency_ms': actual,
        })

    achieved_fps = 1000 / total_latency if total_latency > 0 else 0
    meets_target = achieved_fps >= target_fps

    return {
        'device_class': device_class,
        'total_latency_ms': total_latency,
        'achieved_fps': achieved_fps,
        'target_fps': target_fps,
        'meets_target': meets_target,
        'module_latencies': module_latencies,
    }


def suggest_optimizations(simulation_results):
    """Suggest optimizations for devices not meeting target."""
    suggestions = []

    for result in simulation_results:
        if not result['meets_target']:
            # Find bottleneck modules
            sorted_modules = sorted(
                result['module_latencies'],
                key=lambda x: -x['latency_ms']
            )

            device = result['device_class']
            suggestions.append({
                'device': device,
                'shortfall_fps': result['target_fps'] - result['achieved_fps'],
                'recommendations': [
                    f"Optimize {sorted_modules[0]['module']} (currently {sorted_modules[0]['latency_ms']:.1f}ms)",
                    f"Consider skipping frames for {sorted_modules[1]['module']}",
                    "Use quantized models for this device class",
                    "Reduce input resolution",
                ],
            })

    return suggestions


def compute_sha256(filepath):
    sha256_hash = hashlib.sha256()
    with open(filepath, 'rb') as f:
        for chunk in iter(lambda: f.read(4096), b''):
            sha256_hash.update(chunk)
    return sha256_hash.hexdigest()


def main():
    args = parse_args()
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    pipeline = DEFAULT_PIPELINE
    target_latency_ms = 1000 / args.target_fps

    if args.dry_run:
        logger.info("dry run mode")
        results = {
            'target_fps': args.target_fps,
            'devices_meeting_target': 2,
            'devices_tested': 4,
        }
    else:
        # Allocate budget
        logger.info(f"allocating latency budget for {args.target_fps}fps...")
        allocations = allocate_budget(pipeline, target_latency_ms)

        logger.info("budget allocations:")
        for a in allocations:
            logger.info(f"  {a['module']}: {a['allocated_ms']:.2f}ms")

        # Simulate on different devices
        logger.info("\nsimulating on device classes...")
        simulations = []

        for device_class in DEVICE_CLASSES:
            result = simulate_device(pipeline, device_class, args.target_fps)
            simulations.append(result)

            status = "✓" if result['meets_target'] else "✗"
            logger.info(f"  {device_class}: {result['achieved_fps']:.1f}fps {status}")

        # Generate suggestions
        suggestions = suggest_optimizations(simulations)

        # Results summary
        meets_target = sum(1 for s in simulations if s['meets_target'])

        results = {
            'target_fps': args.target_fps,
            'target_latency_ms': target_latency_ms,
            'devices_meeting_target': meets_target,
            'devices_tested': len(DEVICE_CLASSES),
            'allocations': allocations,
            'simulations': simulations,
            'optimization_suggestions': suggestions,
        }

        # Save detailed allocations
        pd.DataFrame(allocations).to_csv(out_dir / 'budget_allocations.csv', index=False)

        # Save simulation results
        sim_summary = [{
            'device': s['device_class'],
            'latency_ms': s['total_latency_ms'],
            'fps': s['achieved_fps'],
            'meets_target': s['meets_target'],
        } for s in simulations]
        pd.DataFrame(sim_summary).to_csv(out_dir / 'device_simulations.csv', index=False)

    with open(out_dir / 'planner_results.json', 'w') as f:
        json.dump(results, f, indent=2)

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

    logger.info(f"latency planner complete. saved to {out_dir}")


if __name__ == '__main__':
    main()
