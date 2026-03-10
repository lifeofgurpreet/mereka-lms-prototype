# Mobile App Secrets Management

<!-- Last verified: 2026-02-14 -->

This document provides a complete inventory of mobile app secrets, their distribution mechanism, rotation schedule, and audit procedures for the Mereka Academy mobile applications.

## Overview

Mobile applications (iOS and Android) require OAuth2 credentials, API keys, and platform-specific secrets to authenticate with the Open edX backend. These secrets are managed through a secure, auditable pipeline and distributed to app builds via environment injection.

**Flow**:
```
Infisical (source of truth)
  → GCP Secret Manager (bridge layer)
  → ExternalSecrets Operator (K8s sync)
  → Kubernetes Secrets
  → Environment injection (app build or runtime)
```

## Secret Inventory

### OAuth2 Credentials

Mobile apps use OAuth2 Authorization Code flow for user authentication. Each app environment has its own OAuth2 application registered in the LMS.

| Secret Name | GCP SM Key | Infisical Path | Purpose | Distribution |
|-------------|------------|-----------------|---------|-------------|
| iOS Production Client ID | `MEREKA_LMS_MOBILE_IOS_PROD_CLIENT_ID` | `/k8s/mereka-lms/mobile` | OAuth2 client ID for iOS production app | Build-time (Xcode Config) |
| iOS Production Client Secret | `MEREKA_LMS_MOBILE_IOS_PROD_CLIENT_SECRET` | `/k8s/mereka-lms/mobile` | OAuth2 client secret for iOS production app | Build-time (Xcode Config) |
| iOS Dev Client ID | `MEREKA_LMS_MOBILE_IOS_DEV_CLIENT_ID` | `/k8s/mereka-lms/mobile` | OAuth2 client ID for iOS dev app | Build-time (Xcode Config) |
| iOS Dev Client Secret | `MEREKA_LMS_MOBILE_IOS_DEV_CLIENT_SECRET` | `/k8s/mereka-lms/mobile` | OAuth2 client secret for iOS dev app | Build-time (Xcode Config) |
| Android Production Client ID | `MEREKA_LMS_MOBILE_ANDROID_PROD_CLIENT_ID` | `/k8s/mereka-lms/mobile` | OAuth2 client ID for Android production app | Build-time (gradle.properties) |
| Android Production Client Secret | `MEREKA_LMS_MOBILE_ANDROID_PROD_CLIENT_SECRET` | `/k8s/mereka-lms/mobile` | OAuth2 client secret for Android production app | Build-time (gradle.properties) |
| Android Dev Client ID | `MEREKA_LMS_MOBILE_ANDROID_DEV_CLIENT_ID` | `/k8s/mereka-lms/mobile` | OAuth2 client ID for Android dev app | Build-time (gradle.properties) |
| Android Dev Client Secret | `MEREKA_LMS_MOBILE_ANDROID_DEV_CLIENT_SECRET` | `/k8s/mereka-lms/mobile` | OAuth2 client secret for Android dev app | Build-time (gradle.properties) |

**Current Production OAuth App**:
- **Client ID**: `mereka-mobile-ios-prod`
- **Client Name**: Mereka Academy iOS (Production)
- **Grant Type**: `authorization-code`
- **Redirect URI**: `merekaacademy://oauth`
- **Scopes**: `user_id email profile read write`
- **Skip Authorization**: Yes (first-party app)
- **Created**: via `tutor local exec lms ./manage.py lms create_dot_application` (see `docs/ops/runbooks/MOBILE_OAUTH_PROVISIONING.md`)

### Platform API Keys

