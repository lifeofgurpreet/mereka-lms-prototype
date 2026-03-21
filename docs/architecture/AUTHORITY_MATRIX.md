# Authority Matrix — Mereka LMS Architecture Convergence Program

> **Status**: WS-0 Baseline (Phase A)
> **Owner**: Principal Debt-Eradication Lead
> **Last updated**: 2026-03-11

Every runtime-config family has exactly one owner, a defined precedence chain,
a verification method, and fail-closed semantics. If two repos write the same
surface, one is canonical and the other is explicitly delegated.

---

## 1. Route Ownership

### 1.1 Ingress (NGINX → Service)

| Host Pattern | Environment | Canonical Owner | File | Backend |
|---|---|---|---|---|
| `academyv2.mereka.io` | prod | bbi-infrastructure | `overlays/prod/ingress-*.yaml` | caddy:80 |
| `academyv2.mereka.dev` | dev | bbi-infrastructure | `overlays/dev/patches/ingress.yaml` | caddy:80 |
| `studio.*` | all | bbi-infrastructure (overlay) | per-env ingress | caddy:80 |
| `apps.*` | all | bbi-infrastructure (overlay) | per-env ingress | caddy:80 |
| `admin.*` | all | bbi-infrastructure (overlay) | per-env ingress | enterprise services (direct) |
| `learner.*` | all | bbi-infrastructure (overlay) | per-env ingress | enterprise-learner-portal:8002 |
| `notes.*` | all | bbi-infrastructure (overlay) | per-env ingress | caddy:80 or notes:8000 |
| `credentials.*` | all | bbi-infrastructure (overlay) | per-env ingress | caddy:80 or credentials:8000 |
| `discovery.*` | all | bbi-infrastructure (overlay) | per-env ingress | caddy:80 |

**Verification**: `kubectl get ingress -n mereka-lms-dev -o wide`
**Fail-closed**: Missing ingress → 404 (no traffic reaches backend)

**KNOWN ISSUE**: Notes and Credentials have dual ingress (direct + via Caddy). NGINX
picks one non-deterministically. Fix: consolidate to Caddy-only (WS-3).

### 1.2 Caddy Reverse Proxy (Service → Backend)

| Route | Upstream | Owner | File |
|---|---|---|---|
| `{$LMS_HOST}` → lms:8000 | LMS pod | mereka-lms repo | `base/apps/caddy/Caddyfile` |
| `{$LMS_HOST}/payments/*` → payments-gateway:8080 | Purchase Gateway | mereka-lms repo | `base/apps/caddy/Caddyfile` |
| `{$STUDIO_HOST}` → cms:8000 | CMS pod | mereka-lms repo | `base/apps/caddy/Caddyfile` |
| `{$MFE_HOST}` → mfe:8002 | MFE container | mereka-lms repo | `base/apps/caddy/Caddyfile` |
| `{$MFE_HOST}/api/mfe_config/*` → lms:8000 | LMS (config API) | mereka-lms repo | `base/apps/caddy/Caddyfile` |
| `{$DISCOVERY_HOST}` → discovery:8000 | Discovery | mereka-lms repo | `base/apps/caddy/Caddyfile` |
| `{$NOTES_HOST}` → notes:8000 | Notes | mereka-lms repo | `base/apps/caddy/Caddyfile` |
| `{$CREDENTIALS_HOST}` → credentials:8000 | Credentials | mereka-lms repo | `base/apps/caddy/Caddyfile` |
| `{$ENTERPRISE_ADMIN_HOST}/api/enterprise-catalog/*` → enterprise-catalog:8160 | Catalog API | mereka-lms repo | `base/apps/caddy/Caddyfile` |
| `{$ENTERPRISE_ADMIN_HOST}/api/enterprise-access/*` → enterprise-access:18270 | Access API | mereka-lms repo | `base/apps/caddy/Caddyfile` |
| `{$ENTERPRISE_ADMIN_HOST}/api/license-manager/*` → license-manager:18170 | License API | mereka-lms repo | `base/apps/caddy/Caddyfile` |
| `{$ENTERPRISE_ADMIN_HOST}/api/enterprise-subsidy/*` → enterprise-subsidy:18280 | Subsidy API | mereka-lms repo | `base/apps/caddy/Caddyfile` |
| `{$ENTERPRISE_ADMIN_HOST}` (default) → enterprise-admin-portal:8002 | Admin MFE | mereka-lms repo | `base/apps/caddy/Caddyfile` |
| `{$ENTERPRISE_LEARNER_HOST}` (default) → enterprise-learner-portal:8002 | Learner MFE | mereka-lms repo | `base/apps/caddy/Caddyfile` |

