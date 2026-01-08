# Komal Privacy & Data Protection

## Sensitive Data Warning

**This project processes highly sensitive data involving children (ages 3-15):**
- Facial images and micro-expressions
- Eye-tracking and gaze patterns
- Touch/gesture behavioral data
- Audio recordings
- Session performance metrics

## Required Safeguards

### Data Collection
- [ ] Obtain **explicit parental/guardian consent** before any data collection
- [ ] Provide clear, age-appropriate privacy notices
- [ ] Allow data deletion requests within 30 days
- [ ] Minimize data collection to what's necessary

### Storage & Encryption
- [ ] Encrypt all PII at rest (AES-256 minimum)
- [ ] Use separate encryption keys per data type
- [ ] Store face/gaze data in restricted S3 bucket
- [ ] Enable access logging on all storage
- [ ] Implement key rotation every 90 days

### Access Control
- [ ] Role-based access (researcher, clinician, admin)
- [ ] Audit logs for all data access
- [ ] No raw data export without approval
- [ ] Multi-factor authentication required

### Processing
- [ ] Use federated learning for production deployments
- [ ] Enable differential privacy (ε ≤ 8.0)
- [ ] Secure aggregation for gradient updates
- [ ] No model memorization testing required

### Retention & Deletion
- [ ] Raw video/audio: Delete after feature extraction
- [ ] Processed features: 2-year retention max
- [ ] Aggregated analytics: May retain longer
- [ ] Automated deletion pipelines

## Compliance Requirements

| Regulation | Applies To | Key Requirements |
|------------|------------|------------------|
| COPPA | US users <13 | Parental consent, limited collection |
| GDPR | EU users | Consent, right to deletion, DPO |
| CCPA | California | Disclosure, opt-out rights |
| HIPAA | If medical | BAA, PHI protections |

**Consult legal counsel for deployment-specific compliance requirements.**

## Clinical Escalation

Auto-flag for clinician review if:
- Gaze avoidance >3 consecutive sessions
- Flat affect detected >80% of session
- Frustration without recovery pattern
- Sudden regression in metrics

## Contact

Data Protection Officer: {{DPO_EMAIL}}
Security Incidents: {{SECURITY_EMAIL}}

---
*This document provides guidelines only. Implement based on your jurisdiction and legal advice.*
