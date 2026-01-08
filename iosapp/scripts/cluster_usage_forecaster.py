#!/usr/bin/env python3
"""
cluster_usage_forecaster.py - Forecast GPU/CPU usage and warn of overspend

Uses time-series models to predict resource usage and costs.
"""

import argparse
import json
import numpy as np
import logging
from datetime import datetime, timedelta
from typing import Dict, List

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class UsageForecaster:
    """Forecast cluster usage using simple time-series models."""

    def __init__(self, config: Dict):
        self.config = config
        self.history = []

        # Cost rates
        self.gpu_cost_per_hour = config.get('gpu_cost_per_hour', 2.50)
        self.cpu_cost_per_hour = config.get('cpu_cost_per_hour', 0.10)

        # Budgets
        self.daily_budget = config.get('daily_budget', 500)
        self.monthly_budget = config.get('monthly_budget', 10000)

    def record_usage(self, gpu_hours: float, cpu_hours: float, timestamp: datetime = None):
        """Record usage data point."""
        if timestamp is None:
            timestamp = datetime.now()

        cost = gpu_hours * self.gpu_cost_per_hour + cpu_hours * self.cpu_cost_per_hour

        self.history.append({
            'timestamp': timestamp.isoformat(),
            'gpu_hours': gpu_hours,
            'cpu_hours': cpu_hours,
            'cost': cost
        })

    def forecast_simple(self, hours_ahead: int = 24) -> Dict:
        """Simple moving average forecast."""
        if len(self.history) < 3:
            return {'error': 'Insufficient data'}

        # Use last N hours as basis
        recent = self.history[-min(len(self.history), 24):]

        avg_gpu = np.mean([h['gpu_hours'] for h in recent])
        avg_cpu = np.mean([h['cpu_hours'] for h in recent])
        avg_cost = np.mean([h['cost'] for h in recent])

        # Simple linear trend
        if len(recent) >= 2:
            gpu_trend = (recent[-1]['gpu_hours'] - recent[0]['gpu_hours']) / len(recent)
            cost_trend = (recent[-1]['cost'] - recent[0]['cost']) / len(recent)
        else:
            gpu_trend = 0
            cost_trend = 0

        forecasted_cost = (avg_cost + cost_trend * hours_ahead / 2) * hours_ahead

        return {
            'hours_ahead': hours_ahead,
            'forecasted_gpu_hours': avg_gpu * hours_ahead,
            'forecasted_cpu_hours': avg_cpu * hours_ahead,
            'forecasted_cost': forecasted_cost,
            'trend': 'increasing' if cost_trend > 0 else 'decreasing' if cost_trend < 0 else 'stable'
        }

    def check_budget_alerts(self) -> List[Dict]:
        """Check for budget alerts."""
        alerts = []

        # Calculate current day/month spend
        now = datetime.now()
        today_start = now.replace(hour=0, minute=0, second=0)
        month_start = now.replace(day=1, hour=0, minute=0, second=0)

        today_cost = sum(
            h['cost'] for h in self.history
            if datetime.fromisoformat(h['timestamp']) >= today_start
        )

        month_cost = sum(
            h['cost'] for h in self.history
            if datetime.fromisoformat(h['timestamp']) >= month_start
        )

        # Daily alerts
        if today_cost > self.daily_budget * 0.8:
            alerts.append({
                'type': 'daily_budget',
                'severity': 'critical' if today_cost > self.daily_budget else 'warning',
                'message': f"Daily spend ${today_cost:.2f} is {today_cost/self.daily_budget*100:.0f}% of budget"
            })

        # Monthly alerts
        days_in_month = 30
        days_elapsed = now.day
        projected_monthly = month_cost * (days_in_month / days_elapsed)

        if projected_monthly > self.monthly_budget:
            alerts.append({
                'type': 'monthly_projected',
                'severity': 'warning',
                'message': f"Projected monthly spend ${projected_monthly:.2f} exceeds budget ${self.monthly_budget}"
            })

        # Forecast alerts
        forecast = self.forecast_simple(24)
        if 'forecasted_cost' in forecast:
            if today_cost + forecast['forecasted_cost'] > self.daily_budget * 1.5:
                alerts.append({
                    'type': 'forecast',
                    'severity': 'info',
                    'message': f"24h forecast: ${forecast['forecasted_cost']:.2f} additional spend"
                })

        return alerts

    def get_summary(self) -> Dict:
        """Get usage summary."""
        if not self.history:
            return {'empty': True}

        total_cost = sum(h['cost'] for h in self.history)
        total_gpu = sum(h['gpu_hours'] for h in self.history)

        return {
            'total_records': len(self.history),
            'total_cost': total_cost,
            'total_gpu_hours': total_gpu,
            'avg_cost_per_record': total_cost / len(self.history)
        }


def main():
    parser = argparse.ArgumentParser(description='Cluster usage forecaster')
    parser.add_argument('--daily-budget', type=float, default=500)
    parser.add_argument('--monthly-budget', type=float, default=10000)
    parser.add_argument('--demo', action='store_true')

    args = parser.parse_args()

    forecaster = UsageForecaster({
        'daily_budget': args.daily_budget,
        'monthly_budget': args.monthly_budget
    })

    if args.demo:
        # Generate synthetic usage history
        now = datetime.now()

        for i in range(48):  # 48 hours
            timestamp = now - timedelta(hours=48-i)

            # Simulate varying usage
            base_gpu = 5 + i * 0.1  # Increasing trend
            gpu_hours = base_gpu + np.random.randn() * 2
            cpu_hours = gpu_hours * 10 + np.random.randn() * 5

            forecaster.record_usage(max(0, gpu_hours), max(0, cpu_hours), timestamp)

        # Forecast
        forecast = forecaster.forecast_simple(24)
        logger.info(f"\n=== 24h Forecast ===")
        logger.info(f"GPU hours: {forecast['forecasted_gpu_hours']:.1f}")
        logger.info(f"Cost: ${forecast['forecasted_cost']:.2f}")
        logger.info(f"Trend: {forecast['trend']}")

        # Alerts
        alerts = forecaster.check_budget_alerts()
        if alerts:
            logger.info(f"\n=== Alerts ===")
            for alert in alerts:
                logger.warning(f"[{alert['severity'].upper()}] {alert['message']}")

        # Summary
        summary = forecaster.get_summary()
        logger.info(f"\n=== Summary ===")
        logger.info(f"Total cost: ${summary['total_cost']:.2f}")
        logger.info(f"Total GPU hours: {summary['total_gpu_hours']:.1f}")


if __name__ == '__main__':
    main()
