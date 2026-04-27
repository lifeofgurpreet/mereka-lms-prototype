# Platform Changes

**Source**: Compiled from Faiz's design specs, ADRs, and architecture documents.
**Date**: 2026-04-27

This document maps all platform changes required by the design documentation, organized by domain. Each change references its source spec and acceptance criteria.

---

## 1. Authentication & SSO

**Source**: `specs/auth-sso-enterprise_spec.md`, `docs/policies/operations/AUTH_HARDENING_SPEC.md`

### 1.1 Enterprise SSO Federation (New)

| Change | Description | Phase |
|--------|-------------|-------|
| SAML 2.0 SP configuration | Per-tenant SAML IdP configs via `SAMLProviderConfig` model | Phase 0 |
| OIDC RP configuration | Per-tenant OIDC configs via `OAuth2ProviderConfig` model | Phase 0 |
| Slug-based IdP routing | `/enterprise/login/{tenant_slug}` redirects to correct IdP | Phase 0 |
| SP metadata endpoint | `/auth/saml/metadata.xml` with correct ACS URL, entity ID, cert | Phase 0 |
| Per-tenant SAML keys | RSA-2048+ key pairs stored via Infisical/ExternalSecrets | Phase 0 |

**Supported IdPs**: ADFS, Microsoft Entra ID (Azure AD), Okta, Google Workspace, PingFederate, any SAML 2.0/OIDC provider.

**Architecture**: Hub-and-spoke model. Each tenant IdP connects directly to LMS (not through Authentik). Authentik remains default OIDC for non-enterprise users at `/auth/login/oidc/`.

### 1.2 MFA Enforcement (New)

See [02-mfa-requirements.md](02-mfa-requirements.md) for full detail.

| Change | Description | Phase |
|--------|-------------|-------|
| MFA middleware for Django admin | Intercept `/admin/` for staff/superuser without MFA | Phase 1 |
| TOTP integration | `django-otp` or `django-two-factor-auth` enrollment + verification | Phase 1 |
| Recovery codes | Generation and break-glass procedure | Phase 1 |
| Forced enrollment | Newly elevated users prompted at next login | Phase 1 |

### 1.3 Session Hardening (New)

| Change | Description | Phase |
|--------|-------------|-------|
| Idle timeout middleware | 30min staff, 120min learner (configurable) | Phase 1 |
| Absolute timeout | 8h staff, 24h learner (configurable) | Phase 1 |
| Concurrent session limit | Default 5 sessions per user; oldest invalidated on overflow (Redis-backed) | Phase 1 |
| Session ID regeneration | `request.session.cycle_key()` post-authentication | Phase 1 |

### 1.4 Security Hardening (New)

| Change | Description | Phase |
|--------|-------------|-------|
| Rate limiting | 20 failed attempts/IP/5min; exponential backoff (5m, 15m, 60m) | Phase 1 |
| Open redirect protection | Validate `next` param against `ALLOWED_HOSTS` + whitelist | Phase 1 |
| SAML assertion replay prevention | Redis cache with TTL = validity + 120s clock skew | Phase 2 |
| SAML signature validation | SHA-256+ required; SHA-1 rejected | Phase 2 |
| OIDC PKCE enforcement | S256 `code_challenge_method` required | Phase 2 |
| Cross-tenant isolation | Validate SAML Issuer / OIDC iss before `EnterpriseCustomerUser` creation | Phase 2 |

### 1.5 Account Provisioning & Deprovisioning (New)

| Change | Description | Phase |
|--------|-------------|-------|
| JIT provisioning | Auto-create user on first IdP auth; link to `EnterpriseCustomer` | Phase 2 |
| Claim-based role mapping | IdP claims -> `enterprise_admin` / `enterprise_learner` | Phase 2 |
| Auto-role revocation | Downgrade when admin claim disappears (configurable per tenant) | Phase 2 |
| SCIM 2.0 endpoint | Account deprovisioning; deactivate (not delete); preserve data | Phase 3 |
| Email verification gate | Unverified JIT accounts gated from enterprise-subsidized content | Phase 2 |

### 1.6 Audit Logging (New)

