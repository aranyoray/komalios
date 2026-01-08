#!/usr/bin/env python3
"""
emotion_overstim_protector.py - Detect overstimulation and switch to calming mode

Detects rapid gaze shifts, AU spikes indicating overstimulation.
"""

import argparse
import json
import numpy as np
import logging
from datetime import datetime
from typing import Dict, List
from collections import deque

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class OverstimulationDetector:
    """Detect signs of overstimulation."""

    def __init__(self, config: Dict):
        self.config = config

        # Thresholds
        self.gaze_shift_threshold = config.get('gaze_shift_threshold', 5)  # shifts per second
        self.au_spike_threshold = config.get('au_spike_threshold', 0.7)
        self.heart_rate_threshold = config.get('heart_rate_threshold', 120)  # if available

        # History windows
        self.gaze_history = deque(maxlen=30)  # 1 second at 30fps
        self.au_history = deque(maxlen=30)
        self.overstim_score_history = deque(maxlen=300)  # 10 seconds

        # State
        self.is_overstimulated = False
        self.calming_mode_active = False
        self.events = []

    def update_gaze(self, gaze_x: float, gaze_y: float):
        """Update gaze position."""
        if self.gaze_history:
            last = self.gaze_history[-1]
            shift = np.sqrt((gaze_x - last[0])**2 + (gaze_y - last[1])**2)
        else:
            shift = 0

        self.gaze_history.append((gaze_x, gaze_y, shift))

    def update_au(self, action_units: Dict[str, float]):
        """Update facial action units."""
        # Key AUs for overstimulation: AU4 (brow), AU7 (lid tightener), AU20 (lip stretch)
        intensity = np.mean([
            action_units.get('AU4', 0),
            action_units.get('AU7', 0),
            action_units.get('AU20', 0)
        ])

        self.au_history.append(intensity)

    def calculate_overstim_score(self) -> float:
        """Calculate current overstimulation score (0-1)."""
        scores = []

        # Gaze shift rate
        if len(self.gaze_history) >= 10:
            recent_shifts = [g[2] for g in list(self.gaze_history)[-10:]]
            significant_shifts = sum(1 for s in recent_shifts if s > 0.1)
            shift_rate = significant_shifts / 10 * 30  # per second
            gaze_score = min(1.0, shift_rate / self.gaze_shift_threshold)
            scores.append(gaze_score)

        # AU intensity
        if len(self.au_history) >= 5:
            recent_au = list(self.au_history)[-5:]
            avg_au = np.mean(recent_au)
            au_score = min(1.0, avg_au / self.au_spike_threshold)
            scores.append(au_score)

        # AU variance (rapid changes)
        if len(self.au_history) >= 10:
            au_variance = np.var(list(self.au_history)[-10:])
            variance_score = min(1.0, au_variance * 10)
            scores.append(variance_score)

        if not scores:
            return 0.0

        return np.mean(scores)

    def check_overstimulation(self) -> Dict:
        """Check for overstimulation and update state."""
        score = self.calculate_overstim_score()
        self.overstim_score_history.append(score)

        # Smooth detection with hysteresis
        if len(self.overstim_score_history) >= 10:
            recent_avg = np.mean(list(self.overstim_score_history)[-10:])

            # Enter overstimulation
            if not self.is_overstimulated and recent_avg > 0.7:
                self.is_overstimulated = True
                self._record_event('overstim_detected', score)

            # Exit overstimulation (with lower threshold for hysteresis)
            elif self.is_overstimulated and recent_avg < 0.4:
                self.is_overstimulated = False
                self._record_event('overstim_resolved', score)

        return {
            'score': score,
            'is_overstimulated': self.is_overstimulated,
            'calming_mode_active': self.calming_mode_active
        }

    def _record_event(self, event_type: str, score: float):
        """Record overstimulation event."""
        event = {
            'type': event_type,
            'score': score,
            'timestamp': datetime.now().isoformat()
        }
        self.events.append(event)
        logger.info(f"Event: {event_type} (score={score:.2f})")


