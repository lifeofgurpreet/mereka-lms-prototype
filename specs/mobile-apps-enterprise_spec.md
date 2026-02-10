---
title: "Mobile Apps (iOS + Android) Enterprise Deployment"
type: "feature_spec"
status: "draft"
owner: "engineering"
vehicle: "talent_platform"
last_updated: "2026-02-10"
links:
  related_docs:
    - "docs/ios-cicd-spec.md"
    - "docs/IOS_DEPLOYMENT_LEARNINGS.md"
    - "docs/IOS_APP_SETUP_NOW.md"
    - "docs/IOS_APP_CI_SETUP.md"
  related_specs:
    - "specs/secrets-management_spec.md"
    - "specs/branding-system_spec.md"
    - "specs/multi-site-domains_spec.md"
    - "specs/k8s-deployment_spec.md"
---

# Human Summary

## What we're building

A production-grade mobile application platform (iOS and Android) for Mereka Academy that supports enterprise "many clients" deployment. Each client organization receives a branded mobile experience backed by a shared Open edX backend. The iOS app is already deployed to TestFlight with working CI/CD; the Android app has not yet started. This spec covers the full contract for both platforms: the mobile API surface, authentication flows, push notifications, deep linking, offline capabilities, multi-tenant branding, security hardening, and app store release procedures.

The system extends the existing Open edX mobile app architecture (openedx-app-ios, openedx-app-android) with enterprise-grade multi-tenant configuration, centralized branding management, and automated deployment pipelines that can produce distinct client builds from a single codebase.

## Why it matters

Mobile is the primary access channel for learners across Mereka Academy's client organizations. Enterprise clients expect branded experiences that reflect their identity, not a generic LMS. Without a formal contract for the mobile API, authentication, multi-tenancy, and release procedures, each new client onboarding becomes ad-hoc engineering work. This spec establishes the contract that makes mobile deployment repeatable, secure, and scalable across dozens of client organizations.

## Success looks like

- Both iOS and Android apps are available in their respective stores with automated CI/CD pipelines
- A new client can be onboarded (branding, configuration, store listing) within 2 business days without code changes
- Push notifications reliably reach learners within 30 seconds of trigger
- Deep links resolve correctly to specific courses, sections, and assignments
- Critical course content is accessible offline within downloaded courses
- Token refresh operates silently with zero user-visible authentication interruptions
- No security incidents related to token leakage, man-in-the-middle attacks, or unauthorized cross-tenant data access

---

# Agent Contract

## Scope

- In scope:
  - Mobile REST API contract between apps and Open edX LMS backend
  - OAuth 2.0 authentication flow (authorization code with PKCE)
  - iOS deployment pipeline (existing, formalized)
  - Android deployment pipeline (new, greenfield)
  - Push notification delivery via Firebase Cloud Messaging (FCM) and Apple Push Notification service (APNs)
  - Deep linking scheme for course content navigation
  - Offline mode for downloaded course content
  - Multi-tenant branding configuration per client
  - Security controls: token lifecycle, certificate pinning, data encryption at rest
  - App store release procedures for both Apple App Store and Google Play Store
  - In-app purchase integration design space (future, not implemented in v1)

- Out of scope:
  - Web/MFE mobile-responsive design (separate concern)
  - LMS backend API implementation changes (this spec consumes existing APIs)
  - Tablet-specific UI/UX design
  - Wearable device support
  - Backend infrastructure scaling for mobile traffic (covered by k8s-deployment spec)
  - MDM (Mobile Device Management) integration
  - Accessibility compliance testing methodology (separate spec)

## Non-goals

- Building a custom mobile app framework from scratch (we extend Open edX upstream apps)
- Supporting Open edX instances other than Mereka Academy's backend
- Real-time video streaming within the app (video is served via external providers)
- Implementing a mobile analytics SDK beyond Open edX's existing telemetry
- White-labeling the app store listing itself per client (clients share the Mereka Academy listing with per-client branding inside the app)
- Replacing the web experience; mobile is complementary, not a full-feature replacement

## Assumptions

- Open edX LMS backend (Tutor 18.2.2, Redwood release) exposes the standard Mobile REST API at `/api/mobile/v1/`, `/api/courses/v1/`, `/api/enrollment/v1/`, and related endpoints
- The existing iOS CI/CD pipeline (`.github/workflows/build-ios-app.yml`) is the baseline for iOS; Android will follow a parallel pattern
- Firebase project `mereka-academy` exists and is configured for both iOS (`com.mereka.academy.mobile`) and Android (`com.mereka.academy.mobile`) bundle/application IDs
- Apple Developer account (Team ID: `44F7G2D7U6`) and Google Play Developer account are both active
- Client organizations are identified by a unique `org_slug` that maps to their tenant configuration
- The Open edX OAuth2 provider is configured with a `mereka-mobile-app` client ID (already present in iOS config)
- Infisical is the secrets source of truth (per `specs/secrets-management_spec.md`)

