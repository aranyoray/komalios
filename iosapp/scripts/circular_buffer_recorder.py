#!/usr/bin/env python3
"""
circular_buffer_recorder.py - Store only last N seconds of frames/audio

Auto-overwrites old data, flushes to disk only when session events
trigger retention.
"""

import argparse
import json
import time
import os
import logging
import numpy as np
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Any
from collections import deque
import threading

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class CircularBuffer:
    """Generic circular buffer with time-based expiry."""

    def __init__(self, max_duration_s: float, dtype: str = 'float32'):
        self.max_duration = max_duration_s
        self.dtype = dtype
        self.buffer = deque()
        self.lock = threading.Lock()

        # Stats
        self.total_added = 0
        self.total_expired = 0

    def add(self, data: Any, timestamp: Optional[float] = None):
        """Add data to buffer."""
        if timestamp is None:
            timestamp = time.time()

        with self.lock:
            self.buffer.append({
                'data': data,
                'timestamp': timestamp
            })
            self.total_added += 1

            # Expire old entries
            self._expire_old()

    def _expire_old(self):
        """Remove entries older than max_duration."""
        if not self.buffer:
            return

        cutoff = time.time() - self.max_duration

        while self.buffer and self.buffer[0]['timestamp'] < cutoff:
            self.buffer.popleft()
            self.total_expired += 1

    def get_all(self) -> List[Dict]:
        """Get all buffered data."""
        with self.lock:
            self._expire_old()
            return list(self.buffer)

    def get_range(self, start_time: float, end_time: float) -> List[Dict]:
        """Get data within time range."""
        with self.lock:
            self._expire_old()
            return [
                entry for entry in self.buffer
                if start_time <= entry['timestamp'] <= end_time
            ]

    def get_duration(self) -> float:
        """Get duration of buffered data."""
        if not self.buffer:
            return 0.0

        return self.buffer[-1]['timestamp'] - self.buffer[0]['timestamp']

    def get_count(self) -> int:
        """Get number of entries."""
        return len(self.buffer)

    def clear(self):
        """Clear buffer."""
        with self.lock:
            self.buffer.clear()

    def get_memory_estimate(self) -> int:
        """Estimate memory usage in bytes."""
        if not self.buffer:
            return 0

        # Estimate from first entry
        sample = self.buffer[0]['data']
        if isinstance(sample, np.ndarray):
            entry_size = sample.nbytes
        elif isinstance(sample, bytes):
            entry_size = len(sample)
        else:
            entry_size = 1000  # Rough estimate

        return entry_size * len(self.buffer)


class FrameBuffer(CircularBuffer):
    """Circular buffer for video frames."""

    def __init__(self, max_duration_s: float, frame_shape: tuple):
        super().__init__(max_duration_s, 'uint8')
        self.frame_shape = frame_shape

    def add_frame(self, frame: np.ndarray, timestamp: Optional[float] = None):
        """Add a video frame."""
        # Ensure correct shape
        if frame.shape != self.frame_shape:
            # Resize would go here
            pass

        self.add(frame, timestamp)


class AudioBuffer(CircularBuffer):
    """Circular buffer for audio data."""

    def __init__(self, max_duration_s: float, sample_rate: int = 16000):
        super().__init__(max_duration_s, 'float32')
        self.sample_rate = sample_rate

    def add_audio(self, samples: np.ndarray, timestamp: Optional[float] = None):
        """Add audio samples."""
        self.add(samples, timestamp)

    def get_audio_array(self) -> np.ndarray:
        """Get all audio as single array."""
        entries = self.get_all()
        if not entries:
            return np.array([])

        return np.concatenate([e['data'] for e in entries])