**Verification**: `curl http://localhost:2019/config/` (Caddy admin API from within pod)
**Fail-closed**: Missing route → 502 or Caddy 404

**Caddy domain env vars** are set by:
- **Base**: `base/apps/caddy/deployment.yaml` (defaults to `localhost`)
- **Overlay**: `patches/caddy-env-patch.yaml` (overrides to `*.mereka.dev` or `*.mereka.io`)
- **Owner of env vars**: bbi-infrastructure overlay (delegates base defaults to mereka-lms repo)

### 1.3 MFE Internal Routing

| Route | Handler | Owner |
|---|---|---|
| `/authn/*` → `authn/index.html` | SPA file_server | mereka-lms repo (`base/plugins/mfe/apps/mfe/Caddyfile`) |
| `/learner-dashboard/*` → `learner-dashboard/index.html` | SPA file_server | mereka-lms repo |
| `/learning/*` → `learning/index.html` | SPA file_server | mereka-lms repo |
| `/profile/api/*` → lms:8000 | reverse_proxy | mereka-lms repo |
| `/login_refresh*` → lms:8000 | reverse_proxy | mereka-lms repo |

**Verification**: `curl -s http://mfe:8002/authn/` (from within cluster)

### 1.4 Enterprise MFE Internal Routing

| Portal | Route | Upstream | Owner |
|---|---|---|---|
| Learner | `/api/v1/bffs/*` → enterprise-access:18270 | BFF endpoint | mereka-lms repo (`learner-portal-Caddyfile`) |
| Learner | `/enterprise/*` → lms:8000 | LMS enterprise APIs | mereka-lms repo |
| Admin | `/enterprise/*` → lms:8000 | LMS enterprise APIs | mereka-lms repo |
| Both | `/csrf/*`, `/oauth2/*`, `/login*` → lms:8000 | Auth flows | mereka-lms repo |

**KNOWN ISSUE**: Enterprise portal routes also exist in main Caddy AND in Ingress.
Three layers route the same paths. Fix: single ownership model (WS-3).

---

## 2. Runtime Config Ownership

### 2.1 Django Settings (LMS)

| Setting Family | Canonical Owner | File | Precedence |
|---|---|---|---|
| Core Django (`SECRET_KEY`, `ALLOWED_HOSTS`) | mereka-lms repo | `base/apps/openedx/settings/lms/production.py` | Settings file → env var override |
| CSP directives | mereka-lms repo | `infrastructure/tutor/plugins/_mereka_lms/lms_settings.py` | Tutor plugin → rendered into production.py |
| Cookie domain/security | mereka-lms repo | `lms_settings.py` + `config_defaults.py` | Tutor defaults → env var override |
| MFE_CONFIG (API) | mereka-lms repo | `lms_settings.py` (lines 657-796) | Settings file |
| OIDC endpoint | **bbi-infrastructure** | `overlays/dev/patches/production-staging.py` | Overlay patch OVERRIDES repo settings |
| Multi-tenant domains | mereka-lms repo | `production.py` (PILOT_TENANT_DOMAINS) | Env var |
| Feature flags | mereka-lms repo | `lms.env.yml` FEATURES dict | Settings file |

**Verification**: `kubectl exec deployment/lms -- python -c "from django.conf import settings; print(settings.ALLOWED_HOSTS)"`
**Fail-closed**: Missing ALLOWED_HOSTS → Django 400 Bad Request

### 2.2 Django Settings (CMS/Studio)

| Setting Family | Canonical Owner | File |
|---|---|---|
| SESSION_COOKIE_NAME | mereka-lms repo | `base/apps/openedx/settings/cms/production.py` |
| SESSION_COOKIE_SAMESITE | mereka-lms repo | `cms/production.py` |
| OAuth2 client config | mereka-lms repo | `cms/production.py` |
| OIDC endpoint | **bbi-infrastructure** | `overlays/dev/patches/production-cms-staging.py` |