---

## Requirements

### Functional

#### Mobile API Contract

- The mobile apps MUST authenticate all API requests using OAuth 2.0 bearer tokens in the `Authorization: Bearer <token>` header
- The mobile apps MUST use the Open edX Mobile REST API endpoints:
  - `POST /oauth2/access_token/` for token exchange
  - `GET /api/mobile/v4/my_courses/` for enrolled courses list
  - `GET /api/courses/v1/courses/{course_id}/` for course detail
  - `GET /api/courses/v1/blocks/?course_id={course_id}` for course structure
  - `GET /api/enrollment/v1/enrollment` for enrollment status
  - `POST /api/enrollment/v1/enrollment` for new enrollment
  - `GET /api/user/v1/accounts/{username}` for user profile
  - `PATCH /api/user/v1/accounts/{username}` for profile updates
  - `GET /api/mobile/v1/users/{username}/course_enrollments` for enrollment list
  - `POST /api/mobile/v1/users/{username}/course_status_info` for progress tracking
  - `GET /api/course_home/v1/dates/{course_id}` for course dates
  - `GET /api/discussion/v1/threads/?course_id={course_id}` for forum threads
- The mobile apps MUST handle API versioning by including `Accept: application/json` and respecting version headers
- The mobile apps MUST send a `User-Agent` header in the format `MerekaAcademy/<version> (<platform>; <os_version>; <device_model>)` on every request
- The mobile apps SHOULD support API response caching using `ETag` and `If-None-Match` headers where the backend provides them
- The mobile apps MUST set the `X-Tenant-ID` header to the active client's `org_slug` on every API request to enable backend tenant routing

#### OAuth 2.0 Authentication Flow

- The mobile apps MUST implement OAuth 2.0 Authorization Code flow with PKCE (Proof Key for Code Exchange)
- The mobile apps MUST use the following OAuth endpoints:
  - Authorization: `https://{lms_host}/oauth2/authorize/`
  - Token exchange: `https://{lms_host}/oauth2/access_token/`
  - Token revocation: `https://{lms_host}/oauth2/revoke_token/`
- The mobile apps MUST store the OAuth client ID (`mereka-mobile-app`) in build configuration, not hardcoded in source
- The mobile apps MUST NOT store client secrets in the app binary (public client pattern)
- The mobile apps MUST generate a cryptographically random `code_verifier` (43-128 characters, unreserved URI characters) per authorization request
- The mobile apps MUST derive `code_challenge` from `code_verifier` using S256 (SHA-256) method
- The mobile apps MUST use the system browser or ASWebAuthenticationSession (iOS) / Custom Tabs (Android) for the authorization flow, not an embedded WebView
- The mobile apps MUST store access tokens and refresh tokens in platform-secure storage:
  - iOS: Keychain Services with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
  - Android: EncryptedSharedPreferences backed by Android Keystore
- The mobile apps MUST NOT log, persist to disk (outside secure storage), or transmit tokens to third parties
- The mobile apps MUST support Apple Sign-In as an authentication provider (already enabled on iOS App ID)
- The mobile apps SHOULD support Google Sign-In as an authentication provider when the backend enables it

#### Token Lifecycle Management

- The mobile apps MUST refresh the access token proactively when the token has less than 5 minutes of validity remaining
- The mobile apps MUST implement a single-flight token refresh mechanism (only one refresh request in-flight at a time; concurrent API calls wait for the same refresh)
- The mobile apps MUST retry a failed API call exactly once after a successful token refresh if the original failure was HTTP 401
- The mobile apps MUST revoke the refresh token on explicit user logout via `POST /oauth2/revoke_token/`
- The mobile apps MUST clear all tokens and cached user data from secure storage on logout
- The mobile apps MUST redirect to the login screen if token refresh fails (refresh token expired or revoked)
- The refresh token lifetime SHOULD be >= 30 days (backend configuration)
- The access token lifetime SHOULD be 1 hour (backend configuration)

#### Push Notifications

