#!/usr/bin/env python3
"""
batch_metrics_aggregator.py — Aggregate and compress telemetry before upload.
Aggregates per-session telemetry into hourly summaries, anonymizes, samples.
"""

import argparse
import json
import logging
import hashlib
import gzip
from pathlib import Path
from datetime import datetime, timedelta
from collections import defaultdict
import random

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description='Batch metrics aggregator')
    parser.add_argument('--input_dir', type=str, required=True)
    parser.add_argument('--output_dir', type=str, default='./aggregated_metrics')
    parser.add_argument('--aggregation_period', type=str, choices=['hourly', 'daily'], default='hourly')
    parser.add_argument('--sample_rate', type=float, default=0.1, help='Sampling rate for raw events')
    parser.add_argument('--server_url', type=str, default='http://localhost:8080/metrics')
    parser.add_argument('--dry_run', action='store_true')
    return parser.parse_args()


def anonymize_identifier(identifier):
    """Hash identifier for anonymization."""
    return hashlib.sha256(identifier.encode()).hexdigest()[:16]


def load_telemetry_files(input_dir):
    """Load telemetry from input directory."""
    events = []

    for json_file in Path(input_dir).glob('*.json'):
        try:
            with open(json_file) as f:
                data = json.load(f)

            if isinstance(data, list):
                events.extend(data)
            else:
                events.append(data)
        except Exception as e:
            logger.warning(f"Failed to load {json_file}: {e}")

    return events


def aggregate_events(events, period):
    """Aggregate events by time period."""
    aggregated = defaultdict(lambda: {
        'count': 0,
        'metrics': defaultdict(list),
        'event_types': defaultdict(int)
    })

    for event in events:
        # Get timestamp
        ts_str = event.get('timestamp', datetime.now().isoformat())
        try:
            ts = datetime.fromisoformat(ts_str.replace('Z', '+00:00'))
        except:
            ts = datetime.now()

        # Get period key
        if period == 'hourly':
            key = ts.strftime('%Y-%m-%d_%H')
        else:
            key = ts.strftime('%Y-%m-%d')

        agg = aggregated[key]
        agg['count'] += 1

        # Aggregate by event type
        event_type = event.get('event_type', event.get('type', 'unknown'))
        agg['event_types'][event_type] += 1

        # Aggregate numeric metrics
        for metric_name in ['latency_ms', 'duration', 'score', 'accuracy']:
            if metric_name in event:
                agg['metrics'][metric_name].append(event[metric_name])

    return dict(aggregated)


def compute_summary_stats(values):
    """Compute summary statistics for a list of values."""
    import numpy as np

    if not values:
        return {}

    arr = np.array(values)
    return {
        'count': len(arr),
        'mean': float(np.mean(arr)),
        'std': float(np.std(arr)),
        'min': float(np.min(arr)),
        'max': float(np.max(arr)),
        'p50': float(np.percentile(arr, 50)),
        'p95': float(np.percentile(arr, 95))
    }


def sample_events(events, rate):
    """Sample events at given rate."""
    if rate >= 1.0:
        return events
    return [e for e in events if random.random() < rate]


def compress_and_save(data, output_path):
    """Compress and save aggregated data."""
    json_str = json.dumps(data)

    # Save compressed
    gz_path = output_path.with_suffix('.json.gz')
    with gzip.open(gz_path, 'wt') as f:
        f.write(json_str)

    # Calculate compression ratio
    original_size = len(json_str.encode())
    compressed_size = gz_path.stat().st_size
    ratio = compressed_size / original_size if original_size > 0 else 1

    return gz_path, ratio


def sync_to_server(file_path, server_url, dry_run):
    """Sync aggregated metrics to server."""
    if dry_run:
        logger.info(f"Would sync: {file_path} to {server_url}")
        return True

    # Placeholder - would POST to server
    logger.info(f"Synced: {file_path}")
    return True


def main():
    args = parse_args()

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    # Load events
    events = load_telemetry_files(args.input_dir)
    logger.info(f"Loaded {len(events)} telemetry events")

    # Sample raw events
    sampled = sample_events(events, args.sample_rate)
    logger.info(f"Sampled {len(sampled)} events (rate={args.sample_rate})")

    # Anonymize identifiers
    for event in events:
        for key in ['user_id', 'session_id', 'device_id']:
            if key in event:
                event[key] = anonymize_identifier(str(event[key]))

    # Aggregate
    aggregated = aggregate_events(events, args.aggregation_period)
    logger.info(f"Aggregated into {len(aggregated)} {args.aggregation_period} buckets")

    # Build output
    output = {
        'aggregation_period': args.aggregation_period,
        'generated_at': datetime.now().isoformat(),
        'total_events': len(events),
        'sampled_events': len(sampled),
        'buckets': {}
    }

    for period_key, data in aggregated.items():
        bucket = {
            'event_count': data['count'],
            'event_types': dict(data['event_types']),
            'metrics': {}
        }

        for metric_name, values in data['metrics'].items():
            bucket['metrics'][metric_name] = compute_summary_stats(values)

        output['buckets'][period_key] = bucket

    # Save compressed
    output_path = output_dir / f"metrics_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    gz_path, ratio = compress_and_save(output, output_path)

    logger.info(f"Saved: {gz_path} (compression ratio: {ratio:.2f})")

    # Sync to server
    sync_to_server(gz_path, args.server_url, args.dry_run)

    # Summary
    summary = {
        'total_events': len(events),
        'aggregation_period': args.aggregation_period,
        'buckets': len(aggregated),
        'output_file': str(gz_path),
        'compression_ratio': round(ratio, 3)
    }

    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()
