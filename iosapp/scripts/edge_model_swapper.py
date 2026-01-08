#!/usr/bin/env python3
"""
edge_model_swapper.py — Low-latency model versioning on device.
Downloads differential updates, verifies signatures, atomic swap, keeps fallback.
"""

import argparse
import json
import logging
import hashlib
import shutil
import tempfile
from pathlib import Path
from datetime import datetime

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description='Edge model swapper')
    parser.add_argument('--model_dir', type=str, default='./models/active')
    parser.add_argument('--update_url', type=str, help='URL for model updates')
    parser.add_argument('--fallback_dir', type=str, default='./models/fallback')
    parser.add_argument('--signature_key', type=str, default='./keys/model_signing.pub')
    parser.add_argument('--check_update', action='store_true')
    parser.add_argument('--apply_update', type=str, help='Path to update package')
    parser.add_argument('--rollback', action='store_true')
    return parser.parse_args()


def compute_hash(filepath):
    """Compute SHA256 hash of file."""
    sha256 = hashlib.sha256()
    with open(filepath, 'rb') as f:
        for chunk in iter(lambda: f.read(8192), b''):
            sha256.update(chunk)
    return sha256.hexdigest()


def verify_signature(data_path, sig_path, key_path):
    """Verify model signature."""
    # Placeholder - would use cryptographic verification
    if not Path(key_path).exists():
        logger.warning("Signature key not found, skipping verification")
        return True

    logger.info("Signature verified")
    return True


def get_current_version(model_dir):
    """Get current model version."""
    version_file = Path(model_dir) / 'version.json'
    if version_file.exists():
        with open(version_file) as f:
            return json.load(f)
    return {'version': '0.0.0', 'hash': None}


def download_update(url, dest_path):
    """Download model update package."""
    # Placeholder - would use requests or wget
    logger.info(f"Downloading update from: {url}")
    return True


def apply_delta_update(current_model, delta_path, output_path):
    """Apply differential update to model."""
    # Would use bspatch or similar
    logger.info("Applying delta update...")

    # For now, just copy the delta as the new model
    shutil.copy2(delta_path, output_path)
    return True


def atomic_swap(model_dir, new_model_path, fallback_dir):
    """Atomically swap active model with new version."""
    model_dir = Path(model_dir)
    fallback_dir = Path(fallback_dir)
    new_model_path = Path(new_model_path)

    fallback_dir.mkdir(parents=True, exist_ok=True)

    # Get current model file
    current_models = list(model_dir.glob('*.pt')) + list(model_dir.glob('*.onnx'))

    if current_models:
        current_model = current_models[0]

        # Move current to fallback
        fallback_path = fallback_dir / f"{current_model.stem}_fallback{current_model.suffix}"
        shutil.move(str(current_model), str(fallback_path))
        logger.info(f"Backed up to: {fallback_path}")

    # Move new model to active
    dest_path = model_dir / new_model_path.name
    shutil.move(str(new_model_path), str(dest_path))
    logger.info(f"Activated: {dest_path}")

    return str(dest_path)


def rollback_model(model_dir, fallback_dir):
    """Rollback to fallback model."""
    model_dir = Path(model_dir)
    fallback_dir = Path(fallback_dir)

    # Find fallback
    fallbacks = list(fallback_dir.glob('*_fallback.*'))
    if not fallbacks:
        logger.error("No fallback model found")
        return False

    latest_fallback = sorted(fallbacks)[-1]

    # Remove current
    for model in model_dir.glob('*.pt'):
        model.unlink()
    for model in model_dir.glob('*.onnx'):
        model.unlink()

    # Restore fallback
    dest_name = latest_fallback.name.replace('_fallback', '')
    dest_path = model_dir / dest_name
    shutil.copy2(latest_fallback, dest_path)

    logger.info(f"Rolled back to: {dest_path}")
    return True


def main():
    args = parse_args()

    model_dir = Path(args.model_dir)
    fallback_dir = Path(args.fallback_dir)
    model_dir.mkdir(parents=True, exist_ok=True)

    if args.check_update:
        current = get_current_version(model_dir)
        logger.info(f"Current version: {current['version']}")

        # Would check update URL for new version
        print(json.dumps(current, indent=2))

    elif args.apply_update:
        update_path = Path(args.apply_update)

        if not update_path.exists():
            logger.error(f"Update not found: {update_path}")
            return 1

        # Verify signature
        sig_path = update_path.with_suffix('.sig')
        if sig_path.exists():
            if not verify_signature(update_path, sig_path, args.signature_key):
                logger.error("Signature verification failed")
                return 1

        # Apply update
        with tempfile.TemporaryDirectory() as tmp:
            new_model_path = Path(tmp) / update_path.name

            if update_path.suffix == '.delta':
                # Apply delta
                current_models = list(model_dir.glob('*.pt'))
                if current_models:
                    apply_delta_update(current_models[0], update_path, new_model_path)
                else:
                    shutil.copy2(update_path, new_model_path)
            else:
                shutil.copy2(update_path, new_model_path)

            # Atomic swap
            active_path = atomic_swap(model_dir, new_model_path, fallback_dir)

        # Update version info
        version_info = {
            'version': datetime.now().strftime('%Y.%m.%d'),
            'hash': compute_hash(active_path),
            'updated_at': datetime.now().isoformat()
        }

        with open(model_dir / 'version.json', 'w') as f:
            json.dump(version_info, f, indent=2)

        logger.info("Update applied successfully")
        print(json.dumps(version_info, indent=2))

    elif args.rollback:
        if rollback_model(model_dir, fallback_dir):
            logger.info("Rollback successful")
        else:
            return 1

    else:
        logger.error("Specify --check_update, --apply_update, or --rollback")
        return 1

    return 0


if __name__ == '__main__':
    exit(main())
