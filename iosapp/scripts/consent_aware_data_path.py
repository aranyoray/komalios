#!/usr/bin/env python3
"""
consent_aware_data_path.py - Route data based on consent flags

Routes data into different folder structures depending on consent,
blocking all raw data if consent=false.
"""

import argparse
import json
import os
import shutil
import logging
from pathlib import Path
from typing import Dict, Optional
from datetime import datetime

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class ConsentManager:
    """Manage user consent settings."""

    def __init__(self, consent_file: str = 'consent_settings.json'):
        self.consent_file = Path(consent_file)
        self.consents = self._load()

    def _load(self) -> Dict:
        if self.consent_file.exists():
            with open(self.consent_file, 'r') as f:
                return json.load(f)
        return {}

    def save(self):
        with open(self.consent_file, 'w') as f:
            json.dump(self.consents, f, indent=2)

    def set_consent(self, user_id: str, consent_type: str, granted: bool):
        if user_id not in self.consents:
            self.consents[user_id] = {}
        self.consents[user_id][consent_type] = {
            'granted': granted,
            'timestamp': datetime.now().isoformat()
        }
        self.save()

    def get_consent(self, user_id: str, consent_type: str) -> bool:
        return self.consents.get(user_id, {}).get(consent_type, {}).get('granted', False)

    def get_all_consents(self, user_id: str) -> Dict:
        return self.consents.get(user_id, {})


class ConsentAwareDataPath:
    """Route data based on consent."""

    CONSENT_TYPES = [
        'raw_video',
        'raw_audio',
        'facial_data',
        'voice_data',
        'analytics',
        'cloud_sync',
        'research_use'
    ]

    def __init__(self, config: Dict):
        self.config = config
        self.base_dir = Path(config.get('base_dir', 'user_data'))
        self.consent_manager = ConsentManager(config.get('consent_file', 'consent_settings.json'))

        # Create directory structure
        self._setup_directories()

    def _setup_directories(self):
        """Create directory structure."""
        dirs = [
            'consented/raw',
            'consented/processed',
            'consented/analytics',
            'non_consented/aggregated_only',
            'quarantine'
        ]
        for d in dirs:
            (self.base_dir / d).mkdir(parents=True, exist_ok=True)

    def get_data_path(self, user_id: str, data_type: str) -> Optional[Path]:
        """Get appropriate path for data based on consent."""
        # Map data types to consent types
        consent_map = {
            'video_frame': 'raw_video',
            'audio_chunk': 'raw_audio',
            'face_landmarks': 'facial_data',
            'voice_features': 'voice_data',
            'session_metrics': 'analytics',
            'emotion_scores': 'facial_data'
        }

        required_consent = consent_map.get(data_type, 'analytics')

        if self.consent_manager.get_consent(user_id, required_consent):
            return self.base_dir / 'consented' / 'raw' / user_id / data_type
        elif self.consent_manager.get_consent(user_id, 'analytics'):
            # Can store aggregated/anonymized version
            return self.base_dir / 'non_consented' / 'aggregated_only' / data_type
        else:
            # No consent - quarantine or reject
            return None

    def store_data(self, user_id: str, data_type: str, data: bytes) -> Dict:
        """Store data with consent awareness."""
        path = self.get_data_path(user_id, data_type)

        if path is None:
            logger.warning(f"No consent for {data_type} from {user_id}, data rejected")
            return {
                'stored': False,
                'reason': 'no_consent',
                'data_type': data_type
            }

        path.parent.mkdir(parents=True, exist_ok=True)
        filename = f"{datetime.now().strftime('%Y%m%d_%H%M%S')}.bin"
        filepath = path / filename

        with open(filepath, 'wb') as f:
            f.write(data)

        logger.debug(f"Stored {data_type} at {filepath}")

        return {
            'stored': True,
            'path': str(filepath),
            'data_type': data_type
        }

    def cleanup_revoked_consent(self, user_id: str, consent_type: str):
        """Clean up data when consent is revoked."""
        # Map consent to data directories
        dir_map = {
            'raw_video': 'video_frame',
            'raw_audio': 'audio_chunk',
            'facial_data': ['face_landmarks', 'emotion_scores'],
            'voice_data': 'voice_features'
        }

        data_types = dir_map.get(consent_type, [])
        if isinstance(data_types, str):
            data_types = [data_types]

        for data_type in data_types:
            path = self.base_dir / 'consented' / 'raw' / user_id / data_type
            if path.exists():
                shutil.rmtree(path)
                logger.info(f"Deleted {path} due to revoked {consent_type} consent")

    def get_storage_report(self, user_id: str) -> Dict:
        """Get storage report for user."""
        consents = self.consent_manager.get_all_consents(user_id)

        user_dir = self.base_dir / 'consented' / 'raw' / user_id
        total_size = 0
        file_count = 0

        if user_dir.exists():
            for f in user_dir.rglob('*'):
                if f.is_file():
                    total_size += f.stat().st_size
                    file_count += 1

        return {
            'user_id': user_id,
            'consents': consents,
            'storage_mb': total_size / (1024**2),
            'file_count': file_count
        }


def main():
    parser = argparse.ArgumentParser(description='Consent-aware data path manager')
    parser.add_argument('--base-dir', type=str, default='user_data')
    parser.add_argument('--user', type=str, default='user_001')
    parser.add_argument('--set-consent', type=str, help='consent_type:true/false')
    parser.add_argument('--demo', action='store_true')

    args = parser.parse_args()

    manager = ConsentAwareDataPath({'base_dir': args.base_dir})

    if args.set_consent:
        consent_type, value = args.set_consent.split(':')
        granted = value.lower() == 'true'
        manager.consent_manager.set_consent(args.user, consent_type, granted)
        logger.info(f"Set {consent_type}={granted} for {args.user}")

    if args.demo:
        # Set up demo consents
        manager.consent_manager.set_consent(args.user, 'analytics', True)
        manager.consent_manager.set_consent(args.user, 'facial_data', True)
        manager.consent_manager.set_consent(args.user, 'raw_video', False)

        # Try storing different data types
        data_types = ['session_metrics', 'emotion_scores', 'video_frame', 'audio_chunk']

        for dtype in data_types:
            result = manager.store_data(args.user, dtype, b'test_data')
            status = 'STORED' if result['stored'] else f"REJECTED ({result['reason']})"
            logger.info(f"{dtype}: {status}")

        # Report
        report = manager.get_storage_report(args.user)
        logger.info(f"\n=== Storage Report ===")
        logger.info(f"Files: {report['file_count']}, Size: {report['storage_mb']:.2f} MB")


if __name__ == '__main__':
    main()
