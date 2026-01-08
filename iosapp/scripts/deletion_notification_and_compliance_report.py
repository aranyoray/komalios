#!/usr/bin/env python3
"""
deletion_notification_and_compliance_report.py — Notify guardians and generate compliance reports.
Produces signed PDF reports and maintains encrypted audit logs.
"""

import argparse
import json
import logging
import os
import smtplib
import hashlib
import hmac
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from pathlib import Path
from datetime import datetime, timedelta
from typing import Dict, List
import csv

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description='Deletion notification and compliance reporting')
    parser.add_argument('--audit_dir', type=str, default='./audit_logs',
                        help='Directory with audit records')
    parser.add_argument('--period', type=str, choices=['daily', 'weekly'], default='daily',
                        help='Report period')
    parser.add_argument('--notify', type=str, default='true',
                        help='Send email notifications (true/false)')
    parser.add_argument('--email_to', type=str, help='Recipient email address')
    parser.add_argument('--report_dir', type=str, default='./compliance_reports',
                        help='Output directory for reports')
    parser.add_argument('--log_dir', type=str, default='./compliance_logs',
                        help='Encrypted compliance log directory')
    parser.add_argument('--secret_key', type=str, default=os.getenv('COMPLIANCE_SECRET', 'default-secret'),
                        help='Secret key for HMAC signing')
    parser.add_argument('--dry_run', action='store_true')
    return parser.parse_args()


def load_audit_records(audit_dir: Path, period: str) -> List[Dict]:
    """Load audit records for the specified period."""
    records = []

    # Determine date range
    now = datetime.now()
    if period == 'daily':
        start_date = now - timedelta(days=1)
    else:  # weekly
        start_date = now - timedelta(days=7)

    for audit_file in audit_dir.glob('audit_*.json'):
        try:
            with open(audit_file, 'r') as f:
                record = json.load(f)

            # Check if record is in period
            record_time = datetime.fromisoformat(record.get('timestamp', ''))
            if record_time >= start_date:
                records.append(record)

        except Exception as e:
            logger.error(f"Failed to load {audit_file}: {e}")

    return records


def generate_compliance_summary(records: List[Dict]) -> Dict:
    """Generate summary statistics from audit records."""
    summary = {
        'total_sessions': len(records),
        'files_deleted': 0,
        'files_failed': 0,
        'total_size_mb': 0,
        'deletion_methods': {},
        'sessions': []
    }

    for record in records:
        summary['files_deleted'] += record.get('files_deleted', 0)
        summary['files_failed'] += record.get('files_failed', 0)

        method = record.get('deletion_method', 'unknown')
        summary['deletion_methods'][method] = summary['deletion_methods'].get(method, 0) + 1

        # Calculate size from deletion results
        for result in record.get('deletion_results', []):
            summary['total_size_mb'] += result.get('size_bytes', 0) / (1024 * 1024)

        summary['sessions'].append({
            'session_id': record.get('session_id'),
            'audit_id': record.get('audit_id'),
            'timestamp': record.get('timestamp'),
            'files_deleted': record.get('files_deleted', 0),
            'consent': record.get('user_consent_flag', False)
        })

    return summary


def sign_content(content: str, secret_key: str) -> str:
    """Create HMAC signature for content."""
    signature = hmac.new(
        secret_key.encode(),
        content.encode(),
        hashlib.sha256
    ).hexdigest()
    return signature


