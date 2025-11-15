# Task 3: SES SMTP Deliverability - Troubleshooting Guide
_Audience: Infrastructure Team • Owner: Infra • Last updated: 2025-11-12_

## Problem Statement

**Error:** AWS SES returns `535 Authentication Credentials Invalid`

**Status:** ⛔ Blocked - Need AWS support/domain verification before enabling email

**Impact:** Open edX cannot send emails (password resets, notifications, course updates)

---

## Current Status

### What We Know

1. **Error Code:** `535 Authentication Credentials Invalid`
2. **Service:** AWS SES (Simple Email Service)
3. **Issue:** SMTP authentication failing
4. **Blocking Factor:** Domain verification required

### Common Causes of 535 Error

1. **Invalid SMTP credentials** (username/password incorrect)
2. **SES account in sandbox mode** (can only send to verified emails)
3. **Domain not verified** in SES
4. **SMTP endpoint incorrect** (wrong region)
5. **IAM user permissions** insufficient
6. **Account suspended** or not fully activated

---

## Step-by-Step Diagnosis

### Step 1: Check SES Account Status

```bash
# Check if SES is in sandbox mode
aws ses get-account-sending-enabled --region us-east-1

# List verified domains
aws ses list-verified-email-addresses --region us-east-1

# List verified domains (for domain verification)
aws ses list-identities --region us-east-1
```

**Expected Output:**
- If in sandbox: Can only send to verified email addresses
- If production: Can send to any email address (after domain verification)

### Step 2: Verify Domain/Email in SES

**For Domain Verification:**
1. Go to AWS SES Console → Verified identities
2. Click "Create identity"
3. Select "Domain"
4. Enter domain: `mereka.io` or `academy.mereka.io`
5. Add DNS records (CNAME/TXT) to domain DNS
6. Wait for verification (can take up to 72 hours)

**For Email Verification (Sandbox Mode):**
1. Go to AWS SES Console → Verified identities
2. Click "Create identity"
3. Select "Email address"
4. Enter email: `noreply@mereka.io`
5. Click verification email
6. Verify email address

### Step 3: Check SMTP Credentials

**Get SMTP Credentials:**
1. Go to AWS SES Console → SMTP settings
2. Click "Create SMTP credentials"
3. Create IAM user for SMTP access
4. Download credentials (or note username/password)

**Verify Credentials:**
```bash
# Test SMTP connection (replace with your credentials)
telnet email-smtp.us-east-1.amazonaws.com 587

# Or use openssl
openssl s_client -connect email-smtp.us-east-1.amazonaws.com:587 -starttls smtp
```

### Step 4: Check Open edX Email Configuration

**Current Configuration Location:**
- Tutor config: `tutor_env/config.yml`
- Environment variables in Kubernetes: `kubectl get deployment lms -n mereka-lms -o yaml | grep EMAIL`

**Required Settings:**
```yaml
EMAIL_BACKEND: django_ses.SESBackend
AWS_SES_REGION_NAME: us-east-1  # or your SES region
AWS_SES_REGION_ENDPOINT: email-smtp.us-east-1.amazonaws.com
AWS_ACCESS_KEY_ID: <your-smtp-username>
AWS_SECRET_ACCESS_KEY: <your-smtp-password>
EMAIL_HOST: email-smtp.us-east-1.amazonaws.com
EMAIL_PORT: 587
EMAIL_USE_TLS: true
DEFAULT_FROM_EMAIL: noreply@mereka.io
```

### Step 5: Test SMTP Connection

**Using Python:**
```python
import smtplib
from email.mime.text import MIMEText

smtp_server = "email-smtp.us-east-1.amazonaws.com"
smtp_port = 587
smtp_username = "YOUR_SMTP_USERNAME"
smtp_password = "YOUR_SMTP_PASSWORD"

try:
    server = smtplib.SMTP(smtp_server, smtp_port)
    server.starttls()
    server.login(smtp_username, smtp_password)
    print("✅ SMTP connection successful!")
    server.quit()
except smtplib.SMTPAuthenticationError as e:
    print(f"❌ Authentication failed: {e}")
except Exception as e:
    print(f"❌ Connection failed: {e}")
```

