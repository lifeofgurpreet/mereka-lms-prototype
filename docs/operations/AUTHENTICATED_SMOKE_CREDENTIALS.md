# Authenticated Smoke Test Credentials

**Purpose**: Secure credential handling for CI-based authenticated smoke tests.

**Coverage**: @covers AC-UIAUTH-004

## Overview

Authenticated smoke tests verify post-login functionality by logging in as a test user and checking critical authenticated routes:

- Learner dashboard (`/learner-dashboard/`)
- Account settings (`/account/`)
- Learning/course player (`/learning/`)
- User profile (`/profile/`)

These tests run automatically in CI and can be triggered manually via GitHub Actions.

## Credential Storage

### GitHub Actions Secrets

Credentials are stored as GitHub repository secrets (not environment variables in code):

| Secret Name | Description | Required |
|-------------|-------------|----------|
| `SMOKE_SSO_USERNAME` | Test user email/username | Yes |
| `SMOKE_SSO_PASSWORD` | Test user password | Yes |

**Location**: Repository → Settings → Secrets and variables → Actions → Repository secrets

### Accessing Secrets in CI

Secrets are interpolated into the workflow using GitHub Actions syntax:

```yaml
env:
  SSO_USERNAME: ${{ secrets.SMOKE_SSO_USERNAME }}
  SSO_PASSWORD: ${{ secrets.SMOKE_SSO_PASSWORD }}
```

**Never** hardcode credentials in:
- Source code
- Configuration files
- Environment variable defaults
- Commit messages
- Pull request descriptions

## Test User Requirements

The smoke test user account must meet these criteria:

### 1. Dedicated Test Account

- **NOT** a production admin account
- **NOT** a staff or superuser account
- Dedicated solely to automated testing
- Username should indicate test purpose (e.g., `smoke-test@mereka.io`)

### 2. Minimal Permissions

- Standard learner permissions (no elevated access)
- Enrolled in at least one course (for course player tests)
- Profile configured (name, bio)
- Account settings accessible

### 3. Stable State

- Password does not expire
- MFA disabled (or use TOTP seed for automation)
- Account not subject to automatic deletion policies
- Email notifications disabled (to avoid spam from test runs)

## Credential Rotation

### When to Rotate

Rotate credentials in these situations:

- **Quarterly**: Routine security hygiene (every 90 days)
- **After breach**: If credentials may have been exposed
- **Staff changes**: When team members with access leave
- **Policy change**: If security requirements change

### How to Rotate

**Step 1: Create new test user credentials**

1. Log in to production LMS admin interface
2. Create new test user account (or reset password for existing user)
3. Verify test user meets requirements above
4. Enroll in at least one course
5. Test login manually to verify credentials work

**Step 2: Update GitHub Secrets**

1. Navigate to: Repository → Settings → Secrets and variables → Actions
2. Edit `SMOKE_SSO_USERNAME` and `SMOKE_SSO_PASSWORD`
3. Click "Update secret"

**Step 3: Verify in CI**

1. Trigger smoke test workflow manually:
   - Actions → "Authenticated Smoke Tests" → "Run workflow"
2. Verify all checks pass
3. Review logs to confirm no authentication errors

**Step 4: Document rotation**

Update this section with rotation date:

```
Last rotated: YYYY-MM-DD
Next rotation: YYYY-MM-DD (90 days later)
```

**Last rotated**: 2026-02-17
**Next rotation**: 2026-05-18

## Security Considerations

### 1. Least Privilege

- Test user has **no** admin privileges
- Cannot access other users' data
- Cannot modify course content
- Cannot access financial/payment data

### 2. Audit Trail

- All smoke test runs are logged in GitHub Actions
- Test user login events visible in LMS audit logs
- Failed login attempts trigger alerts

### 3. Network Isolation

- CI runners use GitHub-hosted infrastructure (isolated)
- No VPN access required (public endpoints only)
- Test user cannot access internal admin interfaces

### 4. Credential Exposure Mitigation

If credentials are accidentally exposed:

1. **Immediately rotate** credentials following procedure above
2. Check LMS audit logs for unauthorized access
3. Review recent smoke test runs for anomalies
4. Consider temporary account suspension during investigation

### 5. Secret Scanning

GitHub secret scanning automatically detects exposed credentials:

- Pre-commit hooks scan for hardcoded secrets
- GitHub Advanced Security scans commits and PRs
- Alerts sent to security team if patterns detected

## Troubleshooting

### Smoke tests fail with "SSO_USERNAME not set"

**Cause**: GitHub secrets not configured or not accessible to workflow

**Fix**:
1. Verify secrets exist: Settings → Secrets and variables → Actions
2. Check secret names match exactly (case-sensitive)
3. Ensure workflow has `secrets: inherit` if calling from another workflow

### Smoke tests fail with "Could not find username field"

**Cause**: SSO login page structure changed (Authentik update)

**Fix**:
1. Inspect login page HTML (DevTools)
2. Update selectors in `scripts/qa/smoke-authenticated.sh` Playwright script
3. Common selectors: `#id_uid_field`, `input[name="uidField"]`, `input[type="email"]`

### Smoke tests fail with "Login page redirected to login"

**Cause**: Authentication failed (wrong credentials or account locked)

**Fix**:
1. Verify credentials by manually logging in at production URL
2. Check if account is locked/disabled in LMS admin
3. Verify password hasn't expired
4. Rotate credentials if needed

### Visual regression fails with "SSO credentials not provided"

**Cause**: `--authenticated` flag used but credentials missing

**Fix**:
1. Ensure `SSO_USERNAME` and `SSO_PASSWORD` environment variables are set
2. For local testing: `export SSO_USERNAME=... SSO_PASSWORD=...`
3. For CI: verify GitHub secrets are configured

## Related Documentation

- **Smoke Test Script**: `scripts/qa/smoke-authenticated.sh`
- **Visual Regression**: `scripts/qa/visual-regression-test.sh`
- **CI Workflow**: `.github/workflows/smoke-authenticated.yml`
- **Verification**: `scripts/qa/verify-authenticated-ui-smoke.sh`

## Manual Testing

To run authenticated smoke tests locally:

```bash
# Set credentials (do not commit these!)
export SSO_USERNAME="smoke-test@mereka.io"
export SSO_PASSWORD="your-test-password"

# Run smoke tests
./scripts/qa/smoke-authenticated.sh --target https://academyv2.mereka.io

# Run visual regression (authenticated)
./scripts/qa/visual-regression-test.sh --env production --authenticated
```

**Important**: Never commit credentials to version control. Use environment variables or CI secrets only.
