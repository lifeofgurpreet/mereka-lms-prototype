# Visual Smoke Baseline

**Bead**: mereka-lms-115d.15
**Covers**: AC-VIS-001, AC-VIS-002, AC-VIS-003, AC-VIS-004
**Last updated**: 2026-02-18
**Audience**: Platform Engineering

## Purpose

This document defines the authenticated visual smoke + screenshot baseline
contract for the 5 critical MFE flows in Mereka Academy. It extends the
existing unauthenticated visual regression infrastructure (described in
`VISUAL_REGRESSION_RUNBOOK.md`) to cover post-login pages that require a
valid session cookie.

## 5 Critical MFE Routes (AC-VIS-002)

| # | Route | MFE App | Auth Required |
|---|-------|---------|---------------|
| 1 | `/learner-dashboard/` | `frontend-app-learner-dashboard` | Yes |
| 2 | `/learning/` | `frontend-app-learning` | Yes (course enrollment) |
| 3 | `/account/` | `frontend-app-account` | Yes |
| 4 | `/profile/` | `frontend-app-profile` | Yes |
| 5 | `/course-authoring/` | `frontend-app-course-authoring` | Yes (staff/author) |

Each route is baselined at desktop (1280×800) and mobile (375×812) viewports.

## Auth Cookie Flow (AC-VIS-001)

Authenticated smoke tests obtain a session by posting to the LMS login
endpoint and extracting the `sessionid` cookie. Credentials are never
hardcoded — they are injected via environment variables:

| Variable | Source | Description |
|----------|--------|-------------|
| `SSO_USERNAME` | GitHub Actions secret `SMOKE_SSO_USERNAME` | Test user email |
| `SSO_PASSWORD` | GitHub Actions secret `SMOKE_SSO_PASSWORD` | Test user password |
| `VISUAL_SMOKE_DOMAIN` | Env / CI var | Target domain (default: `academyv2.mereka.io`) |

The test user account (`smoke-test@mereka.io`) is a dedicated learner account
enrolled in at least one published course. See
`docs/reference/operations/AUTHENTICATED_SMOKE_CREDENTIALS.md` for the full credential
management runbook including rotation schedule.

### Cookie Acquisition Steps

1. POST `/api/user/v2/account/login_session/` with username + password.
2. Extract `Set-Cookie: sessionid=...` from the response.
3. Pass `Cookie: sessionid=<value>` on all subsequent screenshot requests.
4. If login fails (HTTP 4xx), abort with `WARN` — do not proceed to screenshot
   capture (avoids false-positive diffs from unauthenticated redirect pages).

## RMSE Diff Threshold Policy (AC-VIS-003)

Visual comparisons use ImageMagick `compare -metric RMSE`. Two thresholds
are defined:

| Threshold | Value | Gate behaviour |
|-----------|-------|----------------|
| **Initial / tolerant** | RMSE ≤ 5.0 | Used during feature development; allows minor layout shifts |
| **Strict / release** | RMSE ≤ 2.0 | Required before merging theme or MFE changes to main |

Set the active threshold via env var:

```bash
VISUAL_RMSE_THRESHOLD=5.0   # default (tolerant)
VISUAL_RMSE_THRESHOLD=2.0   # strict (for release gates)
```

The threshold value is logged in each run artifact for audit traceability.

### False Positive Triage Guide

| Symptom | Likely Cause | Resolution |
|---------|--------------|------------|
| Small diff (<5%) in date/time fields | Dynamic content renders differently | Mask the region or use tolerant threshold |
| Diff only on scrollbar / focus ring | Browser rendering variation between runs | Update baseline on reference machine |
| Diff on skeleton / loading state | Race condition — element not yet hydrated | Increase `waitForSelector` timeout |
| Diff on course thumbnail | CDN propagation lag | Re-run after 5 min; not a regression |
| Diff only on mobile viewport | Font metrics differ on Ubuntu CI runner | Tolerate at 5.0; document in diff notes |