### 2.3 ConfigMaps

| ConfigMap | Generator Owner | Behavior | Hash Suffix |
|---|---|---|---|
| `openedx-settings-lms` | mereka-lms repo (base) | create | yes |
| `openedx-settings-lms-patched` | bbi-infrastructure (overlay) | create | disabled |
| `openedx-settings-cms` | mereka-lms repo (base) | create | yes |
| `openedx-settings-cms-patched` | bbi-infrastructure (overlay) | create | disabled |
| `openedx-config` | mereka-lms repo (base) | create | yes |
| `openedx-config-staging` | bbi-infrastructure (overlay) | create | disabled |
| `caddy-config` | mereka-lms repo (base) | create | yes |
| `caddy-config-staging` | bbi-infrastructure (overlay) | create | disabled |
| `enterprise-mfe-env` | bbi-infrastructure (overlay) | **replace** | disabled |
| `mfe-caddy-config` | mereka-lms repo (base) | create | yes |

**Precedence rule**: Overlay `behavior: replace` wins over base. Overlay
`configMapGenerator` with same name replaces base entirely.

**KNOWN ISSUE**: `disableNameSuffixHash: true` on overlay ConfigMaps means pod template
changes don't trigger rollouts. Manual restart needed after config changes.

### 2.4 Enterprise Service Config-Gen

| Service | Config File | Owner | LMS_ROOT_URL Owner |
|---|---|---|---|
| enterprise-catalog | `/config/enterprise_catalog.yml` | mereka-lms repo (base deployment) | bbi-infrastructure (overlay patch) |
| enterprise-subsidy | `/config/enterprise_subsidy.yml` | mereka-lms repo (base deployment) | bbi-infrastructure (overlay patch) |
| license-manager | `/config/license_manager.yml` | mereka-lms repo (base deployment) | bbi-infrastructure (overlay patch) |
| enterprise-access | `/config/enterprise_access.yml` | mereka-lms repo (base deployment) | bbi-infrastructure (overlay patch) |

**Pattern**: Base deployment has init container with Python config-gen.
Overlay patches env vars (especially `LMS_ROOT_URL`). Config-gen runs at pod
startup and renders env vars into YAML.

**Verification**: `kubectl exec deployment/<service> -- cat /config/<service>.yml | grep JWT_ISSUER`
**Fail-closed**: Missing `LMS_ROOT_URL` → JWT issuer defaults to `http://localhost/oauth2` → all JWT auth fails

---

## 3. Auth / Session / JWT Ownership

### 3.1 JWT Signing

| Component | Owner | File | Notes |
|---|---|---|---|
| `JWT_PRIVATE_SIGNING_JWK` | Infisical (source) → ESO → K8s Secret | `external-secrets.yaml` | RSA JWK with ALL CRT params |
| `JWT_PUBLIC_SIGNING_JWK_SET` | mereka-lms repo (derived at startup) | `lms/production.py` | NEVER hardcode — derive from private key |
| `JWT_SECRET_KEY_LMS` | Infisical → K8s Secret | `external-secrets.yaml` | HS256 fallback |
| Satellite JWT_AUTH | mereka-lms repo (base) + bbi-infrastructure (overlay) | deployment YAML + patch | Config-gen derives public JWK from private key |

**Verification**: `kubectl exec deployment/lms -- python -c "from django.conf import settings; print(settings.JWT_AUTH['JWT_PUBLIC_SIGNING_JWK_SET'][:50])"`
**Fail-closed**: Mismatched public/private JWK → all JWT signature verification fails → all enterprise API calls return 401

### 3.2 Session Cookies

| Setting | LMS Value | CMS Value | Owner |
|---|---|---|---|
| `SESSION_COOKIE_NAME` | `sessionid` (default) | `studio_session_id` | mereka-lms repo |
| `SESSION_COOKIE_DOMAIN` | host-only (None) or `.academyv2.mereka.dev` | None (host-only) | mereka-lms repo |
| `SESSION_COOKIE_SAMESITE` | `Lax` | `None` | mereka-lms repo |
| `SESSION_COOKIE_SECURE` | `True` | `True` | mereka-lms repo |
| `CSRF_COOKIE_DOMAIN` | `.academyv2.mereka.dev` | (default) | mereka-lms repo |

