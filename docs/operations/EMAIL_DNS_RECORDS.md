# Email DNS Records for SES

<!-- @covers AC-001, AC-002, AC-004 -->
<!-- @spec: email-notifications-pipeline_spec.md -->

This document describes the DNS records required for AWS SES domain verification and email delivery for Mereka Academy.

## Verified Sending Domains

### Primary Domain: academyv2.mereka.io

**AC-001: Domain verification with DKIM/SPF/DMARC**

#### DKIM Records (AC-001)

Add the following CNAME records in Cloudflare DNS. The actual values will be provided by AWS SES after initiating domain verification.

```
Type: CNAME
Name: <token1>._domainkey.academyv2.mereka.io
Value: <token1>.dkim.amazonses.com
TTL: Auto

Type: CNAME
Name: <token2>._domainkey.academyv2.mereka.io
Value: <token2>.dkim.amazonses.com
TTL: Auto

Type: CNAME
Name: <token3>._domainkey.academyv2.mereka.io
Value: <token3>.dkim.amazonses.com
TTL: Auto
```

**To obtain DKIM tokens:**
```bash
aws sesv2 get-email-identity --email-identity academyv2.mereka.io \
  --region ap-southeast-1 \
  --query 'DkimAttributes.Tokens' \
  --output table
```

#### SPF Record (AC-001)

```
Type: TXT
Name: academyv2.mereka.io
Value: v=spf1 include:amazonses.com ~all
TTL: Auto
```

**Note**: If an SPF record already exists, merge the values:
```
v=spf1 include:amazonses.com include:existing-spf.com ~all
```

#### DMARC Record (AC-001)

```
Type: TXT
Name: _dmarc.academyv2.mereka.io
Value: v=DMARC1; p=quarantine; rua=mailto:dmarc@mereka.io; pct=100
TTL: Auto
```

**DMARC Policy Explanation:**
- `p=quarantine`: Quarantine emails that fail DMARC (recommended for production)
- `rua=mailto:dmarc@mereka.io`: Send aggregate reports to this address
- `pct=100`: Apply policy to 100% of failing messages

**Gradual Rollout:**
1. Start with `p=none; pct=100` to monitor without enforcement
2. After 2 weeks of clean reports, change to `p=quarantine; pct=25`
3. Gradually increase `pct` to 100 over 4-8 weeks
4. Once stable at quarantine, consider `p=reject` for maximum protection

#### Custom MAIL FROM Domain (AC-004)

**Purpose**: DMARC alignment for the envelope sender.

```
Type: MX
Name: mail.academyv2.mereka.io
Value: 10 feedback-smtp.ap-southeast-1.amazonses.com
TTL: Auto

Type: TXT
Name: mail.academyv2.mereka.io
Value: v=spf1 include:amazonses.com ~all
TTL: Auto
```

**SES Configuration:**
```bash
aws sesv2 put-email-identity-mail-from-attributes \
  --email-identity academyv2.mereka.io \
  --mail-from-domain mail.academyv2.mereka.io \
  --behavior-on-mx-failure REJECT_MESSAGE \
  --region ap-southeast-1
```

---

### Secondary Domain: academy.biji-biji.com

**AC-002: Domain verification for academy.biji-biji.com**

Follow the same pattern as above, replacing `academyv2.mereka.io` with `academy.biji-biji.com`.

#### DKIM Records (AC-002)

```
Type: CNAME
Name: <token1>._domainkey.academy.biji-biji.com
Value: <token1>.dkim.amazonses.com
TTL: Auto

Type: CNAME
Name: <token2>._domainkey.academy.biji-biji.com
Value: <token2>.dkim.amazonses.com
TTL: Auto

Type: CNAME
Name: <token3>._domainkey.academy.biji-biji.com
Value: <token3>.dkim.amazonses.com
TTL: Auto
```

**To obtain DKIM tokens:**
```bash
aws sesv2 get-email-identity --email-identity academy.biji-biji.com \
  --region ap-southeast-1 \
  --query 'DkimAttributes.Tokens' \
  --output table
```

