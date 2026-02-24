# Mobile Deployment Operations

<!-- Last verified: 2026-02-24 -->

**Spec**: `specs/mobile-apps-enterprise_spec.md`
**ADR**: `docs/adr/016-android-deferral.md` (Android deferred indefinitely)

## Overview

| Platform | Status | CI Workflow | Distribution |
|----------|--------|-------------|--------------|
| iOS | Active | `.github/workflows/build-ios-app.yml` | TestFlight / App Store |
| Android | Deferred (ADR-016) | Not yet created | Google Play (future) |

**Bundle ID**: `com.mereka.academy.mobile`
**LMS Backend**: `https://academyv2.mereka.io`
**OAuth2 Client**: `mereka-mobile-app`

---

## iOS Build and TestFlight Deployment

### Prerequisites

| Secret (GitHub Actions) | Purpose | Source |
|-------------------------|---------|--------|
| `APPLE_TEAM_ID` | Apple Developer Team ID (`44F7G2D7U6`) | Apple Developer Portal |
| `MATCH_DEPLOY_KEY` | SSH key for `ios-certificates` repo | `ssh-keygen -t ed25519` |
| `MATCH_PASSWORD` | Fastlane match encryption password | Infisical: `MEREKA_LMS_MATCH_PASSWORD` |
| `APP_STORE_CONNECT_API_KEY_ID` | ASC API key ID | Apple App Store Connect |
| `APP_STORE_CONNECT_ISSUER_ID` | ASC issuer ID | Apple App Store Connect |
| `APP_STORE_CONNECT_API_KEY_BASE64` | ASC API key (base64 `.p8`) | Apple App Store Connect |

### Trigger a TestFlight build

```bash
# Manual trigger via GitHub CLI
gh workflow run build-ios-app.yml --ref main

# Or push a change to mobile/ios/** on main
git push origin main
```

### Build workflow steps (build-ios-app.yml)

1. Checkout `mereka-lms` repo
2. Clone `openedx/openedx-app-ios` at the latest release tag
3. Install Ruby gems (Fastlane) and CocoaPods
4. Create Mereka config in `default_config/mereka/prod/`
5. Run the OpenEdX whitelabel script to set bundle ID
6. Patch xcconfig files for `com.mereka.academy.mobile`
7. Configure framework signing (manual, CODE_SIGNING_ALLOWED=NO for frameworks)
8. Fetch distribution certificate and provisioning profile via Fastlane match
9. Run `fastlane ci_testflight` lane (build + upload)
10. Cleanup: remove SSH keys (always runs)

**Timeout**: 90 minutes (match regeneration can take 15-20 min on first run)

### Certificate management (Fastlane match)

Certificates are stored in the `Biji-Biji-Initiative/ios-certificates` private repo.

```bash
# Renew distribution certificate (run from a Mac with Xcode)
cd ios-app
bundle exec fastlane match appstore --force
# Follow prompts to renew in Apple Developer Portal
```

Fastlane match stores:
- `Certificates/distribution/AppleDistribution_com.mereka.academy.mobile.cer`
- `Profiles/appstore/AppStore_com.mereka.academy.mobile.mobileprovision`

### TestFlight deployment verification

After a successful build:

1. Check TestFlight via App Store Connect at https://appstoreconnect.apple.com
2. New build should appear under `Mereka Academy` → TestFlight within 15-30 minutes
3. Internal testers get the build automatically; external testers require manual distribution

---

## Android Build Pipeline (Phase 3 — Not Yet Implemented)

**Status**: Deferred per ADR-016. Revisit conditions:
1. iOS fully operational and verified in production
2. User demand quantified
3. `specs/mobile-apps-enterprise_spec.md` reaches APPROVED status
4. Team capacity available

**When Android starts**, the workflow will follow this pattern:
- Trigger: push to `mobile/android/**` on `main`
- Build tool: Gradle + Android Gradle Plugin
- Signing: Android Keystore (stored in GitHub Secrets)
- Distribution: Google Play Internal Testing track
- Artifact: signed `.aab` (Android App Bundle)

