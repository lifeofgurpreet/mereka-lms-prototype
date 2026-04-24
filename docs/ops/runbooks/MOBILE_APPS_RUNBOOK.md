# Mobile Apps Runbook
_Audience: Platform Eng + Mobile Dev • Owner: Engineering Lead • Last updated: 2026-02-13_

This runbook covers operational procedures for enterprise mobile app testing.

> **Current posture (2026-04-09)**: iOS remains a major intended product surface, but the active delivery lane is paused for program-timing and CI-cost reasons. Android remains deferred. This runbook documents the target-state operating model for when the lane is intentionally resumed.
> **Current front door**: Start with [`../../reference/operations/IOS_CI_CD_REFERENCE.md`](../../reference/operations/IOS_CI_CD_REFERENCE.md) for the current iOS workflow contract and lane status. Use this runbook for resumed operational procedures, not as proof that mobile runtime verification is complete today.
> **Architecture boundary**: Use [`../../architecture/mobile-apps-overview.md`](../../architecture/mobile-apps-overview.md) for the stable mobile system model and paused-lane ownership split.
> **Runtime verification**: REQUIRED before operational use - Mobile API enablement and OAuth setup have not been runtime-verified
> **Spec**: `specs/proposals/mobile-apps-enterprise_spec.md`
> **Testmap**: `specs/testmaps/mobile-apps-enterprise_spec.testmap.yml`

Current owner split:

- iOS workflow and signing contract:
  [../../reference/operations/IOS_CI_CD_REFERENCE.md](../../reference/operations/IOS_CI_CD_REFERENCE.md)
- stable system model and paused-lane architecture boundary:
  [../../architecture/mobile-apps-overview.md](../../architecture/mobile-apps-overview.md)
- mobile secrets, Firebase, APNs, and Google Play service-account boundary:
  [../../reference/operations/MOBILE_SECRETS_MANAGEMENT.md](../../reference/operations/MOBILE_SECRETS_MANAGEMENT.md)
- resumed device/runtime procedure: this runbook

Do not create a separate Android or Google Play release companion while the
Android lane remains deferred.

## Runtime Verification Commands

Before using this runbook operationally, verify mobile API configuration:

```bash
# Verify ENABLE_MOBILE_REST_API is enabled
tutor local run lms python manage.py lms shell -c \
  "from django.conf import settings; print(settings.FEATURES.get('ENABLE_MOBILE_REST_API'))"
# Expected: True

# Verify OAuth application exists
kubectl exec -n mereka-lms deployment/lms -- \
  ./manage.py lms shell -c \
  "from oauth2_provider.models import Application; print(Application.objects.filter(client_id='mereka-mobile-app').exists())"
# Expected: True

# Verify FCM/APNs credentials are configured (when push notifications implemented)
kubectl get secret -n mereka-lms mobile-secrets -o jsonpath='{.data.MOBILE_FCM_SERVICE_ACCOUNT_JSON}' | base64 -d | jq .
# Expected: Valid Firebase service account JSON
```

<!-- Last verified: 2026-02-13 (docs audit, not runtime) -->

## Prerequisites

When the lane is resumed, confirm the active workflow, signing path, and upstream Open edX mobile guidance before relying on the procedures below.

- Physical iOS and Android test devices (or emulators for basic testing)
- FCM (Firebase Cloud Messaging) credentials configured
- APNs (Apple Push Notification service) credentials configured
- LMS admin access

## Reactivation Procedure

Use this sequence when the paused mobile lane is intentionally resumed.

1. confirm the active iOS workflow contract in
   [../../reference/operations/IOS_CI_CD_REFERENCE.md](../../reference/operations/IOS_CI_CD_REFERENCE.md)
2. confirm current secret inventory and distribution path in
   [../../reference/operations/MOBILE_SECRETS_MANAGEMENT.md](../../reference/operations/MOBILE_SECRETS_MANAGEMENT.md)
3. confirm Apple Developer / TestFlight setup is still valid
4. produce a build from the maintained workflow front door
5. run device-level auth and course-access smoke checks before claiming the
   lane is back