- The system MUST deliver push notifications via Firebase Cloud Messaging (FCM) for both iOS and Android
- The iOS app MUST register for APNs and forward the device token to FCM
- The Android app MUST register for FCM directly
- The mobile apps MUST register the device token with the backend via `POST /api/mobile/v1/notifications/register/` including `device_token`, `platform` (ios/android), `app_version`, and `org_slug`
- The mobile apps MUST unregister the device token on logout via `DELETE /api/mobile/v1/notifications/register/`
- The backend MUST support the following notification types:
  - `course_announcement` -- new announcement in an enrolled course
  - `assignment_due` -- assignment deadline reminder (24h and 1h before)
  - `grade_posted` -- grade available for a submission
  - `discussion_reply` -- reply to a followed discussion thread
  - `system_maintenance` -- scheduled maintenance window
- Each notification payload MUST include: `type`, `title`, `body`, `course_id` (if applicable), `deep_link_url`, `org_slug`, `timestamp`
- The mobile apps MUST display notifications in the system notification center with appropriate grouping by course
- The mobile apps MUST navigate to the relevant content when a notification is tapped (via deep link)
- The mobile apps MUST request notification permissions at an appropriate time (after first successful login, not at app launch)
- The backend SHOULD send notifications within 30 seconds of the triggering event
- The mobile apps SHOULD support notification preferences (per-type opt-in/opt-out) synced with the backend

#### Deep Linking

- The mobile apps MUST register for Universal Links (iOS) and App Links (Android) on the following domains:
  - `academyv2.mereka.io`
  - `academy.biji-biji.com`
  - `*.client-slug.mereka.io` (per-client domains, when applicable)
- The mobile apps MUST handle the following deep link patterns:
  - `https://{host}/courses/{course_id}/` -- open course detail
  - `https://{host}/courses/{course_id}/courseware/{section_id}/` -- open specific section
  - `https://{host}/courses/{course_id}/courseware/{section_id}/{unit_id}/` -- open specific unit
  - `https://{host}/dashboard` -- open learner dashboard
  - `https://{host}/u/{username}` -- open user profile
  - `https://{host}/courses/{course_id}/discussion/forum/` -- open course discussion
- The mobile apps MUST implement a custom URL scheme `mereka-academy://` as a fallback for app-to-app linking
- The backend MUST serve `apple-app-site-association` (AASA) file at `/.well-known/apple-app-site-association` with correct `appID` entries
- The backend MUST serve `assetlinks.json` at `/.well-known/assetlinks.json` with correct Android package and SHA-256 fingerprint
- The mobile apps MUST handle unauthenticated deep links by storing the target URL, completing login, then navigating to the stored URL
- The mobile apps MUST fall back to opening the URL in an in-app browser if the deep link target is not supported natively

#### Offline Mode

- The mobile apps MUST allow learners to download individual course sections for offline access
- The mobile apps MUST store downloaded content in the app's sandboxed storage (not externally accessible)
- The mobile apps MUST track download progress and allow pause/resume of downloads
- The mobile apps MUST show a clear visual indicator for content that is available offline vs. requires network
- The mobile apps MUST sync completion/progress data when connectivity is restored (queue locally, flush on reconnect)
- The mobile apps MUST handle storage pressure by allowing users to manage (view size, delete) downloaded content
- Downloaded content MUST include: video files (at user-selected quality), HTML content blocks, PDF attachments, and problem/assessment structure
- Downloaded content MUST NOT include: discussion forums, wiki content, or real-time collaborative features
- The mobile apps SHOULD support background downloads (iOS: `URLSession` background configuration; Android: `WorkManager`)
- The mobile apps SHOULD warn the user when device storage is below 500 MB before starting a download
- The mobile apps MUST encrypt downloaded content at rest using platform encryption:
  - iOS: Data Protection with `NSFileProtectionCompleteUntilFirstUserAuthentication`
  - Android: file-based encryption (default on Android 10+)

#### Multi-Tenant Branding

- The system MUST support per-client branding without separate app binaries
- Each client MUST be identified by a unique `org_slug` (e.g., `mereka`, `client-a`, `client-b`)
- The mobile apps MUST fetch client branding configuration from `GET /api/mobile/v1/config/{org_slug}/` on launch and cache it locally
- The branding configuration response MUST include:
  - `org_slug`: string
  - `display_name`: string (e.g., "Acme Corp Academy")
  - `primary_color`: hex color string
  - `accent_color`: hex color string
  - `logo_url`: URL to logo image (PNG, minimum 512x512)
  - `logo_dark_url`: URL to dark-mode logo variant
  - `favicon_url`: URL to favicon
  - `splash_background_color`: hex color string
  - `login_background_image_url`: URL (optional)
  - `support_email`: string
  - `support_url`: URL (optional)
  - `terms_url`: URL
  - `privacy_url`: URL
  - `feature_flags`: object with boolean toggles
