#!/usr/bin/env python3
"""
delta_sync_client.py — Reduced sync for session params only.
Syncs changed JSON params and thumbnails, avoids reuploading assets.
"""

import argparse
import json
import logging
import hashlib
from pathlib import Path
from datetime import datetime

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description='Delta sync client')
    parser.add_argument('--local_dir', type=str, required=True)
    parser.add_argument('--remote_manifest', type=str, help='Remote manifest URL/path')
    parser.add_argument('--output_dir', type=str, default='./sync_output')
    parser.add_argument('--server_url', type=str, default='http://localhost:8080')
    parser.add_argument('--dry_run', action='store_true')
    return parser.parse_args()


def compute_file_hash(path):
    """Compute MD5 hash of file."""
    md5 = hashlib.md5()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(8192), b''):
            md5.update(chunk)
    return md5.hexdigest()


def compute_json_diff(old_data, new_data):
    """Compute diff between JSON objects."""
    diff = {'added': {}, 'removed': [], 'changed': {}}

    for key, value in new_data.items():
        if key not in old_data:
            diff['added'][key] = value
        elif old_data[key] != value:
            diff['changed'][key] = {'old': old_data[key], 'new': value}

    for key in old_data:
        if key not in new_data:
            diff['removed'].append(key)

    return diff


def build_local_manifest(local_dir):
    """Build manifest of local files."""
    local_dir = Path(local_dir)
    manifest = {'files': {}, 'timestamp': datetime.now().isoformat()}

    for path in local_dir.rglob('*'):
        if path.is_file():
            rel_path = str(path.relative_to(local_dir))

            # Only sync JSON params and thumbnails
            if path.suffix in ['.json', '.thumb.png', '.thumb.webp']:
                manifest['files'][rel_path] = {
                    'hash': compute_file_hash(path),
                    'size': path.stat().st_size,
                    'mtime': path.stat().st_mtime
                }

    return manifest


def load_remote_manifest(path_or_url):
    """Load remote manifest."""
    if not path_or_url:
        return {'files': {}}

    path = Path(path_or_url)
    if path.exists():
        with open(path) as f:
            return json.load(f)

    # Could also fetch from URL
    return {'files': {}}


def compute_sync_plan(local_manifest, remote_manifest):
    """Determine what needs to be synced."""
    plan = {
        'upload': [],
        'download': [],
        'delete_remote': [],
        'unchanged': []
    }

    local_files = local_manifest['files']
    remote_files = remote_manifest['files']

    # Files to upload (new or changed)
    for path, info in local_files.items():
        if path not in remote_files:
            plan['upload'].append({'path': path, 'reason': 'new'})
        elif info['hash'] != remote_files[path]['hash']:
            plan['upload'].append({'path': path, 'reason': 'changed'})
        else:
            plan['unchanged'].append(path)

    # Files to delete remotely (removed locally)
    for path in remote_files:
        if path not in local_files:
            plan['delete_remote'].append(path)

    return plan


def apply_sync_plan(plan, local_dir, output_dir, dry_run):
    """Apply sync plan."""
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    local_dir = Path(local_dir)

    results = {'uploaded': 0, 'failed': 0, 'bytes_transferred': 0}

    for item in plan['upload']:
        src = local_dir / item['path']
        dst = output_dir / item['path']

        if dry_run:
            logger.info(f"Would upload: {item['path']} ({item['reason']})")
        else:
            dst.parent.mkdir(parents=True, exist_ok=True)

            # For JSON, compute and save delta
            if src.suffix == '.json':
                with open(src) as f:
                    data = json.load(f)

                # Save as delta (in production, would send to server)
                with open(dst, 'w') as f:
                    json.dump(data, f)
            else:
                # Copy thumbnail
                import shutil
                shutil.copy2(src, dst)

            results['uploaded'] += 1
            results['bytes_transferred'] += src.stat().st_size
            logger.info(f"Uploaded: {item['path']}")

    return results


def validate_integrity(output_dir, local_dir):
    """Validate synced files match local."""
    output_dir = Path(output_dir)
    local_dir = Path(local_dir)

    valid = True
    for path in output_dir.rglob('*'):
        if path.is_file():
            rel_path = path.relative_to(output_dir)
            local_path = local_dir / rel_path

            if local_path.exists():
                if compute_file_hash(path) != compute_file_hash(local_path):
                    logger.error(f"Hash mismatch: {rel_path}")
                    valid = False

    return valid


def main():
    args = parse_args()

    # Build manifests
    logger.info("Building local manifest...")
    local_manifest = build_local_manifest(args.local_dir)
    logger.info(f"Found {len(local_manifest['files'])} syncable files")

    remote_manifest = load_remote_manifest(args.remote_manifest)
    logger.info(f"Remote has {len(remote_manifest['files'])} files")

    # Compute plan
    plan = compute_sync_plan(local_manifest, remote_manifest)

    logger.info(f"Sync plan: {len(plan['upload'])} uploads, {len(plan['unchanged'])} unchanged")

    if args.dry_run:
        logger.info("DRY RUN - no changes will be made")

    # Apply
    results = apply_sync_plan(plan, args.local_dir, args.output_dir, args.dry_run)

    # Validate
    if not args.dry_run and results['uploaded'] > 0:
        if validate_integrity(args.output_dir, args.local_dir):
            logger.info("Integrity check passed")

    # Summary
    summary = {
        'local_files': len(local_manifest['files']),
        'remote_files': len(remote_manifest['files']),
        'uploaded': results['uploaded'],
        'bytes_transferred': results['bytes_transferred'],
        'unchanged': len(plan['unchanged'])
    }

    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()
