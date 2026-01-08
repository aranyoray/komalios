#!/usr/bin/env python3
"""
model_artifact_packer.py - Bundle models into compressed tarballs

Bundles models, configs, adapters, and assets with checksums for delta updates.
"""

import argparse
import json
import hashlib
import tarfile
import os
import logging
from pathlib import Path
from datetime import datetime
from typing import Dict, List

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class ModelArtifactPacker:
    """Pack model artifacts for distribution."""

    def __init__(self, config: Dict):
        self.config = config
        self.compression = config.get('compression', 'gz')  # gz, bz2, xz

    def compute_checksum(self, file_path: Path) -> str:
        """Compute SHA256 checksum of file."""
        sha256 = hashlib.sha256()
        with open(file_path, 'rb') as f:
            for chunk in iter(lambda: f.read(8192), b''):
                sha256.update(chunk)
        return sha256.hexdigest()

    def collect_artifacts(self, source_dir: Path, patterns: List[str]) -> List[Dict]:
        """Collect artifacts matching patterns."""
        artifacts = []

        for pattern in patterns:
            for file_path in source_dir.glob(pattern):
                if file_path.is_file():
                    artifacts.append({
                        'path': file_path,
                        'relative': file_path.relative_to(source_dir),
                        'size': file_path.stat().st_size,
                        'checksum': self.compute_checksum(file_path)
                    })

        return artifacts

    def create_manifest(self, artifacts: List[Dict], version: str) -> Dict:
        """Create manifest for artifacts."""
        return {
            'version': version,
            'created': datetime.now().isoformat(),
            'compression': self.compression,
            'total_size': sum(a['size'] for a in artifacts),
            'file_count': len(artifacts),
            'files': [
                {
                    'path': str(a['relative']),
                    'size': a['size'],
                    'checksum': a['checksum']
                }
                for a in artifacts
            ]
        }

    def pack(self, source_dir: str, output_path: str, version: str,
             patterns: List[str] = None) -> Dict:
        """Pack artifacts into compressed tarball."""
        source = Path(source_dir)
        output = Path(output_path)

        if patterns is None:
            patterns = [
                '*.tflite',
                '*.onnx',
                '*.pt',
                '*.pth',
                '*.json',
                '*.yaml',
                '*.yml',
                'config/*',
                'adapters/*'
            ]

        # Collect artifacts
        artifacts = self.collect_artifacts(source, patterns)

        if not artifacts:
            return {'error': 'No artifacts found'}

        logger.info(f"Found {len(artifacts)} artifacts")

        # Create manifest
        manifest = self.create_manifest(artifacts, version)

        # Determine compression mode
        if self.compression == 'xz':
            mode = 'w:xz'
            ext = '.tar.xz'
        elif self.compression == 'bz2':
            mode = 'w:bz2'
            ext = '.tar.bz2'
        else:
            mode = 'w:gz'
            ext = '.tar.gz'

        # Add extension if needed
        if not str(output).endswith(ext):
            output = Path(str(output) + ext)

        # Create tarball
        with tarfile.open(output, mode) as tar:
            # Add manifest
            manifest_str = json.dumps(manifest, indent=2)
            manifest_bytes = manifest_str.encode('utf-8')

            import io
            manifest_info = tarfile.TarInfo(name='manifest.json')
            manifest_info.size = len(manifest_bytes)
            tar.addfile(manifest_info, io.BytesIO(manifest_bytes))

            # Add artifacts
            for artifact in artifacts:
                arcname = str(artifact['relative'])
                tar.add(artifact['path'], arcname=arcname)
                logger.debug(f"Added {arcname}")

        # Get final size
        output_size = output.stat().st_size
        original_size = manifest['total_size']
        compression_ratio = original_size / output_size if output_size > 0 else 1

        result = {
            'output_path': str(output),
            'version': version,
            'file_count': len(artifacts),
            'original_size_mb': original_size / (1024**2),
            'compressed_size_mb': output_size / (1024**2),
            'compression_ratio': compression_ratio,
            'manifest': manifest
        }

        logger.info(f"Created {output} ({output_size / (1024**2):.1f} MB, {compression_ratio:.1f}x compression)")

        return result

    def unpack(self, archive_path: str, output_dir: str) -> Dict:
        """Unpack artifact archive."""
        archive = Path(archive_path)
        output = Path(output_dir)
        output.mkdir(parents=True, exist_ok=True)

        with tarfile.open(archive, 'r:*') as tar:
            tar.extractall(output)

        # Load manifest
        manifest_path = output / 'manifest.json'
        if manifest_path.exists():
            with open(manifest_path, 'r') as f:
                manifest = json.load(f)
        else:
            manifest = None

        logger.info(f"Unpacked to {output}")

        return {
            'output_dir': str(output),
            'manifest': manifest
        }

    def verify(self, archive_path: str) -> Dict:
        """Verify archive integrity."""
        archive = Path(archive_path)

        with tarfile.open(archive, 'r:*') as tar:
            # Extract manifest
            try:
                manifest_file = tar.extractfile('manifest.json')
                manifest = json.loads(manifest_file.read().decode('utf-8'))
            except:
                return {'valid': False, 'error': 'No manifest found'}

            # Verify files
            errors = []
            for file_info in manifest['files']:
                try:
                    member = tar.getmember(file_info['path'])
                    if member.size != file_info['size']:
                        errors.append(f"{file_info['path']}: size mismatch")
                except KeyError:
                    errors.append(f"{file_info['path']}: missing")

        return {
            'valid': len(errors) == 0,
            'version': manifest.get('version'),
            'file_count': manifest.get('file_count'),
            'errors': errors
        }