class CircularBufferRecorder:
    """Main recorder with circular buffers for frames and audio."""

    def __init__(self, config: Dict):
        self.config = config

        # Create buffers
        frame_duration = config.get('frame_buffer_duration_s', 30)
        audio_duration = config.get('audio_buffer_duration_s', 30)
        frame_shape = tuple(config.get('frame_shape', [480, 640, 3]))

        self.frame_buffer = FrameBuffer(frame_duration, frame_shape)
        self.audio_buffer = AudioBuffer(audio_duration, config.get('sample_rate', 16000))

        # Event buffer for triggers
        self.event_buffer = CircularBuffer(config.get('event_buffer_duration_s', 60))

        # Retention state
        self.retained_segments = []
        self.save_dir = Path(config.get('save_dir', 'retained_recordings'))
        self.save_dir.mkdir(exist_ok=True)

    def add_frame(self, frame: np.ndarray, timestamp: Optional[float] = None):
        """Add a video frame to buffer."""
        self.frame_buffer.add_frame(frame, timestamp)

    def add_audio(self, samples: np.ndarray, timestamp: Optional[float] = None):
        """Add audio samples to buffer."""
        self.audio_buffer.add_audio(samples, timestamp)

    def add_event(self, event_type: str, data: Dict, timestamp: Optional[float] = None):
        """Add an event to buffer."""
        event = {
            'type': event_type,
            'data': data
        }
        self.event_buffer.add(event, timestamp)

        # Check if event triggers retention
        if self._should_retain(event_type, data):
            self._retain_current_buffer(event_type)

    def _should_retain(self, event_type: str, data: Dict) -> bool:
        """Check if event should trigger retention."""
        retention_triggers = self.config.get('retention_triggers', [
            'emotion_spike',
            'attention_drop',
            'milestone',
            'user_request'
        ])

        return event_type in retention_triggers

    def _retain_current_buffer(self, trigger: str):
        """Flush current buffer to disk for retention."""
        timestamp = time.time()

        # Get current buffer contents
        frames = self.frame_buffer.get_all()
        audio = self.audio_buffer.get_all()
        events = self.event_buffer.get_all()

        if not frames and not audio:
            logger.debug("Nothing to retain")
            return

        # Create segment
        segment_id = f"segment_{int(timestamp)}"
        segment_dir = self.save_dir / segment_id
        segment_dir.mkdir(exist_ok=True)

        # Save metadata
        metadata = {
            'id': segment_id,
            'trigger': trigger,
            'timestamp': datetime.fromtimestamp(timestamp).isoformat(),
            'frame_count': len(frames),
            'audio_samples': sum(len(a['data']) for a in audio) if audio else 0,
            'event_count': len(events),
            'duration_s': self.frame_buffer.get_duration()
        }

        with open(segment_dir / 'metadata.json', 'w') as f:
            json.dump(metadata, f, indent=2)

        # Save frames
        if frames:
            frame_data = np.stack([f['data'] for f in frames])
            np.save(segment_dir / 'frames.npy', frame_data)

            frame_times = [f['timestamp'] for f in frames]
            np.save(segment_dir / 'frame_times.npy', frame_times)

        # Save audio
        if audio:
            audio_data = np.concatenate([a['data'] for a in audio])
            np.save(segment_dir / 'audio.npy', audio_data)

        # Save events
        if events:
            event_data = [
                {'timestamp': e['timestamp'], **e['data']}
                for e in events
            ]
            with open(segment_dir / 'events.json', 'w') as f:
                json.dump(event_data, f, indent=2)

        self.retained_segments.append(metadata)
        logger.info(f"Retained segment {segment_id}: {metadata['frame_count']} frames, "
                   f"{metadata['duration_s']:.1f}s, trigger: {trigger}")

    def get_stats(self) -> Dict:
        """Get recorder statistics."""
        return {
            'frame_buffer': {
                'count': self.frame_buffer.get_count(),
                'duration_s': self.frame_buffer.get_duration(),
                'memory_mb': self.frame_buffer.get_memory_estimate() / (1024 * 1024),
                'total_added': self.frame_buffer.total_added,
                'total_expired': self.frame_buffer.total_expired
            },
            'audio_buffer': {
                'count': self.audio_buffer.get_count(),
                'duration_s': self.audio_buffer.get_duration(),
                'memory_mb': self.audio_buffer.get_memory_estimate() / (1024 * 1024)
            },
            'retained_segments': len(self.retained_segments),
            'total_retained_frames': sum(s['frame_count'] for s in self.retained_segments)
        }


def run_demo(recorder: CircularBufferRecorder, duration: int = 30):
    """Run demo of circular buffer recorder."""
    logger.info(f"Running recorder demo for {duration}s")

    start = time.time()
    frame_interval = 1.0 / 30  # 30 FPS
    audio_interval = 0.1  # 100ms chunks

    frame_count = 0
    last_frame = 0
    last_audio = 0

    while time.time() - start < duration:
        now = time.time()

        # Add frames
        if now - last_frame >= frame_interval:
            frame = np.random.randint(0, 255, (480, 640, 3), dtype=np.uint8)
            recorder.add_frame(frame)
            frame_count += 1
            last_frame = now

        # Add audio
        if now - last_audio >= audio_interval:
            samples = np.random.randn(1600).astype(np.float32)
            recorder.add_audio(samples)
            last_audio = now

        # Simulate events
        elapsed = now - start
        if int(elapsed) == 10:
            recorder.add_event('attention_drop', {'value': 0.3})
        elif int(elapsed) == 20:
            recorder.add_event('emotion_spike', {'emotion': 'happy', 'intensity': 0.9})

        time.sleep(0.01)

    # Final stats
    stats = recorder.get_stats()
    logger.info(f"\n=== Recorder Stats ===")
    logger.info(f"Total frames added: {stats['frame_buffer']['total_added']}")
    logger.info(f"Frames expired: {stats['frame_buffer']['total_expired']}")
    logger.info(f"Current buffer: {stats['frame_buffer']['count']} frames")
    logger.info(f"Buffer duration: {stats['frame_buffer']['duration_s']:.1f}s")
    logger.info(f"Frame buffer memory: {stats['frame_buffer']['memory_mb']:.1f} MB")
    logger.info(f"Retained segments: {stats['retained_segments']}")


def main():
    parser = argparse.ArgumentParser(description='Circular buffer recorder')
    parser.add_argument('--frame-duration', type=float, default=30, help='Frame buffer duration (s)')
    parser.add_argument('--audio-duration', type=float, default=30, help='Audio buffer duration (s)')
    parser.add_argument('--save-dir', type=str, default='retained_recordings', help='Save directory')
    parser.add_argument('--duration', type=int, default=30, help='Demo duration')
    parser.add_argument('--demo', action='store_true', help='Run demo')

    args = parser.parse_args()

    config = {
        'frame_buffer_duration_s': args.frame_duration,
        'audio_buffer_duration_s': args.audio_duration,
        'save_dir': args.save_dir,
        'frame_shape': [480, 640, 3],
        'sample_rate': 16000,
        'retention_triggers': ['emotion_spike', 'attention_drop', 'milestone']
    }

    recorder = CircularBufferRecorder(config)

    if args.demo:
        run_demo(recorder, args.duration)
    else:
        logger.info("Use --demo to run demonstration")


if __name__ == '__main__':
    main()
