# Post-Deploy E2E Gate
_Audience: Operators and developers • Owner: Platform Team • Last verified: 2026-03-12 • Status: active_

<!-- Last verified: 2026-02-24 -->

The post-deploy E2E gate blocks release completion if any of the five critical user paths fail after a deployment. It runs automatically after each successful build-and-push and can be re-run manually.

---

## Overview

| Property | Value |
|----------|-------|
| **Workflow** | `.github/workflows/post-deploy-e2e.yml` |
| **Verification script** | `scripts/qa/verify-post-deploy-gate.sh` |
| **Trigger** | Automatic after `Build and Push Tutor Images` succeeds; manual dispatch |
| **Default target** | `https://academyv2.mereka.io` |
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

Set these as GitHub repository secrets before the gate can run:

| Secret | Description |
|--------|-------------|
| `E2E_TEST_USERNAME` | Test learner account email |
| `E2E_TEST_PASSWORD` | Test learner account password |
| `E2E_TEST_COURSE_ID` | Course ID to use for enrollment / video / forum / certificate tests (can also be a repository variable) |

The test account must be enrolled in the test course and must have completed it (for certificate tests). Create a dedicated `e2e-learner@mereka.io` account in the LMS with a completed course run.

---

## How It Works

```
Build and Push Tutor Images (success)
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

The workflow posts a commit status (`post-deploy-e2e/critical-paths`) visible on pull requests and the commit page. A `failure` status means the release is blocked.

---

## Running the Gate Manually

```bash
# Via GitHub CLI (targets production)
gh workflow run post-deploy-e2e.yml \
  -f target_url=https://academyv2.mereka.io \
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

# Endpoint health
curl -I https://academyv2.mereka.io/heartbeat
```

### 3. Re-run failing tests locally

```bash
# Install Playwright
cd tests/e2e && npm ci
npx playwright install --with-deps chromium

# Run with visible browser for debugging
LMS_BASE_URL=https://academyv2.mereka.io \
E2E_USERNAME=e2e-learner@mereka.io \
E2E_PASSWORD=<password> \
npx playwright test --headed --debug
```

### 4. Check for SSO issues

Login failures are most commonly caused by SSO session problems. Check:

```bash
# Verify Authentik is healthy
curl -I https://auth0.mereka.io/api/v3/

# Check SSO canary
./scripts/qa/verify-authenticated-sso-canary.sh --env prod
```

---

## Marking a Release Complete

A release may only be marked complete after:

1. The post-deploy E2E gate shows `success` on the deployment commit
2. `./scripts/qa/verify-post-deploy-gate.sh --mode online` returns `PASS`
3. No P0 incidents are open in the operations runbook

If the gate fails and the failure is a known flake (not a real regression), document the exception in a PR comment and get sign-off from a second engineer before proceeding.

---

## Edge Cases

- **Gate skips if deploy failed**: If the upstream `Build and Push Tutor Images` workflow fails, the E2E gate skips automatically (no point testing a broken deploy).
- **Concurrency**: Only one gate run per environment at a time. If a gate is already running, a new trigger waits; it does not cancel the in-progress run.
- **No Playwright config yet**: If `tests/e2e/` does not exist (T049 not yet merged), the gate falls back to running `verify-post-deploy-gate.sh --mode offline`, which verifies wiring only. This is a graceful degradation — not a bypass.
- **Missing secrets**: If `E2E_TEST_USERNAME` or `E2E_TEST_PASSWORD` are not set, the gate fails with a clear error before attempting any browser tests.

---

## Related

- Workflow: `.github/workflows/post-deploy-e2e.yml`
- Verification: `scripts/qa/verify-post-deploy-gate.sh`
- E2E framework: `tests/e2e/` (created by T049)
- Operations gate: `scripts/qa/run-operations-gates.sh`
- Post-deploy smoke: `scripts/qa/verify-post-deploy-smoke.sh`
- Spec: `specs/ci-cd-pipeline_spec.md` (AC-040 through AC-044)
