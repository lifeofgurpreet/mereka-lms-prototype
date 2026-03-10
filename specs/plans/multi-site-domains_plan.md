---
spec: multi-site-domains_spec.md
tier: 1
status: draft
estimated_effort: "3-5 days (M overall)"
owner: engineering
last_updated: "2026-02-10"
depends_on:
  - repository-structure_spec.md
  - secrets-management_spec.md
  - tutor-configuration_spec.md
  - cross-cutting-requirements_spec.md
blocks:
  - branding-system_spec.md
  - multi-tenancy-architecture_spec.md
---

# Implementation Plan: Multi-Site Domain Configuration

**Source Spec**: `specs/multi-site-domains_spec.md`

## Summary

This plan formalizes the multi-site domain configuration thatalready partially exists in the Mereka Academy deployment. The primary work is hardening existing configuration, adding missing verification scripts, documenting the domain addition/removal procedure, and ensuring all acceptance criteria are continuously tested. Most of the Django settings, Caddy rules,and Nginx config are already applied through `infrastructure/tutor/apply-patches.sh`. The plan focuses on closing gaps, adding automated verification, and ensuring resilience acrossTutor config regeneration cycles.

## Prerequisites

| Prerequisite | Status | Notes |
|-------------|--------|-------|
| Tier 0 specs (repo structure, secrets, tutor config, cross-cutting) | Partially complete | `repository-structure_spec.md` approved; others in review |
| `apply-patches.sh` operational | Done | Already adds extrahosts, CSRF origins, Caddy blocks |
| `scripts/shared/config.sh` domain variables | Done | Defines LMS_DOMAIN, BIJI_DOMAIN, SKILLOURFUTURE_DOMAIN |
| kubectl access to prod GKE + dev Kind | Done | Contexts configured |
| DNS records for all three domains | Done | Managed in `infrastructure/cloudflare/` |

## Existing Infrastructure Audit

Before implementing, review what already exists:

| Component | File | Current State |
|-----------|------|---------------|
| ALLOWED_HOSTS patching | `infrastructure/tutor/apply-patches.sh` (ensure_allowed_hosts) | Adds biji + skillourfuture toALLOWED_HOSTS |
| CSRF_TRUSTED_ORIGINS patching | `infrastructure/tutor/apply-patches.sh` (ensure_csrf_origins) | Adds CSRF origins for extra domains |
| Caddy extra host blocks | `infrastructure/tutor/apply-patches.sh` (Caddyfile section) | Generates server blocks per extra host |
| Nginx server_name | `infrastructure/tutor/apply-patches.sh`(lms.conf section) | Adds extra domains to server_name |
| Nginx profile API proxy | `infrastructure/tutor/apply-patches.sh` (lms.conf section) | Proxies /profile/api/ with correct Host header |
| DEFAULT_SITE_THEME | `infrastructure/tutor/apply-patches.sh` (production.py section) | Sets "mereka" if missing |
| Multisite config verification | `scripts/qa/verify-multisite-config.sh` | Validates SiteConfiguration per domain |
| OIDC provider verification | `scripts/qa/verify-oidc-provider-configs.sh` | Validates OAuth2ProviderConfig per domain |
| MFE config contract check | `scripts/qa/verify-mfe-config-contract.sh` | Validates /api/mfe_config/v1 response |
| Smoke tests | `scripts/qa/smoke-test.sh` | HTTP 200 checksfor all domains |
| Governance gates | `scripts/qa/run-multisite-governance-gates.sh` | Orchestrates multisite + org + auth checks |
| Domain routing map | `scripts/qa/map-openedx-host-routing.sh` | Shows all hostname routing across clusters |
| Public health check | `scripts/qa/public-health-check.sh` |Per-domain endpoint checks (prod + dev) |

---

## Task Breakdown

### Build

- [ ] **[S]** Verify `SESSION_COOKIE_DOMAIN` and `CSRF_COOKIE_DOMAIN` are set correctly in `apply-patches.sh` (`infrastructure/tutor/apply-patches.sh`) | AC: #2, #3 | Depends: None
  - **Done**: `ensure_mfe_cookie_env` sets SESSION_COOKIE_DOMAIN and CSRF_COOKIE_DOMAIN as Docker build args in the MFE Dockerfile. Verify that the LMS `production.py` patch also sets`SESSION_COOKIE_DOMAIN = ".academyv2.mereka.io"` and `CSRF_COOKIE_DOMAIN = ".academyv2.mereka.io"` explicitly, not relying only on MFE env vars.
  - **Files**: `infrastructure/tutor/apply-patches.sh` (production.py section)

