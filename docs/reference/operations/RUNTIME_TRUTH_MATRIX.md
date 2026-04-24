# Runtime Truth Matrix — Mereka LMS

_Generated from config/source truth (not live probing) • 2026-04-04_
_Canonical host intent source: `deploy/k8s/tenancy/tenant-registry.yaml` v1.5.0_

---

## 1. Summary

| Metric | Count |
|--------|-------|
| **Tenants** | 3 (Mereka Academy, Biji-Biji Academy, Skill Our Future) |
| **Environments** | 5 (production, dev, profiles-dev, staging, local) |
| **Total declared domains** | 85 |
| **Production domains** | 27 (13 Mereka, 8 Biji-Biji, 6 Skill Our Future) |
| **Dev domains** | 24 (12 Mereka, 8 Biji-Biji, 8 SOF, + profiles-dev aliases) |
| **Profiles-dev domains** | 9 (Mereka only) |
| **Staging domains** | 25 (12 Mereka, 8 Biji-Biji, 5+5 SOF legacy+target) |
| **Distinct host roles** | 14 (primary, studio, mfe, preview, discovery, notes, credentials, forum, enterprise-admin, enterprise-learner, analytics, ecommerce, payments, auth) |
| **Distinct backend services** | 12 (lms, cms, mfe, discovery, notes, credentials, enterprise-admin-portal, enterprise-learner-portal, enterprise-catalog, enterprise-access, enterprise-subsidy, license-manager, superset, payments-gateway) |
| **Release-critical (P0) domains** | 15 |
| **Domains with Ingress TLS** | ~38 |
| **Domains WITHOUT Ingress TLS** | ~47 |

---

## 2. Full Runtime Truth Matrix

### 2.1 PRODUCTION — Mereka Academy (primary tenant)

| Host | Role | Backend Service | Caddy Backend | TLS (Ingress) | DNS Record | Status | Proof Priority | Auth Class | Owner Layer | Config Source |
|------|------|----------------|---------------|----------------|------------|--------|----------------|------------|-------------|---------------|
| `academyv2.mereka.io` | primary | caddy → lms:8000 | lms:8000 | ✅ cert-manager | A → 34.177.83.168 | active | **P0** | DIRECT_AUTH | app | tenant-registry.yaml, ingress-openedx-lms.yaml, records.json |
| `studio.academyv2.mereka.io` | studio | caddy → cms:8000 | cms:8000 | ✅ cert-manager | CNAME → academyv2.mereka.io | active | **P0** | DIRECT_AUTH | app | tenant-registry.yaml, ingress-openedx-studio.yaml |
| `apps.academyv2.mereka.io` | mfe | caddy → mfe:8002 | mfe:8002 | ✅ cert-manager | CNAME → academyv2.mereka.io | active | **P0** | REDIRECT_TARGET | app | tenant-registry.yaml, ingress-openedx-mfe.yaml |
| `preview.academyv2.mereka.io` | preview | caddy → lms:8000 | lms:8000 | ✅ cert-manager | CNAME → academyv2.mereka.io | active | P1 | AUTH_TRANSPARENT | app | tenant-registry.yaml, ingress-openedx-lms.yaml |
| `discovery.academyv2.mereka.io` | discovery | caddy → discovery:8000 | discovery:8000 | ✅ cert-manager | CNAME → academyv2.mereka.io | active | **P0** | DIRECT_AUTH | app | tenant-registry.yaml, ingress-openedx-lms.yaml |
| `notes.academyv2.mereka.io` | notes | notes:8000 (direct) | notes:8000 | ✅ cert-manager | CNAME → academyv2.mereka.io | active | P1 | AUTH_TRANSPARENT | app | tenant-registry.yaml, ingress-notes.yaml |
| `credentials.academyv2.mereka.io` | credentials | credentials:8000 (direct) | credentials:8000 | ✅ cert-manager | CNAME → academyv2.mereka.io | active | P1 | DIRECT_AUTH | app | tenant-registry.yaml, ingress-credentials.yaml |
| `forum.academyv2.mereka.io` | forum | caddy → lms:8000 | lms:8000 | ✅ cert-manager | CNAME → academyv2.mereka.io | active | P1 | AUTH_TRANSPARENT | app | tenant-registry.yaml, ingress-openedx-lms.yaml |
| `admin.academyv2.mereka.io` | enterprise-admin | caddy → enterprise-admin-portal:8002 | enterprise-admin-portal:8002 | ✅ cert-manager | CNAME → academyv2.mereka.io | active | P1 | CORS_ORIGIN | app | tenant-registry.yaml, ingress-enterprise-admin.yaml |
| `learner.academyv2.mereka.io` | enterprise-learner | caddy → enterprise-learner-portal:8002 | enterprise-learner-portal:8002 | ✅ cert-manager | CNAME → academyv2.mereka.io | active | P2 | AUTH_TRANSPARENT | app | tenant-registry.yaml, ingress-enterprise-learner.yaml |
| `ecommerce.academyv2.mereka.io` | ecommerce | caddy → ecommerce:8000 | ecommerce:8000 | ⚠️ (no Caddyfile block) | CNAME → academyv2.mereka.io | **deprecated** | P2 | DIRECT_AUTH | app | tenant-registry.yaml (deprecated) |
| `analytics.academyv2.mereka.io` | analytics | caddy → superset:8088 | superset:8088 | ⚠️ (no Caddyfile/Ingress) | CNAME → academyv2.mereka.io | active | P1 | DIRECT_AUTH | app | tenant-registry.yaml |
| `auth0.mereka.io` | auth | external (Authentik) | N/A | ❌ external | N/A (bbi-infra) | active | **P0** | OIDC_PROVIDER | infra/platform | tenant-registry.yaml |

