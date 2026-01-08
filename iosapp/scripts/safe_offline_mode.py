#!/usr/bin/env python3
"""
safe_offline_mode.py - Turn app fully offline safely

Disables cloud calls, uses cached models, tracks time since last sync.
"""

import argparse
import json
import time
import logging
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, Optional

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class SafeOfflineMode:
    """Manage safe offline operation."""

    def __init__(self, config: Dict):
        self.config = config
        self.state_file = Path(config.get('state_file', 'offline_state.json'))

        self.state = self._load_state()
        self.cached_models = self._scan_cached_models()

    def _load_state(self) -> Dict:
        """Load offline state."""
        if self.state_file.exists():
            with open(self.state_file, 'r') as f:
                return json.load(f)

        return {
            'is_offline': False,
            'offline_since': None,
            'last_sync': None,
            'pending_syncs': 0,
            'cached_sessions': 0
        }

    def _save_state(self):
        """Save offline state."""
        with open(self.state_file, 'w') as f:
            json.dump(self.state, f, indent=2)

    def _scan_cached_models(self) -> Dict:
        """Scan for cached models."""
        model_dir = Path(self.config.get('model_dir', 'models'))
        models = {}

        if model_dir.exists():
            for model_file in model_dir.glob('*.tflite'):
                models[model_file.stem] = {
                    'path': str(model_file),
                    'size_mb': model_file.stat().st_size / (1024**2),
                    'modified': datetime.fromtimestamp(model_file.stat().st_mtime).isoformat()
                }

            for model_file in model_dir.glob('*.onnx'):
                models[model_file.stem] = {
                    'path': str(model_file),
                    'size_mb': model_file.stat().st_size / (1024**2),
                    'modified': datetime.fromtimestamp(model_file.stat().st_mtime).isoformat()
                }

        return models

    def enter_offline_mode(self):
        """Enter offline mode."""
        self.state['is_offline'] = True
        self.state['offline_since'] = datetime.now().isoformat()
        self._save_state()
        logger.info("Entered offline mode")

    def exit_offline_mode(self):
        """Exit offline mode."""
        self.state['is_offline'] = False
        self.state['offline_since'] = None
        self._save_state()
        logger.info("Exited offline mode")

    def record_sync(self):
        """Record a successful sync."""
        self.state['last_sync'] = datetime.now().isoformat()
        self.state['pending_syncs'] = 0
        self._save_state()

    def queue_sync(self):
        """Queue data for sync when online."""
        self.state['pending_syncs'] += 1
        self._save_state()

    def get_time_since_sync(self) -> Optional[timedelta]:
        """Get time since last sync."""
        if self.state['last_sync']:
            last = datetime.fromisoformat(self.state['last_sync'])
            return datetime.now() - last
        return None

    def get_offline_duration(self) -> Optional[timedelta]:
        """Get how long we've been offline."""
        if self.state['offline_since']:
            since = datetime.fromisoformat(self.state['offline_since'])
            return datetime.now() - since
        return None

    def get_available_features(self) -> Dict:
        """Get features available in offline mode."""
        features = {
            'core_activities': True,
            'emotion_recognition': 'emotion' in self.cached_models,
            'attention_tracking': 'attention' in self.cached_models,
            'voice_analysis': 'voice' in self.cached_models,
            'session_recording': True,
            'cloud_sync': not self.state['is_offline'],
            'reports': False,  # Need cloud
            'new_content': False  # Need cloud
        }

        return features

    def get_ui_config(self) -> Dict:
        """Get UI configuration for offline mode."""
        time_since_sync = self.get_time_since_sync()
        offline_duration = self.get_offline_duration()

        config = {
            'show_offline_indicator': self.state['is_offline'],
            'show_sync_warning': False,
            'sync_button_enabled': not self.state['is_offline'],
            'pending_syncs': self.state['pending_syncs']
        }

        # Warnings
        if time_since_sync and time_since_sync > timedelta(days=1):
            config['show_sync_warning'] = True
            config['sync_warning_message'] = f"Last sync was {time_since_sync.days} days ago"

        if self.state['pending_syncs'] > 10:
            config['sync_urgent'] = True
            config['sync_urgent_message'] = f"{self.state['pending_syncs']} sessions waiting to sync"

        return config

    def get_status(self) -> Dict:
        """Get complete offline status."""
        time_since_sync = self.get_time_since_sync()
        offline_duration = self.get_offline_duration()

        return {
            'is_offline': self.state['is_offline'],
            'offline_since': self.state['offline_since'],
            'offline_duration_hours': offline_duration.total_seconds() / 3600 if offline_duration else 0,
            'last_sync': self.state['last_sync'],
            'time_since_sync_hours': time_since_sync.total_seconds() / 3600 if time_since_sync else 0,
            'pending_syncs': self.state['pending_syncs'],
            'cached_models': list(self.cached_models.keys()),
            'available_features': self.get_available_features()
        }


def main():
    parser = argparse.ArgumentParser(description='Safe offline mode manager')
    parser.add_argument('--enter', action='store_true', help='Enter offline mode')
    parser.add_argument('--exit', action='store_true', help='Exit offline mode')
    parser.add_argument('--status', action='store_true', help='Show status')
    parser.add_argument('--demo', action='store_true', help='Run demo')

    args = parser.parse_args()

    manager = SafeOfflineMode({})

    if args.enter:
        manager.enter_offline_mode()
    elif args.exit:
        manager.exit_offline_mode()
        manager.record_sync()

    if args.demo:
        # Demo offline mode
        manager.record_sync()  # Pretend we synced
        manager.enter_offline_mode()

        for i in range(5):
            manager.queue_sync()

        logger.info("Demo: Now in offline mode with 5 pending syncs")

    if args.status or args.demo:
        status = manager.get_status()
        ui = manager.get_ui_config()

        logger.info(f"\n=== Offline Mode Status ===")
        logger.info(f"Offline: {status['is_offline']}")
        logger.info(f"Pending syncs: {status['pending_syncs']}")
        logger.info(f"Time since sync: {status['time_since_sync_hours']:.1f} hours")
        logger.info(f"Cached models: {', '.join(status['cached_models']) or 'None'}")

        features = status['available_features']
        logger.info(f"\nAvailable features:")
        for feature, available in features.items():
            status_str = 'Yes' if available else 'No'
            logger.info(f"  {feature}: {status_str}")


if __name__ == '__main__':
    main()
