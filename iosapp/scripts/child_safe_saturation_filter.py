#!/usr/bin/env python3
"""
child_safe_saturation_filter.py - Reduce high contrast/saturation for eye safety

Protects vision on low-end screens by reducing overly bright content.
"""

import argparse
import numpy as np
import logging
from typing import Dict, Tuple

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class ChildSafeSaturationFilter:
    """Apply child-safe saturation and contrast filters."""

    def __init__(self, config: Dict):
        self.config = config

        # Safety limits
        self.max_saturation = config.get('max_saturation', 0.8)
        self.max_brightness = config.get('max_brightness', 0.9)
        self.max_contrast = config.get('max_contrast', 0.85)

        # Age-based adjustments
        self.age_adjustments = {
            'toddler': {'saturation': 0.6, 'brightness': 0.8, 'contrast': 0.7},  # 3-5
            'child': {'saturation': 0.75, 'brightness': 0.85, 'contrast': 0.8},   # 5-8
            'preteen': {'saturation': 0.85, 'brightness': 0.9, 'contrast': 0.85}  # 8-12
        }

    def rgb_to_hsv(self, rgb: np.ndarray) -> np.ndarray:
        """Convert RGB to HSV."""
        rgb_normalized = rgb.astype(float) / 255.0

        r, g, b = rgb_normalized[..., 0], rgb_normalized[..., 1], rgb_normalized[..., 2]

        max_c = np.maximum(np.maximum(r, g), b)
        min_c = np.minimum(np.minimum(r, g), b)
        diff = max_c - min_c

        # Hue
        h = np.zeros_like(max_c)
        mask = diff != 0

        # Red is max
        idx = (max_c == r) & mask
        h[idx] = (60 * ((g[idx] - b[idx]) / diff[idx]) + 360) % 360

        # Green is max
        idx = (max_c == g) & mask
        h[idx] = (60 * ((b[idx] - r[idx]) / diff[idx]) + 120) % 360

        # Blue is max
        idx = (max_c == b) & mask
        h[idx] = (60 * ((r[idx] - g[idx]) / diff[idx]) + 240) % 360

        # Saturation
        s = np.zeros_like(max_c)
        s[max_c != 0] = diff[max_c != 0] / max_c[max_c != 0]

        # Value
        v = max_c

        return np.stack([h, s, v], axis=-1)

    def hsv_to_rgb(self, hsv: np.ndarray) -> np.ndarray:
        """Convert HSV to RGB."""
        h, s, v = hsv[..., 0], hsv[..., 1], hsv[..., 2]

        c = v * s
        x = c * (1 - np.abs((h / 60) % 2 - 1))
        m = v - c

        rgb = np.zeros((*h.shape, 3))

        # Different sectors
        idx = (h >= 0) & (h < 60)
        rgb[idx] = [c[idx], x[idx], np.zeros_like(c[idx])]

        idx = (h >= 60) & (h < 120)
        rgb[idx] = [x[idx], c[idx], np.zeros_like(c[idx])]

        idx = (h >= 120) & (h < 180)
        rgb[idx] = [np.zeros_like(c[idx]), c[idx], x[idx]]

        idx = (h >= 180) & (h < 240)
        rgb[idx] = [np.zeros_like(c[idx]), x[idx], c[idx]]

        idx = (h >= 240) & (h < 300)
        rgb[idx] = [x[idx], np.zeros_like(c[idx]), c[idx]]

        idx = (h >= 300) & (h < 360)
        rgb[idx] = [c[idx], np.zeros_like(c[idx]), x[idx]]

        rgb = rgb + m[..., np.newaxis]

        return (rgb * 255).astype(np.uint8)

    def apply_filter(self, image: np.ndarray, age_group: str = 'child') -> np.ndarray:
        """Apply child-safe filter to image."""
        # Get age-based limits
        limits = self.age_adjustments.get(age_group, self.age_adjustments['child'])

        # Convert to HSV
        hsv = self.rgb_to_hsv(image)

        # Limit saturation
        max_sat = min(limits['saturation'], self.max_saturation)
        hsv[..., 1] = np.minimum(hsv[..., 1], max_sat)

        # Limit brightness
        max_bright = min(limits['brightness'], self.max_brightness)
        hsv[..., 2] = np.minimum(hsv[..., 2], max_bright)

        # Convert back to RGB
        filtered = self.hsv_to_rgb(hsv)

        # Apply contrast reduction
        max_contrast = min(limits['contrast'], self.max_contrast)
        mean = np.mean(filtered)
        filtered = (filtered - mean) * max_contrast + mean
        filtered = np.clip(filtered, 0, 255).astype(np.uint8)

        return filtered

    def analyze_image(self, image: np.ndarray) -> Dict:
        """Analyze image for safety metrics."""
        hsv = self.rgb_to_hsv(image)

        avg_saturation = np.mean(hsv[..., 1])
        max_saturation = np.max(hsv[..., 1])
        avg_brightness = np.mean(hsv[..., 2])
        max_brightness = np.max(hsv[..., 2])

        # Contrast estimation
        gray = np.mean(image, axis=-1)
        contrast = np.std(gray) / 128

        warnings = []
        if max_saturation > self.max_saturation:
            warnings.append(f'High saturation ({max_saturation:.2f})')
        if max_brightness > self.max_brightness:
            warnings.append(f'High brightness ({max_brightness:.2f})')
        if contrast > self.max_contrast:
            warnings.append(f'High contrast ({contrast:.2f})')

        return {
            'avg_saturation': avg_saturation,
            'max_saturation': max_saturation,
            'avg_brightness': avg_brightness,
            'max_brightness': max_brightness,
            'contrast': contrast,
            'safe': len(warnings) == 0,
            'warnings': warnings
        }

    def get_css_filter(self, age_group: str = 'child') -> str:
        """Get CSS filter string for web use."""
        limits = self.age_adjustments.get(age_group, self.age_adjustments['child'])

        return (
            f"saturate({limits['saturation']*100:.0f}%) "
            f"brightness({limits['brightness']*100:.0f}%) "
            f"contrast({limits['contrast']*100:.0f}%)"
        )


