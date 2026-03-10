# Email Pipeline Reference
_Audience: Platform Operators • Owner: Platform Team • Last verified: 2026-03-10 • Status: canonical_

This reference records the steady-state infrastructure facts for the email delivery path.

## SMTP endpoint

- AWS SES SMTP endpoint: `email-smtp.ap-southeast-1.amazonaws.com`
- Expected transport: port `587` with `STARTTLS`

## Current system shape

- Production email delivery is expected to use SMTP, not console or file backends.
- Domain and sender records are tracked in [`EMAIL_DNS_RECORDS.md`](EMAIL_DNS_RECORDS.md).
- Operational procedures belong in [`../../ops/runbooks/EMAIL_NOTIFICATIONS_RUNBOOK.md`](../../ops/runbooks/EMAIL_NOTIFICATIONS_RUNBOOK.md).

## Sender identity

- per-tenant sender configuration is allowed where required
- tenant-specific sender handling should remain consistent with the DNS and LMS configuration surfaces
- the reference term used across docs and checks is `TENANT_EMAIL_SENDERS`

## Verification

- `bash scripts/qa/verify-email-notifications-pipeline.sh`

## Related docs

- [`EMAIL_DNS_RECORDS.md`](EMAIL_DNS_RECORDS.md)
- [`../../ops/runbooks/EMAIL_NOTIFICATIONS_RUNBOOK.md`](../../ops/runbooks/EMAIL_NOTIFICATIONS_RUNBOOK.md)
