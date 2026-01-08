#!/usr/bin/env python3
"""
tiny_cache_reaper.py - Delete old local temp assets based on LRU

Cleans thumbnails, intermediate frames, temp files based on LRU,
max size, and session age.
"""

import argparse
import json
import os
import time
import logging
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional
import shutil

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class CacheEntry:
    """Represents a cache entry with metadata."""

    def __init__(self, path: Path):
        self.path = path
        self.size = path.stat().st_size if path.exists() else 0
        self.atime = path.stat().st_atime if path.exists() else 0
        self.mtime = path.stat().st_mtime if path.exists() else 0


class TinyCacheReaper:
    """Manage and clean local caches."""

    def __init__(self, config: Dict):
        self.config = config

        # Cache directories to manage
        self.cache_dirs = [
            Path(d) for d in config.get('cache_dirs', [
                '.thumbnails',
                '.frame_cache',
                '.model_cache',
                '.audio_cache',
                'temp'
            ])
        ]

        # Limits
        self.max_total_size_mb = config.get('max_total_size_mb', 500)
        self.max_age_hours = config.get('max_age_hours', 24)
        self.max_files = config.get('max_files', 10000)

        # Stats
        self.stats = {
            'files_deleted': 0,
            'bytes_freed': 0,
            'scans': 0
        }

    def scan_caches(self) -> List[CacheEntry]:
        """Scan all cache directories."""
        entries = []

        for cache_dir in self.cache_dirs:
            if not cache_dir.exists():
                continue

            for path in cache_dir.rglob('*'):
                if path.is_file():
                    try:
                        entries.append(CacheEntry(path))
                    except Exception as e:
                        logger.warning(f"Could not stat {path}: {e}")

        self.stats['scans'] += 1
        return entries

    def get_cache_stats(self) -> Dict:
        """Get current cache statistics."""
        entries = self.scan_caches()

        total_size = sum(e.size for e in entries)
        file_count = len(entries)

        if entries:
            oldest = min(e.atime for e in entries)
            newest = max(e.atime for e in entries)
            oldest_age = (time.time() - oldest) / 3600
        else:
            oldest_age = 0

        return {
            'total_size_mb': total_size / (1024 * 1024),
            'file_count': file_count,
            'oldest_file_hours': oldest_age,
            'cache_dirs': [str(d) for d in self.cache_dirs if d.exists()]
        }

    def reap_by_age(self, max_age_hours: Optional[float] = None) -> int:
        """Delete files older than max age."""
        if max_age_hours is None:
            max_age_hours = self.max_age_hours

        cutoff = time.time() - (max_age_hours * 3600)
        entries = self.scan_caches()

        deleted = 0
        freed = 0

        for entry in entries:
            if entry.atime < cutoff:
                try:
                    entry.path.unlink()
                    deleted += 1
                    freed += entry.size
                    logger.debug(f"Deleted (age): {entry.path}")
                except Exception as e:
                    logger.warning(f"Could not delete {entry.path}: {e}")

        self.stats['files_deleted'] += deleted
        self.stats['bytes_freed'] += freed

        if deleted > 0:
            logger.info(f"Deleted {deleted} files older than {max_age_hours}h "
                       f"({freed / (1024*1024):.1f} MB freed)")

        return deleted

    def reap_by_size(self, max_size_mb: Optional[float] = None) -> int:
        """Delete files to stay under size limit using LRU."""
        if max_size_mb is None:
            max_size_mb = self.max_total_size_mb

        max_bytes = max_size_mb * 1024 * 1024
        entries = self.scan_caches()

        # Sort by access time (LRU first)
        entries.sort(key=lambda e: e.atime)

        total_size = sum(e.size for e in entries)
        deleted = 0
        freed = 0

        for entry in entries:
            if total_size <= max_bytes:
                break

            try:
                entry.path.unlink()
                total_size -= entry.size
                freed += entry.size
                deleted += 1
                logger.debug(f"Deleted (LRU): {entry.path}")
            except Exception as e:
                logger.warning(f"Could not delete {entry.path}: {e}")

        self.stats['files_deleted'] += deleted
        self.stats['bytes_freed'] += freed

        if deleted > 0:
            logger.info(f"Deleted {deleted} LRU files to stay under {max_size_mb}MB "
                       f"({freed / (1024*1024):.1f} MB freed)")

        return deleted

    def reap_by_count(self, max_files: Optional[int] = None) -> int:
        """Delete files to stay under file count limit."""
        if max_files is None:
            max_files = self.max_files

        entries = self.scan_caches()

        if len(entries) <= max_files:
            return 0

        # Sort by access time (LRU first)
        entries.sort(key=lambda e: e.atime)

        to_delete = len(entries) - max_files
        deleted = 0
        freed = 0

        for entry in entries[:to_delete]:
            try:
                entry.path.unlink()
                freed += entry.size
                deleted += 1
            except Exception as e:
                logger.warning(f"Could not delete {entry.path}: {e}")

        self.stats['files_deleted'] += deleted
        self.stats['bytes_freed'] += freed

        if deleted > 0:
            logger.info(f"Deleted {deleted} files to stay under {max_files} files "
                       f"({freed / (1024*1024):.1f} MB freed)")

        return deleted

    def reap_empty_dirs(self) -> int:
        """Delete empty directories in cache."""
        deleted = 0

        for cache_dir in self.cache_dirs:
            if not cache_dir.exists():
                continue

            for dirpath in sorted(cache_dir.rglob('*'), reverse=True):
                if dirpath.is_dir():
                    try:
                        dirpath.rmdir()  # Only works if empty
                        deleted += 1
                        logger.debug(f"Deleted empty dir: {dirpath}")
                    except OSError:
                        pass  # Not empty

        if deleted > 0:
            logger.info(f"Deleted {deleted} empty directories")

        return deleted

    def reap_all(self) -> Dict:
        """Run all reaping strategies."""
        results = {
            'by_age': self.reap_by_age(),
            'by_size': self.reap_by_size(),
            'by_count': self.reap_by_count(),
            'empty_dirs': self.reap_empty_dirs()
        }

        total = sum(results.values())
        results['total_deleted'] = total

        return results

    def get_stats(self) -> Dict:
        """Get reaper statistics."""
        cache_stats = self.get_cache_stats()

        return {
            'cache': cache_stats,
            'reaper': {
                'total_files_deleted': self.stats['files_deleted'],
                'total_bytes_freed': self.stats['bytes_freed'],
                'total_mb_freed': self.stats['bytes_freed'] / (1024 * 1024),
                'scans': self.stats['scans']
            }
        }


