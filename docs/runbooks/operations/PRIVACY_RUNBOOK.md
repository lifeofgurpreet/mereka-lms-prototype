# Data Privacy & GDPR Compliance Runbook

> **Spec**: `specs/data-privacy-gdpr-compliance_spec.md`
> **Owner**: platform-engineering
> **Last Updated**: 2026-02-19

This runbook covers operational procedures for GDPR/privacy compliance in the Mereka LMS platform.

## Scope

Operational playbooks for data subject requests, consent management, data retention, and regulatory compliance verification.

## Data Subject Request Handling

### Subject Access Request (SAR)

1. Receive request via privacy@mereka.io
2. Verify identity of requestor
3. Export user data from LMS:
   ```bash
   kubectl exec -n mereka-lms deployment/lms -- python manage.py export_user_data --username <user>
   ```
4. Review and redact sensitive third-party data
5. Deliver within 30 days

### Right to Erasure (RTBF)

1. Verify legal basis for erasure (no overriding legitimate interest)
2. Anonymize user records:
   ```bash
   kubectl exec -n mereka-lms deployment/lms -- python manage.py retire_user --username <user>
   ```
3. Log erasure in audit trail
4. Confirm deletion to requestor within 30 days

## Data Retention Verification

```bash
# Verify retention policy configuration
kubectl get configmap openedx-config-lms -n mereka-lms -o jsonpath='{.data}' | grep -i retention
```

## Consent Management

- Consent records stored in LMS MySQL (`student_courseenrollment` + consent tables)
- Third-party sharing consent managed via `enterprise-consent` service
- Audit trail: Open edX event tracking (`org.openedx.learning.student.registration.completed.v1`)

## Rollback / Incident Response

If an erasure job fails mid-run:
1. Check Celery task status in Redis
2. Re-run with `--dry-run` to verify state
3. Resume with `python manage.py retire_user --username <user> --force`

## References

- `specs/data-privacy-gdpr-compliance_spec.md`
- Open edX User Retirement: https://docs.openedx.org/en/latest/developers/references/user_retirement/index.html
