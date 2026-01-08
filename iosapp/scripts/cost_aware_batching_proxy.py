#!/usr/bin/env python3
"""
cost_aware_batching_proxy.py — Batch inference gateway with cost cap.
Batches requests, enforces GPU-hour budget, falls back to cache when exceeded.
"""

import argparse
import json
import logging
import time
import threading
from pathlib import Path
from collections import deque
from datetime import datetime, timedelta
from http.server import HTTPServer, BaseHTTPRequestHandler

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description='Cost-aware batching proxy')
    parser.add_argument('--port', type=int, default=8082)
    parser.add_argument('--batch_size', type=int, default=8)
    parser.add_argument('--batch_timeout_ms', type=int, default=50)
    parser.add_argument('--gpu_budget_hours', type=float, default=10.0, help='Monthly GPU-hour budget')
    parser.add_argument('--billing_log', type=str, default='./logs/billing.jsonl')
    parser.add_argument('--cache_dir', type=str, default='./inference_cache')
    return parser.parse_args()


class CostAwareBatchingProxy:
    """Manages batching and cost tracking."""

    def __init__(self, batch_size, batch_timeout_ms, gpu_budget_hours):
        self.batch_size = batch_size
        self.batch_timeout = batch_timeout_ms / 1000
        self.monthly_budget_seconds = gpu_budget_hours * 3600

        self.pending_requests = deque()
        self.lock = threading.Lock()
        self.gpu_usage_seconds = 0
        self.usage_reset_time = datetime.now().replace(day=1, hour=0, minute=0, second=0)

        self.cache = {}
        self.billing_log = []
        self.total_requests = 0
        self.cache_hits = 0

    def add_request(self, request_id, data):
        """Add request to batch queue."""
        with self.lock:
            self.pending_requests.append({
                'id': request_id,
                'data': data,
                'timestamp': time.time()
            })
            self.total_requests += 1

    def get_batch(self):
        """Get batch of requests ready for processing."""
        with self.lock:
            if not self.pending_requests:
                return []

            # Wait for batch to fill or timeout
            oldest = self.pending_requests[0]['timestamp']
            if len(self.pending_requests) < self.batch_size:
                if time.time() - oldest < self.batch_timeout:
                    return []

            # Extract batch
            batch = []
            while self.pending_requests and len(batch) < self.batch_size:
                batch.append(self.pending_requests.popleft())

            return batch

    def is_budget_exceeded(self):
        """Check if GPU budget is exceeded."""
        # Reset monthly
        now = datetime.now()
        if now >= self.usage_reset_time + timedelta(days=30):
            self.gpu_usage_seconds = 0
            self.usage_reset_time = now.replace(day=1, hour=0, minute=0, second=0)

        return self.gpu_usage_seconds >= self.monthly_budget_seconds

    def record_gpu_usage(self, seconds):
        """Record GPU usage time."""
        self.gpu_usage_seconds += seconds

    def get_cached_response(self, key):
        """Get cached response."""
        if key in self.cache:
            self.cache_hits += 1
            return self.cache[key]
        return None

    def cache_response(self, key, response):
        """Cache response."""
        self.cache[key] = response

    def log_billing(self, batch_size, gpu_seconds, cached):
        """Log billing event."""
        event = {
            'timestamp': datetime.now().isoformat(),
            'batch_size': batch_size,
            'gpu_seconds': gpu_seconds,
            'cached': cached,
            'total_usage_seconds': self.gpu_usage_seconds,
            'budget_remaining': self.monthly_budget_seconds - self.gpu_usage_seconds
        }
        self.billing_log.append(event)

    def get_stats(self):
        """Get proxy statistics."""
        return {
            'total_requests': self.total_requests,
            'cache_hits': self.cache_hits,
            'cache_hit_rate': self.cache_hits / self.total_requests if self.total_requests > 0 else 0,
            'gpu_usage_hours': self.gpu_usage_seconds / 3600,
            'budget_hours': self.monthly_budget_seconds / 3600,
            'budget_utilization': self.gpu_usage_seconds / self.monthly_budget_seconds
        }


def process_batch(proxy, batch):
    """Process a batch of requests."""
    if not batch:
        return []

    # Check budget
    if proxy.is_budget_exceeded():
        logger.warning("GPU budget exceeded, using cached responses")
        results = []
        for req in batch:
            cached = proxy.get_cached_response(str(req['data']))
            if cached:
                results.append({'id': req['id'], 'result': cached, 'cached': True})
            else:
                results.append({'id': req['id'], 'error': 'Budget exceeded', 'cached': False})
        proxy.log_billing(len(batch), 0, True)
        return results

    # Simulate GPU inference
    start = time.perf_counter()
    results = []

    for req in batch:
        # Simulate inference
        import numpy as np
        result = {'embedding': np.random.randn(128).tolist()}
        results.append({'id': req['id'], 'result': result, 'cached': False})
        proxy.cache_response(str(req['data']), result)

    gpu_seconds = time.perf_counter() - start
    proxy.record_gpu_usage(gpu_seconds)
    proxy.log_billing(len(batch), gpu_seconds, False)

    return results


def main():
    args = parse_args()

    proxy = CostAwareBatchingProxy(
        args.batch_size,
        args.batch_timeout_ms,
        args.gpu_budget_hours
    )

    # Ensure directories exist
    Path(args.billing_log).parent.mkdir(parents=True, exist_ok=True)
    Path(args.cache_dir).mkdir(parents=True, exist_ok=True)

    class ProxyHandler(BaseHTTPRequestHandler):
        def do_POST(self):
            if self.path == '/infer':
                content_length = int(self.headers['Content-Length'])
                data = json.loads(self.rfile.read(content_length))

                request_id = f"req_{time.time_ns()}"
                proxy.add_request(request_id, data)

                # Wait for batch processing
                batch = proxy.get_batch()
                if batch:
                    results = process_batch(proxy, batch)
                    for result in results:
                        if result['id'] == request_id:
                            self.send_response(200)
                            self.send_header('Content-Type', 'application/json')
                            self.end_headers()
                            self.wfile.write(json.dumps(result).encode())
                            return

                self.send_response(202)
                self.end_headers()
            else:
                self.send_error(404)

        def do_GET(self):
            if self.path == '/stats':
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps(proxy.get_stats()).encode())
            else:
                self.send_error(404)

        def log_message(self, format, *args):
            pass

    server = HTTPServer(('0.0.0.0', args.port), ProxyHandler)
    logger.info(f"Batching proxy running on port {args.port}")
    logger.info(f"GPU budget: {args.gpu_budget_hours} hours/month")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        # Save billing log
        with open(args.billing_log, 'w') as f:
            for event in proxy.billing_log:
                f.write(json.dumps(event) + '\n')
        logger.info(f"Billing log saved: {args.billing_log}")


if __name__ == '__main__':
    main()
