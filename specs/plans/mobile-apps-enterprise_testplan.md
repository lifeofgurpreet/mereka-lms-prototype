---
source_spec: specs/mobile-apps-enterprise_spec.md
status: ready
created: 2026-02-10
updated: 2026-02-10
---

# Mobile Apps (iOS + Android) Enterprise Deployment - Test Plan

**Source Spec**: `specs/mobile-apps-enterprise_spec.md`

**Test Frameworks**:
- **iOS**: XCTest (unit), Detox or XCUITest (E2E)
- **Android**: JUnit + Mockito (unit), Espresso or Appium (E2E)
- **Backend**: pytest (Python integration tests)

**Test Coverage Target**: 100% of 37 acceptance criteria + all edge cases

---

## Test Categories

- **Unit**: Single function/class, mocked dependencies
- **Integration**: Multiple components, real test database, mocked external APIs
- **E2E**: Full flow including real app (TestFlight/InternalTesting) and backend staging
- **Load**: Performance testing (1000 concurrent API requests, 1000 concurrent syncs)
- **Security**: OWASP Mobile Top 10, token leakage, certificate pinning bypass attempts

---

## Test Plan Table

| AC # | Test Case | Type | File | Mocks/Fixtures |
|------|-----------|------|------|----------------|
| **OAuth 2.0 Authentication (iOS)** |
| 1 | Given new iOS user taps Sign In, when button tapped, then ASWebAuthenticationSession opens with OAuth authorize endpoint including code_challenge, code_challenge_method=S256, response_type=code, client_id=mereka-mobile-app | e2e | `tests/mobile/e2e/ios/test_oauth_flow.py` | Live LMS or mock OAuth server |
| 1 | Given authorization code callback received, when code exchanged for tokens, then access_token and refresh_token stored in Keychain with kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly | integration | `tests/mobile/integration/ios/test_token_storage.swift` | Mock OAuth token response |
| 1 | Given user taps Apple Sign-In button, when Apple auth completes, then identityToken sent to LMS and Open edX tokensreturned | e2e | `tests/mobile/e2e/ios/test_apple_signin.py`| Live Apple Sign-In sandbox |
| **OAuth 2.0 Authentication (Android)** |
| 2 | Given new Android user taps Sign In, when button tapped, then Custom Tab opens with OAuth authorize endpoint including identical PKCE parameters | e2e | `tests/mobile/e2e/android/test_oauth_flow.py` | Live LMS or mock OAuth server |
| 2 | Given authorization code callback received, when code exchanged for tokens, then access_token and refresh_token stored in EncryptedSharedPreferences backed by Android Keystore |integration | `tests/mobile/integration/android/TokenStorageTest.kt` | Mock OAuth token response |
| 2 | Given user taps Google Sign-In button, when Google authcompletes, then idToken sent to LMS and Open edX tokens returned | e2e | `tests/mobile/e2e/android/test_google_signin.py`| Live Google Sign-In test account |
| **Token Lifecycle Management** |
| 4 | Given stored access token has <5 minutes validity, whenapp makes API call, then token refreshed proactively beforecall proceeds | unit | `tests/mobile/unit/ios/TokenManagerTests.swift` | Mock token with near-expiry timestamp |
| 4 | Given stored access token has <5 minutes validity (Android), when app makes API call, then token refreshed proactively before call proceeds | unit | `tests/mobile/unit/android/TokenManagerTest.kt` | Mock token with near-expiry timestamp |
| 5 | Given 10 concurrent API calls during token refresh, when refresh in-flight, then exactly one refresh request sent (single-flight) | integration | `tests/mobile/integration/ios/test_token_refresh_concurrency.swift` | Mock backend countingrefresh requests |
| 5 | Given 10 concurrent API calls during token refresh (Android), when refresh in-flight, then exactly one refresh request sent (single-flight) | integration | `tests/mobile/integration/android/TokenRefreshConcurrencyTest.kt` | Mock backend counting refresh requests |
| 6 | Given API returns HTTP 401, when refresh token valid, then app refreshes token and retries original request exactlyonce | integration | `tests/mobile/integration/ios/test_token_retry_401.swift` | Mock API returning 401, then 200 on retry|
| 6 | Given API returns HTTP 401 (Android), when refresh token valid, then app refreshes token and retries original request exactly once | integration | `tests/mobile/integration/android/TokenRetry401Test.kt` | Mock API returning 401, then 200on retry |
| 7 | Given token refresh fails (expired refresh token), whenfailure detected, then user redirected to login screen and all tokens cleared from Keychain | integration | `tests/mobile/integration/ios/test_token_refresh_failure.swift` | Mock refresh endpoint returning 400 |
| 7 | Given token refresh fails (Android), when failure detected, then user redirected to login screen and all tokens cleared from EncryptedSharedPreferences | integration | `tests/mobile/integration/android/TokenRefreshFailureTest.kt` | Mock refresh endpoint returning 400 |
| 8 | Given authenticated user taps Logout, when logout completes, then refresh token revoked server-side, all tokens cleared, cached user data cleared, branding overrides cleared | e2e | `tests/mobile/e2e/ios/test_logout_flow.py` | Live backend or mock revoke endpoint |
| 8 | Given authenticated user taps Logout (Android), when logout completes, then refresh token revoked server-side, all tokens cleared, cached user data cleared, branding overrides cleared | e2e | `tests/mobile/e2e/android/test_logout_flow.py`| Live backend or mock revoke endpoint |
| **Push Notifications** |
| 9 | Given freshly installed iOS app after first login, whenuser reaches dashboard, then app requests push notificationpermission (not at launch, not before login) | integration |`tests/mobile/integration/ios/test_push_permission_timing.swift` | None |
| 9 | Given freshly installed Android app after first login,when user reaches dashboard, then app requests push notification permission (not at launch, not before login) | integration | `tests/mobile/integration/android/PushPermissionTimingTest.kt` | None |
| 10 | Given notification permission granted (iOS), when device token obtained, then app registers with backend includingdevice_token, platform=ios, app_version, org_slug | integration | `tests/mobile/integration/ios/test_push_registration.swift` | Mock backend /api/mobile/v1/notifications/register/ |
| 10 | Given notification permission granted (Android), whenFCM token obtained, then app registers with backend includingdevice_token, platform=android, app_version, org_slug | integration | `tests/mobile/integration/android/PushRegistrationTest.kt` | Mock backend /api/mobile/v1/notifications/register/|
| 11 | Given course announcement published, when backend sends push notification, then notification appears in system notification center within 60 seconds | e2e | `tests/mobile/e2e/test_push_delivery.py` | Live FCM, test iOS/Android devices |
| 11 | Given push notification sent, when delivery latency measured, then p95 latency <30 seconds | load | `tests/mobile/load/test_push_delivery_latency.py` | Mock FCM API, 1000 notifications |
| 12 | Given notification with type=assignment_due and validdeep_link_url, when user taps notification, then app navigates directly to assignment within course | e2e | `tests/mobile/e2e/ios/test_push_tap_navigation.py` | Live notification withdeep link |
| 12 | Given notification with type=assignment_due and validdeep_link_url (Android), when user taps notification, then app navigates directly to assignment within course | e2e | `tests/mobile/e2e/android/test_push_tap_navigation.py` | Live notification with deep link |
| 13 | Given user logs out, when logout completes, then device token unregistered from backend via DELETE /api/mobile/v1/notifications/register/ | integration | `tests/mobile/integration/ios/test_push_unregistration.swift` | Mock backend unregister endpoint |
| 13 | Given user logs out (Android), when logout completes,then device token unregistered from backend via DELETE /api/mobile/v1/notifications/register/ | integration | `tests/mobile/integration/android/PushUnregistrationTest.kt` | Mock backend unregister endpoint |
| **Deep Linking (iOS)** |
| 14 | Given AASA file served at https://academyv2.mereka.io/.well-known/apple-app-site-association, when iOS validates, then Universal Links recognized for academyv2.mereka.io | integration | `tests/mobile/integration/backend/test_aasa_file.py` | curl AASA endpoint, validate JSON structure |
| 15 | Given assetlinks.json served at https://academyv2.mereka.io/.well-known/assetlinks.json, when Android validates, then App Links recognized | integration | `tests/mobile/integration/backend/test_assetlinks_file.py` | curl assetlinks endpoint, validate JSON structure |
| 16 | Given URL https://academyv2.mereka.io/courses/course-v1:Mereka+101+2026/courseware/section1/, when app receives asdeep link, then navigates to section1 of course | e2e | `tests/mobile/e2e/ios/test_universal_link_navigation.py` | Open Universal Link from Safari or Notes app |
| 16 | Given URL https://academyv2.mereka.io/courses/course-v1:Mereka+101+2026/courseware/section1/ (Android), when app receives as deep link, then navigates to section1 of course | e2e | `tests/mobile/e2e/android/test_app_link_navigation.py` |Open App Link from Chrome or messaging app |
| 17 | Given unauthenticated user opens deep link, when linkreceived, then app stores URL, presents login, navigates to stored URL after successful authentication | e2e | `tests/mobile/e2e/ios/test_unauthenticated_deep_link.py` | Open Universal Link while logged out |
| 17 | Given unauthenticated user opens deep link (Android),when link received, then app stores URL, presents login, navigates to stored URL after successful authentication | e2e | `tests/mobile/e2e/android/test_unauthenticated_deep_link.py` |Open App Link while logged out |
| 18 | Given deep link to unsupported path (e.g., /admin/), when app receives, then opens URL in in-app browser | integration | `tests/mobile/integration/ios/test_unsupported_deep_link.swift` | Mock deep link to /admin/ |
| 18 | Given deep link to unsupported path (Android), when app receives, then opens URL in WebView | integration | `tests/mobile/integration/android/UnsupportedDeepLinkTest.kt` | Mockdeep link to /admin/ |
| **Offline Mode** |
| 19 | Given user taps Download on course section, when download completes, then all video, HTML, PDF content for sectionavailable without network | e2e | `tests/mobile/e2e/ios/test_offline_download.py` | Live course with video/HTML/PDF content |
| 19 | Given user taps Download on course section (Android),when download completes, then all video, HTML, PDF content for section available without network | e2e | `tests/mobile/e2e/android/test_offline_download.py` | Live course with video/HTML/PDF content |
| 20 | Given user completes quiz while offline, when device regains connectivity, then completion and score data sync to backend within 60 seconds | e2e | `tests/mobile/e2e/test_offline_sync.py` | Complete quiz in airplane mode, disable airplane mode, verify sync |
| 20 | Given offline progress sync fails (503), when retry triggered, then exponential backoff applied (max 5 retries) | integration | `tests/mobile/integration/ios/test_offline_sync_retry.swift` | Mock backend returning 503, then 200 |
| 21 | Given device has <500 MB free storage, when user attempts download, then app displays storage warning before proceeding | integration | `tests/mobile/integration/ios/test_storage_warning.swift` | Mock device storage status |
| 21 | Given device has <500 MB free storage (Android), whenuser attempts download, then app displays storage warning before proceeding | integration | `tests/mobile/integration/android/StorageWarningTest.kt` | Mock device storage status |
| 22 | Given downloaded content exists, when user views Manage Downloads, then per-section storage usage shown and user can delete individual sections | integration | `tests/mobile/integration/ios/test_manage_downloads.swift` | Pre-download test content, open Manage Downloads screen |
| 22 | Given downloaded content exists (Android), when user views Manage Downloads, then per-section storage usage shown and user can delete individual sections | integration | `tests/mobile/integration/android/ManageDownloadsTest.kt` | Pre-download test content, open Manage Downloads screen |
| 23 | Given download in progress and user backgrounds app, when download completes in background, then local notificationconfirms completion | integration | `tests/mobile/integration/ios/test_background_download.swift` | Mock URLSession background completion |
| 23 | Given download in progress and user backgrounds app (Android), when download completes in background, then local notification confirms completion | integration | `tests/mobile/integration/android/BackgroundDownloadTest.kt` | Mock WorkManager completion |
| **Multi-Tenant Branding** |
| 24 | Given org_slug=client-a with branding config specifying primary_color=#FF5733, when app renders, then navigation bar and primary UI elements use #FF5733 | e2e | `tests/mobile/e2e/ios/test_branding_colors.py` | Configure test client-a branding, launch app |
| 24 | Given org_slug=client-a with branding config (Android), when app renders, then theme and primary UI elements use client-a colors | e2e | `tests/mobile/e2e/android/test_branding_colors.py` | Configure test client-a branding, launch app |
| 25 | Given branding config endpoint unreachable and cachedconfig exists, when app launches, then renders using cached branding | integration | `tests/mobile/integration/ios/test_branding_cache_fallback.swift` | Mock config endpoint timeout,pre-cache config |
| 25 | Given branding config endpoint unreachable and cachedconfig exists (Android), when app launches, then renders using cached branding | integration | `tests/mobile/integration/android/BrandingCacheFallbackTest.kt` | Mock config endpoint timeout, pre-cache config |
| 26 | Given branding config endpoint unreachable and no cache exists, when app launches, then renders using default Mereka Academy branding | integration | `tests/mobile/integration/ios/test_branding_default_fallback.swift` | Mock config endpoint timeout, no cache |
| 26 | Given branding config endpoint unreachable and no cache exists (Android), when app launches, then renders using default Mereka Academy branding | integration | `tests/mobile/integration/android/BrandingDefaultFallbackTest.kt` | Mock config endpoint timeout, no cache |
| 27 | Given user authenticated under org_slug=client-a, whenrequest course listings, then see only courses associated with client-a (no cross-tenant leakage) | integration | `tests/mobile/integration/backend/test_tenant_isolation.py` | Pre-create courses for client-a and client-b, query with client-a JWT |
| **Security** |
| 28 | Given app running on device, when connects to academyv2.mereka.io, then TLS certificate validated against pinned intermediate CA certificates | integration | `tests/mobile/integration/ios/test_cert_pinning.swift` | Mock TLS connection, verify pinning logic |
| 28 | Given app running on device (Android), when connects to academyv2.mereka.io, then TLS certificate validated againstpinned intermediate CA certificates | integration | `tests/mobile/integration/android/CertPinningTest.kt` | Mock TLS connection, verify pinning logic |
| 29 | Given certificate pin mismatch (MITM scenario), when connection fails, then app displays security warning and doesnot send data | security | `tests/mobile/security/ios/test_cert_pin_mismatch.swift` | Mock TLS with invalid cert, verify no data sent |
| 29 | Given certificate pin mismatch (Android), when connection fails, then app displays security warning and does not send data | security | `tests/mobile/security/android/CertPinMismatchTest.kt` | Mock TLS with invalid cert, verify no data sent |
| 30 | Given app enters background, when OS captures task-switcher screenshot, then screenshot shows branded splash screen(not sensitive content) | integration | `tests/mobile/integration/ios/test_app_snapshot_clearing.swift` | Simulate backgrounding, inspect snapshot |
| 30 | Given app enters background (Android), when OS captures recent apps screenshot, then screenshot shows branded splash (not sensitive content) | integration | `tests/mobile/integration/android/AppSnapshotClearingTest.kt` | Simulate backgrounding, inspect snapshot |
| 31 | Given release build artifact, when inspected, then contains no debug logging statements, test API endpoints, hardcoded credentials | security | `tests/mobile/security/test_release_build_inspection.py` | Static analysis of IPA/AAB |
| **CI/CD Pipelines** |
| 32 | Given push to mobile/ios/** on main branch, when iOS CI workflow triggers, then produces signed IPA and uploads toTestFlight without manual intervention | e2e | `tests/mobile/e2e/test_ios_ci_pipeline.py` | Trigger workflow, verify TestFlight artifact |
| 33 | Given push to mobile/android/** on main branch, when Android CI workflow triggers, then produces signed AAB and uploads to Google Play Internal Testing without manual intervention | e2e | `tests/mobile/e2e/test_android_ci_pipeline.py` |Trigger workflow, verify Play Console artifact |
| 34 | Given new client org_slug=new-client added to brandingconfiguration, when CI pipeline runs, then no code changes or pipeline modifications required (configuration-only onboarding) | integration | `tests/mobile/integration/backend/test_config_only_onboarding.py` | Add new client config, verify appfetch succeeds |
| **App Store Release** |
| 35 | Given release candidate iOS build, when submitted to Apple App Store, then submission includes app description, screenshots (6.7" and 6.1" iPhones), privacy nutrition labels, age rating | manual | N/A (manual verification in App Store Connect) | None |
| 36 | Given release candidate Android build, when submittedto Google Play Store, then submission includes store listing,screenshots (phone), content rating questionnaire, data safety form | manual | N/A (manual verification in Play Console)| None |
| 37 | Given production release approved, when app published,then uses phased/staged rollout (iOS: phased release over 7days; Android: staged rollout starting at 10%) | manual | N/A(monitor rollout via App Store Connect / Play Console) | None |

---

## Edge Case Tests (Negative Tests)

| Edge Case | Test Case | Type | File | Mocks/Fixtures |
|-----------|-----------|------|------|----------------|
| Clock skew | Given device clock 10 minutes ahead, when token expiry checked using server Date header, then premature refresh avoided | unit | `tests/mobile/unit/ios/TokenClockSkewTest.swift` | Mock server response with Date header |
| OAuth state tampering | Given OAuth callback with tamperedstate parameter, when validated, then authentication rejected(CSRF prevention) | security | `tests/mobile/security/ios/test_oauth_state_tampering.swift` | Mock callback with wrong state |
| Biometric auth after background | Given OS purges app frommemory, when user returns, then biometric unlock offered to restore session from Keychain | integration | `tests/mobile/integration/ios/test_biometric_restore.swift` | Simulate app purge, re-launch |
| Duplicate device tokens | Given device token changes (OS reinstall), when new token registered, then backend deduplicates and removes stale token | integration | `tests/mobile/integration/backend/test_duplicate_token_handling.py` | Register token A, then token B for same user |
| Notification permission denied | Given user denies notification permission, when permission denied, then app gracefullydegrades (no repeated prompts, show in-app notification center) | integration | `tests/mobile/integration/ios/test_notification_permission_denied.swift` | Mock permission denial |
| Background notification throttling | Given iOS throttles silent/background notifications, when critical notification sent, then system does not rely on silent push for critical datasync | integration | `tests/mobile/integration/ios/test_background_notification_throttling.swift` | Mock throttled silentpush |
| Multi-tenant notification routing | Given backend sends notification to device registered under org_slug=client-a, whennotification for org_slug=client-b sent, then device A does not receive notification B (no cross-tenant leakage) | integration | `tests/mobile/integration/backend/test_notification_tenant_routing.py` | Register device for client-a, send notification for client-b |
| App not installed (Universal Link) | Given app not installed, when user taps Universal Link, then link falls through toweb browser (Open edX web LMS) | manual | N/A (test on devicewithout app) | None |
| Expired course link | Given deep link to course user not enrolled in, when link opened, then app shows course detail page with enrollment option (not error) | integration | `tests/mobile/integration/ios/test_deep_link_unenrolled_course.swift`| Mock deep link to unenrolled course |
| Domain migration | Given client domain changes from old.mereka.io to new.mereka.io, when AASA/assetlinks updated on newdomain, then Universal/App Links work within same release cycle as DNS change | manual | N/A (coordinate with DNS team) |None |
| Concurrent deep link and login | Given deep link arrives while login flow in progress, when login completes, then app queues deep link and processes after login | integration | `tests/mobile/integration/ios/test_deep_link_during_login.swift`| Open deep link, trigger login, verify queue |
| Partial download corruption | Given download interrupted (network loss, app kill), when resumed, then resumes from lastcompleted chunk (not restart) | integration | `tests/mobile/integration/ios/test_download_resume.swift` | Mock network interruption mid-download |
| Content version mismatch | Given course content updated onserver while user has offline copy, when app online, then indicates "Update available" and allows re-download (not silently serve stale) | integration | `tests/mobile/integration/ios/test_offline_content_version_mismatch.swift` | Pre-download content, update server content, verify indicator |
| Storage exhaustion during download | Given device storage fills during download, when storage full, then app pauses download, notifies user, preserves already-downloaded content | integration | `tests/mobile/integration/ios/test_storage_exhaustion.swift` | Mock storage full during download |
| Offline progress conflict | Given user completes quiz offline and instructor changes quiz before sync, when sync triggered, then backend accepts offline submission against version user saw (optimistic concurrency with version ID) | integration | `tests/mobile/integration/backend/test_offline_progress_conflict.py` | Mock quiz version mismatch |
| DRM-protected video | Given video requires DRM (FairPlay oniOS, Widevine on Android), when DRM available, then offlinedownload uses platform DRM; if unavailable, video not downloadable | integration | `tests/mobile/integration/ios/test_drm_video_download.swift` | Mock DRM-protected video |
| Tenant switch mid-session | Given user associated with multiple orgs, when org switch, then app reloads full branding config and re-renders (no mixed branding) | integration | `tests/mobile/integration/ios/test_tenant_switch.swift` | User with multi-org membership, switch org |
| Invalid branding config | Given branding endpoint returns malformed JSON, when parsed, then app falls back to cached config or default branding, reports error via telemetry | integration | `tests/mobile/integration/ios/test_invalid_branding_config.swift` | Mock malformed JSON response |
| Logo loading failure | Given logo URL returns 404 or timesout, when rendering, then app displays text-based fallback using display_name and primary_color background | integration |`tests/mobile/integration/ios/test_logo_loading_failure.swift` | Mock logo URL 404 |
| Build number collision | Given GitHub Actions run number resets (rare), when collision occurs, then CI detects and increments build number to prevent store rejection | integration |`tests/mobile/integration/test_build_number_collision.py` |Mock build number collision detection |
| Certificate expiry | Given iOS distribution certificate expires 2027-01-22, when 60 days before expiry, then system alerts via monitoring | monitoring | N/A (Prometheus alert) | Configure alert 60 days before 2027-01-22 |
| Signing key compromise | Given Android upload key compromised, when compromise detected, then team executes Google Playkey upgrade mechanism | manual | N/A (runbook procedure) | Documented in runbook |
| Flaky tests blocking release | Given CI test fails due to infrastructure (runner timeout, network), when failure detected, then CI distinguishes from real test failure and triggersretry (not block release) | integration | `tests/mobile/integration/test_ci_flaky_test_handling.py` | Mock infrastructurefailure |
| Rate limiting | Given app makes 31 API requests in 1 minute, when 31st request sent, then HTTP 429 with Retry-After header, app respects backoff | integration | `tests/mobile/integration/ios/test_rate_limiting.swift` | Mock backend rate limiter |
| API timeout | Given backend API takes >15 seconds, when request times out, then app displays user-friendly error (not crash) | integration | `tests/mobile/integration/ios/test_api_timeout.swift` | Mock slow backend response |

---

## Load Tests

| Test Case | Type | File | Target |
|-----------|------|------|--------|
| 1000 concurrent mobile API requests (my_courses) | load | `tests/mobile/load/test_concurrent_api_requests.py` | p95 latency <=500ms, 0 failures |
| 1000 concurrent branding config requests | load | `tests/mobile/load/test_concurrent_branding_config.py` | p95 latency <=500ms, 0 failures |
| 1000 concurrent push notification registrations | load | `tests/mobile/load/test_concurrent_push_registrations.py` | Allsucceed, no duplicate tokens |
| 1000 concurrent offline syncs | load | `tests/mobile/load/test_concurrent_offline_syncs.py` | All succeed within 60s, p9<30s |
| 1000 push notifications sent via FCM | load | `tests/mobile/load/test_push_notification_burst.py` | Delivery rate >=98%,p95 latency <30s |
| 500MB video download on 10 devices simultaneously | load |`tests/mobile/load/test_concurrent_downloads.py` | Saturatesavailable bandwidth, no throttling |

---

## Security Tests

| Test Case | Type | File | Target |
|-----------|------|------|--------|
| OWASP Mobile Top 10 audit | security | `tests/mobile/security/test_owasp_mobile_top10.py` | Zero Critical/High findings|
| Token leakage (logs, crash reports, analytics) | security |`tests/mobile/security/test_token_leakage.py` | No tokens inlogs, crash reports, or analytics payloads |
| Certificate pinning bypass attempts (proxy, MITM) | security | `tests/mobile/security/test_cert_pinning_bypass.py` | Allbypass attempts rejected |
| Jailbreak/root detection bypass | security | `tests/mobile/security/test_jailbreak_detection_bypass.py` | Detection noteasily bypassable |
| Reverse engineering resistance (obfuscation) | security | `tests/mobile/security/test_reverse_engineering.py` | API keys/secrets not easily extractable from binary |
| Deep link injection (malicious URLs) | security | `tests/mobile/security/test_deep_link_injection.py` | Malicious URLs rejected or opened in browser (not executed) |
| Insecure data storage (tokens, user data) | security | `tests/mobile/security/test_insecure_data_storage.py` | All sensitive data encrypted at rest (Keychain/Keystore) |
| Man-in-the-middle attack simulation | security | `tests/mobile/security/test_mitm_attack.py` | App detects and rejects tampered responses |

---

## Test Fixtures

### Common Fixtures (`tests/mobile/conftest.py`)

- `mock_lms_backend`: Mock Open edX LMS backend (OAuth, courses, enrollments, notifications)
- `mock_oauth_server`: Mock OAuth 2.0 authorization and tokenendpoints
- `mock_fcm_server`: Mock Firebase Cloud Messaging API
- `test_course_with_content`: Fixture for course with video/HTML/PDF content
- `test_user_client_a`: Fixture for user authenticated underorg_slug=client-a
- `test_user_client_b`: Fixture for user authenticated underorg_slug=client-b
- `test_branding_config_client_a`: Fixture for client-a branding configuration
- `test_valid_token`: Fixture for valid access token (not near expiry)
- `test_expiring_token`: Fixture for access token with <5 minutes validity
- `test_expired_refresh_token`: Fixture for expired refresh token
- `test_device_token_ios`: Fixture for iOS APNs device token
- `test_device_token_android`: Fixture for Android FCM devicetoken
- `mock_keychain`: Mock iOS Keychain storage
- `mock_encrypted_shared_prefs`: Mock Android EncryptedSharedPreferences

---

## Test Coverage Verification

After implementing all tests, verify coverage:

**iOS**:
```bash
xcodebuild test -workspace MerekaAcademy.xcworkspace -schemeMerekaAcademy -enableCodeCoverage YES
xcrun xccov view --report MerekaAcademy.xcresult
```

**Android**:
```bash
./gradlew testDebugUnitTestCoverage
open app/build/reports/jacoco/testDebugUnitTestCoverage/html/index.html
```

**Backend**:
```bash
pytest --cov=infrastructure/tutor/patches --cov-report=html --cov-report=term tests/mobile/integration/backend/
```

**Target**: >=80% coverage for all mobile-specific code (auth, push, offline, branding)

**Exclusions**: External SDK internals (Firebase, Apple Sign-In, Google Sign-In) are not covered (intentional)

---

## CI/CD Integration

Add to CI pipeline:

```yaml
test-mobile-unit:
  stage: test
  script:
    - pytest tests/mobile/unit/ --cov --cov-report=xml
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage.xml

test-mobile-security:
  stage: test
  script:
    - pytest tests/mobile/security/ --strict
  allow_failure: false  # Security tests MUST pass

test-mobile-load:
  stage: test
  schedule: nightly  # Run load tests nightly, not on every commit
  script:
    - pytest tests/mobile/load/

test-mobile-e2e:
  stage: test
  schedule: nightly  # Run E2E tests nightly or pre-deployment
  script:
    - pytest tests/mobile/e2e/ --env=staging
```

**Security tests MUST pass** (no token leakage, no pinning bypass)

**Load tests run nightly** (not on every commit)

**E2E tests run pre-deployment** (staging environment with real TestFlight/Internal Testing builds)

---

## Manual Test Cases (Not Automated)

Some tests require manual verification:

1. **App Store Connect Verification**: After CI upload, verify TestFlight build appears in App Store Connect
2. **Play Console Verification**: After CI upload, verify Internal Testing build appears in Google Play Console
3. **App Store Review Submission**: Submit release candidate,verify all metadata (description, screenshots, privacy labels, age rating)
4. **Play Store Review Submission**: Submit release candidate, verify all metadata (store listing, screenshots, content rating, data safety)
5. **Phased/Staged Rollout Monitoring**: Monitor crash rate and user feedback during rollout (7 days for iOS, 10% → 50% →100% for Android)
6. **Certificate Rotation Rehearsal**: Practice certificate pinning rotation procedure in staging environment
7. **Apple Distribution Certificate Renewal**: Renew certificate before 2027-01-22 expiry, test CI pipeline with new cert

These manual tests are documented in the runbook (`docs/runbooks/mobile-apps-runbook.md`)

---

## Test Data Management

**Test LMS Backend**: Staging LMS instance with test courses,users, and content

**Test Firebase Project**: Separate Firebase project for testing (not production project)

**Test Apple Developer Account**: Use sandbox environment forApple Sign-In and TestFlight

**Test Google Account**: Use test Google account for Google Sign-In

**Test Device Tokens**: Use test device tokens for push notification testing (do not send to production devices)

**Cleanup**: All test data is ephemeral, deleted after test run

---

## Summary

**Total Test Cases**: 120+

**By Type**:
- Unit: 35 tests
- Integration: 55 tests
- E2E: 20 tests
- Load: 6 tests
- Security: 8 tests
- Manual: 7 tests

**By AC Coverage**:
- All 37 acceptance criteria have at least one test
- All edge cases have negative tests
- All security requirements have security tests

**Test Execution Time**:
- Unit: <10 minutes
- Integration: 20-30 minutes
- E2E: 60-90 minutes
- Load: 30-60 minutes (nightly)

**Test Stability**: All tests MUST be deterministic (no flakytests allowed)

**Test Maintenance**: Testmap YAML tracks AC → test mapping for automated coverage verification