#### SPF Record (AC-002)

```
Type: TXT
Name: academy.biji-biji.com
Value: v=spf1 include:amazonses.com ~all
TTL: Auto
```

#### DMARC Record (AC-002)

```
Type: TXT
Name: _dmarc.academy.biji-biji.com
Value: v=DMARC1; p=quarantine; rua=mailto:dmarc@mereka.io; pct=100
TTL: Auto
```

#### Custom MAIL FROM Domain (AC-004)

```
Type: MX
Name: mail.academy.biji-biji.com
Value: 10 feedback-smtp.ap-southeast-1.amazonses.com
TTL: Auto

Type: TXT
Name: mail.academy.biji-biji.com
Value: v=spf1 include:amazonses.com ~all
TTL: Auto
```

**SES Configuration:**
```bash
aws sesv2 put-email-identity-mail-from-attributes \
  --email-identity academy.biji-biji.com \
  --mail-from-domain mail.academy.biji-biji.com \
  --behavior-on-mx-failure REJECT_MESSAGE \
  --region ap-southeast-1
```

---

## Verification Steps

### 1. Add DNS Records

Add all records in Cloudflare DNS (or your DNS provider). Wait 5-10 minutes for propagation.

### 2. Verify with dig/nslookup

```bash
# Verify SPF
dig TXT academyv2.mereka.io +short

# Verify DMARC
dig TXT _dmarc.academyv2.mereka.io +short

# Verify DKIM (replace <token> with actual value)
dig CNAME <token>._domainkey.academyv2.mereka.io +short

# Verify MAIL FROM MX
dig MX mail.academyv2.mereka.io +short
```

### 3. Check SES Verification Status

```bash
# Check verification status
aws sesv2 get-email-identity --email-identity academyv2.mereka.io \
  --region ap-southeast-1 \
  --query 'VerifiedForSendingStatus' \
  --output text

# Check DKIM status
aws sesv2 get-email-identity --email-identity academyv2.mereka.io \
  --region ap-southeast-1 \
  --query 'DkimAttributes.Status' \
  --output text
```

Expected output: `SUCCESS` for both.

### 4. Test Email Delivery

Send a test email from the LMS:

```bash
# From LMS pod
kubectl exec -n mereka-lms deploy/lms -it -- \
  python manage.py lms shell -c "
from django.core.mail import send_mail
send_mail(
    'SES Test',
    'This is a test email from Mereka Academy SES.',
    'no-reply@academyv2.mereka.io',
    ['your-email@example.com'],
    fail_silently=False,
)
print('Email sent successfully')
"
```

Check the recipient inbox and verify:
- Email delivered successfully
- Email headers show `DKIM: PASS`
- Email headers show `SPF: PASS`
- Email headers show `DMARC: PASS`

---

## SES Configuration Set (AC-004)

Create the SES configuration set for event tracking:

```bash
# Create configuration set
aws sesv2 create-configuration-set \
  --configuration-set-name mereka-academy-production \
  --region ap-southeast-1

# Create SNS topic for SES events
aws sns create-topic \
  --name mereka-academy-ses-events \
  --region ap-southeast-1

# Subscribe webhook endpoint to SNS topic
aws sns subscribe \
  --topic-arn arn:aws:sns:ap-southeast-1:ACCOUNT_ID:mereka-academy-ses-events \
  --protocol https \
  --notification-endpoint https://academyv2.mereka.io/api/webhooks/ses \
  --region ap-southeast-1

# Add event destination to configuration set
aws sesv2 create-configuration-set-event-destination \
  --configuration-set-name mereka-academy-production \
  --event-destination-name sns-all-events \
  --event-destination '{
    "Enabled": true,
    "MatchingEventTypes": ["SEND", "DELIVERY", "BOUNCE", "COMPLAINT", "REJECT", "OPEN", "CLICK"],
    "SnsDestination": {
      "TopicArn": "arn:aws:sns:ap-southeast-1:ACCOUNT_ID:mereka-academy-ses-events"
    }
  }' \
  --region ap-southeast-1
```

---