**KNOWN ISSUE (cookie-domain-staging.md)**: `staging.apps.X` is NOT a subdomain of
`staging.X`. Cookie domain must be broadened for cross-subdomain auth.

### 3.3 OAuth2 Clients

| Service | Client Key | Secret Source | Auth Type | Owner |
|---|---|---|---|---|
| CMS → LMS | `cms-key` | `CMS_SOCIAL_AUTH_EDX_OAUTH2_SECRET` | User SSO | mereka-lms repo |
| Discovery → LMS | `discovery-key` | `DISCOVERY_BACKEND_OAUTH2_SECRET` | Service-to-service | mereka-lms repo |
| Credentials → LMS | `credentials-key` | `CREDENTIALS_BACKEND_OAUTH2_SECRET` | Service-to-service | mereka-lms repo |
| Enterprise-catalog → LMS | `enterprise-catalog-key` | `ENTERPRISE_CATALOG_OAUTH2_SECRET` | Service-to-service | mereka-lms repo |
| Enterprise-access → LMS | `enterprise-access-key` | `ENTERPRISE_ACCESS_OAUTH2_SECRET` | Service-to-service | mereka-lms repo |
| Enterprise-subsidy → LMS | `enterprise-subsidy-key` | `ENTERPRISE_SUBSIDY_OAUTH2_SECRET` | Service-to-service | mereka-lms repo |
| License-manager → LMS | `license-manager-key` | `LICENSE_MANAGER_OAUTH2_SECRET` | Service-to-service | mereka-lms repo |

**Internal URL**: `SOCIAL_AUTH_EDX_OAUTH2_URL_ROOT = http://lms:8000` (pod-to-pod)
**Public URL**: `SOCIAL_AUTH_EDX_OAUTH2_PUBLIC_URL_ROOT = https://academyv2.mereka.dev` (browser)

### 3.4 OIDC (Authentik)

| Setting | Owner | Notes |
|---|---|---|
| `SOCIAL_AUTH_OIDC_OIDC_ENDPOINT` | **bbi-infrastructure** | Authentik provider URL |
| `SOCIAL_AUTH_OIDC_KEY` | **bbi-infrastructure** | OIDC client ID |
| `OIDC_CLIENT_SECRET` | Infisical → K8s Secret | Shared secret |
| `THIRD_PARTY_AUTH_BACKENDS` | mereka-lms repo | Auth backend list |

**CRITICAL**: OIDC endpoint is NOT in mereka-lms repo. Editing it here has no effect —
bbi-infrastructure overlay patches override it.

---

## 4. Enterprise Service Ownership

### 4.1 Backend Services

| Service | Image Owner | Config Owner | Env Overlay Owner | Port |
|---|---|---|---|---|
| enterprise-catalog | mereka-lms repo (GHCR) | mereka-lms repo (base) | bbi-infrastructure (overlay) | 8160 |
| enterprise-subsidy | mereka-lms repo (GHCR) | mereka-lms repo (base) | bbi-infrastructure (overlay) | 18280 |
| enterprise-access | mereka-lms repo (GHCR) | mereka-lms repo (base) | bbi-infrastructure (overlay) | 18270 |
| license-manager | mereka-lms repo (GHCR) | mereka-lms repo (base) | bbi-infrastructure (overlay) | 18170 |
| enterprise-catalog-worker | mereka-lms repo (GHCR) | mereka-lms repo (base) | bbi-infrastructure (overlay) | n/a |
| enterprise-access-worker | mereka-lms repo (GHCR) | mereka-lms repo (base) | bbi-infrastructure (overlay) | n/a |

### 4.2 Enterprise MFEs

| Service | Image Owner | Config Owner | Theme Owner | Port |
|---|---|---|---|---|
| enterprise-admin-portal | mereka-lms repo (GHCR) | bbi-infrastructure (configMapGenerator replace) | mereka-lms repo (PARAGON_THEME in env.config.js) | 8002 |
| enterprise-learner-portal | mereka-lms repo (GHCR) | bbi-infrastructure (configMapGenerator replace) | mereka-lms repo (PARAGON_THEME in env.config.js) | 8002 |

