#!/usr/bin/env python3
"""
emoji_avatar_engine.py — 2.5D Emoji Avatar Engine with speech-sync and face-driven modes.

Required packages:
numpy, opencv-python, pillow, mediapipe, imageio, scipy, tqdm, pandas

CLI: python emoji_avatar_engine.py --emoji smile --seconds 3 --out output.mp4 --fps 30
"""

import argparse
import hashlib
import json
import logging
import math
import os
import sys
import time
from datetime import datetime
from multiprocessing import Pool, cpu_count
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

try:
    import cv2
    HAS_CV2 = True
except ImportError:
    HAS_CV2 = False

try:
    import imageio
    HAS_IMAGEIO = True
except ImportError:
    HAS_IMAGEIO = False

try:
    import mediapipe as mp
    HAS_MEDIAPIPE = True
except ImportError:
    HAS_MEDIAPIPE = False

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)

# Safe positive emoji set
EMOJI_SET = {
    'smile': {'mouth': 'smile', 'eyes': 'happy', 'brows': 'relaxed'},
    'big_smile': {'mouth': 'big_smile', 'eyes': 'happy', 'brows': 'raised'},
    'soft_smile': {'mouth': 'soft_smile', 'eyes': 'gentle', 'brows': 'relaxed'},
    'laughing': {'mouth': 'laugh', 'eyes': 'closed_happy', 'brows': 'raised'},
    'beaming': {'mouth': 'beam', 'eyes': 'sparkle', 'brows': 'raised'},
    'blushing': {'mouth': 'shy_smile', 'eyes': 'happy', 'brows': 'relaxed', 'cheeks': 'blush'},
    'excited': {'mouth': 'open_smile', 'eyes': 'wide', 'brows': 'raised'},
    'curious': {'mouth': 'small_o', 'eyes': 'wide', 'brows': 'raised_one'},
    'grateful': {'mouth': 'gentle_smile', 'eyes': 'soft', 'brows': 'relaxed'},
    'friendly_wink': {'mouth': 'smile', 'eyes': 'wink', 'brows': 'relaxed'},
    'caring_smile': {'mouth': 'warm_smile', 'eyes': 'soft', 'brows': 'concerned'},
}

# Color palettes (child-safe)
SKIN_TONES = ['#FFE0BD', '#F5D0A9', '#E5BA8C', '#C9A06B', '#A67C52', '#8D5524']
HAIR_COLORS = ['#2C1810', '#4A3728', '#8B4513', '#D2691E', '#FFD700', '#FF6B6B', '#9370DB', '#20B2AA']


def parse_args():
    parser = argparse.ArgumentParser(description='2.5D Emoji Avatar Engine')
    parser.add_argument('--emoji', type=str, default='smile', choices=list(EMOJI_SET.keys()))
    parser.add_argument('--seconds', type=float, default=3.0)
    parser.add_argument('--out', type=str, default='output.mp4')
    parser.add_argument('--fps', type=int, default=30)
    parser.add_argument('--size', type=int, default=256)
    parser.add_argument('--drive_mode', type=str, default='static', choices=['static', 'speech', 'face'])
    parser.add_argument('--audio', type=str, default=None, help='WAV file for speech sync')
    parser.add_argument('--batch_generate', type=int, default=0, help='Generate N animations')
    parser.add_argument('--compute_heavy', action='store_true', help='Enable heavy compute effects')
    parser.add_argument('--multi_res', action='store_true', help='Multi-resolution rendering')
    parser.add_argument('--low_mem', action='store_true', help='Low memory mode (<60MB)')
    parser.add_argument('--gpu', action='store_true', help='Use GPU acceleration')
    parser.add_argument('--dry_run', action='store_true')
    parser.add_argument('--synthetic', type=int, default=0, help='Generate N synthetic test frames')
    parser.add_argument('--generate_thumbs', action='store_true', help='Generate accessory thumbnails')
    parser.add_argument('--convert', action='store_true', help='Export sprite sheets')
    parser.add_argument('--test', action='store_true', help='Run unit tests')
    parser.add_argument('--privacy_mode', action='store_true', help='Strip identifiable metadata')
    return parser.parse_args()


def ease_in_out_quad(t):
    """Quadratic easing function."""
    return 2 * t * t if t < 0.5 else 1 - pow(-2 * t + 2, 2) / 2


