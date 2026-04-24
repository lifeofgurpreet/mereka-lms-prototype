---
title: Tenant Domain Migration Runbook
type: runbook
owner: platform
status: active
last_verified: 2026-04-21
---

# Tenant Domain Migration Runbook

Canonical procedure for migrating an LMS tenant from one domain tree to
another without breaking auth, MFE flows, or existing user sessions.

## When to use this

- Onboarding a tenant on a Mereka-owned subdomain, later moving them to
  their own domain (e.g. `new-tenant.academy.mereka.io` → `academy.new-tenant.com`).
- Consolidating tenants onto a shared domain tree (e.g. the 2026 SOF
  migration from `academy.mereka.io` → `academyv2.mereka.io`).
- Rebranding a tenant.
- Retiring a legacy domain tree after a platform upgrade.

If you are just *adding* a new tenant on a greenfield domain, use the
**Tenant Onboarding** runbook instead. This runbook assumes there is an
existing tenant whose live URL is about to change.

## The domain graph — what actually has to move

Tenant identity is expressed across ~15 coordinated surfaces. A tenant
domain migration is defined to be **complete** only when every one of
these points at the new tree. A domain change that touches three of
them is a drift, not a migration.

| # | Surface | Location | Owner |
|---|---------|----------|-------|
| 1 | Source-of-truth tenant registry | `deploy/k8s/tenancy/tenant-registry.yaml` (app repo) | app |
| 2 | Tenant-registry ConfigMap (runtime) | `deploy/k8s/base/apps/multi-tenancy/configmap-tenants.yaml` | app |
| 3 | Django LMS `ALLOWED_HOSTS` + `CSRF_TRUSTED_ORIGINS` + `CORS_ORIGIN_WHITELIST` | `deploy/k8s/base/apps/openedx/settings/lms/production.py` | app |
| 4 | Django CMS `ALLOWED_HOSTS` + `CSRF_TRUSTED_ORIGINS` | `deploy/k8s/base/apps/openedx/settings/cms/production.py` | app |
| 5 | Multisite cookie-domain policy | `deploy/k8s/base/apps/openedx/settings/lms/mereka_multisite.py` + tests | app |
| 6 | Enterprise MFE env file | `deploy/k8s/base/apps/enterprise/mfe/<tenant>-mfe-env.js` | app |
| 7 | Caddyfile virtual host | `infrastructure/tutor/plugins/_mereka_lms/caddy.py` (if applicable) | app |
| 8 | SiteConfiguration rows (LMS + apps) | Django DB — 2 rows per tenant | runtime |
| 9 | OAuth2 Application redirect URIs | Django DB (`oauth2_provider_application`) | runtime |
| 10 | Kubernetes Ingress hosts | `apps/mereka-lms/overlays/<env>/` (bbi-infrastructure) | infra |
| 11 | cert-manager Certificate SANs | same overlay dir (bbi-infrastructure) | infra |
| 12 | DNS (Cloudflare A/CNAME) | Cloudflare console + Infisical CF tokens | infra |
| 13 | Authentik OIDC Application redirect URIs | Authentik admin | auth |
| 14 | Release-proof tenant probe matrix | `scripts/tenants/verify-*-runtime-proof.sh` | app |
| 15 | Runbook links, docs, status trackers | `docs/` | app |

## Staging principles

1. **Add before cut.** Every new URL must be accepted by every layer
   *before* you flip the "primary" flag anywhere. This lets traffic
   arrive on the new URL even during the cutover window without
   producing `DisallowedHost` or CORS/CSRF failures.
2. **Dual-active, then cut, then retire.** Hold both trees active long
   enough to verify + drain (minimum 14 days for prod). Never cut in
   one step.
3. **Cookie tree unity is non-negotiable.** LMS + MFE + Studio MUST end
   the migration on the same cookie domain parent. Splitting them
   (e.g. LMS on one tree, MFE on another) creates structurally-broken
   auth because cookies scope by domain. The registry has a
   "D-08 drift" comment pattern to flag this class of bug.
