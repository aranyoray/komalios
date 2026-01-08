#!/usr/bin/env python3
"""
micro_battery_guard.py - Enforce session runtime limits based on battery percentage

Blocks expensive animations under 20% battery, enforces session time limits,
and records battery drain slope for analysis.
"""

import argparse
import json
import time
import os
import logging
from datetime import datetime
from typing import Dict, Optional, List
from pathlib import Path

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class BatteryMonitor:
    """Monitor battery status."""

    def __init__(self):
        self.simulated_level = 100.0
        self.simulated_charging = False
        self.drain_rate = 0.05  # % per second under load

    def get_status(self) -> Dict:
        """Get current battery status."""
        # Try real battery API (Linux)
        try:
            power_supply = Path("/sys/class/power_supply")
            for supply in power_supply.iterdir():
                if "BAT" in supply.name:
                    capacity_file = supply / "capacity"
                    status_file = supply / "status"

                    if capacity_file.exists():
                        level = int(capacity_file.read_text().strip())
                        charging = False

                        if status_file.exists():
                            status = status_file.read_text().strip()
                            charging = status in ["Charging", "Full"]

                        return {
                            'level': level,
                            'charging': charging,
                            'source': 'real'
                        }
        except Exception as e:
            pass

        # Simulate
        if not self.simulated_charging:
            self.simulated_level = max(0, self.simulated_level - self.drain_rate)

        return {
            'level': self.simulated_level,
            'charging': self.simulated_charging,
            'source': 'simulated'
        }


class MicroBatteryGuard:
    """Guard against excessive battery drain."""

    def __init__(self, config: Dict):
        self.config = config
        self.monitor = BatteryMonitor()

        # Thresholds
        self.critical_level = config.get('critical_level', 10)
        self.low_level = config.get('low_level', 20)
        self.warn_level = config.get('warn_level', 30)

        # Session limits (minutes per battery level range)
        self.session_limits = config.get('session_limits', {
            'critical': 5,
            'low': 10,
            'warn': 20,
            'normal': 30
        })

        # Feature flags
        self.blocked_features = {
            'critical': ['all_inference', 'animations', 'recording', 'sync'],
            'low': ['animations', 'hd_recording', 'background_sync'],
            'warn': ['heavy_animations', 'continuous_recording'],
            'normal': []
        }

        # Tracking
        self.session_start = time.time()
        self.readings = []
        self.drain_slopes = []

    def get_battery_state(self) -> str:
        """Get current battery state category."""
        status = self.monitor.get_status()
        level = status['level']

        if status['charging']:
            return 'charging'
        elif level <= self.critical_level:
            return 'critical'
        elif level <= self.low_level:
            return 'low'
        elif level <= self.warn_level:
            return 'warn'
        return 'normal'

    def check_session_allowed(self) -> Dict:
        """Check if session should continue."""
        status = self.monitor.get_status()
        state = self.get_battery_state()

        # Record reading
        reading = {
            'timestamp': time.time(),
            'level': status['level'],
            'state': state
        }
        self.readings.append(reading)

        # Calculate drain slope
        if len(self.readings) >= 2:
            recent = self.readings[-10:]
            if len(recent) >= 2:
                time_diff = recent[-1]['timestamp'] - recent[0]['timestamp']
                level_diff = recent[0]['level'] - recent[-1]['level']

                if time_diff > 0:
                    slope = level_diff / (time_diff / 60)  # % per minute
                    self.drain_slopes.append({
                        'timestamp': time.time(),
                        'slope': slope
                    })

        # Check session time limit
        elapsed_minutes = (time.time() - self.session_start) / 60
        max_minutes = self.session_limits.get(state, 30)

        time_exceeded = elapsed_minutes > max_minutes

        # Get blocked features
        blocked = self.blocked_features.get(state, [])

        result = {
            'allowed': state != 'critical' and not time_exceeded,
            'state': state,
            'battery_level': status['level'],
            'charging': status['charging'],
            'elapsed_minutes': elapsed_minutes,
            'max_minutes': max_minutes,
            'time_remaining': max(0, max_minutes - elapsed_minutes),
            'blocked_features': blocked,
            'reason': None
        }

        if state == 'critical':
            result['reason'] = 'Battery critical - session must end'
        elif time_exceeded:
            result['reason'] = f'Session time limit exceeded for {state} battery'

        return result

    def is_feature_allowed(self, feature: str) -> bool:
        """Check if a specific feature is allowed."""
        state = self.get_battery_state()
        blocked = self.blocked_features.get(state, [])

        return feature not in blocked and 'all_inference' not in blocked

    def get_recommended_settings(self) -> Dict:
        """Get recommended app settings for current battery state."""
        state = self.get_battery_state()

        settings = {
            'charging': {
                'fps': 30,
                'resolution': 'high',
                'animations': 'full',
                'sync_interval': 30,
                'recording_quality': 'high'
            },
            'normal': {
                'fps': 30,
                'resolution': 'high',
                'animations': 'full',
                'sync_interval': 60,
                'recording_quality': 'high'
            },
            'warn': {
                'fps': 24,
                'resolution': 'medium',
                'animations': 'reduced',
                'sync_interval': 120,
                'recording_quality': 'medium'
            },
            'low': {
                'fps': 15,
                'resolution': 'low',
                'animations': 'none',
                'sync_interval': 300,
                'recording_quality': 'low'
            },
            'critical': {
                'fps': 10,
                'resolution': 'minimal',
                'animations': 'none',
                'sync_interval': 0,  # disabled
                'recording_quality': 'none'
            }
        }

        return settings.get(state, settings['normal'])

    def get_drain_analysis(self) -> Dict:
        """Analyze battery drain patterns."""
        if not self.readings:
            return {'error': 'No readings available'}

        # Overall drain
        total_time = (self.readings[-1]['timestamp'] - self.readings[0]['timestamp']) / 60
        total_drain = self.readings[0]['level'] - self.readings[-1]['level']

        avg_drain_rate = total_drain / total_time if total_time > 0 else 0

        # Recent drain (last 5 minutes)
        recent_readings = [r for r in self.readings
                         if r['timestamp'] > time.time() - 300]

        recent_drain_rate = 0
        if len(recent_readings) >= 2:
            recent_time = (recent_readings[-1]['timestamp'] - recent_readings[0]['timestamp']) / 60
            recent_drain = recent_readings[0]['level'] - recent_readings[-1]['level']
            recent_drain_rate = recent_drain / recent_time if recent_time > 0 else 0

        # Estimated time remaining
        current_level = self.readings[-1]['level']
        if avg_drain_rate > 0:
            estimated_remaining = current_level / avg_drain_rate
        else:
            estimated_remaining = float('inf')

        return {
            'total_time_minutes': total_time,
            'total_drain_percent': total_drain,
            'avg_drain_rate': avg_drain_rate,
            'recent_drain_rate': recent_drain_rate,
            'current_level': current_level,
            'estimated_remaining_minutes': estimated_remaining if estimated_remaining != float('inf') else -1,
            'readings_count': len(self.readings)
        }

    def export_drain_log(self, output_path: str):
        """Export drain log for analysis."""
        data = {
            'session_start': datetime.fromtimestamp(self.session_start).isoformat(),
            'config': self.config,
            'readings': [
                {
                    'timestamp': datetime.fromtimestamp(r['timestamp']).isoformat(),
                    'level': r['level'],
                    'state': r['state']
                }
                for r in self.readings
            ],
            'drain_slopes': self.drain_slopes,
            'analysis': self.get_drain_analysis()
        }

        with open(output_path, 'w') as f:
            json.dump(data, f, indent=2)

        logger.info(f"Exported drain log to {output_path}")


