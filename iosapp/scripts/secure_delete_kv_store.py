#!/usr/bin/env python3
"""
secure_delete_kv_store.py — Ensure ephemeral storage doesn't retain sensitive data.
Securely delete Redis keys and rotate encryption keys.
"""

import argparse
import json
import logging
import os
import secrets
import time
from pathlib import Path
from datetime import datetime
from typing import List, Dict

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description='Securely delete KV store sensitive data')
    parser.add_argument('--redis_host', type=str, default=os.getenv('REDIS_HOST', 'localhost'))
    parser.add_argument('--redis_port', type=int, default=int(os.getenv('REDIS_PORT', 6379)))
    parser.add_argument('--redis_db', type=int, default=int(os.getenv('REDIS_DB', 0)))
    parser.add_argument('--redis_password', type=str, default=os.getenv('REDIS_PASSWORD', None))
    parser.add_argument('--pattern', type=str, default='session:*:raw',
                        help='Key pattern to delete')
    parser.add_argument('--rotate_keys', action='store_true',
                        help='Rotate encryption keys')
    parser.add_argument('--key_file', type=str, default='./keys/cache_encryption.key',
                        help='Local key file path')
    parser.add_argument('--kms_key_id', type=str, help='AWS KMS key ID for rotation')
    parser.add_argument('--simulate', action='store_true',
                        help='Simulate without actual deletion')
    parser.add_argument('--report_dir', type=str, default='./deletion_reports')
    return parser.parse_args()


def get_redis_client(args):
    """Get Redis client connection."""
    try:
        import redis
    except ImportError:
        logger.error("redis-py not installed. Run: pip install redis")
        return None

    try:
        client = redis.Redis(
            host=args.redis_host,
            port=args.redis_port,
            db=args.redis_db,
            password=args.redis_password,
            decode_responses=False  # Need bytes for secure overwrite
        )
        client.ping()
        logger.info(f"Connected to Redis: {args.redis_host}:{args.redis_port}")
        return client
    except Exception as e:
        logger.error(f"Failed to connect to Redis: {e}")
        return None


def find_sensitive_keys(client, pattern: str) -> List[bytes]:
    """Find keys matching pattern."""
    keys = []

    # Use SCAN for production safety
    cursor = 0
    while True:
        cursor, batch = client.scan(cursor, match=pattern, count=1000)
        keys.extend(batch)
        if cursor == 0:
            break

    return keys


def secure_delete_key(client, key: bytes, simulate: bool = False) -> Dict:
    """Securely delete a Redis key with overwrite."""
    result = {
        'key': key.decode() if isinstance(key, bytes) else key,
        'success': False,
        'method': 'unknown',
        'original_size': 0
    }

    try:
        # Get original value size
        key_type = client.type(key)

        if key_type == b'string':
            original = client.get(key)
            result['original_size'] = len(original) if original else 0

            if simulate:
                result['method'] = 'simulated'
                result['success'] = True
                return result

            # Overwrite with random data
            random_data = secrets.token_bytes(result['original_size'])
            client.set(key, random_data)

            # Delete
            client.delete(key)
            result['method'] = 'overwrite_delete'
            result['success'] = True

        elif key_type in [b'list', b'set', b'zset', b'hash']:
            # For complex types, just delete (can't easily overwrite)
            if simulate:
                result['method'] = 'simulated'
                result['success'] = True
                return result

            client.delete(key)
            result['method'] = 'delete_only'
            result['success'] = True

        else:
            result['method'] = 'unknown_type'
            result['success'] = False

    except Exception as e:
        result['error'] = str(e)
        logger.error(f"Failed to delete key {key}: {e}")

    return result


def verify_deletion(client, keys: List[bytes]) -> List[Dict]:
    """Verify keys were actually deleted."""
    verification = []

    for key in keys:
        exists = client.exists(key)
        verification.append({
            'key': key.decode() if isinstance(key, bytes) else key,
            'still_exists': bool(exists)
        })

        if exists:
            logger.warning(f"Key still exists after deletion: {key}")

    return verification


