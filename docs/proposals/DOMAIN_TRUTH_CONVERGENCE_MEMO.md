# Domain Truth Convergence Memo

_Date: 2026-04-01 | Registry version: 1.5.0 | 100 domains (97 active, 3 deprecated)_

## Current Deployed Truth by Tenant

### Mereka Academy (primary tenant)

**13 active production domains** covering all surfaces:
- `academyv2.mereka.io` (LMS), `studio.*`, `apps.*`, `preview.*`
- `discovery.*`, `notes.*`, `credentials.*`, `forum.*`
- `admin.*` (enterprise admin), `learner.*` (enterprise learner)
- `analytics.*` (Superset, dormant per ADR-017)
- `auth0.mereka.io` (shared OIDC)
- `ecommerce.*` (deprecated)

### Biji-Biji Academy

**3 active production domains** (LMS, Studio, MFE):
- `academy.biji-biji.com`, `studio.academy.biji-biji.com`, `apps.academy.biji-biji.com`

Enterprise admin/learner, credentials, analytics, preview: **not deployed** — currently uses shared Mereka hostnames.

### Skill Our Future

**1 active production domain** (LMS only):
- `skillourfuture.academy.mereka.io`

Studio and MFE are `planned` (no TLS, not routable). All other surfaces use shared Mereka hostnames.

---

## Target Host-Intent Truth by Tenant

### Target Model

Per-tenant surfaces (every tenant gets these in target state):
- primary, studio, mfe, preview
- enterprise-admin, enterprise-learner, credentials, analytics

Target-state intent ratified by the domain truth convergence tranche.
Current runtime remains shared for enterprise-admin/learner/credentials/analytics
until realization.

Shared-by-design (not per-tenant):
- discovery (backend API, users never visit)
- notes (backend API, users never visit)
- forum (in-process LMS alias, discussions via course pages)
- auth (shared Authentik OIDC)
- ecommerce (deprecated)

### Mereka — target = current (no gap)

All 8 per-tenant surfaces are active.

### Biji-Biji — 8 per-tenant surfaces (4 active, 4 planned)

| Role | Hostname | Status |
|------|----------|--------|
| primary | `academy.biji-biji.com` | **active** |
| studio | `studio.academy.biji-biji.com` | **active** |
| mfe | `apps.academy.biji-biji.com` | **active** |
| preview | `preview.academy.biji-biji.com` | planned |
| enterprise-admin | `admin.academy.biji-biji.com` | planned (current runtime shared) |
| enterprise-learner | `learner.academy.biji-biji.com` | planned (current runtime shared) |
| credentials | `credentials.academy.biji-biji.com` | planned (current runtime shared) |
| analytics | `analytics.academy.biji-biji.com` | planned (current runtime shared) |

### Skill Our Future — 8 per-tenant surfaces at NEW root (1 active at legacy, rest planned)

| Role | Current Hostname | Target Hostname | Status |
|------|-----------------|----------------|--------|
| primary | `skillourfuture.academy.mereka.io` | `skillourfuture.academyv2.mereka.io` | **migration** |
| studio | — | `studio.skillourfuture.academyv2.mereka.io` | planned |
| mfe | — | `apps.skillourfuture.academyv2.mereka.io` | planned |
| preview | — | `preview.skillourfuture.academyv2.mereka.io` | planned |
| enterprise-admin | shared | `admin.skillourfuture.academyv2.mereka.io` | planned (current runtime shared) |
| enterprise-learner | shared | `learner.skillourfuture.academyv2.mereka.io` | planned (current runtime shared) |
| credentials | shared | `credentials.skillourfuture.academyv2.mereka.io` | planned (current runtime shared) |
| analytics | shared | `analytics.skillourfuture.academyv2.mereka.io` | planned (current runtime shared) |

---

## SOF Root Migration Gap

| Dimension | Current | Target |
|-----------|---------|--------|
| Root | `skillourfuture.academy.mereka.io` | `skillourfuture.academyv2.mereka.io` |
| Cookie domain | `.skillourfuture.academy.mereka.io` | `.skillourfuture.academyv2.mereka.io` |
| Dev root | `skillourfuture.academyv2.mereka.dev` | same (**already on target**) |
| Staging root | `staging.skillourfuture.academy.mereka.io` | `staging.skillourfuture.academyv2.mereka.io` |

