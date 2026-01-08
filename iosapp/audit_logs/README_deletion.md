# Deletion Audit Documentation

## Overview

This directory contains immutable audit records for all data deletion operations in the Komal system. Every deletion of raw recordings is logged with full traceability.

## Audit Record Format

Each audit record (`audit_<session_id>.json`) contains:

```json
{
  "audit_id": "uuid",
  "session_id": "session identifier",
  "timestamp": "ISO8601 timestamp",
  "start_time": "operation start",
  "end_time": "operation end",
  "analytics_checksum": "SHA256 of session_scores.json",
  "deletion_results": [...],
  "deletion_method": "method used",
  "files_deleted": count,
  "files_failed": count,
  "user_consent_flag": boolean,
  "operator_id": "optional operator"
}
```

## Deletion Methods

### Secure Deletion (for raw recordings)
1. **mmap_overwrite**: Memory-mapped file overwritten with random data (3 passes)
2. **file_overwrite**: Standard file overwrite with random data (3 passes)
3. **shred_command**: System `shred` utility
4. **unlink_only**: Simple deletion (fallback when overwrite fails)

### Verification
- Post-deletion verification attempts to read deleted keys
- Failed deletions are quarantined to encrypted storage
- Quarantine alerts are generated for manual review

## Scripts

- `audit_and_autodelete_pipeline.py` - Main deletion pipeline
- `safe_retention_policy_enforcer.py` - Policy enforcement
- `secure_delete_kv_store.py` - Redis/cache deletion
- `deletion_notification_and_compliance_report.py` - Compliance reporting

## Compliance

- Audit records are immutable (chmod 444)
- 90-day encrypted compliance log maintained
- Weekly compliance reports with HMAC signatures
- Guardian notifications sent after deletion

## Modifying Deletion Logic

When modifying any deletion-related code:

1. Update this documentation
2. Add unit tests for new deletion methods
3. Ensure audit logging is preserved
4. Test quarantine failsafe
5. Update CI/CD pipeline checks

## Quarantine Process

Files that fail secure deletion are moved to `./quarantine/` with:
- Timestamp prefix
- Original filename preserved
- Alert created in `./alerts/quarantine_notify.json`

## Contact

For compliance questions or audit requests, contact the data protection team.

---
Last updated: 2024-01-15
