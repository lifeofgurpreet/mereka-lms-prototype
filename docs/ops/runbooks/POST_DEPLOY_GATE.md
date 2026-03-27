# Post-Deploy E2E Gate
_Audience: Operators and developers • Owner: Platform Team • Last verified: 2026-03-27 • Status: active_

<!-- Last verified: 2026-02-24 -->

The post-deploy E2E gate blocks release completion if any of the five critical user paths fail after a deployment. It runs automatically after each successful build-and-push and can be re-run manually. The current automated lane is `staging`; `production` remains an explicit manual target while that lane is still parked.

---

## Overview

| Property | Value |
|----------|-------|
| **Workflow** | `.github/workflows/post-deploy-e2e.yml` |
| **Verification script** | `scripts/qa/verify-post-deploy-gate.sh` |
| **Trigger** | Automatic after `Build Tutor Images` succeeds; manual dispatch |
| **Default target** | `https://staging.academyv2.mereka.io` |
| **Timeout** | 30 minutes |
| **Artifacts** | 30-day retention in `post-deploy-e2e-<run_id>` |

---

## Critical Paths Tested

These five paths are verified on every deployment. A failure in any one blocks the release.

| # | Path | What is tested |
|---|------|----------------|
| 1 | **Login** | Authenticated session via SSO (Authentik OIDC) |
| 2 | **Enroll** | Course enrollment flow for a test learner |
| 3 | **Video** | Mux video playback loads in course unit |
| 4 | **Forum** | Discussions MFE renders course threads |
| 5 | **Certificate** | Certificate issuance and display for completed course |

Oscar ecommerce is **deprecated** and is not included in the critical path suite.

---

## Required Secrets

The gate resolves credentials from the following sources, in order:

1. `E2E_TEST_*` repository secrets when you want a dedicated override account
2. the matching authenticated canary credentials for the selected environment
   (`SSO_CANARY_*_PROD` or `SSO_CANARY_*_STAGING`)

Set at least one complete source before the gate can run:

| Secret | Description |
|--------|-------------|
| `E2E_TEST_USERNAME` | Optional dedicated test learner account email override |
| `E2E_TEST_PASSWORD` | Optional dedicated test learner account password override |
| `E2E_TEST_COURSE_ID` | Course ID to use for enrollment / video / forum / certificate tests (can also be a repository variable) |
| `SSO_CANARY_EMAIL_PROD` / `SSO_CANARY_PASSWORD_PROD` | Canonical production learner fallback used when `E2E_TEST_*` overrides are absent |
| `SSO_CANARY_EMAIL_STAGING` / `SSO_CANARY_PASSWORD_STAGING` | Canonical staging learner fallback used when `E2E_TEST_*` overrides are absent |

The effective test account must be enrolled in the test course and must have completed it (for certificate tests). If you do not maintain a dedicated `E2E_TEST_*` learner, keep the canary learner in that state instead.

---

## How It Works

```
Build Tutor Images (success)
        │
        ▼
  post-deploy-e2e.yml
        │
        ├─ gate-check (skip if triggering workflow failed)
        │
        ├─ e2e-critical-paths
        │   ├─ Wait for LMS heartbeat (up to 3 min)
        │   ├─ Run Playwright tests (tests/e2e/)
        │   ├─ Post commit status to GitHub
        │   └─ Upload artifacts (screenshots, logs)
        │
        └─ notify-on-failure (if e2e job failed)
```

The workflow posts an environment-scoped commit status (`post-deploy-e2e/critical-paths-staging` or `post-deploy-e2e/critical-paths-production`) visible on pull requests and the commit page. A `failure` status means the release is blocked for that lane.

---

## Running the Gate Manually

```bash
# Via GitHub CLI (defaults to the active staging lane)
gh workflow run post-deploy-e2e.yml \
  -f environment=staging

# Production is explicit while parked
gh workflow run post-deploy-e2e.yml \
  -f environment=production

# Via GitHub UI
# Go to Actions → Post-Deploy E2E Gate → Run workflow
```

