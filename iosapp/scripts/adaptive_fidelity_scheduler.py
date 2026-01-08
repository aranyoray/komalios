#!/usr/bin/env python3
"""
adaptive_fidelity_scheduler.py — Dynamic resolution + frame rate controller.
Monitors CPU, battery, latency and adjusts camera FPS, model input size, animation complexity.
"""

import argparse
import json
import logging
import time
import threading
from pathlib import Path
from typing import Dict
from dataclasses import dataclass
from collections import deque

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)

try:
    import psutil
    PSUTIL_AVAILABLE = True
except ImportError:
    PSUTIL_AVAILABLE = False


def parse_args():
    parser = argparse.ArgumentParser(description='Adaptive fidelity scheduler')
    parser.add_argument('--policy', type=str, choices=['conservative', 'balanced', 'aggressive'],
                        default='balanced', help='Scheduling policy')
    parser.add_argument('--target_latency_ms', type=float, default=100, help='P95 latency target')
    parser.add_argument('--check_interval', type=float, default=1.0, help='Check interval in seconds')
    parser.add_argument('--output', type=str, default='./fidelity_config.json', help='Output config path')
    parser.add_argument('--duration', type=int, default=60, help='Run duration in seconds')
    return parser.parse_args()


@dataclass
class FidelityConfig:
    """Current fidelity configuration."""
    camera_fps: int = 30
    camera_resolution: tuple = (640, 480)
    model_input_size: int = 224
    animation_complexity: str = 'high'  # low, medium, high
    batch_size: int = 1

    def to_dict(self):
        return {
            'camera_fps': self.camera_fps,
            'camera_resolution': list(self.camera_resolution),
            'model_input_size': self.model_input_size,
            'animation_complexity': self.animation_complexity,
            'batch_size': self.batch_size
        }


# Policy presets
POLICIES = {
    'conservative': {
        'cpu_threshold_high': 60,
        'cpu_threshold_low': 40,
        'battery_threshold': 30,
        'latency_tolerance': 0.8,  # Allow 80% of target
        'min_fps': 10,
        'min_resolution': (320, 240),
        'min_model_size': 112
    },
    'balanced': {
        'cpu_threshold_high': 75,
        'cpu_threshold_low': 50,
        'battery_threshold': 20,
        'latency_tolerance': 1.0,
        'min_fps': 15,
        'min_resolution': (480, 360),
        'min_model_size': 160
    },
    'aggressive': {
        'cpu_threshold_high': 90,
        'cpu_threshold_low': 70,
        'battery_threshold': 10,
        'latency_tolerance': 1.2,  # Allow 120% of target
        'min_fps': 20,
        'min_resolution': (640, 480),
        'min_model_size': 192
    }
}


