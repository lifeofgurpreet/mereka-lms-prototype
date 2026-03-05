# CI Runner Policy

**Parent docs**: [CI_CD_RUNNERS.md](CI_CD_RUNNERS.md) | [CI_OPTIMIZATION_TRACKER.md](CI_OPTIMIZATION_TRACKER.md)
**Related**: [CI_CD_SETUP.md](CI_CD_SETUP.md) | [CI_PIPELINE_COST_OPTIMIZATION.md](CI_PIPELINE_COST_OPTIMIZATION.md)

---

## Overview

This document defines which runner class each workflow job type must use. It is the authoritative
policy for `runs-on` label selection in `.github/workflows/*.yml`.

The policy is enforced by `scripts/qa/verify-ci-runner-policy.sh`, which is registered in
`.github/ci-scripts-static.txt` and runs on every PR.

---

## Runner Classes

### Class A — ARC Lightweight (`mereka-k8s-runners`)

| Property | Value |
|----------|-------|
| Label | `mereka-k8s-runners` |
| Resources | 2 CPU, 4 GB RAM |
| Docker | Not available (no DinD sidecar) |
| Cluster access | Yes (in-cluster, kubectl pre-configured) |
| Cost | Sunk-cost (VPS always on) |
| Fallback expression | `${{ vars.USE_SELF_HOSTED_RUNNERS == 'true' && 'mereka-k8s-runners' || 'ubuntu-24.04' }}` |

Use for jobs that need live cluster access, runtime checks, or scheduled audits. These jobs
benefit from in-cluster network proximity (no external auth round-trip) and eliminate GitHub-hosted
runner minutes on workloads that run dozens of times per day.

### Class B — ARC Heavy (`mereka-k8s-heavy-builders`)

| Property | Value |
|----------|-------|
| Label | `mereka-k8s-heavy-builders` |
| Resources | 4 CPU, 12 GB RAM + DinD sidecar (4 CPU, 8 GB RAM) |
| Docker | Available via TLS-authenticated TCP socket |
| PVC caches | `arc-docker-cache` (50 Gi), `arc-dep-cache` (10 Gi) |
| Cost | Sunk-cost (VPS always on) |

Use for Docker image builds and Playwright E2E tests that require browser downloads. These jobs
benefit from the persistent BuildKit layer cache and npm/Playwright browser cache across runs,
dropping image build times from 30+ min to ~5 min on warm cache.

### Class C — GitHub-Hosted (`ubuntu-24.04`) — RESTRICTED

| Property | Value |
|----------|-------|
| Label | `ubuntu-24.04` |
| Resources | Standard GitHub-hosted runner (2 CPU, 7 GB RAM) |
| Docker | Available (but no persistent cache) |
| Cluster access | No (cannot reach rke2-nonprod) |
| Cost | Per-minute billing |

**RESTRICTED**: GitHub-hosted runners are ONLY permitted for workflows that require
GitHub-native tooling APIs (CodeQL, OSSF Scorecard, Dependency Review). All other jobs
MUST use ARC runners (Class A or B). If ARC is unavailable, jobs fail — this is intentional
to ensure infra issues are surfaced and fixed, not silently worked around.

Permitted exceptions:
- `codeql.yml` — requires GitHub CodeQL Actions integration
- `scorecard.yml` — requires GitHub OSSF Scorecard API
- `dependency-review.yml` — requires GitHub dependency graph API

### Class D — GitHub-Hosted macOS (`macos-14`)

Use only for iOS/macOS-specific builds. macOS runners cost 10x the Linux per-minute rate; all
Apple platform jobs must use `workflow_dispatch` or tag-only triggers (never `push: branches: [main]`).

### Class E — Reusable Workflow (no `runs-on`)

Jobs that use `uses:` to call a reusable workflow do not set `runs-on` directly. The runner
is determined by the called workflow. This applies to `build-enterprise-mfe.yml` and
`build-purchase-gateway.yml` (both call `bbi-infrastructure` reusable workflows).