- The mobile apps MUST apply branding dynamically at runtime (navigation bar color, accent color, logo, splash screen)
- The mobile apps MUST cache the most recent branding configuration so the app renders correctly when offline
- The mobile apps MUST fall back to default Mereka Academy branding if the config endpoint is unreachable and no cache exists
- The mobile apps SHOULD refresh branding configuration at most once per app launch (not on every screen)
- The system MUST NOT allow cross-tenant data leakage: a user authenticated under `org_slug=client-a` MUST NOT see courses or data belonging to `org_slug=client-b` unless explicitly cross-enrolled
- The branding configuration endpoint MUST respond within 500ms at p95

#### In-App Purchases (Future -- Design Space Reserved)

- The system SHOULD reserve the API endpoint namespace `/api/mobile/v1/purchases/` for future in-app purchase integration
- The system SHOULD NOT implement in-app purchase flows in v1
- When implemented, the system MUST use Apple StoreKit 2 (iOS) and Google Play Billing Library v6+ (Android)
- When implemented, the system MUST validate purchase receipts server-side via App Store Server API and Google Play Developer API, never client-side only
- When implemented, the system MUST support subscription and one-time purchase product types
- When implemented, the system MUST handle purchase restoration across device reinstalls

### Non-functional (NFRs)

#### Performance

- Mobile API p95 latency MUST be <= 500ms for list endpoints (courses, enrollments) measured at the backend
- Mobile API p95 latency MUST be <= 200ms for single-resource endpoints (course detail, user profile) measured at the backend
- App cold-start to interactive MUST be <= 3 seconds on devices released within the last 3 years
- Branding configuration endpoint p95 latency MUST be <= 500ms
- Offline content download speed MUST saturate available bandwidth (no artificial throttling)

#### Reliability

- Push notification delivery success rate MUST be >= 98% (measured as delivered to FCM/APNs, not to device)
- Token refresh MUST succeed on first attempt >= 99.5% of the time when the refresh token is valid
- Offline progress sync MUST be eventually consistent within 60 seconds of connectivity restoration

#### Security

- The mobile apps MUST implement TLS certificate pinning for all connections to `*.mereka.io` and `*.biji-biji.com` domains
- Certificate pins MUST include at least 2 pins (primary + backup) to prevent lockout during certificate rotation
- The mobile apps MUST pin against the intermediate CA certificate (not the leaf) to allow certificate renewal without app updates
- The mobile apps MUST implement a pin expiry mechanism: if all pins expire without update, fall back to standard TLS validation with a telemetry alert
- The mobile apps MUST NOT transmit any PII (email, name, progress data) over unencrypted connections
- The mobile apps MUST implement jailbreak/root detection and display a warning (not block usage) if detected
- The mobile apps MUST clear the app snapshot (task switcher screenshot) when the app enters background to prevent token/content leakage
- The mobile apps MUST enforce a minimum OS version:
  - iOS: 16.0
  - Android: API level 28 (Android 9.0)
- The mobile apps MUST NOT include debug logging, test credentials, or development endpoints in release builds
- Binary artifacts MUST be signed with the organization's distribution certificate (iOS) or upload key (Android)

#### Observability

- The mobile apps MUST report crash data to a centralized crash reporting service (Firebase Crashlytics)
- The mobile apps MUST track the following custom events:
  - `app_launch` (with `org_slug`, `app_version`, `os_version`)
  - `login_success`, `login_failure` (with `auth_provider`, `org_slug`)
  - `token_refresh_success`, `token_refresh_failure`
  - `push_received`, `push_tapped` (with `notification_type`)
  - `deep_link_resolved`, `deep_link_failed` (with `url_pattern`)
  - `content_downloaded`, `content_download_failed` (with `course_id`, `size_mb`)
  - `offline_sync_completed`, `offline_sync_failed`
- The backend MUST expose mobile-specific Prometheus metrics:
  - `mobile_api_requests_total` (labels: `endpoint`, `platform`, `org_slug`, `status_code`)
  - `mobile_api_latency_seconds` (histogram, labels: `endpoint`, `platform`)
  - `push_notifications_sent_total` (labels: `type`, `org_slug`, `platform`)
  - `push_notifications_failed_total` (labels: `type`, `org_slug`, `platform`, `error_code`)
  - `device_registrations_active` (gauge, labels: `platform`, `org_slug`)

---

## Acceptance Criteria

### Authentication

