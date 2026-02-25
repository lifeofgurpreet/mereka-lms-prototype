# Email Pipeline Operations Guide

<!-- @covers AC-003, AC-004, AC-005, AC-006, AC-008, AC-111, AC-112 -->
<!-- @spec: email-notifications-pipeline_spec.md -->

This document describes the production email delivery infrastructure for Mereka Academy, credential management, email types, monitoring, and troubleshooting procedures.

## Architecture Overview

```
Open edX LMS (Django)
  └── ACE (Automated Communication Engine)
        └── django_email channel
              └── Django SMTP backend
                    └── AWS SES SMTP relay
                          email-smtp.ap-southeast-1.amazonaws.com:587 (STARTTLS)
```

All transactional email sent by Open edX flows through Django's email backend. The backend is configured to use AWS SES via SMTP (STARTTLS on port 587). Push and in-app notification channels are planned for a future phase.

## SES SMTP Configuration

### Connection Parameters

| Parameter | Value |
|-----------|-------|
| `EMAIL_HOST` | `email-smtp.ap-southeast-1.amazonaws.com` |
| `EMAIL_PORT` | `587` |
| `EMAIL_USE_TLS` | `True` (STARTTLS) |
| `EMAIL_USE_SSL` | `False` |
| `EMAIL_HOST_USER` | IAM SMTP username (from `openedx-secrets` K8s secret) |
| `EMAIL_HOST_PASSWORD` | IAM SMTP password (from `openedx-secrets` K8s secret) |
| `DEFAULT_FROM_EMAIL` | `"Mereka Academy" <no-reply@academyv2.mereka.io>` |
| `SERVER_EMAIL` | `admin@academyv2.mereka.io` |

### ACE Channel Configuration

The Automated Communication Engine (ACE) is the message dispatch layer for Open edX. It routes notification events to registered delivery channels.

```python
# Production LMS settings
ACE_ENABLED_CHANNELS = ["django_email"]
ACE_CHANNEL_DEFAULT_EMAIL = "django_email"
BULK_EMAIL_SEND_USING_EDX_ACE = True
```

System-critical emails (password reset, account activation) are non-suppressible: they are delivered regardless of a user's notification preferences. These message types bypass the preference check in ACE dispatch.

## Credential Management

### Secret Pipeline

```
Infisical (source of truth)
  → GCP Secret Manager (bbi-k8 project)
    → ExternalSecret (openedx-secrets)
      → K8s Secret (openedx-secrets in mereka-lms namespace)
        → LMS pod env vars
```

### Secret Names

| Infisical / GCP SM Key | K8s Secret Key | Purpose |
|------------------------|----------------|---------|
| `MEREKA_LMS_EMAIL_HOST_USER` | `EMAIL_HOST_USER` | SES SMTP username |
| `MEREKA_LMS_EMAIL_HOST_PASSWORD` | `EMAIL_HOST_PASSWORD` | SES SMTP password |
| `MEREKA_LMS_SES_SNS_WEBHOOK_SECRET` | `SES_SNS_WEBHOOK_SECRET` | SNS webhook HMAC verification |
| `MEREKA_LMS_UNSUBSCRIBE_HMAC_SECRET` | `UNSUBSCRIBE_HMAC_SECRET` | One-click unsubscribe token signing |

### Generating SES SMTP Credentials

SES SMTP credentials are derived from IAM access keys using a signing formula. They are NOT the same as IAM access keys.

```bash
# 1. Create an IAM user with SES send permissions
aws iam create-user --user-name ses-smtp-mereka-lms

aws iam attach-user-policy \
  --user-name ses-smtp-mereka-lms \
  --policy-arn arn:aws:iam::aws:policy/AmazonSESFullAccess

# 2. Create an access key
aws iam create-access-key --user-name ses-smtp-mereka-lms

# 3. Convert the secret access key to an SMTP password using the AWS formula:
#    https://docs.aws.amazon.com/ses/latest/dg/smtp-credentials.html
#    Python utility: scripts/infra/ses-smtp-password.py

# 4. Store in Infisical
cd /home/gurpreet/projects/k8s/reka-slackbot
infisical secrets set MEREKA_LMS_EMAIL_HOST_USER="<SMTP_USERNAME>" \
  --domain https://secrets.mereka.io/api --env prod --path /
infisical secrets set MEREKA_LMS_EMAIL_HOST_PASSWORD="<SMTP_PASSWORD>" \
  --domain https://secrets.mereka.io/api --env prod --path /

# 5. Sync to GCP Secret Manager
printf '%s' '<SMTP_USERNAME>' | gcloud secrets create MEREKA_LMS_EMAIL_HOST_USER \
  --data-file=- --project=bbi-k8
printf '%s' '<SMTP_PASSWORD>' | gcloud secrets create MEREKA_LMS_EMAIL_HOST_PASSWORD \
  --data-file=- --project=bbi-k8

# 6. ExternalSecret will sync to K8s within 1 hour, or force refresh:
kubectl annotate externalsecret openedx-secrets -n mereka-lms \
  force-sync=$(date +%s) --overwrite
```

