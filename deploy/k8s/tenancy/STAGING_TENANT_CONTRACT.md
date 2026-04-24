# Staging Tenant Domain Contract

> Version: 1.0.0
> Date: 2026-03-07
> Status: Published — awaiting GitOps consumption
> Source of truth: `deploy/k8s/tenancy/tenant-registry.yaml` (environment: staging)

## Decision

Staging uses explicit staging-prefixed tenant domains, but the public hostname
shape is tenant-specific:

- Primary tenant uses `staging.{service}.academyv2.mereka.io`
- Secondary tenants use `{service}.staging.<tenant-domain>`

Production tenant domains are never admitted into staging settings. This is
enforced by the staging activation gate policy in bbi-infrastructure.

---

## 1. Canonical Staging Tenant Domain Table

### Mereka Academy (primary tenant)

| Role | Domain | Required | Proof Priority |
|------|--------|----------|----------------|
| primary | `staging.academyv2.mereka.io` | now | P0 |
| studio | `staging.studio.academyv2.mereka.io` | now | P0 |
| mfe | `staging.apps.academyv2.mereka.io` | now | P0 |
| preview | `staging.preview.academyv2.mereka.io` | now | P1 |
| discovery | `staging.discovery.academyv2.mereka.io` | now | P1 |
| notes | `staging.notes.academyv2.mereka.io` | now | P2 |
| credentials | `staging.credentials.academyv2.mereka.io` | now | P2 |
| enterprise-admin | `staging.admin.academyv2.mereka.io` | now | P1 |
| enterprise-learner | `staging.learner.academyv2.mereka.io` | deferred | P2 |
| auth | `staging.auth0.mereka.io` | now | P0 |

### Biji-Biji Academy (tenant)

| Role | Domain | Required | Proof Priority |
|------|--------|----------|----------------|
| primary | `staging.academy.biji-biji.com` | now | P0 |
| studio | `studio.staging.academy.biji-biji.com` | now | P0 |
| mfe | `apps.staging.academy.biji-biji.com` | now | P0 |

### Skill Our Future (tenant)

| Role | Domain | Required | Proof Priority |
|------|--------|----------|----------------|
| primary | `staging.skillourfuture.academy.mereka.io` | now | P0 |
| studio | `studio.staging.skillourfuture.academy.mereka.io` | now | P0 |
| mfe | `apps.staging.skillourfuture.academy.mereka.io` | now | P0 |

### Enterprise tenant-specific surfaces

Enterprise admin and learner portals are **primary-tenant-only** in staging.
No per-tenant enterprise surfaces for Biji-Biji or SkilloFuture.
Enterprise services read MFE config from the primary tenant's LMS.
This is out of scope for the tenant proof gate.

---

## 2. Expected Site / SiteConfiguration Values Per Staging Tenant

### Mereka Academy

```
Site.domain:              staging.academyv2.mereka.io
SiteConfiguration:
  enabled:                true
  LMS_ROOT_URL:           https://staging.academyv2.mereka.io
  CMS_ROOT_URL:           https://staging.studio.academyv2.mereka.io
  MFE_BASE_URL:           https://staging.apps.academyv2.mereka.io
  THEME_NAME:             mereka
  course_org_filter:      ["MEREKA"]
  MFE_CONFIG.LMS_BASE_URL:    https://staging.academyv2.mereka.io
  MFE_CONFIG.STUDIO_BASE_URL: https://staging.studio.academyv2.mereka.io
```

### Biji-Biji Academy

```
Site.domain:              staging.academy.biji-biji.com
SiteConfiguration:
  enabled:                true
  LMS_ROOT_URL:           https://staging.academy.biji-biji.com
  CMS_ROOT_URL:           https://studio.staging.academy.biji-biji.com
  MFE_BASE_URL:           https://apps.staging.academy.biji-biji.com
  THEME_NAME:             mereka
  course_org_filter:      ["BIJIBIJI"]
  MFE_CONFIG.LMS_BASE_URL:    https://staging.academy.biji-biji.com
  MFE_CONFIG.STUDIO_BASE_URL: https://studio.staging.academy.biji-biji.com
```

### Skill Our Future

```
Site.domain:              staging.skillourfuture.academy.mereka.io
SiteConfiguration:
  enabled:                true
  LMS_ROOT_URL:           https://staging.skillourfuture.academy.mereka.io
  CMS_ROOT_URL:           https://studio.staging.skillourfuture.academy.mereka.io
  MFE_BASE_URL:           https://apps.staging.skillourfuture.academy.mereka.io
  THEME_NAME:             mereka
  course_org_filter:      ["SKILLOURFUTURE"]
  MFE_CONFIG.LMS_BASE_URL:    https://staging.skillourfuture.academy.mereka.io
  MFE_CONFIG.STUDIO_BASE_URL: https://studio.staging.skillourfuture.academy.mereka.io
```