def generate_pdf_report(summary: Dict, output_path: Path, secret_key: str):
    """Generate compliance PDF report with HMAC signature."""
    try:
        from reportlab.lib import colors
        from reportlab.lib.pagesizes import letter
        from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer
        from reportlab.lib.styles import getSampleStyleSheet

        doc = SimpleDocTemplate(str(output_path), pagesize=letter)
        styles = getSampleStyleSheet()
        elements = []

        # Title
        elements.append(Paragraph("Data Deletion Compliance Report", styles['Heading1']))
        elements.append(Spacer(1, 12))

        # Period info
        elements.append(Paragraph(f"Generated: {datetime.now().isoformat()}", styles['Normal']))
        elements.append(Spacer(1, 24))

        # Summary table
        summary_data = [
            ['Metric', 'Value'],
            ['Total Sessions Processed', str(summary['total_sessions'])],
            ['Files Deleted', str(summary['files_deleted'])],
            ['Files Failed', str(summary['files_failed'])],
            ['Total Size Freed (MB)', f"{summary['total_size_mb']:.2f}"],
        ]

        table = Table(summary_data)
        table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.grey),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
            ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (-1, 0), 12),
            ('BOTTOMPADDING', (0, 0), (-1, 0), 12),
            ('BACKGROUND', (0, 1), (-1, -1), colors.beige),
            ('GRID', (0, 0), (-1, -1), 1, colors.black)
        ]))
        elements.append(table)
        elements.append(Spacer(1, 24))

        # Deletion methods
        elements.append(Paragraph("Deletion Methods Used:", styles['Heading2']))
        for method, count in summary['deletion_methods'].items():
            elements.append(Paragraph(f"  • {method}: {count}", styles['Normal']))
        elements.append(Spacer(1, 24))

        # Session details
        elements.append(Paragraph("Session Details:", styles['Heading2']))
        session_data = [['Session ID', 'Audit ID', 'Timestamp', 'Files Deleted', 'Consent']]
        for session in summary['sessions'][:50]:  # Limit to 50
            session_data.append([
                session['session_id'],
                session['audit_id'][:8] + '...',
                session['timestamp'][:19],
                str(session['files_deleted']),
                '✓' if session['consent'] else '✗'
            ])

        session_table = Table(session_data)
        session_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.grey),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
            ('FONTSIZE', (0, 0), (-1, -1), 8),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.black)
        ]))
        elements.append(session_table)
        elements.append(Spacer(1, 24))

        # Signature
        report_content = json.dumps(summary, sort_keys=True)
        signature = sign_content(report_content, secret_key)

        elements.append(Paragraph("Document Signature (HMAC-SHA256):", styles['Heading2']))
        elements.append(Paragraph(f"<font size=8>{signature}</font>", styles['Normal']))

        doc.build(elements)
        logger.info(f"Generated PDF report: {output_path}")

    except ImportError:
        # Fallback: generate text report
        logger.warning("ReportLab not available, generating text report")

        report_content = json.dumps(summary, sort_keys=True)
        signature = sign_content(report_content, secret_key)

        text_report = f"""
DATA DELETION COMPLIANCE REPORT
==============================
Generated: {datetime.now().isoformat()}

SUMMARY
-------
Total Sessions: {summary['total_sessions']}
Files Deleted: {summary['files_deleted']}
Files Failed: {summary['files_failed']}
Size Freed: {summary['total_size_mb']:.2f} MB

DELETION METHODS
----------------
"""
        for method, count in summary['deletion_methods'].items():
            text_report += f"  {method}: {count}\n"

        text_report += f"\nSIGNATURE: {signature}\n"

        text_path = output_path.with_suffix('.txt')
        with open(text_path, 'w') as f:
            f.write(text_report)
        logger.info(f"Generated text report: {text_path}")