- [ ] AC-001: Given a new user on iOS, when they tap "Sign In", then the system browser opens to the LMS OAuth authorize endpoint with PKCE parameters (`code_challenge`, `code_challenge_method=S256`, `response_type=code`, `client_id=mereka-mobile-app`)
- [ ] AC-002: Given a new user on Android, when they tap "Sign In", then a Custom Tab opens to the LMS OAuth authorize endpoint with identical PKCE parameters
- [ ] AC-003: Given a successful authorization code callback, when the app exchanges the code for tokens, then the access token and refresh token are stored in platform-secure storage (Keychain on iOS, EncryptedSharedPreferences on Android)
- [ ] AC-004: Given a stored access token with < 5 minutes remaining validity, when the app makes an API call, then the token is refreshed proactively before the call proceeds
- [ ] AC-005: Given a concurrent burst of 10 API calls during token refresh, when the refresh is in-flight, then exactly one token refresh request is sent to the backend (single-flight)
- [ ] AC-006: Given a 401 response from the API, when the refresh token is still valid, then the app refreshes the token and retries the original request exactly once
- [ ] AC-007: Given a failed token refresh (invalid/expired refresh token), when the app detects the failure, then the user is redirected to the login screen and all tokens are cleared
- [ ] AC-008: Given an authenticated user who taps "Logout", when logout completes, then the refresh token is revoked server-side and all local tokens, cached user data, and branding overrides are cleared

### Push Notifications

- [ ] AC-009: Given a freshly installed app after first login, when the user reaches the dashboard, then the app requests push notification permission (not at app launch, not before login)
- [ ] AC-010: Given notification permission granted, when the device token is obtained, then the app registers it with the backend including `device_token`, `platform`, `app_version`, and `org_slug`
- [ ] AC-011: Given a course announcement is published, when the backend sends a push notification, then the notification appears in the system notification center within 60 seconds
- [ ] AC-012: Given a notification with `type=assignment_due` and a valid `deep_link_url`, when the user taps it, then the app navigates directly to the assignment within the course
- [ ] AC-013: Given a user logs out, when logout completes, then the device token is unregistered from the backend

### Deep Linking

- [ ] AC-014: Given the AASA file is served at `https://academyv2.mereka.io/.well-known/apple-app-site-association`, when iOS validates it, then Universal Links are recognized for `academyv2.mereka.io`
- [ ] AC-015: Given the `assetlinks.json` is served at `https://academyv2.mereka.io/.well-known/assetlinks.json`, when Android validates it, then App Links are recognized
- [ ] AC-016: Given a URL `https://academyv2.mereka.io/courses/course-v1:Mereka+101+2026/courseware/section1/`, when the app receives it as a deep link, then it navigates to section1 of the course
- [ ] AC-017: Given an unauthenticated user opens a deep link, when the link is received, then the app stores the URL, presents login, and navigates to the stored URL after successful authentication
- [ ] AC-018: Given a deep link to an unsupported path (e.g., `/admin/`), when the app receives it, then it opens the URL in an in-app browser

### Offline Mode

- [ ] AC-019: Given a user taps "Download" on a course section, when the download completes, then all video, HTML, and PDF content for that section is available without network connectivity
- [ ] AC-020: Given a user completes a quiz while offline, when the device regains connectivity, then the completion and score data sync to the backend within 60 seconds
- [ ] AC-021: Given the device has less than 500 MB free storage, when the user attempts to start a download, then the app displays a storage warning before proceeding
- [ ] AC-022: Given downloaded content exists, when the user views "Manage Downloads", then they see per-section storage usage and can delete individual sections
- [ ] AC-023: Given a download is in progress and the user backgrounds the app, when the download completes in the background, then a local notification confirms completion (iOS: background URLSession; Android: WorkManager)

### Multi-Tenant Branding

- [ ] AC-024: Given `org_slug=client-a` with branding config specifying `primary_color=#FF5733`, when the app renders, then the navigation bar and primary UI elements use `#FF5733`
- [ ] AC-025: Given the branding config endpoint is unreachable and a cached config exists, when the app launches, then it renders using the cached branding
- [ ] AC-026: Given the branding config endpoint is unreachable and no cache exists, when the app launches, then it renders using default Mereka Academy branding
- [ ] AC-027: Given a user authenticated under `org_slug=client-a`, when they request course listings, then they see only courses associated with `client-a` (no cross-tenant leakage)

### Security

- [ ] AC-028: Given the app is running on a device, when it connects to `academyv2.mereka.io`, then the TLS certificate is validated against pinned intermediate CA certificates
- [ ] AC-029: Given a certificate pin mismatch (MITM scenario), when the connection fails, then the app displays a security warning and does not send any data
- [ ] AC-030: Given the app enters the background, when the OS captures a task-switcher screenshot, then the screenshot shows a branded splash screen (not sensitive content)
- [ ] AC-031: Given a release build artifact, when inspected, then it contains no debug logging statements, test API endpoints, or hardcoded credentials

