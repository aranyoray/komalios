#!/usr/bin/env python3
"""
safe_retention_policy_enforcer.py — Enforce data retention policies across storage.
Deletes or archives files according to configurable retention rules.
"""

import argparse
import json
import logging
import os
import subprocess
import yaml
from pathlib import Path
from datetime import datetime, timedelta
from typing import Dict, List, Optional
from concurrent.futures import ThreadPoolExecutor, as_completed

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description='Enforce data retention policies')
    parser.add_argument('--config', type=str, default='./config/retention.yaml',
                        help='Retention policy config file')
    parser.add_argument('--storage_type', type=str, choices=['local', 's3'], default='local',
                        help='Storage type')
    parser.add_argument('--bucket', type=str, help='S3 bucket name')
    parser.add_argument('--storage_path', type=str, default='./data', help='Local storage path')
    parser.add_argument('--dry_run', action='store_true', help='Preview without deleting')
    parser.add_argument('--force', action='store_true', help='Force deletion without confirmation')
    parser.add_argument('--max_parallel', type=int, default=4, help='Max parallel deletions')
    parser.add_argument('--whitelist', type=str, help='JSON file with whitelisted session IDs')
    parser.add_argument('--report_dir', type=str, default='./retention_reports', help='Report directory')
    return parser.parse_args()


def load_retention_config(config_path: Path) -> Dict:
    """Load retention policy configuration."""
    default_config = {
        'policies': {
            'raw_recordings': {
                'patterns': ['*.mp4', '*.avi', '*.mov', '*.wav', '*.mp3'],
                'retention_days': 0,  # Delete after analytics success
                'secure_delete': True
            },
            'processed_analytics': {
                'patterns': ['*_scores.json', '*_report.pdf'],
                'retention_days': 365,
                'secure_delete': False
            },
            'anonymized_aggregates': {
                'patterns': ['*_aggregate.json'],
                'retention_days': 1825,  # 5 years
                'secure_delete': False
            },
            'temp_files': {
                'patterns': ['*.tmp', '*.cache'],
                'retention_days': 1,
                'secure_delete': False
            }
        }
    }

    if config_path.exists():
        with open(config_path, 'r') as f:
            return yaml.safe_load(f)

    # Create default config
    config_path.parent.mkdir(parents=True, exist_ok=True)
    with open(config_path, 'w') as f:
        yaml.dump(default_config, f, default_flow_style=False)

    logger.info(f"Created default config: {config_path}")
    return default_config


def load_whitelist(whitelist_path: Optional[str]) -> set:
    """Load whitelisted session IDs."""
    if not whitelist_path:
        return set()

    path = Path(whitelist_path)
    if not path.exists():
        return set()

    with open(path, 'r') as f:
        data = json.load(f)

    return set(data.get('session_ids', []))


def find_files_by_policy(storage_path: Path, policy: Dict) -> List[Path]:
    """Find files matching policy patterns."""
    files = []

    for pattern in policy.get('patterns', []):
        files.extend(storage_path.rglob(pattern))

    return files


def is_expired(filepath: Path, retention_days: int) -> bool:
    """Check if file has exceeded retention period."""
    if retention_days == 0:
        return True  # Immediate deletion

    mtime = datetime.fromtimestamp(filepath.stat().st_mtime)
    expiry = mtime + timedelta(days=retention_days)

    return datetime.now() > expiry


def secure_delete_file(filepath: Path) -> bool:
    """Securely delete file using audit_and_autodelete_pipeline."""
    try:
        # Call the secure delete pipeline
        result = subprocess.run([
            'python', 'scripts/audit_and_autodelete_pipeline.py',
            '--session_dir', str(filepath.parent),
            '--accept_real_data',
            '--force_delete'
        ], capture_output=True, text=True, timeout=120)

        return result.returncode == 0
    except Exception as e:
        logger.error(f"Secure delete failed for {filepath}: {e}")
        return False


def delete_file_local(filepath: Path, secure: bool = False) -> Dict:
    """Delete file from local storage."""
    result = {
        'path': str(filepath),
        'success': False,
        'method': 'unknown',
        'size_bytes': 0
    }

    try:
        result['size_bytes'] = filepath.stat().st_size

        if secure:
            # Use secure deletion
            if secure_delete_file(filepath):
                result['success'] = True
                result['method'] = 'secure_delete'
        else:
            # Standard deletion
            filepath.unlink()
            result['success'] = True
            result['method'] = 'unlink'

    except Exception as e:
        result['error'] = str(e)
        logger.error(f"Delete failed: {filepath}: {e}")

    return result


