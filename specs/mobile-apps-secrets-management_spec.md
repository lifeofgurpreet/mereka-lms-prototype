---
title: "Mobile Apps API Keys & Secrets Management"
type: "feature_spec"
status: "draft"
owner: "engineering"
vehicle: "talent_platform"
last_updated: "2026-02-13"
depends_on:
  - "specs/secrets-management_spec.md"
  - "specs/mobile-apps-enterprise_spec.md"
  - "specs/ci-cd-pipeline_spec.md"
links:
  related_docs:
    - "docs/APPLE_SETUP_STATUS.md"
    - "docs/GITHUB_SECRETS_READY.md"
    - "docs/ios-cicd-spec.md"
    - "docs/IOS_APP_CI_SETUP.md"
    - "docs/IOS_DEPLOYMENT_LEARNINGS.md"
    - "docs/operations/runbooks/MOBILE_APPS_RUNBOOK.md"
  related_specs:
    - "specs/secrets-management_spec.md"
    - "specs/mobile-apps-enterprise_spec.md"
    - "specs/ci-cd-pipeline_spec.md"
    - "specs/k8s-deployment_spec.md"
    - "specs/cross-cutting-requirements_spec.md"
---

# Human Summary

## What we're building

A comprehensive secrets management contract for the Mereka Academy mobile apps (iOS and Android). This spec defines the complete inventory of API keys and credentials required to build, sign, distribute, and operate the mobile apps -- covering Apple Developer credentials, Google Play credentials, Firebase Cloud Messaging keys, App Store Connect API keys, code signing certificates, and the build-time injection mechanisms that deliver these secrets to CI/CD pipelines and runtime environments. It extends the platform-wide secrets management spec (`specs/secrets-management_spec.md`) with mobile-specific conventions, naming rules, storage locations, and verification tooling.

The mobile apps require three distinct categories of secrets: (1) **build-time secrets** consumed by GitHub Actions CI/CD (Apple signing certificates, App Store Connect API keys, Fastlane match passwords), (2) **runtime secrets** consumed by the LMS backend to support mobile features (Firebase service account for push notifications, APNs authentication key), and (3) **app configuration secrets** embedded in builds (Firebase config values, OAuth client IDs). Each category has different storage, rotation, and verification requirements.

## Why it matters

Mobile secrets are uniquely fragile. An expired Apple Distribution certificate blocks all iOS TestFlight and App Store submissions until manually rotated. A leaked Android upload key requires a multi-week Google Play key upgrade process. A misconfigured Firebase project ID causes push notifications to silently fail for all users. Unlike backend secrets that follow the established Infisical-to-K8s pipeline, mobile secrets span three separate trust boundaries (GitHub Actions, Apple/Google developer portals, Firebase console), each with different access patterns and rotation cadences. Without a machine-verifiable inventory and validation script, missing or expired secrets surface only when a build fails or a production feature stops working.

## Success looks like

- All mobile secrets are inventoried in a single source of truth with clear ownership, rotation schedules, and expiry dates.
- A validation script (`scripts/mobile/validate-mobile-secrets.sh`) confirms that all required secrets exist in their respective stores (Infisical, GitHub Actions, Firebase console) with non-empty, non-placeholder values.
- iOS CI/CD builds succeed end-to-end without manual signing intervention.
- Android CI/CD builds (when implemented) succeed end-to-end with proper signing.
- Push notifications work on both platforms because Firebase and APNs credentials are correctly provisioned and injected.
- Secret rotation (certificate renewal, key rotation) completes within documented procedures without app downtime.
- Zero secret-related build failures per quarter after initial setup.

---

# Agent Contract

## Scope

- In scope:
  - Complete inventory of all API keys and secrets required for iOS and Android mobile apps
  - Naming conventions for mobile secrets in Infisical (`MEREKA_LMS_MOBILE_*` prefix)
  - GitHub Actions secrets inventory and naming for CI/CD pipelines
  - Firebase project configuration (FCM server key, APNs auth key, service account)
  - Apple Developer credentials (Team ID, App Store Connect API key, signing certificates, provisioning profiles)
  - Google Play credentials (upload key, service account JSON for Play Console API)
  - Build-time secret injection mechanisms (GitHub Actions secrets, Fastlane match, environment variables)
  - Runtime secret injection for LMS backend mobile features (push notifications via K8s secrets)
  - OAuth client configuration (`mereka-mobile-app` client ID)
  - Verification scripts that validate all required secrets exist and are non-empty
  - Secret rotation procedures and expiry tracking for certificates and keys
  - Dev/prod separation for mobile secrets (test vs production Firebase projects, sandbox vs production signing)

- Out of scope:
  - Mobile app feature implementation (covered by `specs/mobile-apps-enterprise_spec.md`)
  - General secrets pipeline architecture (covered by `specs/secrets-management_spec.md`)
  - Apple/Google developer account creation and administration
  - Firebase project creation and initial setup
  - In-app purchase receipt validation secrets (reserved for future spec)
  - Third-party analytics SDK keys (Segment, Braze, Branch -- currently disabled)
  - MDM (Mobile Device Management) certificate management