| Secret Name | GCP SM Key | Infisical Path | Purpose | Distribution |
|-------------|------------|-----------------|---------|-------------|
| Firebase iOS Config | `MEREKA_LMS_FIREBASE_IOS_PLIST` | `/k8s/mereka-lms/mobile` | Firebase Analytics and Crashlytics | Build-time (GoogleService-Info.plist) |
| Firebase Android Config | `MEREKA_LMS_FIREBASE_ANDROID_JSON` | `/k8s/mereka-lms/mobile` | Firebase Analytics and Crashlytics | Build-time (google-services.json) |
| Sentry DSN iOS | `MEREKA_LMS_SENTRY_DSN_IOS` | `/k8s/mereka-lms/mobile` | Error tracking for iOS | Build-time (Info.plist) |
| Sentry DSN Android | `MEREKA_LMS_SENTRY_DSN_ANDROID` | `/k8s/mereka-lms/mobile` | Error tracking for Android | Build-time (AndroidManifest.xml) |

### App Store Distribution

| Secret Name | GCP SM Key | Infisical Path | Purpose | Distribution |
|-------------|------------|-----------------|---------|-------------|
| App Store Connect API Key | `MEREKA_LMS_APPSTORE_CONNECT_KEY_ID` | `/k8s/mereka-lms/mobile` | TestFlight upload automation | CI/CD (Fastlane Match) |
| App Store Connect Issuer ID | `MEREKA_LMS_APPSTORE_CONNECT_ISSUER_ID` | `/k8s/mereka-lms/mobile` | TestFlight upload automation | CI/CD (Fastlane Match) |
| App Store Connect Key Content | `MEREKA_LMS_APPSTORE_CONNECT_KEY` | `/k8s/mereka-lms/mobile` | TestFlight upload automation | CI/CD (Fastlane Match) |
| Match Git Repository | `MEREKA_LMS_MATCH_GIT_URL` | `/k8s/mereka-lms/mobile` | iOS code signing certificates | CI/CD (Fastlane Match) |
| Match Repository Password | `MEREKA_LMS_MATCH_PASSWORD` | `/k8s/mereka-lms/mobile` | Decrypt signing certificates | CI/CD (Fastlane Match) |
| Google Play Service Account | `MEREKA_LMS_GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | `/k8s/mereka-lms/mobile` | Play Store upload automation | CI/CD (Gradle Play Publisher) |

## Distribution Mechanism

### 1. Infisical to GCP Secret Manager

All mobile secrets are stored in Infisical under the path `/k8s/mereka-lms/mobile` and synced to GCP Secret Manager using the standard sync script:

```bash
# Sync mobile secrets to GCP SM
./scripts/infra/sync-mereka-lms-secrets-to-gcpsm.sh

# Verify sync
gcloud secrets list --filter="name~MEREKA_LMS_MOBILE_" --format="table(name,createTime)"
```

### 2. GCP Secret Manager to ExternalSecrets

Mobile secrets are **NOT** synced to Kubernetes via ExternalSecrets because they are consumed at build-time by CI/CD workflows, not at runtime by pods.

### 3. ExternalSecrets to GitHub Actions

CI/CD workflows retrieve secrets from GCP Secret Manager using Workload Identity Federation:

```yaml
# .github/workflows/ios-build.yml
- name: Retrieve mobile secrets
  id: secrets
  run: |
    echo "CLIENT_ID=$(gcloud secrets versions access latest --secret=MEREKA_LMS_MOBILE_IOS_PROD_CLIENT_ID)" >> $GITHUB_OUTPUT
    echo "CLIENT_SECRET=$(gcloud secrets versions access latest --secret=MEREKA_LMS_MOBILE_IOS_PROD_CLIENT_SECRET)" >> $GITHUB_OUTPUT