### CI/CD Pipelines

- [ ] AC-032: Given a push to `mobile/ios/**` on the `main` branch, when the iOS CI workflow triggers, then it produces a signed IPA and uploads it to TestFlight without manual intervention
- [ ] AC-033: Given a push to `mobile/android/**` on the `main` branch, when the Android CI workflow triggers, then it produces a signed AAB and uploads it to Google Play Internal Testing without manual intervention
- [ ] AC-034: Given a new client `org_slug=new-client` is added to the branding configuration, when the CI pipeline runs, then no code changes or pipeline modifications are required (configuration-only onboarding)

### App Store Release

- [ ] AC-035: Given a release candidate build, when submitted to the Apple App Store, then the submission includes: app description, screenshots (6.7" and 6.1" iPhones), privacy nutrition labels, and age rating
- [ ] AC-036: Given a release candidate build, when submitted to Google Play Store, then the submission includes: store listing, screenshots (phone), content rating questionnaire, and data safety form
- [ ] AC-037: Given a production release is approved, when the app is published, then it uses a phased/staged rollout (iOS: phased release over 7 days; Android: staged rollout starting at 10%)

---

## Edge Cases

### Authentication Edge Cases

- **Refresh token race condition**: If two app instances (e.g., iPad + iPhone) share the same account and refresh simultaneously, the backend MUST support concurrent refresh token usage or the apps MUST handle "refresh token already used" by falling back to re-login
- **Clock skew**: Token expiry checks MUST use server time from response headers (the `Date` header), not device clock, to avoid premature or late refresh on devices with incorrect time
- **OAuth state tampering**: The apps MUST validate the `state` parameter in the OAuth callback matches the one sent in the authorization request to prevent CSRF attacks
- **Biometric auth after background**: If the OS purges the app from memory and the user returns, the app SHOULD offer biometric unlock to restore the session from Keychain/Keystore rather than requiring full re-login

### Push Notification Edge Cases

- **Duplicate device tokens**: If a device token changes (OS reinstall, token rotation), the app MUST re-register the new token and the backend MUST deduplicate, removing stale tokens
- **Notification permission denied**: If the user denies notification permission, the app MUST gracefully degrade (no repeated prompts; show in-app notification center instead)
- **Background notification throttling**: iOS aggressively throttles silent/background notifications; the system MUST NOT rely on silent push for critical data sync
- **Multi-tenant notification routing**: The backend MUST route notifications only to devices registered under the matching `org_slug` to prevent cross-tenant notification leakage

### Deep Linking Edge Cases

- **App not installed**: If the app is not installed and a user taps a Universal Link, the link MUST fall through to the web browser gracefully (Open edX web LMS)
- **Expired course links**: If a deep link points to a course the user is not enrolled in, the app MUST show the course detail page with an enrollment option, not an error
- **Domain migration**: If a client domain changes, the AASA/assetlinks files MUST be updated on the new domain within the same release cycle as the DNS change
- **Concurrent deep link and login**: If a deep link arrives while a login flow is in progress, the app MUST queue the deep link and process it after login completes

### Offline Mode Edge Cases

- **Partial download corruption**: If a download is interrupted (network loss, app kill), the app MUST resume from the last completed chunk, not restart from scratch
- **Content version mismatch**: If course content is updated on the server while the user has an offline copy, the app MUST indicate "Update available" and allow re-download, not silently serve stale content
- **Storage exhaustion during download**: If device storage fills during a download, the app MUST pause the download, notify the user, and preserve already-downloaded content
- **Offline progress conflict**: If the user completes a quiz offline and the instructor changes the quiz before the sync, the backend MUST accept the offline submission against the version the user saw (optimistic concurrency with version ID)
- **DRM-protected video content**: If a video provider requires DRM, the offline download MUST use platform DRM (FairPlay on iOS, Widevine on Android); if DRM is not available for a video, that video MUST NOT be available for download

### Multi-Tenant Branding Edge Cases

- **Tenant switch mid-session**: If a user is associated with multiple organizations, the app MUST NOT mix branding. On org switch, the app MUST reload the full branding config and re-render
- **Invalid branding config**: If the branding endpoint returns malformed JSON or missing required fields, the app MUST fall back to cached config or default branding and report the error via telemetry
- **Logo loading failure**: If a logo URL returns 404 or times out, the app MUST display a text-based fallback using `display_name` and the `primary_color` background

### CI/CD Edge Cases