---

## Job-Type Routing Rules

| Job type | Required runner class | Rationale |
|----------|----------------------|-----------|
| Docker image builds (Tutor openedx, MFE) | B — ARC heavy | Needs DinD + 12 GB RAM + BuildKit PVC cache |
| Playwright E2E / browser-based tests | B — ARC heavy | Needs DinD or browser cache PVC |
| Live cluster health checks | A — ARC lightweight | In-cluster kubectl access |
| ArgoCD drift checks (online) | A — ARC lightweight | Needs kubectl to compare live state |
| Runtime observability audits | A — ARC lightweight | Reads live cluster metrics |
| Secret scanning (TruffleHog full history) | A — ARC lightweight | Sunk-cost, no reason for GitHub-hosted |
| Tenant isolation gates | A — ARC lightweight | Cluster-awareness needed for full checks |
| DR evidence bundle | A — ARC lightweight | Reads live cluster state |
| Static analysis / linting | A — ARC lightweight | ARC-only policy — no GitHub-hosted fallback |
| YAML / Markdown / shell syntax checks | A — ARC lightweight | ARC-only policy — no GitHub-hosted fallback |
| Unit and integration tests (Python) | A — ARC lightweight | ARC-only policy — no GitHub-hosted fallback |
| Tutor config tests (offline rendering) | A — ARC lightweight | ARC-only policy — no GitHub-hosted fallback |
| CodeQL / Scorecard / Dependency Review | C — GitHub-hosted | GitHub-managed security tooling (ONLY exceptions) |
| Release evidence assembly (offline) | A — ARC lightweight | ARC-only policy — no GitHub-hosted fallback |
| iOS / macOS builds | D — macOS | Apple platform requirement |
| Reusable workflow call | E — no runs-on | Delegated to callee |

---

## Fallback Expression Pattern — DEPRECATED

**As of 2026-03-05, fallback expressions are REMOVED.** All workflows now hard-code ARC runner
labels. If ARC is unavailable, jobs fail — this is intentional to surface infrastructure issues.

The old pattern was:
```yaml
# DEPRECATED — do not use
runs-on: ${{ vars.USE_SELF_HOSTED_RUNNERS == 'true' && 'mereka-k8s-runners' || 'ubuntu-24.04' }}
```

The correct pattern is now:
```yaml
runs-on: mereka-k8s-runners        # Class A — lightweight
runs-on: mereka-k8s-heavy-builders  # Class B — Docker builds, Playwright
```

---

## Current Audit — All Workflows (updated 2026-03-05)

All workflows migrated to ARC self-hosted runners. No GitHub-hosted fallback expressions remain.

Legend:
- `CONFORM` — uses correct ARC runner label
- `EXCEPTION` — GitHub-hosted, permitted per Class C/D policy
- `REUSABLE` — job delegates to reusable workflow (no `runs-on` set here)