Required secrets (to provision when Android work begins):
- `ANDROID_KEYSTORE_BASE64` — release keystore
- `ANDROID_KEY_ALIAS` — key alias
- `ANDROID_KEY_PASSWORD` — key password
- `ANDROID_STORE_PASSWORD` — keystore password
- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` — Play Developer API service account

---

## Mobile API Configuration

### Enabling the mobile API on the LMS

The mobile REST API is controlled via LMS feature flags in `deploy/k8s/base/apps/openedx/config/lms.env.yml`:

```yaml
FEATURES:
  ENABLE_MOBILE_REST_API: true
  ENABLE_OAUTH2_PROVIDER: true
  DEFAULT_MOBILE_AVAILABLE: true   # Makes all courses mobile-accessible by default
```

After changing these values, apply via Kustomize and let ArgoCD reconcile.

### Verify mobile API is active

```bash
# From inside a running LMS pod
kubectl exec -n mereka-lms $(kubectl get pod -n mereka-lms -l app.kubernetes.io/name=lms -o name | head -1) -- \
  python manage.py lms shell -c \
  "from django.conf import settings; print('MOBILE_REST_API:', settings.FEATURES.get('ENABLE_MOBILE_REST_API'))"

# Or via HTTP (expect 401 Unauthorized, not 404)
curl -s -o /dev/null -w "%{http_code}" https://academyv2.mereka.io/api/mobile/v1/
```

### OAuth2 mobile client

The OAuth2 application `mereka-mobile-app` must exist in the LMS database:

```bash
# Check if it exists
kubectl exec -n mereka-lms $(kubectl get pod -n mereka-lms -l app.kubernetes.io/name=lms -o name | head -1) -- \
  python manage.py lms shell -c \
  "from oauth2_provider.models import Application; print(Application.objects.filter(client_id='mereka-mobile-app').values('name', 'client_type', 'redirect_uris'))"

# Create if missing
kubectl exec -n mereka-lms $(kubectl get pod -n mereka-lms -l app.kubernetes.io/name=lms -o name | head -1) -- \
  python manage.py lms shell -c "
from oauth2_provider.models import Application
from django.contrib.auth import get_user_model
User = get_user_model()
admin = User.objects.filter(is_superuser=True).first()
Application.objects.get_or_create(
    client_id='mereka-mobile-app',
    defaults={
        'name': 'Mereka Academy Mobile App',
        'client_type': 'public',
        'authorization_grant_type': 'authorization-code',
        'redirect_uris': 'com.mereka.academy.mobile://oauth2Callback',
        'user': admin,
    }
)
print('Done')
"
```

### Key API endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/oauth2/authorize/` | GET | OAuth2 authorization (opens browser) |
| `/oauth2/access_token/` | POST | Token exchange / refresh |
| `/oauth2/revoke_token/` | POST | Token revocation on logout |
| `/api/mobile/v1/users/me` | GET | Current user profile |
| `/api/mobile/v4/my_courses/` | GET | Enrolled courses list |
| `/api/mobile/v1/courses/{id}/blocks` | GET | Course content blocks |
| `/api/mobile/v1/notifications/register/` | POST | Device token registration |
| `/api/mobile/v1/notifications/register/` | DELETE | Device token unregistration |
| `/api/mobile/v1/config/{org_slug}/` | GET | Tenant branding config |
| `/.well-known/apple-app-site-association` | GET | iOS Universal Links |
| `/.well-known/assetlinks.json` | GET | Android App Links |

---

## Push Notification Setup

**Current status**: Not configured. Firebase is present as a placeholder (ENABLED: false) in the iOS app config.

### Enabling Firebase push notifications

