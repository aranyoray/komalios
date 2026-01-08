#!/usr/bin/env python3
"""
embedding_cache_service.py — On-device reusable embedding cache with LRU eviction.
Stores compact hashed embeddings, deduplicates frames, snapshots to disk.
"""

import argparse
import hashlib
import json
import logging
import pickle
import threading
import time
from pathlib import Path
from collections import OrderedDict
from typing import Optional, Tuple
import numpy as np

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description='Embedding cache service')
    parser.add_argument('--max_size_mb', type=float, default=100, help='Max cache size in MB')
    parser.add_argument('--prefill', type=str, help='Prefill cache from snapshot')
    parser.add_argument('--snapshot_path', type=str, default='./cache/embedding_cache.pkl')
    parser.add_argument('--snapshot_interval', type=int, default=300, help='Snapshot interval in seconds')
    parser.add_argument('--hash_dims', type=int, default=64, help='Dimensions for locality-sensitive hash')
    parser.add_argument('--serve', action='store_true', help='Run as service')
    parser.add_argument('--port', type=int, default=8081)
    return parser.parse_args()


class EmbeddingCache:
    """LRU cache for embeddings with deduplication."""

    def __init__(self, max_size_mb=100, hash_dims=64):
        self.max_size_bytes = int(max_size_mb * 1024 * 1024)
        self.hash_dims = hash_dims
        self.cache = OrderedDict()  # key -> (embedding, size, timestamp)
        self.hash_index = {}  # frame_hash -> key
        self.current_size = 0
        self.lock = threading.RLock()

        # Stats
        self.hits = 0
        self.misses = 0
        self.dedup_hits = 0

        # LSH random projection for deduplication
        self.lsh_projection = None

    def _compute_frame_hash(self, frame: np.ndarray) -> str:
        """Compute perceptual hash of frame for deduplication."""
        # Downsample and hash
        if frame.ndim == 3:
            frame = frame.mean(axis=2)  # Grayscale

        # Resize to small fixed size
        from scipy.ndimage import zoom
        small = zoom(frame, (8 / frame.shape[0], 8 / frame.shape[1]))

        # Compute hash from DCT-like features
        mean_val = small.mean()
        bits = (small > mean_val).flatten()
        return hashlib.md5(bits.tobytes()).hexdigest()

    def _compute_embedding_key(self, embedding: np.ndarray) -> str:
        """Compute LSH key for embedding lookup."""
        if self.lsh_projection is None:
            self.lsh_projection = np.random.randn(embedding.shape[0], self.hash_dims)

        projected = embedding @ self.lsh_projection
        bits = (projected > 0).astype(np.uint8)
        return hashlib.md5(bits.tobytes()).hexdigest()

    def get(self, key: str) -> Optional[np.ndarray]:
        """Get embedding from cache."""
        with self.lock:
            if key in self.cache:
                # Move to end (most recently used)
                self.cache.move_to_end(key)
                self.hits += 1
                return self.cache[key][0]
            self.misses += 1
            return None

    def get_by_frame(self, frame: np.ndarray) -> Optional[Tuple[str, np.ndarray]]:
        """Get cached embedding for similar frame (deduplication)."""
        frame_hash = self._compute_frame_hash(frame)

        with self.lock:
            if frame_hash in self.hash_index:
                key = self.hash_index[frame_hash]
                if key in self.cache:
                    self.cache.move_to_end(key)
                    self.dedup_hits += 1
                    return key, self.cache[key][0]
        return None

    def put(self, key: str, embedding: np.ndarray, frame: np.ndarray = None):
        """Store embedding in cache."""
        embedding_bytes = embedding.nbytes

        with self.lock:
            # Evict if necessary
            while self.current_size + embedding_bytes > self.max_size_bytes and self.cache:
                oldest_key, (_, size, _) = self.cache.popitem(last=False)
                self.current_size -= size
                # Clean up hash index
                self.hash_index = {k: v for k, v in self.hash_index.items() if v != oldest_key}

            # Store
            self.cache[key] = (embedding.copy(), embedding_bytes, time.time())
            self.current_size += embedding_bytes

            # Index by frame hash for deduplication
            if frame is not None:
                frame_hash = self._compute_frame_hash(frame)
                self.hash_index[frame_hash] = key

    def stats(self):
        """Get cache statistics."""
        with self.lock:
            total_requests = self.hits + self.misses
            hit_rate = self.hits / total_requests if total_requests > 0 else 0

            return {
                'entries': len(self.cache),
                'size_mb': self.current_size / (1024 * 1024),
                'max_size_mb': self.max_size_bytes / (1024 * 1024),
                'hits': self.hits,
                'misses': self.misses,
                'dedup_hits': self.dedup_hits,
                'hit_rate': round(hit_rate, 3)
            }

    def save_snapshot(self, path: str):
        """Save cache to disk."""
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)

        with self.lock:
            snapshot = {
                'cache': dict(self.cache),
                'hash_index': self.hash_index,
                'lsh_projection': self.lsh_projection,
                'stats': self.stats()
            }

            with open(path, 'wb') as f:
                pickle.dump(snapshot, f)

        logger.info(f"Saved snapshot: {path} ({len(self.cache)} entries)")

    def load_snapshot(self, path: str):
        """Load cache from disk."""
        path = Path(path)
        if not path.exists():
            logger.warning(f"Snapshot not found: {path}")
            return

        with open(path, 'rb') as f:
            snapshot = pickle.load(f)

        with self.lock:
            self.cache = OrderedDict(snapshot['cache'])
            self.hash_index = snapshot.get('hash_index', {})
            self.lsh_projection = snapshot.get('lsh_projection')
            self.current_size = sum(entry[1] for entry in self.cache.values())

        logger.info(f"Loaded snapshot: {path} ({len(self.cache)} entries)")


