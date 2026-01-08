#!/usr/bin/env python3
"""
billing_and_quota_guard.py — Auto-shut on exceed + alerts.
Monitors cloud spend, triggers throttling, sends Slack/email alerts.
"""

import argparse
import json
import logging
import os
import time
from pathlib import Path
from datetime import datetime

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description='Billing and quota guard')
    parser.add_argument('--budget_limit', type=float, default=1000.0, help='Monthly budget USD')
    parser.add_argument('--gpu_hours_limit', type=float, default=500.0)
    parser.add_argument('--warning_threshold', type=float, default=0.8)
    parser.add_argument('--critical_threshold', type=float, default=0.95)
    parser.add_argument('--check_interval', type=int, default=300)
    parser.add_argument('--slack_webhook', type=str, default=os.getenv('SLACK_WEBHOOK'))
    parser.add_argument('--email', type=str, default=os.getenv('ALERT_EMAIL'))
    parser.add_argument('--dry_run', action='store_true')
    parser.add_argument('--simulate', action='store_true')
    return parser.parse_args()


class BillingGuard:
    """Monitors spending and enforces limits."""

    def __init__(self, budget_limit, gpu_hours_limit, warning_threshold, critical_threshold):
        self.budget_limit = budget_limit
        self.gpu_hours_limit = gpu_hours_limit
        self.warning_threshold = warning_threshold
        self.critical_threshold = critical_threshold

        self.current_spend = 0.0
        self.current_gpu_hours = 0.0
        self.alerts_sent = []
        self.throttling_active = False
        self.emergency_mode = False

    def get_current_usage(self, simulate=False):
        """Get current usage from cloud provider."""
        if simulate:
            # Simulate increasing usage
            self.current_spend += self.budget_limit * 0.01
            self.current_gpu_hours += self.gpu_hours_limit * 0.01
        else:
            # Would call AWS/GCP billing API
            pass

        return {
            'spend_usd': self.current_spend,
            'gpu_hours': self.current_gpu_hours,
            'spend_percent': self.current_spend / self.budget_limit,
            'gpu_percent': self.current_gpu_hours / self.gpu_hours_limit
        }

    def check_thresholds(self, usage):
        """Check usage against thresholds."""
        actions = []

        # Check spend
        spend_pct = usage['spend_percent']
        gpu_pct = usage['gpu_percent']

        if spend_pct >= self.critical_threshold or gpu_pct >= self.critical_threshold:
            if not self.emergency_mode:
                actions.append({
                    'level': 'critical',
                    'action': 'emergency_rollback',
                    'message': f"Critical: Spend at {spend_pct*100:.1f}%, GPU at {gpu_pct*100:.1f}%"
                })
                self.emergency_mode = True

        elif spend_pct >= self.warning_threshold or gpu_pct >= self.warning_threshold:
            if not self.throttling_active:
                actions.append({
                    'level': 'warning',
                    'action': 'enable_throttling',
                    'message': f"Warning: Spend at {spend_pct*100:.1f}%, GPU at {gpu_pct*100:.1f}%"
                })
                self.throttling_active = True

        return actions

    def apply_throttling(self):
        """Apply throttling rules."""
        rules = [
            'Reduce Optuna concurrency to 1',
            'Pause non-critical training jobs',
            'Reduce batch inference batch size',
            'Enable aggressive caching'
        ]
        logger.warning(f"Applying throttling: {rules}")
        return rules

    def apply_emergency_rollback(self):
        """Apply emergency cost reduction."""
        actions = [
            'Stop all training jobs',
            'Switch to on-demand fallbacks',
            'Disable prefetching',
            'Enable minimal mode'
        ]
        logger.critical(f"Emergency rollback: {actions}")
        return actions


def send_slack_alert(webhook_url, message, dry_run=False):
    """Send Slack alert."""
    if not webhook_url:
        return False

    if dry_run:
        logger.info(f"Would send Slack: {message}")
        return True

    try:
        import requests
        response = requests.post(webhook_url, json={'text': message})
        return response.ok
    except:
        return False


def send_email_alert(email, subject, message, dry_run=False):
    """Send email alert."""
    if not email:
        return False

    if dry_run:
        logger.info(f"Would email {email}: {subject}")
        return True

    # Placeholder - would use SMTP
    return False


def main():
    args = parse_args()

    guard = BillingGuard(
        args.budget_limit,
        args.gpu_hours_limit,
        args.warning_threshold,
        args.critical_threshold
    )

    logger.info(f"Starting billing guard")
    logger.info(f"Budget: ${args.budget_limit}, GPU limit: {args.gpu_hours_limit}h")
    logger.info(f"Warning: {args.warning_threshold*100}%, Critical: {args.critical_threshold*100}%")

    iteration = 0
    max_iterations = 20 if args.simulate else None

    while max_iterations is None or iteration < max_iterations:
        # Get usage
        usage = guard.get_current_usage(args.simulate)

        logger.info(f"Spend: ${usage['spend_usd']:.2f} ({usage['spend_percent']*100:.1f}%), "
                   f"GPU: {usage['gpu_hours']:.1f}h ({usage['gpu_percent']*100:.1f}%)")

        # Check thresholds
        actions = guard.check_thresholds(usage)

        for action in actions:
            # Apply action
            if action['action'] == 'enable_throttling':
                guard.apply_throttling()
            elif action['action'] == 'emergency_rollback':
                guard.apply_emergency_rollback()

            # Send alerts
            send_slack_alert(args.slack_webhook, action['message'], args.dry_run)
            send_email_alert(args.email, f"Komal Alert: {action['level'].upper()}",
                           action['message'], args.dry_run)

            guard.alerts_sent.append({
                'timestamp': datetime.now().isoformat(),
                **action
            })

        # Stop if emergency
        if guard.emergency_mode:
            logger.critical("Emergency mode activated, exiting")
            break

        iteration += 1

        if args.simulate:
            time.sleep(1)
        else:
            time.sleep(args.check_interval)

    # Final report
    report = {
        'final_spend': guard.current_spend,
        'final_gpu_hours': guard.current_gpu_hours,
        'throttling_active': guard.throttling_active,
        'emergency_mode': guard.emergency_mode,
        'alerts_sent': len(guard.alerts_sent)
    }

    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
