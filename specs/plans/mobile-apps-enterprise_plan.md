---
source_spec: specs/proposals/mobile-apps-enterprise_spec.md
status: ready
created: 2026-02-10
updated: 2026-02-10
spec: proposals/mobile-apps-enterprise_spec.md
last_updated: '2026-02-10'
---

# Mobile Apps (iOS + Android) Enterprise Deployment - Implementation Plan

**Source Spec**: `specs/proposals/mobile-apps-enterprise_spec.md`

**Spec Summary**: 37 Acceptance Criteria spanning mobile APIcontract, OAuth 2.0 authentication with PKCE, push notifications via FCM/APNs, deep linking, offline mode, multi-tenant branding, security hardening, and CI/CD pipelines for both iOSand Android.

---

## Task Categories

Tasks are grouped by category and ordered by dependency. Eachtask includes:
- **Complexity**: S (<2h), M (2-8h), L (>8h)
- **AC Mapping**: Which acceptance criteria this task addresses
- **File Path**: Where the work happens
- **Dependencies**: Prerequisites (or "None" if independent)

---

## Build Tasks

### Backend Mobile API Endpoints

- [ ] **[M]** Implement mobile branding configuration endpoint (`infrastructure/tutor/patches/mobile_branding_api.py`) | AC: #24-27 | Depends: None
  - Endpoint: `GET /api/mobile/v1/config/{org_slug}/`
  - Return JSON with: `org_slug`, `display_name`, `primary_color`, `accent_color`, `logo_url`, `logo_dark_url`, `favicon_url`, `splash_background_color`, `login_background_image_url`,`support_email`, `support_url`, `terms_url`, `privacy_url`,`feature_flags`
  - p95 latency target: <=500ms
  - Cache headers: `Cache-Control: public, max-age=3600`
  - Fallback to default Mereka Academy branding if org_slug not found

- [ ] **[M]** Implement push notification device registrationendpoint (`infrastructure/tutor/patches/mobile_push_notifications.py`) | AC: #9-13 | Depends: None
  - Endpoint: `POST /api/mobile/v1/notifications/register/`
  - Accept: `device_token`, `platform` (ios/android), `app_version`, `org_slug`
  - Store in database: `MobileDeviceToken` model with fields:`user_id`, `device_token`, `platform`, `app_version`, `org_slug`, `created_at`, `last_active_at`
  - Unique constraint on `device_token`
  - Update `last_active_at` on duplicate registration (idempotent)

- [ ] **[M]** Implement push notification device unregistration endpoint (`infrastructure/tutor/patches/mobile_push_notifications.py`) | AC: #13 | Depends: Registration endpoint
  - Endpoint: `DELETE /api/mobile/v1/notifications/register/`
  - Accept: `device_token`
  - Delete `MobileDeviceToken` record
  - Idempotent: return HTTP 200 if already deleted

- [ ] **[L]** Implement push notification dispatch service (`infrastructure/tutor/patches/mobile_push_dispatch.py`) | AC:#9-13 | Depends: Registration endpoint
  - Celery task: `send_mobile_push_notification(user_ids, notification_type, payload)`
  - Supported types: `course_announcement`, `assignment_due`,`grade_posted`, `discussion_reply`, `system_maintenance`
  - Payload format: `type`, `title`, `body`, `course_id`, `deep_link_url`, `org_slug`, `timestamp`
  - Firebase Admin SDK integration for FCM
  - Send to APNs via FCM (iOS devices register APNs token with FCM)
  - Batch notifications: group by 500 devices per FCM multicast request
  - p95 dispatch latency target: <=30s from event trigger

- [ ] **[M]** Implement notification triggers for supported event types (`infrastructure/tutor/patches/mobile_notification_triggers.py`) | AC: #9-13 | Depends: Dispatch service
  - Hook into Open edX signals:
    - `COURSE_ANNOUNCEMENT_SENT` → `course_announcement` notification
    - `ASSIGNMENT_DUE_REMINDER` (24h and 1h before) → `assignment_due` notification
    - `GRADE_POSTED` → `grade_posted` notification
    - `DISCUSSION_REPLY` → `discussion_reply` notification (only for followed threads)
    - Manual trigger for `system_maintenance` notification (Django admin action)
  - Filter recipients by enrolled course and `org_slug`
  - Include deep link URL in payload

### Backend Deep Linking Support

- [ ] **[M]** Implement AASA (Apple App Site Association) file endpoint (`infrastructure/tutor/patches/mobile_deep_linking.py`) | AC: #14-18 | Depends: None
  - Serve `apple-app-site-association` at `/.well-known/apple-app-site-association`
  - Content-Type: `application/json` (no `.json` extension infilename)
  - Include `appID` entries: `44F7G2D7U6.com.mereka.academy.mobile`
  - Paths: `/courses/*`, `/dashboard`, `/u/*`, `/courses/*/courseware/*`, `/courses/*/discussion/forum/*`
  - Cache headers: `Cache-Control: public, max-age=86400`