## Email Types

### Transactional (System-Critical, Non-Suppressible)

These are delivered regardless of user notification preferences:

| Event | Open edX Signal | From Address |
|-------|----------------|--------------|
| Password reset | `account.password_reset_requested` | `no-reply@academyv2.mereka.io` |
| Account activation | `account.email_change_requested` | `no-reply@academyv2.mereka.io` |
| Certificate issued | `course.certificate_created` | `no-reply@academyv2.mereka.io` |

### Transactional (User-Suppressible)

| Event | Default | Channel |
|-------|---------|---------|
| Course enrollment confirmation | Enabled | `django_email` |
| Grade posted | Enabled | `django_email` |
| Discussion reply | Enabled | `django_email` |
| Course announcement | Enabled | `django_email` |

### Marketing / Bulk (Opt-In Required)

`bulk_campaign` emails require explicit opt-in. Users who have not opted in do not receive bulk campaign emails. The `BULK_EMAIL_SEND_USING_EDX_ACE` setting routes all bulk email through ACE so that preference checks are enforced.

## Per-Tenant Sender Identities

Enterprise tenants can customize the display name in the `From` header while sharing the verified sending domain. This avoids the need to verify additional SES identities per tenant.

```python
# Planned configuration in production.py (AC-005)
TENANT_EMAIL_SENDERS = {
    "default": {
        "display_name": "Mereka Academy",
        "from_address": "no-reply@academyv2.mereka.io",
    },
    "biji-biji": {
        "display_name": "Biji-Biji Initiative",
        "from_address": "no-reply@academy.biji-biji.com",
    },
}
DEFAULT_FROM_EMAIL = '"Mereka Academy" <no-reply@academyv2.mereka.io>'
```

See `docs/operations/EMAIL_DNS_RECORDS.md` for DNS verification requirements for each sender domain.

## Dev / Staging Environment (rke2-nonprod, *.mereka.dev)

The nonprod cluster (`academyv2.mereka.dev`) uses the same SES account and SMTP credentials as production. This means email sent from nonprod goes through the live SES endpoint.

**To avoid sending test emails to real users:**

1. Set `DEFAULT_FROM_EMAIL` in the nonprod overlay to a clearly labelled sender:
   ```
   "Mereka Academy [TEST]" <no-reply@academyv2.mereka.dev>
   ```
   Note: `academyv2.mereka.dev` must also be verified in SES for this to work.

2. Alternatively, use SES sandbox mode for nonprod (requires manual recipient verification for each test address).

3. For pure local development (Docker Compose), use Django's console email backend:
   ```python
   EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"
   ```
   This is the Tutor default for `tutor local` mode and does not require SES.

### Credential Parity

The nonprod ExternalSecrets patch (`deploy/k8s/overlays/rke2-nonprod/patches/externalsecrets-infisical.yaml`) maps `MEREKA_LMS_EMAIL_HOST_USER` and `MEREKA_LMS_EMAIL_HOST_PASSWORD` from Infisical directly, giving nonprod the same SES access as production.

## Monitoring

### PrometheusRule

`deploy/k8s/base/monitoring/prometheusrule-email.yaml` defines the following alerts:

| Alert | Threshold | Severity |
|-------|-----------|----------|
| `EmailBounceRateHigh` | > 5% over 15 min | critical |
| `EmailComplaintRateHigh` | > 0.1% over 15 min | critical |
| `SESQuotaNearLimit` | < 10% quota remaining | warning |
| `EmailDeliveryLatencyHigh` | p95 > 30s over 10 min | warning |
| `EmailSuppressionListGrowthHigh` | > 100 new entries / hour | warning |
| `SMTPRelayPodDown` | SMTP pod down > 5 min | critical |
| `EximQueueSizeHigh` | Queue > 1000 messages | warning |
| `EmailSendRateDropped` | < 25% of normal rate | warning |

### Delivery Rate Tracking

SES publishes send/delivery/bounce/complaint events via SNS. The webhook endpoint `/api/webhooks/ses` receives these events and feeds them to:
- The `EmailSuppression` model (for bounce/complaint suppression)
- Prometheus metrics (for alerting)

