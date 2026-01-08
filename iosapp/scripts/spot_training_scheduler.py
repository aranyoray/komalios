#!/usr/bin/env python3
"""
spot_training_scheduler.py — Schedule training on spot/preemptible VMs.
Checkpointing, preemption monitoring, migration to on-demand.
"""

import argparse
import json
import logging
import time
import signal
import threading
from pathlib import Path
from datetime import datetime

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description='Spot instance training scheduler')
    parser.add_argument('--training_script', type=str, required=True)
    parser.add_argument('--checkpoint_dir', type=str, default='./checkpoints')
    parser.add_argument('--checkpoint_interval', type=int, default=300, help='Seconds')
    parser.add_argument('--spot_price', type=float, default=0.50, help='Spot price per hour')
    parser.add_argument('--ondemand_price', type=float, default=2.00, help='On-demand price per hour')
    parser.add_argument('--max_preemption_risk', type=float, default=0.3)
    parser.add_argument('--dry_run', action='store_true')
    return parser.parse_args()


class SpotTrainingScheduler:
    """Manages training jobs on spot instances."""

    def __init__(self, checkpoint_dir, checkpoint_interval):
        self.checkpoint_dir = Path(checkpoint_dir)
        self.checkpoint_dir.mkdir(parents=True, exist_ok=True)
        self.checkpoint_interval = checkpoint_interval

        self.is_spot = True
        self.preemption_signal = False
        self.training_active = False
        self.total_spot_hours = 0
        self.total_ondemand_hours = 0
        self.start_time = None

        # Set up signal handlers for preemption
        signal.signal(signal.SIGTERM, self._handle_preemption)
        signal.signal(signal.SIGINT, self._handle_preemption)

    def _handle_preemption(self, signum, frame):
        """Handle preemption signal."""
        logger.warning("Preemption signal received!")
        self.preemption_signal = True

    def get_preemption_risk(self):
        """Estimate preemption risk (simulated)."""
        # In production, would query cloud provider APIs
        import random
        base_risk = 0.1
        # Risk increases over time
        if self.start_time:
            hours_running = (time.time() - self.start_time) / 3600
            base_risk += hours_running * 0.02
        return min(base_risk + random.uniform(0, 0.1), 1.0)

    def save_checkpoint(self, epoch, state):
        """Save training checkpoint."""
        checkpoint = {
            'epoch': epoch,
            'state': state,
            'timestamp': datetime.now().isoformat(),
            'is_spot': self.is_spot
        }
        path = self.checkpoint_dir / f'checkpoint_epoch_{epoch}.json'
        with open(path, 'w') as f:
            json.dump(checkpoint, f)
        logger.info(f"Saved checkpoint: {path}")

    def load_latest_checkpoint(self):
        """Load most recent checkpoint."""
        checkpoints = sorted(self.checkpoint_dir.glob('checkpoint_*.json'))
        if not checkpoints:
            return None
        with open(checkpoints[-1]) as f:
            return json.load(f)

    def migrate_to_ondemand(self):
        """Migrate from spot to on-demand instance."""
        logger.info("Migrating to on-demand instance...")
        self.is_spot = False
        # In production, would:
        # 1. Save checkpoint
        # 2. Request on-demand instance
        # 3. Transfer checkpoint
        # 4. Resume training

    def estimate_cost_savings(self, spot_price, ondemand_price):
        """Estimate cost savings from spot usage."""
        spot_cost = self.total_spot_hours * spot_price
        ondemand_cost = self.total_ondemand_hours * ondemand_price
        actual_cost = spot_cost + ondemand_cost

        hypothetical_ondemand = (self.total_spot_hours + self.total_ondemand_hours) * ondemand_price
        savings = hypothetical_ondemand - actual_cost
        savings_percent = (savings / hypothetical_ondemand * 100) if hypothetical_ondemand > 0 else 0

        return {
            'spot_hours': self.total_spot_hours,
            'ondemand_hours': self.total_ondemand_hours,
            'actual_cost': actual_cost,
            'hypothetical_cost': hypothetical_ondemand,
            'savings': savings,
            'savings_percent': round(savings_percent, 1)
        }


def run_training(scheduler, training_script, args):
    """Run training with checkpointing and preemption handling."""
    scheduler.start_time = time.time()
    scheduler.training_active = True

    # Load checkpoint if exists
    checkpoint = scheduler.load_latest_checkpoint()
    start_epoch = checkpoint['epoch'] + 1 if checkpoint else 0

    logger.info(f"Starting training from epoch {start_epoch}")

    # Simulate training loop
    num_epochs = 100
    last_checkpoint = time.time()

    for epoch in range(start_epoch, num_epochs):
        if not scheduler.training_active:
            break

        # Check preemption
        if scheduler.preemption_signal:
            scheduler.save_checkpoint(epoch, {'progress': epoch / num_epochs})
            logger.warning("Training interrupted by preemption")
            break

        # Check preemption risk
        risk = scheduler.get_preemption_risk()
        if risk > args.max_preemption_risk and scheduler.is_spot:
            logger.warning(f"High preemption risk ({risk:.2f}), migrating to on-demand")
            scheduler.save_checkpoint(epoch, {'progress': epoch / num_epochs})
            scheduler.migrate_to_ondemand()

        # Simulate epoch training
        if not args.dry_run:
            time.sleep(0.1)  # Simulate work

        # Periodic checkpoint
        if time.time() - last_checkpoint > scheduler.checkpoint_interval:
            scheduler.save_checkpoint(epoch, {'progress': epoch / num_epochs})
            last_checkpoint = time.time()

        # Track usage
        elapsed_hours = (time.time() - scheduler.start_time) / 3600
        if scheduler.is_spot:
            scheduler.total_spot_hours = elapsed_hours
        else:
            scheduler.total_ondemand_hours = elapsed_hours - scheduler.total_spot_hours

        if (epoch + 1) % 10 == 0:
            logger.info(f"Epoch {epoch + 1}/{num_epochs}")

    # Final checkpoint
    scheduler.save_checkpoint(epoch, {'progress': 1.0, 'completed': True})
    scheduler.training_active = False


def main():
    args = parse_args()

    scheduler = SpotTrainingScheduler(args.checkpoint_dir, args.checkpoint_interval)

    logger.info("Starting spot training scheduler")
    logger.info(f"Spot price: ${args.spot_price}/hr, On-demand: ${args.ondemand_price}/hr")

    # Run training
    run_training(scheduler, args.training_script, args)

    # Report savings
    savings = scheduler.estimate_cost_savings(args.spot_price, args.ondemand_price)
    logger.info("Training complete")
    print(json.dumps(savings, indent=2))


if __name__ == '__main__':
    main()
