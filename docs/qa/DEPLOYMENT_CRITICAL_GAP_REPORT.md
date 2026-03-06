# Deployment-Critical Spec Coverage Gap Report

**Bead**: 23ry.3
**Date**: 2026-02-18
**Author**: Engineering (spec-planner / verify pipeline)
**Status**: Active — updated each time `verify-deployment-critical-coverage.sh` runs

---

## Summary

Seven specs govern deployment safety: ci-cd-pipeline, k8s-deployment, tutor-configuration,
tutor-configuration-resilience, branding-system, secrets-management, multi-tenancy-architecture.

Five of the seven are at 100% coverage. Two (ci-cd-pipeline and k8s-deployment) sit at ~86%
because their cross-spec integration criteria (AC-INT-\*) require a live cluster or GitHub
Actions runner and cannot be exercised purely from the repository tree.

All seven pass error-level lint and have matching plan and testplan files.

---

## Coverage Table

| Spec | Owner | Coverage | Total ACs | Unmapped | Tier | Plan | Testplan |
|------|-------|----------|-----------|----------|------|------|----------|
| ci-cd-pipeline | engineering | 86.0% | 43 | 6 | GREEN | present | present |
| k8s-deployment | engineering | 86.5% | 37 | 5 | GREEN | present | present |
| branding-system | engineering | 100% | 13 | 0 | GREEN | present | present |
| tutor-configuration | engineering | 100% | 10 | 0 | GREEN | present | present |
| tutor-configuration-resilience | engineering | 100% | 12 | 0 | GREEN | present | present |
| secrets-management | engineering | 100% | 18 | 0 | GREEN | present | present |
| multi-tenancy-architecture | engineering | 100% | 33 | 0 | GREEN | present | present |

All seven specs are in GREEN tier (≥ 80%). No spec is YELLOW or RED.

---

## Command Outputs

### Spec Lint (`mereka_spec_lint.py --severity-filter error`)

Run on 2026-02-18 from repository root:

```
=== ci-cd-pipeline ===
PASS specs/ci-cd-pipeline_spec.md

=== k8s-deployment ===
PASS specs/k8s-deployment_spec.md

=== branding-system ===
PASS specs/branding-system_spec.md

=== tutor-configuration ===
PASS specs/tutor-configuration_spec.md

=== tutor-configuration-resilience ===
PASS specs/tutor-configuration-resilience_spec.md

=== secrets-management ===
PASS specs/secrets-management_spec.md

=== multi-tenancy-architecture ===
PASS specs/multi-tenancy-architecture_spec.md
```

All seven specs pass error-level lint with zero violations.

### Coverage Dashboard (`spec_coverage_dashboard.py --format text`)

Excerpt showing deployment-critical rows (full dashboard: 38 specs, 976 ACs):

```
=== Spec Coverage Dashboard ===
38 specs | 976 ACs | 771 automated | 17 manual | 0 monitoring | 188 unmapped
Overall coverage: 80.7%

Tier | Spec                                    | ACs | Auto | Man | Mon | Unmapped | Coverage
-----|----------------------------------------|-----|------|-----|-----|----------|----------
   ? | branding-system                        |  13 |   13 |   0 |   0 |        0 |   100.0%
   ? | multi-tenancy-architecture             |  33 |   33 |   0 |   0 |        0 |   100.0%
   ? | secrets-management                     |  18 |   18 |   0 |   0 |        0 |   100.0%
   ? | tutor-configuration-resilience         |  12 |   12 |   0 |   0 |        0 |   100.0%
   ? | tutor-configuration                    |  10 |   10 |   0 |   0 |        0 |   100.0%
   ? | k8s-deployment                         |  37 |   32 |   0 |   0 |        5 |    86.5%
   ? | ci-cd-pipeline                         |  43 |   37 |   0 |   0 |        6 |    86.0%

Coverage tiers:
  GREEN  (>=80%): 33 specs
  YELLOW (50-79%): 0 specs
  RED    (<50%): 5 specs
```

---

## Unmapped ACs Detail

### ci-cd-pipeline (6 unmapped)

| AC ID | Description | Category |
|-------|-------------|----------|
| AC-INT-001 | K8s manifests pass `validate-k8s.sh`; CI builds and pushes images; production overlay references new tags and `kubectl apply` succeeds | Cross-spec integration (CI/CD → K8s) |
| AC-INT-002 | CI deployment workflow verifies ExternalSecrets reach `SecretSynced` before declaring success | Cross-spec integration (CI/CD → Secrets) |
| AC-INT-003 | CI runs secret validation (`infisical-validate-mereka-lms.sh`); fails build if required `MEREKA_LMS_*` key missing | Cross-spec integration (CI/CD → Secrets) |
| AC-INT-004 | CI builds openedx image; `branding-preflight.sh` passes and verifies Mereka logo presence | Cross-spec integration (CI/CD → Branding) |
| AC-003 | `lint` job fails when Python files have ruff violations | CI gate — requires live GitHub Actions runner |
| AC-004 | `validate-k8s` job fails when any YAML in `deploy/k8s/` is not a valid Kubernetes manifest | CI gate — requires live GitHub Actions runner |

