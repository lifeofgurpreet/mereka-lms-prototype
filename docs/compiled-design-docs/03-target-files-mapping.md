# Target Files & Implementation Steps Mapping

**Source**: Compiled from all specs, ADRs, and architecture documents.
**Date**: 2026-04-27

This document maps each design requirement area to the specific files that need to be created or modified, and the implementation steps required.

---

## 1. Authentication & SSO Enterprise

### 1.1 SAML/OIDC Federation Setup (Phase 0)

**Target files to CREATE**:

| File | Purpose |
|------|---------|
| `scripts/tenants/generate-saml-keys.sh` | Generate RSA-2048+ key pairs per tenant, store in Infisical |
| `scripts/tenants/configure-tenant-idp.sh` | Wrapper for Django management commands to create SAMLProviderConfig / OAuth2ProviderConfig |
| `deploy/k8s/base/secrets/tenant-idp-secrets-template.yaml` | ExternalSecret template for per-tenant SAML/OIDC secrets |
| `docs/onboarding/ENTERPRISE_IDP_SETUP.md` | Client IT team guide for SAML metadata exchange |
| `scripts/qa/verify-enterprise-sso.sh` | Per-tenant SSO verification script |

**Target files to MODIFY**:

| File | Change |
|------|--------|
| `infrastructure/tutor/apply-patches.sh` | Ensure SAML/OIDC backend dependencies installed |
| `infrastructure/tutor/patches/` | SAML/OIDC backend configuration patches |
| `infrastructure/tutor/plugins/mereka_lms.py` | Add enterprise SSO Tutor config entries |
| `scripts/qa/verify-auth-surfaces.sh` | Add enterprise SAML/OIDC endpoint checks |
| `deploy/k8s/overlays/production/` | Feature flag ConfigMap entries |

**Steps**:
1. Audit existing `third_party_auth` in Tutor build -- verify SAML/OIDC dependencies
2. Create SAML key generation script with Infisical integration
3. Create IdP configuration helper script wrapping Django management commands
4. Create ExternalSecret templates for per-tenant secrets
5. Implement slug-based IdP routing at `/enterprise/login/{tenant_slug}`
6. Validate SP metadata at `/auth/saml/metadata.xml`
7. Implement unique SP entity ID per tenant: `https://{lms_host}/saml/entity/{tenant_slug}`
8. Add `ENABLE_ENTERPRISE_SSO` and per-tenant feature flags
9. Extend verification scripts

---

### 1.2 MFA Enforcement (Phase 1)

**Target files to CREATE**:

| File | Purpose |
|------|---------|
| `deploy/k8s/base/apps/openedx/settings/lms/mereka_mfa_enforcement.py` | MFA enforcement middleware module |
| `scripts/qa/verify-mfa-enforcement.sh` | MFA enforcement verification |
| `scripts/qa/verify-session-hardening.sh` | Session timeout/limit verification |
| `scripts/qa/verify-auth-rate-limiting.sh` | Rate limiting verification |

**Target files to MODIFY**:

| File | Change |
|------|--------|
| `infrastructure/tutor/apply-patches.sh` | Register MFA middleware in `MIDDLEWARE` list |
| `infrastructure/tutor/plugins/mereka_lms.py` | Add `django-otp` to `INSTALLED_APPS`, MFA settings |
| `infrastructure/tutor/patches/` | Add `django-otp` / `django-two-factor-auth` to pip requirements |
| `deploy/k8s/base/apps/openedx/settings/lms/mereka_platform_admin.py` | Coordinate with MFA enforcement |
| `scripts/qa/verify-auth-surfaces.sh` | Add open redirect protection tests |
| `deploy/k8s/overlays/production/` | MFA feature flag ConfigMap entries |

**Steps**:
1. Add `django-otp` (or `django-two-factor-auth`) dependency to image build
2. Create MFA enforcement middleware that intercepts `/admin/` requests
3. Implement TOTP enrollment flow (QR code, confirmation, recovery codes)
4. Implement session idle timeout middleware (30min staff, 120min learner)
5. Implement absolute session timeout (8h staff, 24h learner)
6. Implement concurrent session limiting (Redis-backed, max 5)
7. Add rate limiting on auth endpoints (20 attempts/IP/5min)
8. Add open redirect protection on `next` parameter
9. Add feature flags: `ENABLE_MFA_ENFORCEMENT`, `ENABLE_SESSION_HARDENING`, `ENABLE_AUTH_RATE_LIMITING`
10. Create verification scripts
11. Staged rollout: staging (1 week) -> production

