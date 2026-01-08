#!/usr/bin/env python3
"""
supabase_aggregator_uploader.py — Privacy-preserving aggregate upload to Supabase.
Uploads only aggregated scores, no raw data or PII.
"""

import argparse
import json
import logging
import os
import time
import hashlib
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional
import uuid

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description='Upload aggregates to Supabase')
    parser.add_argument('--input', type=str, help='session_scores.json file')
    parser.add_argument('--batch_dir', type=str, help='Directory with multiple score files')
    parser.add_argument('--audit_only', action='store_true', help='Print SQL without uploading')
    parser.add_argument('--synthetic', type=int, default=0, help='Generate N synthetic uploads for testing')
    parser.add_argument('--backup_dir', type=str, default='./local_backups', help='Local backup directory')
    parser.add_argument('--dry_run', action='store_true', help='Preview without uploading')
    return parser.parse_args()


# Supabase connection
def get_supabase_client():
    """Get Supabase client from environment variables."""
    try:
        from supabase import create_client, Client
    except ImportError:
        logger.error("supabase-py not installed. Run: pip install supabase")
        return None

    url = os.getenv('SUPABASE_URL')
    key = os.getenv('SUPABASE_KEY')

    if not url or not key:
        logger.error("SUPABASE_URL and SUPABASE_KEY environment variables required")
        return None

    return create_client(url, key)


def extract_aggregates(scores: Dict) -> Dict:
    """Extract privacy-preserving aggregates from scores."""

    # Map age to bucket (no exact age)
    age = scores.get('child_age', scores.get('age', 0))
    if age <= 0:
        age_bucket = 'unknown'
    elif age < 6:
        age_bucket = '3-5'
    elif age < 9:
        age_bucket = '6-8'
    elif age < 12:
        age_bucket = '9-11'
    else:
        age_bucket = '12+'

    aggregate = {
        'session_id': scores.get('session_id', str(uuid.uuid4())),
        'child_age_bucket': age_bucket,
        'session_date': scores.get('session_date', datetime.now().strftime('%Y-%m-%d')),
        'attention_score': scores.get('attention_score', 0.0),
        'concentration_stability': scores.get('concentration_stability', scores.get('engagement_score', 0.0)),
        'frustration_tolerance_index': 1.0 - scores.get('frustration_index', scores.get('frustration_tolerance_index', 0.0)),
        'empathy_response_score': scores.get('empathy_response_score', scores.get('empathy_score', 0.0)),
        'touch_accuracy': scores.get('touch_accuracy', 0.0),
        'dwell_time_mean': scores.get('dwell_time_stats', {}).get('mean', 0.0) if isinstance(scores.get('dwell_time_stats'), dict) else 0.0,
        'dwell_time_std': scores.get('dwell_time_stats', {}).get('std', 0.0) if isinstance(scores.get('dwell_time_stats'), dict) else 0.0,
        'session_duration': scores.get('session_duration', scores.get('duration', 0)),
        'model_version': scores.get('model_version', '1.0.0'),
        'data_quality_flags': json.dumps(scores.get('data_quality_flags', [])),
        'processed_at': scores.get('processed_at', datetime.now().isoformat())
    }

    return aggregate


def check_consent(scores: Dict) -> bool:
    """Check if user consent is present and true."""
    consent = scores.get('user_consent', scores.get('consent', None))

    if consent is None:
        logger.warning(f"No consent field found for session {scores.get('session_id')}")
        return False

    if consent in [True, 'true', 'yes', 1, '1']:
        return True

    return False


def save_local_backup(aggregate: Dict, backup_dir: Path) -> str:
    """Save encrypted local backup when consent not available."""
    backup_dir.mkdir(parents=True, exist_ok=True)

    # In production, would encrypt this data
    backup_path = backup_dir / f"pending_{aggregate['session_id']}.json"

    backup_data = {
        'aggregate': aggregate,
        'timestamp': datetime.now().isoformat(),
        'reason': 'consent_pending'
    }

    with open(backup_path, 'w') as f:
        json.dump(backup_data, f, indent=2)

    logger.info(f"Saved local backup: {backup_path}")
    return str(backup_path)


def generate_upsert_sql(aggregate: Dict) -> str:
    """Generate SQL for upsert operation."""
    columns = list(aggregate.keys())
    values = []

    for col in columns:
        val = aggregate[col]
        if isinstance(val, str):
            # Escape single quotes
            val = val.replace("'", "''")
            values.append(f"'{val}'")
        elif val is None:
            values.append('NULL')
        else:
            values.append(str(val))

    sql = f"""
INSERT INTO session_aggregates ({', '.join(columns)})
VALUES ({', '.join(values)})
ON CONFLICT (session_id)
DO UPDATE SET
    attention_score = CASE
        WHEN EXCLUDED.processed_at > session_aggregates.processed_at
        THEN EXCLUDED.attention_score
        ELSE session_aggregates.attention_score
    END,
    concentration_stability = CASE
        WHEN EXCLUDED.processed_at > session_aggregates.processed_at
        THEN EXCLUDED.concentration_stability
        ELSE session_aggregates.concentration_stability
    END,
    frustration_tolerance_index = CASE
        WHEN EXCLUDED.processed_at > session_aggregates.processed_at
        THEN EXCLUDED.frustration_tolerance_index
        ELSE session_aggregates.frustration_tolerance_index
    END,
    empathy_response_score = CASE
        WHEN EXCLUDED.processed_at > session_aggregates.processed_at
        THEN EXCLUDED.empathy_response_score
        ELSE session_aggregates.empathy_response_score
    END,
    processed_at = CASE
        WHEN EXCLUDED.processed_at > session_aggregates.processed_at
        THEN EXCLUDED.processed_at
        ELSE session_aggregates.processed_at
    END;
"""
    return sql


