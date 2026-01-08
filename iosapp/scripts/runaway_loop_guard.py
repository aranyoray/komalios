#!/usr/bin/env python3
"""
runaway_loop_guard.py - Detect and stop runaway loops in scripts

Instruments loops, limits iterations, detects hangs, and aborts safely.
"""

import argparse
import json
import time
import signal
import logging
from datetime import datetime
from typing import Dict, Callable, Any
from functools import wraps

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class LoopGuard:
    """Guard against runaway loops."""

    def __init__(self, config: Dict):
        self.config = config
        self.max_iterations = config.get('max_iterations', 10000)
        self.max_time_seconds = config.get('max_time_seconds', 60)
        self.check_interval = config.get('check_interval', 100)

        self.active_guards = {}
        self.violations = []

    def guard(self, name: str = None, max_iter: int = None, max_time: float = None):
        """Decorator to guard a loop-containing function."""
        def decorator(func):
            @wraps(func)
            def wrapper(*args, **kwargs):
                guard_name = name or func.__name__
                guard_max_iter = max_iter or self.max_iterations
                guard_max_time = max_time or self.max_time_seconds

                guard_state = {
                    'iterations': 0,
                    'start_time': time.time(),
                    'max_iter': guard_max_iter,
                    'max_time': guard_max_time
                }

                self.active_guards[guard_name] = guard_state

                try:
                    result = func(*args, **kwargs)
                    return result
                finally:
                    del self.active_guards[guard_name]

            return wrapper
        return decorator

    def check_iteration(self, guard_name: str) -> bool:
        """Check if iteration should continue. Call this in your loop."""
        if guard_name not in self.active_guards:
            return True

        state = self.active_guards[guard_name]
        state['iterations'] += 1

        # Check interval
        if state['iterations'] % self.check_interval != 0:
            return True

        # Check iterations
        if state['iterations'] > state['max_iter']:
            self._record_violation(guard_name, 'max_iterations',
                                  f"Exceeded {state['max_iter']} iterations")
            return False

        # Check time
        elapsed = time.time() - state['start_time']
        if elapsed > state['max_time']:
            self._record_violation(guard_name, 'max_time',
                                  f"Exceeded {state['max_time']}s")
            return False

        return True

    def _record_violation(self, guard_name: str, violation_type: str, message: str):
        """Record a loop violation."""
        violation = {
            'guard': guard_name,
            'type': violation_type,
            'message': message,
            'timestamp': datetime.now().isoformat()
        }

        self.violations.append(violation)
        logger.warning(f"Loop violation [{guard_name}]: {message}")

    def get_stats(self) -> Dict:
        """Get guard statistics."""
        return {
            'active_guards': len(self.active_guards),
            'total_violations': len(self.violations),
            'violations': self.violations[-10:]
        }


class TimeoutGuard:
    """Guard functions with timeout."""

    def __init__(self, timeout_seconds: float = 30):
        self.timeout = timeout_seconds
        self.timed_out = False

    def __enter__(self):
        self.timed_out = False

        def handler(signum, frame):
            self.timed_out = True
            raise TimeoutError(f"Operation timed out after {self.timeout}s")

        signal.signal(signal.SIGALRM, handler)
        signal.alarm(int(self.timeout))
        return self

    def __exit__(self, *args):
        signal.alarm(0)


def guarded_loop(iterable, guard: LoopGuard, name: str):
    """Generator that wraps an iterable with loop guard checks."""
    for item in iterable:
        if not guard.check_iteration(name):
            logger.warning(f"Loop '{name}' terminated by guard")
            break
        yield item


def main():
    parser = argparse.ArgumentParser(description='Runaway loop guard')
    parser.add_argument('--max-iter', type=int, default=10000)
    parser.add_argument('--max-time', type=float, default=60)
    parser.add_argument('--demo', action='store_true')

    args = parser.parse_args()

    guard = LoopGuard({
        'max_iterations': args.max_iter,
        'max_time_seconds': args.max_time
    })

    if args.demo:
        # Demo 1: Controlled loop
        logger.info("Demo 1: Normal loop with guard")

        @guard.guard('normal_loop', max_iter=1000)
        def normal_processing():
            count = 0
            for i in guarded_loop(range(500), guard, 'normal_loop'):
                count += 1
                time.sleep(0.001)
            return count

        result = normal_processing()
        logger.info(f"Normal loop completed: {result} iterations")

        # Demo 2: Runaway loop (would be stopped)
        logger.info("\nDemo 2: Runaway loop (guarded)")

        @guard.guard('runaway_loop', max_iter=100)
        def runaway_processing():
            count = 0
            for i in guarded_loop(range(1000000), guard, 'runaway_loop'):
                count += 1
            return count

        result = runaway_processing()
        logger.info(f"Runaway loop stopped at: {result} iterations")

        # Demo 3: Time-limited loop
        logger.info("\nDemo 3: Time-limited loop")

        @guard.guard('time_limited', max_time=2.0)
        def slow_processing():
            count = 0
            while guard.check_iteration('time_limited'):
                count += 1
                time.sleep(0.1)
            return count

        result = slow_processing()
        logger.info(f"Time-limited loop stopped at: {result} iterations")

        # Stats
        stats = guard.get_stats()
        logger.info(f"\n=== Guard Stats ===")
        logger.info(f"Violations: {stats['total_violations']}")
        for v in stats['violations']:
            logger.info(f"  {v['guard']}: {v['message']}")


if __name__ == '__main__':
    main()
