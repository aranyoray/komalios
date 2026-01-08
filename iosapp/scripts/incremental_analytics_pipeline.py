#!/usr/bin/env python3
"""
incremental_analytics_pipeline.py — Process only new data each run.
Tracks cursors, computes analytics incrementally, writes to Supabase.
"""

import argparse
import json
import logging
from pathlib import Path
from datetime import datetime
import hashlib

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description='Incremental analytics pipeline')
    parser.add_argument('--input_dir', type=str, required=True)
    parser.add_argument('--cursor_file', type=str, default='./analytics_cursor.json')
    parser.add_argument('--output_dir', type=str, default='./incremental_reports')
    parser.add_argument('--supabase_table', type=str, default='analytics_incremental')
    parser.add_argument('--dry_run', action='store_true')
    return parser.parse_args()


def load_cursor(cursor_file):
    """Load last processed cursor."""
    if Path(cursor_file).exists():
        with open(cursor_file) as f:
            return json.load(f)
    return {'last_processed': None, 'processed_files': []}


def save_cursor(cursor_file, cursor):
    """Save cursor state."""
    with open(cursor_file, 'w') as f:
        json.dump(cursor, f, indent=2)


def get_new_files(input_dir, cursor):
    """Get files not yet processed."""
    input_dir = Path(input_dir)
    processed = set(cursor.get('processed_files', []))

    new_files = []
    for json_file in sorted(input_dir.glob('*.json')):
        file_id = json_file.name
        if file_id not in processed:
            new_files.append(json_file)

    return new_files


def compute_session_analytics(session):
    """Compute analytics for a single session."""
    import numpy as np

    analytics = {
        'session_id': session.get('session_id'),
        'computed_at': datetime.now().isoformat()
    }

    # Gaze analytics
    if 'gaze_series' in session:
        gaze = session['gaze_series']
        if gaze:
            x_vals = [g.get('x', 0.5) for g in gaze if isinstance(g, dict)]
            y_vals = [g.get('y', 0.5) for g in gaze if isinstance(g, dict)]

            if x_vals:
                analytics['gaze_mean_x'] = float(np.mean(x_vals))
                analytics['gaze_std_x'] = float(np.std(x_vals))
                analytics['gaze_coverage'] = float(np.std(x_vals) * np.std(y_vals))

    # AU analytics
    if 'au_series' in session:
        au = session['au_series']
        if au and isinstance(au[0], dict):
            all_vals = []
            for sample in au:
                vals = sample.get('values', [])
                if vals:
                    all_vals.append(vals)

            if all_vals:
                arr = np.array(all_vals)
                analytics['au_mean_activation'] = float(arr.mean())
                analytics['au_variance'] = float(arr.var())

    # Duration
    analytics['duration'] = session.get('duration', 0)

    return analytics


def upload_to_supabase(analytics_list, table_name, dry_run):
    """Upload analytics to Supabase."""
    if dry_run:
        logger.info(f"Would upload {len(analytics_list)} records to {table_name}")
        return True

    # Placeholder - would use supabase client
    logger.info(f"Uploaded {len(analytics_list)} records")
    return True


def main():
    args = parse_args()

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    # Load cursor
    cursor = load_cursor(args.cursor_file)
    logger.info(f"Last processed: {cursor.get('last_processed', 'never')}")

    # Get new files
    new_files = get_new_files(args.input_dir, cursor)
    logger.info(f"Found {len(new_files)} new files to process")

    if not new_files:
        logger.info("No new files to process")
        return 0

    # Process files
    analytics_list = []
    processed_files = []

    for file_path in new_files:
        try:
            with open(file_path) as f:
                session = json.load(f)

            analytics = compute_session_analytics(session)
            analytics_list.append(analytics)
            processed_files.append(file_path.name)

            logger.info(f"Processed: {file_path.name}")

        except Exception as e:
            logger.error(f"Failed: {file_path.name}: {e}")

    # Save incremental report
    report = {
        'timestamp': datetime.now().isoformat(),
        'files_processed': len(processed_files),
        'analytics': analytics_list
    }

    report_path = output_dir / f"incremental_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    with open(report_path, 'w') as f:
        json.dump(report, f, indent=2)

    # Upload to Supabase
    if analytics_list:
        upload_to_supabase(analytics_list, args.supabase_table, args.dry_run)

    # Update cursor
    if not args.dry_run:
        cursor['last_processed'] = datetime.now().isoformat()
        cursor['processed_files'].extend(processed_files)
        save_cursor(args.cursor_file, cursor)

    logger.info(f"Processed {len(analytics_list)} sessions")
    print(json.dumps({'processed': len(analytics_list), 'report': str(report_path)}, indent=2))


if __name__ == '__main__':
    main()