- [ ] **[S]** Verify ALLOWED_HOSTS includes all three domainsplus subdomains (`infrastructure/tutor/apply-patches.sh`) |AC: #1, #4 | Depends: None
  - **Done**: `ensure_allowed_hosts` adds biji + skillourfuture. Confirm `apps.academyv2.mereka.io`, `studio.academyv2.mereka.io`, and MFE subdomains are included either directly or via wildcard.
  - **Files**: `infrastructure/tutor/apply-patches.sh` (ensure_allowed_hosts function)

- [ ] **[S]** Verify CSRF_TRUSTED_ORIGINS includes all HTTPSorigins (`infrastructure/tutor/apply-patches.sh`) | AC: #4 |Depends: None
  - **Done**: `ensure_csrf_origins` appends extra origins after the `apps.academyv2.mereka.io` anchor. Verify the full list: `https://academyv2.mereka.io`, `https://apps.academyv2.mereka.io`, `https://academy.biji-biji.com`, `https://skillourfuture.academy.mereka.io`.
  - **Files**: `infrastructure/tutor/apply-patches.sh` (ensure_csrf_origins function)

- [ ] **[M]** Ensure SiteConfiguration records exist for allthree domains via Django admin or management command (`scripts/qa/verify-multisite-config.sh`) | AC: #1, #5 | Depends: None
  - **Done**: `verify-multisite-config.sh` already checks SiteConfiguration per domain (prod: LMS_DOMAIN, BIJI_DOMAIN, SKILLOURFUTURE_DOMAIN). Review that expected values (LMS_ROOT_URL, CMS_ROOT_URL, MFE_BASE_URL, THEME_NAME, COURSE_ORG_FILTER)match the spec for each domain. If SKILLOURFUTURE_DOMAIN isempty in config.sh, decide whether to set it or mark it as deprecated.
  - **Files**: `scripts/qa/verify-multisite-config.sh`, `scripts/shared/config.sh`

- [ ] **[S]** Verify Caddy server blocks include favicon rewrite, 1MB profile image limit, and 4MB general body limit forall domains (`infrastructure/tutor/apply-patches.sh`) | AC: #7, #8 | Depends: None
  - **Done**: The `lms_caddy_block_template` in apply-patches.sh already includes favicon rewrite, 1MB profile image limit, and 4MB general body limit. Verify that the template is applied for all extra hosts.
  - **Files**: `infrastructure/tutor/apply-patches.sh` (Caddyfile section)

- [ ] **[S]** Verify Nginx `server_name` directive includes all domains and `/profile/api/` proxy is configured (`infrastructure/tutor/apply-patches.sh`) | AC: #7 | Depends: None
  - **Done**: The lms.conf section adds extra domains to `server_name` and configures `/profile/api/` proxy. Verify the Host header is set to `academyv2.mereka.io`.
  - **Files**: `infrastructure/tutor/apply-patches.sh` (lms.conf section)

- [ ] **[S]** Verify Studio is only accessible at `studio.academyv2.mereka.io` - no Caddy/Nginx rules serve CMS on other domains (`infrastructure/tutor/apply-patches.sh`) | AC: #6 | Depends: None
  - **Done**: The Caddy blocks for extra domains only proxy to `lms:8000`, not `cms:8000`. Verify no Studio server block exists for biji or skillourfuture domains.
  - **Files**: `infrastructure/tutor/apply-patches.sh` (Caddyfile section)

- [ ] **[M]** Resolve SKILLOURFUTURE_DOMAIN configuration gapin `scripts/shared/config.sh` | AC: #1 | Depends: None
  - **Current state**: `SKILLOURFUTURE_DOMAIN` defaults to empty string in config.sh with a comment "Deprecated micrositedomain: set explicitly only if you still operate it." The spec lists it as a required production domain. Either set it to`skillourfuture.academy.mereka.io` or update the spec to remove it.
  - **Files**: `scripts/shared/config.sh`

- [ ] **[M]** Verify OIDC provider configuration per domain matches spec contract (`scripts/qa/verify-oidc-provider-configs.sh`) | AC: #9 | Depends: None
  - **Done**: Script already validates OAuth2ProviderConfig for backend_name=oidc per site. Verify it checks: enabled+visible, non-empty effective secret, display name "Sign in with Mereka".
  - **Files**: `scripts/qa/verify-oidc-provider-configs.sh`

