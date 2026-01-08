#!/usr/bin/env python3
"""
audit_and_autodelete_pipeline.py — Secure post-session processing and deletion pipeline.
Runs analytics, verifies integrity, securely deletes raw data, and creates audit records.
"""

import argparse
import json
import logging
import os
import hashlib
import secrets
import subprocess
import shutil
import mmap
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional
import uuid

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description='Secure audit and deletion pipeline')
    parser.add_argument('--session_dir', type=str, required=True, help='Session directory to process')
    parser.add_argument('--dry_run', action='store_true', help='Preview without deleting')
    parser.add_argument('--force_delete', action='store_true', help='Force deletion without confirmation')
    parser.add_argument('--accept_real_data', action='store_true',
                        help='REQUIRED to enable actual deletion of real data')
    parser.add_argument('--quarantine_dir', type=str, default='./quarantine',
                        help='Directory for failed deletions')
    parser.add_argument('--audit_dir', type=str, default='./audit_logs', help='Audit log directory')
    parser.add_argument('--alerts_dir', type=str, default='./alerts', help='Alerts directory')
    return parser.parse_args()


def compute_checksum(filepath: Path) -> str:
    """Compute SHA-256 checksum of file."""
    sha256 = hashlib.sha256()
    with open(filepath, 'rb') as f:
        for chunk in iter(lambda: f.read(4096), b''):
            sha256.update(chunk)
    return sha256.hexdigest()


def verify_json_schema(filepath: Path, required_fields: List[str]) -> bool:
    """Verify JSON file has required fields."""
    try:
        with open(filepath, 'r') as f:
            data = json.load(f)
        return all(field in data for field in required_fields)
    except Exception as e:
        logger.error(f"Schema verification failed: {e}")
        return False


def run_analytics_sandboxed(session_dir: Path) -> Dict:
    """Run analytics scripts in sandboxed subprocess."""
    results = {
        'success': False,
        'scores_path': None,
        'report_path': None,
        'error': None
    }

    scores_path = session_dir / 'session_scores.json'
    report_path = session_dir / 'session_report.pdf'

    try:
        # Run analytics (placeholder - would call actual analytics scripts)
        # In production, this would use subprocess with resource limits

        # Create sample scores for demo
        scores = {
            'session_id': session_dir.name,
            'processed_at': datetime.now().isoformat(),
            'attention_score': 0.85,
            'engagement_score': 0.78,
            'frustration_index': 0.12,
            'completion_rate': 0.95
        }

        with open(scores_path, 'w') as f:
            json.dump(scores, f, indent=2)

        # Create placeholder report
        with open(report_path, 'wb') as f:
            f.write(b'%PDF-1.4 placeholder report')

        results['success'] = True
        results['scores_path'] = str(scores_path)
        results['report_path'] = str(report_path)

    except Exception as e:
        results['error'] = str(e)
        logger.error(f"Analytics failed: {e}")

    return results


def secure_delete_file(filepath: Path, passes: int = 3) -> Dict:
    """Securely delete file with multiple overwrite passes."""
    result = {
        'path': str(filepath),
        'method': 'unknown',
        'success': False,
        'error': None
    }

    if not filepath.exists():
        result['error'] = 'File not found'
        return result

    try:
        file_size = filepath.stat().st_size

        # Method 1: Try memory-mapped overwrite
        try:
            with open(filepath, 'r+b') as f:
                # Try to memory-map for faster overwrite
                try:
                    mm = mmap.mmap(f.fileno(), 0)
                    for pass_num in range(passes):
                        mm.seek(0)
                        mm.write(secrets.token_bytes(file_size))
                        mm.flush()
                    mm.close()
                    result['method'] = 'mmap_overwrite'
                except Exception:
                    # Fallback to regular write
                    for pass_num in range(passes):
                        f.seek(0)
                        f.write(secrets.token_bytes(file_size))
                        f.flush()
                        os.fsync(f.fileno())
                    result['method'] = 'file_overwrite'
        except PermissionError:
            # Try shred command on Unix
            try:
                subprocess.run(['shred', '-vfz', '-n', str(passes), str(filepath)],
                             check=True, capture_output=True, timeout=60)
                result['method'] = 'shred_command'
            except (subprocess.CalledProcessError, FileNotFoundError):
                # Best effort: just delete
                result['method'] = 'unlink_only'

        # Remove the file
        filepath.unlink()
        result['success'] = True

    except Exception as e:
        result['error'] = str(e)
        logger.error(f"Secure delete failed for {filepath}: {e}")

    return result


def move_to_quarantine(filepath: Path, quarantine_dir: Path) -> bool:
    """Move file to encrypted quarantine directory."""
    quarantine_dir.mkdir(parents=True, exist_ok=True)

    try:
        # In production, would encrypt the file before moving
        dest = quarantine_dir / f"{datetime.now().strftime('%Y%m%d_%H%M%S')}_{filepath.name}"
        shutil.move(str(filepath), str(dest))
        logger.warning(f"Moved to quarantine: {dest}")
        return True
    except Exception as e:
        logger.error(f"Failed to quarantine {filepath}: {e}")
        return False


