---
spec: platform-middleware-custom-apps_spec.md
tier: 2
status: completed
estimated_effort: "1-2 weeks (retrospective documentation + verification scripts + hardening)"
owner: engineering
last_updated: "2026-02-10"
prerequisites:
  - k8s-deployment_spec.md (Tier 1, DRAFT)
  - multi-site-domains_spec.md (Tier 2, DRAFT)
  - secrets-management_spec.md (Tier 0, IN_REVIEW)
  - observability-stack_spec.md (Tier 2, DRAFT)
  - cross-cutting-requirements_spec.md (Tier 0, IN_REVIEW)
---

# Implementation Plan: Platform Middleware and Custom Apps

**Source Spec**: specs/platform-middleware-custom-apps_spec.md
**Tier**: 2 -- Platform Extensions
**Status**: COMPLETED (code already deployed)

## Summary

The middleware stack and custom apps are **already implemented and deployed** to production. This plan focuses on:

1. **Verification scripting** -- building automated tests for all 20 acceptance criteria
2. **Documentation hardening** -- creating operational runbooks for middleware troubleshooting
3. **Gap analysis** -- identifying any missing features or edge cases not yet covered
4. **Observability enhancement** -- adding custom Prometheus metrics for middleware actions

## Current State Analysis

All three middleware components and two custom apps are deployed to production:

- **Middleware source files**:
  - `deploy/k8s/base/apps/openedx/settings/lms/mereka_platform_admin.py` -- MerekaPlatformAdminMiddleware
  - `deploy/k8s/base/apps/openedx/settings/lms/mereka_multisite.py` -- MerekaCookieDomainMiddleware + Sites framework patch
  - `deploy/k8s/base/apps/openedx/settings/lms/mereka_forwarded_headers.py` -- MerekaForwardedHeadersMiddleware

- **Custom apps**:
  - `infrastructure/tutor/custom-apps/mfe_oauth_fix/` -- MFE OAuth provider injection and renaming
  - `infrastructure/tutor/custom-apps/openedx_prometheus/` -- Django Prometheus metrics endpoint

- **Integration point**:
  - `infrastructure/tutor/apply-patches.sh` -- injects middleware imports, adds to MIDDLEWARE list, adds apps to INSTALLED_APPS, injects URL patterns

### Current Deployment Status

| Component | Status | Notes |
|-----------|--------|-------|
| MerekaPlatformAdminMiddleware | DEPLOYED | Active in production |
| MerekaCookieDomainMiddleware | DEPLOYED | Active in production |
| MerekaForwardedHeadersMiddleware | DEPLOYED | Active in production |
| mfe_oauth_fix | DEPLOYED | Active in production |
| openedx_prometheus | DEPLOYED | Active in production |

### Known Gaps

| Gap | AC(s) Affected | Severity |
|-----|---------------|----------|
| No automated verification scripts for middleware behavior | AC-001 through AC-020 | High |
| Middleware order verification not in CI | AC-001 through AC-020 | Medium |
| No custom Prometheus metrics for middleware actions (only django-prometheus built-ins) | Observability/Metrics | Medium |
| No runbook for middleware troubleshooting (cookie domain issues, header normalization failures) | Edge Cases | Medium |
| Sites framework patch idempotency check could race in multi-worker environments | AC-008 | Low |
| MFEOAuthFixMiddleware does not cache OAuth provider queries (repeated DB hits on every /api/mfe_context request) | Performance/NFR | Low |

---

## Task Breakdown

### Verify -- Document Current Implementation

- [ ] **[S]** V-01: Audit all three middleware source files to confirm they match spec requirements (order, configuration, error handling) | AC: #001-#012 | Depends: None

- [ ] **[S]** V-02: Audit mfe_oauth_fix middleware to confirm OAuth provider injection, Authentik renaming, and path filtering | AC: #013-#016 | Depends: None

- [ ] **[S]** V-03: Audit openedx_prometheus app to confirm /metrics endpoint, URL routing, and django-prometheus integration | AC: #017-#018 | Depends: None

- [ ] **[S]** V-04: Verify apply-patches.sh correctly injects middleware in the required order (see spec Middleware Stack Order section) | AC: All | Depends: None

- [ ] **[S]** V-05: Verify MEREKA_PLATFORM_ADMIN_EMAILS environment variable is set in production K8s ConfigMap or Secret | AC: #001-#003, #019 | Depends: None

### Test -- Verification Scripts

- [ ] **[L]** T-01: Create scripts/qa/verify-middleware-stack.sh -- comprehensive verification script covering AC-001 through AC-012 (admin escalation, cookie domain rewriting, Sites framework patch, header normalization, /metrics host rewrite) | AC: #001-#012 | Depends: V-01, V-04