### 2.2 PRODUCTION — Biji-Biji Academy (tenant)

| Host | Role | Backend Service | Caddy Backend | TLS (Ingress) | DNS Record | Status | Proof Priority | Auth Class | Owner Layer | Config Source |
|------|------|----------------|---------------|----------------|------------|--------|----------------|------------|-------------|---------------|
| `academy.biji-biji.com` | primary | caddy → lms:8000 | lms:8000 | ✅ cert-manager | CNAME → academyv2.mereka.io (proxied) | active | **P0** | DIRECT_AUTH | app | tenant-registry.yaml, ingress-openedx-lms.yaml, records.biji-biji.com.json |
| `studio.academy.biji-biji.com` | studio | caddy → cms:8000 | cms:8000 | ✅ cert-manager | CNAME → academy.biji-biji.com | active | **P0** | DIRECT_AUTH | app | tenant-registry.yaml, ingress-openedx-studio.yaml |
| `apps.academy.biji-biji.com` | mfe | caddy → mfe:8002 | mfe:8002 | ✅ cert-manager | CNAME → academy.biji-biji.com | active | **P0** | REDIRECT_TARGET | app | tenant-registry.yaml, ingress-openedx-mfe.yaml |
| `preview.academy.biji-biji.com` | preview | caddy → lms:8000 | lms:8000 | ❌ no TLS | CNAME → academyv2.mereka.io | active | P2 | AUTH_TRANSPARENT | app | tenant-registry.yaml, records.biji-biji.com.json |
| `admin.academy.biji-biji.com` | enterprise-admin | caddy → enterprise-admin-portal:8002 | enterprise-admin-portal:8002 | ❌ no TLS | CNAME → academyv2.mereka.io | active | P2 | CORS_ORIGIN | app | tenant-registry.yaml, records.biji-biji.com.json |
| `learner.academy.biji-biji.com` | enterprise-learner | caddy → enterprise-learner-portal:8002 | enterprise-learner-portal:8002 | ❌ no TLS | CNAME → academyv2.mereka.io | active | P2 | AUTH_TRANSPARENT | app | tenant-registry.yaml, records.biji-biji.com.json |
| `credentials.academy.biji-biji.com` | credentials | caddy → credentials:8000 | credentials:8000 | ❌ no TLS | CNAME → academyv2.mereka.io | active | P2 | DIRECT_AUTH | app | tenant-registry.yaml, records.biji-biji.com.json |
| `analytics.academy.biji-biji.com` | analytics | caddy → superset:8088 | superset:8088 | ❌ no TLS | CNAME → academyv2.mereka.io | active | P2 | DIRECT_AUTH | app | tenant-registry.yaml, records.biji-biji.com.json |

### 2.3 PRODUCTION — Skill Our Future (tenant)