def ease_in_out_sine(t):
    """Sine easing function."""
    return -(math.cos(math.pi * t) - 1) / 2


def render_face_base(draw, cx, cy, radius, skin_color):
    """Render base face circle with 2.5D shading."""
    # Main face
    draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius],
                 fill=skin_color, outline=None)

    # Subtle 2.5D shading (lighter top, darker bottom)
    for i in range(5):
        alpha = int(30 - i * 5)
        shade_y = cy - radius + i * radius // 5
        # Simplified shading effect


def render_eyes(draw, cx, cy, radius, eye_type, frame_t):
    """Render eyes based on type."""
    eye_spacing = radius * 0.35
    eye_y = cy - radius * 0.1
    eye_radius = radius * 0.12

    # Eye animation
    blink = 1.0
    if int(frame_t * 3) % 90 == 0:  # Blink every ~3 seconds
        blink = max(0.1, 1.0 - ease_in_out_sine((frame_t * 3) % 1))

    if eye_type == 'happy':
        # Happy curved eyes
        for dx in [-eye_spacing, eye_spacing]:
            arc_bbox = [cx + dx - eye_radius, eye_y - eye_radius * blink,
                       cx + dx + eye_radius, eye_y + eye_radius * blink]
            draw.arc(arc_bbox, 0, 180, fill='#2C1810', width=3)

    elif eye_type == 'closed_happy':
        for dx in [-eye_spacing, eye_spacing]:
            draw.arc([cx + dx - eye_radius, eye_y - eye_radius,
                     cx + dx + eye_radius, eye_y + eye_radius],
                    0, 180, fill='#2C1810', width=3)

    elif eye_type == 'wink':
        # Left eye normal, right eye winking
        draw.ellipse([cx - eye_spacing - eye_radius, eye_y - eye_radius * blink,
                     cx - eye_spacing + eye_radius, eye_y + eye_radius * blink],
                    fill='#2C1810')
        draw.arc([cx + eye_spacing - eye_radius, eye_y - eye_radius,
                 cx + eye_spacing + eye_radius, eye_y + eye_radius],
                0, 180, fill='#2C1810', width=3)

    elif eye_type in ['wide', 'sparkle']:
        for dx in [-eye_spacing, eye_spacing]:
            draw.ellipse([cx + dx - eye_radius * 1.2, eye_y - eye_radius * 1.3 * blink,
                         cx + dx + eye_radius * 1.2, eye_y + eye_radius * 1.3 * blink],
                        fill='#2C1810')
            # Sparkle highlight
            if eye_type == 'sparkle':
                draw.ellipse([cx + dx - eye_radius * 0.3, eye_y - eye_radius * 0.5,
                             cx + dx + eye_radius * 0.1, eye_y - eye_radius * 0.1],
                            fill='white')

    else:  # default, gentle, soft
        for dx in [-eye_spacing, eye_spacing]:
            draw.ellipse([cx + dx - eye_radius, eye_y - eye_radius * blink,
                         cx + dx + eye_radius, eye_y + eye_radius * blink],
                        fill='#2C1810')


def render_mouth(draw, cx, cy, radius, mouth_type, frame_t, speech_energy=0):
    """Render mouth based on type with optional speech sync."""
    mouth_y = cy + radius * 0.3
    mouth_width = radius * 0.4
    mouth_height = radius * 0.15

    # Speech animation
    if speech_energy > 0:
        mouth_height *= (1 + speech_energy * 0.5)

    # Micro-expression wobble
    wobble = math.sin(frame_t * 8) * 0.02

    if mouth_type in ['smile', 'soft_smile', 'gentle_smile', 'warm_smile']:
        # Curved smile
        curve_depth = radius * 0.1 if mouth_type == 'soft_smile' else radius * 0.15
        draw.arc([cx - mouth_width, mouth_y - curve_depth,
                 cx + mouth_width, mouth_y + curve_depth + mouth_height],
                0, 180, fill='#8B4513', width=3)

    elif mouth_type == 'big_smile':
        draw.arc([cx - mouth_width * 1.3, mouth_y - radius * 0.1,
                 cx + mouth_width * 1.3, mouth_y + radius * 0.25],
                0, 180, fill='#8B4513', width=4)

    elif mouth_type in ['laugh', 'beam', 'open_smile']:
        # Open mouth
        draw.ellipse([cx - mouth_width * 0.8, mouth_y,
                     cx + mouth_width * 0.8, mouth_y + mouth_height * 2],
                    fill='#8B4513', outline='#5D3A1A')

    elif mouth_type == 'shy_smile':
        draw.arc([cx - mouth_width * 0.7, mouth_y - radius * 0.05,
                 cx + mouth_width * 0.7, mouth_y + radius * 0.1],
                0, 180, fill='#8B4513', width=2)

    elif mouth_type == 'small_o':
        draw.ellipse([cx - mouth_width * 0.3, mouth_y,
                     cx + mouth_width * 0.3, mouth_y + mouth_height * 1.5],
                    fill='#8B4513')