## Non-goals

- Automating secret rotation across Apple Developer Portal, Google Play Console, and Firebase Console (these require manual portal interactions; the spec covers documentation and verification, not automation)
- Building a custom secrets vault for mobile app binaries (secrets are injected at build time via CI environment, not at runtime via an app-side vault)
- Encrypting secrets within the mobile app binary beyond platform-native protections (iOS Data Protection, Android Keystore)
- Supporting multiple Firebase projects per environment (one Firebase project serves both platforms)
- Implementing certificate transparency monitoring for Apple Distribution certificates

## Assumptions

- The Mereka Academy Firebase project (`mereka-academy`) exists and is configured for both iOS (`com.mereka.academy.mobile`) and Android (`com.mereka.academy.mobile`)
- Apple Developer Team ID `44F7G2D7U6` is active with an Apple Developer Program membership
- The `ios-certificates` private git repository (`git@github.com:Biji-Biji-Initiative/ios-certificates.git`) is used by Fastlane match for certificate and profile storage
- GitHub Actions is the CI/CD platform for both iOS and Android builds
- Infisical at `secrets.mereka.io` is the canonical source of truth for secrets that flow to K8s (per `specs/secrets-management_spec.md`)
- GitHub repository secrets are the canonical source of truth for CI/CD-only secrets that do not need K8s injection
- The existing iOS CI/CD pipeline (`.github/workflows/build-ios-app.yml`) is operational and serves as the baseline pattern
- Google Play Developer account will be provisioned before Android CI/CD implementation begins

---

## Requirements

### Functional

#### Secret Categories and Storage

- The system MUST categorize mobile secrets into three tiers:
  1. **CI/CD Build Secrets**: Consumed only by GitHub Actions workflows during build and signing. Stored as GitHub Actions repository secrets.
  2. **Backend Runtime Secrets**: Consumed by the LMS/CMS backend to support mobile features (push notifications, deep linking verification). Stored in Infisical and synced to K8s via the established pipeline.
  3. **App Configuration Values**: Non-secret configuration embedded in app builds (OAuth client ID, API host URL, feature flags). Stored in repository config files (not secrets).

- The system MUST store CI/CD build secrets exclusively in GitHub Actions repository secrets, not in Infisical or K8s.
- The system MUST store backend runtime secrets in Infisical under the canonical path `/k8s/mereka-lms` with the `MEREKA_LMS_MOBILE_*` prefix, and sync them to K8s via GCP Secret Manager and ExternalSecrets.
- The system MUST NOT embed secret values (API keys, private keys, passwords) in repository source files, config templates, or CI workflow files.
- App configuration values (OAuth client ID, API host URL) MAY be stored in repository config files if they are non-secret public values.

#### Naming Convention

- All mobile-specific secrets in Infisical and GCP Secret Manager MUST use the prefix `MEREKA_LMS_MOBILE_` (e.g., `MEREKA_LMS_MOBILE_FCM_SERVICE_ACCOUNT_JSON`).
- K8s secret keys for mobile secrets MUST strip the `MEREKA_LMS_` prefix, retaining `MOBILE_*` (e.g., K8s key `MOBILE_FCM_SERVICE_ACCOUNT_JSON` maps to Infisical key `MEREKA_LMS_MOBILE_FCM_SERVICE_ACCOUNT_JSON`).
- GitHub Actions secrets MUST use descriptive uppercase names following the existing pattern (e.g., `APPLE_TEAM_ID`, `MATCH_PASSWORD`, `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`).
- GitHub Actions secrets MUST NOT use the `MEREKA_LMS_` prefix (GitHub Actions has its own namespace scoped to the repository).

#### Required Secret Inventory -- iOS CI/CD (GitHub Actions)

- The following GitHub Actions repository secrets MUST exist for iOS builds:

  | GitHub Secret Name | Purpose | Current Status | Rotation Cadence |
  |-------------------|---------|----------------|------------------|
  | `APPLE_TEAM_ID` | Apple Developer Team ID (`44F7G2D7U6`) | Configured | Stable (no rotation) |
  | `APP_STORE_CONNECT_API_KEY_ID` | ASC API Key ID for Fastlane (`9MUD3HJQH5`) | Configured | When key is revoked/replaced |
  | `APP_STORE_CONNECT_ISSUER_ID` | ASC Issuer ID | Configured | Stable (no rotation) |
  | `APP_STORE_CONNECT_API_KEY_BASE64` | Base64-encoded `.p8` private key for ASC API | Configured | When key is revoked/replaced |
  | `MATCH_DEPLOY_KEY` | SSH deploy key for `ios-certificates` git repo | Configured | Annually or on compromise |
  | `MATCH_PASSWORD` | Encryption password for Fastlane match certificate repo | Configured | On compromise only |

#### Required Secret Inventory -- Android CI/CD (GitHub Actions)