**Using Open edX Django Shell:**
```bash
kubectl exec -n mereka-lms deploy/lms -- python manage.py lms shell --settings=tutor.production << 'PYEOF'
from django.core.mail import send_mail
from django.conf import settings

print(f"EMAIL_BACKEND: {settings.EMAIL_BACKEND}")
print(f"AWS_SES_REGION_NAME: {getattr(settings, 'AWS_SES_REGION_NAME', 'Not set')}")
print(f"DEFAULT_FROM_EMAIL: {settings.DEFAULT_FROM_EMAIL}")

# Test email (only works if domain/email is verified)
try:
    send_mail(
        'Test Email',
        'This is a test email from Open edX',
        settings.DEFAULT_FROM_EMAIL,
        ['test@example.com'],  # Use verified email in sandbox mode
        fail_silently=False,
    )
    print("✅ Email sent successfully!")
except Exception as e:
    print(f"❌ Email failed: {e}")
PYEOF
```

---

## Fix Procedures

### Fix 1: Verify Domain in SES

**Steps:**
1. **AWS Console:**
   - Go to SES → Verified identities → Create identity
   - Select "Domain"
   - Enter: `mereka.io` (or subdomain like `academy.mereka.io`)
   - Choose "Easy DKIM" (recommended)
   - Copy DNS records (CNAME records)

2. **DNS Configuration:**
   - Go to Cloudflare (or your DNS provider)
   - Add CNAME records as shown in SES console
   - Wait for DNS propagation (can take up to 72 hours)

3. **Verify:**
   ```bash
   aws ses get-identity-verification-attributes \
     --identities mereka.io \
     --region us-east-1
   ```

### Fix 2: Request Production Access (If in Sandbox)

**Steps:**
1. Go to AWS SES Console → Account dashboard
2. Click "Request production access"
3. Fill out form:
   - **Use case:** Transactional emails (password resets, notifications)
   - **Website URL:** https://staging.academy.mereka.io
   - **Describe use case:** Educational platform sending course notifications and password resets
   - **Expected volume:** < 50,000 emails/month (or your estimate)
4. Submit request
5. Wait for AWS approval (usually 24-48 hours)

### Fix 3: Create/Update SMTP Credentials

**Steps:**
1. **Create SMTP User:**
   ```bash
   # Create IAM user for SMTP
   aws iam create-user --user-name ses-smtp-user
   
   # Attach SES sending policy
   aws iam attach-user-policy \
     --user-name ses-smtp-user \
     --policy-arn arn:aws:iam::aws:policy/AmazonSESFullAccess
   ```

2. **Generate SMTP Credentials:**
   - Go to SES Console → SMTP settings
   - Click "Create SMTP credentials"
   - Select IAM user: `ses-smtp-user`
   - Download credentials CSV

3. **Update Open edX Configuration:**
   ```bash
   # Update Tutor config
   source ops/tutor-env.sh
   tutor config save \
     --set EMAIL_BACKEND=django_ses.SESBackend \
     --set AWS_SES_REGION_NAME=us-east-1 \
     --set AWS_ACCESS_KEY_ID="<smtp-username>" \
     --set AWS_SECRET_ACCESS_KEY="<smtp-password>" \
     --set DEFAULT_FROM_EMAIL=noreply@mereka.io
   
   # Apply to Kubernetes
   tutor k8s start
   ```

### Fix 4: Store Credentials Securely

**Using Google Secret Manager:**
```bash
# Store SMTP credentials
echo -n "<smtp-username>" | gcloud secrets create ses-smtp-username --data-file=-
echo -n "<smtp-password>" | gcloud secrets create ses-smtp-password --data-file=-

# Update Tutor to use secrets
tutor config save \
  --set AWS_ACCESS_KEY_ID="$(gcloud secrets versions access latest --secret=ses-smtp-username)" \
  --set AWS_SECRET_ACCESS_KEY="$(gcloud secrets versions access latest --secret=ses-smtp-password)"
```

---

## Verification Checklist

