#!/usr/bin/env python3
"""
thermal_load_balancer.py - Monitor device thermals and throttle workloads proactively

Monitors CPU/GPU temperature sensors (or estimates from usage), predicts temperature
rise using thermal models, and throttles frame rate/model complexity before OS-level
throttling kicks in. Exports per-device thermal profiles.
"""

import argparse
import json
import time
import os
import logging
from datetime import datetime
from pathlib import Path
from collections import deque
from typing import Dict, List, Optional, Tuple
import random

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class ThermalSensor:
    """Read or simulate thermal sensor data."""

    def __init__(self, use_real_sensors: bool = True):
        self.use_real = use_real_sensors
        self.simulated_temp = 35.0

    def read_cpu_temp(self) -> float:
        """Read CPU temperature in Celsius."""
        if self.use_real:
            # Try Linux thermal zones
            thermal_paths = [
                "/sys/class/thermal/thermal_zone0/temp",
                "/sys/class/hwmon/hwmon0/temp1_input",
                "/sys/devices/platform/coretemp.0/hwmon/hwmon2/temp1_input"
            ]
            for path in thermal_paths:
                if os.path.exists(path):
                    try:
                        with open(path, 'r') as f:
                            temp = int(f.read().strip()) / 1000.0
                            return temp
                    except:
                        continue

        # Simulate based on CPU load
        try:
            load = os.getloadavg()[0]
            self.simulated_temp = 35.0 + (load * 8) + random.uniform(-1, 1)
        except:
            self.simulated_temp += random.uniform(-0.5, 1.0)

        return min(self.simulated_temp, 95.0)

    def read_gpu_temp(self) -> Optional[float]:
        """Read GPU temperature if available."""
        # Try nvidia-smi
        try:
            import subprocess
            result = subprocess.run(
                ['nvidia-smi', '--query-gpu=temperature.gpu', '--format=csv,noheader,nounits'],
                capture_output=True, text=True, timeout=5
            )
            if result.returncode == 0:
                return float(result.stdout.strip())
        except:
            pass

        return None


class ThermalPredictor:
    """Predict temperature rise using RC thermal model."""

    def __init__(self, tau: float = 30.0, r_thermal: float = 0.5):
        """
        tau: thermal time constant in seconds
        r_thermal: thermal resistance (°C/W)
        """
        self.tau = tau
        self.r_thermal = r_thermal
        self.temp_history = deque(maxlen=60)
        self.ambient = 25.0

    def update(self, temp: float, power_estimate: float):
        """Update model with new temperature reading."""
        self.temp_history.append({
            'temp': temp,
            'power': power_estimate,
            'time': time.time()
        })

    def predict(self, seconds_ahead: float, future_power: float) -> float:
        """Predict temperature after seconds_ahead."""
        if not self.temp_history:
            return self.ambient

        current_temp = self.temp_history[-1]['temp']

        # Steady-state temp for given power
        steady_state = self.ambient + (future_power * self.r_thermal * 60)

        # RC model: T(t) = T_ss + (T_0 - T_ss) * exp(-t/tau)
        predicted = steady_state + (current_temp - steady_state) * (
            2.718 ** (-seconds_ahead / self.tau)
        )

        return predicted

    def estimate_safe_duration(self, max_temp: float, power: float) -> float:
        """Estimate how long until max_temp is reached."""
        if not self.temp_history:
            return float('inf')

        current = self.temp_history[-1]['temp']
        steady_state = self.ambient + (power * self.r_thermal * 60)

        if steady_state <= max_temp:
            return float('inf')

        if current >= max_temp:
            return 0.0

        # Solve for t: max_temp = steady_state + (current - steady_state) * exp(-t/tau)
        ratio = (max_temp - steady_state) / (current - steady_state)
        if ratio <= 0:
            return 0.0

        import math
        duration = -self.tau * math.log(ratio)
        return max(0.0, duration)


class WorkloadThrottler:
    """Throttle workloads based on thermal state."""

    def __init__(self, config: Dict):
        self.thresholds = config.get('thresholds', {
            'normal': 60,
            'warm': 70,
            'hot': 80,
            'critical': 90
        })
        self.current_level = 'normal'

    def get_throttle_level(self, temp: float) -> str:
        """Determine throttle level from temperature."""
        if temp >= self.thresholds['critical']:
            return 'critical'
        elif temp >= self.thresholds['hot']:
            return 'hot'
        elif temp >= self.thresholds['warm']:
            return 'warm'
        return 'normal'

    def get_settings(self, level: str) -> Dict:
        """Get recommended settings for throttle level."""
        settings = {
            'normal': {
                'fps': 30,
                'model_complexity': 1.0,
                'animations_enabled': True,
                'resolution_scale': 1.0
            },
            'warm': {
                'fps': 24,
                'model_complexity': 0.8,
                'animations_enabled': True,
                'resolution_scale': 0.9
            },
            'hot': {
                'fps': 15,
                'model_complexity': 0.5,
                'animations_enabled': False,
                'resolution_scale': 0.75
            },
            'critical': {
                'fps': 10,
                'model_complexity': 0.25,
                'animations_enabled': False,
                'resolution_scale': 0.5
            }
        }
        return settings.get(level, settings['normal'])