| Workflow file | Job(s) | `runs-on` | Policy class | Status |
|---------------|--------|-----------|--------------|--------|
| `a11y-tenant-branding.yml` | all | `mereka-k8s-runners` | A | CONFORM |
| `accessibility-audit.yml` | all | `mereka-k8s-runners` | A | CONFORM |
| `argocd-drift-check.yml` | all (3 jobs) | `mereka-k8s-runners` | A | CONFORM |
| `aspects-compat.yml` | all | `mereka-k8s-runners` | A | CONFORM |
| `atlas-health.yml` | all | `mereka-k8s-runners` | A | CONFORM |
| `build-enterprise-mfe.yml` | admin-portal, learner-portal | _(reusable)_ | E | REUSABLE |
| `build-ios-app.yml` | all | `macos-latest` | D | EXCEPTION |
| `build-purchase-gateway.yml` | build, update-dev | _(reusable)_ | E | REUSABLE |
| `build-tutor-images.yml` | Build OpenEdX/MFE Image | `mereka-k8s-heavy-builders` | B | CONFORM |
| `build-tutor-images.yml` | Lint, SLSA, Release, GitOps | `mereka-k8s-runners` | A | CONFORM |
| `certificate-branding.yml` | all | `mereka-k8s-runners` | A | CONFORM |
| `ci.yml` | all (4 jobs) | `mereka-k8s-runners` | A | CONFORM |
| `cloud-sql-backup.yml` | all | `mereka-k8s-runners` | A | CONFORM |
| `codeql.yml` | Analyze | `ubuntu-24.04` | C | EXCEPTION |
| `cross-browser-branding-smoke.yml` | all | `mereka-k8s-heavy-builders` | B | CONFORM |
| `daily-infrastructure-audit.yml` | all (4 jobs) | `mereka-k8s-runners` | A | CONFORM |
| `dependency-review.yml` | all | `ubuntu-24.04` | C | EXCEPTION |
| `dr-evidence-bundle.yml` | all | `mereka-k8s-runners` | A | CONFORM |
| `e2e-tests.yml` | all (2 jobs) | `mereka-k8s-runners` | A | CONFORM |
| `email-template-branding.yml` | all | `mereka-k8s-runners` | A | CONFORM |
| `frontend-before-after-visuals.yml` | all | `mereka-k8s-runners` | A | CONFORM |
| `frontend-branding-closure.yml` | all | `mereka-k8s-heavy-builders` | B | CONFORM |
| `frontend-performance-spotcheck.yml` | all | `mereka-k8s-runners` | A | CONFORM |
| `frontend-runtime-qa.yml` | all | `mereka-k8s-runners` | A | CONFORM |
| `iac-scan.yml` | all (2 jobs) | `mereka-k8s-runners` | A | CONFORM |
| `ios-testflight.yml` | all | `macos-14` | D | EXCEPTION |
| `lighthouse-ci.yml` | all | `mereka-k8s-runners` | A | CONFORM |
| `mfe-live-dom-audit.yml` | all | `mereka-k8s-heavy-builders` | B | CONFORM |
| `mfe-selector-hardening.yml` | all | `mereka-k8s-runners` | A | CONFORM |
| `mfe-slot-runtime-gates.yml` | all | `mereka-k8s-runners` | A | CONFORM |
| `mobile-secrets-check.yml` | all | `mereka-k8s-runners` | A | CONFORM |
| `npm-start-mfe-smoke.yml` | all | `mereka-k8s-heavy-builders` | B | CONFORM |
| `observability-compliance.yml` | all (2 jobs) | `mereka-k8s-runners` | A | CONFORM |
| `operations-gates-runtime.yml` | all | `mereka-k8s-runners` | A | CONFORM |
| `paragon-runtime-contract.yml` | all | `mereka-k8s-runners` | A | CONFORM |
| `paragon-theme-budget.yml` | all | `mereka-k8s-runners` | A | CONFORM |
| `phase2-smoke-evidence.yml` | all | `mereka-k8s-runners` | A | CONFORM |
| `post-deploy-e2e.yml` | all (3 jobs) | `mereka-k8s-runners` | A | CONFORM |
| `public-health-check.yml` | all | `mereka-k8s-runners` | A | CONFORM |
| `release-evidence-bundle.yml` | all | `mereka-k8s-runners` | A | CONFORM |
| `release-evidence.yml` | all | `mereka-k8s-runners` | A | CONFORM |
| `release.yml` | all | `mereka-k8s-runners` | A | CONFORM |
| `runtime-theme-drift-diagnose.yml` | all | `mereka-k8s-runners` | A | CONFORM |
| `scorecard.yml` | all | `ubuntu-24.04` | C | EXCEPTION |
| `secret-scan-audit.yml` | all | `mereka-k8s-runners` | A | CONFORM |
| `security-exceptions.yml` | all | `mereka-k8s-runners` | A | CONFORM |
| `smoke-authenticated.yml` | all (2 jobs) | `mereka-k8s-runners` | A | CONFORM |
| `smoke-authn-mfe.yml` | all | `mereka-k8s-runners` | A | CONFORM |
| `smoke-unauthenticated.yml` | all | `mereka-k8s-runners` | A | CONFORM |
| `tenant-isolation-check.yml` | all | `mereka-k8s-runners` | A | CONFORM |
| `tenant-safety-audit.yml` | all (2 jobs) | `mereka-k8s-runners` | A | CONFORM |
| `test-arc-runners.yml` | standard / heavy | `mereka-k8s-runners` / `mereka-k8s-heavy-builders` | A/B | CONFORM |
| `translation-check.yml` | all | `mereka-k8s-runners` | A | CONFORM |
| `ttfs-onboarding.yml` | all | `mereka-k8s-runners` | A | CONFORM |
| `tutor-plugin-test.yml` | all (6 jobs) | `mereka-k8s-runners` | A | CONFORM |
| `validate-multisite.yml` | all | `mereka-k8s-runners` | A | CONFORM |
| `verify-commit-signing.yml` | all | `mereka-k8s-runners` | A | CONFORM |
| `verify-wif-readiness.yml` | all | `mereka-k8s-runners` | A | CONFORM |
| `visual-regression-auth.yml` | all | `mereka-k8s-runners` | A | CONFORM |

