# Domain Matrix

> Source of truth: `scripts/shared/config.sh` (45 domain variables)
> Verified by: `scripts/qa/verify-domain-url-invariants.sh` (74 checks)

## Primary Domains (Mereka Academy)

| Service | Production (GKE) | Dev (rke2-nonprod) | Staging (rke2-nonprod) |
|---|---|---|---|
| **LMS** | `academyv2.mereka.io` | `academyv2.mereka.dev` | `staging.academyv2.mereka.io` |
| **Studio** | `studio.academyv2.mereka.io` | `studio.academyv2.mereka.dev` | `studio.staging.academyv2.mereka.io` |
| **MFE** | `apps.academyv2.mereka.io` | `apps.academyv2.mereka.dev` | `apps.staging.academyv2.mereka.io` |
| **Auth (Authentik)** | `auth0.mereka.io` | `auth0.mereka.dev` | `staging.auth0.mereka.io` |
| **Preview** | `preview.academyv2.mereka.io` | `preview.academyv2.mereka.dev` | `preview.staging.academyv2.mereka.io` |
| **Discovery** | `discovery.academyv2.mereka.io` | `discovery.academyv2.mereka.dev` | `discovery.staging.academyv2.mereka.io` |
| **Notes** | `notes.academyv2.mereka.io` | `notes.academyv2.mereka.dev` | `notes.staging.academyv2.mereka.io` |
| **Credentials** | `credentials.academyv2.mereka.io` | `credentials.academyv2.mereka.dev` | `credentials.staging.academyv2.mereka.io` |
| **Forum** | `forum.academyv2.mereka.io` | `forum.academyv2.mereka.dev` | `forum.staging.academyv2.mereka.io` |
| **Ecommerce** (legacy) | `ecommerce.academyv2.mereka.io` | `ecommerce.academyv2.mereka.dev` | `ecommerce.staging.academyv2.mereka.io` |
| **Enterprise Admin** | `admin.academyv2.mereka.io` | `admin.academyv2.mereka.dev` | `admin.staging.academyv2.mereka.io` |
| **Enterprise Learner** | `enterprise.academyv2.mereka.io` | `learner.academyv2.mereka.dev` | `learner.staging.academyv2.mereka.io` |
| **Payments Gateway** | `payments.academyv2.mereka.io` | `payments.academyv2.mereka.dev` | `payments.staging.academyv2.mereka.io` |

**Total: 13 services x 3 environments = 39 domains**

## Multisite / Subsites (Production Only)

| Subsite | LMS | Studio | MFE |
|---|---|---|---|
| **Biji-Biji** | `academy.biji-biji.com` | `studio.academy.biji-biji.com` | `apps.academy.biji-biji.com` |
| **SkillOurFuture** | `skillourfuture.academy.mereka.io` | `studio.skillourfuture.academy.mereka.io` | `apps.skillourfuture.academy.mereka.io` |

**Total: 2 subsites x 3 domains = 6 domains**

## Naming Inconsistency

| Item | Issue | Status |
|---|---|---|
| Enterprise Learner portal | Prod uses `enterprise.*`, dev/staging use `learner.*` | **OPEN** — needs alignment |

`config.sh` defines `ENTERPRISE_PORTAL_DOMAIN=enterprise.academyv2.mereka.io` for prod, but dev/staging use `learner.*`. The ingresses, Caddy routes, and DNS all need to agree. Recommend standardising on `learner.*` everywhere (more descriptive), which requires updating the prod ingress and Caddy config.

## Operational Status (2026-03-05)

### Production (GKE) — LIVE

| Service | Pods | URL Status | Notes |
|---|---|---|---|
| LMS | 2/2 Running | 200 | |
| Studio | 1/1 Running | 200 | |
| MFE | via Caddy | 200 | |
| Enterprise Admin MFE | 1/1 Running | 200 | Served via Caddy enterprise route |
| Enterprise Learner MFE | 1/1 Running | 200 | Served via Caddy enterprise route |
| Enterprise Catalog | 1/1 Running | — | Backend API only |
| Enterprise Access | 1/1 Running | — | Backend API only |
| Enterprise Subsidy | 1/1 Running | — | Backend API only |
| License Manager | 1/1 Running | — | Backend API only |
| Biji-Biji | alias | 200 | Same Site as academyv2 |
| SkillOurFuture | alias | 200 | Same Site as academyv2 |

### Dev / rke2-nonprod — PARTIAL

