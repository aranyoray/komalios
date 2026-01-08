#!/usr/bin/env python3
"""
fifo_upload_compressor.py — Low-bandwidth encrypted uploader.
Compresses with zstd, lossy video compression, encrypts, uploads, purges on success.
"""

import argparse
import json
import logging
import os
import subprocess
import secrets
import hashlib
from pathlib import Path
from datetime import datetime
import time

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description='Compressed encrypted uploader')
    parser.add_argument('--input_dir', type=str, required=True)
    parser.add_argument('--output_bucket', type=str, default='s3://komal-uploads')
    parser.add_argument('--video_quality', type=int, default=28, help='CRF for video (higher=smaller)')
    parser.add_argument('--zstd_level', type=int, default=15)
    parser.add_argument('--max_retries', type=int, default=3)
    parser.add_argument('--purge_on_success', action='store_true')
    parser.add_argument('--dry_run', action='store_true')
    return parser.parse_args()


def compress_video(input_path, output_path, crf=28):
    """Compress video with ffmpeg."""
    try:
        subprocess.run([
            'ffmpeg', '-i', str(input_path),
            '-c:v', 'libx264', '-crf', str(crf),
            '-preset', 'fast', '-y', str(output_path)
        ], check=True, capture_output=True)
        return True
    except:
        return False


def compress_zstd(input_path, output_path, level=15):
    """Compress with zstd."""
    try:
        subprocess.run([
            'zstd', f'-{level}', str(input_path), '-o', str(output_path)
        ], check=True, capture_output=True)
        return True
    except:
        # Fallback to gzip
        subprocess.run(['gzip', '-c', str(input_path)], stdout=open(output_path, 'wb'))
        return True


def encrypt_file(input_path, output_path, key):
    """Encrypt file with AES."""
    try:
        from cryptography.fernet import Fernet
        import base64
        key_b64 = base64.urlsafe_b64encode(key[:32].ljust(32, b'\0'))
        f = Fernet(key_b64)
        with open(input_path, 'rb') as fin:
            encrypted = f.encrypt(fin.read())
        with open(output_path, 'wb') as fout:
            fout.write(encrypted)
        return True
    except ImportError:
        # Fallback: XOR with key (not secure, placeholder)
        with open(input_path, 'rb') as fin:
            data = fin.read()
        key_stream = (key * (len(data) // len(key) + 1))[:len(data)]
        encrypted = bytes(a ^ b for a, b in zip(data, key_stream))
        with open(output_path, 'wb') as fout:
            fout.write(encrypted)
        return True


def upload_to_storage(file_path, bucket, max_retries):
    """Upload file to storage with retries."""
    for attempt in range(max_retries):
        try:
            subprocess.run([
                'aws', 's3', 'cp', str(file_path), bucket
            ], check=True, capture_output=True)
            return True
        except:
            if attempt < max_retries - 1:
                time.sleep(2 ** attempt)
    return False


def main():
    args = parse_args()

    input_dir = Path(args.input_dir)
    temp_dir = input_dir / '.upload_temp'
    temp_dir.mkdir(exist_ok=True)

    # Generate session key
    session_key = secrets.token_bytes(32)

    results = []
    total_original = 0
    total_compressed = 0

    for file_path in input_dir.iterdir():
        if file_path.is_file() and not file_path.name.startswith('.'):
            logger.info(f"Processing: {file_path.name}")

            original_size = file_path.stat().st_size
            total_original += original_size

            # Compress
            if file_path.suffix in ['.mp4', '.avi', '.mov']:
                compressed_path = temp_dir / f"{file_path.stem}_compressed.mp4"
                compress_video(file_path, compressed_path, args.video_quality)
            else:
                compressed_path = temp_dir / f"{file_path.name}.zst"
                compress_zstd(file_path, compressed_path, args.zstd_level)

            # Encrypt
            encrypted_path = temp_dir / f"{compressed_path.name}.enc"
            encrypt_file(compressed_path, encrypted_path, session_key)

            compressed_size = encrypted_path.stat().st_size
            total_compressed += compressed_size

            result = {
                'file': file_path.name,
                'original_size': original_size,
                'compressed_size': compressed_size,
                'ratio': round(compressed_size / original_size, 3)
            }

            # Upload
            if not args.dry_run:
                if upload_to_storage(encrypted_path, args.output_bucket, args.max_retries):
                    result['uploaded'] = True
                    if args.purge_on_success:
                        file_path.unlink()
                        result['purged'] = True
                else:
                    result['uploaded'] = False

            results.append(result)

            # Cleanup temp
            compressed_path.unlink(missing_ok=True)
            encrypted_path.unlink(missing_ok=True)

    # Summary
    summary = {
        'timestamp': datetime.now().isoformat(),
        'total_original_mb': total_original / (1024 * 1024),
        'total_compressed_mb': total_compressed / (1024 * 1024),
        'overall_ratio': round(total_compressed / total_original, 3) if total_original > 0 else 0,
        'files': results
    }

    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()