**Root cause**: AC-INT-\* require a running GKE cluster and live Infisical integration.
AC-003 and AC-004 require a GitHub Actions runner with repository secrets available.
These cannot be tested from a pure repository-tree shell script.

### k8s-deployment (5 unmapped)

| AC ID | Description | Category |
|-------|-------------|----------|
| AC-INT-001 | ExternalSecrets deployed; K8s deployments reference `openedx-secrets`; all pods reach Running state | Cross-spec integration (K8s → Secrets) |
| AC-INT-002 | ExternalSecrets reach `SecretSynced`; `kubectl exec lms-pod -- env | grep OPENEDX_SECRET_KEY` returns non-empty value | Live cluster verification |
| AC-INT-003 | Secret rotated in Infisical, synced to GCP SM, ExternalSecrets refresh within 1h, new pods use rotated value | Live cluster end-to-end rotation |
| AC-INT-004 | K8s manifests reference MySQL; MySQL Deployment includes `--mysql-native-password=ON`; LMS connects | Cross-spec integration (K8s → Tutor config) |
| AC-INT-005 | Tutor config includes multi-site domains; running LMS pod `ALLOWED_HOSTS` contains all three domains | Cross-spec integration (K8s → multi-site) |

**Root cause**: All five require a live cluster (`kubectl exec`, ExternalSecret sync, pod environment
inspection). These are covered by the cluster-level verification scripts
(`scripts/qa/verify-k8s-deployment-spec.sh`, `scripts/qa/verify-kustomize-render.sh`) when a cluster
is present; they are excluded from the testmap because they cannot run in the repository-only CI
environment without cluster credentials.

---

## Owner Mapping

| Domain | Owner | Contact |
|--------|-------|---------|
| CI/CD pipeline | engineering | GitHub Actions; `.github/workflows/` |
| K8s deployment | engineering | `deploy/k8s/`; GKE production cluster |
| Tutor configuration | engineering | `infrastructure/tutor/`; `apply-patches.sh` |
| Tutor configuration resilience | engineering | Patch idempotency scripts |
| Branding system | engineering | `infrastructure/tutor/themes/mereka/` |
| Secrets management | engineering | Infisical → GCP SM → ExternalSecrets pipeline |
| Multi-tenancy architecture | engineering | `infrastructure/tutor/plugins/multi-tenancy/` |

All seven specs are owned by the engineering team. Sub-domain contacts are noted above for
cross-team escalation.

---

## Action Items

| AC IDs | Gap | Priority | Recommended Action |
|--------|-----|----------|--------------------|
| ci-cd-pipeline AC-INT-001..004, AC-003, AC-004 | Require live GHA runner or GKE cluster | P2 | Add to CI integration test suite that runs in nightly environment with cluster access; mark as `type: manual` in testmap with runbook reference |
| k8s-deployment AC-INT-001..005 | Require live cluster for pod/secret inspection | P2 | Covered by `scripts/qa/verify-k8s-live-cluster.sh` (and `scripts/qa/verify-k8s-deployment-spec.sh`) when `KUBECONFIG` is present; add `type: manual` entries pointing to `docs/operations/TROUBLESHOOTING.md` |

**Priority definitions:**
- **P1** — Blocking deployment; must resolve before next production release
- **P2** — Post-launch; should be resolved within next sprint cycle
- **P3** — Nice-to-have; defer to backlog

No P1 items. All unmapped ACs are P2 because the specs remain GREEN (≥ 80%) and the
uncovered criteria are live-cluster tests that run in the nightly integration lane.

---

## Duplicate AC ID Check

All seven deployment-critical specs were scanned for duplicate AC IDs on 2026-02-18.

| Spec | Duplicates Found |
|------|-----------------|
| ci-cd-pipeline | None |
| k8s-deployment | None |
| branding-system | None |
| tutor-configuration | None |
| tutor-configuration-resilience | None |
| secrets-management | None |
| multi-tenancy-architecture | None |

---

## AC Prefix Inventory

| Spec | Prefixes Used | Notes |
|------|--------------|-------|
| ci-cd-pipeline | `AC-NNN`, `AC-INT-NNN` | `INT` = cross-spec integration criteria (standard pattern) |
| k8s-deployment | `AC-NNN`, `AC-INT-NNN` | `INT` = cross-spec integration criteria (standard pattern) |
| branding-system | `AC-NNN`, `AC-INT-NNN` | `INT` = cross-spec integration criteria (standard pattern) |
| tutor-configuration | `AC-NNN` | No integration criteria; single-spec scope |
| tutor-configuration-resilience | `AC-TCR-NNN` | Spec-scoped prefix; consistent throughout |
| secrets-management | `AC-NNN` | No integration criteria; single-spec scope |
| multi-tenancy-architecture | `AC-MTA-NNN` | Spec-scoped prefix; consistent throughout |

All prefixes follow the `AC-PREFIX-NNN` pattern defined in `mereka_spec_lint.py`. The `INT`
prefix for cross-spec integration criteria is the established platform convention.

---

## Verification Script

To re-run these checks at any time:

```bash
./scripts/qa/verify-deployment-critical-coverage.sh
```

The script exercises all four acceptance criteria (AC-SPEC-301..304) and exits with code 0
only when all checks pass.