| Change | Description | Phase |
|--------|-------------|-------|
| Auth event logging | login_attempt, login_success, login_failure, logout, session_*, mfa_* | Phase 1-2 |
| Provisioning event logging | JIT, SCIM, manual provisioning events | Phase 2 |
| Security event logging | Cross-tenant denied, replay detected, rate limited | Phase 2 |
| Sensitive data masking | user_id_hash (SHA-256), ip_address_hash; NO raw tokens in logs | Phase 2 |

### 1.7 Feature Flags

| Flag | Scope | Phase |
|------|-------|-------|
| `ENABLE_ENTERPRISE_SSO` | Global gate | Phase 0 |
| `ENABLE_ENTERPRISE_SSO_{TENANT_SLUG}` | Per-tenant | Phase 0 |
| `ENABLE_MFA_ENFORCEMENT` | Platform-wide | Phase 1 |
| `ENABLE_SESSION_HARDENING` | Platform-wide | Phase 1 |
| `ENABLE_AUTH_RATE_LIMITING` | Platform-wide | Phase 1 |
| `ENABLE_SCIM_PROVISIONING` | Per-tenant | Phase 3 |
| `ENABLE_CLAIM_BASED_ROLE_SYNC` | Per-tenant | Phase 2 |
| `ENABLE_AUTO_ROLE_REVOCATION` | Per-tenant | Phase 2 |

---

## 2. Platform Middleware Stack

**Source**: `specs/platform-middleware-custom-apps_spec.md`

### 2.1 Existing Middleware (Operational)

These are already built and deployed:

| Middleware | Purpose | Status |
|-----------|---------|--------|
| `MerekaPlatformAdminMiddleware` | Auto-escalate configured admin emails to staff/superuser | Operational |
| `MerekaCookieDomainMiddleware` | Multi-domain cookie management (.mereka.io, .biji-biji.com) | Operational |
| `MerekaForwardedHeadersMiddleware` | Normalize proxy headers from Cloudflare/Ingress/Caddy chain | Operational |
| `MFEOAuthFixMiddleware` | Inject OAuth providers into `/api/mfe_context`; rename "Authentik" -> "Mereka" | Operational |

### 2.2 Custom Django Apps (Operational)

| App | Purpose | Status |
|-----|---------|--------|
| `mfe_oauth_fix` | OAuth provider normalization for MFE authn page | Operational |
| `openedx_prometheus` | `/metrics` endpoint for Prometheus scraping | Operational |

### 2.3 Middleware Execution Order (Required)

```
1. django_prometheus.middleware.PrometheusBeforeMiddleware
2. MerekaForwardedHeadersMiddleware
3. MerekaCookieDomainMiddleware
4. (Django core middleware)
5. MerekaPlatformAdminMiddleware
6. mfe_oauth_fix.middleware.MFEOAuthFixMiddleware
7. django_prometheus.middleware.PrometheusAfterMiddleware
```

---

## 3. Multi-Tenancy Architecture

**Source**: `specs/multi-tenancy-architecture_spec.md`, ADR-024

### 3.1 Tenant Model

| Aspect | Design Decision |
|--------|----------------|
| Tenant boundary | `EnterpriseCustomer` UUID |
| Isolation level | Application-layer (queryset filtering, API permissions) -- NOT database-level |
| Shared infrastructure | Single K8s cluster, MySQL, MongoDB, Redis |
| Per-tenant scope | Branding, domain routing, SiteConfiguration, catalog, SSO, analytics |
| Provisioning | Via `scripts/tenants/provision-tenant.sh` (not ad-hoc) |

### 3.2 Active Tenants

- **Mereka Academy** (primary) -- `academyv2.mereka.io`
- **Biji-Biji Initiative** -- `academy.biji-biji.com`
- **SkillOurFuture** -- `skillourfuture.academy.mereka.io`

---

## 4. Kubernetes Deployment

**Source**: `specs/k8s-deployment_spec.md`

### 4.1 Workloads (17+)

LMS, CMS, MFEs, Discovery, Forum, Credentials, Notes, XQueue, Purchase Gateway, Enterprise Services (catalog, license-manager, access, subsidy, integrated-channels), and supporting services.

### 4.2 Ownership Split

| Layer | Owner | Location |
|-------|-------|----------|
| Base K8s resources | App repo (mereka-lms) | `deploy/k8s/base/` |
| Environment overlays | GitOps repo (bbi-infrastructure) | Overlay directories |
| Local overlay | App repo | `deploy/k8s/overlays/local/` |
| Image tags | ArgoCD Image Updater | GitOps repo |