| Service | Pods | URL Status | Notes |
|---|---|---|---|
| LMS | 1/1 Running | 200 | |
| Studio | 1/1 Running | 200 | |
| MFE | via Caddy | 200 | |
| Enterprise Admin MFE | 1/1 Running | **503** | Caddy routes `admin.*` to LMS instead of enterprise-admin-portal:8002 |
| Enterprise Learner MFE | 1/1 Running | **No ingress** | `learner.academyv2.mereka.dev` not in any ingress |
| Enterprise backends | 7 pods Running | — | Services exist, no external access needed |

**Root cause**: bbi-infrastructure's dev Caddy config merged `admin.academyv2.mereka.dev` into the LMS host matcher. It doesn't have the enterprise routing blocks that prod has. **Fix required in bbi-infrastructure** (add enterprise Caddy routes for dev).

### Staging — NOT DEPLOYED

Overlay is ready in this repo but staging is not yet deployed via ArgoCD. Requires:
1. ArgoCD Application for staging namespace
2. DNS records for `staging.academyv2.mereka.io` and subdomains
3. TLS certificates (cert-manager will handle via letsencrypt-prod)

## Subsite Coverage Gaps

### What subsites get today (prod)

| Feature | Biji-Biji | SkillOurFuture |
|---|---|---|
| LMS (own domain) | `academy.biji-biji.com` | `skillourfuture.academy.mereka.io` |
| Studio | `studio.academy.biji-biji.com` | `studio.skillourfuture.academy.mereka.io` |
| MFE | `apps.academy.biji-biji.com` | `apps.skillourfuture.academy.mereka.io` |
| Ingress + TLS | Yes (shared cert) | Yes (shared cert) |
| Caddy routing | Yes (host matcher) | Yes (host matcher) |
| ALLOWED_HOSTS | Yes | Yes |
| CSRF trusted origins | Yes | Yes |
| Own design system | **No** — shares Mereka theme | **No** — shares Mereka theme |
| Own enterprise services | **No** — shared | **No** — shared |
| Own discovery/notes/etc | **No** — shared | **No** — shared |
| Dev/staging domains | **No** — prod only | **No** — prod only |

### What subsites DON'T have

1. **No dev/staging domains** — `academy.biji-biji.com` has no dev equivalent. Testing happens on the prod LMS with the alternate domain.
2. **No own design system** — Both subsites share the Mereka comprehensive theme. Tenant-level branding (logo, colours) is via Open edX Site Configuration, not a separate theme.
3. **No own enterprise services** — Enterprise admin/learner/catalog/subsidy are per-platform, not per-tenant. EnterpriseCustomer records in the LMS DB scope enterprise features to the correct tenant.
4. **No own auxiliary services** — Discovery, notes, credentials, forum, ecommerce, payments are all shared platform services. Tenant isolation is at the application layer (Sites framework + TenantConfig), not at the infrastructure layer.

### Is this a problem?

**For current subsites (alias domains)**: No. Biji-Biji and SkillOurFuture are alias domains for the same Mereka Academy Site. They don't need separate infra.

**For future enterprise subsites (dedicated tenants)**: Depends on the isolation model:
- **Shared platform, separate branding** (current approach): New tenant gets a domain (`acme.academyv2.mereka.io`), a Site record, a TenantConfig, and brand assets. No new infra needed. This is what the multi-tenancy foundation supports.
- **Dedicated infrastructure per tenant**: Each tenant would need their own service stack, databases, secrets. This is NOT the current architecture and would be a major change.

## Infrastructure Ownership

| Component | Owner | Repo |
|---|---|---|
| Domain variables | mereka-lms | `scripts/shared/config.sh` |
| K8s overlays | mereka-lms | `deploy/k8s/overlays/` |
| Caddy routing config | bbi-infrastructure | `apps/mereka-lms/overlays/*/caddy/` |
| Ingress resources | Split | mereka-lms defines, bbi-infrastructure may override |
| DNS records | bbi-infrastructure | Cloudflare IaC |
| TLS certificates | Automatic | cert-manager + letsencrypt-prod |
| ArgoCD Applications | bbi-infrastructure | ApplicationSet `bbi-kustomize-apps` |

## Action Items

| # | Item | Owner | Priority |
|---|---|---|---|
| 1 | Fix enterprise learner portal naming: standardise `enterprise.*` or `learner.*` across all envs | mereka-lms + bbi-infrastructure | Medium |
| 2 | Add enterprise Caddy routes to dev Caddy config (fixes admin/learner 503 on dev) | bbi-infrastructure | High |
| 3 | Deploy staging overlay via ArgoCD | bbi-infrastructure | Medium |
| 4 | Add dev/staging DNS records for staging.academyv2.mereka.io subdomains | bbi-infrastructure | Medium |
| 5 | Decide: do subsites (biji-biji, skillourfuture) need dev/staging domains? | Product decision | Low |
