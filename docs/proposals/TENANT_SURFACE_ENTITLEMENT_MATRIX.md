# Tenant Surface Entitlement Matrix

_Date: 2026-04-01 | Status: proposed | Owner: Platform Team_

This document answers four questions:

1. What domains does each tenant get **today** (current deployed truth)?
2. What domains **should** each tenant get (target host-intent truth)?
3. What is the **exact gap** between current and target?
4. Which **repo owns** each part of the truth?

Every decision cites the evidence file that proves it.

---

## Methodology

For each surface, three independent assessments:

- **Is a per-tenant hostname meaningful?** Does it improve user experience, branding,
  or cookie/session behavior? (Shared deployment does NOT automatically mean shared hostname.)
- **Is it architecturally feasible?** Can Caddy/Ingress/SiteConfiguration route it?
- **Is it current reality, or only target intent?**

---

## 1. Surface Analysis

### Per-Tenant Surfaces (Target: Every Tenant Gets These)

#### primary (LMS)

| Dimension | Value |
|-----------|-------|
| Per-tenant hostname meaningful? | **YES** — learners visit this URL directly; branding/theme resolution via Host→SiteConfiguration |
| Architecturally feasible? | YES — proven today for all 3 tenants |
| Current deployed? | YES — all 3 tenants in prod, dev, staging |
| Target model | Tenant-hosted |
| Evidence | `tenant-registry.yaml` (active entries), `infrastructure/tutor/multisite-sites.yml` |

#### studio

| Dimension | Value |
|-----------|-------|
| Per-tenant hostname meaningful? | **YES** — course creators visit this URL; org_filter scopes authoring |
| Architecturally feasible? | YES — same mechanism as LMS (Host header → SiteConfiguration) |
| Current deployed? | Mereka: active. BB: active. SOF: **planned** (no TLS, not routable in prod) |
| Target model | Tenant-hosted |
| Evidence | `tenant-registry.yaml`, `skillourfuture-mfe-env.js` (references studio URL) |

#### mfe (apps)

| Dimension | Value |
|-----------|-------|
| Per-tenant hostname meaningful? | **YES** — learners visit this URL; MFE Config API returns tenant-scoped values per Host |
| Architecturally feasible? | YES — proven for Mereka/BB |
| Current deployed? | Mereka: active. BB: active. SOF: **planned** (no TLS in prod) |
| Target model | Tenant-hosted |
| Evidence | `tenant-registry.yaml`, `scripts/qa/verify-mfe-config-api.sh` |

#### preview

| Dimension | Value |
|-----------|-------|
| Per-tenant hostname meaningful? | **YES** — Studio "View Live" redirects to PREVIEW_LMS_BASE. Must share tenant cookie domain for session continuity. |
| Architecturally feasible? | YES — routes to LMS, same as primary (caddy_backend: lms:8000) |
| Current deployed? | Mereka: active. BB: **not deployed**. SOF: **not deployed**. |
| Target model | Tenant-hosted (follows studio lifecycle) |
| Evidence | Cookie domain mismatch without per-tenant preview; Caddy routes `preview.*` to LMS |

#### enterprise-admin

| Dimension | Value |
|-----------|-------|
| Per-tenant hostname meaningful? | **YES** — admin users visit this dashboard. Per-tenant URL improves branding and cookie domain alignment. |
| Architecturally feasible? | **YES** — Caddy has `{$ENTERPRISE_ADMIN_HOST}` env var. Per-tenant MFE env files exist as reference. |
| Current deployed? | **Mereka only** — `admin.academyv2.mereka.io`. BB and SOF currently share Mereka's admin domain. |
| Target model | **Tenant-hosted (planned)** — target-state intent ratified by domain truth convergence tranche |
| Evidence | Caddy `{$ENTERPRISE_ADMIN_HOST}` supports per-tenant routing. Per-tenant MFE env files exist (`biji-biji-mfe-env.js`, `skillourfuture-mfe-env.js`). ADR-024 slug routing coexists with per-tenant hostnames. |
| Key nuance | Current runtime is shared. Target-state intent is tenant-specific. Realization requires DNS, TLS, Caddy routing, and MFE env config deployment. |

#### enterprise-learner

| Dimension | Value |
|-----------|-------|
| Per-tenant hostname meaningful? | **YES** — learners visit this portal to browse enterprise catalog. Branded URL improves UX. |
| Architecturally feasible? | **YES** — same as admin: Caddy `{$ENTERPRISE_LEARNER_HOST}`, per-tenant MFE env files exist. |
| Current deployed? | **Mereka only** — `learner.academyv2.mereka.io`. BB and SOF currently share Mereka's learner domain. |
| Target model | **Tenant-hosted (planned)** — target-state intent ratified by domain truth convergence tranche |
| Evidence | Same infrastructure as enterprise-admin. Current runtime shared. Target-state intent is tenant-specific. Realization work remains. |