def run_snapshot_thread(cache, path, interval):
    """Periodically save snapshots."""
    while True:
        time.sleep(interval)
        try:
            cache.save_snapshot(path)
        except Exception as e:
            logger.error(f"Snapshot failed: {e}")


def main():
    args = parse_args()

    cache = EmbeddingCache(max_size_mb=args.max_size_mb, hash_dims=args.hash_dims)

    # Prefill from snapshot
    if args.prefill:
        cache.load_snapshot(args.prefill)

    if args.serve:
        # Start snapshot thread
        snapshot_thread = threading.Thread(
            target=run_snapshot_thread,
            args=(cache, args.snapshot_path, args.snapshot_interval),
            daemon=True
        )
        snapshot_thread.start()

        # Simple HTTP service
        from http.server import HTTPServer, BaseHTTPRequestHandler
        import json

        class CacheHandler(BaseHTTPRequestHandler):
            def do_GET(self):
                if self.path == '/stats':
                    self.send_response(200)
                    self.send_header('Content-Type', 'application/json')
                    self.end_headers()
                    self.wfile.write(json.dumps(cache.stats()).encode())
                else:
                    self.send_error(404)

            def log_message(self, format, *args):
                pass

        server = HTTPServer(('0.0.0.0', args.port), CacheHandler)
        logger.info(f"Cache service running on port {args.port}")
        server.serve_forever()
    else:
        # Demo mode
        logger.info("Running demo...")

        # Generate test embeddings
        for i in range(100):
            key = f"embedding_{i}"
            embedding = np.random.randn(512).astype(np.float32)
            frame = np.random.randint(0, 255, (64, 64), dtype=np.uint8)
            cache.put(key, embedding, frame)

        # Test retrieval
        for i in range(50):
            cache.get(f"embedding_{i}")

        print(json.dumps(cache.stats(), indent=2))
        cache.save_snapshot(args.snapshot_path)


if __name__ == '__main__':
    main()