- The following GitHub Actions repository secrets MUST exist before Android CI/CD is operational:

  | GitHub Secret Name | Purpose | Current Status | Rotation Cadence |
  |-------------------|---------|----------------|------------------|
  | `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | Base64-encoded service account JSON for Google Play Console API uploads | Not yet created | Annually |
  | `ANDROID_KEYSTORE_BASE64` | Base64-encoded `.jks` or `.keystore` upload signing keystore | Not yet created | Never (Google Play App Signing manages the app signing key) |
  | `ANDROID_KEYSTORE_PASSWORD` | Password for the upload keystore | Not yet created | On compromise only |
  | `ANDROID_KEY_ALIAS` | Alias of the upload key within the keystore | Not yet created | Stable (no rotation) |
  | `ANDROID_KEY_PASSWORD` | Password for the specific key entry | Not yet created | On compromise only |

#### Required Secret Inventory -- Firebase & Push Notifications (Infisical -> K8s)

- The following secrets MUST exist in Infisical at `/k8s/mereka-lms` and be synced to K8s for backend mobile features:

  | Infisical Key | K8s Secret Key | Purpose | Current Status |
  |--------------|----------------|---------|----------------|
  | `MEREKA_LMS_MOBILE_FCM_SERVICE_ACCOUNT_JSON` | `MOBILE_FCM_SERVICE_ACCOUNT_JSON` | Firebase Admin SDK service account for sending push notifications via FCM | Not yet created |
  | `MEREKA_LMS_MOBILE_FCM_SERVER_KEY` | `MOBILE_FCM_SERVER_KEY` | Legacy FCM server key (for HTTP v1 migration period) | Not yet created |
  | `MEREKA_LMS_MOBILE_APNS_AUTH_KEY_BASE64` | `MOBILE_APNS_AUTH_KEY_BASE64` | Base64-encoded Apple Push Notification Authentication Key (.p8) | Not yet created |
  | `MEREKA_LMS_MOBILE_APNS_AUTH_KEY_ID` | `MOBILE_APNS_AUTH_KEY_ID` | APNs Authentication Key ID | Not yet created |
  | `MEREKA_LMS_MOBILE_FIREBASE_PROJECT_ID` | `MOBILE_FIREBASE_PROJECT_ID` | Firebase project ID (e.g., `mereka-academy`) | Not yet created |

- These secrets MUST be added to a new `mobile-secrets` ExternalSecret resource or appended to the existing `openedx-secrets` ExternalSecret in `deploy/k8s/base/secrets/external-secrets.yaml`.

#### Required Secret Inventory -- App Configuration (Repository Config)

- The following values MUST be present in the mobile app configuration files (non-secret, committed to repository):

  | Config Key | Value | Location |
  |-----------|-------|----------|
  | `API_HOST_URL` | `https://academyv2.mereka.io` | `default_config/mereka/prod/shared.yaml` |
  | `OAUTH_CLIENT_ID` | `mereka-mobile-app` | `default_config/mereka/prod/shared.yaml` |
  | `FIREBASE.ENABLED` | `false` (until Firebase is fully configured) | `default_config/mereka/prod/ios.yaml` |
  | `FIREBASE.BUNDLE_ID` | `com.mereka.academy.mobile` | `default_config/mereka/prod/ios.yaml` |
  | `FIREBASE.PROJECT_ID` | `mereka-academy` (or actual project ID) | `default_config/mereka/prod/ios.yaml` |
  | `APPLE_SIGNIN.ENABLED` | `true` | `default_config/mereka/prod/shared.yaml` |

- The `OAUTH_CLIENT_ID` value (`mereka-mobile-app`) MUST match the OAuth application registered in the LMS via `scripts/infra/setup-mobile-api.sh`.
- Firebase placeholder values in `ios.yaml` (e.g., `AIzaSyPlaceholder`) MUST be replaced with real values before enabling `FIREBASE.ENABLED: true`.

#### Build-Time Injection Mechanism