---

### 1.3 JIT Provisioning & Role Mapping (Phase 2)

**Target files to CREATE**:

| File | Purpose |
|------|---------|
| Custom `python-social-auth` pipeline module | Tenant-scoped JIT provisioning, collision avoidance, role mapping |
| `scripts/qa/smoke-enterprise-sso.sh` | End-to-end enterprise SSO smoke test |
| `scripts/qa/verify-saml-security.sh` | SAML assertion security tests |
| `scripts/qa/verify-oidc-security.sh` | OIDC token security tests |
| `scripts/qa/verify-jit-provisioning.sh` | JIT provisioning verification |
| `scripts/qa/verify-cross-tenant-isolation.sh` | Cross-tenant isolation test |
| `scripts/qa/verify-role-mapping.sh` | Claim-based role assignment tests |
| `scripts/qa/verify-logout-flow.sh` | Logout flow verification |

**Target files to MODIFY**:

| File | Change |
|------|--------|
| `infrastructure/tutor/plugins/mereka_lms.py` | Custom social-auth pipeline config |
| `infrastructure/tutor/apply-patches.sh` | Pipeline registration |
| LMS production settings | SAML/OIDC validation hardening settings |

**Steps**:
1. Implement custom `python-social-auth` pipeline steps for JIT provisioning
2. Implement SAML assertion validation hardening (signature, issuer, audience, replay)
3. Implement OIDC validation hardening (JWKS, iss/aud/exp/nonce, PKCE)
4. Implement cross-tenant IdP isolation
5. Implement IdP claim-based role assignment with configurable mappings
6. Implement auto-role revocation
7. Implement SAML/OIDC logout flows
8. Create all verification scripts
9. Staged rollout with test IdP (mock or Authentik-as-enterprise)

---

### 1.4 SCIM Deprovisioning (Phase 3)

**Target files to CREATE**:

| File | Purpose |
|------|---------|
| SCIM 2.0 endpoint module | Account deprovisioning API |
| `scripts/qa/verify-scim-endpoint.sh` | SCIM endpoint verification |

**Steps**:
1. Implement SCIM 2.0 endpoint (DELETE and scheduled sync)
2. Deactivate user (not delete) -- preserve enrollments/progress
3. Add `ENABLE_SCIM_PROVISIONING` feature flag
4. Scale to 2-3+ tenant IdPs

---

## 2. Platform Middleware (Existing -- Reference)

These files already exist and are operational:

| File | Component |
|------|-----------|
| `deploy/k8s/base/apps/openedx/settings/lms/mereka_platform_admin.py` | PlatformAdmin middleware |
| `deploy/k8s/base/apps/openedx/settings/lms/mereka_multisite.py` | CookieDomain middleware |
| `deploy/k8s/base/apps/openedx/settings/lms/mereka_forwarded_headers.py` | ForwardedHeaders middleware |
| `infrastructure/tutor/custom-apps/mfe_oauth_fix/` | MFE OAuth fix app |
| `infrastructure/tutor/custom-apps/openedx_prometheus/` | Prometheus metrics app |
| `infrastructure/tutor/apply-patches.sh` | Middleware/app registration |

---

## 3. Multi-Tenancy

### Target files (Existing -- Reference)

| File | Purpose |
|------|---------|
| `scripts/tenants/provision-tenant.sh` | Tenant provisioning script |
| `scripts/infra/apply-multisite-config.sh` | Multisite SiteConfiguration management |
| `scripts/qa/verify-multisite-config.sh` | Multisite config verification |
| `scripts/qa/verify-org-role-ownership.sh` | Org role ownership verification |

---

## 4. Observability (Auth-Specific Additions)

**Target files to CREATE**:

| File | Purpose |
|------|---------|
| Prometheus metric definitions module | Auth metrics registration |
| Grafana dashboard JSON (x4) | Auth monitoring dashboards |
| PrometheusRule manifests | Alert rules for auth anomalies |

**Target files to MODIFY**:

| File | Change |
|------|--------|
| `infrastructure/monitoring/prometheus/` | Auth metric scraping config |
| `deploy/k8s/base/` | PrometheusRule manifests |

---

## 5. Auth Hardening Scripts (Existing -- Reference)

All scripts that agents should be aware of:

### Enforcement Scripts (`scripts/infra/`)