---

## Running the Verification Script Locally

```bash
# Offline: check workflow wiring only (no network required)
./scripts/qa/verify-post-deploy-gate.sh

# Online: also query last run status from GitHub API
GITHUB_REPO=biji-biji/mereka-lms GH_TOKEN=ghp_... \
  ./scripts/qa/verify-post-deploy-gate.sh --mode online
```

---

## Debugging Failures

### 1. Download artifacts

```bash
# List recent runs
gh run list --workflow=post-deploy-e2e.yml --limit=5

# Download artifacts from last run
gh run download --name "post-deploy-e2e-<run_id>"
```

### 2. Check LMS health

```bash
# Are pods running?
kubectl get pods -n mereka-lms

# LMS logs (last 100 lines)
kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms --tail=100

# Endpoint health (staging default lane)
curl -I https://staging.academyv2.mereka.io/heartbeat
```

### 3. Re-run failing tests locally

```bash
# Install Playwright
cd tests/e2e && npm ci
npx playwright install --with-deps chromium

# Run with visible browser for debugging
BASE_URL=https://staging.academyv2.mereka.io \
E2E_USERNAME=e2e-learner@mereka.io \
E2E_PASSWORD=<password> \
npx playwright test --headed --debug
```

### 4. Check for SSO issues

Login failures are most commonly caused by SSO session problems or missing credential sources. Check:

```bash
# Verify Authentik is healthy
curl -I https://auth0.mereka.io/api/v3/

# Check SSO canary
./scripts/qa/verify-authenticated-sso-canary.sh --env prod
```

If the gate fails before Playwright starts, verify that either:

- `E2E_TEST_USERNAME` and `E2E_TEST_PASSWORD` are set, or
- the matching `SSO_CANARY_*` credentials exist for the selected environment

The shared `.github/actions/setup-playwright` action resolves the Playwright version from `tests/e2e/package-lock.json` and reinstalls Chromium if a restored cache is stale or incomplete. A browser-launch failure after that usually indicates runner image drift rather than the old stale-cache bug.

If the gate fails on `production` heartbeat while `staging` passes, that currently indicates the parked prod lane was targeted explicitly. Re-run against `staging` unless you are intentionally validating the parked prod path.

---

## Marking a Release Complete

A release may only be marked complete after:

1. The post-deploy E2E gate shows `success` on the deployment commit
2. `./scripts/qa/verify-post-deploy-gate.sh --mode online` returns `PASS`
3. No P0 incidents are open in the operations runbook

If the gate fails and the failure is a known flake (not a real regression), document the exception in a PR comment and get sign-off from a second engineer before proceeding.

---

## Edge Cases

- **Gate skips if deploy failed**: If the upstream `Build Tutor Images` workflow fails, the E2E gate skips automatically (no point testing a broken deploy).
- **Concurrency**: Only one gate run per environment at a time. If a gate is already running, a new trigger waits; it does not cancel the in-progress run.
- **No Playwright config yet**: If `tests/e2e/` does not exist (T049 not yet merged), the gate falls back to running `verify-post-deploy-gate.sh --mode offline`, which verifies wiring only. This is a graceful degradation — not a bypass.
- **Missing credentials**: If neither `E2E_TEST_*` overrides nor the selected environment's `SSO_CANARY_*` credentials are available, the gate fails with a clear error before attempting any browser tests.

---

## Related

- Workflow: `.github/workflows/post-deploy-e2e.yml`
- Verification: `scripts/qa/verify-post-deploy-gate.sh`
- E2E framework: `tests/e2e/` (created by T049)
- Operations gate: `scripts/qa/run-operations-gates.sh`
- Post-deploy smoke: `scripts/qa/verify-post-deploy-smoke.sh`
- Spec: `specs/ci-cd-pipeline_spec.md` (AC-040 through AC-044)