| Host | Role | Backend Service | Caddy Backend | TLS (Ingress) | DNS Record | Status | Proof Priority | Auth Class | Owner Layer | Config Source |
|------|------|----------------|---------------|----------------|------------|--------|----------------|------------|-------------|---------------|
| `skillourfuture.academy.mereka.io` | primary | caddy → lms:8000 | lms:8000 | ✅ cert-manager | CNAME → academyv2.mereka.io | active | **P0** | DIRECT_AUTH | app | tenant-registry.yaml, ingress-openedx-lms.yaml |
| `skillourfuture.academyv2.mereka.io` | primary (migration target) | caddy → lms:8000 | lms:8000 | ❌ no TLS | ❌ no DNS | active | P1 | DIRECT_AUTH | app | tenant-registry.yaml |
| `studio.skillourfuture.academy.mereka.io` | studio (legacy) | caddy → cms:8000 | cms:8000 | ❌ no TLS | ❌ no DNS | **deprecated** | P2 | DIRECT_AUTH | app | tenant-registry.yaml, multisite-sites.yml |
| `studio.skillourfuture.academyv2.mereka.io` | studio (target) | caddy → cms:8000 | cms:8000 | ❌ no TLS | ❌ no DNS | active | P2 | DIRECT_AUTH | app | tenant-registry.yaml |
| `apps.skillourfuture.academy.mereka.io` | mfe (legacy) | caddy → mfe:8002 | mfe:8002 | ❌ no TLS | ❌ no DNS | **deprecated** | P2 | REDIRECT_TARGET | app | tenant-registry.yaml |
| `apps.skillourfuture.academyv2.mereka.io` | mfe (target) | caddy → mfe:8002 | mfe:8002 | ❌ no TLS | ❌ no DNS | active | P2 | REDIRECT_TARGET | app | tenant-registry.yaml |
| `preview.skillourfuture.academyv2.mereka.io` | preview | caddy → lms:8000 | lms:8000 | ❌ no TLS | CNAME → academyv2.mereka.io | active | P2 | AUTH_TRANSPARENT | app | tenant-registry.yaml, records.json |
| `admin.skillourfuture.academyv2.mereka.io` | enterprise-admin | caddy → enterprise-admin-portal:8002 | enterprise-admin-portal:8002 | ❌ no TLS | CNAME → academyv2.mereka.io | active | P2 | CORS_ORIGIN | app | tenant-registry.yaml, records.json |
| `learner.skillourfuture.academyv2.mereka.io` | enterprise-learner | caddy → enterprise-learner-portal:8002 | enterprise-learner-portal:8002 | ❌ no TLS | CNAME → academyv2.mereka.io | active | P2 | AUTH_TRANSPARENT | app | tenant-registry.yaml, records.json |
| `credentials.skillourfuture.academyv2.mereka.io` | credentials | caddy → credentials:8000 | credentials:8000 | ❌ no TLS | CNAME → academyv2.mereka.io | active | P2 | DIRECT_AUTH | app | tenant-registry.yaml, records.json |
| `analytics.skillourfuture.academyv2.mereka.io` | analytics | caddy → superset:8088 | superset:8088 | ❌ no TLS | CNAME → academyv2.mereka.io | active | P2 | DIRECT_AUTH | app | tenant-registry.yaml, records.json |

### 2.4 DEV — Mereka Academy (rke2-nonprod, `*.mereka.dev`)

| Host | Role | Backend Service | TLS (Ingress) | DNS Record | Status | Proof Priority | Config Source |
|------|------|----------------|----------------|------------|--------|----------------|---------------|
| `academyv2.mereka.dev` | primary | caddy → lms:8000 | ✅ cert-manager | A → 194.233.84.55 | active | P1 | ingress-openedx-lms.yaml, records.mereka-dev.json |
| `studio.academyv2.mereka.dev` | studio | caddy → cms:8000 | ✅ cert-manager | CNAME → academyv2.mereka.dev | active | P1 | ingress-openedx-studio.yaml |
| `apps.academyv2.mereka.dev` | mfe | caddy → mfe:8002 | ✅ cert-manager | CNAME → academyv2.mereka.dev | active | P1 | ingress-openedx-mfe.yaml |
| `preview.academyv2.mereka.dev` | preview | caddy → lms:8000 | ✅ cert-manager | CNAME → academyv2.mereka.dev | active | P2 | ingress-openedx-lms.yaml |
| `discovery.academyv2.mereka.dev` | discovery | caddy → discovery:8000 | ✅ cert-manager | CNAME → academyv2.mereka.dev | active | P1 | ingress-openedx-lms.yaml |
| `notes.academyv2.mereka.dev` | notes | notes:8000 (direct) | ✅ cert-manager | CNAME → academyv2.mereka.dev | active | P2 | ingress-notes.yaml |
| `credentials.academyv2.mereka.dev` | credentials | credentials:8000 (direct) | ✅ cert-manager | CNAME → academyv2.mereka.dev | active | P2 | ingress-credentials.yaml |
| `forum.academyv2.mereka.dev` | forum | caddy → lms:8000 | ✅ cert-manager | CNAME → academyv2.mereka.dev | active | P2 | ingress-openedx-lms.yaml |
| `admin.academyv2.mereka.dev` | enterprise-admin | enterprise-admin-portal:8002 | ✅ cert-manager | ❌ no DNS | active | P2 | ingress-enterprise-admin.yaml, domain-env.yaml |
| `learner.academyv2.mereka.dev` | enterprise-learner | enterprise-learner-portal:8002 | ✅ cert-manager | ❌ no DNS | active | P2 | ingress-enterprise-learner.yaml, domain-env.yaml |
| `auth0.mereka.dev` | auth | external (Authentik) | ❌ external | N/A (bbi-infra) | active | P1 | domain-env.yaml |
| `analytics.academyv2.mereka.dev` | analytics | caddy → superset:8088 | ⚠️ | CNAME → academyv2.mereka.dev | active | P2 | tenant-registry.yaml |

