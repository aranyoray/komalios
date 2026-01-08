#!/usr/bin/env python3
"""
cdn_asset_optimizer.py — Auto-optimize static assets for CDN.
Compresses images, generates webp/avif, creates LQIP, uploads with cache headers.
"""

import argparse
import json
import logging
import subprocess
from pathlib import Path
from datetime import datetime

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description='CDN asset optimizer')
    parser.add_argument('--input_dir', type=str, required=True)
    parser.add_argument('--output_dir', type=str, default='./optimized_assets')
    parser.add_argument('--cdn_bucket', type=str, default='s3://komal-cdn')
    parser.add_argument('--quality', type=int, default=80)
    parser.add_argument('--lqip_size', type=int, default=20, help='LQIP dimension')
    parser.add_argument('--cache_max_age', type=int, default=31536000, help='Cache-Control max-age')
    parser.add_argument('--dry_run', action='store_true')
    return parser.parse_args()


def optimize_image(input_path, output_dir, quality, lqip_size):
    """Optimize image and generate variants."""
    from PIL import Image

    output_dir = Path(output_dir)
    stem = input_path.stem
    results = []

    img = Image.open(input_path)
    original_size = input_path.stat().st_size

    # Original format optimized
    out_path = output_dir / f"{stem}.png"
    img.save(out_path, optimize=True)
    results.append({'format': 'png', 'path': str(out_path), 'size': out_path.stat().st_size})

    # WebP
    webp_path = output_dir / f"{stem}.webp"
    img.save(webp_path, 'WEBP', quality=quality)
    results.append({'format': 'webp', 'path': str(webp_path), 'size': webp_path.stat().st_size})

    # AVIF (if available)
    try:
        avif_path = output_dir / f"{stem}.avif"
        img.save(avif_path, 'AVIF', quality=quality)
        results.append({'format': 'avif', 'path': str(avif_path), 'size': avif_path.stat().st_size})
    except:
        pass

    # LQIP (Low Quality Image Placeholder)
    lqip = img.copy()
    lqip.thumbnail((lqip_size, lqip_size))
    lqip_path = output_dir / f"{stem}_lqip.webp"
    lqip.save(lqip_path, 'WEBP', quality=20)
    results.append({'format': 'lqip', 'path': str(lqip_path), 'size': lqip_path.stat().st_size})

    return results, original_size


def upload_to_cdn(file_path, bucket, cache_max_age, dry_run):
    """Upload to CDN with cache headers."""
    cmd = [
        'aws', 's3', 'cp', str(file_path), bucket,
        '--cache-control', f'public,max-age={cache_max_age}',
        '--content-type', get_content_type(file_path)
    ]

    if dry_run:
        logger.info(f"Would upload: {file_path}")
        return True

    try:
        subprocess.run(cmd, check=True, capture_output=True)
        return True
    except:
        return False


def get_content_type(path):
    """Get content type for file."""
    ext = Path(path).suffix.lower()
    types = {
        '.png': 'image/png',
        '.webp': 'image/webp',
        '.avif': 'image/avif',
        '.jpg': 'image/jpeg',
        '.jpeg': 'image/jpeg'
    }
    return types.get(ext, 'application/octet-stream')


def main():
    args = parse_args()

    input_dir = Path(args.input_dir)
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    # Find images
    patterns = ['*.png', '*.jpg', '*.jpeg']
    images = []
    for pattern in patterns:
        images.extend(input_dir.glob(pattern))

    logger.info(f"Found {len(images)} images to optimize")

    total_original = 0
    total_optimized = 0
    all_results = []

    for img_path in images:
        logger.info(f"Optimizing: {img_path.name}")

        try:
            results, original = optimize_image(img_path, output_dir, args.quality, args.lqip_size)
            total_original += original

            for result in results:
                if result['format'] != 'lqip':
                    total_optimized += result['size']

                # Upload
                if not args.dry_run:
                    upload_to_cdn(result['path'], args.cdn_bucket, args.cache_max_age, args.dry_run)

            all_results.append({
                'input': str(img_path),
                'original_size': original,
                'variants': results
            })

        except Exception as e:
            logger.error(f"Failed: {img_path}: {e}")

    # Summary
    savings = (1 - total_optimized / total_original) * 100 if total_original > 0 else 0

    summary = {
        'timestamp': datetime.now().isoformat(),
        'images_processed': len(images),
        'total_original_kb': total_original / 1024,
        'total_optimized_kb': total_optimized / 1024,
        'savings_percent': round(savings, 1),
        'results': all_results
    }

    manifest_path = output_dir / 'optimization_manifest.json'
    with open(manifest_path, 'w') as f:
        json.dump(summary, f, indent=2)

    logger.info(f"Optimization complete: {savings:.1f}% savings")
    print(json.dumps({k: v for k, v in summary.items() if k != 'results'}, indent=2))


if __name__ == '__main__':
    main()
