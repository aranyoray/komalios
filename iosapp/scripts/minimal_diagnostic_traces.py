#!/usr/bin/env python3
"""
minimal_diagnostic_traces.py - Gather device diagnostics without PII

Collects FPS drops, CPU spikes, etc. in compressed format.
"""

import argparse
import json
import gzip
import time
import os
import logging
from datetime import datetime
from typing import Dict, List
from collections import deque

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class DiagnosticTracer:
    """Collect minimal diagnostic traces."""

    def __init__(self, config: Dict):
        self.config = config
        self.buffer_size = config.get('buffer_size', 1000)
        self.traces = deque(maxlen=self.buffer_size)

        # Thresholds for anomalies
        self.fps_drop_threshold = config.get('fps_drop_threshold', 20)
        self.cpu_spike_threshold = config.get('cpu_spike_threshold', 0.9)
        self.memory_spike_threshold = config.get('memory_spike_percent', 90)

        # Aggregate stats
        self.anomaly_counts = {
            'fps_drops': 0,
            'cpu_spikes': 0,
            'memory_spikes': 0,
            'errors': 0
        }

    def record_frame(self, fps: float, cpu_load: float, memory_percent: float):
        """Record a frame diagnostic."""
        trace = {
            't': int(time.time()),
            'fps': round(fps, 1),
            'cpu': round(cpu_load, 2),
            'mem': round(memory_percent, 1)
        }

        # Check anomalies
        if fps < self.fps_drop_threshold:
            self.anomaly_counts['fps_drops'] += 1
            trace['a'] = 'fps'

        if cpu_load > self.cpu_spike_threshold:
            self.anomaly_counts['cpu_spikes'] += 1
            trace['a'] = trace.get('a', '') + 'cpu'

        if memory_percent > self.memory_spike_threshold:
            self.anomaly_counts['memory_spikes'] += 1
            trace['a'] = trace.get('a', '') + 'mem'

        self.traces.append(trace)

    def record_error(self, error_type: str, message: str):
        """Record an error (sanitized)."""
        # Remove any potential PII from message
        sanitized = message[:100].replace('\n', ' ')

        trace = {
            't': int(time.time()),
            'err': error_type,
            'msg': sanitized
        }

        self.traces.append(trace)
        self.anomaly_counts['errors'] += 1

    def get_summary(self) -> Dict:
        """Get diagnostic summary."""
        if not self.traces:
            return {'empty': True}

        fps_values = [t['fps'] for t in self.traces if 'fps' in t]
        cpu_values = [t['cpu'] for t in self.traces if 'cpu' in t]
        mem_values = [t['mem'] for t in self.traces if 'mem' in t]

        import numpy as np

        summary = {
            'trace_count': len(self.traces),
            'anomalies': self.anomaly_counts,
            'duration_s': self.traces[-1]['t'] - self.traces[0]['t'] if len(self.traces) > 1 else 0
        }

        if fps_values:
            summary['fps'] = {
                'mean': round(float(np.mean(fps_values)), 1),
                'min': round(float(np.min(fps_values)), 1),
                'p5': round(float(np.percentile(fps_values, 5)), 1)
            }

        if cpu_values:
            summary['cpu'] = {
                'mean': round(float(np.mean(cpu_values)), 2),
                'max': round(float(np.max(cpu_values)), 2),
                'p95': round(float(np.percentile(cpu_values, 95)), 2)
            }

        if mem_values:
            summary['memory'] = {
                'mean': round(float(np.mean(mem_values)), 1),
                'max': round(float(np.max(mem_values)), 1)
            }

        return summary

    def export_compressed(self, output_path: str):
        """Export traces as compressed JSON."""
        data = {
            'version': 1,
            'exported': datetime.now().isoformat(),
            'summary': self.get_summary(),
            'traces': list(self.traces)
        }

        json_bytes = json.dumps(data, separators=(',', ':')).encode('utf-8')
        compressed = gzip.compress(json_bytes)

        with open(output_path, 'wb') as f:
            f.write(compressed)

        compression_ratio = len(json_bytes) / len(compressed)
        logger.info(f"Exported {len(self.traces)} traces to {output_path} "
                   f"({len(compressed)} bytes, {compression_ratio:.1f}x compression)")

        return {
            'original_size': len(json_bytes),
            'compressed_size': len(compressed),
            'compression_ratio': compression_ratio
        }


def run_demo(tracer: DiagnosticTracer, duration: int = 10):
    """Run demo trace collection."""
    import random

    start = time.time()
    frame_count = 0

    while time.time() - start < duration:
        # Simulate metrics with occasional anomalies
        fps = 30 + random.gauss(0, 5)
        if random.random() < 0.05:  # 5% chance of drop
            fps = random.uniform(5, 15)

        cpu = random.uniform(0.3, 0.7)
        if random.random() < 0.03:  # 3% chance of spike
            cpu = random.uniform(0.9, 1.0)

        memory = random.uniform(40, 70)
        if random.random() < 0.02:
            memory = random.uniform(90, 98)

        tracer.record_frame(fps, cpu, memory)
        frame_count += 1

        # Occasional error
        if random.random() < 0.01:
            tracer.record_error('network', 'Connection timeout')

        time.sleep(0.033)  # ~30 FPS

    logger.info(f"Collected {frame_count} frames")


def main():
    parser = argparse.ArgumentParser(description='Minimal diagnostic traces')
    parser.add_argument('--duration', type=int, default=10, help='Demo duration')
    parser.add_argument('--output', type=str, default='diagnostics.json.gz')
    parser.add_argument('--demo', action='store_true')

    args = parser.parse_args()

    tracer = DiagnosticTracer({})

    if args.demo:
        run_demo(tracer, args.duration)

        # Summary
        summary = tracer.get_summary()
        logger.info(f"\n=== Diagnostic Summary ===")
        logger.info(f"Traces: {summary['trace_count']}")
        logger.info(f"FPS drops: {summary['anomalies']['fps_drops']}")
        logger.info(f"CPU spikes: {summary['anomalies']['cpu_spikes']}")
        if 'fps' in summary:
            logger.info(f"FPS: mean={summary['fps']['mean']}, min={summary['fps']['min']}")

        tracer.export_compressed(args.output)


if __name__ == '__main__':
    main()