class AdaptiveFidelityScheduler:
    """Monitors system and adjusts fidelity settings."""

    def __init__(self, policy: str, target_latency_ms: float):
        self.policy_config = POLICIES[policy]
        self.target_latency_ms = target_latency_ms
        self.config = FidelityConfig()
        self.latency_history = deque(maxlen=100)
        self.cpu_history = deque(maxlen=20)
        self.adjustments = []

    def get_system_metrics(self) -> Dict:
        """Get current system metrics."""
        metrics = {
            'cpu_percent': 50.0,
            'battery_percent': 100.0,
            'battery_plugged': True,
            'memory_percent': 50.0
        }

        if PSUTIL_AVAILABLE:
            metrics['cpu_percent'] = psutil.cpu_percent(interval=0.1)
            metrics['memory_percent'] = psutil.virtual_memory().percent

            battery = psutil.sensors_battery()
            if battery:
                metrics['battery_percent'] = battery.percent
                metrics['battery_plugged'] = battery.power_plugged

        return metrics

    def record_latency(self, latency_ms: float):
        """Record inference latency measurement."""
        self.latency_history.append(latency_ms)

    def get_p95_latency(self) -> float:
        """Get P95 latency from history."""
        if not self.latency_history:
            return 0.0
        sorted_latencies = sorted(self.latency_history)
        idx = int(len(sorted_latencies) * 0.95)
        return sorted_latencies[min(idx, len(sorted_latencies) - 1)]

    def adjust_fidelity(self):
        """Adjust fidelity based on current conditions."""
        metrics = self.get_system_metrics()
        p95_latency = self.get_p95_latency()

        self.cpu_history.append(metrics['cpu_percent'])
        avg_cpu = sum(self.cpu_history) / len(self.cpu_history)

        policy = self.policy_config
        target = self.target_latency_ms * policy['latency_tolerance']

        adjustments_made = []

        # Check if we need to reduce fidelity
        need_reduction = (
            avg_cpu > policy['cpu_threshold_high'] or
            p95_latency > target or
            (metrics['battery_percent'] < policy['battery_threshold'] and
             not metrics['battery_plugged'])
        )

        # Check if we can increase fidelity
        can_increase = (
            avg_cpu < policy['cpu_threshold_low'] and
            p95_latency < target * 0.7 and
            (metrics['battery_percent'] > policy['battery_threshold'] * 2 or
             metrics['battery_plugged'])
        )

        if need_reduction:
            # Reduce fidelity
            if self.config.camera_fps > policy['min_fps']:
                old_fps = self.config.camera_fps
                self.config.camera_fps = max(policy['min_fps'], self.config.camera_fps - 5)
                adjustments_made.append(f"FPS: {old_fps} -> {self.config.camera_fps}")

            if self.config.model_input_size > policy['min_model_size']:
                old_size = self.config.model_input_size
                self.config.model_input_size = max(policy['min_model_size'],
                                                    self.config.model_input_size - 32)
                adjustments_made.append(f"Model size: {old_size} -> {self.config.model_input_size}")

            if self.config.animation_complexity == 'high':
                self.config.animation_complexity = 'medium'
                adjustments_made.append("Animation: high -> medium")
            elif self.config.animation_complexity == 'medium':
                self.config.animation_complexity = 'low'
                adjustments_made.append("Animation: medium -> low")

        elif can_increase:
            # Increase fidelity
            if self.config.camera_fps < 30:
                old_fps = self.config.camera_fps
                self.config.camera_fps = min(30, self.config.camera_fps + 5)
                adjustments_made.append(f"FPS: {old_fps} -> {self.config.camera_fps}")

            if self.config.model_input_size < 224:
                old_size = self.config.model_input_size
                self.config.model_input_size = min(224, self.config.model_input_size + 32)
                adjustments_made.append(f"Model size: {old_size} -> {self.config.model_input_size}")

            if self.config.animation_complexity == 'low':
                self.config.animation_complexity = 'medium'
                adjustments_made.append("Animation: low -> medium")
            elif self.config.animation_complexity == 'medium':
                self.config.animation_complexity = 'high'
                adjustments_made.append("Animation: medium -> high")

        if adjustments_made:
            adjustment_record = {
                'timestamp': time.time(),
                'metrics': metrics,
                'p95_latency_ms': p95_latency,
                'adjustments': adjustments_made
            }
            self.adjustments.append(adjustment_record)
            logger.info(f"Adjusted: {', '.join(adjustments_made)}")

        return self.config

    def get_stats(self) -> Dict:
        """Get scheduler statistics."""
        return {
            'current_config': self.config.to_dict(),
            'p95_latency_ms': self.get_p95_latency(),
            'avg_cpu_percent': sum(self.cpu_history) / len(self.cpu_history) if self.cpu_history else 0,
            'total_adjustments': len(self.adjustments)
        }


def simulate_inference_latency(config: FidelityConfig) -> float:
    """Simulate inference latency based on config."""
    # Base latency
    base = 20.0

    # FPS impact
    fps_factor = config.camera_fps / 30.0

    # Model size impact (quadratic)
    size_factor = (config.model_input_size / 224) ** 2

    # Animation impact
    anim_factor = {'low': 0.5, 'medium': 1.0, 'high': 1.5}[config.animation_complexity]

    latency = base * fps_factor * size_factor * anim_factor

    # Add noise
    import random
    latency *= random.uniform(0.8, 1.2)

    return latency


def main():
    args = parse_args()

    scheduler = AdaptiveFidelityScheduler(args.policy, args.target_latency_ms)

    logger.info(f"Starting scheduler with {args.policy} policy")
    logger.info(f"Target P95 latency: {args.target_latency_ms}ms")

    start_time = time.time()

    try:
        while time.time() - start_time < args.duration:
            # Simulate inference
            latency = simulate_inference_latency(scheduler.config)
            scheduler.record_latency(latency)

            # Adjust fidelity
            config = scheduler.adjust_fidelity()

            time.sleep(args.check_interval)

    except KeyboardInterrupt:
        pass

    # Save final config
    output = {
        'policy': args.policy,
        'target_latency_ms': args.target_latency_ms,
        'final_config': scheduler.config.to_dict(),
        'stats': scheduler.get_stats(),
        'adjustments': scheduler.adjustments[-10:]  # Last 10 adjustments
    }

    with open(args.output, 'w') as f:
        json.dump(output, f, indent=2)

    logger.info(f"Final config saved to: {args.output}")
    print(json.dumps(scheduler.get_stats(), indent=2))


if __name__ == '__main__':
    main()