4. **Every step is a PR** with independent CI + review. Big-bang migrations
   hide drift; sliced migrations expose it.

## The pipeline

### Stage 0 — Pre-flight audit

**Goal:** know the truthful current state before you change anything.

```bash
# Read the source of truth
cat deploy/k8s/tenancy/tenant-registry.yaml

# Dump every surface that references the tenant's current domain
TENANT_OLD=old.example.com
grep -rn "$TENANT_OLD" deploy/ infrastructure/ scripts/ docs/
```

Inventory every hit and classify which of the 15 surfaces it belongs
to. Anything you can't classify is probably drift to fix first.

Produce a **migration ledger** (one Markdown table, stored under
`docs/status/active/TENANT_MIGRATION_<tenant>.md`) listing old URL,
new URL, and current state of each of the 15 surfaces.

### Stage 1 — Add the new URLs (no cut)

**App-repo PR** (mereka-lms):

- [ ] `tenant-registry.yaml` — add `target_site_domain`, keep
  `site_domain` unchanged. Add new URLs to `domains:` section as
  `status: active` where they physically route, `status: planned`
  otherwise.
- [ ] `production.py` (LMS + CMS) — append new URLs to
  `ALLOWED_HOSTS`, `CSRF_TRUSTED_ORIGINS`, `CORS_ORIGIN_WHITELIST`,
  `LOGIN_REDIRECT_WHITELIST`.
- [ ] `mereka_multisite.py` — teach the cookie-policy helper about the
  new URL, return the new cookie domain for requests on the new host.
  Update tests.
- [ ] Enterprise MFE env file — add the new `LMS_BASE_URL` /
  `STUDIO_BASE_URL` as future overrides, but keep current values
  pointing at the still-live old tree.
- [ ] Run `bash scripts/qa/verify-tenant-isolation-gates.sh` —
  must PASS.

**Infra-repo PR** (bbi-infrastructure):

- [ ] Ingress — add new host alongside old.
- [ ] Certificate — add new SAN alongside old.
- [ ] DNS — create new record pointing at the same ingress IP.

**Verification after Stage 1 lands:**

- [ ] `curl -sI https://<new_url>/` returns 2xx/3xx with correct
  server identity (not a Caddy 502 or nginx 400).
- [ ] `curl -s https://<new_url>/api/mfe_config/v1/?mfe=learning` returns
  MFE config keyed to the new tenant.
- [ ] Both old + new URLs serve the tenant simultaneously.

### Stage 2 — Data-plane preparation

**Runtime** (no PR — Django admin or `manage.py` shell):

- [ ] SiteConfiguration — add new Site rows for the new URL tree. Each
  tenant has 2 rows (LMS host + apps host); add 2 for the new tree
  too, initially inactive.
- [ ] OAuth2 Applications — add new URLs to `redirect_uris` for the
  tenant's LMS Application, CMS Application, and (if separate) MFE
  Application.
- [ ] Authentik OIDC Application — add new URLs to the OIDC
  `redirect_uris` / `allowed_redirect_urls` whitelist.

### Stage 3 — Soak + probe

Hold Stages 1 + 2 for ≥ 14 days in prod, ≥ 48 h in dev. Monitor:

- [ ] No spike in `DisallowedHost` Sentry events.
- [ ] No spike in Authentik OIDC mismatched-redirect errors.
- [ ] Tenant's live users still land on old URL correctly.
- [ ] Playwright proof script probes both old AND new URLs — both
  complete authn + dashboard flows.

### Stage 4 — Cut

**App-repo PR:**

- [ ] `tenant-registry.yaml` — flip `site_domain` to the new URL.
  The old URL becomes an alias.
- [ ] `configmap-tenants.yaml` — flip `domain` to the new URL.
- [ ] `mereka_multisite.py` — default cookie-domain policy for the
  tenant now returns the new tree.
- [ ] Enterprise MFE env file — flip `LMS_BASE_URL` / `STUDIO_BASE_URL`
  / `LOGIN_URL` to new tree.

**Runtime:**