**Registry approach**: Current active entries preserved at legacy root. Target entries added as `planned`. Generators prefer `active` over `planned` to avoid breaking current deployments. Migration proceeds when DNS/TLS/Ingress are ready.

**Affected files outside registry**: `tenant-contracts.yml`, `multisite-sites.yml`, `skillourfuture-mfe-env.js`, bbi-infrastructure overlays, Cloudflare DNS records.

---

## Shared-by-Design Surfaces

| Surface | Why shared is correct |
|---------|----------------------|
| discovery | Backend catalog API. Users never visit. Enterprise-catalog scopes by UUID. |
| notes | Backend annotation API. Users never visit. Scoped by user_id + course_id. |
| forum | In-process LMS alias. Discussions accessed via LMS course pages. Thread visibility is data-scoped (course), not hostname-scoped. |
| auth | Shared Authentik OIDC. Transparent redirect. |
| ecommerce | Deprecated. Replaced by payments-gateway. |

---

## Target Surfaces Not Yet Realized

| Surface | Tenant | Required Work | Owner |
|---------|--------|---------------|-------|
| preview | BB | DNS, TLS, Ingress | infra + DNS admin |
| preview | SOF | DNS, TLS, Ingress (new root) | infra + DNS admin |
| enterprise-admin | BB | DNS, TLS, Caddy env, MFE config | infra + app repo |
| enterprise-admin | SOF | DNS, TLS, Caddy env, MFE config (new root) | infra + app repo |
| enterprise-learner | BB | DNS, TLS, Caddy env, MFE config | infra + app repo |
| enterprise-learner | SOF | DNS, TLS, Caddy env, MFE config (new root) | infra + app repo |
| credentials | BB | DNS, TLS, Caddy routing, satellite ALLOWED_HOSTS | infra + app repo |
| credentials | SOF | DNS, TLS, Caddy routing (new root) | infra + app repo |
| analytics | BB | DNS, TLS, Ingress host rule, Superset CORS | infra + app repo |
| analytics | SOF | DNS, TLS, Ingress host rule (new root) | infra + app repo |
| analytics | Mereka (prod) | ADR-017 defers activation until criteria met | product decision |
| SOF primary | SOF | Root migration: DNS → TLS → ALLOWED_HOSTS → SiteConfiguration → redirect | all repos |
| SOF studio/mfe | SOF | Root migration + TLS + Ingress | infra + DNS admin |

---

## Next-Step Owners per Gap

| Repo | What to do |
|------|-----------|
| **mereka-lms** | Registry is updated (this PR). MFE env files need target-root URLs when migration begins. |
| **platform-control-plane** | `admin` and `analytics` added to service prefix policy (this session). DNS records needed when realization begins. |
| **bbi-infrastructure** | Ingress resources, Caddy env patches, and TLS certs for each new per-tenant hostname. Largest volume of work. |
| **Cloudflare** | DNS records for all planned hostnames (~30 new records across zones). |

---

## What Changed in This Session

### Registry (v1.3.0 → v1.5.0)
- **+28 new domain entries**: per-tenant enterprise-admin, enterprise-learner, credentials, analytics for BB and SOF across prod/dev/staging, plus SOF migration target entries
- **4 entries updated**: SOF planned entries moved from legacy root to target root
- **Analytics role added**: 3 entries for Mereka (prod/dev/staging) — previously missing from registry despite DNS records existing
- **SOF target_site_domain**: added to tenants section for migration tracking

### Generators
- `generate_config_domains.py`: fixed to prefer `active` over `planned` entries when duplicate (env, tenant, role) keys exist
- `generate_domain_env.py`: same fix applied to both `build_domain_index` and `build_cookie_index`

### Control-plane
- `tenant-domain-authority.yaml`: added `admin` and `analytics` service prefixes, added staging environment host template

### Validation
- All gates pass: 133 PASS URL invariants, 15 PASS authority chain, 6 PASS generated surfaces, 15 PASS DNS inventory