def create_test_cache(base_dir: Path, file_count: int = 100):
    """Create test cache files for demo."""
    import random

    cache_dirs = [
        base_dir / '.thumbnails',
        base_dir / '.frame_cache',
        base_dir / 'temp'
    ]

    for cache_dir in cache_dirs:
        cache_dir.mkdir(parents=True, exist_ok=True)

    for i in range(file_count):
        cache_dir = random.choice(cache_dirs)
        file_path = cache_dir / f"file_{i}.tmp"

        # Create file with random size
        size = random.randint(1000, 100000)
        file_path.write_bytes(os.urandom(size))

        # Set random access time (some old, some new)
        age = random.uniform(0, 48 * 3600)  # 0-48 hours
        atime = time.time() - age
        os.utime(file_path, (atime, atime))

    logger.info(f"Created {file_count} test cache files")


def main():
    parser = argparse.ArgumentParser(description='Tiny cache reaper')
    parser.add_argument('--max-size', type=float, default=500, help='Max total size in MB')
    parser.add_argument('--max-age', type=float, default=24, help='Max file age in hours')
    parser.add_argument('--max-files', type=int, default=10000, help='Max file count')
    parser.add_argument('--cache-dirs', type=str, nargs='+', help='Cache directories')
    parser.add_argument('--create-test', type=int, help='Create N test files')
    parser.add_argument('--dry-run', action='store_true', help='Show what would be deleted')
    parser.add_argument('--demo', action='store_true', help='Run demo')

    args = parser.parse_args()

    if args.cache_dirs:
        cache_dirs = args.cache_dirs
    else:
        cache_dirs = ['.thumbnails', '.frame_cache', '.model_cache', 'temp']

    config = {
        'cache_dirs': cache_dirs,
        'max_total_size_mb': args.max_size,
        'max_age_hours': args.max_age,
        'max_files': args.max_files
    }

    reaper = TinyCacheReaper(config)

    if args.create_test:
        create_test_cache(Path('.'), args.create_test)

    if args.dry_run:
        stats = reaper.get_cache_stats()
        logger.info(f"\n=== Cache Stats (Dry Run) ===")
        logger.info(f"Total size: {stats['total_size_mb']:.1f} MB")
        logger.info(f"File count: {stats['file_count']}")
        logger.info(f"Oldest file: {stats['oldest_file_hours']:.1f} hours")
        logger.info(f"Dirs: {stats['cache_dirs']}")
    elif args.demo:
        # Create test data
        create_test_cache(Path('.'), 200)

        # Show before
        before = reaper.get_cache_stats()
        logger.info(f"\nBefore: {before['file_count']} files, {before['total_size_mb']:.1f} MB")

        # Reap
        results = reaper.reap_all()

        # Show after
        after = reaper.get_cache_stats()
        logger.info(f"After: {after['file_count']} files, {after['total_size_mb']:.1f} MB")

        logger.info(f"\n=== Reap Results ===")
        logger.info(f"By age: {results['by_age']}")
        logger.info(f"By size: {results['by_size']}")
        logger.info(f"By count: {results['by_count']}")
        logger.info(f"Empty dirs: {results['empty_dirs']}")
        logger.info(f"Total freed: {reaper.stats['bytes_freed'] / (1024*1024):.1f} MB")
    else:
        # Normal operation
        results = reaper.reap_all()
        stats = reaper.get_stats()

        logger.info(f"Deleted {results['total_deleted']} files")
        logger.info(f"Freed {stats['reaper']['total_mb_freed']:.1f} MB")
        logger.info(f"Current cache: {stats['cache']['total_size_mb']:.1f} MB, "
                   f"{stats['cache']['file_count']} files")


if __name__ == '__main__':
    main()