### Test

- [ ] **[M]** Create or update domain resolution smoke test to verify all three domains return HTTP 200 (`scripts/qa/smoke-test.sh`) | AC: #1 | Depends: Build tasks
  - **Done**: `smoke-test.sh` already checks all five endpoints. Verify it matches the spec domain list and consider adding response time assertions for the p95 <2s NFR.
  - **Files**: `scripts/qa/smoke-test.sh`

- [ ] **[M]** Create cross-subdomain session persistence test(`scripts/qa/verify-session-persistence.sh`) | AC: #2 | Depends: Build tasks (cookie domain)
  - **New script**: Login on `academyv2.mereka.io`, capture session cookie, navigate to `apps.academyv2.mereka.io`, verifysession is maintained (no re-login). Check that `SESSION_COOKIE_DOMAIN` is `.academyv2.mereka.io`.
  - **Files**: `scripts/qa/verify-session-persistence.sh` (new)

- [ ] **[S]** Create independent session test for biji-biji.com (`scripts/qa/verify-session-persistence.sh`) | AC: #3 | Depends: Build tasks (cookie domain)
  - **New test case**: Verify that login on `academy.biji-biji.com` does not share cookies with `academyv2.mereka.io`. Session must be independent.
  - **Files**: `scripts/qa/verify-session-persistence.sh` (new, same file)

- [ ] **[S]** Create CSRF token acceptance test for all threedomains (`scripts/qa/verify-csrf-multisite.sh`) | AC: #4 | Depends: Build tasks (CSRF origins)
  - **New script**: For each domain, fetch CSRF token from `/csrf/api/v1/token`, then issue a POST request and verify it is accepted (not 403).
  - **Files**: `scripts/qa/verify-csrf-multisite.sh` (new)

- [ ] **[M]** Create /api/mfe_config/v1 per-domain contract test (`scripts/qa/verify-mfe-config-contract.sh`) | AC: #5 | Depends: Build tasks
  - **Existing script**: Already verifies MFE config for prod/dev. Extend or verify it checks `LMS_BASE_URL` for each domain, not just the primary. If biji and skillourfuture have separate MFE config endpoints, add them.
  - **Files**: `scripts/qa/verify-mfe-config-contract.sh`

- [ ] **[S]** Verify Studio accessibility test: `studio.academyv2.mereka.io` returns 200, no Studio on other domains (`scripts/qa/smoke-test.sh`) | AC: #6 | Depends: None
  - **Existing test**: smoke-test.sh checks `studio.academyv2.mereka.io`. Add negative test confirming `studio.academy.biji-biji.com` is NOT served (or returns 404/502).
  - **Files**: `scripts/qa/smoke-test.sh`

- [ ] **[S]** Verify profile image upload from MFE succeeds (manual or automated) | AC: #7 | Depends: Build tasks (Nginx +Caddy proxy)
  - **Manual test**: Upload a profile image via `apps.academyv2.mereka.io/account/settings` and verify it saves. Documentas a manual verification step with curl command.
  - **Files**: Documentation in testplan

- [ ] **[S]** Verify favicon loads on all domains (`scripts/qa/verify-favicon-multisite.sh`) | AC: #8 | Depends: Build tasks (Caddy rewrite)
  - **New script**: For each domain, `curl -sI https://<domain>/favicon.ico` and verify HTTP 200 + correct content-type.
  - **Files**: `scripts/qa/verify-favicon-multisite.sh` (new)

- [ ] **[S]** Run OIDC provider verification script against prod (`scripts/qa/verify-oidc-provider-configs.sh`) | AC: #9 |Depends: Build tasks
  - **Existing script**: Run `./scripts/qa/verify-oidc-provider-configs.sh --env prod` and verify it passes.
  - **Files**: `scripts/qa/verify-oidc-provider-configs.sh`

### Observability

- [ ] **[S]** Verify LMS request logs capture domain in `http_host` header (`infrastructure/tutor/apply-patches.sh`) | Req: OBS-1 | Depends: Build tasks
  - **Done**: Default Django/Nginx logging includes Host header. Verify `tutor local logs lms | grep domain` shows correcthost per request.
  - **Files**: Documentation only (already supported by default)