- **Build number collision**: Build numbers MUST use `GITHUB_RUN_NUMBER` (iOS) and equivalent auto-incrementing scheme (Android) to prevent store rejection
- **Certificate expiry**: iOS distribution certificate expires 2027-01-22. The system MUST alert 60 days before expiry and the rotation runbook MUST be tested
- **Signing key compromise**: If the Android upload key is compromised, the team MUST use Google Play's key upgrade mechanism. The spec reserves this as a documented emergency procedure
- **Flaky tests blocking release**: CI MUST distinguish between test failures and infrastructure failures. Infrastructure failures (runner timeout, network) MUST trigger retry, not block release

### Rate Limiting

- The mobile apps MUST respect HTTP 429 (Too Many Requests) responses by reading the `Retry-After` header and backing off
- The mobile apps MUST implement exponential backoff with jitter (base: 1s, max: 60s, jitter: +/- 500ms) for retries on 5xx errors
- The mobile apps MUST cap total retries at 3 per request

---

## Observability

### Logs

- **Mobile apps**: All logs MUST be structured JSON sent to Firebase Crashlytics custom logs, categorized by severity (debug, info, warning, error)
- **Backend mobile API**: Access logs MUST include `platform`, `app_version`, `org_slug`, `user_id`, `endpoint`, `status_code`, `latency_ms`
- **Push notification service**: Delivery logs MUST include `notification_id`, `type`, `org_slug`, `platform`, `device_token_hash` (not full token), `delivery_status`, `fcm_message_id`
- **Authentication**: Token events MUST log `event_type` (issue, refresh, revoke, expire), `user_id`, `org_slug`, `client_ip_hash`, `timestamp` -- MUST NOT log token values

### Metrics

- `mobile_app_launches_total` (labels: `platform`, `org_slug`, `app_version`) -- counter
- `mobile_auth_events_total` (labels: `event_type`, `platform`, `org_slug`, `auth_provider`) -- counter
- `mobile_token_refresh_duration_seconds` (labels: `platform`, `outcome`) -- histogram
- `mobile_api_requests_total` (labels: `endpoint`, `platform`, `org_slug`, `status_code`) -- counter
- `mobile_api_latency_seconds` (labels: `endpoint`, `platform`) -- histogram
- `push_notifications_sent_total` (labels: `type`, `org_slug`, `platform`) -- counter
- `push_notifications_delivery_latency_seconds` (labels: `type`, `platform`) -- histogram
- `mobile_offline_downloads_total` (labels: `platform`, `org_slug`, `outcome`) -- counter
- `mobile_offline_sync_duration_seconds` (labels: `platform`, `outcome`) -- histogram
- `mobile_deep_links_total` (labels: `platform`, `pattern`, `outcome`) -- counter
- `mobile_device_registrations_active` (labels: `platform`, `org_slug`) -- gauge
- `mobile_crash_rate` (labels: `platform`, `app_version`, `org_slug`) -- counter

### Alerts

- **Critical**: `push_notifications_failed_total` rate exceeds 5% over 15 minutes -- page oncall
- **Critical**: `mobile_token_refresh_duration_seconds` p99 exceeds 10 seconds -- page oncall
- **Warning**: `mobile_crash_rate` increases by 3x compared to previous 7-day average -- notify channel
- **Warning**: `mobile_api_latency_seconds` p95 exceeds 1 second for any endpoint over 10 minutes -- notify channel
- **Warning**: iOS distribution certificate expires within 60 days -- notify channel weekly
- **Info**: `mobile_device_registrations_active` drops by more than 20% day-over-day -- notify channel

### Dashboards

- **Mobile Overview**: app launches by platform/version, active device registrations, crash rate trend
- **Mobile Auth**: login success/failure rates, token refresh latency distribution, active sessions by org
- **Push Notifications**: send rate, delivery rate, tap-through rate, failure breakdown by error code
- **Mobile API**: request volume, latency percentiles, error rate by endpoint
- **Offline Mode**: download volume, sync success rate, average sync latency
- **Multi-Tenant**: per-org active users, per-org crash rate, per-org API latency

---

## Rollout & Rollback

### Rollout Plan

#### Phase 1: iOS Stabilization (current state -> v1.0)
1. Formalize existing TestFlight pipeline (already complete)
2. Implement token lifecycle management (PKCE, refresh, revocation)
3. Implement push notification registration and delivery
4. Implement deep linking with AASA file
5. Submit to App Store review (phased release over 7 days)

#### Phase 2: Android Bootstrap (v1.0)
1. Fork `openedx-app-android` and apply Mereka branding
2. Set up GitHub Actions workflow for Android (`build-android-app.yml`)
3. Configure signing (upload key in GitHub Secrets, app signing by Google Play)
4. Implement feature parity with iOS v1.0
5. Deploy to Google Play Internal Testing, then Production (staged rollout starting at 10%)