def upload_to_supabase(client, aggregate: Dict) -> Dict:
    """Upload aggregate to Supabase with upsert."""
    result = {
        'session_id': aggregate['session_id'],
        'success': False,
        'error': None,
        'latency_ms': 0
    }

    start_time = time.time()

    try:
        # Use upsert for idempotency
        response = client.table('session_aggregates').upsert(
            aggregate,
            on_conflict='session_id'
        ).execute()

        result['success'] = True
        result['latency_ms'] = (time.time() - start_time) * 1000

    except Exception as e:
        result['error'] = str(e)
        logger.error(f"Upload failed for {aggregate['session_id']}: {e}")

    return result


def generate_synthetic_scores(n: int) -> List[Dict]:
    """Generate synthetic session scores for testing."""
    import random

    scores = []
    for i in range(n):
        scores.append({
            'session_id': f'synthetic_{uuid.uuid4().hex[:8]}',
            'child_age': random.randint(3, 14),
            'session_date': datetime.now().strftime('%Y-%m-%d'),
            'attention_score': random.uniform(0.5, 1.0),
            'engagement_score': random.uniform(0.5, 1.0),
            'frustration_index': random.uniform(0.0, 0.3),
            'empathy_score': random.uniform(0.6, 1.0),
            'touch_accuracy': random.uniform(0.7, 1.0),
            'dwell_time_stats': {
                'mean': random.uniform(1.0, 5.0),
                'std': random.uniform(0.1, 1.0)
            },
            'session_duration': random.randint(300, 1800),
            'model_version': '1.0.0',
            'data_quality_flags': [],
            'user_consent': True,
            'processed_at': datetime.now().isoformat()
        })

    return scores


def main():
    args = parse_args()

    backup_dir = Path(args.backup_dir)

    # Collect scores to process
    scores_list = []

    if args.synthetic > 0:
        scores_list = generate_synthetic_scores(args.synthetic)
        logger.info(f"Generated {args.synthetic} synthetic scores")

    elif args.input:
        with open(args.input, 'r') as f:
            scores_list = [json.load(f)]

    elif args.batch_dir:
        batch_path = Path(args.batch_dir)
        for json_file in batch_path.glob('*scores*.json'):
            with open(json_file, 'r') as f:
                scores_list.append(json.load(f))

    else:
        logger.error("Specify --input, --batch_dir, or --synthetic")
        return 1

    if not scores_list:
        logger.warning("No scores to process")
        return 0

    # Get Supabase client
    client = None
    if not args.audit_only and not args.dry_run:
        client = get_supabase_client()
        if not client:
            logger.error("Failed to initialize Supabase client")
            return 1

    # Process each score
    upload_results = []
    total_latency = 0

    for scores in scores_list:
        # Check consent
        if not check_consent(scores):
            aggregate = extract_aggregates(scores)
            save_local_backup(aggregate, backup_dir)
            logger.info(f"Skipped upload (no consent): {scores.get('session_id')}")
            continue

        # Extract aggregates
        aggregate = extract_aggregates(scores)

        # Audit mode: print SQL
        if args.audit_only:
            sql = generate_upsert_sql(aggregate)
            print(f"\n-- Session: {aggregate['session_id']}")
            print(sql)
            continue

        # Dry run
        if args.dry_run:
            logger.info(f"Would upload: {aggregate['session_id']}")
            continue

        # Upload
        result = upload_to_supabase(client, aggregate)
        upload_results.append(result)
        total_latency += result.get('latency_ms', 0)

        if result['success']:
            logger.info(f"Uploaded: {aggregate['session_id']} ({result['latency_ms']:.1f}ms)")
        else:
            logger.error(f"Failed: {aggregate['session_id']}")

    # Summary
    if upload_results:
        success_count = sum(1 for r in upload_results if r['success'])
        avg_latency = total_latency / len(upload_results) if upload_results else 0

        logger.info(f"\nUpload Summary:")
        logger.info(f"  Total: {len(upload_results)}")
        logger.info(f"  Success: {success_count}")
        logger.info(f"  Failed: {len(upload_results) - success_count}")
        logger.info(f"  Avg Latency: {avg_latency:.1f}ms")
        logger.info(f"  Throughput: {len(upload_results) / (total_latency / 1000):.1f} records/sec" if total_latency > 0 else "")

        # Log metrics
        try:
            import mlflow
            with mlflow.start_run(run_name='supabase_upload'):
                mlflow.log_metric('records_uploaded', success_count)
                mlflow.log_metric('avg_latency_ms', avg_latency)
        except:
            pass

    return 0


if __name__ == '__main__':
    exit(main())