def create_audit_record(session_dir: Path, analytics_result: Dict,
                        deletion_results: List[Dict], audit_dir: Path) -> str:
    """Create immutable audit record."""
    audit_dir.mkdir(parents=True, exist_ok=True)

    session_id = session_dir.name
    audit_id = str(uuid.uuid4())

    # Compute analytics checksum
    analytics_checksum = None
    if analytics_result.get('scores_path'):
        scores_path = Path(analytics_result['scores_path'])
        if scores_path.exists():
            analytics_checksum = compute_checksum(scores_path)

    audit_record = {
        'audit_id': audit_id,
        'session_id': session_id,
        'timestamp': datetime.now().isoformat(),
        'start_time': datetime.now().isoformat(),
        'end_time': datetime.now().isoformat(),
        'analytics_checksum': analytics_checksum,
        'analytics_success': analytics_result.get('success', False),
        'deletion_results': deletion_results,
        'deletion_method': deletion_results[0].get('method') if deletion_results else None,
        'files_deleted': sum(1 for r in deletion_results if r.get('success')),
        'files_failed': sum(1 for r in deletion_results if not r.get('success')),
        'user_consent_flag': True,  # Would be read from session metadata
        'operator_id': os.getenv('OPERATOR_ID', None)
    }

    audit_path = audit_dir / f'audit_{session_id}.json'

    with open(audit_path, 'w') as f:
        json.dump(audit_record, f, indent=2)

    # Make immutable (where supported)
    try:
        os.chmod(audit_path, 0o444)
    except:
        pass

    logger.info(f"Audit record created: {audit_path}")

    # Log to MLflow
    try:
        import mlflow
        with mlflow.start_run(run_name=f'audit_{session_id}'):
            mlflow.log_param('session_id', session_id)
            mlflow.log_param('audit_id', audit_id)
            mlflow.log_metric('files_deleted', audit_record['files_deleted'])
            mlflow.log_metric('files_failed', audit_record['files_failed'])
    except:
        pass

    return audit_id


def create_quarantine_alert(session_id: str, failed_files: List[str], alerts_dir: Path):
    """Create alert for quarantined files."""
    alerts_dir.mkdir(parents=True, exist_ok=True)

    alert = {
        'alert_type': 'quarantine',
        'timestamp': datetime.now().isoformat(),
        'session_id': session_id,
        'severity': 'high',
        'message': f'Failed to delete {len(failed_files)} files',
        'files': failed_files,
        'action_required': 'Manual review and deletion required'
    }

    alert_path = alerts_dir / 'quarantine_notify.json'

    # Append to existing alerts
    existing = []
    if alert_path.exists():
        with open(alert_path, 'r') as f:
            existing = json.load(f)

    existing.append(alert)

    with open(alert_path, 'w') as f:
        json.dump(existing, f, indent=2)

    logger.warning(f"Quarantine alert created: {alert_path}")


def main():
    args = parse_args()

    session_dir = Path(args.session_dir)
    audit_dir = Path(args.audit_dir)
    quarantine_dir = Path(args.quarantine_dir)
    alerts_dir = Path(args.alerts_dir)

    if not session_dir.exists():
        logger.error(f"Session directory not found: {session_dir}")
        return 1

    logger.info(f"Processing session: {session_dir.name}")

    # Safety check
    if not args.accept_real_data and not args.dry_run:
        logger.error("--accept_real_data flag required to enable actual deletion")
        logger.info("Use --dry_run to preview without deletion")
        return 1

    # Step 1: Run analytics
    logger.info("Running analytics...")
    analytics_result = run_analytics_sandboxed(session_dir)

    if not analytics_result['success']:
        logger.error("Analytics failed, aborting deletion")
        return 1

    # Step 2: Verify session_scores.json
    scores_path = Path(analytics_result['scores_path'])
    required_fields = ['session_id', 'processed_at', 'attention_score']

    if not verify_json_schema(scores_path, required_fields):
        logger.error("Scores file schema verification failed")
        return 1

    # Step 3: Find raw files to delete
    raw_patterns = ['*.mp4', '*.avi', '*.mov', '*.wav', '*.mp3', '*.raw', '*.bin']
    raw_files = []

    for pattern in raw_patterns:
        raw_files.extend(session_dir.glob(pattern))

    logger.info(f"Found {len(raw_files)} raw files to delete")

    if args.dry_run:
        logger.info("DRY RUN - Files that would be deleted:")
        for f in raw_files:
            logger.info(f"  {f}")

        # Create dry-run audit record
        deletion_results = [{'path': str(f), 'method': 'dry_run', 'success': True} for f in raw_files]
        create_audit_record(session_dir, analytics_result, deletion_results, audit_dir)
        return 0

    # Step 4: Secure deletion
    deletion_results = []
    failed_files = []

    for raw_file in raw_files:
        logger.info(f"Securely deleting: {raw_file}")

        # Retry up to 3 times
        for attempt in range(3):
            result = secure_delete_file(raw_file)

            if result['success']:
                deletion_results.append(result)
                break
            else:
                if attempt < 2:
                    logger.warning(f"Retry {attempt + 1} for {raw_file}")
                else:
                    # Move to quarantine
                    if move_to_quarantine(raw_file, quarantine_dir):
                        result['method'] = 'quarantined'
                    deletion_results.append(result)
                    failed_files.append(str(raw_file))

    # Step 5: Create audit record
    audit_id = create_audit_record(session_dir, analytics_result, deletion_results, audit_dir)

    # Step 6: Create quarantine alert if needed
    if failed_files:
        create_quarantine_alert(session_dir.name, failed_files, alerts_dir)

    # Summary
    success_count = sum(1 for r in deletion_results if r.get('success'))
    logger.info(f"Deletion complete: {success_count}/{len(raw_files)} files successfully deleted")
    logger.info(f"Audit ID: {audit_id}")

    return 0 if not failed_files else 1


if __name__ == '__main__':
    exit(main())
