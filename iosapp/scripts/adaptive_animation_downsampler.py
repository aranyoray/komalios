#!/usr/bin/env python3
"""
adaptive_animation_downsampler.py - Reduce emoji animation complexity dynamically

Reduces animation complexity (eye sparkle, glow, bounce) based on current FPS
and CPU load to maintain smooth performance on low-end devices.
"""

import argparse
import json
import time
import os
import logging
from datetime import datetime
from typing import Dict, List, Optional
from collections import deque

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class PerformanceMonitor:
    """Monitor FPS and CPU load."""

    def __init__(self, window_size: int = 30):
        self.frame_times = deque(maxlen=window_size)
        self.last_frame_time = time.time()

    def record_frame(self):
        """Record a frame completion."""
        now = time.time()
        self.frame_times.append(now - self.last_frame_time)
        self.last_frame_time = now

    def get_fps(self) -> float:
        """Get current FPS."""
        if not self.frame_times:
            return 60.0

        avg_frame_time = sum(self.frame_times) / len(self.frame_times)
        return 1.0 / avg_frame_time if avg_frame_time > 0 else 60.0

    def get_cpu_load(self) -> float:
        """Get current CPU load (0-1)."""
        try:
            load = os.getloadavg()[0]
            cpu_count = os.cpu_count() or 1
            return min(1.0, load / cpu_count)
        except:
            return 0.5


class AnimationSettings:
    """Animation complexity settings."""

    def __init__(self):
        self.settings = {
            'eye_sparkle': {
                'enabled': True,
                'intensity': 1.0,
                'particles': 10
            },
            'glow': {
                'enabled': True,
                'intensity': 1.0,
                'radius': 20
            },
            'bounce': {
                'enabled': True,
                'amplitude': 1.0,
                'frequency': 1.0
            },
            'blink': {
                'enabled': True,
                'frequency': 1.0
            },
            'particle_effects': {
                'enabled': True,
                'count': 50
            },
            'shadows': {
                'enabled': True,
                'quality': 'high'
            },
            'blur_effects': {
                'enabled': True,
                'quality': 'high'
            }
        }

    def apply_quality_level(self, level: str):
        """Apply a predefined quality level."""
        presets = {
            'ultra': {
                'eye_sparkle': {'enabled': True, 'intensity': 1.0, 'particles': 15},
                'glow': {'enabled': True, 'intensity': 1.0, 'radius': 25},
                'bounce': {'enabled': True, 'amplitude': 1.0, 'frequency': 1.0},
                'blink': {'enabled': True, 'frequency': 1.0},
                'particle_effects': {'enabled': True, 'count': 100},
                'shadows': {'enabled': True, 'quality': 'high'},
                'blur_effects': {'enabled': True, 'quality': 'high'}
            },
            'high': {
                'eye_sparkle': {'enabled': True, 'intensity': 0.8, 'particles': 10},
                'glow': {'enabled': True, 'intensity': 0.8, 'radius': 20},
                'bounce': {'enabled': True, 'amplitude': 0.8, 'frequency': 1.0},
                'blink': {'enabled': True, 'frequency': 1.0},
                'particle_effects': {'enabled': True, 'count': 50},
                'shadows': {'enabled': True, 'quality': 'medium'},
                'blur_effects': {'enabled': True, 'quality': 'medium'}
            },
            'medium': {
                'eye_sparkle': {'enabled': True, 'intensity': 0.5, 'particles': 5},
                'glow': {'enabled': True, 'intensity': 0.5, 'radius': 15},
                'bounce': {'enabled': True, 'amplitude': 0.5, 'frequency': 0.8},
                'blink': {'enabled': True, 'frequency': 0.8},
                'particle_effects': {'enabled': True, 'count': 20},
                'shadows': {'enabled': False, 'quality': 'low'},
                'blur_effects': {'enabled': False, 'quality': 'low'}
            },
            'low': {
                'eye_sparkle': {'enabled': False, 'intensity': 0, 'particles': 0},
                'glow': {'enabled': True, 'intensity': 0.3, 'radius': 10},
                'bounce': {'enabled': True, 'amplitude': 0.3, 'frequency': 0.5},
                'blink': {'enabled': True, 'frequency': 0.5},
                'particle_effects': {'enabled': False, 'count': 0},
                'shadows': {'enabled': False, 'quality': 'none'},
                'blur_effects': {'enabled': False, 'quality': 'none'}
            },
            'minimal': {
                'eye_sparkle': {'enabled': False, 'intensity': 0, 'particles': 0},
                'glow': {'enabled': False, 'intensity': 0, 'radius': 0},
                'bounce': {'enabled': False, 'amplitude': 0, 'frequency': 0},
                'blink': {'enabled': True, 'frequency': 0.3},
                'particle_effects': {'enabled': False, 'count': 0},
                'shadows': {'enabled': False, 'quality': 'none'},
                'blur_effects': {'enabled': False, 'quality': 'none'}
            }
        }

        if level in presets:
            self.settings = presets[level].copy()

    def get_render_cost(self) -> float:
        """Estimate relative render cost (0-1)."""
        cost = 0.0

        if self.settings['eye_sparkle']['enabled']:
            cost += 0.15 * self.settings['eye_sparkle']['intensity']
            cost += 0.01 * self.settings['eye_sparkle']['particles']

        if self.settings['glow']['enabled']:
            cost += 0.1 * self.settings['glow']['intensity']

        if self.settings['particle_effects']['enabled']:
            cost += 0.005 * self.settings['particle_effects']['count']

        if self.settings['shadows']['enabled']:
            quality_cost = {'high': 0.15, 'medium': 0.08, 'low': 0.03, 'none': 0}
            cost += quality_cost.get(self.settings['shadows']['quality'], 0)

        if self.settings['blur_effects']['enabled']:
            quality_cost = {'high': 0.2, 'medium': 0.1, 'low': 0.05, 'none': 0}
            cost += quality_cost.get(self.settings['blur_effects']['quality'], 0)

        return min(1.0, cost)