def rotate_local_key(key_file: str) -> Dict:
    """Rotate local encryption key."""
    key_path = Path(key_file)
    result = {
        'path': str(key_path),
        'success': False,
        'method': 'local_file'
    }

    try:
        # Backup old key
        if key_path.exists():
            backup_path = key_path.with_suffix(f'.{datetime.now().strftime("%Y%m%d%H%M%S")}.bak')
            key_path.rename(backup_path)
            result['backup'] = str(backup_path)

        # Generate new key
        key_path.parent.mkdir(parents=True, exist_ok=True)
        new_key = secrets.token_bytes(32)  # 256-bit key

        with open(key_path, 'wb') as f:
            f.write(new_key)

        # Restrict permissions
        os.chmod(key_path, 0o600)

        result['success'] = True
        logger.info(f"Rotated local key: {key_path}")

    except Exception as e:
        result['error'] = str(e)
        logger.error(f"Failed to rotate local key: {e}")

    return result


def rotate_kms_key(key_id: str) -> Dict:
    """Rotate AWS KMS key."""
    result = {
        'key_id': key_id,
        'success': False,
        'method': 'aws_kms'
    }

    try:
        import boto3
        kms = boto3.client('kms')

        # Enable automatic key rotation
        kms.enable_key_rotation(KeyId=key_id)

        # Create new data key
        response = kms.generate_data_key(
            KeyId=key_id,
            KeySpec='AES_256'
        )

        result['success'] = True
        result['new_key_id'] = response.get('KeyId')
        logger.info(f"Rotated KMS key: {key_id}")

    except Exception as e:
        result['error'] = str(e)
        logger.error(f"Failed to rotate KMS key: {e}")

    return result


def generate_report(deletion_results: List[Dict], verification: List[Dict],
                    key_rotation: Dict, report_dir: Path) -> str:
    """Generate deletion report."""
    report_dir.mkdir(parents=True, exist_ok=True)

    report = {
        'timestamp': datetime.now().isoformat(),
        'summary': {
            'keys_processed': len(deletion_results),
            'successful_deletions': sum(1 for r in deletion_results if r.get('success')),
            'failed_deletions': sum(1 for r in deletion_results if not r.get('success')),
            'verification_failures': sum(1 for v in verification if v.get('still_exists')),
            'key_rotation': key_rotation
        },
        'deletion_results': deletion_results,
        'verification': verification
    }

    report_path = report_dir / f"kv_deletion_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"

    with open(report_path, 'w') as f:
        json.dump(report, f, indent=2)

    logger.info(f"Report saved: {report_path}")
    return str(report_path)


def main():
    args = parse_args()

    report_dir = Path(args.report_dir)

    # Connect to Redis
    client = get_redis_client(args)

    deletion_results = []
    verification = []
    key_rotation = {}

    if client:
        # Find sensitive keys
        keys = find_sensitive_keys(client, args.pattern)
        logger.info(f"Found {len(keys)} keys matching pattern: {args.pattern}")

        if args.simulate:
            logger.info("SIMULATION MODE - No actual deletions")

        # Delete each key
        for key in keys:
            result = secure_delete_key(client, key, args.simulate)
            deletion_results.append(result)

            if result['success']:
                logger.info(f"Deleted: {result['key']} ({result['method']})")
            else:
                logger.error(f"Failed: {result['key']}")

        # Verify deletions
        if not args.simulate:
            verification = verify_deletion(client, keys)

    # Rotate encryption keys
    if args.rotate_keys:
        if args.kms_key_id:
            key_rotation = rotate_kms_key(args.kms_key_id)
        else:
            key_rotation = rotate_local_key(args.key_file)

    # Generate report
    report_path = generate_report(deletion_results, verification, key_rotation, report_dir)

    # Summary
    success = sum(1 for r in deletion_results if r.get('success'))
    logger.info(f"\nDeletion Summary:")
    logger.info(f"  Keys processed: {len(deletion_results)}")
    logger.info(f"  Successful: {success}")
    logger.info(f"  Failed: {len(deletion_results) - success}")

    if verification:
        still_exists = sum(1 for v in verification if v.get('still_exists'))
        if still_exists:
            logger.warning(f"  Verification failures: {still_exists}")

    # Log to MLflow
    try:
        import mlflow
        with mlflow.start_run(run_name='kv_secure_delete'):
            mlflow.log_metric('keys_deleted', success)
            mlflow.log_metric('keys_failed', len(deletion_results) - success)
    except:
        pass

    return 0


if __name__ == '__main__':
    exit(main())