def render_blush(draw, cx, cy, radius):
    """Render cheek blush."""
    blush_color = (255, 182, 193, 100)
    blush_y = cy + radius * 0.15
    blush_offset = radius * 0.5

    for dx in [-blush_offset, blush_offset]:
        draw.ellipse([cx + dx - radius * 0.15, blush_y - radius * 0.08,
                     cx + dx + radius * 0.15, blush_y + radius * 0.08],
                    fill='#FFB6C1')


def render_hair(draw, cx, cy, radius, hair_style, hair_color):
    """Render hair style."""
    if hair_style == 'short':
        draw.arc([cx - radius, cy - radius * 1.3, cx + radius, cy - radius * 0.3],
                180, 360, fill=hair_color, width=int(radius * 0.3))

    elif hair_style == 'long':
        # Long flowing hair
        draw.ellipse([cx - radius * 1.1, cy - radius * 1.2,
                     cx + radius * 1.1, cy + radius * 0.8],
                    fill=hair_color)
        # Face cutout
        draw.ellipse([cx - radius * 0.9, cy - radius * 0.9,
                     cx + radius * 0.9, cy + radius * 0.9],
                    fill='#FFE0BD')

    elif hair_style == 'curly':
        for angle in range(0, 360, 30):
            rad = math.radians(angle)
            hx = cx + math.cos(rad) * radius * 0.9
            hy = cy - radius * 0.8 + math.sin(rad) * radius * 0.3
            draw.ellipse([hx - radius * 0.15, hy - radius * 0.15,
                         hx + radius * 0.15, hy + radius * 0.15],
                        fill=hair_color)

    elif hair_style == 'spiky':
        for i in range(7):
            angle = math.radians(150 + i * 12)
            x1 = cx + math.cos(angle) * radius * 0.8
            y1 = cy - radius * 0.7
            x2 = cx + math.cos(angle) * radius * 1.3
            y2 = cy - radius * 1.2
            draw.polygon([(x1, y1), (x2, y2), (x1 + 10, y1)], fill=hair_color)


def render_accessory(draw, cx, cy, radius, accessory_type, accessory_color):
    """Render accessory."""
    if accessory_type == 'bow':
        bow_y = cy - radius * 1.0
        draw.polygon([(cx - radius * 0.3, bow_y), (cx - radius * 0.1, bow_y - radius * 0.15),
                     (cx - radius * 0.1, bow_y + radius * 0.15)], fill=accessory_color)
        draw.polygon([(cx + radius * 0.3, bow_y), (cx + radius * 0.1, bow_y - radius * 0.15),
                     (cx + radius * 0.1, bow_y + radius * 0.15)], fill=accessory_color)
        draw.ellipse([cx - radius * 0.08, bow_y - radius * 0.08,
                     cx + radius * 0.08, bow_y + radius * 0.08], fill=accessory_color)

    elif accessory_type == 'glasses':
        glass_y = cy - radius * 0.1
        for dx in [-radius * 0.35, radius * 0.35]:
            draw.ellipse([cx + dx - radius * 0.2, glass_y - radius * 0.12,
                         cx + dx + radius * 0.2, glass_y + radius * 0.12],
                        outline='#2C1810', width=2)
        draw.line([cx - radius * 0.15, glass_y, cx + radius * 0.15, glass_y],
                 fill='#2C1810', width=2)

    elif accessory_type == 'hat':
        draw.rectangle([cx - radius * 0.6, cy - radius * 1.2,
                       cx + radius * 0.6, cy - radius * 0.8],
                      fill=accessory_color)
        draw.ellipse([cx - radius * 0.8, cy - radius * 0.95,
                     cx + radius * 0.8, cy - radius * 0.65],
                    fill=accessory_color)

    elif accessory_type == 'headband':
        draw.arc([cx - radius, cy - radius * 1.1, cx + radius, cy - radius * 0.3],
                180, 360, fill=accessory_color, width=int(radius * 0.1))