class AdaptiveAnimationDownsampler:
    """Dynamically adjust animation complexity."""

    def __init__(self, config: Dict):
        self.config = config
        self.monitor = PerformanceMonitor()
        self.animation = AnimationSettings()

        # Thresholds
        self.target_fps = config.get('target_fps', 30)
        self.min_fps = config.get('min_fps', 15)
        self.max_cpu_load = config.get('max_cpu_load', 0.8)

        # Quality levels in order
        self.quality_levels = ['ultra', 'high', 'medium', 'low', 'minimal']
        self.current_level_idx = 1  # Start at 'high'

        # Adaptation settings
        self.adaptation_cooldown = config.get('adaptation_cooldown', 2.0)
        self.last_adaptation = 0

        # History
        self.adaptation_log = []

    def update(self) -> Dict:
        """Update animation settings based on performance."""
        self.monitor.record_frame()

        fps = self.monitor.get_fps()
        cpu_load = self.monitor.get_cpu_load()

        current_level = self.quality_levels[self.current_level_idx]
        new_level = current_level

        # Check if we should adapt
        now = time.time()
        can_adapt = (now - self.last_adaptation) > self.adaptation_cooldown

        if can_adapt:
            # Downgrade if struggling
            if fps < self.min_fps or cpu_load > self.max_cpu_load:
                if self.current_level_idx < len(self.quality_levels) - 1:
                    self.current_level_idx += 1
                    new_level = self.quality_levels[self.current_level_idx]
                    self.last_adaptation = now

                    self.adaptation_log.append({
                        'timestamp': datetime.now().isoformat(),
                        'action': 'downgrade',
                        'from': current_level,
                        'to': new_level,
                        'fps': fps,
                        'cpu_load': cpu_load
                    })
                    logger.info(f"Downgraded animation: {current_level} -> {new_level} (FPS={fps:.1f})")

            # Upgrade if performing well
            elif fps > self.target_fps * 1.2 and cpu_load < self.max_cpu_load * 0.6:
                if self.current_level_idx > 0:
                    self.current_level_idx -= 1
                    new_level = self.quality_levels[self.current_level_idx]
                    self.last_adaptation = now

                    self.adaptation_log.append({
                        'timestamp': datetime.now().isoformat(),
                        'action': 'upgrade',
                        'from': current_level,
                        'to': new_level,
                        'fps': fps,
                        'cpu_load': cpu_load
                    })
                    logger.info(f"Upgraded animation: {current_level} -> {new_level} (FPS={fps:.1f})")

        # Apply settings
        self.animation.apply_quality_level(new_level)

        return {
            'quality_level': new_level,
            'fps': fps,
            'cpu_load': cpu_load,
            'render_cost': self.animation.get_render_cost(),
            'settings': self.animation.settings.copy()
        }

    def force_level(self, level: str):
        """Force a specific quality level."""
        if level in self.quality_levels:
            self.current_level_idx = self.quality_levels.index(level)
            self.animation.apply_quality_level(level)
            logger.info(f"Forced animation level: {level}")

    def get_stats(self) -> Dict:
        """Get adaptation statistics."""
        upgrades = sum(1 for a in self.adaptation_log if a['action'] == 'upgrade')
        downgrades = sum(1 for a in self.adaptation_log if a['action'] == 'downgrade')

        return {
            'current_level': self.quality_levels[self.current_level_idx],
            'total_adaptations': len(self.adaptation_log),
            'upgrades': upgrades,
            'downgrades': downgrades,
            'current_fps': self.monitor.get_fps(),
            'current_cpu': self.monitor.get_cpu_load()
        }

    def export_log(self, output_path: str):
        """Export adaptation log."""
        data = {
            'config': self.config,
            'stats': self.get_stats(),
            'adaptations': self.adaptation_log,
            'final_settings': self.animation.settings
        }

        with open(output_path, 'w') as f:
            json.dump(data, f, indent=2)

        logger.info(f"Exported animation log to {output_path}")


