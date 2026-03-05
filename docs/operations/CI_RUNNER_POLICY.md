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

### Class C — GitHub-Hosted (`ubuntu-24.04`)

| Property | Value |
|----------|-------|
| Label | `ubuntu-24.04` (preferred) or `ubuntu-latest` (legacy, see note) |
| Resources | Standard GitHub-hosted runner (2 CPU, 7 GB RAM) |
| Docker | Available (but no persistent cache) |
| Cluster access | No (cannot reach rke2-nonprod) |
| Cost | Per-minute billing |

Use for jobs that do not need cluster access or Docker layer caching: static analysis, linting,
unit tests, documentation generation, and dependency reviews.

**Note on `ubuntu-latest`**: Several legacy workflows use `ubuntu-latest`, which is a rolling
pointer that can break on major runner image updates. New jobs must use `ubuntu-24.04` (pinned).
Existing `ubuntu-latest` usages are tracked in the migration table below.

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
| Live cluster health checks | A — ARC lightweight (with fallback) | In-cluster kubectl access |
| ArgoCD drift checks (online) | A — ARC lightweight (with fallback) | Needs kubectl to compare live state |
| Runtime observability audits | A — ARC lightweight (with fallback) | Reads live cluster metrics |
| Secret scanning (TruffleHog full history) | A — ARC lightweight (with fallback) | Scheduled, no cluster access required but benefits from self-hosted |
| Tenant isolation gates | A — ARC lightweight (with fallback) | Cluster-awareness needed for full checks |
| DR evidence bundle | A — ARC lightweight (with fallback) | Reads live cluster state |
| Static analysis / linting | C — GitHub-hosted | No cluster or Docker needed |
| YAML / Markdown / shell syntax checks | C — GitHub-hosted | No cluster or Docker needed |
| Unit and integration tests (Python) | C — GitHub-hosted | No cluster or Docker needed |
| Tutor config tests (offline rendering) | C — GitHub-hosted | Runs locally without cluster |
| Dependency review / CodeQL | C — GitHub-hosted | GitHub-managed security tooling |
| Documentation generation | C — GitHub-hosted | No cluster or Docker needed |
| Release evidence assembly (offline) | C — GitHub-hosted | Reads artifacts, no cluster needed |
| iOS / macOS builds | D — macOS | Apple platform requirement |
| Reusable workflow call | E — no runs-on | Delegated to callee |

---

## Fallback Expression Pattern

When a job should prefer ARC lightweight but must fall back to GitHub-hosted when ARC is not
deployed (e.g., on a fork or before ARC is provisioned), use:

```yaml
runs-on: ${{ vars.USE_SELF_HOSTED_RUNNERS == 'true' && 'mereka-k8s-runners' || 'ubuntu-24.04' }}
```

This is the **only approved pattern** for dual-mode jobs. Do not invent alternatives.

Set `USE_SELF_HOSTED_RUNNERS=true` as a GitHub repository variable when ARC runners are deployed
and healthy. Leave unset (or set to `false`) to force GitHub-hosted runners for all jobs.

---

## Current Audit — All Workflows

The table below documents every workflow file, each job, its current `runs-on`, the policy-required
runner class, and whether it conforms. **Do not change `runs-on` labels in workflow files directly**
— this table is the documentation layer; actual migration requires a separate PR with full CI
validation.

Legend:
- `CONFORM` — current label matches policy
- `LEGACY` — uses `ubuntu-latest` instead of pinned `ubuntu-24.04` (low priority migration)
- `FLAG` — potential policy mismatch (review before migrating)
- `REUSABLE` — job delegates to reusable workflow (no `runs-on` set here)

