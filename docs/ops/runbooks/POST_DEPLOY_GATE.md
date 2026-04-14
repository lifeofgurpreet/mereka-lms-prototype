# Post-Deploy E2E Gate
_Audience: Operators and developers • Owner: Platform Team • Last verified: 2026-03-27 • Status: active_

<!-- Last verified: 2026-02-24 -->

The post-deploy runtime gate enforces the current runtime-proof contract. In the present topology, manual browser proof defaults to staging, while automatic post-build runs verify that production remains intentionally parked at zero replicas.

The runtime policy also carries the successor production browser/runtime proof lane, the
non-dev synthetic fixture manifests, and the canonical smoke-account registry so production
reactivation does not depend on tribal knowledge.

---

## Overview

| Property | Value |
|----------|-------|
| **Workflow** | `.github/workflows/post-deploy-e2e.yml` |
| **Verification script** | `scripts/qa/verify-post-deploy-gate.sh` |
| **Trigger** | Automatic after `Build Tutor Images` succeeds; manual dispatch |
| **Runtime policy** | `config/runtime-proof-policy.env` |
| **Prod successor runtime verifier** | `scripts/tenants/verify-prod-runtime-proof.sh` |
| **Non-dev fixture manifests** | `config/runtime-proof/staging.synthetic-proof-fixtures.yaml`, `config/runtime-proof/prod.synthetic-proof-fixtures.yaml` |
| **Smoke credential contract** | `config/smoke-account-registry.yaml` |
| **Manual default target** | `https://staging.academyv2.mereka.io` |
| **Timeout** | 30 minutes |
| **Artifacts** | 30-day retention in `post-deploy-e2e-<run_id>` |

---

## Critical Paths Tested

These five paths are verified when the gate runs in browser-E2E mode. A failure in any one blocks the release for that environment.

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
        ├─ production parked?
        │   ├─ yes → verify-prod-parked-state.sh
        │   └─ no  → continue to browser E2E
        │
        ├─ e2e-critical-paths (staging/manual authoritative lane today)
        │   ├─ Wait for LMS heartbeat (up to 3 min)
        │   ├─ Run Playwright tests (tests/e2e/)
        │   ├─ Post environment-specific commit status to GitHub
        │   └─ Upload artifacts (screenshots, logs)
        │
        └─ notify-on-failure (if e2e job failed)
```

The workflow posts an environment-specific commit status:

- `post-deploy-e2e/critical-paths/staging` for staging browser proof
- `post-deploy/production-parked-state` for automatic production parked-state verification

A `failure` status means the active runtime contract for that lane is blocked.

---

## Running the Gate Manually

```bash
# Via GitHub CLI (manual proof defaults to staging)
gh workflow run post-deploy-e2e.yml \
  -f environment=staging

# Production stays on parked-state verification while parked
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
# Staging pods
kubectl get pods -n stg-mereka-lms

# Staging LMS logs (last 100 lines)
kubectl logs -n stg-mereka-lms -l app.kubernetes.io/name=lms --tail=100

# Staging endpoint health
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

For parked production verification, run:

```bash
./scripts/qa/verify-prod-parked-state.sh
```

### 4. Check for SSO issues

Login failures are most commonly caused by SSO session problems or missing credential sources. Check:

```bash
# Verify Authentik is healthy
curl -I https://auth0.mereka.io/api/v3/

# Check staging SSO canary
./scripts/qa/verify-authenticated-sso-canary.sh --env staging
```

If the gate fails before Playwright starts, verify that either:

- `E2E_TEST_USERNAME` and `E2E_TEST_PASSWORD` are set, or
- the matching `SSO_CANARY_*` credentials exist for the selected environment

The shared `.github/actions/setup-playwright` action resolves the Playwright version from `tests/e2e/package-lock.json` and reinstalls Chromium if a restored cache is stale or incomplete. A browser-launch failure after that usually indicates runner image drift rather than the old stale-cache bug.

If the gate fails in `production` parked-state mode, inspect the zero-replica and GitOps parked-state contract instead of trying to run browser E2E against prod.

If production is reactivated, switch the runtime lane to the successor verifier in
`config/runtime-proof-policy.env` and validate against the production fixture manifest and smoke
account registry before calling the lane runtime-complete.

---

## Marking a Release Complete

A release may only be marked complete after the relevant runtime lane proof passes:

1. staging browser proof shows `success` on the deployment commit when staging is the active runtime lane
2. production parked-state verification shows `success` when prod remains intentionally parked
3. if production is reactivated, `scripts/tenants/verify-prod-runtime-proof.sh` becomes the authoritative production runtime verifier instead of the parked-state check
4. `./scripts/qa/verify-post-deploy-gate.sh --mode online` returns `PASS`
5. No P0 incidents are open in the operations runbook

If the gate fails and the failure is a known flake (not a real regression), document the exception in a PR comment and get sign-off from a second engineer before proceeding.

## Exception Logging And Evidence Minimums

This runbook is the current owner for deployment-gate exception logging on the
rebased branch. Do not assume a separate deployment-gate evidence companion
exists unless a distinct operator workflow is later justified.

When a deployment proceeds with a known flake, manual exception, or temporary
runtime qualification, record all of the following in the release evidence or
PR discussion:

1. the exact failing gate or degraded assertion
2. the reason the failure is being treated as non-blocking
3. the artifact set reviewed:
   - run URL
   - screenshots, logs, or downloaded artifacts
   - verifier output used for the decision
4. the approving second engineer
5. the follow-up action required to remove the exception

Use [DEPLOYMENT_RUNBOOK.md](DEPLOYMENT_RUNBOOK.md) for the wider release and
promotion mechanics. Use this runbook for the runtime gate decision and the
minimum evidence needed to defend it.

---

## Edge Cases

- **Gate skips if deploy failed**: If the upstream `Build Tutor Images` workflow fails, the E2E gate skips automatically (no point testing a broken deploy).
- **Concurrency**: Only one gate run per environment at a time. If a gate is already running, a new trigger waits; it does not cancel the in-progress run.
- **No Playwright config yet**: If `tests/e2e/` does not exist (T049 not yet merged), the gate falls back to running `verify-post-deploy-gate.sh --mode offline`, which verifies wiring only. This is a graceful degradation — not a bypass.
- **Parked production**: Automatic post-build runs verify `scripts/qa/verify-prod-parked-state.sh` instead of browser E2E while production is intentionally parked.
- **Missing credentials**: If neither `E2E_TEST_*` overrides nor the selected environment's `SSO_CANARY_*` credentials are available, the gate fails with a clear error before attempting any browser tests.

---

## Related

- Workflow: `.github/workflows/post-deploy-e2e.yml`
- Verification: `scripts/qa/verify-post-deploy-gate.sh`
- E2E framework: `tests/e2e/` (created by T049)
- Operations gate: `scripts/qa/run-operations-gates.sh`
- Post-deploy smoke: `scripts/qa/verify-post-deploy-smoke.sh`
- Spec: `specs/ci-cd-pipeline_spec.md` (AC-040 through AC-044)