### 2.5 DEV — Biji-Biji Academy (tenant, `*.biji-biji.academyv2.mereka.dev`)

| Host | Role | Backend Service | TLS (Ingress) | DNS Record | Status | Proof Priority | Config Source |
|------|------|----------------|----------------|------------|--------|----------------|---------------|
| `biji-biji.academyv2.mereka.dev` | primary | caddy → lms:8000 | ✅ | ❌ no DNS | active | P1 | tenant-registry.yaml |
| `studio.biji-biji.academyv2.mereka.dev` | studio | caddy → cms:8000 | ✅ | ❌ no DNS | active | P1 | tenant-registry.yaml |
| `apps.biji-biji.academyv2.mereka.dev` | mfe | caddy → mfe:8002 | ✅ | ❌ no DNS | active | P1 | tenant-registry.yaml |
| `preview.biji-biji.academyv2.mereka.dev` | preview | caddy → lms:8000 | ❌ | CNAME → academyv2.mereka.dev | active | P2 | tenant-registry.yaml, records.mereka-dev.json |
| `admin.biji-biji.academyv2.mereka.dev` | enterprise-admin | enterprise-admin-portal:8002 | ❌ | CNAME → academyv2.mereka.dev | active | P2 | tenant-registry.yaml, records.mereka-dev.json |
| `learner.biji-biji.academyv2.mereka.dev` | enterprise-learner | enterprise-learner-portal:8002 | ❌ | CNAME → academyv2.mereka.dev | active | P2 | tenant-registry.yaml, records.mereka-dev.json |
| `credentials.biji-biji.academyv2.mereka.dev` | credentials | credentials:8000 | ❌ | CNAME → academyv2.mereka.dev | active | P2 | tenant-registry.yaml, records.mereka-dev.json |
| `analytics.biji-biji.academyv2.mereka.dev` | analytics | superset:8088 | ❌ | CNAME → academyv2.mereka.dev | active | P2 | tenant-registry.yaml, records.mereka-dev.json |

### 2.6 DEV — Skill Our Future (tenant, `*.skillourfuture.academyv2.mereka.dev`)

| Host | Role | Backend Service | TLS (Ingress) | DNS Record | Status | Proof Priority | Config Source |
|------|------|----------------|----------------|------------|--------|----------------|---------------|
| `skillourfuture.academyv2.mereka.dev` | primary | caddy → lms:8000 | ✅ | ❌ no DNS | active | P1 | tenant-registry.yaml |
| `studio.skillourfuture.academyv2.mereka.dev` | studio | caddy → cms:8000 | ✅ | ❌ no DNS | active | P1 | tenant-registry.yaml |
| `apps.skillourfuture.academyv2.mereka.dev` | mfe | caddy → mfe:8002 | ✅ | ❌ no DNS | active | P1 | tenant-registry.yaml |
| `preview.skillourfuture.academyv2.mereka.dev` | preview | caddy → lms:8000 | ❌ | CNAME → academyv2.mereka.dev | active | P2 | tenant-registry.yaml, records.mereka-dev.json |
| `admin.skillourfuture.academyv2.mereka.dev` | enterprise-admin | enterprise-admin-portal:8002 | ❌ | CNAME → academyv2.mereka.dev | active | P2 | tenant-registry.yaml, records.mereka-dev.json |
| `learner.skillourfuture.academyv2.mereka.dev` | enterprise-learner | enterprise-learner-portal:8002 | ❌ | CNAME → academyv2.mereka.dev | active | P2 | tenant-registry.yaml, records.mereka-dev.json |
| `credentials.skillourfuture.academyv2.mereka.dev` | credentials | credentials:8000 | ❌ | CNAME → academyv2.mereka.dev | active | P2 | tenant-registry.yaml, records.mereka-dev.json |
| `analytics.skillourfuture.academyv2.mereka.dev` | analytics | superset:8088 | ❌ | CNAME → academyv2.mereka.dev | active | P2 | tenant-registry.yaml, records.mereka-dev.json |

### 2.7 PROFILES-DEV — Mereka Academy (`*-dev.mereka.dev`)