class ThermalLoadBalancer:
    """Main thermal load balancer."""

    def __init__(self, config_path: Optional[str] = None):
        self.config = self._load_config(config_path)
        self.sensor = ThermalSensor(self.config.get('use_real_sensors', True))
        self.predictor = ThermalPredictor(
            tau=self.config.get('thermal_tau', 30.0),
            r_thermal=self.config.get('thermal_resistance', 0.5)
        )
        self.throttler = WorkloadThrottler(self.config)

        self.thermal_log = []
        self.profile_data = {
            'device_id': self.config.get('device_id', 'unknown'),
            'readings': [],
            'throttle_events': []
        }

    def _load_config(self, path: Optional[str]) -> Dict:
        """Load configuration."""
        default = {
            'use_real_sensors': True,
            'thermal_tau': 30.0,
            'thermal_resistance': 0.5,
            'max_temp': 80.0,
            'poll_interval': 1.0,
            'device_id': f"device_{int(time.time()) % 10000}"
        }

        if path and os.path.exists(path):
            with open(path, 'r') as f:
                loaded = json.load(f)
                default.update(loaded)

        return default

    def estimate_power(self) -> float:
        """Estimate current power consumption (arbitrary units)."""
        try:
            load = os.getloadavg()[0]
            return load / os.cpu_count() if os.cpu_count() else load
        except:
            return 0.5

    def update(self) -> Dict:
        """Update thermal state and get recommendations."""
        cpu_temp = self.sensor.read_cpu_temp()
        gpu_temp = self.sensor.read_gpu_temp()
        power = self.estimate_power()

        # Use max of CPU/GPU temp
        temp = cpu_temp
        if gpu_temp:
            temp = max(cpu_temp, gpu_temp)

        self.predictor.update(temp, power)

        # Predict ahead
        predicted_30s = self.predictor.predict(30.0, power)
        predicted_60s = self.predictor.predict(60.0, power)
        safe_duration = self.predictor.estimate_safe_duration(
            self.config['max_temp'], power
        )

        # Get throttle level
        level = self.throttler.get_throttle_level(temp)
        settings = self.throttler.get_settings(level)

        # Log
        reading = {
            'timestamp': datetime.now().isoformat(),
            'cpu_temp': cpu_temp,
            'gpu_temp': gpu_temp,
            'power_estimate': power,
            'predicted_30s': predicted_30s,
            'predicted_60s': predicted_60s,
            'throttle_level': level,
            'safe_duration_s': safe_duration if safe_duration != float('inf') else -1
        }

        self.thermal_log.append(reading)
        self.profile_data['readings'].append(reading)

        # Track throttle events
        if level != self.throttler.current_level:
            event = {
                'timestamp': datetime.now().isoformat(),
                'from_level': self.throttler.current_level,
                'to_level': level,
                'temp': temp
            }
            self.profile_data['throttle_events'].append(event)
            self.throttler.current_level = level
            logger.info(f"Throttle level changed: {event['from_level']} -> {level} at {temp:.1f}°C")

        return {
            'current_temp': temp,
            'throttle_level': level,
            'settings': settings,
            'predicted_30s': predicted_30s,
            'predicted_60s': predicted_60s,
            'safe_duration': safe_duration
        }

    def export_profile(self, output_path: str):
        """Export thermal profile for this device."""
        self.profile_data['export_time'] = datetime.now().isoformat()
        self.profile_data['total_readings'] = len(self.profile_data['readings'])

        # Compute stats
        temps = [r['cpu_temp'] for r in self.profile_data['readings']]
        if temps:
            self.profile_data['stats'] = {
                'min_temp': min(temps),
                'max_temp': max(temps),
                'avg_temp': sum(temps) / len(temps),
                'throttle_events_count': len(self.profile_data['throttle_events'])
            }

        with open(output_path, 'w') as f:
            json.dump(self.profile_data, f, indent=2)

        logger.info(f"Exported thermal profile to {output_path}")

    def export_thermal_curve(self, output_path: str):
        """Export thermal curve data for analysis."""
        curve_data = {
            'timestamps': [],
            'temperatures': [],
            'predictions': [],
            'throttle_levels': []
        }

        for r in self.thermal_log:
            curve_data['timestamps'].append(r['timestamp'])
            curve_data['temperatures'].append(r['cpu_temp'])
            curve_data['predictions'].append(r['predicted_30s'])
            curve_data['throttle_levels'].append(r['throttle_level'])

        with open(output_path, 'w') as f:
            json.dump(curve_data, f, indent=2)

        logger.info(f"Exported thermal curve to {output_path}")

    def run_monitor(self, duration: float = 60.0):
        """Run monitoring loop for specified duration."""
        start = time.time()

        logger.info(f"Starting thermal monitoring for {duration}s")

        while time.time() - start < duration:
            state = self.update()

            logger.info(
                f"Temp: {state['current_temp']:.1f}°C | "
                f"Level: {state['throttle_level']} | "
                f"Pred 30s: {state['predicted_30s']:.1f}°C | "
                f"FPS: {state['settings']['fps']}"
            )

            time.sleep(self.config['poll_interval'])

        logger.info("Monitoring complete")


def main():
    parser = argparse.ArgumentParser(description='Thermal load balancer')
    parser.add_argument('--config', type=str, help='Config file path')
    parser.add_argument('--duration', type=float, default=60.0, help='Monitor duration in seconds')
    parser.add_argument('--output-profile', type=str, default='thermal_profile.json', help='Output profile path')
    parser.add_argument('--output-curve', type=str, default='thermal_curve.json', help='Output curve path')
    parser.add_argument('--max-temp', type=float, default=80.0, help='Max safe temperature')

    args = parser.parse_args()

    balancer = ThermalLoadBalancer(args.config)
    balancer.config['max_temp'] = args.max_temp

    try:
        balancer.run_monitor(args.duration)
    except KeyboardInterrupt:
        logger.info("Interrupted")
    finally:
        balancer.export_profile(args.output_profile)
        balancer.export_thermal_curve(args.output_curve)


if __name__ == '__main__':
    main()