## Per-Tenant Sender Identities (AC-005)

**AC-005: Per-tenant sender identity with custom display name**

Tenants can customize the "From" display name while using the shared verified domain.

**Configuration in Django settings:**

```python
# infrastructure/tutor/env/apps/openedx/settings/lms/production.py

# Per-tenant email sender configuration
TENANT_EMAIL_SENDERS = {
    'default': {
        'display_name': 'Mereka Academy',
        'from_address': 'no-reply@academyv2.mereka.io',
    },
    'acme-corp': {
        'display_name': 'Acme Corp via Mereka Academy',
        'from_address': 'no-reply@academyv2.mereka.io',
    },
    'biji-biji': {
        'display_name': 'Biji-Biji Initiative',
        'from_address': 'no-reply@academy.biji-biji.com',
    },
}

# Default sender (used when tenant not found)
DEFAULT_FROM_EMAIL = '"Mereka Academy" <no-reply@academyv2.mereka.io>'
SERVER_EMAIL = 'admin@academyv2.mereka.io'
```

**Usage in code:**

```python
from django.core.mail import EmailMessage

def send_tenant_email(tenant_slug, recipient, subject, body):
    config = settings.TENANT_EMAIL_SENDERS.get(
        tenant_slug,
        settings.TENANT_EMAIL_SENDERS['default']
    )

    from_email = f'"{config["display_name"]}" <{config["from_address"]}>'

    email = EmailMessage(
        subject=subject,
        body=body,
        from_email=from_email,
        to=[recipient],
    )
    email.send()
```

---

## Troubleshooting

### DNS Propagation Delays

If DNS changes don't propagate immediately:

```bash
# Check authoritative nameservers
dig NS academyv2.mereka.io +short

# Query authoritative server directly
dig @ns1.cloudflare.com TXT academyv2.mereka.io +short
```

### SES Verification Stuck

If SES verification stays "Pending":

1. Verify DNS records are correct (no typos)
2. Wait 72 hours (DNS propagation can be slow)
3. Remove and re-add the domain in SES
4. Contact AWS Support if still failing

### DMARC Alignment Failures

If emails fail DMARC:

1. Verify MAIL FROM domain is configured (AC-004)
2. Check SPF record includes `amazonses.com`
3. Verify DKIM records are correct (3 CNAME records)
4. Use https://mxtoolbox.com/dmarc.aspx to test

### Bounce/Complaint Rate High

If bounce rate > 5% or complaint rate > 0.1%:

1. Check email list quality (invalid addresses from Kajabi migration?)
2. Review email content (too promotional?)
3. Check suppression list: `kubectl exec -n mereka-lms deploy/lms -it -- python manage.py shell -c "from mereka_email_suppression.models import EmailSuppression; print(EmailSuppression.objects.count())"`
4. Review SES reputation dashboard in AWS Console

---

## Maintenance

### Monthly Tasks

1. Review DMARC aggregate reports (sent to dmarc@mereka.io)
2. Check SES sending statistics in AWS Console
3. Review suppression list growth trends
4. Verify DNS records still exist (accidental deletion check)

### Quarterly Tasks

1. Rotate SES SMTP credentials (if using IAM user, not recommended)
2. Review per-tenant sender configurations
3. Audit email deliverability metrics
4. Consider DMARC policy progression (none → quarantine → reject)

---

## References

- [AWS SES Domain Verification](https://docs.aws.amazon.com/ses/latest/dg/verify-domain-procedure.html)
- [DKIM Setup](https://docs.aws.amazon.com/ses/latest/dg/send-email-authentication-dkim-easy-setup-domain.html)
- [SPF Records](https://docs.aws.amazon.com/ses/latest/dg/send-email-authentication-spf.html)
- [DMARC Records](https://docs.aws.amazon.com/ses/latest/dg/send-email-authentication-dmarc.html)
- [Custom MAIL FROM Domain](https://docs.aws.amazon.com/ses/latest/dg/mail-from.html)
- [SES Configuration Sets](https://docs.aws.amazon.com/ses/latest/dg/using-configuration-sets.html)
