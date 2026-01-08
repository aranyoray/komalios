#!/usr/bin/env python3
"""
heavy_job_gatekeeper.py - Require manual override for expensive workloads

Prevents accidental cost spikes from heavy jobs.
"""

import argparse
import json
import hashlib
import time
import logging
from datetime import datetime
from typing import Dict, Optional

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class HeavyJobGatekeeper:
    """Gate heavy jobs requiring manual override."""

    def __init__(self, config: Dict):
        self.config = config

        # Thresholds
        self.gpu_hours_threshold = config.get('gpu_hours_threshold', 10)
        self.cost_threshold = config.get('cost_threshold', 25)
        self.gpu_cost_per_hour = config.get('gpu_cost_per_hour', 2.50)

        # Override keys (in production, would be from secure config)
        self.valid_override_keys = config.get('override_keys', ['admin_key_001', 'emergency_key'])

        # Audit log
        self.audit_log = []

    def classify_job(self, job_id: str, estimated_gpu_hours: float) -> str:
        """Classify job as light, medium, or heavy."""
        estimated_cost = estimated_gpu_hours * self.gpu_cost_per_hour

        if estimated_gpu_hours >= self.gpu_hours_threshold or estimated_cost >= self.cost_threshold:
            return 'heavy'
        elif estimated_gpu_hours >= self.gpu_hours_threshold / 2:
            return 'medium'
        return 'light'

    def check_job(self, job_id: str, estimated_gpu_hours: float, override_key: Optional[str] = None) -> Dict:
        """Check if job is allowed to run."""
        classification = self.classify_job(job_id, estimated_gpu_hours)
        estimated_cost = estimated_gpu_hours * self.gpu_cost_per_hour

        result = {
            'job_id': job_id,
            'classification': classification,
            'estimated_gpu_hours': estimated_gpu_hours,
            'estimated_cost': estimated_cost,
            'timestamp': datetime.now().isoformat()
        }

        if classification == 'heavy':
            if override_key:
                # Verify override key
                if override_key in self.valid_override_keys:
                    result['allowed'] = True
                    result['reason'] = 'Heavy job approved with override key'
                    result['override_used'] = True
                else:
                    result['allowed'] = False
                    result['reason'] = 'Invalid override key'
            else:
                result['allowed'] = False
                result['reason'] = f'Heavy job requires override key (>{self.gpu_hours_threshold}h or >${self.cost_threshold})'
        else:
            result['allowed'] = True
            result['reason'] = f'{classification.title()} job auto-approved'

        # Audit
        self.audit_log.append(result)

        return result

    def generate_override_request(self, job_id: str, estimated_gpu_hours: float) -> Dict:
        """Generate an override request for approval."""
        estimated_cost = estimated_gpu_hours * self.gpu_cost_per_hour

        request = {
            'request_id': hashlib.md5(f"{job_id}{time.time()}".encode()).hexdigest()[:8],
            'job_id': job_id,
            'estimated_gpu_hours': estimated_gpu_hours,
            'estimated_cost': estimated_cost,
            'created': datetime.now().isoformat(),
            'status': 'pending',
            'message': f"Job {job_id} requires {estimated_gpu_hours:.1f} GPU-hours (${estimated_cost:.2f}). "
                      f"Override key required to proceed."
        }

        return request

    def get_audit_summary(self) -> Dict:
        """Get audit summary."""
        total = len(self.audit_log)
        allowed = sum(1 for e in self.audit_log if e.get('allowed'))
        blocked = total - allowed
        overrides = sum(1 for e in self.audit_log if e.get('override_used'))

        blocked_cost = sum(
            e['estimated_cost'] for e in self.audit_log
            if not e.get('allowed')
        )

        return {
            'total_requests': total,
            'allowed': allowed,
            'blocked': blocked,
            'overrides_used': overrides,
            'cost_prevented': blocked_cost
        }


def main():
    parser = argparse.ArgumentParser(description='Heavy job gatekeeper')
    parser.add_argument('--gpu-hours-threshold', type=float, default=10)
    parser.add_argument('--cost-threshold', type=float, default=25)
    parser.add_argument('--override-key', type=str, help='Override key for heavy jobs')
    parser.add_argument('--demo', action='store_true')

    args = parser.parse_args()

    gatekeeper = HeavyJobGatekeeper({
        'gpu_hours_threshold': args.gpu_hours_threshold,
        'cost_threshold': args.cost_threshold
    })

    if args.demo:
        # Test various jobs
        jobs = [
            ('quick_eval', 2),
            ('medium_train', 8),
            ('heavy_hpo', 50),
            ('overnight_train', 100)
        ]

        for job_id, hours in jobs:
            result = gatekeeper.check_job(job_id, hours)
            status = 'ALLOWED' if result['allowed'] else 'BLOCKED'
            logger.info(f"{job_id} ({hours}h, ${result['estimated_cost']:.0f}): {status} - {result['reason']}")

        # Try with override
        result = gatekeeper.check_job('heavy_hpo', 50, 'admin_key_001')
        logger.info(f"heavy_hpo with override: {'ALLOWED' if result['allowed'] else 'BLOCKED'}")

        # Summary
        summary = gatekeeper.get_audit_summary()
        logger.info(f"\n=== Gatekeeper Summary ===")
        logger.info(f"Allowed: {summary['allowed']}, Blocked: {summary['blocked']}")
        logger.info(f"Cost prevented: ${summary['cost_prevented']:.2f}")
        logger.info(f"Overrides used: {summary['overrides_used']}")


if __name__ == '__main__':
    main()