#### credentials

| Dimension | Value |
|-----------|-------|
| Per-tenant hostname meaningful? | **YES** — public certificate verification URLs appear in emails and LinkedIn. `credentials.academy.biji-biji.com/credentials/{uuid}/` is better branding than a shared Mereka URL. |
| Architecturally feasible? | **YES** — Caddy uses `{$CREDENTIALS_HOST}`. Routing is straightforward since all credential UUIDs resolve from the same DB regardless of hostname. |
| Current deployed? | **Mereka only** — `credentials.academyv2.mereka.io`. BB and SOF currently share. |
| Target model | **Tenant-hosted (planned)** — target-state intent ratified by domain truth convergence tranche |
| Evidence | Caddy supports per-host routing via `{$CREDENTIALS_HOST}`. Current runtime shared. Target-state intent is tenant-specific. Realization requires DNS, TLS, Caddy routing, satellite ALLOWED_HOSTS. |

#### analytics

| Dimension | Value |
|-----------|-------|
| Per-tenant hostname meaningful? | **YES** — admins and instructors visit the Superset dashboard. Per-tenant branded access improves UX. |
| Architecturally feasible? | **YES** — Superset has its own Ingress. Adding tenant hostnames requires Ingress host rules + Superset CSRF/CORS config. RLS provides data isolation regardless of hostname. |
| Current deployed? | **Mereka only** — `analytics.academyv2.mereka.io` (prod dormant per ADR-017), `analytics.academyv2.mereka.dev` (dev active). BB and SOF currently share. |
| Target model | **Tenant-hosted (planned)** — target-state intent ratified by domain truth convergence tranche |
| Evidence | Mereka DNS exists (`infrastructure/cloudflare/records.json`). Current BB/SOF runtime shared. Target-state intent is tenant-specific. Realization requires DNS, TLS, Ingress host rules, Superset CORS. |

### Shared-by-Design Surfaces

#### discovery

| Dimension | Value |
|-----------|-------|
| Per-tenant hostname meaningful? | **NO** — discovery is a backend catalog API. Users never navigate to `discovery.*` in a browser. MFEs call it via AJAX (CORS configured). No user-visible branding value. |
| Architecturally feasible? | Yes (just routing) but pointless |
| Current deployed? | Mereka only. Shared-by-design. |
| Target model | **Shared-by-design** |
| Evidence | `enterprise-microservices_spec.md`: enterprise-catalog provides tenant scoping by UUID. `tenant-registry.yaml` notes: "Discovery has own ALLOWED_HOSTS via satellite config." |

#### notes

| Dimension | Value |
|-----------|-------|
| Per-tenant hostname meaningful? | **NO** — notes is a backend API for student annotations. Users never visit `notes.*` directly. The annotation UI is embedded in LMS courseware. No user-visible branding value. |
| Architecturally feasible? | Yes but pointless |
| Current deployed? | Mereka only. Shared-by-design. |
| Target model | **Shared-by-design** |
| Evidence | `tenant-registry.yaml` notes: "Notes has own ALLOWED_HOSTS via satellite config." |

#### forum

