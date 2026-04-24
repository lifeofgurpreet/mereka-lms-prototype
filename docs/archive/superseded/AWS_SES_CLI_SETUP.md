# AWS SES CLI Setup - Complete

_Last updated: 2026-02-27_

**Date**: 2026-02-03
**Status**: ✅ Operational

---

## Summary

AWS CLI configured with full SES access for the mereka-lms project. Credentials synchronized across Infisical, GCP Secret Manager, and local AWS CLI configuration.

---

## Credentials Overview

### IAM User
- **Name**: `ses-smtp-user.20251113-104139-g-test-singapore`
- **Region**: `ap-southeast-1` (Singapore)
- **Created**: 2025-11-13

### SES Status
- **Mode**: Production (not sandbox)
- **Max Send (24h)**: 200,000 emails
- **Max Send Rate**: 100 emails/second
- **Current Usage**: 14 emails sent in last 24h

### Verified Identities (16 domains/emails)
- `mereka.io` ✅
- `biji-biji.com` ✅
- `mereka.my` ✅
- `academy.biji-biji.com` ✅
- `skillourfuture.academy.mereka.io` ✅
- And 11 more domains

---

## Credential Storage Locations

| System | Secret Names | Notes |
|--------|--------------|-------|
| **Infisical** | `AWS_ACCESS_KEY_ID`<br>`AWS_SECRET_ACCESS_KEY` | Root path (`/`), prod environment<br>**Source of truth** |
| **GCP Secret Manager** | `aws-access-key-id`<br>`aws-secret-access-key`<br>`ses-smtp-username`<br>`ses-smtp-password` | Project: `mereka-lms`<br>Synced from Infisical |
| **K8s Secret** | `RELAY_USERNAME`<br>`RELAY_PASSWORD` | Namespace: `mereka-lms`<br>Secret: `ses-smtp-credentials`<br>For SMTP relay only |
| **Local AWS CLI** | Configured in `~/.aws/credentials` | Auto-populated from GCP<br>For CLI usage |

---

## AWS CLI Installation

**Version**: `aws-cli/1.44.30`
**Installation Method**: pip (in project `.venv`)
**Config Location**: `~/.aws/config` (region: ap-southeast-1)
**Credentials Location**: `~/.aws/credentials` (permissions: 600)

### Installation Command
```bash
source .venv/bin/activate
pip install awscli
```

### Configuration Applied
```bash
# Retrieve from GCP Secret Manager
AWS_ACCESS_KEY_ID=$(gcloud secrets versions access latest \
  --secret=aws-access-key-id --project=mereka-lms)
AWS_SECRET_ACCESS_KEY=$(gcloud secrets versions access latest \
  --secret=aws-secret-access-key --project=mereka-lms)

# Configure AWS CLI
cat > ~/.aws/credentials << EOF
[default]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
EOF

cat > ~/.aws/config << EOF
[default]
region = ap-southeast-1
output = json
EOF
```

---

## Usage Examples

### Verify SES Access
```bash
source .venv/bin/activate
aws ses get-send-quota
```

**Expected Output**:
```json
{
    "Max24HourSend": 200000.0,
    "MaxSendRate": 100.0,
    "SentLast24Hours": 14.0
}
```

### List Verified Identities
```bash
aws ses list-identities
```

### Send Test Email
```bash
aws ses send-email \
  --from noreply@mereka.io \
  --to gurpreet@biji-biji.com \
  --subject "Test Email from AWS CLI" \
  --text "This is a test email sent via AWS SES CLI"
```

### Check Sending Statistics
```bash
aws ses get-send-statistics
```

### Verify New Email Address
```bash
aws ses verify-email-identity --email-address new@mereka.io
```

### Get Account Sending Status
```bash
aws sesv2 get-account
```

---

## SMTP vs API Credentials

### SMTP Credentials (Email Relay)
- **Used by**: Open edX SMTP relay container
- **Username**: `<from K8s secret>` (from `ses-smtp-credentials`)
- **Password**: SMTP-specific password (derived from IAM secret)
- **Server**: `email-smtp.ap-southeast-1.amazonaws.com:587`
- **Purpose**: Send emails from Open edX platform

### API Credentials (AWS CLI)
- **Used by**: AWS CLI, API operations, SES management
- **Secret Key**: In `~/.aws/credentials`
- **Purpose**: Manage SES settings, verify domains, send via API

**IMPORTANT**: The SMTP password is NOT the same as the AWS Secret Access Key. SMTP passwords are generated using a special algorithm and cannot be reversed.

---

## Integration with Secrets Management

This setup follows the **Secrets Management Architecture** documented in:
- `/home/gurpreet/projects/secrets-management/specs/`

### Workflow
```
Infisical (source of truth)
    ↓
GCP Secret Manager (synced via GitHub Action)
    ↓
Local AWS CLI (pulled on-demand)
```

### Key Principles
1. **Infisical is the only place to edit secrets**
2. **GCP Secret Manager** is a sync target for K8s consumption
3. **Local credentials** are pulled from GCP on-demand
4. **Never commit credentials** to git

---

## Common Operations

### Rotate Credentials
1. Create new access key in AWS IAM Console
2. Update in Infisical:
   ```bash
   cd ~/projects/k8s/reka-slackbot
   infisical secrets set AWS_ACCESS_KEY_ID="new-key" \
     --domain https://secrets.mereka.io/api --env prod --path /
   infisical secrets set AWS_SECRET_ACCESS_KEY="new-secret" \
     --domain https://secrets.mereka.io/api --env prod --path /
   ```
3. Trigger GCP sync (automatic via GitHub Action)
4. Update local AWS CLI config (rerun configuration script)
5. Delete old access key in AWS IAM Console

### Verify Configuration
```bash
# Test AWS CLI
aws sts get-caller-identity

# Expected output shows IAM user
{
    "UserId": "AIDAXHZNJFIABCDEFGHIJ",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/ses-smtp-user.20251113-104139-g-test-singapore"
}
```

---

## Troubleshooting

### Error: "Unable to locate credentials"

**Solution**: Re-run configuration script to populate `~/.aws/credentials`

### Error: "Access Denied"

**Solution**: Verify IAM user has `AmazonSESFullAccess` policy attached

### Error: "Invalid credentials"

**Solution**: Check if access key is still active in AWS IAM Console

### SMTP relay not working
**Solution**: Check K8s secret `ses-smtp-credentials` has correct `RELAY_USERNAME` and `RELAY_PASSWORD`

---

## Related Documentation

- **SES Setup Complete**: `docs/TASK3_SES_SETUP_COMPLETE.md`
- **Secrets Architecture**: `/home/gurpreet/projects/secrets-management/specs/01-architecture/OVERVIEW.md`
- **Secrets Inventory**: `/home/gurpreet/projects/secrets-management/specs/00-overview/INVENTORY.md`
- **Repository Guidelines**: `AGENTS.md`

---

**Last Updated**: 2026-02-03
**Maintainer**: Infrastructure Team