---

## 5. Frontend & Branding

**Source**: `specs/mfe-plugin-slots_spec.md`, `specs/branding-system_spec.md`, `specs/studio-customization_spec.md`

### 5.1 MFE Plugin Slot Roadmap

| Phase | Slot | Status |
|-------|------|--------|
| Current | Footer slot | Active |
| Phase 1 | Header branding slot | Planned |
| Phase 2 | Learning experience slot | Planned |
| Phase 3 | Account/profile slot | Planned |

### 5.2 Branding System

- Design token pipeline: brand pack -> style-dictionary -> CSS/SCSS variables
- Per-tenant theme via `THEME_NAME` in `SiteConfiguration`
- Brand package following OEP-48 standard

---

## 6. Enterprise Services

**Source**: `specs/enterprise-microservices_spec.md`, `specs/ecommerce-purchase-gateway_spec.md`

### 6.1 Services

| Service | Purpose | Status |
|---------|---------|--------|
| enterprise-catalog | Course catalog management per tenant | Frozen at 21.0.0 |
| license-manager | License allocation and tracking | Frozen at 21.0.0 |
| enterprise-access | Subsidy access policies | Frozen at 21.0.0 |
| enterprise-subsidy | Subsidy budget management | Frozen at 21.0.0 |
| enterprise-integrated-channels | LMS/content sync to external systems | Frozen at 21.0.0 |
| Purchase Gateway (NEW) | Stripe-based payment (replaces Oscar) | Spec'd |

**Note**: Enterprise services are frozen at 21.0.0 (upstream archived Nov 2024, pending fork/replacement decision -- WS-5 debt item).

---

## 7. Tutor Configuration

**Source**: `specs/tutor-configuration_spec.md`, ADR-006

### 7.1 Configuration Approach

- **Primary mechanism**: Tutor plugin at `infrastructure/tutor/plugins/mereka_lms.py`
- **Canonical prepare path**: `scripts/infra/prepare-tutor-build-context.sh --target all`
- **Post-save requirement**: Run prepare path after every `tutor config save`

### 7.2 Critical Patches

| Patch | Purpose |
|-------|---------|
| MySQL auth | Authentication method compatibility |
| MFE build (Node 24) | Build pipeline fix for newer Node |
| Multi-site domains | Multi-domain routing support |
| Custom apps | Install custom Django apps |
| Webpack memory | Memory limit increase for builds |

---

## 8. Settings Authority

**Source**: ADR-042, `docs/architecture/SETTINGS-OWNERSHIP-CONSOLIDATION.md`

| Component | Owner | Location |
|-----------|-------|----------|
| All Django settings logic | App repo (mereka-lms) | `deploy/k8s/base/apps/openedx/settings/` |
| Environment wiring | GitOps repo (bbi-infrastructure) | Overlay ConfigMaps |
| JWT signing key | Infisical (single platform-wide JWK) | ExternalSecret |
| Runtime settings | bbi-infrastructure overlay | **Single canonical writer** |

**Key invariant**: Tutor plugin = image-baked defaults only. `apply-patches.sh` = Dockerfile/asset work only (NO Django settings). Overlay = authoritative runtime truth.

---

## 9. Observability

**Source**: `specs/observability-stack_spec.md`

| Component | Purpose |
|-----------|---------|
| Prometheus | Metrics collection (15+ auth metrics planned) |
| Grafana | Dashboards (4 auth dashboards planned) |
| Loki | Log aggregation |
| Tempo | Distributed tracing |

### Auth-Specific Metrics (Planned)

`auth_login_total`, `auth_login_latency_seconds`, `auth_session_active_count`, `auth_session_expired_total`, `auth_mfa_challenge_total`, `auth_rate_limit_triggered_total`, `auth_saml_assertion_processing_seconds`, `auth_oidc_token_exchange_seconds`, `auth_jit_provisioning_total`, `auth_cross_tenant_access_denied_total`

---

## 10. Secrets Management

**Source**: `specs/secrets-management_spec.md`

**Pipeline**: Infisical -> GCP Secret Manager -> ExternalSecrets -> K8s Secrets

New secrets required for enterprise SSO:
- Per-tenant SAML signing certificates (RSA-2048+)
- Per-tenant OIDC client secrets
- SCIM endpoint authentication tokens (method TBD)