#### Phase 3: Multi-Tenant Branding (v1.1)
1. Build branding configuration API endpoint on the backend
2. Implement dynamic branding in both apps
3. Onboard first 2 pilot clients with custom branding
4. Validate tenant isolation with security review

#### Phase 4: Offline Mode (v1.2)
1. Implement course section download and local storage
2. Implement progress queue and sync mechanism
3. Implement download management UI
4. Load test offline sync with 1000 concurrent syncs

#### Phase 5: In-App Purchases (future, not scheduled)
1. Requires separate spec and business model definition

### Feature Flags

- `mobile_push_notifications_enabled` -- gate push registration and delivery (per org_slug)
- `mobile_offline_mode_enabled` -- gate download UI and sync (per org_slug)
- `mobile_deep_linking_enabled` -- gate Universal/App Links registration (global)
- `mobile_multi_tenant_branding_enabled` -- gate dynamic branding fetch (global)
- `mobile_certificate_pinning_enabled` -- gate certificate pinning (global, for emergency disable during cert rotation)
- `mobile_iap_enabled` -- gate in-app purchase flows (global, default off)

### Backward Compatibility

- API endpoints MUST be versioned (v1, v2, etc.) and the backend MUST support at least 2 major versions simultaneously
- The branding configuration API MUST be additive-only (new fields MAY be added; existing fields MUST NOT be removed or renamed without a deprecation period of at least 2 app release cycles)
- Push notification payload schema MUST be backward compatible; new fields MAY be added but existing fields MUST NOT be removed
- Deep link patterns MUST be stable; new patterns MAY be added but existing patterns MUST NOT change semantics

### Rollback Steps

#### iOS App Rollback
1. In App Store Connect, stop the phased release
2. If the issue is server-side, toggle the relevant feature flag off (immediate effect, no app update needed)
3. If the issue requires a client-side fix, submit an expedited review with the fix
4. If the issue is critical and affects all users, use App Store Connect to remove the version from sale (last resort)

#### Android App Rollback
1. In Google Play Console, halt the staged rollout
2. If server-side, toggle feature flag off
3. If client-side, upload a fix and resume rollout at 100% targeting only affected users
4. Google Play supports rollback to previous version via "Deactivate release"

#### Backend API Rollback
1. Revert the backend deployment via `kubectl rollout undo deployment/lms -n mereka-lms`
2. Verify endpoints return expected responses
3. Mobile apps MUST handle gracefully if an endpoint returns 404 (feature not yet available in this backend version)

#### Push Notification Rollback
1. Disable `mobile_push_notifications_enabled` feature flag (stops new notifications)
2. If FCM is misconfigured, update Firebase project settings (does not require app update)
3. Stale device tokens will expire naturally; no manual cleanup needed

---

## Open Questions

1. **Android app identity**: Should the Android app use the same application ID (`com.mereka.academy.mobile`) as iOS, or a different one? Using the same simplifies FCM configuration but may cause confusion in analytics.

2. **Multi-tenant app listing strategy**: Should enterprise clients eventually get their own App Store / Play Store listings (separate binary, separate listing) or always share the single "Mereka Academy" listing with dynamic branding? Separate listings require Apple/Google enterprise program enrollment per client.

3. **Offline video quality tiers**: What quality tiers should be offered for video downloads (e.g., 360p, 720p, 1080p)? This affects storage requirements and download times. Need input from content team on typical video file sizes.

4. **Push notification backend**: Should we build the push notification dispatch service in-house on the Open edX backend, or use a third-party service (e.g., OneSignal, Firebase directly)? In-house gives more control over tenant routing but requires more engineering.

5. **Certificate pinning update mechanism**: How will certificate pins be updated without shipping an app update? Options include: (a) fetch pins from a pinning configuration endpoint (chicken-and-egg problem), (b) include multiple future pins at build time, (c) use a short pin expiry with graceful fallback. Need security team input.

6. **App Store review SLA for enterprise clients**: When a new client needs urgent onboarding, can we guarantee the app update (if needed) passes App Store review within a specific timeframe? Apple review typically takes 24-48 hours but can be longer. Is expedited review acceptable as the standard process?

7. **Backend tenant isolation mechanism**: Does the Open edX backend currently support the `X-Tenant-ID` header for routing, or does tenant isolation need to be built? If built, should it be middleware-level (filter querysets) or database-level (separate schemas/databases per tenant)? This is a backend architecture decision that directly impacts the mobile API contract.