```

### 4. Environment Injection

**iOS (Xcode)**:
- Secrets are injected into `Config.xcconfig` via Fastlane during build
- The app reads from `Bundle.main.object(forInfoDictionaryKey:)` at runtime

**Android (Gradle)**:
- Secrets are injected into `local.properties` or `gradle.properties` via CI
- The app reads from `BuildConfig` constants at runtime

## Rotation Schedule

| Secret Type | Rotation Frequency | Last Rotation | Next Rotation | Automation |
|-------------|-------------------|---------------|---------------|------------|
| OAuth2 Client Secrets | Quarterly (90 days) | 2026-02-01 | 2026-05-01 | Manual via `create_dot_application --update` |
| Firebase Configs | Annually or on key rotation in Firebase Console | 2025-12-15 | 2026-12-15 | Manual download from Firebase Console |
| Sentry DSN | Never (public client key) | N/A | N/A | N/A |
| App Store Connect API Key | Annually | 2025-11-01 | 2026-11-01 | Manual via App Store Connect |
| Fastlane Match Password | Annually | 2025-11-01 | 2026-11-01 | Manual rotation, update Infisical |
| Google Play Service Account | Annually | 2025-11-01 | 2026-11-01 | Manual via GCP IAM |

### OAuth2 Client Secret Rotation Procedure

Follow this procedure to rotate mobile OAuth2 client secrets:

```bash
# 1. Generate new secret via LMS management command
kubectl exec -it -n mereka-lms deploy/lms -- bash
./manage.py lms create_dot_application \
  --client-id "mereka-mobile-ios-prod" \
  --update

# 2. Retrieve the new client secret from the output
# (Secret is printed during creation if --skip-authorization is used)

# 3. Update Infisical
INFISICAL="${INFISICAL:-<path-to-infisical-cli>}"
${INFISICAL} secrets set MEREKA_LMS_MOBILE_IOS_PROD_CLIENT_SECRET="<new-secret>" \
  --domain https://secrets.mereka.io/api \
  --env prod \
  --path /k8s/mereka-lms/mobile

# 4. Sync to GCP SM
./scripts/infra/sync-mereka-lms-secrets-to-gcpsm.sh

# 5. Verify in GCP SM
gcloud secrets versions access latest --secret=MEREKA_LMS_MOBILE_IOS_PROD_CLIENT_SECRET

# 6. Trigger new iOS build to pick up rotated secret
gh workflow run ios-build.yml --ref main

# 7. Test OAuth flow in TestFlight build
# (Manual verification - see docs/ops/runbooks/MOBILE_OAUTH_PROVISIONING.md)
```

## Audit Procedures

### ExternalSecrets Sync Status

ExternalSecrets provide sync status for secrets distributed to Kubernetes. However, mobile secrets are **NOT** synced to K8s, so this check does not apply.

```bash
# This will NOT show mobile secrets (they are not synced to K8s)
kubectl get externalsecrets -n mereka-lms
```

### GCP Secret Manager Audit Logs

GCP Secret Manager maintains audit logs for all secret access operations.

```bash
# View access logs for mobile secrets (last 7 days)
gcloud logging read 'resource.type="secretmanager.googleapis.com/Secret"
  AND protoPayload.resourceName=~"MEREKA_LMS_MOBILE_"
  AND timestamp>="2026-02-07T00:00:00Z"' \
  --limit 50 \
  --format json \
  --project bbi-k8

# Check who accessed mobile secrets
gcloud logging read 'resource.type="secretmanager.googleapis.com/Secret"
  AND protoPayload.resourceName=~"MEREKA_LMS_MOBILE_"
  AND protoPayload.methodName="AccessSecretVersion"
  AND timestamp>="2026-02-07T00:00:00Z"' \
  --limit 50 \
  --format="table(timestamp,protoPayload.authenticationInfo.principalEmail,protoPayload.resourceName)"
```

### Infisical Audit Logs

Infisical maintains an audit log accessible via the web UI or API.

```bash
# List recent changes to mobile secrets
${INFISICAL} audit-logs list \
  --domain https://secrets.mereka.io/api \
  --env prod \
  --path /k8s/mereka-lms/mobile \
  --limit 20
```

### CI/CD Build Secret Usage

GitHub Actions logs show which secrets were retrieved during builds (secret values are masked).

```bash
# View recent iOS builds that used mobile secrets
gh run list --workflow=ios-build.yml --limit 10 --json databaseId,conclusion,createdAt

# View logs for a specific run (secret values are automatically masked)
gh run view <run-id> --log
```

### Validation Script

Verify all mobile secrets exist in Infisical and GCP SM:

```bash
# Validate mobile secrets inventory
./scripts/qa/verify-mobile-secrets-inventory.sh