| Workflow file | Job name | Current `runs-on` | Policy class | Status |
|---------------|----------|-------------------|--------------|--------|
| `a11y-tenant-branding.yml` | _(unnamed)_ | `ubuntu-latest` | C | LEGACY |
| `accessibility-audit.yml` | axe-core WCAG 2.2 AA Audit | `ubuntu-24.04` | C | CONFORM |
| `argocd-drift-check.yml` | Offline Drift Check | fallback expr (`mereka-k8s-runners`) | A | CONFORM |
| `argocd-drift-check.yml` | Online Drift Check | fallback expr (`mereka-k8s-runners`) | A | CONFORM |
| `argocd-drift-check.yml` | Alert on Drift | fallback expr (`mereka-k8s-runners`) | A | CONFORM |
| `aspects-compat.yml` | Aspects Version Compatibility Check | `ubuntu-24.04` | C | CONFORM |
| `atlas-health.yml` | Atlas SRV Connectivity Verification | `ubuntu-24.04` | C | CONFORM |
| `build-enterprise-mfe.yml` | admin-portal | _(reusable)_ | E | REUSABLE |
| `build-enterprise-mfe.yml` | learner-portal | _(reusable)_ | E | REUSABLE |
| `build-ios-app.yml` | _(unnamed)_ | `macos-latest` | D | LEGACY (use `macos-14`) |
| `build-purchase-gateway.yml` | build | _(reusable)_ | E | REUSABLE |
| `build-purchase-gateway.yml` | update-dev | _(reusable)_ | E | REUSABLE |
| `build-tutor-images.yml` | Lint & Validate | `ubuntu-24.04` | C | CONFORM |
| `build-tutor-images.yml` | Build OpenEdX Image | `mereka-k8s-heavy-builders` | B | CONFORM |
| `build-tutor-images.yml` | Build MFE Image | `mereka-k8s-heavy-builders` | B | CONFORM |
| `build-tutor-images.yml` | SLSA Provenance & Attestation | `ubuntu-24.04` | C | CONFORM |
| `build-tutor-images.yml` | Generate Release Bundle | `ubuntu-24.04` | C | CONFORM |
| `build-tutor-images.yml` | Update GitOps | `ubuntu-24.04` | C | CONFORM |
| `certificate-branding.yml` | _(unnamed)_ | `ubuntu-latest` | C | LEGACY |
| `ci.yml` | Static Validation | `ubuntu-24.04` | C | CONFORM |
| `ci.yml` | Tutor Configuration Tests | `ubuntu-24.04` | C | CONFORM |
| `ci.yml` | Security Scans | `ubuntu-24.04` | C | CONFORM |
| `ci.yml` | Python test coverage | `ubuntu-24.04` | C | CONFORM |
| `cloud-sql-backup.yml` | _(unnamed)_ | `ubuntu-24.04` | C | CONFORM |
| `codeql.yml` | Analyze | `ubuntu-24.04` | C | CONFORM |
| `cross-browser-branding-smoke.yml` | _(unnamed)_ | `ubuntu-latest` | C | LEGACY |
| `daily-infrastructure-audit.yml` | Observability Audits | fallback expr (`mereka-k8s-runners`) | A | CONFORM |
| `daily-infrastructure-audit.yml` | Image Freshness Check | fallback expr (`mereka-k8s-runners`) | A | CONFORM |
| `daily-infrastructure-audit.yml` | Runtime parity | fallback expr (`mereka-k8s-runners`) | A | CONFORM |
| `daily-infrastructure-audit.yml` | Parity rollup summary | fallback expr (`mereka-k8s-runners`) | A | CONFORM |
| `dependency-review.yml` | Review dependencies | `ubuntu-24.04` | C | CONFORM |
| `dr-evidence-bundle.yml` | Build DR Evidence Bundle | fallback expr (`mereka-k8s-runners`) | A | CONFORM |
| `e2e-tests.yml` | Verify E2E Framework (offline) | fallback expr (`mereka-k8s-runners`) | A | FLAG (offline check; class C may be sufficient) |
| `e2e-tests.yml` | E2E Critical Path | fallback expr (`mereka-k8s-runners`) | A | CONFORM |
| `email-template-branding.yml` | _(unnamed)_ | `ubuntu-latest` | C | LEGACY |
| `frontend-before-after-visuals.yml` | Build Before/After Visual Evidence | `ubuntu-24.04` | C | CONFORM |
| `frontend-branding-closure.yml` | _(unnamed)_ | `ubuntu-latest` | C | LEGACY |
| `frontend-performance-spotcheck.yml` | _(unnamed)_ | `ubuntu-latest` | C | LEGACY |
| `frontend-runtime-qa.yml` | Run Runtime Frontend QA Tranche | `ubuntu-24.04` | C | CONFORM |
| `iac-scan.yml` | Trivy — K8s Manifests | `ubuntu-24.04` | C | CONFORM |
| `iac-scan.yml` | Trivy — Terraform | `ubuntu-24.04` | C | CONFORM |
| `ios-testflight.yml` | Build and Deploy to TestFlight | `macos-14` | D | CONFORM |
| `lighthouse-ci.yml` | Verify Lighthouse Budgets | `ubuntu-24.04` | C | CONFORM |
| `mfe-live-dom-audit.yml` | _(unnamed)_ | `ubuntu-latest` | C | LEGACY |
| `mfe-selector-hardening.yml` | _(unnamed)_ | `ubuntu-latest` | C | LEGACY |
| `mfe-slot-runtime-gates.yml` | Run MFE Slot Runtime Gates | fallback expr (`mereka-k8s-runners`) | A | CONFORM |
| `mobile-secrets-check.yml` | Mobile Secrets Offline Check | `ubuntu-24.04` | C | CONFORM |
| `npm-start-mfe-smoke.yml` | _(unnamed)_ | `ubuntu-latest` | C | LEGACY |
| `observability-compliance.yml` | Validate observability monitoring manifests | `ubuntu-24.04` | C | CONFORM |
| `observability-compliance.yml` | Runtime observability verification | `ubuntu-24.04` | C | FLAG (runtime check; could benefit from class A) |
| `operations-gates-runtime.yml` | Run Operations Gates (Runtime) | fallback expr (`mereka-k8s-runners`) | A | CONFORM |
| `paragon-runtime-contract.yml` | _(unnamed)_ | `ubuntu-latest` | C | LEGACY |
| `paragon-theme-budget.yml` | _(unnamed)_ | `ubuntu-latest` | C | LEGACY |
| `phase2-smoke-evidence.yml` | Run Phase 2 Smoke Evidence Gates | `ubuntu-24.04` | C | CONFORM |
| `post-deploy-e2e.yml` | Pre-flight Gate Check | fallback expr (`mereka-k8s-runners`) | A | CONFORM |
| `post-deploy-e2e.yml` | E2E Critical Path Tests | fallback expr (`mereka-k8s-runners`) | A | CONFORM |
| `post-deploy-e2e.yml` | Notify Gate Failure | fallback expr (`mereka-k8s-runners`) | A | CONFORM |
| `public-health-check.yml` | Branding + Public Endpoint Checks | fallback expr (`mereka-k8s-runners`) | A | CONFORM |
| `release-evidence-bundle.yml` | Assemble Release Evidence Bundle | `ubuntu-24.04` | C | CONFORM |
| `release-evidence.yml` | Build Release Evidence Bundle | `ubuntu-24.04` | C | CONFORM |
| `release.yml` | Create GitHub Release | `ubuntu-24.04` | C | CONFORM |
| `runtime-theme-drift-diagnose.yml` | Diagnose Runtime Theme Drift | `ubuntu-24.04` | C | CONFORM |
| `scorecard.yml` | Scorecard analysis | `ubuntu-24.04` | C | CONFORM |
| `secret-scan-audit.yml` | TruffleHog — Full History Scan | fallback expr (`mereka-k8s-runners`) | A | CONFORM |
| `security-exceptions.yml` | Verify security exception expiry dates | `ubuntu-24.04` | C | CONFORM |
| `smoke-authenticated.yml` | _(unnamed, job 1)_ | fallback expr (`mereka-k8s-runners`) | A | CONFORM |
| `smoke-authenticated.yml` | SSO Canary | fallback expr (`mereka-k8s-runners`) | A | CONFORM |
| `smoke-authn-mfe.yml` | Authn MFE Smoke Tests | `ubuntu-24.04` | C | FLAG (browser smoke test; class B preferred if Playwright) |
| `smoke-unauthenticated.yml` | Smoke | `ubuntu-24.04` | C | CONFORM |
| `tenant-isolation-check.yml` | Tenant Isolation Gates (offline) | fallback expr (`mereka-k8s-runners`) | A | CONFORM |
| `test-arc-runners.yml` | _(standard test)_ | `mereka-k8s-runners` | A | CONFORM (test workflow) |
| `test-arc-runners.yml` | _(heavy test)_ | `mereka-k8s-heavy-builders` | B | CONFORM (test workflow) |
| `translation-check.yml` | Verify Translation Completeness | `ubuntu-24.04` | C | CONFORM |
| `ttfs-onboarding.yml` | Verify TTFS Onboarding Funnel Config | `ubuntu-24.04` | C | CONFORM |
| `tutor-plugin-test.yml` | Test MFE OAuth Fix Plugin | `ubuntu-24.04` | C | CONFORM |
| `tutor-plugin-test.yml` | Test Plugin Enable/Disable Lifecycle | `ubuntu-24.04` | C | CONFORM |
| `tutor-plugin-test.yml` | Verify Custom App Structure | `ubuntu-24.04` | C | CONFORM |
| `tutor-plugin-test.yml` | Lint Plugin Code | `ubuntu-24.04` | C | CONFORM |
| `tutor-plugin-test.yml` | Integration Test - Plugin with Patches | `ubuntu-24.04` | C | CONFORM |
| `tutor-plugin-test.yml` | Post PR Comment on Plugin Test Failure | `ubuntu-24.04` | C | CONFORM |
| `validate-multisite.yml` | Validate SITE_VARIANTS and multisite config | `ubuntu-24.04` | C | CONFORM |
| `verify-commit-signing.yml` | Commit Signing Check | `ubuntu-24.04` | C | CONFORM |
| `verify-wif-readiness.yml` | Verify WIF Migration Readiness | `ubuntu-24.04` | C | CONFORM |
| `visual-regression-auth.yml` | Authenticated route checks | `ubuntu-24.04` | C | CONFORM |

