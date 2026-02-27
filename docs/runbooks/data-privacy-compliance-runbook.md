# Data Privacy & GDPR Compliance Runbook
_Audience: Platform Eng + Legal + Operations • Owner: Engineering Lead • Last updated: 2026-02-10_

This runbook covers operational procedures for GDPR/PDPA compliance, data deletion, and data portability.

> **Status**: Compliance framework is **not yet implemented** (Tier 5). This runbook documents target-state procedures.
> **Spec**: `specs/data-privacy-gdpr-compliance_spec.md`
> **Testmap**: `specs/testmaps/data-privacy-gdpr-compliance_spec.testmap.yml`

## Prerequisites

- Django admin access (`/admin/`)
- Database read access (for verification)
- Infisical access for compliance service credentials
- Legal counsel approval for deletion/export workflows

---

## Processing a Data Subject Access Request (DSAR)

### Procedure
1. Receive verified DSAR from learner via support ticket
2. Verify identity using multi-factor authentication
3. Initiate data export via Django admin:
   ```bash
   kubectl exec -n mereka-lms -l app.kubernetes.io/name=lms -- \
     python manage.py lms export_user_data --username <username> --output /tmp/export.zip
   ```
4. Download export archive:
   ```bash
   kubectl cp mereka-lms/<pod-name>:/tmp/export.zip ./user-export.zip
   ```
5. Verify export contains all PII categories:
   - User profile (name, email, DOB, location)
   - Enrollment records
   - Course progress and grades
   - Forum posts and replies
   - Certificates issued
   - Purchase history (if applicable)
6. Encrypt export with GPG using user's public key
7. Deliver via secure channel (registered email or secure portal)

### Acceptance
- Export completes within 72 hours of verified request
- Archive is machine-readable (JSON + CSV format)
- All PII fields are included per data map
- Delivery receipt is logged for audit

---

## Processing a Right to Be Forgotten Request (Data Deletion)

### Procedure
1. Receive verified deletion request from learner
2. Verify no legal hold or retention requirement
3. Initiate deletion pipeline via Django admin:
   ```bash
   kubectl exec -n mereka-lms -l app.kubernetes.io/name=lms -- \
     python manage.py lms delete_user_data --username <username> --confirm
   ```
4. Monitor deletion progress across all data stores:
   - MySQL: User, profile, enrollments, grades
   - MongoDB Atlas: Forum posts (anonymized), modulestore metadata
   - PostgreSQL: Purchase history (anonymized)
   - Redis: Session and cache data
   - ClickHouse: Analytics events (anonymized)
   - Object storage: Profile images, certificate PDFs
   - Loki: Application logs (PII redacted)
5. Verify deletion completion:
   ```bash
   kubectl exec -n mereka-lms -l app.kubernetes.io/name=lms -- \
     python manage.py lms verify_user_deletion --username <username>
   ```
6. Generate cryptographic deletion proof
7. Send confirmation email to user

### Acceptance
- Deletion completes within 30 days of verified request
- All PII is removed or anonymized across 8+ data stores
- Cryptographic proof of deletion is generated
- Deletion cannot be reversed
- User receives confirmation email

---

## Managing Consent Records

### Procedure
1. Review user consent records via Django admin:
   - Navigate to **Consent** → **Data Consent Records**
2. Filter by user, consent type, or date range
3. Update consent status (granted/withdrawn):
   - User withdraws consent via account settings
   - Consent service updates record with timestamp
4. Verify consent enforcement:
   - Analytics events respect opt-out settings
   - Marketing emails respect unsubscribe status
   - Cookies respect cookie consent settings

### Acceptance
- All consent changes are timestamped and versioned
- Consent withdrawal takes effect within 24 hours
- Audit trail captures all consent changes
- GDPR lawful basis is recorded for each processing activity

---

## PII Leakage Detection

### Procedure
1. Run automated PII scan on logs and metrics:
   ```bash
   kubectl exec -n mereka-lms -l app.kubernetes.io/name=lms -- \
     python manage.py lms scan_pii_leakage --days 7 --output /tmp/pii-scan.json
   ```
2. Review scan results for detected PII:
   - Email addresses in log messages
   - Phone numbers in exception traces
   - Names in metric labels
3. For each detected leak:
   - Identify source code location
   - Add redaction/sanitization at log emission point
   - Update Loki/Promtail config to redact PII patterns
4. Verify fix by re-running scan
5. Alert engineering team if leak persists

### Acceptance
- PII scan runs automatically every 24 hours
- Detected leaks are flagged in compliance dashboard
- Engineering is notified within 1 hour of detection
- Leak rate < 0.1% of log entries

---

## Handling a Data Breach

### Procedure (CRITICAL)
1. **Detect**: Breach detected via monitoring, user report, or security scan
2. **Contain**: Immediately isolate affected systems
   ```bash
   # Example: Scale down affected service
   kubectl scale deployment <affected-service> --replicas=0 -n mereka-lms
   ```
3. **Assess**:
   - Identify PII fields exposed
   - Estimate number of affected users
   - Determine breach scope (internal/external)
4. **Notify**:
   - **Within 72 hours** (GDPR requirement): Notify supervisory authority
   - Notify affected users if high risk to rights and freedoms
   - Use breach notification template from legal team
5. **Document**:
   - Record breach in incident log
   - Capture timeline, scope, affected data, remediation
6. **Remediate**:
   - Fix vulnerability that caused breach
   - Implement additional controls
   - Update runbooks to prevent recurrence

### Acceptance
- Breach notification sent within 72 hours (GDPR)
- Incident commander assigned within 1 hour
- Root cause analysis completed within 7 days
- Post-mortem document published to team

---

## Data Retention Policy Enforcement

### Procedure
1. Review retention policies in `specs/data-privacy-gdpr-compliance_spec.md`
2. Run automated retention cleanup:
   ```bash
   kubectl exec -n mereka-lms -l app.kubernetes.io/name=lms -- \
     python manage.py lms enforce_retention_policy --dry-run
   ```
3. Review dry-run output for records eligible for deletion
4. Execute cleanup (non-dry-run):
   ```bash
   kubectl exec -n mereka-lms -l app.kubernetes.io/name=lms -- \
     python manage.py lms enforce_retention_policy
   ```
5. Verify deletions in compliance dashboard

### Acceptance
- Retention cleanup runs automatically monthly
- Records past retention period are deleted or anonymized
- Compliance dashboard shows retention adherence percentage
- Legal hold records are excluded from automated cleanup

---

## Generating Compliance Reports

### Procedure
1. Access compliance dashboard at `https://compliance.academyv2.mereka.io`
2. Select report type:
   - **GDPR Compliance Status**: Consent coverage, DSAR metrics, deletion metrics
   - **Data Processor Inventory**: Third-party processors, DPA status
   - **PII Leakage Report**: Recent scans, detected leaks, remediation status
   - **Breach Log**: All reported breaches, status, notifications
3. Set date range and tenant filter (if applicable)
4. Click **Generate Report** (PDF or CSV)
5. Download report for audit or legal review

### Acceptance
- Reports are available on-demand within 5 minutes
- Reports include all required compliance metrics
- Reports can be filtered by tenant for enterprise clients
- Report generation is logged for audit

---

## Related Documentation
- **Spec**: `specs/data-privacy-gdpr-compliance_spec.md`
- **Architecture**: `docs/architecture/multi-tenancy-overview.md`
- **General Troubleshooting**: `docs/operations/TROUBLESHOOTING.md`