def main():
    parser = argparse.ArgumentParser(description='Child-safe saturation filter')
    parser.add_argument('--age-group', type=str, default='child',
                       choices=['toddler', 'child', 'preteen'])
    parser.add_argument('--demo', action='store_true')

    args = parser.parse_args()

    filter_obj = ChildSafeSaturationFilter({})

    if args.demo:
        # Create test image with high saturation
        logger.info("Creating test image with high saturation/brightness")

        test_image = np.zeros((100, 100, 3), dtype=np.uint8)
        # Bright red quadrant
        test_image[:50, :50] = [255, 0, 0]
        # Bright green quadrant
        test_image[:50, 50:] = [0, 255, 0]
        # Bright blue quadrant
        test_image[50:, :50] = [0, 0, 255]
        # White quadrant
        test_image[50:, 50:] = [255, 255, 255]

        # Analyze original
        analysis = filter_obj.analyze_image(test_image)
        logger.info(f"\nOriginal image analysis:")
        logger.info(f"  Max saturation: {analysis['max_saturation']:.2f}")
        logger.info(f"  Max brightness: {analysis['max_brightness']:.2f}")
        logger.info(f"  Contrast: {analysis['contrast']:.2f}")
        logger.info(f"  Safe: {analysis['safe']}")
        if analysis['warnings']:
            for w in analysis['warnings']:
                logger.warning(f"  Warning: {w}")

        # Apply filter
        filtered = filter_obj.apply_filter(test_image, args.age_group)

        # Analyze filtered
        analysis = filter_obj.analyze_image(filtered)
        logger.info(f"\nFiltered image ({args.age_group}):")
        logger.info(f"  Max saturation: {analysis['max_saturation']:.2f}")
        logger.info(f"  Max brightness: {analysis['max_brightness']:.2f}")
        logger.info(f"  Contrast: {analysis['contrast']:.2f}")
        logger.info(f"  Safe: {analysis['safe']}")

        # CSS filter for web
        css = filter_obj.get_css_filter(args.age_group)
        logger.info(f"\nCSS filter: {css}")


if __name__ == '__main__':
    main()