- [ ] Promote SiteConfiguration rows on the new URL to primary;
  demote the old URL rows to legacy/read-only.
- [ ] Authentik: set new URLs as default redirect, old URLs kept in
  allowlist for drain window.

**Verification:**

- [ ] `verify-<env>-runtime-proof.sh` passes for the tenant with
  `SITE_DOMAIN=<new_url>`.
- [ ] Both old and new URLs complete full login → dashboard flow.
- [ ] Cookie domain visible in browser devtools matches the new tree
  parent domain (`.new.example.com`), unified across LMS + MFE + Studio.

### Stage 5 — Drain window

Both URL trees remain active for N days (recommended: 30 for prod).
Old-tree traffic should trend to zero as external links update.

- [ ] Metric: new-tree / (old + new) request share by day.
- [ ] Alert on *requests* to old tree after drain deadline — tells you
  which consumers (partner sites, bookmarks, emails) still need
  updating.

### Stage 6 — Retire old tree

**App-repo PR:**

- [ ] `tenant-registry.yaml` — move old URL entries from `status: active`
  → `status: deprecated` (do not delete yet; audit tooling still refers).
- [ ] Remove old URL from `ALLOWED_HOSTS`, `CORS_*`, `CSRF_*`.
- [ ] Remove old URL from `mereka_multisite.py` + tests.

**Infra-repo PR:**

- [ ] Remove old host from Ingress.
- [ ] Remove old SAN from Certificate (cert-manager reissues).
- [ ] Install a 301 redirect at the old URL pointing to the new URL.

**Runtime:**

- [ ] SiteConfiguration old-tree rows → archived.
- [ ] OAuth2 Applications → remove old `redirect_uris`.
- [ ] Authentik → remove old redirect URLs from allowlist.

**DNS:**

- [ ] Old CNAME/A record → leave in place with TTL ≤ 300s pointing at
  the 301-redirect ingress for 90 days.
- [ ] After 90 days: remove DNS record. Tenant is fully migrated.

### Stage 7 — Retire old domain tree entries

After Stage 6 + 90 days:

- [ ] `tenant-registry.yaml` — delete `status: deprecated` entries.
- [ ] Delete any surviving references in `docs/`.
- [ ] Close the migration ledger.

## Failure modes to avoid

1. **Splitting the cookie tree.** Never ship an LMS cut without the
   matching MFE + Studio cut. If you can't ship them together, pick
   the half-state you can sustain indefinitely (i.e. keep LMS + MFE
   on the same tree, even if that means reverting an MFE move).
2. **Forgetting OAuth2 Application redirect URIs.** A perfect Stage 4
   will still redirect-loop if the OAuth app doesn't have the new URL
   whitelisted. This has happened on SOF Studio twice already.
3. **Not updating `multisite-sites.yml` / SiteConfiguration.** Django
   uses these to resolve a hostname → `Site` → `SiteConfiguration`
   override chain. Missing new URL here → MFE config API returns
   default tenant (usually Mereka), corrupting the frontend.
4. **Cutting without Playwright evidence on both URLs.** Don't trust
   "looks fine on Chrome". Probe from the CI runner, with cookies
   cleared, full login flow.
5. **Treating the runbook as source-of-truth.** Update this file when
   you find a gap. The **migration ledger** in `docs/status/active/`
   is the operational truth per tenant; this runbook is the
   *procedure*.

## Related

- `deploy/k8s/tenancy/tenant-registry.yaml` — authoritative registry
- ADR-025 — app/infra repo boundary (why Stages 1, 4, 6 span both
  repos)
- D-08 drift flag in `tenant-registry.yaml` — the cookie-tree split
  failure mode this runbook exists to prevent
- Skill: `domain-truth-convergence`

## History

| Date | Tenant | Migration | Outcome |
|------|--------|-----------|---------|
| 2026-04-21 | SOF | `skillourfuture.academy.mereka.io` → `skillourfuture.academyv2.mereka.io` | In progress — see `docs/status/active/TENANT_MIGRATION_SOF_2026-04.md` |
