#!/usr/bin/env python3
"""
gpu_autoscaler_rules.py - Scale GPU nodes based on job queues and cost caps

Automatically scales GPU infrastructure up/down, caps GPU-hours per day.
"""

import argparse
import json
import time
import logging
from datetime import datetime, timedelta
from typing import Dict, List

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class GPUAutoscaler:
    """Autoscale GPU nodes based on rules."""

    def __init__(self, config: Dict):
        self.config = config
        self.max_gpu_hours_daily = config.get('max_gpu_hours_daily', 100)
        self.min_nodes = config.get('min_nodes', 0)
        self.max_nodes = config.get('max_nodes', 10)

        # Simulated state
        self.current_nodes = 0
        self.job_queue = []
        self.gpu_hours_today = 0.0
        self.scaling_history = []

    def add_job(self, job_id: str, gpu_hours_estimate: float, priority: str = 'normal'):
        """Add job to queue."""
        self.job_queue.append({
            'id': job_id,
            'gpu_hours': gpu_hours_estimate,
            'priority': priority,
            'queued_at': time.time()
        })

    def get_queue_demand(self) -> float:
        """Calculate total GPU hours demanded by queue."""
        return sum(job['gpu_hours'] for job in self.job_queue)

    def calculate_desired_nodes(self) -> int:
        """Calculate desired number of nodes."""
        if not self.job_queue:
            return self.min_nodes

        demand = self.get_queue_demand()
        remaining_budget = self.max_gpu_hours_daily - self.gpu_hours_today

        # Scale based on demand but respect budget
        effective_demand = min(demand, remaining_budget)

        # Assume each node processes 1 GPU-hour per hour
        # Target: process queue in 2 hours
        desired = int(effective_demand / 2)

        return max(self.min_nodes, min(self.max_nodes, desired))

    def scale(self) -> Dict:
        """Perform scaling decision."""
        desired = self.calculate_desired_nodes()

        action = 'none'
        if desired > self.current_nodes:
            action = 'scale_up'
        elif desired < self.current_nodes:
            action = 'scale_down'

        if action != 'none':
            self.scaling_history.append({
                'timestamp': datetime.now().isoformat(),
                'action': action,
                'from': self.current_nodes,
                'to': desired,
                'queue_size': len(self.job_queue)
            })
            self.current_nodes = desired

        return {
            'action': action,
            'nodes': self.current_nodes,
            'queue_demand': self.get_queue_demand(),
            'budget_remaining': self.max_gpu_hours_daily - self.gpu_hours_today
        }

    def process_jobs(self, hours: float = 1.0):
        """Simulate processing jobs for given hours."""
        if self.current_nodes == 0:
            return []

        processed_hours = self.current_nodes * hours
        processed = []

        while self.job_queue and processed_hours > 0:
            job = self.job_queue[0]
            if job['gpu_hours'] <= processed_hours:
                processed_hours -= job['gpu_hours']
                self.gpu_hours_today += job['gpu_hours']
                processed.append(self.job_queue.pop(0))
            else:
                break

        return processed

    def pause_low_priority(self):
        """Pause low-priority jobs when near budget."""
        if self.gpu_hours_today > self.max_gpu_hours_daily * 0.8:
            paused = [j for j in self.job_queue if j['priority'] == 'low']
            self.job_queue = [j for j in self.job_queue if j['priority'] != 'low']
            if paused:
                logger.info(f"Paused {len(paused)} low-priority jobs (budget at 80%)")
            return paused
        return []

    def get_stats(self) -> Dict:
        """Get autoscaler statistics."""
        return {
            'current_nodes': self.current_nodes,
            'queue_size': len(self.job_queue),
            'gpu_hours_today': self.gpu_hours_today,
            'budget_percent': (self.gpu_hours_today / self.max_gpu_hours_daily) * 100,
            'scaling_events': len(self.scaling_history)
        }


def main():
    parser = argparse.ArgumentParser(description='GPU autoscaler rules')
    parser.add_argument('--max-hours', type=float, default=100, help='Max GPU-hours daily')
    parser.add_argument('--max-nodes', type=int, default=10)
    parser.add_argument('--demo', action='store_true')

    args = parser.parse_args()

    scaler = GPUAutoscaler({
        'max_gpu_hours_daily': args.max_hours,
        'max_nodes': args.max_nodes
    })

    if args.demo:
        # Simulate job submissions and processing
        import random

        for i in range(20):
            gpu_hours = random.uniform(1, 10)
            priority = random.choice(['low', 'normal', 'high'])
            scaler.add_job(f'job_{i}', gpu_hours, priority)

        logger.info(f"Queued 20 jobs, total demand: {scaler.get_queue_demand():.1f} GPU-hours")

        # Simulate over time
        for hour in range(10):
            result = scaler.scale()
            processed = scaler.process_jobs(1.0)
            scaler.pause_low_priority()

            logger.info(f"Hour {hour}: {result['action']} to {result['nodes']} nodes, "
                       f"processed {len(processed)} jobs, budget: {result['budget_remaining']:.1f}h remaining")

        stats = scaler.get_stats()
        logger.info(f"\n=== Final Stats ===")
        logger.info(f"GPU-hours used: {stats['gpu_hours_today']:.1f} ({stats['budget_percent']:.1f}%)")
        logger.info(f"Remaining queue: {stats['queue_size']}")
        logger.info(f"Scaling events: {stats['scaling_events']}")


if __name__ == '__main__':
    main()