## Reactivation Decision Table

| Symptom | Route |
| --- | --- |
| workflow/signing failure | [../../reference/operations/IOS_CI_CD_REFERENCE.md](../../reference/operations/IOS_CI_CD_REFERENCE.md) |
| missing Firebase/APNs/Play credentials | [../../reference/operations/MOBILE_SECRETS_MANAGEMENT.md](../../reference/operations/MOBILE_SECRETS_MANAGEMENT.md) |
| release/TestFlight procedure question | [MOBILE_DEPLOYMENT.md](MOBILE_DEPLOYMENT.md) |
| runtime device symptom | continue in this runbook |

---

## Token Refresh Deduplication

### Procedure
1. Sign in on a test device and capture an access token close to expiry.
2. Trigger 10 concurrent API requests from the app (or a test harness) while token refresh is required.
3. Inspect LMS OAuth logs and client telemetry for refresh calls during the burst.
4. Confirm only one refresh request is emitted and all pending API requests reuse the refreshed token.
5. Repeat once with simulated refresh failure to confirm requests fail cleanly and user is redirected to login.

### Acceptance
- Exactly one token refresh request is issued for a concurrent burst.
- Pending requests are replayed after refresh without duplicate refresh traffic.
- Refresh failure clears local auth state and prompts re-authentication.

---

## Push Notification Testing

### Procedure
1. Configure FCM/APNs credentials in LMS admin:
   - Verify FCM server key is set in ExternalSecrets
   - Verify APNs certificate is valid and not expired
2. Trigger a push notification from LMS (e.g., course announcement)
3. Verify notification appears on the test device:
   - Title matches the announcement title
   - Body contains the expected content
   - Tapping opens the correct screen in the app
4. Test on both iOS and Android devices

### Acceptance
- Push notification received within 30 seconds on both platforms
- Notification content matches the LMS announcement
- Tapping notification opens the correct in-app screen
- Notifications respect device Do Not Disturb settings

### Provider setup boundary

Before running push tests, verify:

- Firebase project config is current for the resumed lane
- APNs key or certificate is still valid for the iOS bundle
- backend/device registration contract is the intended one for the resumed lane
- no one is claiming push as live merely because credentials exist

---

## Offline Mode Testing

### Procedure
1. Open the mobile app and navigate to an enrolled course
2. Download course content for offline access
3. Enable airplane mode on the device
4. Verify downloaded content is accessible:
   - Course outline loads
   - Text content renders
   - Previously cached videos play
5. Complete a quiz while offline
6. Disable airplane mode and verify sync:
   - Quiz results sync to server
   - Progress updates reflect on LMS web

### Acceptance
- Downloaded content accessible without network
- Quiz answers are cached locally and synced when online
- No data loss during offline-to-online transition
- Sync conflicts are handled gracefully

---

## Deep Link Testing

### Procedure
1. Send a deep link via email or web:
   - Course link: `mereka://course/<course_id>`
   - Specific lesson: `mereka://course/<course_id>/section/<section_id>`
2. Open the link on a device with the app installed
3. Verify the app opens directly to the correct screen
4. Test links without the app installed (should redirect to app store)

### Acceptance
- Deep links open the correct in-app screen
- Links work from email, web browser, and messaging apps
- Unauthenticated deep links prompt login first, then navigate
- App-not-installed case redirects to appropriate app store

## Tenant Branding and Course Access Testing

### Procedure
1. launch the app with the intended tenant/org context
2. verify branding payload or cached config matches the intended tenant
3. sign in through the expected OAuth path
4. verify course access and learner navigation land in the correct tenant
   context
5. verify logout clears session and cached user-sensitive state

### Acceptance
- app branding matches the intended tenant
- auth does not fall back to the wrong tenant or default host silently
- enrolled course access works after login
- logout removes local auth state cleanly

## Runtime Proof Boundary

Do not claim the mobile lane is operationally resumed until all of these are
proved on real devices for the intended lane:

- auth works
- tenant branding is correct
- course access works
- release/distribution path works

Push, offline mode, and Android remain separate proofs; do not collapse them
into the iOS resume verdict.