- [ ] **[M]** Implement assetlinks.json file endpoint (`infrastructure/tutor/patches/mobile_deep_linking.py`) | AC: #14-18| Depends: None
  - Serve `assetlinks.json` at `/.well-known/assetlinks.json`
  - Content-Type: `application/json`
  - Include Android package name: `com.mereka.academy.mobile`
  - Include SHA-256 fingerprint from Android upload keystore(store in Infisical)
  - Cache headers: `Cache-Control: public, max-age=86400`

- [ ] **[S]** Update Caddy/Ingress to serve `.well-known` files from LMS (`infrastructure/caddy/Caddyfile`) | AC: #14, #15| Depends: AASA and assetlinks endpoints
  - Route `/.well-known/apple-app-site-association` to LMS
  - Route `/.well-known/assetlinks.json` to LMS
  - Ensure no authentication required for these endpoints

### iOS App Implementation

- [ ] **[L]** Implement OAuth 2.0 PKCE authorization flow iniOS app (`mobile/ios/Core/Core/Network/OAuth/`) | AC: #1-8 |Depends: None
  - Generate cryptographically random `code_verifier` (43-128chars, unreserved URI characters)
  - Derive `code_challenge` from `code_verifier` using SHA-25(S256 method)
  - Open system browser with `ASWebAuthenticationSession` forauthorization
  - Authorization URL: `https://{lms_host}/oauth2/authorize/?client_id={client_id}&response_type=code&redirect_uri={redirect_uri}&code_challenge={challenge}&code_challenge_method=S256`
  - Redirect URI: `com.mereka.academy.mobile://oauth-callback`
  - Handle callback, extract `code`, exchange for tokens at `POST /oauth2/access_token/`
  - Store tokens in Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`

- [ ] **[M]** Implement token lifecycle management in iOS app(`mobile/ios/Core/Core/Network/TokenManager/`) | AC: #4-8 |Depends: PKCE flow
  - Proactively refresh access token when <5 minutes validityremaining
  - Single-flight token refresh: queue concurrent API calls,issue one refresh request
  - Retry failed API call exactly once after successful refresh if original failure was HTTP 401
  - Revoke refresh token on logout via `POST /oauth2/revoke_token/`
  - Clear all tokens and cached user data from Keychain on logout
  - Redirect to login screen if token refresh fails

- [ ] **[M]** Implement Apple Sign-In integration in iOS app(`mobile/ios/Core/Core/Authentication/AppleSignIn/`) | AC: #1| Depends: PKCE flow
  - Use `AuthenticationServices` framework for Sign in with Apple
  - Extract `identityToken` and send to LMS backend for validation
  - Backend validates token with Apple servers
  - LMS returns Open edX OAuth tokens after successful AppleSign-In

- [ ] **[M]** Implement push notification registration in iOSapp (`mobile/ios/Core/Core/Notifications/`) | AC: #9-13 | Depends: None
  - Register for APNs using `UNUserNotificationCenter`
  - Request notification permission after first successful login (not at app launch)
  - Forward APNs device token to FCM via Firebase SDK
  - Call backend `POST /api/mobile/v1/notifications/register/` with FCM token, platform=ios, app_version, org_slug
  - Unregister on logout via `DELETE /api/mobile/v1/notifications/register/`

- [ ] **[M]** Implement push notification handling in iOS app(`mobile/ios/Core/Core/Notifications/`) | AC: #9-13 | Depends: Registration
  - Handle foreground notifications: display in-app banner
  - Handle background notifications: update badge count
  - Handle notification tap: parse `deep_link_url`, navigateto content
  - Support notification grouping by `course_id`
  - Log notification received and tapped events

- [ ] **[M]** Implement Universal Links handling in iOS app (`mobile/ios/Core/Core/Routing/UniversalLinks/`) | AC: #14-18| Depends: None
  - Implement `UIApplicationDelegate` `application(_:continue:restorationHandler:)` method
  - Parse URL patterns: `/courses/{course_id}/`, `/courses/{course_id}/courseware/{section_id}/`, `/courses/{course_id}/courseware/{section_id}/{unit_id}/`, `/dashboard`, `/u/{username}`, `/courses/{course_id}/discussion/forum/`
  - If unauthenticated: store URL, complete login, then navigate
  - If authenticated: navigate immediately
  - Fallback to in-app browser for unsupported paths

- [ ] **[L]** Implement offline course content download in iOS app (`mobile/ios/Core/Core/Offline/`) | AC: #19-23 | Depends: None
  - Download API: fetch course blocks, videos (HLS), HTML content, PDF attachments
  - Store in app sandbox: `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:)`
  - Track download progress with `URLSessionDownloadTask`
  - Support pause/resume via `URLSession` background configuration
  - Encrypt downloaded content using Data Protection API (`NSFileProtectionCompleteUntilFirstUserAuthentication`)
  - UI: show download icon per section, progress indicator, storage usage, delete option

- [ ] **[M]** Implement offline progress sync in iOS app (`mobile/ios/Core/Core/Offline/`) | AC: #20 | Depends: Download implementation
  - Queue completion/progress events locally (Core Data or Realm)
  - On connectivity restore: flush queue to backend API
  - Retry logic: exponential backoff, max 5 retries
  - Sync within 60 seconds of connectivity restoration (p95)

- [ ] **[M]** Implement multi-tenant branding configuration in iOS app (`mobile/ios/Core/Core/Branding/`) | AC: #24-27 | Depends: None
  - Fetch branding config at app launch: `GET /api/mobile/v1/config/{org_slug}/`
  - Cache config locally (UserDefaults or FileManager)
  - Apply colors dynamically: navigation bar, accent color, buttons
  - Load logo from `logo_url` (light mode) and `logo_dark_url` (dark mode)
  - Render splash screen with `splash_background_color`
  - Display login background image if `login_background_image_url` present
  - Fallback to default Mereka branding if config fetch failsand no cache exists

- [ ] **[M]** Implement TLS certificate pinning in iOS app (`mobile/ios/Core/Core/Network/CertificatePinning/`) | AC: #28-| Depends: None
  - Pin intermediate CA certificate (not leaf) for `*.mereka.io` and `*.biji-biji.com`
  - Include 2+ pins (primary + backup) to prevent lockout during rotation
  - Use `URLSession` `URLSessionDelegate` `urlSession(_:didReceive:completionHandler:)` for validation
  - Implement pin expiry mechanism: if all pins expired, fallback to standard TLS validation + telemetry alert
  - Log certificate validation failures

- [ ] **[M]** Implement security controls in iOS app (`mobile/ios/Core/Core/Security/`) | AC: #28-31 | Depends: None
  - Jailbreak detection: check for cydia, `/Applications/Cydia.app`, `/bin/bash` existence
  - Display warning if jailbroken (do not block usage)
  - Clear app snapshot on background: override `UIApplicationDelegate` `applicationDidEnterBackground` to show branded splash screen
  - Minimum OS version enforcement: iOS 16.0 (set in `Info.plist`)

- [ ] **[M]** Update iOS CI/CD pipeline for production build(`​.github/workflows/build-ios-app.yml`) | AC: #32, #34, #35| Depends: All iOS implementation tasks
  - Build number: use `GITHUB_RUN_NUMBER`
  - Version number: read from `marketing_version` in `project.yml`
  - Sign with distribution certificate (Team ID: `44F7G2D7U6`)
  - Upload IPA to TestFlight via Fastlane: `fastlane pilot upload`
  - Trigger on push to `mobile/ios/**` on `main` branch
  - Manual workflow_dispatch for release builds
  - Store App Store Connect API key in GitHub Secrets

- [ ] **[S]** Prepare iOS App Store listing assets (`mobile/ios/AppStore/`) | AC: #35 | Depends: None
  - App description (2-4 paragraphs)
  - Screenshots: 6.7" iPhone (Pro Max), 6.1" iPhone (standard)
  - Privacy nutrition labels: data collection categories (email, usage data)
  - Age rating: 4+ (no restricted content)
  - App category: Education
  - Keywords: learning, courses, education, academy

### Android App Implementation

- [ ] **[L]** Bootstrap Android app from `openedx-app-android` (`mobile/android/`) | AC: #33 | Depends: None
  - Fork/clone `https://github.com/openedx/openedx-app-android.git`
  - Apply Mereka branding: colors, logo, app name
  - Configure `applicationId`: `com.mereka.academy.mobile`
  - Set `minSdkVersion: 28` (Android 9.0)
  - Update Gradle build files for signing config (release keystore)

- [ ] **[L]** Implement OAuth 2.0 PKCE authorization flow inAndroid app (`mobile/android/core/src/main/java/org/openedx/core/network/oauth/`) | AC: #1-8 | Depends: Android bootstrap
  - Generate cryptographically random `code_verifier` (43-128chars, unreserved URI characters)
  - Derive `code_challenge` from `code_verifier` using SHA-25(S256 method)
  - Open Custom Tab for authorization via Chrome Custom Tabs
  - Authorization URL: same as iOS
  - Redirect URI: `com.mereka.academy.mobile://oauth-callback`
  - Handle callback, extract `code`, exchange for tokens
  - Store tokens in EncryptedSharedPreferences backed by Android Keystore

- [ ] **[M]** Implement token lifecycle management in Androidapp (`mobile/android/core/src/main/java/org/openedx/core/network/TokenManager.kt`) | AC: #4-8 | Depends: PKCE flow
  - Same logic as iOS: proactive refresh, single-flight, retry on 401, revoke on logout
  - Clear tokens from EncryptedSharedPreferences on logout

- [ ] **[M]** Implement Google Sign-In integration in Androidapp (`mobile/android/auth/src/main/java/org/openedx/auth/GoogleSignIn.kt`) | AC: #1 | Depends: PKCE flow
  - Use Google Sign-In SDK
  - Extract `idToken` and send to LMS backend for validation
  - Backend validates token with Google
  - LMS returns Open edX OAuth tokens after successful GoogleSign-In

- [ ] **[M]** Implement push notification registration in Android app (`mobile/android/core/src/main/java/org/openedx/core/notifications/`) | AC: #9-13 | Depends: Android bootstrap
  - Register for FCM using Firebase SDK
  - Request notification permission (Android 13+ requires runtime permission)
  - Call backend `POST /api/mobile/v1/notifications/register/` with FCM token, platform=android, app_version, org_slug
  - Unregister on logout via `DELETE /api/mobile/v1/notifications/register/`

- [ ] **[M]** Implement push notification handling in Androidapp (`mobile/android/core/src/main/java/org/openedx/core/notifications/`) | AC: #9-13 | Depends: Registration
  - Extend `FirebaseMessagingService` for FCM message handling
  - Handle foreground notifications: display in-app notification
  - Handle background notifications: update notification badge
  - Handle notification tap: parse `deep_link_url`, navigateto content
  - Support notification channels by type (course, grade, discussion, system)

- [ ] **[M]** Implement App Links handling in Android app (`mobile/android/core/src/main/java/org/openedx/core/routing/AppLinks.kt`) | AC: #14-18 | Depends: Android bootstrap
  - Declare intent filters in `AndroidManifest.xml` for `*.mereka.io` and `*.biji-biji.com` domains
  - Handle deep links in MainActivity `onNewIntent()`
  - Parse URL patterns: same as iOS
  - If unauthenticated: store URL, complete login, then navigate
  - Fallback to WebView for unsupported paths

- [ ] **[L]** Implement offline course content download in Android app (`mobile/android/course/src/main/java/org/openedx/course/offline/`) | AC: #19-23 | Depends: Android bootstrap
  - Download API: fetch course blocks, videos, HTML content,PDF attachments
  - Store in app-specific storage: `context.filesDir`
  - Track download progress with `WorkManager` (background downloads)
  - Support pause/resume via WorkManager constraints
  - Encrypt downloaded content using file-based encryption (default on Android 10+)
  - UI: show download icon per section, progress indicator, storage usage, delete option

- [ ] **[M]** Implement offline progress sync in Android app(`mobile/android/course/src/main/java/org/openedx/course/offline/`) | AC: #20 | Depends: Download implementation
  - Queue completion/progress events locally (Room database)
  - On connectivity restore: flush queue to backend API via WorkManager periodic task
  - Retry logic: exponential backoff, max 5 retries
  - Sync within 60 seconds of connectivity restoration (p95)

- [ ] **[M]** Implement multi-tenant branding configuration in Android app (`mobile/android/core/src/main/java/org/openedx/core/branding/`) | AC: #24-27 | Depends: Android bootstrap
  - Fetch branding config at app launch: `GET /api/mobile/v1/config/{org_slug}/`
  - Cache config locally (SharedPreferences or Room)
  - Apply colors dynamically: theme, navigation bar, accent color, buttons
  - Load logo from `logo_url` (light mode) and `logo_dark_url` (dark mode) via Coil/Glide
  - Render splash screen with `splash_background_color`
  - Display login background image if `login_background_image_url` present
  - Fallback to default Mereka branding if config fetch failsand no cache exists

- [ ] **[M]** Implement TLS certificate pinning in Android app (`mobile/android/core/src/main/java/org/openedx/core/network/CertificatePinning.kt`) | AC: #28-31 | Depends: Android bootstrap
  - Use OkHttp `CertificatePinner` for pinning
  - Pin intermediate CA certificate (not leaf) for `*.mereka.io` and `*.biji-biji.com`
  - Include 2+ pins (primary + backup)
  - Implement pin expiry mechanism: if all pins expired, fallback to standard TLS validation + telemetry alert
  - Log certificate validation failures

- [ ] **[M]** Implement security controls in Android app (`mobile/android/core/src/main/java/org/openedx/core/security/`)| AC: #28-31 | Depends: Android bootstrap
  - Root detection: check for `su` binary, Magisk, SuperSU, root management apps
  - Display warning if rooted (do not block usage)
  - Clear app snapshot on background: override `onPause()` inactivities to show branded splash
  - Minimum OS version enforcement: API level 28 (set in `build.gradle`)

- [ ] **[M]** Create Android CI/CD pipeline (`​.github/workflows/build-android-app.yml`) | AC: #33, #34, #36 | Depends: All Android implementation tasks
  - Build number: use `GITHUB_RUN_NUMBER`
  - Version number: read from `versionName` in `build.gradle`
  - Sign with upload key (stored in GitHub Secrets)
  - Upload AAB to Google Play Internal Testing via Fastlane:`fastlane supply`
  - Trigger on push to `mobile/android/**` on `main` branch
  - Manual workflow_dispatch for release builds
  - Store Google Play Service Account JSON in GitHub Secrets

- [ ] **[S]** Prepare Android Google Play Store listing assets (`mobile/android/PlayStore/`) | AC: #36 | Depends: None
  - Store listing (short description, full description)
  - Screenshots: phone (portrait and landscape)
  - Content rating: questionnaire responses (educational content, no violence/gambling)
  - Data safety form: data collection categories (email, usage data)
  - App category: Education

### Database & Secrets

- [ ] **[S]** Create database migration for mobile device tokens (`infrastructure/tutor/migrations/`) | Depends: None
  - Table: `mobile_device_tokens`
  - Columns: `id`, `user_id` (FK), `device_token` (unique), `platform` (enum: ios/android), `app_version`, `org_slug`, `created_at`, `last_active_at`
  - Indexes: `user_id`, `org_slug`, `platform`, `last_active_at`

- [ ] **[S]** Store Firebase Cloud Messaging server key in Infisical (`scripts/infra/create-mobile-secrets.sh`) | Depends:None
  - Secret name: `MEREKA_LMS_FCM_SERVER_KEY`
  - Obtain from Firebase Console → Project Settings → Cloud Messaging → Server key
  - Sync to GCP Secret Manager
  - Create ExternalSecret manifest: `deploy/k8s/base/secrets/mobile-secrets.yaml`

- [ ] **[S]** Store Android upload keystore in Infisical (`scripts/infra/create-mobile-secrets.sh`) | Depends: None
  - Generate upload keystore: `keytool -genkey -v -keystore upload-keystore.jks -alias mereka-mobile -keyalg RSA -keysize
validity 10000`
  - Extract SHA-256 fingerprint: `keytool -list -v -keystoreupload-keystore.jks -alias mereka-mobile | grep SHA256`
  - Store keystore file in Infisical as base64-encoded secret: `MEREKA_LMS_ANDROID_UPLOAD_KEYSTORE_BASE64`
  - Store keystore password: `MEREKA_LMS_ANDROID_UPLOAD_KEYSTORE_PASSWORD`
  - Store key alias password: `MEREKA_LMS_ANDROID_KEY_ALIAS_PASSWORD`
  - Store SHA-256 fingerprint for assetlinks.json

- [ ] **[S]** Store Apple App Store Connect API key in GitHubSecrets | Depends: None
  - Generate API key in App Store Connect → Users and Access→ Keys
  - Store in GitHub Secrets: `APPLE_API_KEY_ID`, `APPLE_API_ISSUER_ID`, `APPLE_API_KEY_CONTENT`

- [ ] **[S]** Store Google Play Service Account JSON in GitHub Secrets | Depends: None
  - Create Service Account in Google Cloud Console
  - Grant permissions in Google Play Console → Setup → API access
  - Download JSON key
  - Store in GitHub Secrets: `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`

---

## Test Tasks

- [ ] **[M]** Write unit tests for OAuth PKCE flow (`tests/mobile/unit/test_oauth_pkce.py`) | AC: #1-8 | Depends: OAuth implementation
  - Verify code_verifier generation (43-128 chars, valid characters)
  - Verify code_challenge derivation (SHA-256, base64url encoding)
  - Verify authorization URL includes correct parameters
  - Mock token exchange, verify correct POST body

- [ ] **[M]** Write unit tests for token lifecycle management(`tests/mobile/unit/test_token_lifecycle.py`) | AC: #4-8 | Depends: Token manager implementation
  - Token refresh triggered when <5min validity
  - Single-flight refresh (concurrent calls queue)
  - Retry on 401 exactly once
  - Logout clears all tokens
  - Redirect to login on refresh failure

- [ ] **[M]** Write integration tests for push notification registration (`tests/mobile/integration/test_push_registration.py`) | AC: #9-13 | Depends: Backend registration endpoint
  - POST /api/mobile/v1/notifications/register/ with valid payload returns HTTP 200
  - Duplicate registration updates last_active_at (idempotent)
  - DELETE unregisters device token
  - Query device tokens by user_id returns correct records

- [ ] **[M]** Write integration tests for push notification dispatch (`tests/mobile/integration/test_push_dispatch.py`) |AC: #9-13 | Depends: Backend dispatch service
  - Mock FCM API
  - Dispatch notification to 1 device → FCM send called withcorrect payload
  - Dispatch to 500 devices → batched into multicast requests
  - Dispatch latency <30s (p95)

- [ ] **[M]** Write unit tests for branding configuration endpoint (`tests/mobile/unit/test_branding_config.py`) | AC: #24-27 | Depends: Backend branding endpoint
  - GET /api/mobile/v1/config/{org_slug}/ returns correct JSON structure
  - Invalid org_slug returns default Mereka branding (not 404)
  - Response includes Cache-Control header
  - p95 latency <500ms

- [ ] **[M]** Write unit tests for certificate pinning (`tests/mobile/unit/test_cert_pinning.py`) | AC: #28-31 | Depends:Certificate pinning implementation
  - Valid certificate passes pinning check
  - Invalid certificate fails pinning check
  - Expired pins fall back to standard TLS validation
  - Pin mismatch logs security event

- [ ] **[M]** Write unit tests for security controls (`tests/mobile/unit/test_security_controls.py`) | AC: #28-31 | Depends: Security implementation
  - Jailbreak/root detection returns correct boolean
  - App snapshot clearing on background invoked correctly
  - Minimum OS version enforcement blocks lower versions

- [ ] **[L]** Write E2E tests for iOS full authentication flow (`tests/mobile/e2e/test_ios_auth_flow.py`) | AC: #1-8 | Depends: iOS app implementation
  - Launch app → tap Sign In → ASWebAuthenticationSession opens → enter credentials → redirect to app → tokens stored in Keychain
  - Agent Browser or Detox for iOS automation

- [ ] **[L]** Write E2E tests for Android full authenticationflow (`tests/mobile/e2e/test_android_auth_flow.py`) | AC: #1-8 | Depends: Android app implementation
  - Launch app → tap Sign In → Custom Tab opens → enter credentials → redirect to app → tokens stored in EncryptedSharedPreferences
  - Appium or Espresso for Android automation

- [ ] **[M]** Write E2E tests for deep linking (`tests/mobile/e2e/test_deep_linking.py`) | AC: #14-18 | Depends: Deep linking implementation
  - Open Universal Link (iOS) or App Link (Android) → app navigates to correct screen
  - Unauthenticated deep link → login → navigate to stored URL
  - Unsupported deep link → open in-app browser

- [ ] **[M]** Write integration tests for offline download (`tests/mobile/integration/test_offline_download.py`) | AC: #19-23 | Depends: Offline implementation
  - Download course section → files stored in sandbox
  - Pause → resume download → completes successfully
  - Storage warning triggered when <500 MB free
  - Delete downloaded content → files removed

- [ ] **[M]** Write integration tests for offline sync (`tests/mobile/integration/test_offline_sync.py`) | AC: #20 | Depends: Offline sync implementation
  - Complete quiz offline → queue event → regain connectivity→ event synced within 60s
  - Retry logic on sync failure (exponential backoff)

- [ ] **[M]** Write integration tests for multi-tenant branding (`tests/mobile/integration/test_multi_tenant_branding.py`)| AC: #24-27 | Depends: Branding implementation
  - Fetch config for client-a → colors applied correctly
  - Config fetch fails, cache exists → use cached config
  - Config fetch fails, no cache → use default Mereka branding
  - No cross-tenant data leakage (user from client-a sees only client-a courses)

- [ ] **[M]** Write load tests for mobile API endpoints (`tests/mobile/load/test_mobile_api_load.py`) | Depends: All backend endpoints
  - 100 concurrent requests to /api/mobile/v4/my_courses/ → p<500ms
  - 100 concurrent requests to /api/mobile/v1/config/{org_slug}/ → p95 <500ms
  - 1000 concurrent push notification registrations → all succeed

---

## Observability Tasks

- [ ] **[M]** Implement Firebase Crashlytics integration (`mobile/ios/Core/Core/Analytics/`, `mobile/android/core/src/main/java/org/openedx/core/analytics/`) | Depends: iOS and Android app implementations
  - Initialize Firebase Crashlytics SDK
  - Log custom events: `app_launch`, `login_success`, `login_failure`, `token_refresh_success`, `token_refresh_failure`, `push_received`, `push_tapped`, `deep_link_resolved`, `deep_link_failed`, `content_downloaded`, `content_download_failed`,`offline_sync_completed`, `offline_sync_failed`
  - Include custom keys: `org_slug`, `app_version`, `os_version`, `device_model`, `auth_provider`, `notification_type`, `url_pattern`, `course_id`, `size_mb`

- [ ] **[M]** Implement backend Prometheus metrics for mobileAPI (`infrastructure/tutor/patches/mobile_metrics.py`) | Depends: Backend endpoints
  - Metrics:
    - `mobile_api_requests_total` (labels: `endpoint`, `platform`, `org_slug`, `status_code`)
    - `mobile_api_latency_seconds` (histogram, labels: `endpoint`, `platform`)
    - `push_notifications_sent_total` (labels: `type`, `org_slug`, `platform`)
    - `push_notifications_failed_total` (labels: `type`, `org_slug`, `platform`, `error_code`)
    - `device_registrations_active` (gauge, labels: `platform`, `org_slug`)
  - Expose metrics at `/metrics/` endpoint (if not already exposed)
  - Integrate with existing Prometheus scraping

- [ ] **[M]** Create Grafana dashboards for mobile observability (`infrastructure/monitoring/grafana/dashboards/mobile-apps.json`) | Depends: Metrics implementation
  - Dashboard: Mobile App Overview (app launches by platform/version, crash rate trend, active device registrations)
  - Dashboard: Mobile Auth (login success/failure rates, token refresh latency distribution, active sessions by org)
  - Dashboard: Push Notifications (send rate, delivery rate,tap-through rate, failure breakdown by error code)
  - Dashboard: Mobile API (request volume, latency percentiles, error rate by endpoint)
  - Dashboard: Offline Mode (download volume, sync success rate, average sync latency)
  - Dashboard: Multi-Tenant (per-org active users, per-org crash rate, per-org API latency)

- [ ] **[M]** Create Prometheus alert rules for mobile services (`deploy/k8s/base/monitoring/prometheusrule-mobile.yaml`)| Depends: Metrics implementation
  - Critical: `push_notifications_failed_total` rate exceeds2% over 15 minutes (page oncall)
  - Critical: `mobile_token_refresh_failure_rate` exceeds 1%over 15 minutes (page oncall)
  - Warning: `mobile_crash_rate` increases by 3x compared toprevious 7-day average (notify channel)
  - Warning: `mobile_api_latency_seconds` p95 exceeds 1 second for any endpoint over 10 minutes (notify channel)
  - Warning: `device_registrations_active` drops by more than20% day-over-day (notify channel)

---

## Documentation Tasks

- [ ] **[S]** Write mobile apps architecture overview (`docs/architecture/mobile-apps-overview.md`) | Depends: All build tasks
  - System diagram: mobile apps ↔ LMS API ↔ Open edX backend
  - OAuth 2.0 flow with PKCE
  - Push notification flow: LMS → FCM → APNs/Android
  - Deep linking architecture: AASA/assetlinks → app navigation
  - Offline mode architecture: download → local storage → sync queue
  - Multi-tenant branding: config API → dynamic theming

- [ ] **[M]** Write mobile apps runbook (`docs/runbooks/mobile-apps-runbook.md`) | Depends: All build + observability tasks
  - Operational procedures: deploy iOS/Android, rollback, certificate rotation
  - Incident playbooks: push notifications not delivered, deep links not working, offline sync failures, crash rate spike
  - Troubleshooting: common symptoms → fixes
  - Certificate pinning rotation procedure
  - Apple distribution certificate renewal procedure (expires2027-01-22)
  - Android upload key compromise recovery procedure
  - Oncall handbook

- [ ] **[S]** Write Firebase setup guide (`docs/operations/FIREBASE_SETUP.md`) | Depends: None
  - How to create Firebase project
  - Register iOS app (bundle ID: `com.mereka.academy.mobile`)
  - Register Android app (package name: `com.mereka.academy.mobile`)
  - Configure Cloud Messaging (FCM)
  - Download `GoogleService-Info.plist` (iOS) and `google-services.json` (Android)
  - Enable Crashlytics

- [ ] **[S]** Write Apple Developer account setup guide (`docs/operations/APPLE_DEVELOPER_SETUP.md`) | Depends: None
  - Team ID: `44F7G2D7U6`
  - Create App ID: `com.mereka.academy.mobile`
  - Enable capabilities: Sign in with Apple, Push Notifications, Associated Domains
  - Create distribution certificate (valid until 2027-01-22)
  - Create provisioning profile for App Store distribution
  - Generate App Store Connect API key

- [ ] **[S]** Write Google Play Developer account setup guide(`docs/operations/GOOGLE_PLAY_SETUP.md`) | Depends: None
  - Create app in Google Play Console
  - Configure app signing (Google manages signing key)
  - Upload initial AAB
  - Set up Internal Testing track
  - Create Service Account for API access
  - Grant permissions in Play Console → API access

- [ ] **[S]** Update main troubleshooting doc with mobile section (`docs/runbooks/operations/TROUBLESHOOTING.md`) | Depends: All build tasks
  - Add mobile apps diagnostic commands
  - Check push notification delivery: query `mobile_device_tokens` table, check FCM logs
  - Check deep linking: verify AASA/assetlinks files, test Universal/App Links
  - Check offline sync: query sync queue, check backend API logs
  - Check branding config: test config endpoint, verify cache

---

## Rollout Tasks

- [ ] **[S]** Create feature flags configuration (`infrastructure/tutor/config.yml`) | Depends: None
  - `ENABLE_MOBILE_PUSH_NOTIFICATIONS` (default: off until Phase 2)
  - `ENABLE_MOBILE_OFFLINE_MODE` (default: off until Phase 4)
  - `ENABLE_MOBILE_DEEP_LINKING` (default: on)
  - `ENABLE_MOBILE_MULTI_TENANT_BRANDING` (default: off untilPhase 3)
  - `ENABLE_MOBILE_CERTIFICATE_PINNING` (default: on, emergency disable during cert rotation)
  - Feature flags stored in Django admin `Waffle` or similar

- [ ] **[M]** iOS Phase 1: Stabilize existing TestFlight pipeline (`scripts/mobile/deploy-ios-v1.sh`) | AC: #32, #35 | Depends: iOS implementation, CI/CD pipeline
  - Verify build-ios-app.yml workflow runs successfully
  - Deploy to TestFlight
  - Invite internal testers (5-10 users)
  - Test OAuth login, course browsing, video playback
  - Monitor crash rate for 48 hours

- [ ] **[M]** iOS Phase 2: Implement and test push notifications (`scripts/mobile/deploy-ios-v1.1.sh`) | AC: #9-13 | Depends: Phase 1, push notification implementation
  - Enable `ENABLE_MOBILE_PUSH_NOTIFICATIONS` feature flag
  - Deploy backend changes
  - Deploy iOS app update to TestFlight
  - Test: send course announcement → verify notification received within 60s
  - Test: tap notification → verify deep link navigation
  - Monitor notification delivery rate for 48 hours

- [ ] **[M]** iOS Phase 3: Implement and test deep linking (`scripts/mobile/deploy-ios-v1.2.sh`) | AC: #14-18 | Depends: Phase 2, deep linking implementation
  - Deploy AASA file
  - Deploy iOS app update to TestFlight
  - Test: open Universal Link → verify app opens and navigates
  - Test: unauthenticated Universal Link → verify login → navigation flow
  - Monitor deep link resolution success rate for 48 hours

- [ ] **[M]** iOS Phase 4: Submit to App Store review (`scripts/mobile/submit-ios-app-store.sh`) | AC: #35 | Depends: Phase 3, App Store listing assets
  - Upload screenshots, app description, privacy labels, agerating
  - Submit for review
  - Monitor review status (typically 24-48 hours)
  - Enable phased release over 7 days after approval

- [ ] **[M]** Android Phase 1: Bootstrap and deploy to Internal Testing (`scripts/mobile/deploy-android-v1.sh`) | AC: #33,#36 | Depends: Android implementation, Android CI/CD pipeline
  - Verify build-android-app.yml workflow runs successfully
  - Deploy to Google Play Internal Testing
  - Invite internal testers (5-10 users)
  - Test OAuth login, course browsing, video playback
  - Monitor crash rate for 48 hours

- [ ] **[M]** Android Phase 2: Implement and test push notifications (`scripts/mobile/deploy-android-v1.1.sh`) | AC: #9-13| Depends: Android Phase 1, push notification implementation
  - Deploy Android app update to Internal Testing
  - Test: send course announcement → verify notification received within 60s
  - Test: tap notification → verify deep link navigation
  - Monitor notification delivery rate for 48 hours

- [ ] **[M]** Android Phase 3: Implement and test deep linking (`scripts/mobile/deploy-android-v1.2.sh`) | AC: #14-18 | Depends: Android Phase 2, deep linking implementation
  - Deploy assetlinks.json file
  - Deploy Android app update to Internal Testing
  - Test: open App Link → verify app opens and navigates
  - Test: unauthenticated App Link → verify login → navigation flow
  - Monitor deep link resolution success rate for 48 hours

- [ ] **[M]** Android Phase 4: Submit to Google Play Production (staged rollout) (`scripts/mobile/submit-android-play-store.sh`) | AC: #36 | Depends: Android Phase 3, Play Store listing assets
  - Upload store listing, screenshots, content rating, data safety form
  - Submit to Production track with staged rollout (start at10%)
  - Monitor crash rate and user feedback
  - Increase rollout to 50% after 48 hours, then 100% after another 48 hours

- [ ] **[M]** iOS/Android Phase 5: Multi-tenant branding rollout (`scripts/mobile/deploy-mobile-branding.sh`) | AC: #24-27| Depends: iOS Phase 4, Android Phase 4, branding implementation
  - Enable `ENABLE_MOBILE_MULTI_TENANT_BRANDING` feature flag
  - Deploy backend branding configuration API
  - Onboard first 2 pilot clients with custom branding configs
  - Deploy iOS and Android app updates
  - Test: launch app with client-a org_slug → verify brandingapplied
  - Validate tenant isolation with security review
  - Monitor branding config endpoint latency

- [ ] **[L]** iOS/Android Phase 6: Offline mode rollout (`scripts/mobile/deploy-mobile-offline.sh`) | AC: #19-23 | Depends: Phase 5, offline implementation
  - Enable `ENABLE_MOBILE_OFFLINE_MODE` feature flag
  - Deploy iOS and Android app updates
  - Test: download course section → verify content availableoffline
  - Test: complete quiz offline → regain connectivity → verify sync within 60s
  - Load test: 1000 concurrent syncs → verify all succeed
  - Monitor download volume, sync success rate, storage usage

- [ ] **[M]** Production hardening (`scripts/qa/mobile-production-hardening-checklist.sh`) | Depends: All phases
  - Enable all alerts and dashboards
  - Certificate pinning rotation rehearsal
  - Apple distribution certificate renewal reminder (60 daysbefore 2027-01-22)
  - Security review: OWASP Mobile Top 10 audit
  - Load test: 1000 concurrent API requests → verify p95 latency targets met
  - Crash recovery testing: kill app during download, duringsync, during token refresh

---

## Summary

**Total Tasks**: 92

**By Complexity**:
- Small (S): 18 tasks
- Medium (M): 57 tasks
- Large (L): 17 tasks

**By Category**:
- Build: 53 tasks
- Test: 17 tasks
- Observability: 4 tasks
- Documentation: 6 tasks
- Rollout: 12 tasks

**Critical Path**:
1. Backend mobile API (branding, push, deep linking) → iOS implementation → iOS CI/CD → TestFlight → App Store
2. Backend mobile API → Android implementation → Android CI/CD → Internal Testing → Play Store
3. Multi-tenant branding → Offline mode

**Estimated Timeline**:
- Phase 1 (iOS Stabilization): 2-3 weeks
- Phase 2 (Android Bootstrap): 3-4 weeks (parallel with iOS Phases 2-3)
- Phase 3 (Multi-Tenant Branding): 2 weeks
- Phase 4 (Offline Mode): 3-4 weeks
- **Total**: 10-13 weeks

**Dependencies External to This Spec**:
- Firebase project `mereka-academy` exists and configured
- Apple Developer account (Team ID: `44F7G2D7U6`) active
- Google Play Developer account active
- MongoDB Atlas connection configured (no local MongoDB)
- OAuth2 client `mereka-mobile-app` registered in LMS

---

## Verification Checklist

Before marking any phase complete:
- [ ] All acceptance criteria for that phase are covered by tests
- [ ] Testmap YAML is updated with new test files
- [ ] Metrics are being collected and dashboards are displaying data
- [ ] Alerts have been tested (fire and resolve)
- [ ] Runbook has been validated by oncall team
- [ ] Rollback procedure has been rehearsed
- [ ] Load testing completed with no degradation
- [ ] Security review completed with no Critical findings (OWASP Mobile Top 10)
- [ ] All secrets are in Infisical/GCP SM, none hardcoded
- [ ] Certificate pinning rotation tested
- [ ] App Store/Play Store review guidelines compliance verified
