#!/usr/bin/env python3
"""
hardware_heat_simulator.py - Simulate heat buildup from neural workloads

Uses a simplified thermal RC model to simulate heat buildup and predict
safe continuous usage duration for different workload profiles.
"""

import argparse
import json
import math
import logging
from datetime import datetime
from typing import Dict, List, Optional, Tuple

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class ThermalRCModel:
    """Simplified thermal RC circuit model."""

    def __init__(self,
                 r_thermal: float = 0.5,      # Thermal resistance (°C/W)
                 c_thermal: float = 50.0,     # Thermal capacitance (J/°C)
                 ambient: float = 25.0):       # Ambient temperature (°C)
        """
        R_thermal: How easily heat flows out (higher = more insulation)
        C_thermal: How much heat can be stored (higher = slower response)
        Time constant tau = R * C
        """
        self.r_thermal = r_thermal
        self.c_thermal = c_thermal
        self.ambient = ambient
        self.tau = r_thermal * c_thermal  # Time constant

        self.temperature = ambient
        self.time = 0.0

    def step(self, power: float, dt: float) -> float:
        """
        Advance simulation by dt seconds with given power input.

        dT/dt = (P - (T - T_ambient)/R) / C

        Discrete: T_new = T + dt * (P - (T - T_ambient)/R) / C
        """
        heat_in = power
        heat_out = (self.temperature - self.ambient) / self.r_thermal

        dT = (heat_in - heat_out) * dt / self.c_thermal
        self.temperature += dT
        self.time += dt

        return self.temperature

    def get_steady_state(self, power: float) -> float:
        """Get steady-state temperature for given power."""
        return self.ambient + power * self.r_thermal

    def time_to_temperature(self, target: float, power: float) -> float:
        """Calculate time to reach target temperature at given power."""
        steady_state = self.get_steady_state(power)

        if steady_state <= target:
            return float('inf')  # Will never reach target

        if self.temperature >= target:
            return 0.0  # Already at or past target

        # T(t) = T_ss - (T_ss - T_0) * exp(-t/tau)
        # Solve for t: target = T_ss - (T_ss - T_0) * exp(-t/tau)
        # t = -tau * ln((T_ss - target) / (T_ss - T_0))

        ratio = (steady_state - target) / (steady_state - self.temperature)
        if ratio <= 0:
            return 0.0

        return -self.tau * math.log(ratio)

    def reset(self):
        """Reset to ambient temperature."""
        self.temperature = self.ambient
        self.time = 0.0


class WorkloadProfile:
    """Neural workload power profiles."""

    PROFILES = {
        'idle': {
            'power': 1.0,
            'description': 'Device idle, screen on'
        },
        'light_inference': {
            'power': 3.0,
            'description': 'Light ML inference (small model)'
        },
        'medium_inference': {
            'power': 6.0,
            'description': 'Medium ML inference (attention + emotion)'
        },
        'heavy_inference': {
            'power': 10.0,
            'description': 'Heavy ML inference (all models)'
        },
        'training': {
            'power': 15.0,
            'description': 'On-device training/fine-tuning'
        },
        'burst': {
            'power': 20.0,
            'description': 'Burst processing (video analysis)'
        }
    }

    @classmethod
    def get_power(cls, profile_name: str) -> float:
        """Get power for a workload profile."""
        return cls.PROFILES.get(profile_name, cls.PROFILES['idle'])['power']

    @classmethod
    def list_profiles(cls) -> List[str]:
        """List available profiles."""
        return list(cls.PROFILES.keys())