1. **Create or configure the Firebase project** `mereka-academy` in Firebase Console
   - Enable FCM for iOS (`com.mereka.academy.mobile`)
   - Download `GoogleService-Info.plist` for iOS
   - Enable APNs in Firebase settings (upload `.p8` APNs auth key)

2. **Store FCM credentials in Infisical**:
   ```bash
   # From the bbi-k8 project (not mereka-lms!)
   gcloud secrets create MEREKA_LMS_FCM_PROJECT_ID --data-file=- <<< "mereka-academy"
   gcloud secrets create MEREKA_LMS_FCM_SERVICE_ACCOUNT_KEY --data-file=service-account.json
   ```

3. **Update ExternalSecrets** in `deploy/k8s/base/secrets/external-secrets-mobile.yaml` to include:
   ```yaml
   - secretKey: FCM_PROJECT_ID
     remoteRef:
       key: MEREKA_LMS_FCM_PROJECT_ID
   - secretKey: FCM_SERVICE_ACCOUNT_KEY
     remoteRef:
       key: MEREKA_LMS_FCM_SERVICE_ACCOUNT_KEY
   ```

4. **Add LMS settings** in `deploy/k8s/base/apps/openedx/settings/lms/production.py`:
   ```python
   FCM_PROJECT_ID = os.environ.get("FCM_PROJECT_ID", "")
   FCM_SERVICE_ACCOUNT_KEY = os.environ.get("FCM_SERVICE_ACCOUNT_KEY", "{}")
   NOTIFICATION_PUSH_ENABLED = os.environ.get("NOTIFICATION_PUSH_ENABLED", "false").lower() == "true"
   ```

5. **Enable in iOS workflow** (`build-ios-app.yml`): update the `FIREBASE` block in the config YAML:
   ```yaml
   FIREBASE:
     ENABLED: true
     GCM_SENDER_ID: "<your-sender-id>"
     # ... other Firebase fields from GoogleService-Info.plist
   ```

6. **Verify** with `scripts/qa/verify-push-notifications.sh` and `scripts/qa/verify-mobile-deployment.sh`

### Push notification types supported

| Type | Trigger | Deep Link |
|------|---------|-----------|
| `course_announcement` | New announcement in enrolled course | Course detail |
| `assignment_due` | 24h and 1h before deadline | Assignment unit |
| `grade_posted` | Grade available for submission | Grade report |
| `discussion_reply` | Reply to followed thread | Discussion thread |
| `system_maintenance` | Scheduled maintenance | Dashboard |

---

## App Store Submission Process

### iOS App Store

**Pre-submission checklist** (AC-035):

- [ ] App description reviewed and accurate
- [ ] Screenshots captured for 6.7" (iPhone Pro Max) and 6.1" (iPhone) sizes
- [ ] Privacy nutrition labels completed in App Store Connect
- [ ] Age rating questionnaire completed
- [ ] Export compliance declaration completed
- [ ] Review notes include test account credentials
- [ ] All required capabilities enabled on App ID (Push Notifications, Sign in with Apple, Associated Domains)

**Submission steps**:

1. Trigger a release build via `build-ios-app.yml` workflow
2. Wait for build to appear in TestFlight (15-30 min)
3. In App Store Connect, select the build for release
4. Complete the release notes (What's New)
5. Submit for review
6. Once approved, use **Phased Release** (7-day rollout) per AC-037:
   - Day 1: 1%
   - Day 2: 2%
   - Day 3: 5%
   - Day 4: 10%
   - Day 5: 20%
   - Day 6: 50%
   - Day 7: 100%

**Emergency release** (critical bug fix): disable phased release and distribute to 100% immediately.

### Google Play Store (when Android is active)

**Pre-submission checklist** (AC-036):

- [ ] Store listing with description and screenshots (phone sizes)
- [ ] Content rating questionnaire completed
- [ ] Data safety form completed (lists data collected: usage data, device ID, crash logs)
- [ ] Signing key fingerprint added to `assetlinks.json`

**Staged rollout** (AC-037): Start at 10%, monitor crash-free sessions and ANR rate for 48h before expanding.

---

## Verification

Run the mobile deployment verification script before any release:

```bash
# Static checks only (no cluster required)
./scripts/qa/verify-mobile-deployment.sh --offline

# Full checks including live cluster
./scripts/qa/verify-mobile-deployment.sh

# Mobile secrets check
./scripts/qa/verify-mobile-secrets-runtime.sh

# iOS-specific checks (PKCE, token lifecycle, push notifications)
./scripts/qa/verify-mobile-ios.sh
```

Related verification scripts:

| Script | Covers |
|--------|--------|
| `verify-mobile-deployment.sh` | iOS workflow, mobile API config, app signing, push setup |
| `verify-mobile-ios.sh` | PKCE auth, token lifecycle, APNs, TestFlight CI |
| `verify-mobile-release.sh` | Offline mode, App Store metadata, Universal Links |
| `verify-mobile-backend-api.sh` | Branding API, device registration, AASA/assetlinks |
| `verify-mobile-secrets-runtime.sh` | iOS certificate management, ExternalSecrets, CI secrets |
| `verify-push-notifications.sh` | FCM/APNs push notification Django app |

---

## Troubleshooting

### iOS build fails: "No matching provisioning profile"

```bash
# Force-regenerate profiles from Apple Developer Portal
cd ios-app
MATCH_PASSWORD=<from-infisical> bundle exec fastlane match appstore --force --readonly false

# Verify the bundle ID matches in all xcconfig files
grep PRODUCT_BUNDLE_IDENTIFIER OpenEdX.xcodeproj/project.pbxproj | head -5
```

### iOS build fails: "Code signing is required for product type"

Framework targets must have `CODE_SIGNING_ALLOWED=NO`. The workflow sets this automatically, but if it fails:

```bash
# Check which target is failing in the Xcode build log
# Look for "requires code signing" in the GitHub Actions log
# Add the framework to the list in build-ios-app.yml → "Configure framework signing"
```

### Mobile API returns 404 instead of 401

The mobile REST API is not enabled. Check:

```bash
# 1. Verify feature flag
kubectl exec -n mereka-lms <lms-pod> -- \
  python manage.py lms shell -c \
  "from django.conf import settings; print(settings.FEATURES.get('ENABLE_MOBILE_REST_API'))"

# 2. If False, update lms.env.yml and apply via Kustomize
# ENABLE_MOBILE_REST_API: true
```

### Push notifications not delivered

```bash
# 1. Check device token registration
kubectl exec -n mereka-lms <lms-pod> -- \
  python manage.py lms shell -c \
  "from openedx_push_notifications.models import DeviceRegistration; print(DeviceRegistration.objects.filter(is_active=True).count(), 'active devices')"

# 2. Check FCM environment variable
kubectl exec -n mereka-lms <lms-pod> -- env | grep FCM

# 3. Check Celery worker task queue for push notification tasks
kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms-worker --tail=100 | grep push_notification
```

### TestFlight build not appearing in App Store Connect

- Wait 15-30 minutes — Apple processing takes time
- Check the GitHub Actions log for the altool upload exit code
- Verify `ASC_KEY_ID`, `ASC_ISSUER_ID`, and `ASC_KEY_P8_BASE64` secrets are current
- Apple may reject the build if the bundle ID or team ID changed

---

## Related Documentation

- `docs/MOBILE_IOS_APP_SETUP.md` — Initial iOS setup guide
- `docs/IOS_DEPLOYMENT_LEARNINGS.md` — CI/CD lessons learned
- `docs/IOS_APP_CI_SETUP.md` — GitHub Actions CI setup walkthrough
- `docs/adr/016-android-deferral.md` — Android deferral decision record
- `specs/mobile-apps-enterprise_spec.md` — Full mobile spec (37 ACs)
- `specs/mobile-apps-secrets-management_spec.md` — Secrets management spec
