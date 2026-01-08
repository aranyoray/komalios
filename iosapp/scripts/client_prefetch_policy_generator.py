#!/usr/bin/env python3
"""
client_prefetch_policy_generator.py — Generate prefetch budgets per device.
Based on battery, network type, user settings.
"""

import argparse
import json
import logging
from pathlib import Path

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description='Generate client prefetch policies')
    parser.add_argument('--output', type=str, default='./client_prefetch_policy.json')
    parser.add_argument('--device_profiles', type=str, help='Custom device profiles JSON')
    return parser.parse_args()


# Default device profiles
DEVICE_PROFILES = {
    'high_end': {
        'memory_gb': 8,
        'storage_gb': 128,
        'battery_capacity': 'large'
    },
    'mid_range': {
        'memory_gb': 4,
        'storage_gb': 64,
        'battery_capacity': 'medium'
    },
    'low_end': {
        'memory_gb': 2,
        'storage_gb': 32,
        'battery_capacity': 'small'
    }
}


def generate_policy(device_profile, network_type, battery_level, user_settings):
    """Generate prefetch policy for given conditions."""
    policy = {
        'enabled': True,
        'max_prefetch_mb': 50,
        'max_concurrent': 2,
        'priority_assets': ['model', 'embeddings'],
        'conditions': {}
    }

    # Battery constraints
    if battery_level < 20:
        policy['enabled'] = False
        policy['reason'] = 'battery_low'
        return policy
    elif battery_level < 50:
        policy['max_prefetch_mb'] = 20
        policy['max_concurrent'] = 1

    # Network constraints
    if network_type == 'cellular':
        policy['max_prefetch_mb'] = min(policy['max_prefetch_mb'], 10)
        policy['conditions']['wifi_only'] = True
    elif network_type == 'wifi':
        policy['max_prefetch_mb'] *= 2
        policy['max_concurrent'] = 3
    elif network_type == 'offline':
        policy['enabled'] = False
        policy['reason'] = 'offline'
        return policy

    # Device constraints
    memory = device_profile.get('memory_gb', 4)
    if memory < 3:
        policy['max_prefetch_mb'] = min(policy['max_prefetch_mb'], 25)
        policy['max_concurrent'] = 1
    elif memory >= 6:
        policy['max_prefetch_mb'] *= 1.5

    # User settings
    if user_settings.get('data_saver', False):
        policy['max_prefetch_mb'] = min(policy['max_prefetch_mb'], 10)
        policy['conditions']['wifi_only'] = True

    if user_settings.get('aggressive_prefetch', False):
        policy['max_prefetch_mb'] *= 2
        policy['max_concurrent'] = 4

    policy['max_prefetch_mb'] = int(policy['max_prefetch_mb'])

    return policy


def generate_full_policy_matrix():
    """Generate policies for all device/network/battery combinations."""
    policies = {}

    network_types = ['wifi', 'cellular', 'offline']
    battery_levels = [10, 30, 50, 80, 100]

    for device_name, device_profile in DEVICE_PROFILES.items():
        policies[device_name] = {}

        for network in network_types:
            policies[device_name][network] = {}

            for battery in battery_levels:
                policy = generate_policy(
                    device_profile,
                    network,
                    battery,
                    {}  # Default user settings
                )
                policies[device_name][network][f'battery_{battery}'] = policy

    return policies


def main():
    args = parse_args()

    # Load custom profiles if provided
    if args.device_profiles:
        with open(args.device_profiles) as f:
            device_profiles = json.load(f)
    else:
        device_profiles = DEVICE_PROFILES

    # Generate policy matrix
    policy_matrix = generate_full_policy_matrix()

    # Add metadata
    output = {
        'version': '1.0',
        'description': 'Client prefetch budgets based on device, network, and battery',
        'device_profiles': device_profiles,
        'policies': policy_matrix,
        'defaults': {
            'enabled': True,
            'max_prefetch_mb': 50,
            'max_concurrent': 2,
            'wifi_only': False
        }
    }

    # Write output
    with open(args.output, 'w') as f:
        json.dump(output, f, indent=2)

    logger.info(f"Generated policy: {args.output}")

    # Summary
    print(json.dumps({
        'devices': list(policy_matrix.keys()),
        'network_types': ['wifi', 'cellular', 'offline'],
        'output': args.output
    }, indent=2))


if __name__ == '__main__':
    main()
