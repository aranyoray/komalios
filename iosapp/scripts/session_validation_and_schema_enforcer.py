#!/usr/bin/env python3
"""
session_validation_and_schema_enforcer.py — Validate session JSONs against schema.
Auto-correct safe issues, flag others for review.
"""

import argparse
import json
import logging
import re
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Any, Tuple
import numpy as np

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description='Validate and enforce session JSON schema')
    parser.add_argument('--input', type=str, required=True, help='Input session JSON')
    parser.add_argument('--output', type=str, help='Output validated JSON')
    parser.add_argument('--report', type=str, help='Validation report path')
    parser.add_argument('--auto_fix', action='store_true', help='Automatically fix safe issues')
    parser.add_argument('--require_human', action='store_true', help='Require human review for all fixes')
    parser.add_argument('--schema', type=str, help='Custom schema JSON file')
    return parser.parse_args()


# Default schema definition
DEFAULT_SCHEMA = {
    'required_fields': ['session_id', 'timestamp', 'child_age_bucket', 'consent'],
    'optional_fields': ['gaze_series', 'au_series', 'touch_events', 'metadata'],
    'field_types': {
        'session_id': 'string',
        'timestamp': 'datetime',
        'child_age_bucket': 'string',
        'consent': 'boolean',
        'gaze_series': 'array',
        'au_series': 'array',
        'touch_events': 'array',
        'duration': 'number'
    },
    'constraints': {
        'gaze_x': {'min': 0.0, 'max': 1.0},
        'gaze_y': {'min': 0.0, 'max': 1.0},
        'au_intensity': {'min': 0.0, 'max': 5.0},
        'fps': {'min': 1, 'max': 120},
        'duration': {'min': 0, 'max': 7200}  # Max 2 hours
    },
    'age_buckets': ['3-5', '6-8', '9-11', '12+', 'unknown']
}


class ValidationResult:
    """Container for validation results."""

    def __init__(self):
        self.errors: List[Dict] = []
        self.warnings: List[Dict] = []
        self.info: List[Dict] = []
        self.fixes_applied: List[Dict] = []

    def add_error(self, field: str, message: str, value: Any = None):
        self.errors.append({'severity': 'ERROR', 'field': field, 'message': message, 'value': value})

    def add_warning(self, field: str, message: str, value: Any = None):
        self.warnings.append({'severity': 'WARN', 'field': field, 'message': message, 'value': value})

    def add_info(self, field: str, message: str, value: Any = None):
        self.info.append({'severity': 'INFO', 'field': field, 'message': message, 'value': value})

    def add_fix(self, field: str, action: str, old_value: Any, new_value: Any, confidence: float):
        self.fixes_applied.append({
            'field': field,
            'action': action,
            'old_value': old_value,
            'new_value': new_value,
            'imputation_confidence': confidence
        })

    def is_valid(self) -> bool:
        return len(self.errors) == 0

    def to_dict(self) -> Dict:
        return {
            'is_valid': self.is_valid(),
            'errors': self.errors,
            'warnings': self.warnings,
            'info': self.info,
            'fixes_applied': self.fixes_applied
        }


def validate_types(data: Dict, schema: Dict, result: ValidationResult):
    """Validate field types."""
    type_map = schema.get('field_types', {})

    for field, expected_type in type_map.items():
        if field not in data:
            continue

        value = data[field]

        if expected_type == 'string' and not isinstance(value, str):
            result.add_error(field, f"Expected string, got {type(value).__name__}", value)

        elif expected_type == 'number' and not isinstance(value, (int, float)):
            result.add_error(field, f"Expected number, got {type(value).__name__}", value)

        elif expected_type == 'boolean' and not isinstance(value, bool):
            # Try to coerce
            if value in ['true', 'True', 1, '1', 'yes']:
                result.add_warning(field, "Coerced to boolean True", value)
            elif value in ['false', 'False', 0, '0', 'no']:
                result.add_warning(field, "Coerced to boolean False", value)
            else:
                result.add_error(field, f"Expected boolean, got {type(value).__name__}", value)

        elif expected_type == 'array' and not isinstance(value, list):
            result.add_error(field, f"Expected array, got {type(value).__name__}", value)

        elif expected_type == 'datetime':
            try:
                datetime.fromisoformat(value.replace('Z', '+00:00'))
            except (ValueError, AttributeError):
                result.add_error(field, "Invalid datetime format", value)