| Host | Role | Backend Service | TLS (Ingress) | DNS | Status | Proof Priority | Config Source |
|------|------|----------------|----------------|-----|--------|----------------|---------------|
| `lms-dev.mereka.dev` | primary | caddy → lms:8000 | ✅ | N/A | active | P1 | tenant-registry.yaml |
| `studio-dev.mereka.dev` | studio | caddy → cms:8000 | ✅ | N/A | active | P1 | tenant-registry.yaml |
| `mfe-dev.mereka.dev` | mfe | caddy → mfe:8002 | ✅ | N/A | active | P1 | tenant-registry.yaml |
| `preview-dev.mereka.dev` | preview | caddy → lms:8000 | ✅ | N/A | active | P2 | tenant-registry.yaml |
| `discovery-dev.mereka.dev` | discovery | caddy → discovery:8000 | ✅ | N/A | active | P2 | tenant-registry.yaml |
| `notes-dev.mereka.dev` | notes | caddy → notes:8000 | ✅ | N/A | active | P2 | tenant-registry.yaml |
| `credentials-dev.mereka.dev` | credentials | caddy → credentials:8000 | ✅ | N/A | active | P2 | tenant-registry.yaml |
| `admin-dev.mereka.dev` | enterprise-admin | enterprise-admin-portal:8002 | ✅ | N/A | active | P2 | tenant-registry.yaml |
| `learner-dev.mereka.dev` | enterprise-learner | enterprise-learner-portal:8002 | ✅ | N/A | active | P2 | tenant-registry.yaml |

### 2.8 STAGING — Mereka Academy (`staging.*.academyv2.mereka.io`)

| Host | Role | Backend Service | TLS (Ingress) | DNS | Status | Proof Priority | Config Source |
|------|------|----------------|----------------|-----|--------|----------------|---------------|
| `staging.academyv2.mereka.io` | primary | caddy → lms:8000 | ✅ cert-manager | ⚠️ needs DNS | active | **P0** | ingress-openedx-lms.yaml, domain-env.yaml |
| `staging.studio.academyv2.mereka.io` | studio | caddy → cms:8000 | ✅ cert-manager | ⚠️ needs DNS | active | **P0** | ingress-openedx-studio.yaml |
| `staging.apps.academyv2.mereka.io` | mfe | caddy → mfe:8002 | ✅ cert-manager | ⚠️ needs DNS | active | **P0** | ingress-openedx-mfe.yaml |
| `staging.preview.academyv2.mereka.io` | preview | caddy → lms:8000 | ✅ cert-manager | ⚠️ needs DNS | active | P1 | ingress-openedx-lms.yaml |
| `staging.discovery.academyv2.mereka.io` | discovery | caddy → discovery:8000 | ✅ cert-manager | ⚠️ needs DNS | active | P1 | ingress-openedx-lms.yaml |
| `staging.notes.academyv2.mereka.io` | notes | caddy → notes:8000 | ✅ cert-manager | ⚠️ needs DNS | active | P2 | ingress-openedx-lms.yaml |
| `staging.credentials.academyv2.mereka.io` | credentials | credentials:8000 (direct) | ✅ cert-manager | ⚠️ needs DNS | active | P2 | ingress-credentials.yaml |
| `staging.admin.academyv2.mereka.io` | enterprise-admin | enterprise-admin-portal:8002 | ✅ cert-manager | ⚠️ needs DNS | active | P1 | ingress-enterprise-admin.yaml |
| `staging.learner.academyv2.mereka.io` | enterprise-learner | enterprise-learner-portal:8002 | ✅ cert-manager | ⚠️ needs DNS | active | P2 | ingress-enterprise-learner.yaml |
| `staging.forum.academyv2.mereka.io` | forum | caddy → lms:8000 | ✅ cert-manager | ⚠️ needs DNS | active | P2 | ingress-openedx-lms.yaml |
| `staging.auth0.mereka.io` | auth | external (Authentik) | ❌ external | N/A (bbi-infra) | active | **P0** | domain-env.yaml |

### 2.9 STAGING — Biji-Biji Academy and Skill Our Future

These follow the same pattern as §2.8 but with `staging.*` prefixed domains.
Per tenant-registry.yaml, both tenants have 8 domains each in staging (primary, studio, mfe, preview, enterprise-admin, enterprise-learner, credentials, analytics).
SOF additionally has a migration-target domain set (`*.staging.skillourfuture.academyv2.mereka.io`).

_Staging tenant domains are declared in tenant-registry.yaml but NOT present in the `records.json` Cloudflare DNS files — these rely on wildcard DNS or manual DNS provisioning in the staging DNS zone._

---

## 3. Route Detail (Caddyfile)

The Caddyfile defines the following route-level behavior for each service host:

| Host Pattern | Route | Backend | Special Behavior |
|-------------|-------|---------|------------------|
| `{$LMS_HOST}`, `{$LMS_HOST_PREVIEW}` | `/` | lms:8000 | favicon rewrite, 4MB body limit, profile image 1MB limit |
| `{$LMS_HOST}` | `/payments/*` | payments-gateway:8080 | URI strip prefix `/payments` |
| `{$STUDIO_HOST}` | `/` | cms:8000 | favicon rewrite, 250MB body limit (course uploads) |
| `{$MFE_HOST}` | `/` | mfe:8002 | Root `/` redirects to `{$LMS_HOST}`, 2MB body limit |
| `{$DISCOVERY_HOST}` | `/` | discovery:8000 | 10MB body limit |
| `{$NOTES_HOST}` | `/` | notes:8000 | Standard proxy |
| `{$CREDENTIALS_HOST}` | `/` | credentials:8000 | Root path serves static HTML landing, `/authn/*` proxied to mfe:8002, `/admin/login*` rewritten to `/authn/login` |
| `{$ENTERPRISE_ADMIN_HOST}` | `/` | enterprise-admin-portal:8002 | API paths proxied: `/api/enterprise-catalog/*` → enterprise-catalog:8160, `/api/enterprise-access/*` → enterprise-access:18270, `/api/license-manager/*` → license-manager:18170, `/api/enterprise-subsidy/*` → enterprise-subsidy:18280, `/api/mfe_config/v1*` + `/login_refresh*` → lms:8000 |
| `{$ENTERPRISE_LEARNER_HOST}` | `/` | enterprise-learner-portal:8002 | API paths: `/api/v1/bffs/*` → enterprise-access:18270, same enterprise API strip-prefix routing as admin, `/api/mfe_config/v1*` + `/login_refresh*` → lms:8000 |
| `localhost` (local only) | `/` | lms:8000 | HTTP-only local development |
| `studio.localhost` (local only) | `/` | cms:8000 | HTTP-only local development |
| `apps.localhost` (local only) | `/` | mfe:8002 | HTTP-only local development |
| `discovery.localhost` (local only) | `/` | discovery:8000 | HTTP-only local development |
| `notes.localhost` (local only) | `/` | notes:8000 | HTTP-only local development |
| `xqueue.localhost` (local only) | `/` | xqueue:8000 | HTTP-only local development, xqueue disabled in prod/dev |

**Cache policy** (global, applied via `(proxy)` snippet):
- Default: `Cache-Control: no-cache`
- `/static/*`, `/theming/asset/*`: `public, max-age=31536000, immutable`
- `/media/*`: `public, max-age=3600`
- `/api/*`, `/oauth2/*`, `/login*`, `/logout*`, `/admin/*`: `no-store`

---

## 4. Risk Flags

### 4.1 ⚠️ Hosts with NO Ingress TLS (cert gap)

These domains are declared active but have no TLS certificate configured in any K8s Ingress:

| Domain | Env | Tenant | Risk |
|--------|-----|--------|------|
| `preview.academy.biji-biji.com` | prod | biji-biji | No cert — preview link from Studio would fail HTTPS |
| `admin.academy.biji-biji.com` | prod | biji-biji | Recently realized (2026-04-01) — TLS status unclear |
| `learner.academy.biji-biji.com` | prod | biji-biji | Recently realized (2026-04-01) — TLS status unclear |
| `credentials.academy.biji-biji.com` | prod | biji-biji | Recently realized (2026-04-01) — TLS status unclear |
| `analytics.academy.biji-biji.com` | prod | biji-biji | Recently realized (2026-04-01) — TLS status unclear |
| `skillourfuture.academyv2.mereka.io` | prod | skillourfuture | Migration target — no TLS, no DNS yet |
| `studio.skillourfuture.academyv2.mereka.io` | prod | skillourfuture | Migration target — no TLS, no DNS |
| `apps.skillourfuture.academyv2.mereka.io` | prod | skillourfuture | Migration target — no TLS, no DNS |
| `studio.skillourfuture.academy.mereka.io` | prod | skillourfuture | Legacy — deprecated, no TLS |
| `apps.skillourfuture.academy.mereka.io` | prod | skillourfuture | Legacy — deprecated, no TLS |

### 4.2 ⚠️ Hosts with NO DNS Record in Cloudflare

These domains are declared in tenant-registry but have no corresponding DNS record in the Cloudflare JSON files:

| Domain | Env | Issue |
|--------|-----|-------|
| `skillourfuture.academyv2.mereka.io` | prod | Migration target — DNS not created yet |
| `studio.skillourfuture.academyv2.mereka.io` | prod | No DNS |
| `apps.skillourfuture.academyv2.mereka.io` | prod | No DNS |
| `studio.skillourfuture.academy.mereka.io` | prod | Legacy deprecated — never had DNS |
| `apps.skillourfuture.academy.mereka.io` | prod | Legacy deprecated — never had DNS |
| `admin.academyv2.mereka.dev` | dev | No DNS record in records.mereka-dev.json |
| `learner.academyv2.mereka.dev` | dev | No DNS record in records.mereka-dev.json |
| `biji-biji.academyv2.mereka.dev` | dev | No DNS in records.mereka-dev.json (parent domain exists) |
| `studio.biji-biji.academyv2.mereka.dev` | dev | No DNS |
| `apps.biji-biji.academyv2.mereka.dev` | dev | No DNS |
| `skillourfuture.academyv2.mereka.dev` | dev | No DNS |
| `studio.skillourfuture.academyv2.mereka.dev` | dev | No DNS |
| `apps.skillourfuture.academyv2.mereka.dev` | dev | No DNS |
| All `staging.*` domains | staging | No dedicated Cloudflare staging DNS records found |
| All `profiles-dev` (`*-dev.mereka.dev`) | profiles-dev | No DNS records found |