class HardwareHeatSimulator:
    """Simulate heat buildup and predict safe usage duration."""

    def __init__(self, config: Dict):
        self.model = ThermalRCModel(
            r_thermal=config.get('r_thermal', 0.5),
            c_thermal=config.get('c_thermal', 50.0),
            ambient=config.get('ambient', 25.0)
        )

        # Safety thresholds
        self.throttle_temp = config.get('throttle_temp', 70.0)
        self.critical_temp = config.get('critical_temp', 85.0)
        self.max_temp = config.get('max_temp', 95.0)

        self.history = []

    def simulate_workload(self,
                         profile: str,
                         duration: float,
                         dt: float = 0.1) -> List[Dict]:
        """Simulate a workload for given duration."""
        power = WorkloadProfile.get_power(profile)
        self.model.reset()

        results = []
        steps = int(duration / dt)

        for i in range(steps):
            temp = self.model.step(power, dt)

            # Determine state
            if temp >= self.max_temp:
                state = 'shutdown'
            elif temp >= self.critical_temp:
                state = 'critical'
            elif temp >= self.throttle_temp:
                state = 'throttle'
            else:
                state = 'normal'

            results.append({
                'time': self.model.time,
                'temperature': temp,
                'power': power,
                'state': state
            })

            if state == 'shutdown':
                break

        return results

    def predict_safe_duration(self, profile: str) -> Dict:
        """Predict safe continuous usage duration for a workload."""
        power = WorkloadProfile.get_power(profile)
        self.model.reset()

        time_to_throttle = self.model.time_to_temperature(self.throttle_temp, power)
        time_to_critical = self.model.time_to_temperature(self.critical_temp, power)
        time_to_max = self.model.time_to_temperature(self.max_temp, power)

        steady_state = self.model.get_steady_state(power)

        return {
            'profile': profile,
            'power_watts': power,
            'steady_state_temp': steady_state,
            'time_to_throttle_s': time_to_throttle if time_to_throttle != float('inf') else -1,
            'time_to_critical_s': time_to_critical if time_to_critical != float('inf') else -1,
            'time_to_shutdown_s': time_to_max if time_to_max != float('inf') else -1,
            'safe_continuous_s': time_to_throttle if time_to_throttle != float('inf') else -1,
            'will_throttle': steady_state > self.throttle_temp,
            'will_overheat': steady_state > self.max_temp
        }

    def simulate_mixed_workload(self, schedule: List[Tuple[str, float]], dt: float = 0.1) -> List[Dict]:
        """
        Simulate a schedule of mixed workloads.

        schedule: List of (profile_name, duration_seconds)
        """
        self.model.reset()
        results = []

        for profile, duration in schedule:
            power = WorkloadProfile.get_power(profile)
            steps = int(duration / dt)

            for i in range(steps):
                temp = self.model.step(power, dt)

                if temp >= self.max_temp:
                    state = 'shutdown'
                elif temp >= self.critical_temp:
                    state = 'critical'
                elif temp >= self.throttle_temp:
                    state = 'throttle'
                else:
                    state = 'normal'

                results.append({
                    'time': self.model.time,
                    'temperature': temp,
                    'power': power,
                    'profile': profile,
                    'state': state
                })

                if state == 'shutdown':
                    return results

        return results

    def analyze_all_profiles(self) -> Dict:
        """Analyze safe duration for all workload profiles."""
        analysis = {}

        for profile in WorkloadProfile.list_profiles():
            analysis[profile] = self.predict_safe_duration(profile)

        return analysis

    def export_results(self, results: List[Dict], output_path: str):
        """Export simulation results."""
        data = {
            'model_params': {
                'r_thermal': self.model.r_thermal,
                'c_thermal': self.model.c_thermal,
                'tau': self.model.tau,
                'ambient': self.model.ambient
            },
            'thresholds': {
                'throttle': self.throttle_temp,
                'critical': self.critical_temp,
                'max': self.max_temp
            },
            'results': results
        }

        with open(output_path, 'w') as f:
            json.dump(data, f, indent=2)

        logger.info(f"Exported simulation results to {output_path}")


def main():
    parser = argparse.ArgumentParser(description='Hardware heat simulator')
    parser.add_argument('--profile', type=str, default='medium_inference',
                       choices=WorkloadProfile.list_profiles(),
                       help='Workload profile')
    parser.add_argument('--duration', type=float, default=300.0, help='Simulation duration (s)')
    parser.add_argument('--r-thermal', type=float, default=0.5, help='Thermal resistance')
    parser.add_argument('--c-thermal', type=float, default=50.0, help='Thermal capacitance')
    parser.add_argument('--ambient', type=float, default=25.0, help='Ambient temperature')
    parser.add_argument('--throttle', type=float, default=70.0, help='Throttle temperature')
    parser.add_argument('--critical', type=float, default=85.0, help='Critical temperature')
    parser.add_argument('--analyze-all', action='store_true', help='Analyze all profiles')
    parser.add_argument('--output', type=str, default='heat_simulation.json', help='Output path')

    args = parser.parse_args()

    config = {
        'r_thermal': args.r_thermal,
        'c_thermal': args.c_thermal,
        'ambient': args.ambient,
        'throttle_temp': args.throttle,
        'critical_temp': args.critical
    }

    simulator = HardwareHeatSimulator(config)

    if args.analyze_all:
        # Analyze all profiles
        analysis = simulator.analyze_all_profiles()

        logger.info("\n=== Workload Profile Analysis ===")
        for profile, data in analysis.items():
            safe_time = data['safe_continuous_s']
            safe_str = f"{safe_time:.0f}s" if safe_time > 0 else "unlimited"

            logger.info(f"\n{profile}:")
            logger.info(f"  Power: {data['power_watts']:.1f}W")
            logger.info(f"  Steady state: {data['steady_state_temp']:.1f}°C")
            logger.info(f"  Safe duration: {safe_str}")
            logger.info(f"  Will throttle: {data['will_throttle']}")

        with open(args.output, 'w') as f:
            json.dump(analysis, f, indent=2)
    else:
        # Single profile simulation
        prediction = simulator.predict_safe_duration(args.profile)

        logger.info(f"\n=== {args.profile} Prediction ===")
        logger.info(f"Power: {prediction['power_watts']:.1f}W")
        logger.info(f"Steady state: {prediction['steady_state_temp']:.1f}°C")

        if prediction['time_to_throttle_s'] > 0:
            logger.info(f"Time to throttle: {prediction['time_to_throttle_s']:.1f}s")
        else:
            logger.info("Will not throttle")

        # Run simulation
        results = simulator.simulate_workload(args.profile, args.duration)

        # Summary
        max_temp = max(r['temperature'] for r in results)
        final_temp = results[-1]['temperature']
        final_state = results[-1]['state']

        logger.info(f"\nSimulation ({args.duration}s):")
        logger.info(f"Max temperature: {max_temp:.1f}°C")
        logger.info(f"Final temperature: {final_temp:.1f}°C")
        logger.info(f"Final state: {final_state}")

        simulator.export_results(results, args.output)

    logger.info(f"\nResults saved to {args.output}")


if __name__ == '__main__':
    main()