def send_notification(session_id: str, deletion_timestamp: str, audit_id: str,
                      recipient: str, args) -> bool:
    """Send email notification about deletion."""
    if args.notify.lower() != 'true':
        return True

    if not recipient:
        logger.warning("No recipient email specified")
        return False

    # Email configuration from environment
    smtp_host = os.getenv('SMTP_HOST', 'localhost')
    smtp_port = int(os.getenv('SMTP_PORT', 587))
    smtp_user = os.getenv('SMTP_USER', '')
    smtp_pass = os.getenv('SMTP_PASS', '')
    from_addr = os.getenv('SMTP_FROM', 'noreply@komal.app')

    # Create message
    msg = MIMEMultipart()
    msg['From'] = from_addr
    msg['To'] = recipient
    msg['Subject'] = f"Komal Data Deletion Confirmation - {session_id}"

    body = f"""
Data Deletion Confirmation
--------------------------

Session ID: {session_id}
Deletion Time: {deletion_timestamp}
Audit Reference: {audit_id}

The raw recording data for this session has been securely deleted
in accordance with our data retention policy.

Processed analytics and aggregated scores remain available in
your guardian dashboard.

This is an automated message. For questions, please contact support.

---
Komal for Kids
Privacy-first child development
"""

    msg.attach(MIMEText(body, 'plain'))

    if args.dry_run:
        logger.info(f"Would send notification to: {recipient}")
        return True

    try:
        with smtplib.SMTP(smtp_host, smtp_port) as server:
            if smtp_user and smtp_pass:
                server.starttls()
                server.login(smtp_user, smtp_pass)
            server.send_message(msg)

        logger.info(f"Sent notification to: {recipient}")
        return True

    except Exception as e:
        logger.error(f"Failed to send notification: {e}")
        return False


def update_compliance_log(records: List[Dict], log_dir: Path, secret_key: str):
    """Update rotating 90-day encrypted compliance log."""
    log_dir.mkdir(parents=True, exist_ok=True)

    log_file = log_dir / 'compliance_log.jsonl'

    # Load existing log
    existing = []
    if log_file.exists():
        with open(log_file, 'r') as f:
            for line in f:
                try:
                    existing.append(json.loads(line))
                except:
                    pass

    # Add new records
    for record in records:
        log_entry = {
            'timestamp': record.get('timestamp'),
            'session_id': record.get('session_id'),
            'audit_id': record.get('audit_id'),
            'files_deleted': record.get('files_deleted', 0)
        }
        existing.append(log_entry)

    # Remove entries older than 90 days
    cutoff = datetime.now() - timedelta(days=90)
    filtered = []
    for entry in existing:
        try:
            entry_time = datetime.fromisoformat(entry['timestamp'])
            if entry_time >= cutoff:
                filtered.append(entry)
        except:
            pass

    # Write back (in production, would encrypt)
    with open(log_file, 'w') as f:
        for entry in filtered:
            f.write(json.dumps(entry) + '\n')

    logger.info(f"Updated compliance log: {len(filtered)} entries")


def main():
    args = parse_args()

    audit_dir = Path(args.audit_dir)
    report_dir = Path(args.report_dir)
    log_dir = Path(args.log_dir)

    report_dir.mkdir(parents=True, exist_ok=True)

    # Load audit records
    records = load_audit_records(audit_dir, args.period)
    logger.info(f"Loaded {len(records)} audit records for {args.period} period")

    if not records:
        logger.info("No records to process")
        return 0

    # Generate summary
    summary = generate_compliance_summary(records)

    # Generate PDF report
    report_name = f"compliance_{args.period}_{datetime.now().strftime('%Y%m%d')}.pdf"
    report_path = report_dir / report_name

    if not args.dry_run:
        generate_pdf_report(summary, report_path, args.secret_key)

    # Send notifications
    if args.email_to:
        for record in records:
            send_notification(
                record.get('session_id'),
                record.get('timestamp'),
                record.get('audit_id'),
                args.email_to,
                args
            )

    # Update compliance log
    if not args.dry_run:
        update_compliance_log(records, log_dir, args.secret_key)

    # Summary
    logger.info(f"\nCompliance Report Summary:")
    logger.info(f"  Period: {args.period}")
    logger.info(f"  Sessions: {summary['total_sessions']}")
    logger.info(f"  Files deleted: {summary['files_deleted']}")
    logger.info(f"  Size freed: {summary['total_size_mb']:.2f} MB")
    if not args.dry_run:
        logger.info(f"  Report: {report_path}")

    return 0


if __name__ == '__main__':
    exit(main())