**MFE config delivery**:
- Static: `enterprise-mfe-env` ConfigMap mounted as `/openedx/dist/env.config.js`
- Dynamic (per-tenant): `mfe_config_api` via LMS `SiteConfiguration.site_values["MFE_CONFIG"]`

---

## 5. Secret / Store Ownership

### 5.1 Secret Stores

| Store | Environment | Owner |
|---|---|---|
| `gcp-secret-manager` | prod | bbi-infrastructure (ClusterSecretStore) |
| `infisical-secret-store-dev` | dev | bbi-infrastructure (ClusterSecretStore) |
| `infisical-secret-store-staging` | staging | bbi-infrastructure (ClusterSecretStore) |

### 5.2 ExternalSecrets

| ExternalSecret | Keys | Owner | Store Override |
|---|---|---|---|
| `openedx-secrets` | ~50 keys (JWT, OAuth2, MongoDB, SMTP, Sentry) | mereka-lms repo (base) | bbi-infrastructure overlay patches store name |
| `database-secrets` | MySQL root + service passwords | mereka-lms repo (base) | bbi-infrastructure overlay patches store name |
| `enterprise-secrets` | 15 keys (per-service secrets, OAuth2, DB passwords) | mereka-lms repo (base) | bbi-infrastructure overlay patches store name |
| `enterprise-sso-secrets` | SAML cert/key, SCIM token, OIDC secret | mereka-lms repo (base) | bbi-infrastructure overlay patches store name |
| `payments-gateway-secrets` | Stripe keys, DB URL | mereka-lms repo (base) | bbi-infrastructure overlay patches store name |
| `aspects-secrets` | ClickHouse, Superset, OAuth | mereka-lms repo (base) | bbi-infrastructure overlay patches store name |
| `ses-smtp-credentials` | SMTP username/password | mereka-lms repo (base) | bbi-infrastructure overlay patches store name |
| `ghcr-registry-secret` | Container registry auth | bbi-infrastructure (overlay only) | n/a |
| `google-oauth-secret` | Google OAuth2 credentials | bbi-infrastructure (overlay only) | n/a |

**Precedence**: Base defines ExternalSecret structure + key mappings.
Overlay patches `spec.secretStoreRef.name` to point at correct store.

**Fail-closed**: Missing secret → pod fails to start (env var not found) or
service fails at first API call (invalid credentials).

---

## 6. Deployment Authority

### 6.1 Image Tag Pinning

| Component | Pin Location | Owner | Update Method |
|---|---|---|---|
| openedx (LMS/CMS) | bbi-infrastructure overlay `images:` | bbi-infrastructure | ArgoCD Image Updater (SHA-based) |
| mfe | bbi-infrastructure overlay `images:` | bbi-infrastructure | ArgoCD Image Updater |
| caddy | bbi-infrastructure overlay `images:` | bbi-infrastructure | Manual (pinned 2.7.4) |
| enterprise-access | bbi-infrastructure overlay `images:` | bbi-infrastructure | Manual |
| enterprise-catalog | bbi-infrastructure overlay `images:` | bbi-infrastructure | Manual (frozen 21.0.0) |
| enterprise-subsidy | bbi-infrastructure overlay `images:` | bbi-infrastructure | Manual (frozen 21.0.0) |
| license-manager | bbi-infrastructure overlay `images:` | bbi-infrastructure | Manual (frozen 21.0.0) |
| enterprise-admin-portal | bbi-infrastructure overlay `images:` | bbi-infrastructure | Manual |
| enterprise-learner-portal | bbi-infrastructure overlay `images:` | bbi-infrastructure | Manual |
| payments-gateway | bbi-infrastructure overlay `images:` | bbi-infrastructure | Manual |

### 6.2 ArgoCD Application

| App | Source Path | Repo | Namespace | Auto-sync |
|---|---|---|---|---|
| `mereka-lms-dev` | `apps/mereka-lms/overlays/profiles/dev` | bbi-infrastructure | `mereka-lms-dev` | yes |

