# Mobile Token Parity Assessment

**Purpose**: Document how Mereka design tokens apply to mobile, assess API parity between
the custom mobile API and Open edX upstream, and identify theming gaps.

**Status**: ACTIVE
**Last audited**: 2026-02-25
**Verification script**: `scripts/qa/verify-mobile-token-parity.sh`

---

## Background

Two dependency specs are complete:

- **T107 — Design Tokens** (`docs/reference/architecture/TOKEN_GENERATION_PIPELINE.md`): Canonical
  token source is `assets/branding/tokens.css` (110 CSS custom properties). A generator
  script (`scripts/branding/generate-tokens-from-canonical.sh`) propagates values to the
  SCSS bridge and runtime CSS layers. All known drift was resolved 2026-02-25.

- **T032 — Mobile deployment** (`docs/runbooks/operations/MOBILE_DEPLOYMENT.md`): iOS is active on
  TestFlight. Android is deferred (ADR-016). The custom mobile API lives under
  `infrastructure/tutor/custom-apps/openedx_mobile_api/`. Push notifications live under
  `infrastructure/tutor/custom-apps/openedx_push_notifications/`.

---

## How Design Tokens Apply to Mobile

### Token Delivery Architecture

Design tokens are CSS custom properties. They are rendered in the LMS/CMS/MFE web layer
via the Mereka Tutor theme. The mobile app is a **native iOS app** (openedx-app-ios)
that does NOT load CSS from the LMS. Tokens reach mobile through two mechanisms:

| Mechanism | Description | Token source |
|-----------|-------------|--------------|
| **Branding Config API** | `/api/mobile/v1/config/{org_slug}/` returns `primary_color` and `secondary_color` as hex strings | `MobileBrandingConfig` model in `openedx_mobile_api` |
| **iOS Branding Extension API** | `/api/mobile/v1/ios/branding/{org_slug}/` returns `tint_color`, `navigation_bar_color`, `tab_bar_color`, splash colors | `IOSBrandingExtension` model |

Neither API ingests tokens from `assets/branding/tokens.css` at runtime. Color values are
stored in Django model fields and must be populated manually with values from the canonical
token file.

### Token → Mobile Mapping (Canonical)

The following table maps canonical tokens from `tokens.css` to the mobile API fields that
should carry the equivalent values. This mapping is the **intended parity contract** —
there is no automated enforcement today.

| Canonical token | Canonical value | Mobile API field | Model | Current default |
|-----------------|-----------------|------------------|-------|-----------------|
| `--color-magenta` | `#ab3b78` | `primary_color` | `MobileBrandingConfig` | `#1a73e8` (DRIFT) |
| `--color-teal` | `#237072` | `secondary_color` | `MobileBrandingConfig` | `#34a853` (DRIFT) |
| `--color-white` | `#ffffff` | `splash_background_color` | `MobileBrandingConfig` | `#ffffff` (OK) |
| `--color-magenta` | `#ab3b78` | `tint_color` | `IOSBrandingExtension` | `#1a73e8` (DRIFT) |
| `--color-white` | `#ffffff` | `navigation_bar_color` | `IOSBrandingExtension` | `#ffffff` (OK) |
| `--color-white` | `#ffffff` | `tab_bar_color` | `IOSBrandingExtension` | `#ffffff` (OK) |

**Key finding**: Both `primary_color` and `tint_color` default to `#1a73e8` (Google Blue)
rather than `#ab3b78` (Mereka Magenta). `secondary_color` defaults to `#34a853` (Google
Green) rather than `#237072` (Mereka Teal). These defaults are hardcoded in the Django model
field definitions and will be wrong for any freshly-created `MobileBrandingConfig` record
unless the operator explicitly sets the correct values at record creation time.

### What Tokens Do NOT Reach Mobile

The following token categories in `tokens.css` have no mobile delivery path:

| Category | Token examples | Mobile gap |
|----------|---------------|------------|
| Typography | `--font-heading`, `--font-body`, `--text-h1` | Native app uses system fonts (SF Pro on iOS). No API to deliver font family or size tokens. |
| Spacing | `--space-1` through `--space-24` | Native layout uses Auto Layout / UIKit constants. No API surface. |
| Border radius | `--radius-sm` through `--radius-full` | Native components use their own radius values. Not exposed via API. |
| Shadows | `--shadow-sm` through `--shadow-xl` | Not applicable to native UIKit shadows. |
| Z-index | `--z-dropdown` etc. | Not applicable in native UI. |
| Breakpoints | `--breakpoint-sm` etc. | Not applicable in native UI (distinct layout system). |
| Animation durations | `--duration-75` etc. | Native app uses UIKit animation APIs. |
| Gray scale | `--gray-50` through `--gray-950` | Not surfaced in branding API. Hardcoded in app. |
| Semantic colors | `--color-success`, `--color-error` etc. | Not surfaced in branding API. |

**Assessment**: This is expected and acceptable. Native mobile apps do not consume web CSS.
The relevant subset — primary brand colors and iOS chrome colors — is the correct scope for
API token delivery.

---

## API Parity Assessment

### Custom Mobile API Endpoints

The custom app at `infrastructure/tutor/custom-apps/openedx_mobile_api/` provides:

| Endpoint | Method | Auth | Status | Notes |
|----------|--------|------|--------|-------|
| `/api/mobile/v1/config/{org_slug}/` | GET | None | Implemented | Branding config, 5-min cache |
| `/api/mobile/v1/notifications/register/` | POST | Bearer | Implemented | Idempotent device registration |
| `/api/mobile/v1/notifications/register/` | DELETE | Bearer | Implemented | Device unregistration |
| `/api/mobile/v1/ios/auth/pkce/challenge/` | POST | None | Implemented | PKCE challenge generation |
| `/api/mobile/v1/ios/auth/token/refresh/` | POST | Bearer | Implemented (placeholder) | Refresh logic is a stub using `secrets.token_urlsafe`. Not integrated with django-oauth-toolkit. |
| `/api/mobile/v1/ios/auth/token/revoke/` | POST | Bearer | Implemented | Server-side revocation |
| `/api/mobile/v1/ios/notifications/apns/` | POST | Bearer | Implemented (placeholder) | Logs only; no actual APNs send |
| `/api/mobile/v1/ios/offline/courses/` | GET | Bearer | Implemented | Offline course list |
| `/api/mobile/v1/ios/offline/courses/{id}/download/` | POST/GET | Bearer | Implemented | Course download initiation |
| `/api/mobile/v1/ios/offline/courses/{id}/progress/` | GET/POST | Bearer | Implemented | Progress sync |
| `/api/mobile/v1/ios/offline/courses/{id}/` | DELETE | Bearer | Implemented | Remove local course |
| `/api/mobile/v1/ios/offline/courses/{id}/videos/` | GET | Bearer | Implemented | Video list for offline |
| `/api/mobile/v1/ios/universal-links/verify/` | GET | None | Implemented | Universal link verification |
| `/api/mobile/v1/ios/app-store/metadata/` | GET | None | Implemented | App Store metadata |
| `/api/mobile/v1/ios/app-store/metadata/{language}/` | GET | None | Implemented | Localized metadata |
| `/api/mobile/v1/ios/app-store/screenshots/{lang}/{device}/` | GET | None | Implemented | Screenshots by device |
| `/api/mobile/v1/ios/app-store/review-notes/{version}/` | GET | Staff only | Implemented | Review notes (staff gate) |
| `/api/mobile/v1/ios/branding/` | GET | None | Implemented | iOS branding (default org) |
| `/api/mobile/v1/ios/branding/{org_slug}/` | GET | None | Implemented | iOS branding per tenant |

### Open edX Upstream Mobile API Endpoints