### 4.3 ⚠️ Conflicting Configurations

| Issue | Detail |
|-------|--------|
| **SOF domain split** | `skillourfuture.academy.mereka.io` (legacy) vs `skillourfuture.academyv2.mereka.io` (target). Both active in tenant-registry. Legacy is in prod Ingress TLS; target has no TLS/DNS. |
| **Ecommerce deprecated but DNS live** | `ecommerce.academyv2.mereka.io` has DNS (CNAME) but no Caddyfile block or Ingress — traffic reaches ingress but gets no response. |
| **Forum DNS but no dedicated Caddy block** | `forum.academyv2.mereka.io` resolves to the ingress and routes to `caddy:80`, but Caddyfile has no dedicated `{$FORUM_HOST}` block. Forum v2 runs in LMS — traffic likely falls through to the LMS host matcher. |
| **Analytics no Caddyfile block** | `analytics.academyv2.mereka.io` has DNS but no matching Caddyfile block in the base config. Superset routing may come from an overlay-injected config. |
| **BB admin domain in tenant-contracts.yml** | `tenant-contracts.yml` lists `admin.academyv2.mereka.io` as the admin domain for Biji-Biji, but the canonical host intent in tenant-registry has `admin.academy.biji-biji.com`. |
| **Production overlay is FROZEN/DEPRECATED** | The `deploy/k8s/overlays/production/kustomization.yaml` is explicitly marked NOT consumed by ArgoCD. ArgoCD deploys from `bbi-infrastructure`. |

### 4.4 ⚠️ Cross-Tenant Routing Risks

| Risk | Detail |
|------|--------|
| **Shared Caddy instance** | All tenants share one Caddy deployment. `{$LMS_HOST}` only matches the primary Mereka host; BB and SOF LMS hosts are injected as additional domains. If env var injection fails, BB/SOF traffic hits the wrong host matcher. |
| **Shared cookie domain risk** | Production cookie domains differ: `.academyv2.mereka.io` (Mereka), `.biji-biji.com` (BB), `.skillourfuture.academy.mereka.io` (SOF). Cross-domain cookie leakage is unlikely, but a misconfigured cookie domain would cause auth failures. |
| **Enterprise portals share same service** | All tenants route to the same `enterprise-admin-portal:8002` and `enterprise-learner-portal:8002` pods. Tenant isolation depends on the MFE reading the correct host-based config from LMS `/api/mfe_config/v1*`. |

---

## 5. Proof Gaps

### 5.1 Runtime Proof Scripts

| Environment | Script | Exists |
|-------------|--------|--------|
| Dev | `scripts/tenants/verify-dev-runtime-proof.sh` | ✅ Referenced in registry |
| Staging | `scripts/tenants/verify-staging-runtime-proof.sh` | ✅ Referenced in registry |
| Production | (none) | ❌ **No production runtime proof script** |
| Local | (none) | ❌ N/A (not needed) |

### 5.2 Evidence Artifacts

| Area | Evidence | Status |
|------|----------|--------|
| Tenant isolation | `evidence/operations/TENANT_ISOLATION_EVIDENCE.md` | Superseded → see `docs/evidence/` |
| Domain QA scripts | `scripts/qa/verify-domain-url-invariants.sh` | ✅ Exists |
| Domain QA scripts | `scripts/qa/verify-rke2-tenant-routes.sh` | ✅ Exists |
| Domain QA scripts | `scripts/qa/verify-mfe-config-api.sh` | ✅ Exists |
| Domain authority chain | `scripts/qa/verify-domain-authority-chain.sh` | ✅ Exists |
| Generated domain surfaces | `scripts/qa/verify-domain-generated-surfaces.sh` | ✅ Exists |
| Tenant DNS inventory | `scripts/qa/verify-tenant-dns-inventory.sh` | ✅ Exists |
| Per-tenant smoke tests | `scripts/qa/verify-tenant-ui-smoke.sh` | ✅ Exists |
| Multisite config | `scripts/qa/verify-multisite-config.sh` | ✅ Exists |
| Tenant isolation | `scripts/qa/verify-tenant-isolation.sh` | ✅ Exists |

### 5.3 Hosts with Zero Runtime Evidence

The following **release-critical (P0)** domains need runtime proof but have **no production runtime proof script**:

| Domain | Env | Priority |
|--------|-----|----------|
| `academyv2.mereka.io` | prod | P0 |
| `studio.academyv2.mereka.io` | prod | P0 |
| `apps.academyv2.mereka.io` | prod | P0 |
| `discovery.academyv2.mereka.io` | prod | P0 |
| `academy.biji-biji.com` | prod | P0 |
| `studio.academy.biji-biji.com` | prod | P0 |
| `apps.academy.biji-biji.com` | prod | P0 |
| `skillourfuture.academy.mereka.io` | prod | P0 |
| `auth0.mereka.io` | prod | P0 |

---

## 6. Owner Hypothesis

| Host Role | Owner Layer | Rationale |
|-----------|-------------|-----------|
| LMS primary (`academyv2.mereka.io`, `academy.biji-biji.com`, `skillourfuture.*`) | **app** (mereka-lms repo) | Tenant-registry.yaml is canonical. Caddyfile, multisite-sites.yml, Django Sites all owned here. |
| Studio (`studio.*`) | **app** | Same as LMS — CMS is part of the Open edX deployment. |
| MFE (`apps.*`) | **app** | MFE container and Caddyfile routing owned by app repo. |
| Preview (`preview.*`) | **app** | Preview is LMS with a different host header — same ownership. |
| Discovery (`discovery.*`) | **app** | Discovery service and Caddyfile block owned by app repo. |
| Notes (`notes.*`) | **app** | Notes service config owned by app repo. |
| Credentials (`credentials.*`) | **app** | Credentials service and Caddyfile block owned by app repo. |
| Forum (`forum.*`) | **app** | Forum v2 runs in LMS — app repo ownership. |
| Enterprise Admin (`admin.*`) | **app** | Enterprise MFE and Caddyfile API routing owned by app repo. |
| Enterprise Learner (`learner.*`) | **app** | Same as admin — enterprise MFE. |
| Analytics (`analytics.*`) | **app/infra shared** | Superset/Aspects config partially in base, partially in overlays. Analytics data pipeline in infra. |
| Auth (`auth0.*`) | **infra/platform** (bbi-infrastructure) | Authentik OIDC provider deployed by bbi-infrastructure, NOT by this repo. |
| Ecommerce (`ecommerce.*`) | **app** (deprecated) | Legacy Oscar — being replaced by payments-gateway. |
| DNS records | **platform** (Cloudflare + platform-control-plane) | DNS managed outside this repo. |
| TLS certificates | **infra/platform** (cert-manager + bbi-infrastructure) | cert-manager issues Let's Encrypt certs; cluster-issuer is platform-owned. |
| Ingress rules | **app** (overlays declared here) but **consumed by infra** (ArgoCD in bbi-infrastructure) | Overlays are declared in app repo but the production overlay is DEPRECATED — bbi-infrastructure is the active consumer. |

---

## 7. Config Source Inventory

| File | Role | Authority |
|------|------|-----------|
| `deploy/k8s/tenancy/tenant-registry.yaml` | **Canonical** host intent for all tenants/envs/roles | Primary (v1.5.0) |
| `infrastructure/tenants/tenant-contracts.yml` | Tenant metadata (slug, name, org, contact) | Primary for metadata, DERIVED for domains |
| `deploy/k8s/base/apps/caddy/Caddyfile` | Caddy reverse-proxy routing rules | Primary for route logic |
| `infrastructure/tutor/multisite-sites.yml` | Django Sites framework config (prod) | Primary for Django site_values |
| `infrastructure/tutor/multisite-sites.dev.yml` | Django Sites framework config (dev) | Primary for Django site_values |
| `infrastructure/tutor/multisite-sites.staging.yml` | Django Sites framework config (staging) | Primary for Django site_values |
| `deploy/k8s/overlays/*/patches/domain-env.yaml` | Environment variable injection per overlay | Primary for env-specific host vars |
| `deploy/k8s/overlays/*/ingress-*.yaml` | K8s Ingress host rules with TLS | Primary for ingress routing |
| `infrastructure/cloudflare/records.json` | Cloudflare DNS (mereka.io zone) | Primary for DNS |
| `infrastructure/cloudflare/records.biji-biji.com.json` | Cloudflare DNS (biji-biji.com zone) | Primary for DNS |
| `infrastructure/cloudflare/records.mereka-dev.json` | Cloudflare DNS (mereka.dev zone) | Primary for DNS |
| `infrastructure/cloudflare/tenant-dns-records.yaml` | Tenant DNS template | Reference (has placeholder vars) |
| `infrastructure/tutor/tenant-branding-schema.yml` | Allowed branding override keys | Primary for branding contract |
| `docs/reference/architecture/DOMAIN_AUTHORITY_END_STATE.md` | Architecture target for domain authority chain | Reference (proposed) |
| `docs/concepts/architecture/TENANT_OPERATING_SYSTEM.md` | Tenant platform operating model | Canonical standard |
| `docs/concepts/architecture/TENANT_LIFECYCLE.md` | Tenant lifecycle states/transitions | Canonical standard |
