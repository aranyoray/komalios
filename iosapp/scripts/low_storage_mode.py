#!/usr/bin/env python3
"""
low_storage_mode.py - Detect low free space and disable heavy features

Automatically disables recording, heavy animations, and local offline
caches when storage is low.
"""

import argparse
import json
import os
import shutil
import logging
from datetime import datetime
from pathlib import Path
from typing import Dict, Optional

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class StorageMonitor:
    """Monitor storage usage and free space."""

    def __init__(self, path: str = '.'):
        self.path = Path(path)

    def get_disk_usage(self) -> Dict:
        """Get disk usage statistics."""
        try:
            usage = shutil.disk_usage(self.path)

            return {
                'total_gb': usage.total / (1024**3),
                'used_gb': usage.used / (1024**3),
                'free_gb': usage.free / (1024**3),
                'free_percent': (usage.free / usage.total) * 100
            }
        except Exception as e:
            logger.error(f"Could not get disk usage: {e}")
            return {
                'total_gb': 0,
                'used_gb': 0,
                'free_gb': 0,
                'free_percent': 0,
                'error': str(e)
            }

    def get_app_usage(self, app_dirs: list) -> Dict:
        """Get storage used by app directories."""
        total = 0

        for dir_path in app_dirs:
            path = Path(dir_path)
            if path.exists():
                for f in path.rglob('*'):
                    if f.is_file():
                        try:
                            total += f.stat().st_size
                        except:
                            pass

        return {
            'app_usage_mb': total / (1024**2),
            'app_usage_gb': total / (1024**3)
        }


class LowStorageMode:
    """Manage app behavior in low storage conditions."""

    def __init__(self, config: Dict):
        self.config = config
        self.monitor = StorageMonitor(config.get('monitor_path', '.'))

        # Thresholds
        self.critical_threshold_gb = config.get('critical_threshold_gb', 0.5)
        self.warning_threshold_gb = config.get('warning_threshold_gb', 1.0)
        self.low_threshold_gb = config.get('low_threshold_gb', 2.0)

        # App directories
        self.app_dirs = config.get('app_dirs', [
            'recordings',
            'models',
            'cache',
            'offline_data'
        ])

        # Current mode
        self.current_mode = 'normal'
        self.mode_history = []

    def get_storage_state(self) -> str:
        """Get current storage state."""
        usage = self.monitor.get_disk_usage()
        free = usage['free_gb']

        if free < self.critical_threshold_gb:
            return 'critical'
        elif free < self.warning_threshold_gb:
            return 'warning'
        elif free < self.low_threshold_gb:
            return 'low'
        return 'normal'

    def get_mode_settings(self, state: str) -> Dict:
        """Get recommended settings for storage state."""
        settings = {
            'normal': {
                'recording_enabled': True,
                'recording_quality': 'high',
                'animations_level': 'full',
                'offline_cache_enabled': True,
                'model_caching': True,
                'max_offline_sessions': 50,
                'auto_cleanup': False
            },
            'low': {
                'recording_enabled': True,
                'recording_quality': 'medium',
                'animations_level': 'reduced',
                'offline_cache_enabled': True,
                'model_caching': True,
                'max_offline_sessions': 20,
                'auto_cleanup': True
            },
            'warning': {
                'recording_enabled': True,
                'recording_quality': 'low',
                'animations_level': 'minimal',
                'offline_cache_enabled': False,
                'model_caching': False,
                'max_offline_sessions': 5,
                'auto_cleanup': True
            },
            'critical': {
                'recording_enabled': False,
                'recording_quality': 'none',
                'animations_level': 'none',
                'offline_cache_enabled': False,
                'model_caching': False,
                'max_offline_sessions': 0,
                'auto_cleanup': True,
                'emergency_cleanup': True
            }
        }

        return settings.get(state, settings['normal'])

    def update(self) -> Dict:
        """Update storage mode and get current settings."""
        usage = self.monitor.get_disk_usage()
        state = self.get_storage_state()
        settings = self.get_mode_settings(state)

        # Track mode changes
        if state != self.current_mode:
            self.mode_history.append({
                'from': self.current_mode,
                'to': state,
                'timestamp': datetime.now().isoformat(),
                'free_gb': usage['free_gb']
            })
            logger.info(f"Storage mode changed: {self.current_mode} -> {state} "
                       f"({usage['free_gb']:.2f} GB free)")
            self.current_mode = state

        return {
            'state': state,
            'settings': settings,
            'usage': usage,
            'mode_changed': len(self.mode_history) > 0 and self.mode_history[-1]['to'] == state
        }

    def get_cleanup_recommendations(self) -> Dict:
        """Get recommendations for freeing storage."""
        usage = self.monitor.get_disk_usage()
        app_usage = self.monitor.get_app_usage(self.app_dirs)
        state = self.get_storage_state()

        recommendations = []

        if state in ['warning', 'critical']:
            recommendations.append({
                'action': 'clear_offline_cache',
                'description': 'Delete offline session cache',
                'estimated_savings_mb': 100
            })

            recommendations.append({
                'action': 'clear_model_cache',
                'description': 'Delete cached ML models',
                'estimated_savings_mb': 200
            })

        if state == 'critical':
            recommendations.append({
                'action': 'delete_old_recordings',
                'description': 'Delete recordings older than 7 days',
                'estimated_savings_mb': 500
            })

            recommendations.append({
                'action': 'clear_all_temp',
                'description': 'Clear all temporary files',
                'estimated_savings_mb': 100
            })

        return {
            'state': state,
            'free_gb': usage['free_gb'],
            'app_usage_mb': app_usage['app_usage_mb'],
            'recommendations': recommendations
        }

    def perform_cleanup(self, action: str) -> Dict:
        """Perform a cleanup action."""
        actions = {
            'clear_offline_cache': self._clear_offline_cache,
            'clear_model_cache': self._clear_model_cache,
            'delete_old_recordings': self._delete_old_recordings,
            'clear_all_temp': self._clear_temp
        }

        if action not in actions:
            return {'success': False, 'error': f'Unknown action: {action}'}

        try:
            freed = actions[action]()
            return {
                'success': True,
                'action': action,
                'freed_mb': freed
            }
        except Exception as e:
            return {
                'success': False,
                'action': action,
                'error': str(e)
            }

    def _clear_offline_cache(self) -> float:
        """Clear offline cache."""
        cache_dir = Path('cache/offline')
        return self._delete_dir_contents(cache_dir)

    def _clear_model_cache(self) -> float:
        """Clear model cache."""
        cache_dir = Path('cache/models')
        return self._delete_dir_contents(cache_dir)

    def _delete_old_recordings(self) -> float:
        """Delete recordings older than 7 days."""
        import time

        recordings_dir = Path('recordings')
        cutoff = time.time() - (7 * 24 * 3600)
        freed = 0

        if recordings_dir.exists():
            for f in recordings_dir.rglob('*'):
                if f.is_file() and f.stat().st_mtime < cutoff:
                    size = f.stat().st_size
                    f.unlink()
                    freed += size

        return freed / (1024**2)

    def _clear_temp(self) -> float:
        """Clear temp files."""
        temp_dir = Path('temp')
        return self._delete_dir_contents(temp_dir)

    def _delete_dir_contents(self, dir_path: Path) -> float:
        """Delete all contents of a directory."""
        freed = 0

        if dir_path.exists():
            for f in dir_path.rglob('*'):
                if f.is_file():
                    try:
                        freed += f.stat().st_size
                        f.unlink()
                    except:
                        pass

        return freed / (1024**2)

    def get_ui_hooks(self) -> Dict:
        """Get UI hooks for current storage state."""
        state = self.get_storage_state()
        usage = self.monitor.get_disk_usage()

        hooks = {
            'show_storage_warning': state in ['warning', 'critical'],
            'show_storage_critical': state == 'critical',
            'disable_recording': state == 'critical',
            'show_cleanup_prompt': state in ['warning', 'critical'],
            'storage_bar_color': {
                'normal': 'green',
                'low': 'yellow',
                'warning': 'orange',
                'critical': 'red'
            }.get(state, 'green'),
            'free_space_text': f"{usage['free_gb']:.1f} GB free"
        }

        if state == 'critical':
            hooks['warning_message'] = "Storage almost full! Recording disabled. Please free up space."
        elif state == 'warning':
            hooks['warning_message'] = "Storage low. Some features limited."

        return hooks

    def get_stats(self) -> Dict:
        """Get storage mode statistics."""
        usage = self.monitor.get_disk_usage()
        app_usage = self.monitor.get_app_usage(self.app_dirs)

        return {
            'current_mode': self.current_mode,
            'disk_usage': usage,
            'app_usage': app_usage,
            'mode_changes': len(self.mode_history),
            'history': self.mode_history[-5:]  # Last 5 changes
        }