---

## Exceptions with Rationale

| Workflow | Job | Exception | Rationale |
|----------|-----|-----------|-----------|
| `e2e-tests.yml` | Verify E2E Framework (offline) | Uses class A (ARC lightweight) instead of class C | The offline framework check runs together with the live E2E job; keeping both jobs on the same runner class simplifies the workflow trigger logic. Low cost impact. |
| `observability-compliance.yml` | Runtime observability verification | Uses class C instead of class A | Workflow is `workflow_dispatch` only (manual trigger). Not worth adding the fallback expression for a rarely-run manual gate. |
| `smoke-authn-mfe.yml` | Authn MFE Smoke Tests | Uses class C instead of class B | Uses `curl` + lightweight checks, not a full Playwright browser session. No Docker required. |

---

## Migration Checklist

Use this checklist when migrating a job from GitHub-hosted to ARC:

- [ ] Confirm ARC runners are healthy: `kubectl get autoscalingrunnersets -n arc-runners`
- [ ] Confirm `USE_SELF_HOSTED_RUNNERS=true` is set as a repository variable
- [ ] Update `runs-on` using the approved fallback expression (class A) or hard label (class B)
- [ ] Verify the job does not rely on GitHub-hosted runner tooling not present on ARC images
  - ARC images are based on `ghcr.io/actions/actions-runner-controller/gha-runner-scale-set-runner`
  - Common missing tools: `gh` CLI, `jq`, `yq` — install in job steps if needed
- [ ] Run the workflow manually with `workflow_dispatch` on a branch before merging
- [ ] Confirm `verify-ci-runner-policy.sh` passes after the change
- [ ] Update the audit table in this document to reflect the new status

### Migrating `ubuntu-latest` to `ubuntu-24.04`

Legacy `ubuntu-latest` jobs (LEGACY status in the table above) are low-priority. To migrate:

1. Change `ubuntu-latest` → `ubuntu-24.04` in the workflow file
2. Trigger the workflow manually to verify compatibility
3. Update the status column in the audit table from `LEGACY` to `CONFORM`

There are currently **12 jobs** using `ubuntu-latest` that should be migrated.

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