def delete_file_s3(bucket: str, key: str) -> Dict:
    """Delete file from S3."""
    result = {
        'path': f"s3://{bucket}/{key}",
        'success': False,
        'method': 's3_delete'
    }

    try:
        import boto3
        s3 = boto3.client('s3')
        s3.delete_object(Bucket=bucket, Key=key)
        result['success'] = True
    except Exception as e:
        result['error'] = str(e)
        logger.error(f"S3 delete failed: {key}: {e}")

    return result


def enforce_retention(args, config: Dict, whitelist: set) -> List[Dict]:
    """Enforce retention policies and return results."""
    results = []
    policies = config.get('policies', {})

    storage_path = Path(args.storage_path)

    for policy_name, policy in policies.items():
        logger.info(f"Processing policy: {policy_name}")

        # Find matching files
        if args.storage_type == 'local':
            files = find_files_by_policy(storage_path, policy)
        else:
            # S3 listing would go here
            files = []

        retention_days = policy.get('retention_days', 365)
        secure = policy.get('secure_delete', False)

        # Filter expired files
        expired_files = []
        for filepath in files:
            # Check whitelist
            session_id = filepath.parent.name
            if session_id in whitelist:
                logger.info(f"Skipped (whitelisted): {filepath}")
                continue

            if is_expired(filepath, retention_days):
                expired_files.append(filepath)

        logger.info(f"  Found {len(expired_files)} expired files")

        if args.dry_run:
            for filepath in expired_files:
                results.append({
                    'path': str(filepath),
                    'policy': policy_name,
                    'action': 'would_delete',
                    'secure': secure
                })
            continue

        # Delete files in parallel
        with ThreadPoolExecutor(max_workers=args.max_parallel) as executor:
            futures = {}

            for filepath in expired_files:
                if args.storage_type == 'local':
                    future = executor.submit(delete_file_local, filepath, secure)
                else:
                    key = str(filepath.relative_to(storage_path))
                    future = executor.submit(delete_file_s3, args.bucket, key)

                futures[future] = filepath

            for future in as_completed(futures):
                result = future.result()
                result['policy'] = policy_name
                results.append(result)

    return results


def generate_report(results: List[Dict], report_dir: Path) -> str:
    """Generate retention enforcement report."""
    report_dir.mkdir(parents=True, exist_ok=True)

    # CSV report
    csv_path = report_dir / f"retention_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"

    import csv
    with open(csv_path, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=['path', 'policy', 'success', 'method', 'size_bytes', 'error'])
        writer.writeheader()
        for result in results:
            writer.writerow({
                'path': result.get('path', ''),
                'policy': result.get('policy', ''),
                'success': result.get('success', result.get('action', '')),
                'method': result.get('method', ''),
                'size_bytes': result.get('size_bytes', 0),
                'error': result.get('error', '')
            })

    # Summary
    total = len(results)
    success = sum(1 for r in results if r.get('success', False))
    total_size = sum(r.get('size_bytes', 0) for r in results)

    summary = {
        'timestamp': datetime.now().isoformat(),
        'total_files': total,
        'deleted': success,
        'failed': total - success,
        'total_size_mb': total_size / (1024 * 1024),
        'report_path': str(csv_path)
    }

    # Log to MLflow
    try:
        import mlflow
        with mlflow.start_run(run_name='retention_enforcement'):
            mlflow.log_metric('files_deleted', success)
            mlflow.log_metric('files_failed', total - success)
            mlflow.log_metric('size_deleted_mb', summary['total_size_mb'])
            mlflow.log_artifact(str(csv_path))
    except:
        pass

    logger.info(f"Report saved: {csv_path}")
    return str(csv_path)


def main():
    args = parse_args()

    config_path = Path(args.config)
    report_dir = Path(args.report_dir)

    # Load configuration
    config = load_retention_config(config_path)
    whitelist = load_whitelist(args.whitelist)

    logger.info(f"Storage type: {args.storage_type}")
    logger.info(f"Whitelist: {len(whitelist)} sessions")

    if args.dry_run:
        logger.info("DRY RUN MODE - No files will be deleted")

    # Enforce retention
    results = enforce_retention(args, config, whitelist)

    # Generate report
    if results:
        report_path = generate_report(results, report_dir)

        # Summary
        success = sum(1 for r in results if r.get('success', False) or r.get('action') == 'would_delete')
        total_size = sum(r.get('size_bytes', 0) for r in results)

        logger.info(f"\nRetention Enforcement Summary:")
        logger.info(f"  Files processed: {len(results)}")
        logger.info(f"  Successfully deleted: {success}")
        logger.info(f"  Total size freed: {total_size / (1024 * 1024):.2f} MB")
        logger.info(f"  Report: {report_path}")

    return 0


if __name__ == '__main__':
    exit(main())