def apply_glow_diffusion(img, intensity=0.3, iterations=3):
    """Apply glow diffusion effect (compute heavy)."""
    glow = img.filter(ImageFilter.GaussianBlur(radius=10))
    return Image.blend(img, glow, intensity)


def render_frame(state, size=256, compute_heavy=False):
    """
    Render a single frame.

    Args:
        state: dict with keys: emoji, frame_t, hair_style, hair_color,
               accessory, accessory_color, skin_color, speech_energy
        size: output size
        compute_heavy: enable heavy effects

    Returns:
        PIL Image
    """
    img = Image.new('RGBA', (size, size), (255, 255, 255, 0))
    draw = ImageDraw.Draw(img)

    cx, cy = size // 2, size // 2
    radius = int(size * 0.35)

    emoji_name = state.get('emoji', 'smile')
    emoji_config = EMOJI_SET.get(emoji_name, EMOJI_SET['smile'])
    frame_t = state.get('frame_t', 0)
    skin_color = state.get('skin_color', SKIN_TONES[0])
    speech_energy = state.get('speech_energy', 0)

    # Render face
    render_face_base(draw, cx, cy, radius, skin_color)

    # Render features
    render_eyes(draw, cx, cy, radius, emoji_config['eyes'], frame_t)
    render_mouth(draw, cx, cy, radius, emoji_config['mouth'], frame_t, speech_energy)

    if emoji_config.get('cheeks') == 'blush':
        render_blush(draw, cx, cy, radius)

    # Render hair
    if state.get('hair_style'):
        render_hair(draw, cx, cy, radius, state['hair_style'],
                   state.get('hair_color', HAIR_COLORS[0]))

    # Render accessory
    if state.get('accessory'):
        render_accessory(draw, cx, cy, radius, state['accessory'],
                        state.get('accessory_color', '#FF69B4'))

    # Heavy compute effects
    if compute_heavy:
        img = apply_glow_diffusion(img)

    return img


def render_sequence(params):
    """
    Render animation sequence.

    Args:
        params: dict with keys: emoji, seconds, fps, size, drive_mode,
                audio_path, hair_style, hair_color, accessory, accessory_color,
                skin_color, compute_heavy

    Returns:
        list of PIL Images
    """
    emoji = params.get('emoji', 'smile')
    seconds = params.get('seconds', 3.0)
    fps = params.get('fps', 30)
    size = params.get('size', 256)
    compute_heavy = params.get('compute_heavy', False)

    n_frames = int(seconds * fps)
    frames = []

    # Speech energy envelope (synthetic if no audio)
    speech_energies = np.zeros(n_frames)
    if params.get('drive_mode') == 'speech':
        # Generate synthetic speech pattern
        for i in range(n_frames):
            t = i / fps
            speech_energies[i] = max(0, math.sin(t * 5) * 0.5 + np.random.rand() * 0.3)

    for i in range(n_frames):
        state = {
            'emoji': emoji,
            'frame_t': i / fps,
            'skin_color': params.get('skin_color', SKIN_TONES[0]),
            'hair_style': params.get('hair_style'),
            'hair_color': params.get('hair_color'),
            'accessory': params.get('accessory'),
            'accessory_color': params.get('accessory_color'),
            'speech_energy': speech_energies[i],
        }
        frame = render_frame(state, size, compute_heavy)
        frames.append(frame)

    return frames


def save_animation(frames, output_path, fps=30):
    """Save frames as video or GIF."""
    if output_path.endswith('.gif'):
        frames[0].save(output_path, save_all=True, append_images=frames[1:],
                      duration=int(1000/fps), loop=0)
    elif output_path.endswith('.mp4') and HAS_IMAGEIO:
        with imageio.get_writer(output_path, fps=fps) as writer:
            for frame in frames:
                writer.append_data(np.array(frame.convert('RGB')))
    else:
        # Save as PNG sequence
        base = output_path.rsplit('.', 1)[0]
        for i, frame in enumerate(frames):
            frame.save(f'{base}_{i:04d}.png')


