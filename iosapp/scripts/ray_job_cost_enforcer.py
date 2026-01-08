#!/usr/bin/env python3
"""
ray_job_cost_enforcer.py - Track and enforce cost limits for Ray jobs

Wraps Ray jobs, tracks cost-per-job, kills jobs exceeding limits.
"""

import argparse
import json
import time
import logging
from datetime import datetime
from typing import Dict, List, Optional

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class CostLedger:
    """Track job costs."""

    def __init__(self, ledger_path: str = 'cost_ledger.json'):
        self.ledger_path = ledger_path
        self.entries = []

    def add_entry(self, job_id: str, cost: float, duration_s: float, status: str):
        """Add ledger entry."""
        self.entries.append({
            'job_id': job_id,
            'cost': cost,
            'duration_s': duration_s,
            'status': status,
            'timestamp': datetime.now().isoformat()
        })

    def save(self):
        """Save ledger to disk."""
        with open(self.ledger_path, 'w') as f:
            json.dump(self.entries, f, indent=2)

    def get_total_cost(self) -> float:
        """Get total cost from ledger."""
        return sum(e['cost'] for e in self.entries)


class RayJobCostEnforcer:
    """Enforce cost limits on Ray jobs."""

    def __init__(self, config: Dict):
        self.config = config
        self.max_cost_per_job = config.get('max_cost_per_job', 50.0)
        self.gpu_cost_per_hour = config.get('gpu_cost_per_hour', 2.50)

        self.ledger = CostLedger(config.get('ledger_path', 'cost_ledger.json'))
        self.active_jobs = {}

    def start_job(self, job_id: str, estimated_cost: float = None):
        """Start tracking a job."""
        if estimated_cost and estimated_cost > self.max_cost_per_job:
            logger.warning(f"Job {job_id} estimated cost ${estimated_cost:.2f} exceeds limit")

        self.active_jobs[job_id] = {
            'start_time': time.time(),
            'estimated_cost': estimated_cost,
            'cost_so_far': 0.0
        }

        logger.info(f"Started tracking job {job_id}")

    def update_job(self, job_id: str, gpu_hours_used: float) -> Dict:
        """Update job cost and check limits."""
        if job_id not in self.active_jobs:
            return {'error': 'Job not found'}

        job = self.active_jobs[job_id]
        job['cost_so_far'] = gpu_hours_used * self.gpu_cost_per_hour

        # Check if exceeded
        if job['cost_so_far'] > self.max_cost_per_job:
            return {
                'action': 'kill',
                'reason': f"Cost ${job['cost_so_far']:.2f} exceeds limit ${self.max_cost_per_job}",
                'cost': job['cost_so_far']
            }

        # Warn at 80%
        if job['cost_so_far'] > self.max_cost_per_job * 0.8:
            return {
                'action': 'warn',
                'reason': f"Cost at {job['cost_so_far']/self.max_cost_per_job*100:.0f}% of limit",
                'cost': job['cost_so_far']
            }

        return {'action': 'continue', 'cost': job['cost_so_far']}

    def complete_job(self, job_id: str, status: str = 'completed'):
        """Mark job as complete and record to ledger."""
        if job_id not in self.active_jobs:
            return

        job = self.active_jobs[job_id]
        duration = time.time() - job['start_time']

        self.ledger.add_entry(job_id, job['cost_so_far'], duration, status)

        del self.active_jobs[job_id]
        logger.info(f"Job {job_id} {status}: ${job['cost_so_far']:.2f}, {duration:.0f}s")

    def kill_job(self, job_id: str, reason: str):
        """Kill a job for cost violation."""
        logger.warning(f"Killing job {job_id}: {reason}")

        # Would call Ray API to kill job here
        # ray.cancel(job_id)

        self.complete_job(job_id, f'killed: {reason}')

    def get_stats(self) -> Dict:
        """Get cost enforcement statistics."""
        return {
            'active_jobs': len(self.active_jobs),
            'total_ledger_cost': self.ledger.get_total_cost(),
            'ledger_entries': len(self.ledger.entries),
            'max_cost_per_job': self.max_cost_per_job
        }


def main():
    parser = argparse.ArgumentParser(description='Ray job cost enforcer')
    parser.add_argument('--max-cost', type=float, default=50.0, help='Max cost per job')
    parser.add_argument('--demo', action='store_true')

    args = parser.parse_args()

    enforcer = RayJobCostEnforcer({
        'max_cost_per_job': args.max_cost
    })

    if args.demo:
        import random

        # Simulate some jobs
        jobs = ['train_emotion', 'train_attention', 'hpo_search', 'evaluation']

        for job_id in jobs:
            estimated = random.uniform(20, 80)
            enforcer.start_job(job_id, estimated)

            # Simulate progress
            total_hours = 0
            for _ in range(10):
                total_hours += random.uniform(0.5, 3)
                result = enforcer.update_job(job_id, total_hours)

                if result['action'] == 'kill':
                    enforcer.kill_job(job_id, result['reason'])
                    break
                elif result['action'] == 'warn':
                    logger.warning(f"Job {job_id}: {result['reason']}")
            else:
                enforcer.complete_job(job_id)

        # Save and show stats
        enforcer.ledger.save()
        stats = enforcer.get_stats()

        logger.info(f"\n=== Cost Enforcement Stats ===")
        logger.info(f"Total cost: ${stats['total_ledger_cost']:.2f}")
        logger.info(f"Jobs processed: {stats['ledger_entries']}")


if __name__ == '__main__':
    main()