def main():
    parser = argparse.ArgumentParser(description='Low storage mode manager')
    parser.add_argument('--critical', type=float, default=0.5, help='Critical threshold GB')
    parser.add_argument('--warning', type=float, default=1.0, help='Warning threshold GB')
    parser.add_argument('--low', type=float, default=2.0, help='Low threshold GB')
    parser.add_argument('--cleanup', type=str, help='Perform cleanup action')
    parser.add_argument('--recommendations', action='store_true', help='Show cleanup recommendations')

    args = parser.parse_args()

    config = {
        'critical_threshold_gb': args.critical,
        'warning_threshold_gb': args.warning,
        'low_threshold_gb': args.low
    }

    mode_manager = LowStorageMode(config)

    # Get current state
    state = mode_manager.update()

    logger.info(f"\n=== Storage Status ===")
    logger.info(f"State: {state['state']}")
    logger.info(f"Free: {state['usage']['free_gb']:.2f} GB ({state['usage']['free_percent']:.1f}%)")
    logger.info(f"Recording: {'enabled' if state['settings']['recording_enabled'] else 'disabled'}")
    logger.info(f"Offline cache: {'enabled' if state['settings']['offline_cache_enabled'] else 'disabled'}")

    if args.recommendations:
        recs = mode_manager.get_cleanup_recommendations()
        logger.info(f"\n=== Cleanup Recommendations ===")
        for rec in recs['recommendations']:
            logger.info(f"- {rec['description']} (~{rec['estimated_savings_mb']} MB)")

    if args.cleanup:
        result = mode_manager.perform_cleanup(args.cleanup)
        if result['success']:
            logger.info(f"Cleanup complete: freed {result['freed_mb']:.1f} MB")
        else:
            logger.error(f"Cleanup failed: {result['error']}")

    # Show UI hooks
    hooks = mode_manager.get_ui_hooks()
    if hooks.get('warning_message'):
        logger.warning(hooks['warning_message'])


if __name__ == '__main__':
    main()
