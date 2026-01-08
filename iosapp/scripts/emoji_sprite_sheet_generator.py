#!/usr/bin/env python3
"""
emoji_sprite_sheet_generator.py - Generate optimized sprite sheets from emoji frames

Produces sprite sheets and metadata for efficient mobile/web rendering.
"""

import argparse
import json
import math
import logging
from pathlib import Path
from typing import Dict, List, Tuple
from PIL import Image

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class EmojiSpriteSheetGenerator:
    """Generate sprite sheets from emoji animation frames."""

    def __init__(self, config: Dict):
        self.config = config
        self.max_texture_size = config.get('max_texture_size', 2048)
        self.padding = config.get('padding', 2)
        self.output_format = config.get('format', 'PNG')

    def load_frames(self, input_dir: Path) -> List[Image.Image]:
        """Load animation frames from directory."""
        frames = []
        extensions = ['.png', '.jpg', '.jpeg']

        files = sorted([
            f for f in input_dir.iterdir()
            if f.suffix.lower() in extensions
        ])

        for file_path in files:
            img = Image.open(file_path)
            if img.mode != 'RGBA':
                img = img.convert('RGBA')
            frames.append(img)

        logger.info(f"Loaded {len(frames)} frames from {input_dir}")
        return frames

    def calculate_layout(self, frames: List[Image.Image]) -> Dict:
        """Calculate optimal sprite sheet layout."""
        if not frames:
            return {}

        # Assume all frames same size
        frame_width = frames[0].width + self.padding * 2
        frame_height = frames[0].height + self.padding * 2
        num_frames = len(frames)

        # Calculate grid dimensions
        # Try to make roughly square
        cols = math.ceil(math.sqrt(num_frames))
        rows = math.ceil(num_frames / cols)

        sheet_width = cols * frame_width
        sheet_height = rows * frame_height

        # Check against max texture size
        if sheet_width > self.max_texture_size or sheet_height > self.max_texture_size:
            # Need multiple sheets
            frames_per_sheet = (self.max_texture_size // frame_width) * (self.max_texture_size // frame_height)
            num_sheets = math.ceil(num_frames / frames_per_sheet)
        else:
            frames_per_sheet = num_frames
            num_sheets = 1

        return {
            'frame_width': frames[0].width,
            'frame_height': frames[0].height,
            'padded_width': frame_width,
            'padded_height': frame_height,
            'cols': cols,
            'rows': rows,
            'sheet_width': min(sheet_width, self.max_texture_size),
            'sheet_height': min(sheet_height, self.max_texture_size),
            'num_frames': num_frames,
            'num_sheets': num_sheets,
            'frames_per_sheet': frames_per_sheet
        }

    def generate_sprite_sheet(self, frames: List[Image.Image], layout: Dict) -> List[Image.Image]:
        """Generate sprite sheet images."""
        sheets = []
        frame_idx = 0

        for sheet_num in range(layout['num_sheets']):
            # Create sheet
            sheet = Image.new('RGBA',
                            (layout['sheet_width'], layout['sheet_height']),
                            (0, 0, 0, 0))

            # Place frames
            for i in range(layout['frames_per_sheet']):
                if frame_idx >= len(frames):
                    break

                col = i % layout['cols']
                row = i // layout['cols']

                x = col * layout['padded_width'] + self.padding
                y = row * layout['padded_height'] + self.padding

                sheet.paste(frames[frame_idx], (x, y))
                frame_idx += 1

            sheets.append(sheet)

        return sheets

    def generate_metadata(self, layout: Dict, animation_name: str) -> Dict:
        """Generate metadata for sprite sheet."""
        frames = []

        for i in range(layout['num_frames']):
            sheet_idx = i // layout['frames_per_sheet']
            frame_in_sheet = i % layout['frames_per_sheet']

            col = frame_in_sheet % layout['cols']
            row = frame_in_sheet // layout['cols']

            x = col * layout['padded_width'] + self.padding
            y = row * layout['padded_height'] + self.padding

            frames.append({
                'frame': i,
                'sheet': sheet_idx,
                'x': x,
                'y': y,
                'w': layout['frame_width'],
                'h': layout['frame_height']
            })

        return {
            'name': animation_name,
            'frame_width': layout['frame_width'],
            'frame_height': layout['frame_height'],
            'sheet_width': layout['sheet_width'],
            'sheet_height': layout['sheet_height'],
            'num_frames': layout['num_frames'],
            'num_sheets': layout['num_sheets'],
            'frames': frames,
            'animations': {
                'default': {
                    'frames': list(range(layout['num_frames'])),
                    'fps': self.config.get('fps', 24),
                    'loop': True
                }
            }
        }

    def process(self, input_dir: str, output_dir: str, animation_name: str = 'emoji') -> Dict:
        """Process frames into sprite sheets."""
        input_path = Path(input_dir)
        output_path = Path(output_dir)
        output_path.mkdir(parents=True, exist_ok=True)

        # Load frames
        frames = self.load_frames(input_path)
        if not frames:
            return {'error': 'No frames found'}

        # Calculate layout
        layout = self.calculate_layout(frames)

        # Generate sheets
        sheets = self.generate_sprite_sheet(frames, layout)

        # Save sheets
        for i, sheet in enumerate(sheets):
            sheet_path = output_path / f"{animation_name}_sheet_{i}.png"
            sheet.save(sheet_path, 'PNG', optimize=True)
            logger.info(f"Saved {sheet_path}")

        # Generate and save metadata
        metadata = self.generate_metadata(layout, animation_name)
        metadata_path = output_path / f"{animation_name}_metadata.json"

        with open(metadata_path, 'w') as f:
            json.dump(metadata, f, indent=2)

        logger.info(f"Saved metadata to {metadata_path}")

        # Calculate savings
        original_size = sum(f.width * f.height * 4 for f in frames)  # RGBA
        sheet_size = sum(s.width * s.height * 4 for s in sheets)

        return {
            'sheets_generated': len(sheets),
            'frames_processed': len(frames),
            'original_size_kb': original_size / 1024,
            'sheet_size_kb': sheet_size / 1024,
            'metadata_path': str(metadata_path)
        }


def create_demo_frames(output_dir: Path, count: int = 24):
    """Create demo frames for testing."""
    output_dir.mkdir(parents=True, exist_ok=True)

    for i in range(count):
        # Create simple animated frame
        img = Image.new('RGBA', (128, 128), (255, 255, 255, 0))

        # Draw a simple face that changes
        from PIL import ImageDraw
        draw = ImageDraw.Draw(img)

        # Face circle
        draw.ellipse([10, 10, 118, 118], fill=(255, 220, 100, 255))

        # Eyes
        eye_y = 45
        draw.ellipse([35, eye_y, 50, eye_y + 15], fill=(0, 0, 0, 255))
        draw.ellipse([78, eye_y, 93, eye_y + 15], fill=(0, 0, 0, 255))

        # Animated mouth
        mouth_open = 5 + int(10 * abs(math.sin(i * 0.5)))
        draw.arc([35, 60, 93, 60 + mouth_open * 2], 0, 180, fill=(0, 0, 0, 255), width=3)

        img.save(output_dir / f"frame_{i:03d}.png")

    logger.info(f"Created {count} demo frames in {output_dir}")


def main():
    parser = argparse.ArgumentParser(description='Emoji sprite sheet generator')
    parser.add_argument('--input', type=str, help='Input frames directory')
    parser.add_argument('--output', type=str, default='sprite_output', help='Output directory')
    parser.add_argument('--name', type=str, default='emoji', help='Animation name')
    parser.add_argument('--max-size', type=int, default=2048, help='Max texture size')
    parser.add_argument('--fps', type=int, default=24, help='Animation FPS')
    parser.add_argument('--demo', action='store_true', help='Generate demo frames')

    args = parser.parse_args()

    config = {
        'max_texture_size': args.max_size,
        'fps': args.fps
    }

    generator = EmojiSpriteSheetGenerator(config)

    if args.demo:
        demo_dir = Path('demo_frames')
        create_demo_frames(demo_dir, 24)
        args.input = str(demo_dir)

    if args.input:
        result = generator.process(args.input, args.output, args.name)

        logger.info(f"\n=== Sprite Sheet Generation Complete ===")
        logger.info(f"Sheets: {result.get('sheets_generated', 0)}")
        logger.info(f"Frames: {result.get('frames_processed', 0)}")
        logger.info(f"Original size: {result.get('original_size_kb', 0):.1f} KB")
        logger.info(f"Sheet size: {result.get('sheet_size_kb', 0):.1f} KB")
    else:
        parser.print_help()


if __name__ == '__main__':
    main()