def run_demo(guard: MicroBatteryGuard, duration: int = 60):
    """Run demo monitoring session."""
    logger.info(f"Starting battery guard demo for {duration}s")

    start = time.time()
    check_interval = 2

    while time.time() - start < duration:
        status = guard.check_session_allowed()
        settings = guard.get_recommended_settings()

        logger.info(
            f"Battery: {status['battery_level']:.1f}% | "
            f"State: {status['state']} | "
            f"FPS: {settings['fps']} | "
            f"Allowed: {status['allowed']}"
        )

        if not status['allowed']:
            logger.warning(f"Session should end: {status['reason']}")
            break

        if status['blocked_features']:
            logger.info(f"Blocked features: {status['blocked_features']}")

        time.sleep(check_interval)

    # Export analysis
    analysis = guard.get_drain_analysis()
    logger.info(f"\n=== Drain Analysis ===")
    logger.info(f"Total drain: {analysis['total_drain_percent']:.1f}%")
    logger.info(f"Avg drain rate: {analysis['avg_drain_rate']:.2f}%/min")
    logger.info(f"Recent drain rate: {analysis['recent_drain_rate']:.2f}%/min")


def main():
    parser = argparse.ArgumentParser(description='Micro battery guard')
    parser.add_argument('--critical', type=int, default=10, help='Critical battery level')
    parser.add_argument('--low', type=int, default=20, help='Low battery level')
    parser.add_argument('--warn', type=int, default=30, help='Warning battery level')
    parser.add_argument('--duration', type=int, default=60, help='Demo duration seconds')
    parser.add_argument('--output', type=str, default='battery_drain_log.json', help='Output path')
    parser.add_argument('--simulate-drain', type=float, default=0.1, help='Simulated drain rate %/s')

    args = parser.parse_args()

    config = {
        'critical_level': args.critical,
        'low_level': args.low,
        'warn_level': args.warn
    }

    guard = MicroBatteryGuard(config)
    guard.monitor.drain_rate = args.simulate_drain

    try:
        run_demo(guard, args.duration)
    except KeyboardInterrupt:
        logger.info("Interrupted")
    finally:
        guard.export_drain_log(args.output)


if __name__ == '__main__':
    main()