| Dimension | Value |
|-----------|-------|
| Per-tenant hostname meaningful? | **NO** — Forum v2 runs in-process with LMS (`caddy_backend: lms:8000`). A per-tenant forum hostname is just another LMS alias. Users access discussions via `/courses/{course}/discussion/` within the LMS, not by navigating to `forum.*`. Thread visibility is course-scoped, not hostname-scoped. |
| Architecturally feasible? | Trivially (it's an LMS alias) |
| Current deployed? | Mereka only (dev/staging/prod). |
| Target model | **Not meaningful to split** — forum content is accessed through LMS course pages, not a standalone surface |
| Evidence | `Caddyfile` shows discussion APIs at `/api/discussion/` under LMS. `multi-tenancy-architecture_spec.md` Open Question #3 on forum thread isolation. |
| Key nuance | Forum thread isolation is a data problem (course-scoping), not a hostname problem. Adding `forum.academy.biji-biji.com` would route to the same LMS serving the same course-scoped threads. |

#### auth

| Dimension | Value |
|-----------|-------|
| Per-tenant hostname meaningful? | **NO** — Authentik is a single OIDC provider. All tenants authenticate through the same Authentik instance. Users are redirected transparently — they don't choose or notice the auth hostname. |
| Architecturally feasible? | Would require separate Authentik applications/providers per tenant |
| Current deployed? | Shared: `auth0.mereka.io` (prod), `auth0.mereka.dev` (dev), `staging.auth0.mereka.io` (staging) |
| Target model | **Shared-by-design** |
| Evidence | `tenant-registry.yaml`: "Authentik OIDC provider. External to this deployment." |

#### ecommerce (deprecated)

| Dimension | Value |
|-----------|-------|
| Per-tenant hostname meaningful? | N/A — service is deprecated |
| Target model | **Deprecated** — being replaced by payments-gateway |
| Evidence | `tenant-registry.yaml`: `status: deprecated` |

---

## 2. Target Hostname Sets by Tenant

### SOF Root Migration

**Current deployed root**: `skillourfuture.academy.mereka.io`
**Target root**: `skillourfuture.academyv2.mereka.io`

The dev environment already uses the target pattern (`skillourfuture.academyv2.mereka.dev`).
Production and staging use the legacy root. This is a real migration that requires:
- New DNS records for all target hostnames
- TLS certificates for all target hostnames
- SiteConfiguration updates (Site.domain)
- ALLOWED_HOSTS / CORS / CSRF updates
- Cookie domain change: `.skillourfuture.academy.mereka.io` → `.skillourfuture.academyv2.mereka.io`
- Redirect from old to new (optional, but good practice)

### Mereka Academy (primary tenant)

Mereka gets every deployed surface. No gaps for core surfaces.

#### Production

| Role | Current Hostname | Target Hostname | Status |
|------|-----------------|----------------|--------|
| primary | `academyv2.mereka.io` | same | active |
| studio | `studio.academyv2.mereka.io` | same | active |
| mfe | `apps.academyv2.mereka.io` | same | active |
| preview | `preview.academyv2.mereka.io` | same | active |
| discovery | `discovery.academyv2.mereka.io` | same (shared) | active |
| notes | `notes.academyv2.mereka.io` | same (shared) | active |
| credentials | `credentials.academyv2.mereka.io` | same | active |
| forum | `forum.academyv2.mereka.io` | same (shared) | active |
| enterprise-admin | `admin.academyv2.mereka.io` | same | active |
| enterprise-learner | `learner.academyv2.mereka.io` | same | active |
| analytics | `analytics.academyv2.mereka.io` | same | active (dormant replicas) |
| auth | `auth0.mereka.io` | same (shared) | active |
| ecommerce | `ecommerce.academyv2.mereka.io` | same | deprecated |

### Biji-Biji Academy (partner tenant)

#### Production

| Role | Current Hostname | Target Hostname | Current Status | Target Status | Gap |
|------|-----------------|----------------|----------------|---------------|-----|
| primary | `academy.biji-biji.com` | same | active | active | none |
| studio | `studio.academy.biji-biji.com` | same | active | active | none |
| mfe | `apps.academy.biji-biji.com` | same | active | active | none |
| preview | — | `preview.academy.biji-biji.com` | — | **planned** | DNS, TLS, Ingress |
| enterprise-admin | (shared: `admin.academyv2.mereka.io`) | `admin.academy.biji-biji.com` | shared | **planned** | DNS, TLS, Caddy routing, MFE env config |
| enterprise-learner | (shared: `learner.academyv2.mereka.io`) | `learner.academy.biji-biji.com` | shared | **planned** | DNS, TLS, Caddy routing, MFE env config |
| credentials | (shared: `credentials.academyv2.mereka.io`) | `credentials.academy.biji-biji.com` | shared | **planned** | DNS, TLS, Caddy routing, satellite ALLOWED_HOSTS |
| analytics | (shared: `analytics.academyv2.mereka.io`) | `analytics.academy.biji-biji.com` | shared | **planned** | DNS, TLS, Ingress host rule, Superset CORS |

#### Dev

| Role | Current Hostname | Target Hostname | Status |
|------|-----------------|----------------|--------|
| primary | `biji-biji.academyv2.mereka.dev` | same | active |
| studio | `studio.biji-biji.academyv2.mereka.dev` | same | active |
| mfe | `apps.biji-biji.academyv2.mereka.dev` | same | active |
| preview | — | `preview.biji-biji.academyv2.mereka.dev` | **planned** |

#### Staging

| Role | Current Hostname | Target Hostname | Status |
|------|-----------------|----------------|--------|
| primary | `staging.academy.biji-biji.com` | same | active |
| studio | `studio.staging.academy.biji-biji.com` | same | active |
| mfe | `apps.staging.academy.biji-biji.com` | same | active |
| preview | — | `preview.staging.academy.biji-biji.com` | **planned** |

### Skill Our Future (partner tenant)

#### Production — includes root migration

| Role | Current Hostname | Target Hostname | Current Status | Target Status | Gap |
|------|-----------------|----------------|----------------|---------------|-----|
| primary | `skillourfuture.academy.mereka.io` | `skillourfuture.academyv2.mereka.io` | active | **planned** | DNS, TLS, SiteConfiguration, root migration |
| studio | `studio.skillourfuture.academy.mereka.io` | `studio.skillourfuture.academyv2.mereka.io` | planned | **planned** | DNS, TLS, Ingress, root migration |
| mfe | `apps.skillourfuture.academy.mereka.io` | `apps.skillourfuture.academyv2.mereka.io` | planned | **planned** | DNS, TLS, Ingress, root migration |
| preview | — | `preview.skillourfuture.academyv2.mereka.io` | — | **planned** | DNS, TLS, Ingress |

#### Dev (already on target root pattern)

| Role | Current Hostname | Target Hostname | Status |
|------|-----------------|----------------|--------|
| primary | `skillourfuture.academyv2.mereka.dev` | same | active |
| studio | `studio.skillourfuture.academyv2.mereka.dev` | same | active |
| mfe | `apps.skillourfuture.academyv2.mereka.dev` | same | active |
| preview | — | `preview.skillourfuture.academyv2.mereka.dev` | **planned** |

#### Staging — includes root migration

| Role | Current Hostname | Target Hostname | Status |
|------|-----------------|----------------|--------|
| primary | `staging.skillourfuture.academy.mereka.io` | `staging.skillourfuture.academyv2.mereka.io` | active → **planned** |
| studio | `studio.staging.skillourfuture.academy.mereka.io` | `studio.staging.skillourfuture.academyv2.mereka.io` | active → **planned** |
| mfe | `apps.staging.skillourfuture.academy.mereka.io` | `apps.staging.skillourfuture.academyv2.mereka.io` | active → **planned** |
| preview | — | `preview.staging.skillourfuture.academyv2.mereka.io` | **planned** |

---

## 3. SOF Root Migration Detail

### What changes

| Dimension | Current (legacy) | Target |
|-----------|-----------------|--------|
| Root | `skillourfuture.academy.mereka.io` | `skillourfuture.academyv2.mereka.io` |
| Cookie domain | `.skillourfuture.academy.mereka.io` | `.skillourfuture.academyv2.mereka.io` |
| Django Site.domain | `skillourfuture.academy.mereka.io` | `skillourfuture.academyv2.mereka.io` |
| Tenant slug in registry | `skillourfuture` | `skillourfuture` (unchanged) |
| Staging root | `staging.skillourfuture.academy.mereka.io` | `staging.skillourfuture.academyv2.mereka.io` |
| Dev root | `skillourfuture.academyv2.mereka.dev` | same (**already on target pattern**) |

### What must happen per repo

| Repo | What changes | Owner |
|------|-------------|-------|
| mereka-lms | `tenant-registry.yaml`: add target entries (planned), keep legacy entries until migrated | app repo |
| mereka-lms | `tenant-contracts.yml`: update site_domain | app repo |
| mereka-lms | `infrastructure/tutor/multisite-sites.yml`: update Site.domain | app repo |
| mereka-lms | `skillourfuture-mfe-env.js`: update LMS_BASE_URL, STUDIO_BASE_URL | app repo |
| bbi-infrastructure | Ingress TLS subjects, Caddy env patches, ALLOWED_HOSTS | infra repo |
| platform-control-plane | DNS records, TLS cert policy | control-plane |
| Cloudflare | New DNS records for `*.skillourfuture.academyv2.mereka.io` | DNS admin |

### Migration approach

1. **Add target entries** to registry as `planned`
2. **Create DNS records** for target hostnames (DNS-only, Let's Encrypt)
3. **Create TLS certs** via cert-manager
4. **Add ALLOWED_HOSTS** for target hostnames
5. **Update SiteConfiguration** to target hostname
6. **Verify** target responds correctly
7. **Update SiteConfiguration** Site.domain to target hostname
8. **Flip status**: target → `active`, legacy → `deprecated`
9. **Remove deprecated** entries when no longer referenced

---

## 4. Shared-by-Design Declaration

These surfaces remain at a single shared hostname across all tenants. This is an
intentional architectural decision, not an implementation gap.

| Surface | Shared hostname | Why shared is correct |
|---------|----------------|----------------------|
| discovery | `discovery.academyv2.{io,dev}` | Backend API. Users never visit. Catalog filtering is at enterprise-catalog layer by UUID. |
| notes | `notes.academyv2.{io,dev}` | Backend API. Users never visit. Annotations are user_id + course_id scoped. |
| forum | `forum.academyv2.{io,dev}` | In-process LMS alias. Discussions accessed via `/courses/{course}/discussion/` in LMS. Thread isolation is data (course-scoped), not hostname. |
| auth | `auth0.{mereka.io,mereka.dev}` | Shared Authentik OIDC provider. Transparent redirect. |
| ecommerce | `ecommerce.academyv2.mereka.io` | Deprecated. Replaced by payments-gateway. |

---

## 5. Authority Ownership

| Truth plane | Canonical source | Repo |
|-------------|-----------------|------|
| Host intent (which domains exist) | `deploy/k8s/tenancy/tenant-registry.yaml` | mereka-lms |
| Tenant metadata (slug, name, contact) | `infrastructure/tenants/tenant-contracts.yml` | mereka-lms |
| DNS/TLS pattern governance | `contracts/tenant-domain-authority.yaml` | platform-control-plane |
| Environment realization | overlay patches, Ingress, Caddy env | bbi-infrastructure |
| Runtime truth | DNS resolution, HTTPS, proof scripts | generated artifacts |

---

## 6. Realization Gap Summary

### Surfaces with target hostnames not yet realized

| Surface | Tenant | Target Hostname | Required Work |
|---------|--------|----------------|---------------|
| preview | BB | `preview.academy.biji-biji.com` | DNS + TLS + Ingress |
| preview | SOF | `preview.skillourfuture.academyv2.mereka.io` | DNS + TLS + Ingress (new root) |
| enterprise-admin | BB | `admin.academy.biji-biji.com` | DNS + TLS + Caddy routing + MFE env |
| enterprise-admin | SOF | `admin.skillourfuture.academyv2.mereka.io` | DNS + TLS + Caddy routing + MFE env (new root) |
| enterprise-learner | BB | `learner.academy.biji-biji.com` | DNS + TLS + Caddy routing + MFE env |
| enterprise-learner | SOF | `learner.skillourfuture.academyv2.mereka.io` | DNS + TLS + Caddy routing + MFE env (new root) |
| credentials | BB | `credentials.academy.biji-biji.com` | DNS + TLS + Caddy routing + satellite ALLOWED_HOSTS |
| credentials | SOF | `credentials.skillourfuture.academyv2.mereka.io` | DNS + TLS + Caddy routing + satellite ALLOWED_HOSTS (new root) |
| analytics | BB | `analytics.academy.biji-biji.com` | DNS + TLS + Ingress host rule + Superset CORS |
| analytics | SOF | `analytics.skillourfuture.academyv2.mereka.io` | DNS + TLS + Ingress host rule + Superset CORS (new root) |
| analytics | Mereka | `analytics.academyv2.mereka.io` | Prod dormant (ADR-017) — surface exists, replicas at 0 |

### SOF root migration (prod + staging)

All SOF surfaces under `*.skillourfuture.academy.mereka.io` need migration to
`*.skillourfuture.academyv2.mereka.io`. Dev is already on the target pattern.

| Current (legacy) | Target | Environment |
|-----------------|--------|-------------|
| `skillourfuture.academy.mereka.io` | `skillourfuture.academyv2.mereka.io` | prod |
| `studio.skillourfuture.academy.mereka.io` | `studio.skillourfuture.academyv2.mereka.io` | prod |
| `apps.skillourfuture.academy.mereka.io` | `apps.skillourfuture.academyv2.mereka.io` | prod |
| `staging.skillourfuture.academy.mereka.io` | `staging.skillourfuture.academyv2.mereka.io` | staging |
| `studio.staging.skillourfuture.academy.mereka.io` | `studio.staging.skillourfuture.academyv2.mereka.io` | staging |
| `apps.staging.skillourfuture.academy.mereka.io` | `apps.staging.skillourfuture.academyv2.mereka.io` | staging |

---

## 7. Control-Plane Policy Gaps

`platform-control-plane/contracts/tenant-domain-authority.yaml` needs these updates:

| Gap | Required change |
|-----|----------------|
| Missing `admin` service prefix | Add `admin` to allowed service prefixes |
| Missing `analytics` service prefix | Add `analytics` to allowed service prefixes |
| Missing `forum` service prefix | Add `forum` if it remains in the registry (shared or otherwise) |
| SOF root pattern | Update or add pattern for `skillourfuture.academyv2.{base_domain}` |
