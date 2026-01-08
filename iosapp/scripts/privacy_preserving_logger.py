#!/usr/bin/env python3
"""
privacy_preserving_logger.py - Apply hashing, aggregation, k-anonymity to logs

Ensures logs contain no PII before storage or upload.
"""

import argparse
import json
import hashlib
import numpy as np
import logging
from datetime import datetime
from typing import Dict, List, Any

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class PrivacyPreservingLogger:
    """Logger with privacy-preserving transformations."""

    def __init__(self, config: Dict):
        self.config = config
        self.k_anonymity = config.get('k_anonymity', 5)
        self.salt = config.get('salt', 'komal_privacy_salt')
        self.logs = []
        self.aggregation_buffer = []

    def hash_identifier(self, value: str) -> str:
        """Hash an identifier (user_id, device_id, etc.)."""
        salted = f"{self.salt}:{value}"
        return hashlib.sha256(salted.encode()).hexdigest()[:16]

    def generalize_age(self, age: int) -> str:
        """Generalize age to bucket for k-anonymity."""
        if age < 5:
            return '3-5'
        elif age < 8:
            return '5-8'
        elif age < 12:
            return '8-12'
        else:
            return '12-15'

    def generalize_location(self, location: Dict) -> Dict:
        """Generalize location to region level."""
        # Remove precise coordinates, keep only region
        return {
            'region': location.get('region', 'unknown'),
            'country': location.get('country', 'unknown')
        }

    def suppress_rare_values(self, field: str, value: Any, counts: Dict) -> Any:
        """Suppress values that appear less than k times."""
        if counts.get(value, 0) < self.k_anonymity:
            return 'OTHER'
        return value

    def sanitize_event(self, event: Dict) -> Dict:
        """Sanitize a single event."""
        sanitized = {}

        for key, value in event.items():
            # Hash identifiers
            if key in ['user_id', 'device_id', 'session_id', 'parent_id']:
                sanitized[key] = self.hash_identifier(str(value))

            # Generalize age
            elif key == 'age':
                sanitized['age_group'] = self.generalize_age(value)

            # Generalize location
            elif key == 'location':
                sanitized['location'] = self.generalize_location(value)

            # Remove PII fields entirely
            elif key in ['name', 'email', 'phone', 'address', 'ip_address']:
                continue

            # Round timestamps to hour
            elif key == 'timestamp':
                dt = datetime.fromisoformat(value) if isinstance(value, str) else value
                sanitized['timestamp_hour'] = dt.replace(minute=0, second=0, microsecond=0).isoformat()

            # Keep safe fields
            elif key in ['event_type', 'attention', 'engagement', 'emotion', 'duration']:
                sanitized[key] = value

            # Aggregate numeric arrays
            elif isinstance(value, (list, np.ndarray)) and len(value) > 0:
                arr = np.array(value)
                if np.issubdtype(arr.dtype, np.number):
                    sanitized[f"{key}_mean"] = float(np.mean(arr))
                    sanitized[f"{key}_std"] = float(np.std(arr))

        return sanitized

    def log_event(self, event: Dict):
        """Log an event with privacy preservation."""
        sanitized = self.sanitize_event(event)
        self.aggregation_buffer.append(sanitized)

        # Aggregate when buffer reaches k
        if len(self.aggregation_buffer) >= self.k_anonymity:
            aggregated = self.aggregate_buffer()
            self.logs.append(aggregated)
            self.aggregation_buffer = []

    def aggregate_buffer(self) -> Dict:
        """Aggregate buffered events."""
        if not self.aggregation_buffer:
            return {}

        aggregated = {
            'count': len(self.aggregation_buffer),
            'timestamp': datetime.now().isoformat()
        }

        # Aggregate numeric fields
        numeric_fields = ['attention', 'engagement', 'duration']
        for field in numeric_fields:
            values = [e.get(field) for e in self.aggregation_buffer if field in e]
            if values:
                aggregated[f"{field}_mean"] = float(np.mean(values))
                aggregated[f"{field}_std"] = float(np.std(values))

        # Count event types
        event_types = [e.get('event_type') for e in self.aggregation_buffer if 'event_type' in e]
        if event_types:
            from collections import Counter
            aggregated['event_types'] = dict(Counter(event_types))

        return aggregated

    def export_logs(self, output_path: str):
        """Export sanitized logs."""
        # Flush remaining buffer
        if self.aggregation_buffer:
            aggregated = self.aggregate_buffer()
            self.logs.append(aggregated)

        with open(output_path, 'w') as f:
            json.dump(self.logs, f, indent=2)

        logger.info(f"Exported {len(self.logs)} aggregated log entries")


def main():
    parser = argparse.ArgumentParser(description='Privacy preserving logger')
    parser.add_argument('--k', type=int, default=5, help='k-anonymity level')
    parser.add_argument('--output', type=str, default='private_logs.json')
    parser.add_argument('--demo', action='store_true')

    args = parser.parse_args()

    plogger = PrivacyPreservingLogger({'k_anonymity': args.k})

    if args.demo:
        # Generate test events
        for i in range(20):
            event = {
                'user_id': f'user_{i % 5}',
                'device_id': f'device_{i % 3}',
                'session_id': f'session_{i}',
                'name': f'Child {i}',
                'email': f'parent{i}@example.com',
                'age': 5 + i % 10,
                'location': {'lat': 37.7749, 'lng': -122.4194, 'region': 'CA', 'country': 'US'},
                'timestamp': datetime.now().isoformat(),
                'event_type': ['session_start', 'activity', 'emotion_spike'][i % 3],
                'attention': np.random.random(),
                'engagement': np.random.random(),
                'duration': np.random.randint(10, 300)
            }

            plogger.log_event(event)

        plogger.export_logs(args.output)
        logger.info(f"Demo complete. Check {args.output}")


if __name__ == '__main__':
    main()