---

## 3. Expected ALLOWED_HOSTS Per Staging Tenant

All domains below must appear in staging production.py `ALLOWED_HOSTS`:

```python
ALLOWED_HOSTS = [
    # Existing staging Mereka domains (already present)
    "staging.academyv2.mereka.io",
    "staging.studio.academyv2.mereka.io",
    "staging.apps.academyv2.mereka.io",
    "staging.preview.academyv2.mereka.io",
    "staging.discovery.academyv2.mereka.io",
    "staging.notes.academyv2.mereka.io",
    "staging.credentials.academyv2.mereka.io",
    "staging.admin.academyv2.mereka.io",
    "staging.learner.academyv2.mereka.io",
    # Staging Biji-Biji tenant (NEW)
    "staging.academy.biji-biji.com",
    "studio.staging.academy.biji-biji.com",
    "apps.staging.academy.biji-biji.com",
    # Staging SkilloFuture tenant (NEW)
    "staging.skillourfuture.academy.mereka.io",
    "studio.staging.skillourfuture.academy.mereka.io",
    "apps.staging.skillourfuture.academy.mereka.io",
    # Internal
    "lms",
]
```

**Policy note**: `staging.academy.biji-biji.com` uses a staging-prefixed LMS
domain, while `studio.staging.academy.biji-biji.com` and
`apps.staging.academy.biji-biji.com` use service-prefixed staging domains. The
staging activation gate must continue to distinguish these from bare production
hosts.

GitOps must distinguish:
- BLOCKED: `academy.biji-biji.com` (bare production domain)
- ALLOWED: `staging.academy.biji-biji.com` (staging-prefixed)
- ALLOWED: `studio.staging.academy.biji-biji.com` / `apps.staging.academy.biji-biji.com`

---

## 4. Expected MFE Config Proof Per Staging Tenant

The proof script must verify `/api/mfe_config/v1` returns correct values per Host header:

| Host Header | Expected LMS_BASE_URL | Expected STUDIO_BASE_URL |
|-------------|----------------------|--------------------------|
| staging.academyv2.mereka.io | https://staging.academyv2.mereka.io | https://staging.studio.academyv2.mereka.io |
| staging.academy.biji-biji.com | https://staging.academy.biji-biji.com | https://studio.staging.academy.biji-biji.com |
| staging.skillourfuture.academy.mereka.io | https://staging.skillourfuture.academy.mereka.io | https://studio.staging.skillourfuture.academy.mereka.io |

---

## 5. Cookie Domain Behavior

| Host | Expected Cookie Domain |
|------|----------------------|
| staging.academyv2.mereka.io | `.academyv2.mereka.io` |
| staging.studio.academyv2.mereka.io | `.academyv2.mereka.io` |
| staging.apps.academyv2.mereka.io | `.academyv2.mereka.io` |
| staging.academy.biji-biji.com | `.academy.biji-biji.com` |
| studio.staging.academy.biji-biji.com | `.academy.biji-biji.com` |
| apps.staging.academy.biji-biji.com | `.academy.biji-biji.com` |
| staging.skillourfuture.academy.mereka.io | `.skillourfuture.academy.mereka.io` |
| studio.staging.skillourfuture.academy.mereka.io | `.skillourfuture.academy.mereka.io` |
| apps.staging.skillourfuture.academy.mereka.io | `.skillourfuture.academy.mereka.io` |

**Cookie domain note**: staging cookies intentionally broaden to the tenant base
domain, not the env-prefixed LMS host. This matches the multisite middleware
and allows LMS, Studio, and MFE to share cookies even when the staging surface
mixes `staging.<tenant>` and `<service>.staging.<tenant>` host shapes.

---

## 6. Auth / Callback Expectations

All staging tenants use `staging.auth0.mereka.io` as the OIDC provider.

| Tenant | Login redirect chain |
|--------|---------------------|
| Mereka | staging.academyv2.mereka.io → LMS → staging.auth0.mereka.io → LMS → redirect back |
| Biji-Biji | staging.academy.biji-biji.com → LMS → staging.auth0.mereka.io → LMS → redirect back |
| SkillOurFuture | staging.skillourfuture.academy.mereka.io → LMS → staging.auth0.mereka.io → LMS → redirect back |

`LOGIN_REDIRECT_WHITELIST` must include all staging MFE and studio domains
so OAuth2 redirects complete correctly.

---

## 7. What GitOps Must Wire (Consumption Contract)

Once this contract is accepted, bbi-infrastructure must:

### Required now (P0)

