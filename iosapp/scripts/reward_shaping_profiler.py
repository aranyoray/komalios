#!/usr/bin/env python3
"""
reward_shaping_profiler.py - Profile reward computation cost for RL optimization

Calculates cost-per-training-task by measuring reward shaping overhead.
"""

import argparse
import json
import time
import numpy as np
import logging
from typing import Dict, List, Callable
from functools import wraps

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


def timed(func):
    """Decorator to time function execution."""
    @wraps(func)
    def wrapper(*args, **kwargs):
        start = time.perf_counter()
        result = func(*args, **kwargs)
        elapsed = time.perf_counter() - start
        return result, elapsed
    return wrapper


class RewardFunction:
    """Base reward function with profiling."""

    def __init__(self, name: str):
        self.name = name
        self.call_count = 0
        self.total_time = 0.0

    def compute(self, state: Dict, action: int, next_state: Dict) -> float:
        raise NotImplementedError

    def __call__(self, state, action, next_state):
        start = time.perf_counter()
        reward = self.compute(state, action, next_state)
        self.total_time += time.perf_counter() - start
        self.call_count += 1
        return reward

    def get_stats(self) -> Dict:
        return {
            'name': self.name,
            'calls': self.call_count,
            'total_ms': self.total_time * 1000,
            'avg_ms': (self.total_time / self.call_count * 1000) if self.call_count > 0 else 0
        }


class AttentionReward(RewardFunction):
    """Reward based on attention metrics."""

    def __init__(self):
        super().__init__('attention')

    def compute(self, state, action, next_state):
        attention = next_state.get('attention', 0.5)
        prev_attention = state.get('attention', 0.5)
        return (attention - prev_attention) * 10 + attention


class EngagementReward(RewardFunction):
    """Reward based on engagement with potential shaping."""

    def __init__(self):
        super().__init__('engagement')

    def compute(self, state, action, next_state):
        engagement = next_state.get('engagement', 0.5)
        # Expensive shaping: compute moving average
        history = next_state.get('engagement_history', [engagement])
        shaped = np.mean(history[-10:]) * engagement
        return shaped * 5


class EmotionRegulationReward(RewardFunction):
    """Reward for emotion regulation (expensive computation)."""

    def __init__(self):
        super().__init__('emotion_regulation')

    def compute(self, state, action, next_state):
        emotions = next_state.get('emotions', np.zeros(7))
        prev_emotions = state.get('emotions', np.zeros(7))

        # Expensive: compute KL divergence
        target = np.array([0.3, 0.3, 0.1, 0.05, 0.1, 0.05, 0.1])
        kl = np.sum(emotions * np.log((emotions + 1e-10) / (target + 1e-10)))

        # Compute stability
        stability = 1.0 / (np.var(emotions - prev_emotions) + 0.1)

        return -kl + stability


class RewardShapingProfiler:
    """Profile reward computation costs."""

    def __init__(self, config: Dict):
        self.config = config
        self.reward_functions = {}
        self.task_costs = []

    def register_reward(self, reward_fn: RewardFunction):
        """Register a reward function."""
        self.reward_functions[reward_fn.name] = reward_fn

    def compute_combined_reward(self, state: Dict, action: int, next_state: Dict) -> float:
        """Compute combined reward from all functions."""
        total = 0.0
        weights = self.config.get('weights', {})

        for name, fn in self.reward_functions.items():
            weight = weights.get(name, 1.0)
            total += weight * fn(state, action, next_state)

        return total

    def profile_task(self, task_steps: int = 100) -> Dict:
        """Profile a complete training task."""
        start = time.perf_counter()

        state = {
            'attention': 0.5,
            'engagement': 0.5,
            'emotions': np.random.dirichlet(np.ones(7)),
            'engagement_history': []
        }

        total_reward = 0.0

        for step in range(task_steps):
            action = np.random.randint(0, 5)

            # Simulate next state
            next_state = {
                'attention': np.clip(state['attention'] + np.random.randn() * 0.1, 0, 1),
                'engagement': np.clip(state['engagement'] + np.random.randn() * 0.1, 0, 1),
                'emotions': np.random.dirichlet(np.ones(7)),
                'engagement_history': state['engagement_history'] + [state['engagement']]
            }

            reward = self.compute_combined_reward(state, action, next_state)
            total_reward += reward
            state = next_state

        elapsed = time.perf_counter() - start

        cost = {
            'steps': task_steps,
            'total_time_ms': elapsed * 1000,
            'time_per_step_ms': elapsed / task_steps * 1000,
            'total_reward': total_reward
        }

        self.task_costs.append(cost)
        return cost

    def get_optimization_suggestions(self) -> List[Dict]:
        """Get suggestions for optimizing reward computation."""
        suggestions = []

        stats = self.get_stats()

        for fn_stats in stats['reward_functions']:
            if fn_stats['avg_ms'] > 1.0:
                suggestions.append({
                    'function': fn_stats['name'],
                    'issue': 'High computation time',
                    'avg_ms': fn_stats['avg_ms'],
                    'suggestions': [
                        'Cache intermediate results',
                        'Use vectorized operations',
                        'Reduce history window size',
                        'Consider approximation'
                    ]
                })

        return suggestions

    def get_stats(self) -> Dict:
        """Get profiling statistics."""
        fn_stats = [fn.get_stats() for fn in self.reward_functions.values()]

        return {
            'reward_functions': fn_stats,
            'task_costs': self.task_costs,
            'avg_task_time_ms': np.mean([t['total_time_ms'] for t in self.task_costs]) if self.task_costs else 0
        }


def main():
    parser = argparse.ArgumentParser(description='Reward shaping profiler')
    parser.add_argument('--tasks', type=int, default=10, help='Number of tasks to profile')
    parser.add_argument('--steps', type=int, default=100, help='Steps per task')

    args = parser.parse_args()

    config = {
        'weights': {
            'attention': 1.0,
            'engagement': 1.5,
            'emotion_regulation': 0.5
        }
    }

    profiler = RewardShapingProfiler(config)

    # Register reward functions
    profiler.register_reward(AttentionReward())
    profiler.register_reward(EngagementReward())
    profiler.register_reward(EmotionRegulationReward())

    # Profile tasks
    logger.info(f"Profiling {args.tasks} tasks with {args.steps} steps each")

    for i in range(args.tasks):
        cost = profiler.profile_task(args.steps)
        logger.info(f"Task {i+1}: {cost['total_time_ms']:.1f}ms, {cost['time_per_step_ms']:.3f}ms/step")

    # Results
    stats = profiler.get_stats()

    logger.info(f"\n=== Reward Function Costs ===")
    for fn in stats['reward_functions']:
        logger.info(f"{fn['name']}: {fn['avg_ms']:.3f}ms avg ({fn['calls']} calls)")

    logger.info(f"\nAvg task time: {stats['avg_task_time_ms']:.1f}ms")

    # Suggestions
    suggestions = profiler.get_optimization_suggestions()
    if suggestions:
        logger.info(f"\n=== Optimization Suggestions ===")
        for s in suggestions:
            logger.info(f"{s['function']}: {s['issue']} ({s['avg_ms']:.2f}ms)")
            for tip in s['suggestions'][:2]:
                logger.info(f"  - {tip}")


if __name__ == '__main__':
    main()