---

## Exceptions with Rationale

| Workflow | Exception | Rationale |
|----------|-----------|-----------|
| `codeql.yml` | GitHub-hosted (`ubuntu-24.04`) | Requires GitHub CodeQL Actions integration (uploads SARIF to GitHub Security tab) |
| `scorecard.yml` | GitHub-hosted (`ubuntu-24.04`) | Requires GitHub OSSF Scorecard API (publishes to OpenSSF dashboard) |
| `dependency-review.yml` | GitHub-hosted (`ubuntu-24.04`) | Requires GitHub dependency graph API (only available on GitHub-hosted) |
| `build-ios-app.yml` | GitHub-hosted (`macos-latest`) | Apple platform — no ARC macOS runners available |
| `ios-testflight.yml` | GitHub-hosted (`macos-14`) | Apple platform — no ARC macOS runners available |

---

## Adding New Workflows

When adding a new workflow:

1. Set `runs-on: mereka-k8s-runners` (Class A) by default
2. Use `runs-on: mereka-k8s-heavy-builders` (Class B) only for Docker builds or Playwright E2E
3. **NEVER** use `ubuntu-24.04` or `ubuntu-latest` — the only exceptions are CodeQL/Scorecard/dependency-review
4. Run `scripts/qa/verify-ci-runner-policy.sh` to confirm compliance
5. Update the audit table in this document

### Legacy: Migrating `ubuntu-latest` to `ubuntu-24.04`

Legacy `ubuntu-latest` jobs (LEGACY status in the table above) are low-priority. To migrate:

1. Change `ubuntu-latest` → `ubuntu-24.04` in the workflow file
2. Trigger the workflow manually to verify compatibility
3. Update the status column in the audit table from `LEGACY` to `CONFORM`

There is currently **1 job** using `ubuntu-latest` that should be migrated: `build-ios-app.yml` uses `macos-latest` (Class D, tracked separately under the macOS runner class).

---

## Policy Enforcement

`scripts/qa/verify-ci-runner-policy.sh` enforces this policy in CI. It:

1. Parses every `.github/workflows/*.yml` file
2. Checks that `runs-on: mereka-k8s-heavy-builders` is used only for Docker build and Playwright jobs
3. Checks that `runs-on: ubuntu-latest` is not used (pinned version required)
4. Reports violations with workflow file and line number

The script runs as part of the `static-validation` job in `ci.yml` via `.github/ci-scripts-static.txt`.
It exits non-zero on violations so CI blocks merges.

See [CI_CD_RUNNERS.md](CI_CD_RUNNERS.md) for ARC infrastructure setup and troubleshooting.