def main():
    parser = argparse.ArgumentParser(description='Model artifact packer')
    parser.add_argument('command', choices=['pack', 'unpack', 'verify'])
    parser.add_argument('--source', type=str, help='Source directory')
    parser.add_argument('--output', type=str, help='Output path')
    parser.add_argument('--version', type=str, default='1.0.0')
    parser.add_argument('--compression', type=str, default='gz', choices=['gz', 'bz2', 'xz'])
    parser.add_argument('--demo', action='store_true')

    args = parser.parse_args()

    packer = ModelArtifactPacker({'compression': args.compression})

    if args.demo:
        # Create demo artifacts
        demo_dir = Path('demo_artifacts')
        demo_dir.mkdir(exist_ok=True)

        # Create fake model files
        (demo_dir / 'emotion.tflite').write_bytes(os.urandom(10000))
        (demo_dir / 'attention.onnx').write_bytes(os.urandom(15000))
        (demo_dir / 'config.json').write_text('{"version": "1.0"}')

        # Pack
        result = packer.pack(str(demo_dir), 'demo_models.tar', '1.0.0')

        logger.info(f"\n=== Pack Result ===")
        logger.info(f"Files: {result['file_count']}")
        logger.info(f"Original: {result['original_size_mb']:.2f} MB")
        logger.info(f"Compressed: {result['compressed_size_mb']:.2f} MB")
        logger.info(f"Ratio: {result['compression_ratio']:.1f}x")

        # Verify
        verify_result = packer.verify(result['output_path'])
        logger.info(f"\nVerification: {'PASS' if verify_result['valid'] else 'FAIL'}")

    elif args.command == 'pack':
        if not args.source or not args.output:
            parser.error("pack requires --source and --output")

        result = packer.pack(args.source, args.output, args.version)
        logger.info(f"Packed {result['file_count']} files to {result['output_path']}")

    elif args.command == 'unpack':
        if not args.source or not args.output:
            parser.error("unpack requires --source and --output")

        result = packer.unpack(args.source, args.output)
        logger.info(f"Unpacked to {result['output_dir']}")

    elif args.command == 'verify':
        if not args.source:
            parser.error("verify requires --source")

        result = packer.verify(args.source)
        if result['valid']:
            logger.info(f"Archive valid: {result['file_count']} files, version {result['version']}")
        else:
            logger.error(f"Archive invalid: {result['errors']}")


if __name__ == '__main__':
    main()