The Open edX LMS provides a standard mobile API at `/api/mobile/v1/` and `/api/mobile/v4/`.
These are consumed by the upstream openedx-app-ios without modification:

| Endpoint | Method | Purpose | Expected status |
|----------|--------|---------|-----------------|
| `/api/mobile/v1/users/me` | GET | Current user profile | Requires `ENABLE_MOBILE_REST_API: true` |
| `/api/mobile/v4/my_courses/` | GET | Enrolled courses | Requires `DEFAULT_MOBILE_AVAILABLE: true` |
| `/api/mobile/v1/courses/{id}/blocks` | GET | Course content blocks | Standard upstream |
| `/oauth2/authorize/` | GET | OAuth2 auth start | Requires `ENABLE_OAUTH2_PROVIDER: true` |
| `/oauth2/access_token/` | POST | Token exchange | Standard upstream |
| `/oauth2/revoke_token/` | POST | Token revocation | Standard upstream |
| `/.well-known/apple-app-site-association` | GET | iOS Universal Links | Served as static file |
| `/.well-known/assetlinks.json` | GET | Android App Links | Served as static file |

**Parity finding**: All custom endpoints are additive. The custom app does not override or
shadow any upstream mobile API endpoints. There is no URL collision.

### Push Notification App Overlap

Two apps handle device registration, which creates a potential conflict depending on how
the LMS root urlconf mounts them:

| App | Model | Relative URL in urls.py | Notes |
|-----|-------|-------------------------|-------|
| `openedx_mobile_api` | `MobileDevice` | `notifications/register/` | Stores platform, app_version, device_name; unique on `device_token` only |
| `openedx_push_notifications` | `DeviceRegistration` | `register/` | Stores org_slug for multi-tenancy; unique on `(device_token, org_slug)` |

**Key finding**: The URL files themselves do not collide statically. The conflict risk
arises if `openedx_push_notifications` is mounted at `api/mobile/v1/notifications/` in the
LMS root urlconf, which would make both apps resolve to the same absolute path. There is no
urlconf audit in this repo confirming the mount points. The `openedx_push_notifications`
model is more complete (multi-tenant aware with `org_slug`, proper deduplication via
`update_or_create`) — that app should be the canonical device registration handler.

---

## Theming Gaps

### Gap 1: Model defaults do not reflect canonical tokens (Critical)

**Location**: `openedx_mobile_api/models.py`, `MobileBrandingConfig` and
`IOSBrandingExtension` classes.

**Problem**: Default values for brand colors in Django model fields use Google's brand colors
(`#1a73e8`, `#34a853`) rather than Mereka canonical tokens. Any new `MobileBrandingConfig`
record created without explicit field values will produce a non-Mereka-branded mobile
experience.

**Affected fields**:
- `MobileBrandingConfig.primary_color` — default `#1a73e8`, should be `#ab3b78`
- `MobileBrandingConfig.secondary_color` — default `#34a853`, should be `#237072`
- `IOSBrandingExtension.tint_color` — default `#1a73e8`, should be `#ab3b78`

**Remediation**: Update model defaults. This requires a Django migration. No code change is
needed until a migration is created — model defaults only affect `DEFAULT` in the database
column, not existing records.

### Gap 2: Token refresh endpoint is a stub (High)

**Location**: `openedx_mobile_api/ios_views.py`, `TokenRefreshView.post()`.

**Problem**: The token refresh endpoint generates a new access token using
`secrets.token_urlsafe(32)` and stores it in a custom `MobileToken` model, bypassing
django-oauth-toolkit entirely. This means:
- The new access token is not recognized by any standard Open edX OAuth2-protected endpoint
- There is no integration between the custom token store and the LMS session system
- The `MobileToken` model in `ios_auth.py` is a parallel token store with no LMS awareness

**Remediation**: Token refresh must be delegated to the LMS's `/oauth2/token/` endpoint
(or the django-oauth-toolkit `TokenView`). The stub should be replaced with a proxy
call to the upstream endpoint. This is a non-trivial implementation gap.