- [ ] **[M]** T-02: Create scripts/qa/verify-custom-apps.sh -- verification script covering AC-013 through AC-018 (MFE OAuth provider injection, Authentik renaming, /metrics endpoint, metrics content) | AC: #013-#018 | Depends: V-02, V-03

- [ ] **[S]** T-03: Create scripts/qa/verify-middleware-order.sh -- parses LMS production settings to verify MIDDLEWARE list order matches spec | AC: Middleware Stack Order | Depends: V-04

- [ ] **[M]** T-04: Add middleware verification to scripts/qa/qa-smoke.sh or create a runtime smoke test that exercises all middleware components via HTTP requests | AC: All | Depends: T-01, T-02

### Harden -- Fill Gaps

- [ ] **[M]** H-01: Add custom Prometheus metrics to middleware (mereka_platform_admin_escalations_total, mereka_cookie_domain_rewrites_total, mereka_forwarded_header_normalizations_total, mereka_mfe_oauth_injections_total) -- inject prometheus_client calls into each middleware | Observability/Metrics | Depends: None

- [ ] **[S]** H-02: Add threading lock to Sites framework monkey-patch in MerekaCookieDomainMiddleware to prevent race conditions in multi-worker setups | AC: #008 | Depends: None

- [ ] **[M]** H-03: Add OAuth provider query caching to MFEOAuthFixMiddleware (in-memory cache with 5-minute TTL, keyed by site_id) to reduce database load | Performance/NFR | Depends: None

- [ ] **[S]** H-04: Add feature flag check for openedx_prometheus app -- if django-prometheus is not installed, log a warning and provide empty URL patterns (graceful degradation) | AC: #020 | Depends: None

### Docs -- Operational Runbooks

- [ ] **[M]** D-01: Create docs/operations/MIDDLEWARE_VERIFICATION.md -- runbook for verifying middleware is loaded, checking middleware order, testing admin escalation, testing cookie domains, testing header normalization | Depends: T-01, T-02, T-03

- [ ] **[M]** D-02: Create docs/operations/MIDDLEWARE_TROUBLESHOOTING.md -- troubleshooting guide for all edge cases from the spec (admin email collision, cookie domain leakage, Prometheus scrape failures, empty OAuth providers, Sites framework patch race condition, middleware order violation) | Depends: None

- [ ] **[S]** D-03: Add middleware verification to docs/operations/DEPLOYMENT_RUNBOOK.md post-deployment checklist | Depends: D-01

- [ ] **[S]** D-04: Document custom Prometheus metrics (labels, usage, example queries) in docs/operations/OBSERVABILITY_GUIDE.md | Depends: H-01

### Rollout -- Add to CI/CD

- [ ] **[S]** R-01: Add middleware order verification to .github/workflows/ci.yml (runs scripts/qa/verify-middleware-order.sh on every push) | Depends: T-03

- [ ] **[M]** R-02: Add middleware verification to pre-deployment smoke tests (Kind cluster or GKE staging) | Depends: T-01, T-02, T-04

---

## Milestones

| Milestone | Tasks | Target |
|-----------|-------|--------|
| M1: Current implementation audited | V-01 through V-05 | Week 1 |
| M2: Verification scripts complete | T-01 through T-04 | Week 2 |
| M3: Hardening and observability | H-01 through H-04, D-04 | Week 3 |
| M4: Documentation and CI integration | D-01 through D-03, R-01, R-02 | Week 4 |

---

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Middleware verification scripts are runtime-dependent (need live Django environment) | Cannot run in CI without cluster | Create synthetic unit tests using Django RequestFactory + mock responses |
| Adding threading lock to Sites framework patch may introduce deadlocks | Site lookups hang under high load | Test thoroughly in staging; use threading.RLock() with timeout |
| Custom Prometheus metrics may cause metric label cardinality explosion if tenant_domain is a label | Prometheus scrape failures | Limit metric labels to fixed values (mereka_io, biji_biji, localhost) |
| OAuth provider caching may show stale providers if configuration changes | MFE shows wrong providers for 5 minutes | Add cache invalidation signal on OAuth2ProviderConfig save |
| Middleware order verification script must parse Python settings file (not YAML) | Fragile parsing, breaks on comments/formatting changes | Use ast.parse() or import settings dynamically in Django shell |

---

## Self-Check

- [x] Every acceptance criterion (AC-001 through AC-020) has at least one verification or hardening task
- [x] Edge cases from spec mapped to troubleshooting docs (D-02)
- [x] File paths specified for every task
- [x] Dependencies identified for all tasks
- [x] Complexity estimated (S/M/L) for each task
- [x] Source spec linked in header
- [x] Observability enhancements planned (H-01, D-04)
- [x] Retrospective nature acknowledged (code already deployed)