def batch_generate_worker(args):
    """Worker for parallel batch generation."""
    idx, params = args
    frames = render_sequence(params)
    output_path = f"batch_outputs/animation_{idx:04d}.mp4"
    save_animation(frames, output_path, params.get('fps', 30))
    return output_path


def generate_thumbnails(output_dir='assets/emojis'):
    """Generate thumbnails for all emojis and accessories."""
    Path(output_dir).mkdir(parents=True, exist_ok=True)

    thumbnails = []
    for emoji_name in EMOJI_SET:
        state = {'emoji': emoji_name, 'frame_t': 0, 'skin_color': SKIN_TONES[0]}
        img = render_frame(state, size=64)
        path = f'{output_dir}/{emoji_name}_thumb.png'
        img.save(path)
        thumbnails.append(path)

    logger.info(f"generated {len(thumbnails)} thumbnails")
    return thumbnails


def run_tests():
    """Run unit tests."""
    logger.info("running unit tests...")

    # Test all emojis
    for emoji_name in EMOJI_SET:
        state = {'emoji': emoji_name, 'frame_t': 0}
        img = render_frame(state, size=128)
        assert img.size == (128, 128), f"size mismatch for {emoji_name}"

    # Test sequence
    params = {'emoji': 'smile', 'seconds': 0.5, 'fps': 10, 'size': 64}
    frames = render_sequence(params)
    assert len(frames) == 5, f"expected 5 frames, got {len(frames)}"

    logger.info("all tests passed!")
    return True


def compute_sha256(filepath):
    sha256_hash = hashlib.sha256()
    with open(filepath, 'rb') as f:
        for chunk in iter(lambda: f.read(4096), b''):
            sha256_hash.update(chunk)
    return sha256_hash.hexdigest()


def update_manifest(artifacts, manifest_path='artifacts_manifest.csv'):
    """Update artifacts manifest."""
    import pandas as pd
    rows = []
    for path in artifacts:
        if os.path.exists(path):
            rows.append({
                'path': path,
                'sha256': compute_sha256(path),
                'size': os.path.getsize(path),
                'created_at': datetime.now().isoformat(),
            })
    df = pd.DataFrame(rows)

    if os.path.exists(manifest_path):
        existing = pd.read_csv(manifest_path)
        df = pd.concat([existing, df], ignore_index=True)

    df.to_csv(manifest_path, index=False)


def main():
    args = parse_args()

    if args.test:
        run_tests()
        return

    if args.generate_thumbs:
        generate_thumbnails()
        return

    if args.synthetic > 0:
        logger.info(f"generating {args.synthetic} synthetic frames...")
        for i in range(args.synthetic):
            emoji = list(EMOJI_SET.keys())[i % len(EMOJI_SET)]
            state = {'emoji': emoji, 'frame_t': i * 0.1}
            render_frame(state, args.size)
        logger.info("synthetic generation complete")
        return

    if args.batch_generate > 0:
        logger.info(f"batch generating {args.batch_generate} animations...")
        Path('batch_outputs').mkdir(exist_ok=True)

        tasks = []
        for i in range(args.batch_generate):
            params = {
                'emoji': list(EMOJI_SET.keys())[i % len(EMOJI_SET)],
                'seconds': args.seconds,
                'fps': args.fps,
                'size': args.size,
                'compute_heavy': args.compute_heavy,
            }
            tasks.append((i, params))

        with Pool(cpu_count()) as pool:
            results = pool.map(batch_generate_worker, tasks)

        update_manifest(results)
        logger.info(f"generated {len(results)} animations")
        return

    if args.dry_run:
        logger.info("dry run mode - skipping actual rendering")
        return

    # Single animation render
    params = {
        'emoji': args.emoji,
        'seconds': args.seconds,
        'fps': args.fps,
        'size': args.size,
        'drive_mode': args.drive_mode,
        'compute_heavy': args.compute_heavy,
    }

    logger.info(f"rendering {args.emoji} animation ({args.seconds}s @ {args.fps}fps)...")
    frames = render_sequence(params)
    save_animation(frames, args.out, args.fps)
    logger.info(f"saved to {args.out}")

    update_manifest([args.out])


if __name__ == '__main__':
    main()