| Script | Purpose | Mode |
|--------|---------|------|
| `ensure-platform-admins.sh` | Enforce staff/superuser/CourseCreator for platform admins | `--verify` / `--apply` |
| `ensure-authentik-admin.sh` | Enforce Authentik admin group (Gurpreet only) | `--verify` / `--apply` |
| `ensure-authentik-admin-mfa.sh` | Enforce MFA for Authentik admins | `--verify` / `--apply` |
| `ensure-authentik-oidc-redirect-uris.sh` | Enforce OIDC redirect URI allowlist | `--verify` / `--apply` |
| `ensure-authentik-hardening.sh` | Unified Authentik hardening entrypoint | `--verify` / `--apply` |

### Verification Scripts (`scripts/qa/`)

| Script | Purpose |
|--------|---------|
| `verify-auth-surfaces.sh {prod\|dev}` | Public auth surface checks (OIDC, Studio, services) |
| `verify-auth-hardening.sh --env both --mode all` | Full auth hardening suite |
| `verify-mfe-config-contract.sh --env {prod\|dev\|both}` | MFE auth-critical config keys |
| `verify-oidc-provider-configs.sh` | OIDC provider enablement/secret check |
| `verify-oidc-user-password-state.sh` | Detect disabled OIDC user accounts |
| `verify-authenticated-sso-canary.sh --env {prod\|dev}` | Real browser SSO flow test |
| `verify-multisite-config.sh` | Multisite SiteConfiguration governance |
| `verify-org-role-ownership.sh` | Org role ownership check |
| `audit-auth-access.sh --env both --mode all` | Consolidated auth audit report |
| `audit-authentik-policy-exceptions.sh` | Root-cause Authentik "Request denied" |

---

## 6. Implementation Priority Order

Based on the spec's phased rollout and dependency chain:

```
Prerequisites (must be true before Phase 0):
  - EnterpriseCustomer model deployed
  - Enterprise roles defined
  - Observability stack operational
  - Secrets pipeline operational
  - Platform middleware deployed (already done)

Phase 0 - Foundation (Week 1-2):
  -> SAML/OIDC dependency audit
  -> Key generation scripts
  -> IdP configuration scripts
  -> Slug-based routing
  -> Feature flag infrastructure
  -> Verification scripts

Phase 1 - MFA & Session Hardening (Week 3-4):
  -> MFA enforcement middleware
  -> TOTP integration
  -> Session idle/absolute timeouts
  -> Concurrent session limits
  -> Rate limiting
  -> Auth event logging
  -> Prometheus metrics

Phase 2 - First Enterprise IdP (Week 5-6):
  -> JIT provisioning pipeline
  -> SAML/OIDC validation hardening
  -> Cross-tenant isolation
  -> Claim-based role mapping
  -> Security event logging

Phase 3 - SCIM & Scale (Week 7-8):
  -> SCIM 2.0 endpoint
  -> Scale to multiple tenants

Phase 4 - Observability & Hardening (Week 9+):
  -> Grafana dashboards
  -> Alert rules
  -> Runbooks
  -> Penetration testing
```

---

## 7. Configuration Reference

### Environment Variables (Required)

| Variable | Purpose | Set Via |
|----------|---------|---------|
| `MEREKA_PLATFORM_ADMIN_EMAILS` | Platform admin allowlist | K8s ConfigMap |
| `MEREKA_LMS_DOMAIN` | Primary LMS domain | K8s ConfigMap |
| `MEREKA_LMS_BASE_URL` | LMS base URL | K8s ConfigMap |
| `MEREKA_BIJI_DOMAIN` | Biji-Biji tenant domain | K8s ConfigMap |
| `MEREKA_SKILLOURFUTURE_DOMAIN` | SkillOurFuture tenant domain | K8s ConfigMap |
| `ENABLE_ENTERPRISE_SSO` | Global enterprise SSO gate | Feature flag |
| `ENABLE_MFA_ENFORCEMENT` | MFA enforcement toggle | Feature flag |
| `ENABLE_SESSION_HARDENING` | Session hardening toggle | Feature flag |
| `ENABLE_AUTH_RATE_LIMITING` | Rate limiting toggle | Feature flag |

### Secrets (Required for Enterprise SSO)

| Secret | Purpose | Storage |
|--------|---------|---------|
| SAML signing key (per tenant) | SP assertion signing | Infisical -> ExternalSecret |
| SAML signing cert (per tenant) | SP metadata | Infisical -> ExternalSecret |
| OIDC client secret (per tenant) | RP authentication | Infisical -> ExternalSecret |
| SCIM bearer token (per tenant) | SCIM API auth | Infisical -> ExternalSecret |
