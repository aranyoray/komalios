#!/usr/bin/env python3
"""
parental_override_lock.py - Enforce time limits, breaks, and session quotas

Stores usage summaries for parental review.
"""

import argparse
import json
import time
import logging
from datetime import datetime, date, timedelta
from pathlib import Path
from typing import Dict, Optional

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class ParentalOverrideLock:
    """Enforce parental controls and limits."""

    def __init__(self, config: Dict):
        self.config = config
        self.state_file = Path(config.get('state_file', 'parental_state.json'))

        # Limits
        self.daily_limit_minutes = config.get('daily_limit_minutes', 60)
        self.session_limit_minutes = config.get('session_limit_minutes', 20)
        self.break_duration_minutes = config.get('break_duration_minutes', 5)
        self.sessions_per_day = config.get('sessions_per_day', 5)

        # Load state
        self.state = self._load_state()

    def _load_state(self) -> Dict:
        """Load state from file."""
        if self.state_file.exists():
            with open(self.state_file, 'r') as f:
                return json.load(f)

        return {
            'daily_usage': {},
            'session_history': [],
            'current_session': None,
            'last_break': None,
            'override_active': False,
            'override_expires': None
        }

    def _save_state(self):
        """Save state to file."""
        with open(self.state_file, 'w') as f:
            json.dump(self.state, f, indent=2)

    def _today_key(self) -> str:
        return date.today().isoformat()

    def get_daily_usage(self) -> float:
        """Get today's usage in minutes."""
        return self.state['daily_usage'].get(self._today_key(), 0)

    def get_sessions_today(self) -> int:
        """Get number of sessions today."""
        today = self._today_key()
        return sum(
            1 for s in self.state['session_history']
            if s.get('date') == today
        )

    def can_start_session(self) -> Dict:
        """Check if a new session can be started."""
        # Check override
        if self._check_override():
            return {'allowed': True, 'reason': 'Override active'}

        # Check daily limit
        daily_usage = self.get_daily_usage()
        if daily_usage >= self.daily_limit_minutes:
            return {
                'allowed': False,
                'reason': f'Daily limit reached ({self.daily_limit_minutes} min)',
                'usage': daily_usage
            }

        # Check session count
        sessions = self.get_sessions_today()
        if sessions >= self.sessions_per_day:
            return {
                'allowed': False,
                'reason': f'Maximum sessions reached ({self.sessions_per_day})',
                'sessions': sessions
            }

        # Check break requirement
        if self.state['last_break']:
            last_break = datetime.fromisoformat(self.state['last_break'])
            since_break = (datetime.now() - last_break).total_seconds() / 60

            if since_break < self.break_duration_minutes:
                remaining = self.break_duration_minutes - since_break
                return {
                    'allowed': False,
                    'reason': f'Break required ({remaining:.0f} min remaining)',
                    'break_remaining': remaining
                }

        return {
            'allowed': True,
            'remaining_daily': self.daily_limit_minutes - daily_usage,
            'sessions_remaining': self.sessions_per_day - sessions
        }

    def start_session(self) -> Dict:
        """Start a new session."""
        check = self.can_start_session()
        if not check['allowed']:
            return check

        self.state['current_session'] = {
            'start': datetime.now().isoformat(),
            'date': self._today_key()
        }

        self._save_state()
        logger.info("Session started")

        return {
            'started': True,
            'max_duration': self.session_limit_minutes
        }

    def end_session(self) -> Dict:
        """End the current session."""
        if not self.state['current_session']:
            return {'error': 'No active session'}

        start = datetime.fromisoformat(self.state['current_session']['start'])
        duration = (datetime.now() - start).total_seconds() / 60

        # Update daily usage
        today = self._today_key()
        self.state['daily_usage'][today] = self.state['daily_usage'].get(today, 0) + duration

        # Record session
        session = {
            'date': today,
            'start': self.state['current_session']['start'],
            'end': datetime.now().isoformat(),
            'duration': duration
        }
        self.state['session_history'].append(session)

        # Require break
        self.state['last_break'] = datetime.now().isoformat()
        self.state['current_session'] = None

        self._save_state()

        logger.info(f"Session ended: {duration:.1f} minutes")

        return {
            'ended': True,
            'duration': duration,
            'daily_total': self.state['daily_usage'][today]
        }

    def check_session_limit(self) -> Dict:
        """Check if current session should end."""
        if not self.state['current_session']:
            return {'active': False}

        start = datetime.fromisoformat(self.state['current_session']['start'])
        elapsed = (datetime.now() - start).total_seconds() / 60

        if elapsed >= self.session_limit_minutes:
            return {
                'active': True,
                'should_end': True,
                'elapsed': elapsed,
                'reason': f'Session limit reached ({self.session_limit_minutes} min)'
            }

        return {
            'active': True,
            'should_end': False,
            'elapsed': elapsed,
            'remaining': self.session_limit_minutes - elapsed
        }

    def _check_override(self) -> bool:
        """Check if override is active."""
        if not self.state['override_active']:
            return False

        if self.state['override_expires']:
            expires = datetime.fromisoformat(self.state['override_expires'])
            if datetime.now() > expires:
                self.state['override_active'] = False
                self._save_state()
                return False

        return True

    def activate_override(self, duration_minutes: float = 30, pin: str = None):
        """Activate parental override."""
        # Would verify PIN in production
        self.state['override_active'] = True
        self.state['override_expires'] = (
            datetime.now() + timedelta(minutes=duration_minutes)
        ).isoformat()
        self._save_state()

        logger.info(f"Override activated for {duration_minutes} minutes")

    def get_usage_summary(self, days: int = 7) -> Dict:
        """Get usage summary for parental review."""
        summaries = []

        for i in range(days):
            day = (date.today() - timedelta(days=i)).isoformat()
            usage = self.state['daily_usage'].get(day, 0)
            sessions = [s for s in self.state['session_history'] if s.get('date') == day]

            summaries.append({
                'date': day,
                'total_minutes': usage,
                'sessions': len(sessions),
                'avg_session': usage / len(sessions) if sessions else 0
            })

        return {
            'period_days': days,
            'daily_summaries': summaries,
            'total_usage': sum(s['total_minutes'] for s in summaries),
            'total_sessions': sum(s['sessions'] for s in summaries)
        }