### Gap 3: APNs delivery view does not send notifications (Medium)

**Location**: `openedx_mobile_api/ios_views.py`, `APNsDeliveryView.post()`.

**Problem**: The view creates a database record and logs the notification type, but contains
a comment `# In production, send to APNs here` with no actual APNs HTTP/2 call. Push
notifications configured via this endpoint will never be delivered.

The `openedx_push_notifications` app (`tasks.py`, `ace_channel.py`) appears to have more
complete FCM/APNs delivery logic, but this view does not delegate to those tasks.

**Remediation**: Either delegate to the Celery task in `openedx_push_notifications`, or
implement `httpx`/`aiohttp` APNs HTTP/2 calls here. Mark as UNIMPLEMENTED until done.

### Gap 4: AASA `appIDs` contains placeholder team ID (Medium)

**Location**: `openedx_mobile_api/static/.well-known/apple-app-site-association`.

**Problem**: The file contains `"TEAM_ID.io.mereka.academy"`. The value `TEAM_ID` is a
placeholder. The actual Apple Developer Team ID is `44F7G2D7U6` (from
`docs/runbooks/operations/MOBILE_DEPLOYMENT.md`). Additionally, the bundle ID in the AASA
(`io.mereka.academy`) does not match the bundle ID in the iOS workflow
(`com.mereka.academy.mobile`).

**Remediation**: Replace `TEAM_ID` with `44F7G2D7U6` and `io.mereka.academy` with
`com.mereka.academy.mobile` so Universal Links function correctly.

### Gap 5: No token-to-mobile pipeline (Low, by design)

Typography, spacing, and other non-color tokens have no mobile delivery path. This is
intentional — native iOS does not consume CSS. However, there is no documentation or
tooling to inform operators which canonical token values should be manually reflected in
`MobileBrandingConfig` records when the Figma design system is updated.

**Remediation**: Add an operator checklist (manual step) to the token update runbook
noting which canonical token values must also be updated in Django admin for the mobile
branding records.

---

## Summary Table

| Check | Status | Gap Severity |
|-------|--------|--------------|
| Token architecture understood | PASS | — |
| Color tokens reach mobile via API | PASS (field exists) | — |
| Model defaults match canonical colors | FAIL | Critical |
| Token refresh endpoint functional | FAIL | High |
| APNs delivery sends actual notifications | FAIL | Medium |
| AASA bundle ID + team ID correct | FAIL | Medium |
| Push app urlconf mount conflict risk | UNVERIFIED (runtime) | Medium |
| Typography tokens — mobile delivery | N/A (by design) | — |
| Spacing tokens — mobile delivery | N/A (by design) | — |

---

## Related Files

| File | Purpose |
|------|---------|
| `assets/branding/tokens.css` | Canonical design tokens (Layer 1) |
| `infrastructure/tutor/custom-apps/openedx_mobile_api/models.py` | Mobile API models (contains defaulting gap) |
| `infrastructure/tutor/custom-apps/openedx_mobile_api/views.py` | Core mobile API views |
| `infrastructure/tutor/custom-apps/openedx_mobile_api/ios_views.py` | iOS-specific views (token refresh stub) |
| `infrastructure/tutor/custom-apps/openedx_mobile_api/ios_release.py` | iOS branding extension model |
| `infrastructure/tutor/custom-apps/openedx_mobile_api/static/.well-known/apple-app-site-association` | AASA file (contains placeholder team ID) |
| `infrastructure/tutor/custom-apps/openedx_push_notifications/models.py` | Push notification device model |
| `docs/reference/architecture/TOKEN_GENERATION_PIPELINE.md` | Token pipeline architecture (T107) |
| `docs/runbooks/operations/MOBILE_DEPLOYMENT.md` | Mobile deployment ops (T032) |
| `specs/proposals/proposals/mobile-apps-enterprise_spec.md` | Full mobile spec (37 ACs) |