**Kustomize render chain**:
```
bbi-infrastructure/apps/mereka-lms/overlays/profiles/dev/kustomization.yaml
  → ../../dev/kustomization.yaml
    → ../../base/kustomization.yaml
      → mereka-lms repo (git submodule or copied base)
```

---

## 7. Proof Authority

### 7.1 Verification Scripts

| Domain | Owner | Location | CI Integration |
|---|---|---|---|
| Security hardening | mereka-lms repo | `scripts/qa/verify-security-hardening.sh` | `.github/ci-scripts-static.txt` |
| CSP directives | mereka-lms repo | `scripts/qa/verify-csp-*.sh` | `.github/ci-scripts-static.txt` |
| Service health | mereka-lms repo | `scripts/qa/verify-service-health.sh` | `.github/ci-scripts-static.txt` |
| Enterprise services | mereka-lms repo | `scripts/qa/verify-enterprise-*.sh` | `.github/ci-scripts-static.txt` |
| Spec coverage | mereka-lms repo | `scripts/qa/spec-tools/` | CI `check` target |
| K8s manifest rendering | bbi-infrastructure | `scripts/verify-*.sh` | bbi-infrastructure CI |

### 7.2 Spec Coverage

| Spec | ACs | Status | Owner |
|---|---|---|---|
| 38 specs | 990 ACs | 835 automated, 155 manual | mereka-lms repo |

---

## 8. Debt Inventory (Convergence Targets)

### 8.1 Route Duplication (WS-3)

| Surface | Issue | Fix |
|---|---|---|
| Notes ingress | Direct + Caddy (dual path) | Remove direct ingress |
| Credentials ingress | Direct + Caddy (dual path); direct path misses authn routing + landing page | Remove direct ingress |
| Enterprise admin API | Ingress direct + Main Caddy (triple path); direct path misses `uri strip_prefix` | Remove direct ingress, keep Caddy |
| Enterprise learner API | Ingress direct + Caddy (dual path) | Remove direct ingress |

**Canonical path**: All traffic through main ingress → Caddy → backend services.
**Redundant files** (per overlay): `ingress-notes.yaml`, `ingress-credentials.yaml`,
`ingress-enterprise-admin.yaml`, `ingress-enterprise-learner.yaml`.
These are boundary.debt — owned by bbi-infrastructure overlays. Coordinate removal there.

**Key defect in direct path**: Enterprise admin API direct ingress does NOT strip
`/api/enterprise-catalog` prefix before routing to catalog service (Caddy does).
This causes incorrect backend routing on the direct path.

### 8.2 Config Duplication (WS-1)

| Surface | Issue | Fix |
|---|---|---|
| JWT_PUBLIC_SIGNING_JWK_SET | Was hardcoded, now derived | Fixed (PR #1550, verified) |
| LMS_ROOT_URL defaults | Base has `http://localhost`, overlay overrides | Working as designed (kustomize pattern) |
| OIDC settings | Not in mereka-lms repo (intentional) | Documented ownership split |

### 8.3 Enterprise Service Debt (WS-5)

| Issue | Impact | Fix |
|---|---|---|
| Upstream archived (Nov 2024) | No security patches | Fork maintenance or replacement |
| Frozen at 21.0.0 | Can't upgrade | Accept or fork |
| Config-gen inline Python | Hard to test, duplicated across 6 deployments | Extract to shared script/image |
| `disableNameSuffixHash` | Config changes don't trigger rollouts | Add rollout annotation or use hash |

### 8.4 Staging MFE Ingress (WS-3)

| Issue | Impact | Fix |
|---|---|---|
| Direct path splits to LMS | 504 on hostNetwork nodes | Route all through Caddy |

---

## 9. Freeze Manifest

The following surfaces are **frozen** — no changes without convergence program review:

1. **JWT_PRIVATE_SIGNING_JWK** — single platform-wide key, recently fixed
2. **OIDC provider endpoint** — owned by bbi-infrastructure, not touchable from this repo
3. **Enterprise service versions** — frozen at 21.0.0 until WS-5
4. **Cookie domain strategy** — host-only for multi-tenant, documented in cookie-domain-staging.md
5. **Ingress → Caddy routing pattern** — all traffic through Caddy (production pattern is canonical)
