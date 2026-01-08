#!/usr/bin/env python3
"""
safe_tempfile_handler.py - Securely create and auto-delete temp files

Handles temp files for recordings, model downloads with secure cleanup.
"""

import argparse
import json
import os
import tempfile
import shutil
import atexit
import logging
from pathlib import Path
from typing import Dict, Optional
from datetime import datetime
import threading

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class SafeTempfileHandler:
    """Secure temporary file management."""

    def __init__(self, config: Dict):
        self.config = config
        self.base_dir = Path(config.get('temp_dir', tempfile.gettempdir())) / 'komal_temp'
        self.base_dir.mkdir(parents=True, exist_ok=True)

        self.active_files = {}
        self.lock = threading.Lock()

        # Stats
        self.created_count = 0
        self.deleted_count = 0
        self.total_size = 0

        # Register cleanup on exit
        atexit.register(self.cleanup_all)

    def create_temp_file(self, prefix: str = 'tmp', suffix: str = '', purpose: str = 'general') -> Path:
        """Create a secure temporary file."""
        with self.lock:
            # Create file
            fd, path = tempfile.mkstemp(prefix=prefix, suffix=suffix, dir=self.base_dir)
            os.close(fd)

            path = Path(path)

            # Track it
            self.active_files[str(path)] = {
                'purpose': purpose,
                'created': datetime.now().isoformat(),
                'size': 0
            }

            self.created_count += 1
            logger.debug(f"Created temp file: {path}")

            return path

    def create_temp_dir(self, prefix: str = 'tmpdir', purpose: str = 'general') -> Path:
        """Create a secure temporary directory."""
        with self.lock:
            path = Path(tempfile.mkdtemp(prefix=prefix, dir=self.base_dir))

            self.active_files[str(path)] = {
                'purpose': purpose,
                'created': datetime.now().isoformat(),
                'is_dir': True
            }

            self.created_count += 1
            return path

    def write_temp_data(self, data: bytes, prefix: str = 'data', suffix: str = '.bin', purpose: str = 'data') -> Path:
        """Write data to a new temp file."""
        path = self.create_temp_file(prefix, suffix, purpose)

        with open(path, 'wb') as f:
            f.write(data)

        with self.lock:
            self.active_files[str(path)]['size'] = len(data)
            self.total_size += len(data)

        return path

    def secure_delete(self, path: Path):
        """Securely delete a temp file."""
        path = Path(path)
        str_path = str(path)

        if not path.exists():
            with self.lock:
                if str_path in self.active_files:
                    del self.active_files[str_path]
            return

        try:
            if path.is_file():
                # Overwrite before delete for sensitive data
                size = path.stat().st_size
                with open(path, 'wb') as f:
                    f.write(os.urandom(size))
                path.unlink()

            elif path.is_dir():
                # Recursively delete
                shutil.rmtree(path)

            with self.lock:
                if str_path in self.active_files:
                    del self.active_files[str_path]
                self.deleted_count += 1

            logger.debug(f"Securely deleted: {path}")

        except Exception as e:
            logger.error(f"Failed to delete {path}: {e}")

    def cleanup_old(self, max_age_hours: float = 1.0):
        """Clean up temp files older than max_age."""
        cutoff = datetime.now().timestamp() - (max_age_hours * 3600)

        to_delete = []

        with self.lock:
            for path, info in self.active_files.items():
                created = datetime.fromisoformat(info['created']).timestamp()
                if created < cutoff:
                    to_delete.append(path)

        for path in to_delete:
            self.secure_delete(Path(path))

        if to_delete:
            logger.info(f"Cleaned up {len(to_delete)} old temp files")

    def cleanup_all(self):
        """Clean up all temp files."""
        paths = list(self.active_files.keys())

        for path in paths:
            self.secure_delete(Path(path))

        # Try to remove base dir
        try:
            if self.base_dir.exists() and not any(self.base_dir.iterdir()):
                self.base_dir.rmdir()
        except:
            pass

        logger.info(f"Cleaned up all temp files ({len(paths)} files)")

    def get_stats(self) -> Dict:
        """Get temp file statistics."""
        active_size = 0
        for path in self.active_files:
            p = Path(path)
            if p.exists() and p.is_file():
                active_size += p.stat().st_size

        return {
            'active_files': len(self.active_files),
            'active_size_mb': active_size / (1024**2),
            'created_count': self.created_count,
            'deleted_count': self.deleted_count,
            'total_written_mb': self.total_size / (1024**2)
        }


def main():
    parser = argparse.ArgumentParser(description='Safe tempfile handler')
    parser.add_argument('--demo', action='store_true')
    parser.add_argument('--cleanup-age', type=float, default=1.0, help='Cleanup files older than N hours')

    args = parser.parse_args()

    handler = SafeTempfileHandler({})

    if args.demo:
        # Create some temp files
        files = []

        for i in range(5):
            data = os.urandom(10000)
            path = handler.write_temp_data(data, prefix=f'test_{i}', purpose='demo')
            files.append(path)
            logger.info(f"Created: {path}")

        # Create temp dir
        temp_dir = handler.create_temp_dir(prefix='demo_dir')
        logger.info(f"Created dir: {temp_dir}")

        # Stats
        stats = handler.get_stats()
        logger.info(f"\n=== Stats ===")
        logger.info(f"Active: {stats['active_files']} ({stats['active_size_mb']:.2f} MB)")

        # Delete some
        handler.secure_delete(files[0])
        handler.secure_delete(temp_dir)

        # Final stats
        stats = handler.get_stats()
        logger.info(f"After cleanup: {stats['active_files']} active")

        # Cleanup rest on exit (atexit handler)
    else:
        # Run cleanup
        handler.cleanup_old(args.cleanup_age)


if __name__ == '__main__':
    main()
