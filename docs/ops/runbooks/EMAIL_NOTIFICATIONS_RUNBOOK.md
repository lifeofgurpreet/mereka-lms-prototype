# Email Notifications Pipeline Runbook
_Audience: Platform Eng • Owner: Engineering Lead • Last updated: 2026-02-10_

This runbook covers operational procedures for the email notifications pipeline.

> **Spec**: `specs/email-notifications-pipeline_spec.md`
> **Testmap**: `specs/_generated/testmaps/email-notifications-pipeline_spec.testmap.yml`

## Prerequisites

- AWS SES account with verified sender domain
- LMS admin access
- Test email recipient address

---

## ACE Pipeline Verification

### Procedure
1. Verify SES sender domain is verified:
   ```bash
   # Check SES domain verification status
   aws ses get-identity-verification-attributes --identities mereka.io
   ```
2. Trigger a test notification from LMS:
   - Create a course announcement (sends email to enrolled students)
   - Or trigger password reset for a test user
3. Verify email is delivered:
   - Check recipient inbox (including spam folder)
   - Check SES sending statistics:
     ```bash
     aws ses get-send-statistics
     ```
4. Verify Celery worker processes the email task:
   ```bash
   kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms-worker --tail=50 | grep -i email
   ```

### Acceptance
- Email is delivered to recipient within 5 minutes
- SES bounce rate < 5%
- SES complaint rate < 0.1%
- Celery worker logs show successful email task completion
- No emails stuck in queue

---

## Email Template Rendering

### Procedure
1. Trigger various email types:
   - Account activation email
   - Password reset email
   - Course enrollment confirmation
   - Course announcement
   - Certificate notification
2. For each email type, verify:
   - Subject line is correct and not generic
   - Branding (Mereka logo, colors) renders in email clients
   - Links point to correct URLs (production domains)
   - Unsubscribe link is present and functional
3. Test rendering across email clients:
   - Gmail (web)
   - Outlook (web and desktop)
   - Apple Mail
   - Mobile email apps

### Acceptance
- All email types have correct subject lines
- Branding renders consistently across major email clients
- All links resolve to valid URLs
- Unsubscribe link works and updates preferences
- No broken images or layout issues