def validate_required_fields(data: Dict, schema: Dict, result: ValidationResult):
    """Check for required fields."""
    for field in schema.get('required_fields', []):
        if field not in data:
            result.add_error(field, f"Required field missing")
        elif data[field] is None:
            result.add_error(field, f"Required field is null")


def validate_constraints(data: Dict, schema: Dict, result: ValidationResult) -> List[Tuple[str, Any, Any]]:
    """Validate value constraints and return clamping suggestions."""
    clamps = []
    constraints = schema.get('constraints', {})

    for field, constraint in constraints.items():
        value = data.get(field)

        if value is None:
            continue

        min_val = constraint.get('min')
        max_val = constraint.get('max')

        if min_val is not None and value < min_val:
            result.add_warning(field, f"Value {value} below minimum {min_val}")
            clamps.append((field, value, min_val))

        if max_val is not None and value > max_val:
            result.add_warning(field, f"Value {value} above maximum {max_val}")
            clamps.append((field, value, max_val))

    return clamps


def validate_gaze_series(data: Dict, schema: Dict, result: ValidationResult) -> Dict:
    """Validate gaze time series data."""
    fixes = {}

    if 'gaze_series' not in data:
        return fixes

    series = data['gaze_series']
    if not series:
        return fixes

    # Check coordinate ranges
    gaze_constraint = schema['constraints'].get('gaze_x', {'min': 0, 'max': 1})

    for i, sample in enumerate(series):
        if isinstance(sample, dict):
            x = sample.get('x', sample.get('gaze_x', 0))
            y = sample.get('y', sample.get('gaze_y', 0))
        elif isinstance(sample, (list, tuple)) and len(sample) >= 2:
            x, y = sample[0], sample[1]
        else:
            continue

        # Check ranges
        if not (gaze_constraint['min'] <= x <= gaze_constraint['max']):
            result.add_warning('gaze_series', f"Gaze x out of range at index {i}", x)

        if not (gaze_constraint['min'] <= y <= gaze_constraint['max']):
            result.add_warning('gaze_series', f"Gaze y out of range at index {i}", y)

    # Check timestamp monotonicity
    if series and isinstance(series[0], dict) and 'timestamp' in series[0]:
        timestamps = [s['timestamp'] for s in series]
        for i in range(1, len(timestamps)):
            if timestamps[i] < timestamps[i-1]:
                result.add_error('gaze_series', f"Timestamp not monotonic at index {i}")
                break

    return fixes


def validate_session_length(data: Dict, result: ValidationResult):
    """Validate minimum session length."""
    duration = data.get('duration', 0)

    if duration < 30:
        result.add_warning('duration', f"Session very short: {duration}s")

    # Check if we can compute from series
    if duration == 0:
        for series_key in ['gaze_series', 'au_series']:
            series = data.get(series_key, [])
            if series and isinstance(series[0], dict) and 'timestamp' in series[0]:
                timestamps = [s['timestamp'] for s in series]
                computed_duration = max(timestamps) - min(timestamps)
                result.add_info('duration', f"Computed duration from {series_key}: {computed_duration}s")


def estimate_age_bucket(data: Dict) -> Tuple[str, float]:
    """Estimate age bucket using age estimator model."""
    # In production, would call age_estimator_small model
    # For now, return unknown with low confidence
    return 'unknown', 0.3