| Item | File/Resource | Hostnames | Notes |
|------|---------------|-----------|-------|
| ALLOWED_HOSTS | `production-staging.py` | All 16 staging domains | See section 3 |
| CSRF/CORS origins | `production-staging.py` | All `https://` origins for staging domains | Mirror MEREKA_SITE_ORIGINS pattern |
| Cookie middleware | `production-staging.py` | Confirm runtime cookie scoping matches section 5 | See section 5 |
| Ingress TLS | staging ingress manifest | All 9 P0 staging domains | cert-manager Certificates |
| Caddy routing | staging Caddyfile patch | Tenant domains → same backends (lms:8000, cms:8000, mfe:8002) | Host-based routing |
| DNS records | Cloudflare | All 16 staging domains → staging ingress IP | A/CNAME records |
| Staging gate update | `verify-staging-activation-gate.sh` | Allow `staging.academy.biji-biji.com` pattern | Distinguish from bare prod domain |

### Required now (P1)

| Item | Notes |
|------|-------|
| `staging.preview.academyv2.mereka.io` in Ingress | Preview LMS for staging |
| `staging.discovery.academyv2.mereka.io` in Ingress | Discovery satellite |
| `staging.admin.academyv2.mereka.io` in Ingress | Enterprise admin portal |

### Deferred (P2)

| Item | Notes |
|------|-------|
| `staging.learner.academyv2.mereka.io` | Enterprise learner portal — low priority |
| `staging.notes.academyv2.mereka.io` | Notes satellite — low priority |
| `staging.credentials.academyv2.mereka.io` | Credentials satellite — low priority |

### TLS Expectations

| Domain Pattern | TLS Provider | Reason |
|----------------|-------------|--------|
| `staging.*.mereka.io` | Cloudflare proxy (orange cloud) | Covered by `*.mereka.io` wildcard |
| `staging.skillourfuture.academy.mereka.io` | Let's Encrypt via cert-manager | Multi-level subdomain, not covered by wildcard |
| `studio.staging.skillourfuture.academy.mereka.io` | Let's Encrypt via cert-manager | Multi-level subdomain |
| `apps.staging.skillourfuture.academy.mereka.io` | Let's Encrypt via cert-manager | Multi-level subdomain |
| `staging.academy.biji-biji.com` | Let's Encrypt via cert-manager | Third-party domain |
| `studio.staging.academy.biji-biji.com` | Let's Encrypt via cert-manager | Third-party domain |
| `apps.staging.academy.biji-biji.com` | Let's Encrypt via cert-manager | Third-party domain |

### DNS Expectations

All staging domains must resolve to the rke2-nonprod ingress IP (154.26.132.35).
Cloudflare-proxied domains use orange cloud. Let's Encrypt domains use DNS-only (gray cloud).

---

## 8. What Remains Unproven After GitOps Wiring

Even after GitOps wires all the above, the following remain unproven until
the staging proof suite runs:

| Item | What proves it |
|------|---------------|
| SiteConfiguration rows seeded in staging DB | `seed-siteconfigs.sh --namespace stg-mereka-lms --environment staging` |
| MFE config returns correct URLs per tenant | `/api/mfe_config/v1` with per-tenant Host headers |
| Cookie domain correct per tenant | `/csrf/api/v1/token` with per-tenant Host headers |
| OAuth2 redirect chain completes per tenant | End-to-end login flow |
| TLS terminates correctly per domain | External HTTPS probe |
| DNS resolves correctly per domain | External DNS probe |

---

## 9. Definition of Done for Staging Tenant Proof

All of the following must be true:

1. **Registry**: tenant-registry.yaml contains all staging domains (this commit)
2. **ALLOWED_HOSTS**: staging production.py includes all 16 staging tenant domains
3. **CSRF/CORS**: all staging tenant origins in CSRF_TRUSTED_ORIGINS and CORS_ORIGIN_WHITELIST
4. **Cookie middleware**: `_cookie_domain_for_host` returns correct domain for all staging hosts
5. **Ingress**: all P0 staging domains have TLS-terminated Ingress rules
6. **DNS**: all P0 staging domains resolve to 154.26.132.35
7. **SiteConfiguration**: seeded via `seed-siteconfigs.sh --environment staging`
8. **MFE config proof**: 3/3 staging tenants return correct LMS_BASE_URL and STUDIO_BASE_URL
9. **Cookie proof**: 3/3 staging tenants get correct cookie domain
10. **Enterprise**: staging.admin.academyv2.mereka.io returns valid MFE config (primary tenant only)

Items 1 is delivered by this commit. Items 2-6 require GitOps. Item 7 requires
seed script execution after items 2-6 are deployed. Items 8-10 are the proof gate.

---

## 10. Reclassification

- **Staging tenant proof**: blocked on missing canonical staging tenant domains in GitOps layer
- The app-side contract is now published (this document + tenant-registry.yaml)
- The blocker is NOT a GitOps failure or guard error
- The blocker is that staging tenant hostnames were never explicitly declared until now
- The staging activation gate policy is correct and must not be weakened