- [ ] **[S]** Add CSRF validation failure rate alert rule toPrometheus (`deploy/k8s/base/monitoring/prometheusrule-lms.yaml`) | Req: OBS-3 | Depends: Build tasks
  - **New rule**: Alert if CSRF validation failures exceed 5%of requests per domain for >1 minute.
  - **Files**: `deploy/k8s/base/monitoring/prometheusrule-lms.yaml`

- [ ] **[S]** Add 5xx error rate alert rule per domain to Prometheus (`deploy/k8s/base/monitoring/prometheusrule-lms.yaml`) | Req: OBS-3 | Depends: Build tasks
  - **New rule**: Alert if any domain returns 5xx errors for>1 minute.
  - **Files**: `deploy/k8s/base/monitoring/prometheusrule-lms.yaml`

### Docs

- [ ] **[M]** Write domain addition/removal runbook (`docs/ops/runbooks/DOMAIN_MANAGEMENT.md`) | Depends: All build tasks
  - **New doc**: Step-by-step procedure for adding or removing a domain. Target: <30 minutes including verification. Include: apply-patches.sh edit, Caddy/Nginx config, SiteConfiguration creation, DNS record, verification script.
  - **Files**: `docs/ops/runbooks/DOMAIN_MANAGEMENT.md` (new)

- [ ] **[S]** Update `docs/reference/operations/OPENEDX_HOSTNAMES.md` with current domain inventory | Depends: None
  - **Existing doc**: Ensure it reflects all three productiondomains plus dev domains. Cross-reference with `scripts/shared/config.sh`.
  - **Files**: `docs/reference/operations/OPENEDX_HOSTNAMES.md`

- [ ] **[S]** Update `docs/ops/runbooks/TROUBLESHOOTING.md` with multisite edge cases | Depends: None
  - **Existing doc**: Add entries for cookie domain mismatch,CSRF rejection, and reverse proxy host header issues from the spec's Edge Cases section.
  - **Files**: `docs/ops/runbooks/TROUBLESHOOTING.md`

### Rollout

- [ ] **[S]** Define rollout verification checklist in governance gate (`scripts/qa/run-multisite-governance-gates.sh`) |Depends: Test tasks
  - **Existing script**: Verify the governance gate includesall new verification scripts (session persistence, CSRF, favicon). Add them to the check list.
  - **Files**: `scripts/qa/run-multisite-governance-gates.sh`

- [ ] **[S]** Document rollback procedure in domain management runbook | Depends: Docs task
  - **Done**: Already included in the spec. Copy to `docs/ops/runbooks/DOMAIN_MANAGEMENT.md` with concrete commands.
  - **Files**: `docs/ops/runbooks/DOMAIN_MANAGEMENT.md`

---

## Milestones

| Milestone | Tasks | Target |
|-----------|-------|--------|
| M1: Configuration audit complete | All Build tasks pass verification | Day 1-2 |
| M2: Automated tests operational | All Test tasks created and passing | Day 2-3 |
| M3: Observability rules deployed | Alert rules in Prometheus | Day 3-4 |
| M4: Documentation complete | All Docs tasks done | Day 4-5|
| M5: Governance gate green | `run-multisite-governance-gates.sh` passes with all new checks | Day 5 |

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| SKILLOURFUTURE_DOMAIN deprecated in config.sh but requiredby spec | Medium | Medium | Resolve config.sh vs spec discrepancy in Build task |
| `tutor config save` overwrites patches on next cycle | High| High | `apply-patches.sh` already handles this; verify idempotency |
| Biji-Biji.com cookie leakage to mereka.io domain | Low | High | Independent session test (AC-003) catches this |
| CSRF token rotation breaks cross-domain after Tutor upgrade| Medium | High | CSRF verification script (AC-004) in governance gate |
| Profile image upload breaks silently with body size limit change | Low | Medium | Manual verification step + Caddy config audit |

## Open Questions from Spec

1. **Separate SiteConfiguration per domain vs shared** -- Theexisting `verify-multisite-config.sh` expects separate SiteConfiguration per domain with per-domain COURSE_ORG_FILTER. This seems to be the established pattern.
2. **Domain-specific branding overrides** -- Deferred to `branding-system_spec.md` (Tier 1 peer).
3. **Biji-biji.com branding** -- The existing SiteConfiguration expects THEME_NAME="mereka" for all domains. Domain-specific theming is a branding-system concern.
4. **Separate analytics per domain** -- Deferred to `analytics-pipeline_spec.md` (Tier 2).
5. **Domain-based rate limiting** -- Not in scope for this spec.