def infer_sample_rate(series: List) -> Tuple[float, float]:
    """Infer sample rate from timestamps."""
    if not series or len(series) < 2:
        return 0.0, 0.0

    if isinstance(series[0], dict) and 'timestamp' in series[0]:
        timestamps = [s['timestamp'] for s in series]
        diffs = np.diff(timestamps)
        mean_interval = np.mean(diffs)
        sample_rate = 1.0 / mean_interval if mean_interval > 0 else 0.0
        confidence = 1.0 - np.std(diffs) / (mean_interval + 1e-6)
        return sample_rate, max(0.0, min(1.0, confidence))

    return 0.0, 0.0


def apply_auto_fixes(data: Dict, schema: Dict, result: ValidationResult, args) -> Dict:
    """Apply automatic fixes where safe."""
    fixed_data = data.copy()

    # Fix missing age_bucket
    if 'child_age_bucket' not in fixed_data or fixed_data['child_age_bucket'] is None:
        bucket, confidence = estimate_age_bucket(fixed_data)
        fixed_data['child_age_bucket'] = bucket
        result.add_fix('child_age_bucket', 'estimated', None, bucket, confidence)

    # Fix missing consent (default to False for safety)
    if 'consent' not in fixed_data:
        fixed_data['consent'] = False
        result.add_fix('consent', 'defaulted', None, False, 1.0)
        result.add_warning('consent', "Consent defaulted to False - requires explicit consent")

    # Coerce boolean consent
    if 'consent' in fixed_data and not isinstance(fixed_data['consent'], bool):
        old_val = fixed_data['consent']
        fixed_data['consent'] = old_val in ['true', 'True', 1, '1', 'yes']
        result.add_fix('consent', 'coerced', old_val, fixed_data['consent'], 1.0)

    # Infer sample rate
    if 'gaze_sample_rate' not in fixed_data:
        series = fixed_data.get('gaze_series', [])
        rate, confidence = infer_sample_rate(series)
        if rate > 0:
            fixed_data['gaze_sample_rate'] = rate
            result.add_fix('gaze_sample_rate', 'inferred', None, rate, confidence)

    # Clamp out-of-range values
    clamps = validate_constraints(fixed_data, schema, ValidationResult())  # Re-check
    for field, old_val, new_val in clamps:
        if not args.require_human:
            fixed_data[field] = new_val
            result.add_fix(field, 'clamped', old_val, new_val, 0.8)

    return fixed_data


def main():
    args = parse_args()

    input_path = Path(args.input)
    output_path = Path(args.output) if args.output else input_path.with_suffix('.validated.json')
    report_path = Path(args.report) if args.report else input_path.with_suffix('.validation_report.json')

    # Load session data
    with open(input_path, 'r') as f:
        data = json.load(f)

    # Load schema
    if args.schema:
        with open(args.schema, 'r') as f:
            schema = json.load(f)
    else:
        schema = DEFAULT_SCHEMA

    # Validate
    result = ValidationResult()

    logger.info(f"Validating: {input_path}")

    validate_required_fields(data, schema, result)
    validate_types(data, schema, result)
    validate_constraints(data, schema, result)
    validate_gaze_series(data, schema, result)
    validate_session_length(data, result)

    # Apply fixes if requested
    if args.auto_fix and not args.require_human:
        data = apply_auto_fixes(data, schema, result, args)

    # Summary
    logger.info(f"Validation complete:")
    logger.info(f"  Errors: {len(result.errors)}")
    logger.info(f"  Warnings: {len(result.warnings)}")
    logger.info(f"  Fixes applied: {len(result.fixes_applied)}")

    if result.errors:
        for error in result.errors:
            logger.error(f"  {error['field']}: {error['message']}")

    # Save validated data
    with open(output_path, 'w') as f:
        json.dump(data, f, indent=2)
    logger.info(f"Validated data saved: {output_path}")

    # Save report
    report = {
        'input_file': str(input_path),
        'output_file': str(output_path),
        'timestamp': datetime.now().isoformat(),
        **result.to_dict()
    }

    with open(report_path, 'w') as f:
        json.dump(report, f, indent=2)
    logger.info(f"Validation report saved: {report_path}")

    return 0 if result.is_valid() else 1


if __name__ == '__main__':
    exit(main())