The SNS webhook endpoint must be subscribed to the SES configuration set. See `docs/operations/EMAIL_DNS_RECORDS.md` for the AWS CLI commands to configure this.

## Bounce Handling

The `mereka_email_suppression` Django plugin (`infrastructure/tutor/plugins/email-suppression/`) processes SES bounce and complaint events:

- **Hard bounce**: Address immediately added to suppression list.
- **Soft bounce**: Counter incremented. After 3 soft bounces within 7 days, address is treated as a hard bounce.
- **Complaint**: Address added to suppression list and the user's `bulk_campaign` email preference is disabled.

Before sending any email, the `EmailSuppressionMiddleware` checks whether the recipient address is on the suppression list. Suppressed addresses are silently dropped (not sent, no error raised to the user).

## Troubleshooting

### Email Not Delivered

1. Confirm SMTP credentials are present in the K8s secret:
   ```bash
   kubectl get secret openedx-secrets -n mereka-lms \
     -o jsonpath='{.data.EMAIL_HOST_USER}' | base64 -d
   ```
   If empty, the ExternalSecret has not synced. Check:
   ```bash
   kubectl get externalsecret openedx-secrets -n mereka-lms
   kubectl describe externalsecret openedx-secrets -n mereka-lms | tail -20
   ```

2. Test SMTP connectivity from the LMS pod:
   ```bash
   kubectl exec -n mereka-lms deploy/lms -- python -c "
   import smtplib, os
   s = smtplib.SMTP('email-smtp.ap-southeast-1.amazonaws.com', 587)
   s.starttls()
   s.login(os.environ['EMAIL_HOST_USER'], os.environ['EMAIL_HOST_PASSWORD'])
   print('SMTP login OK')
   s.quit()
   "
   ```

3. Send a test email:
   ```bash
   kubectl exec -n mereka-lms deploy/lms -- python manage.py lms shell -c "
   from django.core.mail import send_mail
   send_mail('Test', 'Test body', 'no-reply@academyv2.mereka.io', ['test@example.com'])
   print('Sent')
   "
   ```

4. Check LMS logs for SMTP errors:
   ```bash
   kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms --tail=100 | grep -i smtp
   ```

### High Bounce Rate

If the `EmailBounceRateHigh` alert fires:

1. Review SES reputation dashboard in AWS Console (ap-southeast-1).
2. Check suppression list size:
   ```bash
   kubectl exec -n mereka-lms deploy/lms -- python manage.py lms shell -c "
   from mereka_email_suppression.models import EmailSuppression
   print('Total suppressed:', EmailSuppression.objects.count())
   print('Hard bounces:', EmailSuppression.objects.filter(reason='hard_bounce').count())
   print('Complaints:', EmailSuppression.objects.filter(reason='complaint').count())
   "
   ```
3. If bounce rate exceeds 10%, pause bulk campaigns immediately to protect the SES account reputation.
4. Review email list quality — Kajabi-migrated addresses may include stale accounts.

### ExternalSecret Not Syncing

```bash
# Check sync status
kubectl get externalsecret openedx-secrets -n mereka-lms -o yaml | grep -A10 conditions

# Force refresh
kubectl annotate externalsecret openedx-secrets -n mereka-lms \
  force-sync=$(date +%s) --overwrite

# Check secret store connectivity
kubectl get clustersecretstore gcp-secret-manager -o yaml | grep -A5 conditions
```

### SES Quota Exhausted

SES has a default sending quota (messages per day) and a maximum send rate (messages per second). If `SESQuotaNearLimit` fires:

1. Check current quota:
   ```bash
   aws sesv2 get-account --region ap-southeast-1 \
     --query 'SendQuota' --output table
   ```
2. Request a quota increase via the AWS console if needed.
3. Implement throttling in bulk campaign dispatch (50 emails/second per tenant, configurable).

## References

- `docs/operations/EMAIL_DNS_RECORDS.md` — DKIM, SPF, DMARC, and MAIL FROM configuration
- `infrastructure/tutor/plugins/email-suppression/` — Bounce/complaint suppression plugin
- `infrastructure/tutor/plugins/email-preferences/` — User notification preference management
- `deploy/k8s/base/monitoring/prometheusrule-email.yaml` — Prometheus alerting rules
- `deploy/k8s/base/secrets/external-secrets.yaml` — K8s secret mapping
- [AWS SES SMTP Credentials](https://docs.aws.amazon.com/ses/latest/dg/smtp-credentials.html)
- [Open edX ACE Documentation](https://docs.openedx.org/projects/openedx-ace/en/latest/)