**Decision tree**:
1. Is RMSE above threshold? → Investigate.
2. Is the visual change intentional (theme update, new component)? → Update baseline.
3. Does it match a known false positive pattern above? → Document and accept.
4. None of the above → File regression bug, block merge.

## Baseline Generation (AC-VIS-002)

### First-time / Bootstrap

```bash
# Capture authenticated baselines for all 5 routes
export SSO_USERNAME="smoke-test@mereka.io"
export SSO_PASSWORD="<from Infisical or local .env>"

RUN_SCREENSHOTS=1 RUN_VISUAL_REGRESSION=1 VISUAL_ALLOW_BOOTSTRAP=1 \
  ./scripts/branding/run-branding-gates.sh prod
```

Baselines are written to `var/screenshots/baseline/` (gitignored). Commit
the baseline directory to a protected branch or artifact store when promoting
to production gate.

### After Intentional Visual Change

```bash
# Update baseline for a specific route
./scripts/qa/visual-regression-test.sh --update-baseline \
  --authenticated --route learner-dashboard --env production
```

### VPS Cron (Continuous Monitoring)

The VPS-side cron (installed by
`scripts/infra/setup-vps-branding-visual-regression-cron.sh`) runs at
`15 */6 * * *` (every 6 hours) and captures screenshots + diffs
automatically. Logs land in `var/cron-branding-visual-regression.log`.

For authenticated flows, set credentials in the cron env file:

```bash
# var/branding-visual-regression.env  (gitignored)
SSO_USERNAME="smoke-test@mereka.io"
SSO_PASSWORD="<value>"
VISUAL_SMOKE_DOMAIN="academyv2.mereka.io"
```

## CI Integration (AC-VIS-004)

| Gate | Trigger | Script |
|------|---------|--------|
| Syntax check | Every PR | `bash -n scripts/qa/verify-visual-smoke-baseline.sh` |
| Offline baseline verification | PRs matching `visual`, `screenshot`, `smoke`, `branding`, `regression` in title | `./scripts/qa/verify-visual-smoke-baseline.sh` |
| Live authenticated smoke | Scheduled / manual dispatch | `.github/workflows/smoke-authenticated.yml` |
| VPS continuous | Every 6 h | `scripts/infra/cron-branding-visual-regression.sh` |

The offline verification script (`verify-visual-smoke-baseline.sh`) always
runs in CI without needing a live cluster. It validates that:

- Documentation and harness files exist.
- All 5 routes are declared.
- Threshold policy is documented.
- CI wiring references the correct scripts.

Live screenshot capture is skipped in CI unless `VISUAL_SMOKE_LIVE=1` is
explicitly set (live cluster + credentials required).

### Related Infrastructure

- `scripts/branding/run-branding-gates.sh` — orchestrator for branding gates;
  set `RUN_SCREENSHOTS=1 RUN_VISUAL_REGRESSION=1` to include visual regression.
- `scripts/infra/setup-vps-branding-visual-regression-cron.sh` — installs VPS
  cron for continuous monitoring.
- `scripts/qa/visual-regression-test.sh` — Playwright screenshot capture +
  ImageMagick diff engine; supports `--authenticated` flag.
- `scripts/qa/smoke-authenticated.sh` — headless browser authenticated smoke
  harness.
- `docs/guides/branding/BRANDING_OPERATING_MODEL.md` — broader branding QA operating
  model; visual regression is section 4.

## Verification

```bash
# Offline (always safe, no cluster needed)
./scripts/qa/verify-visual-smoke-baseline.sh

# Live cluster
VISUAL_SMOKE_LIVE=1 \
  SSO_USERNAME="smoke-test@mereka.io" \
  SSO_PASSWORD="<value>" \
  ./scripts/qa/verify-visual-smoke-baseline.sh
```

Expected result: **0 FAIL**. WARNs for live-only checks are acceptable in
offline mode.
