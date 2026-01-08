#!/usr/bin/env python3
"""
delta_ota_patcher.py — Minimal differential OTA updates for models/assets.
Computes binary diffs, serves patches via HTTP, verifies SHA256, atomic swap with rollback.
"""

import argparse
import hashlib
import json
import logging
import os
import shutil
import subprocess
import tempfile
from pathlib import Path
from datetime import datetime
from http.server import HTTPServer, SimpleHTTPRequestHandler
import threading

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description='Delta OTA patcher for models/assets')
    parser.add_argument('--create_patch', action='store_true', help='Create delta patch')
    parser.add_argument('--apply_patch', action='store_true', help='Apply delta patch')
    parser.add_argument('--old_file', type=str, help='Old version file')
    parser.add_argument('--new_file', type=str, help='New version file')
    parser.add_argument('--patch_file', type=str, help='Patch file path')
    parser.add_argument('--target_file', type=str, help='Target file to update')
    parser.add_argument('--serve', action='store_true', help='Serve patches via HTTP')
    parser.add_argument('--port', type=int, default=8080)
    parser.add_argument('--patch_dir', type=str, default='./patches')
    parser.add_argument('--backup_dir', type=str, default='./rollback')
    return parser.parse_args()


def compute_sha256(filepath):
    sha256 = hashlib.sha256()
    with open(filepath, 'rb') as f:
        for chunk in iter(lambda: f.read(8192), b''):
            sha256.update(chunk)
    return sha256.hexdigest()


def create_bsdiff_patch(old_file, new_file, patch_file):
    """Create binary diff using bsdiff."""
    try:
        subprocess.run(['bsdiff', old_file, new_file, patch_file], check=True, capture_output=True)
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        logger.warning("bsdiff not available, falling back to xdelta")
        try:
            subprocess.run(['xdelta3', '-e', '-s', old_file, new_file, patch_file],
                         check=True, capture_output=True)
            return True
        except (subprocess.CalledProcessError, FileNotFoundError):
            logger.error("Neither bsdiff nor xdelta3 available")
            return False


def apply_bsdiff_patch(old_file, patch_file, new_file):
    """Apply binary diff using bspatch."""
    try:
        subprocess.run(['bspatch', old_file, new_file, patch_file], check=True, capture_output=True)
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        try:
            subprocess.run(['xdelta3', '-d', '-s', old_file, patch_file, new_file],
                         check=True, capture_output=True)
            return True
        except (subprocess.CalledProcessError, FileNotFoundError):
            return False


def create_patch(old_file, new_file, patch_dir):
    """Create delta patch with metadata."""
    patch_dir = Path(patch_dir)
    patch_dir.mkdir(parents=True, exist_ok=True)

    old_hash = compute_sha256(old_file)
    new_hash = compute_sha256(new_file)

    patch_name = f"patch_{old_hash[:8]}_{new_hash[:8]}.delta"
    patch_path = patch_dir / patch_name

    if not create_bsdiff_patch(old_file, new_file, str(patch_path)):
        return None

    old_size = os.path.getsize(old_file)
    new_size = os.path.getsize(new_file)
    patch_size = os.path.getsize(patch_path)

    manifest = {
        'patch_file': patch_name,
        'old_hash': old_hash,
        'new_hash': new_hash,
        'old_size': old_size,
        'new_size': new_size,
        'patch_size': patch_size,
        'savings_percent': round((1 - patch_size / new_size) * 100, 2),
        'created_at': datetime.now().isoformat()
    }

    manifest_path = patch_dir / f"{patch_name}.manifest.json"
    with open(manifest_path, 'w') as f:
        json.dump(manifest, f, indent=2)

    logger.info(f"Created patch: {patch_path}")
    logger.info(f"Savings: {manifest['savings_percent']}% ({patch_size} vs {new_size} bytes)")

    return manifest


def apply_patch(patch_file, target_file, backup_dir, expected_hash=None):
    """Apply patch with atomic swap and rollback support."""
    backup_dir = Path(backup_dir)
    backup_dir.mkdir(parents=True, exist_ok=True)

    target_path = Path(target_file)

    # Create backup for rollback
    backup_path = backup_dir / f"{target_path.name}.{datetime.now().strftime('%Y%m%d%H%M%S')}.bak"
    shutil.copy2(target_file, backup_path)
    logger.info(f"Created backup: {backup_path}")

    # Apply patch to temp file
    with tempfile.NamedTemporaryFile(delete=False) as tmp:
        tmp_path = tmp.name

    try:
        if not apply_bsdiff_patch(target_file, patch_file, tmp_path):
            raise RuntimeError("Failed to apply patch")

        # Verify hash if provided
        if expected_hash:
            actual_hash = compute_sha256(tmp_path)
            if actual_hash != expected_hash:
                raise RuntimeError(f"Hash mismatch: {actual_hash} != {expected_hash}")

        # Atomic swap
        os.replace(tmp_path, target_file)
        logger.info(f"Successfully updated: {target_file}")

        return True

    except Exception as e:
        logger.error(f"Patch failed: {e}")
        # Rollback
        shutil.copy2(backup_path, target_file)
        logger.info("Rolled back to previous version")
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)
        return False


def rollback(target_file, backup_dir):
    """Rollback to most recent backup."""
    backup_dir = Path(backup_dir)
    target_name = Path(target_file).name

    backups = sorted(backup_dir.glob(f"{target_name}.*.bak"), reverse=True)
    if not backups:
        logger.error("No backups found")
        return False

    latest_backup = backups[0]
    shutil.copy2(latest_backup, target_file)
    logger.info(f"Rolled back to: {latest_backup}")
    return True


class PatchHTTPHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, directory=None, **kwargs):
        super().__init__(*args, directory=directory, **kwargs)


def serve_patches(patch_dir, port):
    """Serve patches via HTTP."""
    handler = lambda *args: PatchHTTPHandler(*args, directory=patch_dir)
    server = HTTPServer(('0.0.0.0', port), handler)
    logger.info(f"Serving patches on http://0.0.0.0:{port}")
    server.serve_forever()


def main():
    args = parse_args()

    if args.create_patch:
        if not args.old_file or not args.new_file:
            logger.error("--old_file and --new_file required for --create_patch")
            return 1
        create_patch(args.old_file, args.new_file, args.patch_dir)

    elif args.apply_patch:
        if not args.patch_file or not args.target_file:
            logger.error("--patch_file and --target_file required for --apply_patch")
            return 1
        apply_patch(args.patch_file, args.target_file, args.backup_dir)

    elif args.serve:
        serve_patches(args.patch_dir, args.port)

    else:
        logger.error("Specify --create_patch, --apply_patch, or --serve")
        return 1

    return 0


if __name__ == '__main__':
    exit(main())