def main():
    parser = argparse.ArgumentParser(description='Parental override lock')
    parser.add_argument('--daily-limit', type=int, default=60)
    parser.add_argument('--session-limit', type=int, default=20)
    parser.add_argument('--override', type=int, help='Activate override for N minutes')
    parser.add_argument('--summary', action='store_true', help='Show usage summary')
    parser.add_argument('--demo', action='store_true')

    args = parser.parse_args()

    lock = ParentalOverrideLock({
        'daily_limit_minutes': args.daily_limit,
        'session_limit_minutes': args.session_limit
    })

    if args.override:
        lock.activate_override(args.override)

    if args.summary:
        summary = lock.get_usage_summary()
        logger.info(f"\n=== Usage Summary ===")
        logger.info(f"Total: {summary['total_usage']:.0f} min, {summary['total_sessions']} sessions")
        for day in summary['daily_summaries'][:7]:
            logger.info(f"  {day['date']}: {day['total_minutes']:.0f} min, {day['sessions']} sessions")

    if args.demo:
        # Simulate a session
        result = lock.start_session()
        if result.get('started'):
            logger.info("Started demo session")

            # Simulate some time
            time.sleep(2)

            # Check limit
            check = lock.check_session_limit()
            logger.info(f"Session check: {check['remaining']:.1f} min remaining")

            # End session
            result = lock.end_session()
            logger.info(f"Session ended: {result['duration']:.1f} min")

            # Try to start another immediately (should need break)
            result = lock.can_start_session()
            logger.info(f"Can start new session: {result['allowed']} - {result.get('reason', 'OK')}")
        else:
            logger.info(f"Cannot start session: {result['reason']}")


if __name__ == '__main__':
    main()
