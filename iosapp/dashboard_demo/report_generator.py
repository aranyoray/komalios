#!/usr/bin/env python3
"""
Report Generator - Generate PDF/CSV reports from session data
Required packages: pandas, reportlab (for PDF)
"""

import json
import pandas as pd
from datetime import datetime
from pathlib import Path

def load_session_data(filepath):
    """Load session data from JSON file."""
    with open(filepath, 'r') as f:
        return json.load(f)

def generate_csv_report(sessions, output_path):
    """Generate CSV report from sessions."""
    df = pd.DataFrame(sessions)
    df.to_csv(output_path, index=False)
    return output_path

def generate_summary_stats(sessions):
    """Generate summary statistics."""
    df = pd.DataFrame(sessions)

    stats = {
        'total_sessions': len(df),
        'total_avatars': df['avatars_created'].sum() if 'avatars_created' in df else 0,
        'avg_duration': df['duration_min'].mean() if 'duration_min' in df else 0,
        'date_range': {
            'start': df['date'].min() if 'date' in df else None,
            'end': df['date'].max() if 'date' in df else None
        }
    }

    if 'primary_emotion' in df:
        emotion_counts = df['primary_emotion'].value_counts()
        stats['top_emotions'] = emotion_counts.head(5).to_dict()

    return stats

def generate_text_report(sessions, child_name='Child'):
    """Generate plain text report."""
    stats = generate_summary_stats(sessions)

    report = f"""
KOMAL ACTIVITY REPORT
=====================
Child: {child_name}
Generated: {datetime.now().strftime('%Y-%m-%d %H:%M')}

OVERVIEW
--------
Total Sessions: {stats['total_sessions']}
Total Avatars Created: {stats['total_avatars']}
Average Session Duration: {stats['avg_duration']:.1f} minutes

DATE RANGE
----------
First Session: {stats['date_range']['start']}
Last Session: {stats['date_range']['end']}

TOP EMOTIONS USED
-----------------
"""

    if 'top_emotions' in stats:
        for emotion, count in stats['top_emotions'].items():
            report += f"  {emotion}: {count}\n"

    report += "\n---\nPrivacy Note: All data processed locally.\n"

    return report

def main():
    """Demo report generation."""
    # Sample data
    sample_sessions = [
        {
            'session_id': 'sess_001',
            'date': '2024-01-15',
            'duration_min': 15,
            'avatars_created': 3,
            'primary_emotion': 'smile'
        },
        {
            'session_id': 'sess_002',
            'date': '2024-01-16',
            'duration_min': 20,
            'avatars_created': 2,
            'primary_emotion': 'excited'
        }
    ]

    # Generate reports
    print(generate_text_report(sample_sessions, 'Demo Child'))

    # CSV export
    output_dir = Path('./outputs')
    output_dir.mkdir(exist_ok=True)

    csv_path = generate_csv_report(sample_sessions, output_dir / 'demo_report.csv')
    print(f"\nCSV saved to: {csv_path}")

if __name__ == '__main__':
    main()