- [ ] SES account status checked (sandbox vs production)
- [ ] Domain verified in SES (`mereka.io` or subdomain)
- [ ] DNS records added and verified
- [ ] SMTP credentials created and tested
- [ ] Open edX email configuration updated
- [ ] Test email sent successfully
- [ ] Credentials stored in Secret Manager
- [ ] Production access requested (if needed)

---

## Alternative Solutions

### Option 1: Use SendGrid (Currently Used for MCT)

**Pros:**
- Already integrated (see `hubspot-webhook-mct/functions/sgrid.js`)
- Easy setup
- Good deliverability

**Cons:**
- Additional service to manage
- Cost (free tier: 100 emails/day)

**Implementation:**
```yaml
EMAIL_BACKEND: django.core.mail.backends.smtp.EmailBackend
EMAIL_HOST: smtp.sendgrid.net
EMAIL_PORT: 587
EMAIL_USE_TLS: true
EMAIL_HOST_USER: apikey
EMAIL_HOST_PASSWORD: <sendgrid-api-key>
DEFAULT_FROM_EMAIL: noreply@mereka.io
```

### Option 2: Use Gmail SMTP (For Testing Only)

**⚠️ Not Recommended for Production**

**Configuration:**
```yaml
EMAIL_BACKEND: django.core.mail.backends.smtp.EmailBackend
EMAIL_HOST: smtp.gmail.com
EMAIL_PORT: 587
EMAIL_USE_TLS: true
EMAIL_HOST_USER: <gmail-address>
EMAIL_HOST_PASSWORD: <app-password>
DEFAULT_FROM_EMAIL: <gmail-address>
```

### Option 3: Use Mailgun

**Pros:**
- Good deliverability
- Easy setup
- Free tier: 5,000 emails/month

**Configuration:**
```yaml
EMAIL_BACKEND: django.core.mail.backends.smtp.EmailBackend
EMAIL_HOST: smtp.mailgun.org
EMAIL_PORT: 587
EMAIL_USE_TLS: true
EMAIL_HOST_USER: <mailgun-smtp-user>
EMAIL_HOST_PASSWORD: <mailgun-smtp-password>
DEFAULT_FROM_EMAIL: noreply@mereka.io
```

---

## Next Steps

1. **Immediate:**
   - Check current SES account status
   - Verify domain/email in SES
   - Test SMTP credentials

2. **Short-term:**
   - Complete domain verification (add DNS records)
   - Request production access if in sandbox
   - Update Open edX configuration

3. **Long-term:**
   - Monitor email deliverability
   - Set up bounce/complaint handling
   - Configure SPF/DKIM/DMARC records

---

## Resources

- **AWS SES Documentation:** https://docs.aws.amazon.com/ses/
- **SES SMTP Settings:** https://console.aws.amazon.com/ses/home#/smtp
- **Domain Verification Guide:** https://docs.aws.amazon.com/ses/latest/dg/verify-domains.html
- **Production Access Request:** https://console.aws.amazon.com/ses/home#/account/dashboard
- **Open edX Email Configuration:** https://docs.tutor.overhang.io/configuration.html#email

---

## Troubleshooting Commands

```bash
# Check SES sending quota
aws ses get-send-quota --region us-east-1

# Check sending statistics
aws ses get-send-statistics --region us-east-1

# List verified identities
aws ses list-identities --region us-east-1

# Get identity verification status
aws ses get-identity-verification-attributes \
  --identities mereka.io \
  --region us-east-1

# Test SMTP connection
telnet email-smtp.us-east-1.amazonaws.com 587

# Check Open edX email settings
kubectl exec -n mereka-lms deploy/lms -- \
  python manage.py lms shell --settings=tutor.production -c \
  "from django.conf import settings; \
   print(f'EMAIL_BACKEND: {settings.EMAIL_BACKEND}'); \
   print(f'AWS_SES_REGION: {getattr(settings, \"AWS_SES_REGION_NAME\", \"Not set\")}'); \
   print(f'DEFAULT_FROM_EMAIL: {settings.DEFAULT_FROM_EMAIL}')"
```

---

**Last Updated:** 2025-11-12
**Status:** ⛔ Blocked - Awaiting domain verification and AWS support