# Expected output:
# ✓ All 16 mobile secrets present in Infisical
# ✓ All 16 mobile secrets synced to GCP SM
# ✓ No placeholder values detected
# ✓ OAuth client secrets valid (length >= 32)
```

## Security Considerations

### Secret Distribution Best Practices

1. **Never commit secrets to git**: All mobile secrets are injected at build-time by CI/CD, never hardcoded in source code.
2. **Use separate dev/prod secrets**: Dev and production apps use different OAuth client IDs to prevent production credential leakage in dev builds.
3. **Minimize secret scope**: OAuth clients use minimal scopes (`user_id email profile read write`) to limit blast radius.
4. **Rotate quarterly**: OAuth client secrets are rotated every 90 days to limit credential lifetime.
5. **Audit access**: GCP SM audit logs track all secret access operations.

### Platform-Specific Security

**iOS**:
- OAuth secrets stored in iOS Keychain (not UserDefaults)
- Fastlane Match encrypts code signing certificates with AES-256
- App Store Connect API keys use P8 format with short expiration

**Android**:
- OAuth secrets stored in EncryptedSharedPreferences
- Google Play Service Account keys use scoped IAM roles
- ProGuard/R8 obfuscates secret key names in APK

## Related Documentation

- **OAuth Provisioning**: `docs/ops/runbooks/MOBILE_OAUTH_PROVISIONING.md` - OAuth app creation and verification
- **Secrets Management Spec**: `specs/secrets-management_spec.md` - Pipeline architecture and validation
- **CI/CD Pipeline Spec**: `specs/ci-cd-pipeline_spec.md` - iOS build workflow
- **iOS App Setup**: `docs/archive/ios/MOBILE_IOS_APP_SETUP.md` - iOS app configuration (if exists)

## Troubleshooting

### "Invalid client_id" in Mobile App

**Symptom**: Mobile app fails OAuth flow with `invalid_client_id` error.

**Diagnosis**:
```bash
# 1. Verify OAuth app exists in LMS
kubectl exec -it -n mereka-lms deploy/lms -- ./manage.py lms shell
>>> from oauth2_provider.models import Application
>>> Application.objects.filter(client_id="mereka-mobile-ios-prod").exists()

# 2. Verify client ID matches in Infisical
${INFISICAL} secrets get MEREKA_LMS_MOBILE_IOS_PROD_CLIENT_ID \
  --domain https://secrets.mereka.io/api \
  --env prod \
  --path /k8s/mereka-lms/mobile
```

**Resolution**: Update Infisical with the correct client ID from the LMS OAuth app.

### "Invalid client_secret" in Mobile App

**Symptom**: Token exchange fails with `invalid_client` error.

**Diagnosis**:
```bash
# Check if secret was recently rotated
gcloud secrets versions list MEREKA_LMS_MOBILE_IOS_PROD_CLIENT_SECRET

# Test secret manually
curl -X POST https://academyv2.mereka.io/oauth2/access_token \
  -d "grant_type=authorization_code" \
  -d "client_id=mereka-mobile-ios-prod" \
  -d "client_secret=<test-secret>" \
  -d "code=<test-code>" \
  -d "redirect_uri=merekaacademy://oauth"
```

**Resolution**: Rotate the secret following the rotation procedure above.

### Mobile Secrets Missing from GCP SM

**Symptom**: CI build fails with "secret not found" error.

**Diagnosis**:
```bash
# Check if secrets exist in GCP SM
gcloud secrets list --filter="name~MEREKA_LMS_MOBILE_" --format="table(name)"

# Verify Infisical has the secrets
${INFISICAL} secrets list \
  --domain https://secrets.mereka.io/api \
  --env prod \
  --path /k8s/mereka-lms/mobile
```

**Resolution**: Run `./scripts/infra/sync-mereka-lms-secrets-to-gcpsm.sh` to sync from Infisical to GCP SM.