def run_simulation(downsampler: AdaptiveAnimationDownsampler, duration: int = 30):
    """Run simulation with varying load."""
    import random

    logger.info(f"Running animation downsampler simulation for {duration}s")

    start = time.time()
    frame_count = 0

    while time.time() - start < duration:
        # Simulate variable frame time
        elapsed = time.time() - start

        # Simulate load spikes
        if 10 < elapsed < 15 or 20 < elapsed < 23:
            # Heavy load period
            frame_time = random.uniform(0.05, 0.1)  # 10-20 FPS
        else:
            # Normal period
            frame_time = random.uniform(0.02, 0.04)  # 25-50 FPS

        time.sleep(frame_time)

        state = downsampler.update()
        frame_count += 1

        if frame_count % 30 == 0:
            logger.info(
                f"Level: {state['quality_level']} | "
                f"FPS: {state['fps']:.1f} | "
                f"Cost: {state['render_cost']:.2f}"
            )

    stats = downsampler.get_stats()
    logger.info(f"\n=== Simulation Results ===")
    logger.info(f"Final level: {stats['current_level']}")
    logger.info(f"Total adaptations: {stats['total_adaptations']}")
    logger.info(f"Upgrades: {stats['upgrades']}, Downgrades: {stats['downgrades']}")


def main():
    parser = argparse.ArgumentParser(description='Adaptive animation downsampler')
    parser.add_argument('--target-fps', type=int, default=30, help='Target FPS')
    parser.add_argument('--min-fps', type=int, default=15, help='Minimum acceptable FPS')
    parser.add_argument('--max-cpu', type=float, default=0.8, help='Max CPU load')
    parser.add_argument('--cooldown', type=float, default=2.0, help='Adaptation cooldown seconds')
    parser.add_argument('--duration', type=int, default=30, help='Simulation duration')
    parser.add_argument('--output', type=str, default='animation_adaptation_log.json', help='Output path')

    args = parser.parse_args()

    config = {
        'target_fps': args.target_fps,
        'min_fps': args.min_fps,
        'max_cpu_load': args.max_cpu,
        'adaptation_cooldown': args.cooldown
    }

    downsampler = AdaptiveAnimationDownsampler(config)

    try:
        run_simulation(downsampler, args.duration)
    except KeyboardInterrupt:
        logger.info("Interrupted")
    finally:
        downsampler.export_log(args.output)


if __name__ == '__main__':
    main()