class CalmingModeController:
    """Control calming mode interventions."""

    def __init__(self, config: Dict):
        self.config = config
        self.active = False

        # Calming settings
        self.calming_settings = {
            'animation_speed': 0.5,
            'color_saturation': 0.7,
            'sound_volume': 0.5,
            'avatar_expression': 'calm',
            'background': 'soft_blue',
            'particle_effects': False
        }

    def activate(self) -> Dict:
        """Activate calming mode."""
        self.active = True
        logger.info("Calming mode activated")
        return self.calming_settings

    def deactivate(self) -> Dict:
        """Deactivate calming mode."""
        self.active = False
        logger.info("Calming mode deactivated")
        return {
            'animation_speed': 1.0,
            'color_saturation': 1.0,
            'sound_volume': 1.0,
            'avatar_expression': 'neutral',
            'background': 'default',
            'particle_effects': True
        }


class EmotionOverstimProtector:
    """Main overstimulation protector."""

    def __init__(self, config: Dict):
        self.detector = OverstimulationDetector(config)
        self.calming = CalmingModeController(config)

        self.auto_calming = config.get('auto_calming', True)

    def update(self, gaze: tuple = None, action_units: Dict = None) -> Dict:
        """Update with new sensor data."""
        if gaze:
            self.detector.update_gaze(gaze[0], gaze[1])

        if action_units:
            self.detector.update_au(action_units)

        result = self.detector.check_overstimulation()

        # Auto-activate calming mode
        if self.auto_calming:
            if result['is_overstimulated'] and not self.calming.active:
                settings = self.calming.activate()
                result['calming_settings'] = settings
            elif not result['is_overstimulated'] and self.calming.active:
                settings = self.calming.deactivate()
                result['calming_settings'] = settings

        result['calming_active'] = self.calming.active
        return result

    def get_stats(self) -> Dict:
        """Get protector statistics."""
        return {
            'events': len(self.detector.events),
            'calming_active': self.calming.active,
            'recent_events': self.detector.events[-5:]
        }


def main():
    parser = argparse.ArgumentParser(description='Emotion overstimulation protector')
    parser.add_argument('--demo', action='store_true')

    args = parser.parse_args()

    protector = EmotionOverstimProtector({})

    if args.demo:
        logger.info("Running overstimulation detection demo")

        # Simulate normal state
        logger.info("\nPhase 1: Normal activity")
        for i in range(30):
            gaze = (0.5 + np.random.randn() * 0.05, 0.5 + np.random.randn() * 0.05)
            aus = {'AU4': 0.2, 'AU7': 0.1, 'AU20': 0.1}
            result = protector.update(gaze, aus)

        logger.info(f"Score: {result['score']:.2f}, Overstim: {result['is_overstimulated']}")

        # Simulate overstimulation
        logger.info("\nPhase 2: Overstimulation")
        for i in range(50):
            # Rapid gaze shifts
            gaze = (np.random.random(), np.random.random())
            # High AU intensity
            aus = {'AU4': 0.8, 'AU7': 0.7, 'AU20': 0.6}
            result = protector.update(gaze, aus)

            if i % 10 == 0:
                logger.info(f"Score: {result['score']:.2f}, Calming: {result['calming_active']}")

        # Recovery
        logger.info("\nPhase 3: Recovery")
        for i in range(50):
            gaze = (0.5 + np.random.randn() * 0.02, 0.5 + np.random.randn() * 0.02)
            aus = {'AU4': 0.1, 'AU7': 0.1, 'AU20': 0.1}
            result = protector.update(gaze, aus)

        logger.info(f"Score: {result['score']:.2f}, Calming: {result['calming_active']}")

        # Stats
        stats = protector.get_stats()
        logger.info(f"\n=== Stats ===")
        logger.info(f"Total events: {stats['events']}")


if __name__ == '__main__':
    main()
