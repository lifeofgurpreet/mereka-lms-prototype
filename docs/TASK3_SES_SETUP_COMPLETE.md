# Task 3: SES SMTP Setup - Completion Report
_Completed: 2025-11-12 • Task Owner: Infra_

## ✅ Setup Complete

### SMTP Credentials Configured

**SMTP Server:** `email-smtp.ap-southeast-1.amazonaws.com:587`  
**Region:** `ap-southeast-1` (Singapore)  
**SMTP Username:** `AKIAXHZNJFIAT74VKX4U`  
**IAM User:** `ses-smtp-user.20251113-104139-g-test-singapore`

### Configuration Applied

**Tutor Config (`tutor_env/config.yml`):**
```yaml
EMAIL_BACKEND: django.core.mail.backends.smtp.EmailBackend
EMAIL_HOST: email-smtp.ap-southeast-1.amazonaws.com
EMAIL_PORT: 587
EMAIL_USE_TLS: true
EMAIL_HOST_USER: AKIAXHZNJFIAT74VKX4U
EMAIL_HOST_PASSWORD: BP3cAl8RoylPkxYmSz3VC77ASdegdbhDP6s38NVCyaOe
DEFAULT_FROM_EMAIL: noreply@mereka.io
```

**Note:** Using SMTP backend (not django-ses) because we have SMTP credentials. django-ses requires AWS API credentials, while SMTP backend works with SMTP credentials.

**Kubernetes Deployment:**
- ✅ LMS deployment updated with email environment variables
- ✅ Credentials stored in Google Secret Manager:
  - `ses-smtp-username`
  - `ses-smtp-password`

### Verification

**SMTP Connection Test:**
```bash
✅ SMTP authentication successful!
```

**Test Email Sent:**
```bash
✅ Email sent successfully to gurpreet@biji-biji.com
```

**Configuration Status:**
- ✅ SMTP credentials tested and working
- ✅ Test email sent successfully
- ✅ Open edX email backend configured (SMTP)
- ✅ Credentials stored securely in Secret Manager
- ✅ LMS deployment updated

---

## ⚠️ Next Steps Required

### 1. Verify Domain/Email in SES (CRITICAL)

**Current Status:** Domain/email may not be verified in SES

**Action Required:**
1. Go to AWS SES Console → Verified identities
2. Verify domain `mereka.io` or email `noreply@mereka.io`
3. Add DNS records if verifying domain
4. Wait for verification (can take up to 72 hours)

**Impact:** 
- If SES is in sandbox mode, can only send to verified email addresses
- If domain not verified, emails may be rejected

### 2. Request Production Access (If in Sandbox)

**Steps:**
1. Go to AWS SES Console → Account dashboard
2. Click "Request production access"
3. Fill out form with use case details
4. Submit and wait for AWS approval (24-48 hours)

**Why:** Sandbox mode limits sending to verified emails only

### 3. Test Email Sending

**Test Command:**
```bash
kubectl exec -n mereka-lms deploy/lms -- python manage.py lms shell --settings=tutor.production << 'PYEOF'
from django.core.mail import send_mail
from django.conf import settings

# Use a verified email address (if in sandbox mode)
send_mail(
    'Test Email',
    'This is a test email from Open edX',
    settings.DEFAULT_FROM_EMAIL,
    ['verified-email@example.com'],  # Replace with verified email
    fail_silently=False,
)
PYEOF
```

---

## 🔒 Security Notes

**Credentials Storage:**
- ✅ Stored in Google Secret Manager
- ✅ Not committed to git
- ⚠️ Currently in `tutor_env/config.yml` (should be removed after testing)

**Recommendation:**
After verifying email works, update Tutor config to use Secret Manager:
```bash
tutor config save \
  --set AWS_ACCESS_KEY_ID="$(gcloud secrets versions access latest --secret=ses-smtp-username)" \
  --set AWS_SECRET_ACCESS_KEY="$(gcloud secrets versions access latest --secret=ses-smtp-password)"
```

---

## 📋 Verification Checklist

- [x] SMTP credentials tested
- [x] Open edX email configuration updated
- [x] Credentials stored in Secret Manager
- [x] LMS deployment updated
- [ ] Domain/email verified in SES
- [ ] Production access requested (if needed)
- [ ] Test email sent successfully
- [ ] Credentials removed from config.yml (use Secret Manager)

---

## 🎯 Testing Email Functionality

**Password Reset Test:**
1. Go to: https://staging.academy.mereka.io/account/password
2. Enter email address (must be verified if in sandbox)
3. Check email inbox for reset link

**Course Notification Test:**
1. Create a test course
2. Send course announcement
3. Verify email is received

---

## 📚 Related Documentation

- **Troubleshooting Guide:** `docs/TASK3_SES_SMTP_GUIDE.md`
- **AWS SES Documentation:** https://docs.aws.amazon.com/ses/
- **Open edX Email Config:** https://docs.tutor.overhang.io/configuration.html#email

---

**Last Updated:** 2026-02-03
**Status:** ✅ FULLY OPERATIONAL - Emails delivering via AWS SES

## 2026-02-03 Update: SES Integration Complete

**SMTP Relay Configuration Fixed:**
- Updated `devture/exim-relay` to use correct environment variables
- `SMARTHOST=email-smtp.ap-southeast-1.amazonaws.com::587`
- `SMTP_USERNAME` and `SMTP_PASSWORD` from K8s Secret `ses-smtp-credentials`
- `HOSTNAME=mail.staging.academy.mereka.io` for proper HELO

**Verified Working:**
- Test email delivered successfully via SES
- TLS 1.3 encryption confirmed
- SES message ID returned (delivery confirmed)

**Files Updated:**
- `deploy/k8s/base/deployments.yml` - SMTP deployment with SES config
- `deploy/k8s/patches/smtp-ses-relay.yaml` - Patch file for reference

