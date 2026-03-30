---
spec: multi-site-domains_spec.md
tier: 1
status: draft
last_updated: '2026-02-10'
plan: multi-site-domains_plan.md
---

# Test Plan: Multi-Site Domain Configuration

**Source Spec**: `specs/multi-site-domains_spec.md`

## Test Framework

This project uses **shell-based verification scripts** (Bash)as the primary test infrastructure, located in `scripts/qa/`. Tests execute against live K8s clusters (prod GKE and dev Kind) via `kubectl` and against public endpoints via `curl`. There is no unit test framework (Vitest/pytest) for the infrastructure-as-code layer.

Test types used:
- `shell_verification` -- Bash scripts that validate configuration state via kubectl + Django shell
- `kubectl_check` -- Direct kubectl commands checking K8s resource state
- `smoke_test` -- HTTP endpoint checks via curl against public domains
- `manual_verification` -- Human-performed checks with documented steps

---

## Acceptance Criteria Test Matrix

| AC # | Test Case | Type | File | Mocks/Fixtures | Notes |
|------|-----------|------|------|----------------|-------|
| AC-001 | All three production domains return HTTP 200 | smoke_test | `scripts/qa/smoke-test.sh` | None (live endpoints)| Already exists; verify domain list matches spec |
| AC-001 | SiteConfiguration records exist and are enabled for all three domains | shell_verification | `scripts/qa/verify-multisite-config.sh` | kubectl exec into LMS pod | Already exists; STRICT=1 mode fails on missing |
| AC-001 | All domains appear in ALLOWED_HOSTS in rendered production.py | shell_verification | `scripts/qa/verify-multisite-config.sh` | kubectl exec into LMS pod | Extend or add separate grep check |
| AC-002 | Login on academyv2.mereka.io persists to apps.academyv2.mereka.io | smoke_test | `scripts/qa/verify-session-persistence.sh` (new) | curl with cookie jar | Login, capture cookie, verify subdomain access |
| AC-002 | SESSION_COOKIE_DOMAIN is ".academyv2.mereka.io" inLMS settings | shell_verification | `scripts/qa/verify-session-persistence.sh` (new) | kubectl exec grep | Check renderedproduction.py |
| AC-003 | Login on academy.biji-biji.com uses independent session (no cookie leakage) | smoke_test | `scripts/qa/verify-session-persistence.sh` (new) | curl with separate cookie jar| Verify different-root-domain isolation |
| AC-003 | CSRF_COOKIE_DOMAIN does not include biji-biji.com| shell_verification | `scripts/qa/verify-session-persistence.sh` (new) | kubectl exec grep | Cookie domain must not be set for different root |
| AC-004 | CSRF token from academyv2.mereka.io accepted on POST | smoke_test | `scripts/qa/verify-csrf-multisite.sh` (new)| curl CSRF token fetch + POST | Fetch /csrf/api/v1/token then POST |
| AC-004 | CSRF token from academy.biji-biji.com accepted onPOST | smoke_test | `scripts/qa/verify-csrf-multisite.sh` (new) | curl CSRF token fetch + POST | Same flow, different domain |
| AC-004 | CSRF token from skillourfuture.academy.mereka.io accepted on POST | smoke_test | `scripts/qa/verify-csrf-multisite.sh` (new) | curl CSRF token fetch + POST | Same flow, different domain |
| AC-004 | CSRF_TRUSTED_ORIGINS includes all HTTPS origins |shell_verification | `scripts/qa/verify-csrf-multisite.sh` (new) | kubectl exec grep | Check rendered production.py |
| AC-005 | /api/mfe_config/v1 returns correct LMS_BASE_URL for primary domain | smoke_test | `scripts/qa/verify-mfe-config-contract.sh` | None (live endpoint) | Already exists for primary |
| AC-005 | /api/mfe_config/v1 contract is correct for biji domain (if MFE served) | smoke_test | `scripts/qa/verify-mfe-config-contract.sh` | None (live endpoint) | Extend to check biji MFE domain |
| AC-006 | studio.academyv2.mereka.io returns HTTP 200 | smoke_test | `scripts/qa/smoke-test.sh` | None (live endpoint) |Already exists |
| AC-006 | No Studio server block for biji or skillourfuturedomains (negative test) | shell_verification | `scripts/qa/verify-studio-isolation.sh` (new) | grep Caddyfile/nginx config| Studio must NOT be served on extra domains |
| AC-007 | Profile image upload from MFE succeeds (1MB limitenforced) | manual_verification | Documented below | Browseror curl upload | Requires authenticated session |
| AC-007 | Profile image upload >1MB rejected by Caddy | smoke_test | `scripts/qa/verify-body-limits.sh` (new) | curl withoversized payload | Caddy must reject with 413 |
| AC-008 | /favicon.ico returns HTTP 200 on all three domains| smoke_test | `scripts/qa/verify-favicon-multisite.sh` (new) | None (live endpoint) | Check content-type is image/* |
| AC-008 | Favicon is served from /theming/asset/images/favicon.ico (rewrite active) | smoke_test | `scripts/qa/verify-favicon-multisite.sh` (new) | curl -L follow redirect | Verify Caddy rewrite rule works |
| AC-009 | OIDC provider configs enabled+visible for all domains | shell_verification | `scripts/qa/verify-oidc-provider-configs.sh` | kubectl exec into LMS pod | Already exists |
| AC-009 | OIDC provider resolves non-empty effective secret| shell_verification | `scripts/qa/verify-oidc-provider-configs.sh` | kubectl exec into LMS pod | Already exists |
| AC-009 | OIDC provider display label is "Mereka" | shell_verification | `scripts/qa/verify-oidc-provider-configs.sh` | kubectl exec into LMS pod | Already exists (VERIFY_OIDC_DISPLAY_NAME=1) |

---

## Edge Case Test Matrix

| EC # | Edge Case | Test Case | Type | File | Notes |
|------|-----------|-----------|------|------|-------|
| EC-001 | Cookie domain mismatch | SESSION_COOKIE_DOMAIN missing or wrong value | shell_verification | `scripts/qa/verify-session-persistence.sh` (new) | grep SESSION_COOKIE_DOMAIN in config |
| EC-002 | CSRF token rejection | MFE domain not in CSRF_TRUSTED_ORIGINS | shell_verification | `scripts/qa/verify-csrf-multisite.sh` (new) | grep CSRF_TRUSTED_ORIGINS for all origins|
| EC-003 | Reverse proxy host header wrong | /profile/api/ returns 404 from MFE | smoke_test | `scripts/qa/verify-profile-api-proxy.sh` (new) | curl /profile/api/ from MFE subdomain |
| EC-004 | CORS blocking cross-origin MFE requests | MFE subdomain not in CORS allowlist | shell_verification | `scripts/qa/verify-csrf-multisite.sh` (new) | Check CORS_ORIGIN_WHITELIST includes MFE host |
| EC-005 | Tutor config regeneration removes patches | Patches lost after `tutor config save` | shell_verification | (partof apply-patches.sh idempotency) | Run apply-patches.sh twice, verify no diff |

---

## NFR Test Matrix

| NFR | Test Case | Type | File | Notes |
|-----|-----------|------|------|-------|
| p95 <2s response | All domain endpoints respond within 2s |smoke_test | `scripts/qa/smoke-test.sh` | Add `-w %{time_total}` to curl checks |
| CSRF failure <0.5% | CSRF validation failure rate monitoring | monitoring | `deploy/k8s/base/monitoring/prometheusrule-lms.yaml` | PrometheusRule alert |
| Zero re-login on subdomain nav | Session cookie propagationtest | smoke_test | `scripts/qa/verify-session-persistence.sh` (new) | Covered by AC-002 test |
| Domain add/remove <30min | Documented procedure timed | manual_verification | `docs/ops/runbooks/DOMAIN_MANAGEMENT.md` | Document with step timings |
| 99.9% availability | Per-domain uptime monitoring | monitoring | Upptime config (`~/infrastructure/upptime/`) | Alreadytracked via status.mereka.dev |
| Body limit enforcement | 1MB/4MB limits enforced without truncation | smoke_test | `scripts/qa/verify-body-limits.sh` (new) | curl with oversized payload |

---

## Manual Verification Steps

### MV-001: Profile Image Upload (AC-007)

**Justification**: Requires authenticated browser session with file upload; not feasible with simple curl.

**Steps**:
1. Navigate to `https://apps.academyv2.mereka.io/account/settings` in a browser
2. Log in with a test account
3. Click the profile image upload area
4. Select an image file <1MB
5. Verify the image saves and displays correctly
6. Attempt to upload an image >1MB
7. Verify the upload is rejected (Caddy 413 response)

**Owner**: QA engineer during release verification
**Frequency**: Each release that modifies Caddy/MFE config

### MV-002: Domain Addition Procedure Timing (NFR)

**Justification**: Procedure timing cannot be automated; requires human execution.

**Steps**:
1. Follow `docs/ops/runbooks/DOMAIN_MANAGEMENT.md` to add a test domain
2. Time each step
3. Verify total time is under 30 minutes
4. Remove the test domain

**Owner**: Operations team during runbook review
**Frequency**: Once during initial documentation, then annually

---

## Test Dependencies

```
Build: apply-patches.sh verified
  |
  +---> smoke-test.sh (AC-001, AC-006)
  +---> verify-multisite-config.sh (AC-001, AC-005)
  +---> verify-session-persistence.sh [NEW] (AC-002, AC-003)
  +---> verify-csrf-multisite.sh [NEW] (AC-004)
  +---> verify-mfe-config-contract.sh (AC-005)
  +---> verify-favicon-multisite.sh [NEW] (AC-008)
  +---> verify-oidc-provider-configs.sh (AC-009)
  +---> verify-body-limits.sh [NEW] (AC-007 NFR)
  +---> verify-studio-isolation.sh [NEW] (AC-006)
  +---> verify-profile-api-proxy.sh [NEW] (EC-003)
  |
  +---> run-multisite-governance-gates.sh (orchestrates all)
```

---

## New Scripts to Create

| Script | Purpose | Estimated Size |
|--------|---------|----------------|
| `scripts/qa/verify-session-persistence.sh` | Cookie domain+ cross-subdomain session test | ~80 lines |
| `scripts/qa/verify-csrf-multisite.sh` | CSRF token acceptance + CSRF_TRUSTED_ORIGINS check | ~60 lines |
| `scripts/qa/verify-favicon-multisite.sh` | Favicon HTTP 200+ content-type on all domains | ~30 lines |
| `scripts/qa/verify-body-limits.sh` | Caddy body size limitenforcement (1MB/4MB) | ~40 lines |
| `scripts/qa/verify-studio-isolation.sh` | Studio NOT servedon extra domains (negative test) | ~25 lines |
| `scripts/qa/verify-profile-api-proxy.sh` | /profile/api/ proxy from MFE subdomain | ~30 lines |

---

## Self-Check

- [x] Every acceptance criterion (AC-001 through AC-009) hasat least one test case
- [x] Every edge case (EC-001 through EC-005) has a test case
- [x] Test type (shell_verification/smoke_test/manual_verification) is appropriate
- [x] Mocks/fixtures specified (kubectl exec, curl, cookie jars)
- [x] NFR tests covered (response time, CSRF rate, availability, body limits)
- [x] New scripts identified with estimated size
- [x] Test dependencies documented
- [x] Manual verification steps have justification and owner