- iOS CI/CD workflows MUST inject Apple signing credentials via Fastlane match, which fetches certificates and profiles from the `ios-certificates` git repo using `MATCH_DEPLOY_KEY` (SSH) and decrypts them with `MATCH_PASSWORD`.
- iOS CI/CD workflows MUST inject App Store Connect API credentials via environment variables (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8_BASE64`) consumed by the Fastlane `app_store_connect_api_key` action.
- Android CI/CD workflows MUST inject the upload keystore via a base64-decoded file written to a temporary path during the build step, then deleted in the cleanup step.
- Android CI/CD workflows MUST inject Play Console API credentials via the `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` secret passed to the Fastlane `supply` or Gradle `publish` action.
- Firebase configuration for iOS builds MUST be injected via the `ios.yaml` config file processed by OpenEdX's `process_config.py` script, which generates `GoogleService-Info.plist`.
- Firebase configuration for Android builds MUST be injected via a `google-services.json` file decoded from a GitHub Actions secret or generated from config.

#### ExternalSecrets Configuration for Mobile Secrets

- Mobile backend runtime secrets MUST be synced to a K8s Secret named `mobile-secrets` (or appended to `openedx-secrets`) in the `mereka-lms` namespace.
- The ExternalSecret for mobile secrets MUST set `refreshInterval: 1h`, `secretStoreRef.kind: ClusterSecretStore` with `name: gcp-secret-manager`, `target.deletionPolicy: Retain`, and `target.creationPolicy: Owner` (matching the existing ExternalSecrets pattern from `specs/secrets-management_spec.md`).
- If mobile secrets are added to `openedx-secrets` rather than a separate ExternalSecret, the existing resource MUST be updated to include the new key mappings without disrupting existing mappings.

#### Verification Tooling

- A validation script (`scripts/mobile/validate-mobile-secrets.sh`) MUST verify that:
  1. All required GitHub Actions secrets exist (via `gh secret list` or equivalent API check).
  2. All required Infisical secrets exist at `/k8s/mereka-lms` with non-empty, non-placeholder values.
  3. The iOS `MATCH_DEPLOY_KEY` can authenticate to the `ios-certificates` git repo (SSH connectivity test).
  4. The Apple Distribution certificate referenced by Fastlane match has not expired.
  5. Firebase project ID in app configuration matches the Firebase project ID in Infisical.
- The validation script MUST exit with a non-zero status code if any required secret is missing or invalid.
- The validation script MUST output a summary table showing each secret's name, store location, and status (present/missing/expired/placeholder).
- The validation script SHOULD be runnable in `--ci` mode (non-interactive, suitable for GitHub Actions) and `--interactive` mode (prompts for manual verification of secrets that cannot be programmatically checked).

#### Certificate and Key Expiry Tracking

- The system MUST track expiry dates for the following time-bounded credentials:

  | Credential | Current Expiry | Alert Threshold |
  |-----------|---------------|-----------------|
  | Apple Distribution Certificate | 2027-01-22 | 60 days before expiry |
  | App Store Connect API Key | No expiry (revocable) | N/A |
  | APNs Authentication Key (.p8) | No expiry (revocable) | N/A |
  | Android Upload Keystore | No expiry | N/A |
  | Fastlane Match Deploy Key | No expiry (rotatable) | Annually |
  | Firebase Service Account | No expiry (rotatable) | Annually |

- The validation script MUST check the Apple Distribution certificate expiry date and MUST fail if the certificate expires within 30 days.
- The validation script SHOULD warn if the certificate expires within 60 days.
- CI/CD workflows SHOULD include a step that checks certificate expiry before attempting a build, failing fast with a clear error message rather than a cryptic signing failure.

#### Security Rules

- The `APP_STORE_CONNECT_API_KEY_BASE64` secret MUST NOT be logged or echoed in CI output, even in debug mode.
- The `MATCH_PASSWORD` MUST NOT appear in any log output or workflow step output.
- The Android upload keystore file MUST be written to a temporary directory during builds and deleted in an `if: always()` cleanup step.
- The `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` MUST NOT be committed to the repository, even in encrypted form.
- Firebase service account JSON MUST NOT be embedded in the mobile app binary; it is consumed only by the backend (LMS pod).
- The FCM server key (legacy) MUST be deprecated in favor of the Firebase Admin SDK service account (FCM HTTP v1 API) before the legacy key sunset date.
- GitHub Actions secrets MUST only be accessible to workflows running on `main` branch and `workflow_dispatch` triggers (not on pull requests from forks).

#### Dev/Prod Separation

- Dev (local/Kind) environments MUST use a separate Firebase project (or the same project with a distinct app registration) to prevent test push notifications from reaching production devices.
- The validation script MUST support an `--env` flag (`prod` or `dev`) to validate environment-specific secrets.
- Android debug builds MUST use a separate debug signing keystore (not the upload keystore) to prevent accidental production-signed debug builds.
- iOS debug builds MUST use Xcode automatic signing with the development certificate, not the distribution certificate managed by Fastlane match.

### Non-Functional Requirements

#### Security

- All secrets in transit between Infisical/GCP SM/K8s MUST be encrypted (TLS 1.2+), per the platform-wide requirement in `specs/cross-cutting-requirements_spec.md`.
- GitHub Actions secrets MUST NOT be exposed to forked repository pull request workflows.
- The `ios-certificates` git repository MUST remain private and accessible only via the `MATCH_DEPLOY_KEY` deploy key.
- Mobile secrets in K8s MUST follow the same `deletionPolicy: Retain` pattern as other ExternalSecrets to prevent accidental loss.

#### Availability

- Missing or expired mobile secrets MUST NOT affect the availability of the LMS web application. Mobile secret failures MUST be isolated to mobile build pipelines and mobile-specific backend features (push notifications).
- If Firebase credentials are missing or invalid, the push notification dispatch service MUST log the error and degrade gracefully (queue notifications for retry), not crash the LMS worker process.

#### Operational

- Adding a new mobile secret MUST follow a documented procedure (create in source store, add to validation script inventory, add to ExternalSecret if K8s-bound, update this spec's inventory tables).
- Secret rotation for Apple certificates MUST be completable within 4 hours by a single operator following the documented runbook.
- The validation script MUST complete within 60 seconds in CI mode.

---

## Acceptance Criteria

### CI/CD Secret Presence

- [ ] AC-MAS-001: Given the GitHub Actions secrets for `mereka-lms`, when `gh secret list` is run, then all 6 iOS secrets exist: `APPLE_TEAM_ID`, `APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_API_KEY_BASE64`, `MATCH_DEPLOY_KEY`, `MATCH_PASSWORD`.
- [ ] AC-MAS-002: Given the iOS CI/CD workflow (`.github/workflows/build-ios-app.yml`), when it references secrets, then every `${{ secrets.* }}` reference maps to a secret defined in the inventory table in this spec.
- [ ] AC-MAS-003: Given the Android CI/CD secrets are provisioned, when `gh secret list` is run, then all 5 Android secrets exist: `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`, `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.

### Infisical Secret Presence

- [ ] AC-MAS-004: Given the Infisical path `/k8s/mereka-lms`, when the mobile push notification backend is ready, then the following keys exist with non-empty values: `MEREKA_LMS_MOBILE_FCM_SERVICE_ACCOUNT_JSON`, `MEREKA_LMS_MOBILE_APNS_AUTH_KEY_BASE64`, `MEREKA_LMS_MOBILE_APNS_AUTH_KEY_ID`, `MEREKA_LMS_MOBILE_FIREBASE_PROJECT_ID`.
- [ ] AC-MAS-005: Given Infisical contains `MEREKA_LMS_MOBILE_*` keys, when the validation script runs with `STRICT=1`, then no key has an empty value, a placeholder value (`REPLACE_ME`, `CHANGE_ME`, `TODO`, `TBD`, `placeholder`, `AIzaSyPlaceholder`), or trailing CR/LF bytes.

### Naming Convention

- [ ] AC-MAS-006: Given all mobile secrets in Infisical, when their key names are inspected, then every mobile-specific key starts with `MEREKA_LMS_MOBILE_`.
- [ ] AC-MAS-007: Given the ExternalSecret mapping for mobile secrets, when the `data` array is inspected, then each entry maps a `MEREKA_LMS_MOBILE_*` remote key to a `MOBILE_*` local K8s secret key.

### Build-Time Injection

- [ ] AC-MAS-008: Given the iOS CI/CD workflow, when a build is triggered on the `main` branch, then Fastlane match successfully fetches the Apple Distribution certificate and provisioning profile from the `ios-certificates` repo using `MATCH_DEPLOY_KEY` and `MATCH_PASSWORD`.
- [ ] AC-MAS-009: Given the iOS CI/CD workflow, when the `build_app` step runs, then the built IPA is signed with the correct Apple Distribution certificate for Team ID `44F7G2D7U6` and bundle ID `com.mereka.academy.mobile`.
- [ ] AC-MAS-010: Given the iOS CI/CD workflow, when the `upload_to_testflight` step runs, then it authenticates via the App Store Connect API using `ASC_KEY_ID`, `ASC_ISSUER_ID`, and `ASC_KEY_P8_BASE64` without manual Apple ID login.

### K8s Secret Injection

- [ ] AC-MAS-011: Given the mobile push notification backend is deployed, when the LMS pod environment is inspected, then the `MOBILE_FCM_SERVICE_ACCOUNT_JSON` environment variable contains a valid Firebase service account JSON string.
- [ ] AC-MAS-012: Given the `mobile-secrets` (or `openedx-secrets`) ExternalSecret, when its spec is inspected, then `refreshInterval: 1h`, `secretStoreRef.name: gcp-secret-manager`, `target.deletionPolicy: Retain`, and `target.creationPolicy: Owner` are set.

### Verification Script

- [ ] AC-MAS-013: Given the validation script `scripts/mobile/validate-mobile-secrets.sh` exists, when run with `--platform ios`, then it checks all 6 iOS GitHub Actions secrets and reports their presence status.
- [ ] AC-MAS-014: Given the validation script, when run with `--platform android`, then it checks all 5 Android GitHub Actions secrets and reports their presence status.
- [ ] AC-MAS-015: Given the validation script, when run with `--platform all --env prod`, then it checks all Infisical `MEREKA_LMS_MOBILE_*` keys at `/k8s/mereka-lms` and reports their presence and value status (non-empty, non-placeholder).
- [ ] AC-MAS-016: Given the validation script, when a required secret is missing, then the script exits with a non-zero status code and prints the missing secret name to stderr.
- [ ] AC-MAS-017: Given the validation script, when the Apple Distribution certificate expires within 60 days, then the script prints a warning. When it expires within 30 days, the script exits with a non-zero status code.

### Certificate Expiry

- [ ] AC-MAS-018: Given the Apple Distribution certificate managed by Fastlane match, when its expiry date is 2027-01-22, then the validation script correctly parses and reports the remaining days until expiry.
- [ ] AC-MAS-019: Given a CI/CD workflow run, when the pre-build certificate check detects expiry within 30 days, then the workflow fails with a clear error message: "Apple Distribution certificate expires in N days. Rotate before continuing."

### Security

- [ ] AC-MAS-020: Given the iOS CI/CD workflow output, when inspected after a successful build, then no secret values (API keys, passwords, base64 certificate data) appear in the workflow logs.
- [ ] AC-MAS-021: Given a pull request from a forked repository, when it triggers a workflow, then GitHub Actions secrets are NOT available to the workflow steps (GitHub default behavior, verified by workflow configuration).
- [ ] AC-MAS-022: Given the Android CI/CD workflow, when the build completes (success or failure), then the temporary keystore file is deleted in the cleanup step.

### App Configuration Consistency

- [ ] AC-MAS-023: Given the iOS app config at `default_config/mereka/prod/shared.yaml`, when `OAUTH_CLIENT_ID` is read, then it equals `mereka-mobile-app` and matches the OAuth application registered in the LMS.
- [ ] AC-MAS-024: Given the iOS app config at `default_config/mereka/prod/ios.yaml`, when `FIREBASE.PROJECT_ID` is read, then it matches the `MEREKA_LMS_MOBILE_FIREBASE_PROJECT_ID` value in Infisical (once Firebase is enabled).

### Dev/Prod Separation

- [ ] AC-MAS-025: Given a dev/Kind environment, when mobile push notification secrets are inspected, then they reference a dev Firebase project (or dev-specific keys), not the production Firebase project credentials.

---

## Edge Cases

### Apple Certificate Expiry During Active Release

- The Apple Distribution certificate expires on 2027-01-22. If an App Store submission is in review when the certificate expires, the already-submitted build remains valid. However, no new builds can be signed until the certificate is renewed. Mitigation: the validation script warns at 60 days and fails at 30 days. The rotation runbook (`docs/operations/runbooks/MOBILE_APPS_RUNBOOK.md`) includes certificate renewal steps. Calendar reminders MUST be set for 90, 60, and 30 days before expiry.

### Fastlane Match Certificate Mismatch

- If the Apple Distribution certificate in the `ios-certificates` repo does not match the one registered in the Apple Developer Portal (e.g., after manual portal changes), Fastlane match will fail with a signing identity mismatch. Mitigation: run `match nuke distribution` to clear the repo, then `match appstore` to regenerate. This requires the `MATCH_PASSWORD` and `MATCH_DEPLOY_KEY` secrets. Document this as an emergency procedure in the runbook.

### GitHub Actions Secret Deletion

- If a GitHub Actions secret is accidentally deleted (e.g., repository settings UI), the next CI build will fail with an empty environment variable. GitHub does not provide secret version history or undo. Mitigation: the validation script detects missing secrets. Secret values MUST be recorded in Infisical under a `github-actions` annotation (metadata only, not the actual pipeline; the values themselves are stored only in GitHub). Recovery requires re-creating the secret from the original source (Apple Developer Portal, keystore file, etc.).

### Firebase Project Mismatch Between App Config and Backend

- If the Firebase project ID in the app's `ios.yaml` config differs from the `MEREKA_LMS_MOBILE_FIREBASE_PROJECT_ID` in the backend, push notifications will be sent to the wrong project and never reach devices. Mitigation: AC-MAS-024 validates that these values match. The validation script cross-checks the two sources.

### Android Upload Key Compromise

- If the Android upload keystore is compromised, Google Play App Signing allows a key upgrade. The process involves generating a new upload key, submitting it to Google Play support, and updating the `ANDROID_KEYSTORE_BASE64` GitHub secret. During the upgrade period (up to 72 hours), no Android builds can be uploaded. Mitigation: document the key upgrade procedure in the runbook. The upload key MUST NOT be shared outside the CI/CD pipeline.

### Legacy FCM Server Key Deprecation

- Google has announced deprecation of the legacy FCM HTTP API (using the server key). The system MUST migrate to the FCM HTTP v1 API (using the Firebase Admin SDK service account) before the deprecation date. During the transition, both `MEREKA_LMS_MOBILE_FCM_SERVER_KEY` (legacy) and `MEREKA_LMS_MOBILE_FCM_SERVICE_ACCOUNT_JSON` (v1) MAY coexist. After migration, the legacy key SHOULD be deleted from Infisical.

### CI Build Fails Due to Expired ASC API Key

- App Store Connect API keys do not expire but can be revoked. If the key is revoked (e.g., by another team member in the Apple Developer Portal), the `upload_to_testflight` step will fail with a 401 error. Mitigation: the ASC API key SHOULD be created as a dedicated CI key with limited scope (App Manager role, not Admin). The validation script SHOULD test ASC API key validity by making a lightweight API call (e.g., list apps).

### Concurrent iOS and Android Builds with Shared Firebase

- If iOS and Android builds run concurrently and both attempt to modify Firebase configuration (e.g., registering app instances), there is no conflict because each platform has a separate app registration within the same Firebase project. The `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) contain platform-specific client IDs that do not overlap.

### Secret Rotation During In-Flight Build

- If a GitHub Actions secret is updated while a CI build is in progress, the running build uses the old value (secrets are injected at workflow start). The new value takes effect on the next build. This is safe because rotation procedures should ensure both old and new credentials are valid during the overlap window.

---

## Observability

### Logs

- The validation script (`validate-mobile-secrets.sh`) MUST log timestamped progress messages to stdout and error details to stderr.
- The validation script MUST output a structured summary (one line per secret: name, store, status) suitable for parsing by CI dashboards.
- iOS CI/CD workflows MUST NOT log secret values. Fastlane's `--verbose` mode MUST be disabled in production CI runs, or secret masking MUST be confirmed active.
- Push notification dispatch failures caused by invalid Firebase credentials MUST log `error_code=FIREBASE_AUTH_FAILED`, `secret_name=MOBILE_FCM_SERVICE_ACCOUNT_JSON`, and `timestamp` -- MUST NOT log the credential value.

### Metrics

- `mobile_secret_validation_result` (gauge, labels: `platform`, `env`, `result`) -- 1 for pass, 0 for fail. Emitted by the validation script when run in CI.
- `mobile_certificate_days_to_expiry` (gauge, labels: `cert_type`) -- days until Apple Distribution certificate expires. Emitted by the validation script or a scheduled CI job.
- `mobile_push_auth_failures_total` (counter, labels: `platform`, `error_type`) -- count of push notification delivery failures due to authentication errors (invalid FCM credentials, expired APNs key).

### Alerts

- **Critical**: `mobile_certificate_days_to_expiry` drops below 30 for any `cert_type` -- page oncall and notify `#mobile-dev` channel.
- **Warning**: `mobile_certificate_days_to_expiry` drops below 60 for any `cert_type` -- notify `#mobile-dev` channel weekly.
- **Warning**: `mobile_push_auth_failures_total` exceeds 10 in 15 minutes -- notify `#ops-warnings` channel.
- **Warning**: `mobile_secret_validation_result{result="0"}` observed in weekly CI validation run -- notify `#mobile-dev` channel.

### Dashboards

- A "Mobile Secrets Health" panel on the Mobile Overview Grafana dashboard SHOULD display:
  - Certificate expiry countdown (days remaining)
  - Last validation script result (pass/fail with timestamp)
  - Push notification auth failure rate over 24 hours
  - Count of configured vs missing secrets by platform

---

## Rollout & Rollback

### Rollout Plan

#### Phase 1: Formalize Existing iOS Secrets (Immediate)
1. Audit and document all currently configured GitHub Actions secrets (6 iOS secrets per the inventory).
2. Create the validation script (`scripts/mobile/validate-mobile-secrets.sh`) with iOS secret checking.
3. Add certificate expiry checking to the validation script.
4. Run validation to confirm current state matches this spec.

#### Phase 2: Add Firebase/Push Notification Secrets (With Mobile Push Feature)
1. Create Firebase Admin SDK service account in the Firebase Console.
2. Create `MEREKA_LMS_MOBILE_FCM_SERVICE_ACCOUNT_JSON` in Infisical at `/k8s/mereka-lms`.
3. Create APNs Authentication Key in Apple Developer Portal and store as `MEREKA_LMS_MOBILE_APNS_AUTH_KEY_BASE64`.
4. Sync to GCP SM via `sync-mereka-lms-secrets-to-gcpsm.sh`.
5. Add key mappings to ExternalSecrets YAML (either new `mobile-secrets` or appended to `openedx-secrets`).
6. Update validation script with Infisical checks.
7. Validate end-to-end: `STRICT=1 scripts/mobile/validate-mobile-secrets.sh --platform all --env prod`.

#### Phase 3: Android CI/CD Secrets (With Android App Development)
1. Generate Android upload keystore and create GitHub Actions secrets.
2. Create Google Play service account and store as `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` in GitHub.
3. Create `google-services.json` generation mechanism for Android builds.
4. Update validation script with Android secret checking.
5. Create `build-android-app.yml` workflow referencing the new secrets.

#### Phase 4: Weekly CI Validation (Ongoing)
1. Add a scheduled GitHub Actions workflow that runs `validate-mobile-secrets.sh --ci --platform all` weekly.
2. Configure alert routing for validation failures.
3. Add certificate expiry metrics to Grafana dashboard.

### Feature Flags

- No feature flags needed for secrets management itself. Push notification delivery is gated by `mobile_push_notifications_enabled` (defined in `specs/mobile-apps-enterprise_spec.md`), which effectively gates whether the Firebase/APNs secrets are exercised at runtime.

### Backward Compatibility

- Adding new secrets to Infisical and GitHub Actions does not affect existing secrets or running services.
- Adding new key mappings to the `openedx-secrets` ExternalSecret is additive and does not disrupt existing mappings (K8s merges the new keys into the existing Secret object on the next sync).
- The validation script is a new tool that does not modify any existing infrastructure.

### Rollback Steps

1. **If a newly added mobile secret causes LMS issues** (e.g., malformed JSON in `MOBILE_FCM_SERVICE_ACCOUNT_JSON` crashes the worker): Remove the offending key from the ExternalSecret YAML, apply the change, and force ESO refresh. The key will be removed from the K8s Secret on the next sync.
2. **If Fastlane match breaks after certificate renewal**: Run `fastlane match nuke distribution` to clear the certificates repo, then `fastlane match appstore` to regenerate. Update the `MATCH_PASSWORD` in GitHub Actions if the encryption password changed.
3. **If the validation script produces false positives**: The script is advisory (does not modify secrets). Fix the script logic and re-run. The script MUST NOT have any write permissions to secrets stores.
4. **If Android keystore is compromised**: Immediately revoke the upload key via Google Play Console key upgrade. Generate a new keystore, update `ANDROID_KEYSTORE_BASE64` and `ANDROID_KEYSTORE_PASSWORD` in GitHub, and re-run the Android CI pipeline.

---

## Verification

```bash
# 1. iOS GitHub Actions secrets exist
gh secret list --repo Biji-Biji-Initiative/mereka-lms | grep -E "APPLE_TEAM_ID|APP_STORE_CONNECT_API_KEY_ID|APP_STORE_CONNECT_ISSUER_ID|APP_STORE_CONNECT_API_KEY_BASE64|MATCH_DEPLOY_KEY|MATCH_PASSWORD"
# MUST return 6 lines

# 2. iOS CI workflow references only known secrets
grep -oP 'secrets\.\K[A-Z_]+' .github/workflows/build-ios-app.yml | sort -u
# Each must be in the inventory table

# 3. Infisical mobile secrets (when provisioned)
cd /home/gurpreet/projects/k8s/reka-slackbot && \
infisical secrets list \
  --domain https://secrets.mereka.io/api \
  --env prod --path /k8s/mereka-lms --recursive --output json 2>/dev/null \
  | jq -r '.[].key' | grep '^MEREKA_LMS_MOBILE_'
# MUST list all MOBILE_* keys after Phase 2

# 4. Naming convention compliance
cd /home/gurpreet/projects/k8s/reka-slackbot && \
infisical secrets list \
  --domain https://secrets.mereka.io/api \
  --env prod --path /k8s/mereka-lms --recursive --output json 2>/dev/null \
  | jq -r '.[].key' | grep 'MOBILE' | grep -v '^MEREKA_LMS_MOBILE_'
# MUST return empty (all mobile keys use MEREKA_LMS_MOBILE_ prefix)

# 5. OAuth client ID consistency
grep 'OAUTH_CLIENT_ID' scripts/mobile/setup-ios-app.sh
# MUST show "mereka-mobile-app"

# 6. Certificate expiry check
# (Requires match cert to be locally available or checked via Apple API)
openssl x509 -enddate -noout -in /path/to/distribution_cert.pem
# Verify expiry is after 2026-11-23 (60 days from concern)

# 7. Validation script (once created)
scripts/mobile/validate-mobile-secrets.sh --platform ios --env prod
# MUST exit 0

# 8. No secrets in workflow logs (manual check)
# Review most recent build-ios-app.yml run in GitHub Actions
# Verify no secret values appear in any step output

# 9. ExternalSecret for mobile (after Phase 2)
kubectl get externalsecret -n mereka-lms -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep mobile
# OR verify mobile keys in openedx-secrets:
kubectl get secret openedx-secrets -n mereka-lms -o jsonpath='{.data}' | jq 'keys[]' | grep MOBILE
```

---

## Open Questions

1. **Separate `mobile-secrets` ExternalSecret vs appending to `openedx-secrets`?** Adding to `openedx-secrets` is simpler (one resource to manage) but increases blast radius of sync failures. A separate `mobile-secrets` ExternalSecret provides isolation but adds operational overhead (another resource to monitor). Recommendation: start with `openedx-secrets` for simplicity, split if the key count exceeds 5.

2. **Firebase project sharing between dev and prod**: Should dev and prod use the same Firebase project with different app registrations, or completely separate Firebase projects? Same project simplifies management but risks dev push notifications reaching prod analytics. Separate projects require duplicating Firebase configuration. Need Firebase admin input.

3. **APNs Authentication Key vs APNs Certificate**: Apple supports two push notification credential types: Authentication Key (.p8, no expiry, one key per account for all apps) and APNs Certificate (.pem, expires yearly, per-app). The Authentication Key is recommended because it does not expire and works across all apps. Confirm this is the chosen approach before creating Infisical entries.

4. **Android upload key generation procedure**: Should the upload keystore be generated locally by an operator, or generated within a CI step and exported? Local generation is more secure (key never exists outside the operator's machine and GitHub) but requires manual steps. CI generation is automated but the key transiently exists in the runner.

5. **FCM HTTP v1 migration timeline**: Google deprecated the legacy FCM server key API. What is the target date for completing the migration to the FCM HTTP v1 API (using the service account)? This determines whether we need the `MEREKA_LMS_MOBILE_FCM_SERVER_KEY` (legacy) entry at all.

6. **Weekly validation CI cost**: Running the validation script weekly requires a GitHub Actions workflow that authenticates to Infisical (needs `INFISICAL_TOKEN` and `INFISICAL_PROJECT_ID` as GitHub secrets) and optionally to the Apple Developer API. Is this approved, and should it be a blocking check or an advisory notification?

7. **Google Play Developer account status**: Is the Google Play Developer account provisioned? The Android CI/CD secrets (Tier Phase 3) depend on this. If not yet provisioned, Android secrets should remain in the "Not yet created" state in the inventory.
