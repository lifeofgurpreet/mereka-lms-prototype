# CI Ceremony Reduction Matrix (#104 Follow-on)

Date: 2026-03-03  
Scope: `mereka-lms` repo only (no GitOps repo changes)

## Canonical Execution Paths

1. Static/source checks: `.github/workflows/ci.yml` (`static-validation` via `.github/ci-scripts-static.txt`)
2. Runtime operations checks: `.github/workflows/operations-gates-runtime.yml`
3. Public runtime/branding checks: `.github/workflows/public-health-check.yml`
4. Release/runtime evidence generation: `.github/workflows/release-evidence.yml`

## Baseline Inventory (current)

Collected with:

```bash
ls .github/workflows/*.yml | wc -l
ls scripts/qa/verify-*.sh | wc -l
rg -n "^[A-Za-z0-9_.-]+:($|[^=])" Makefile | sed -E 's/:.*$//' | wc -l
```

| Metric | Current count |
|---|---:|
| Workflow files (`.github/workflows/*.yml`) | 56 |
| Verify scripts (`scripts/qa/verify-*.sh`) | 465 |
| Make targets (`Makefile` target declarations) | 77 |

## Deletion / Consolidation Matrix

| Candidate | Type | Why redundant | Canonical replacement | Status |
|---|---|---|---|---|
| `.github/workflows/policy-checks.yml` | Workflow wrapper | Manual-only fanout of contract wrappers that duplicate checks already covered by `ci.yml` static lanes | `ci.yml` + `verify-ci-cd-pipeline.sh` | Completed |
| `scripts/qa/verify-*-workflow.sh` family (18 files) | Meta wrapper scripts | Checks wrapper/workflow shape rather than runtime behavior; high ceremony, low signal | Direct source/runtime checks already in `ci-scripts-static.txt` | Completed |
| `Makefile` frontend QA wrapper aliases (env-specific duplicates) | Make target duplication | Multiple targets differ only by env/flags | Parameterized canonical target (`qa-frontend-closure` + `QA_ENV`/flag matrix) | Completed |

## Post-Tranche Counts

After removing `policy-checks` and the 18-script workflow-wrapper family, and parameterizing frontend closure Make lanes:

| Metric | Baseline | Current | Delta |
|---|---:|---:|---:|
| Workflow files | 60 | 56 | -4 |
| Verify scripts | 495 | 465 | -30 |
| Make targets | 76 | 77 | +1 |

## Follow-on Completion (Make Lane Canonicalization)

- Added canonical parameterized target:
  - `qa-frontend-closure` (driven by `QA_ENV`, `QA_CROSS_BROWSER`, `QA_CAPTURE_SCREENSHOTS`, `QA_MFE_ONLY`, `QA_REQUIRE_RUNTIME_THEME`)
- Removed redundant env-specific wrapper aliases to enforce one canonical execution path:
  - removed `qa-frontend-closure-prod`
  - removed `qa-frontend-closure-dev`
  - removed `qa-frontend-closure-prod-screenshots`
  - removed `qa-frontend-closure-prod-screenshots-mfe`
  - removed `qa-frontend-closure-dev-screenshots`
  - removed `qa-frontend-closure-dev-screenshots-mfe`
- Canonical invocation examples:
  - `make qa-frontend-closure QA_ENV=prod QA_CROSS_BROWSER=1 QA_REQUIRE_RUNTIME_THEME=1`
  - `make qa-frontend-closure QA_ENV=dev QA_CROSS_BROWSER=1 QA_CAPTURE_SCREENSHOTS=1 QA_MFE_ONLY=1`

## Wrapper Script Deletion Set (18)

1. `scripts/qa/verify-a11y-tenant-branding-workflow.sh`
2. `scripts/qa/verify-accessibility-audit-workflow.sh`
3. `scripts/qa/verify-certificate-branding-workflow.sh`
4. `scripts/qa/verify-cicd-tutor-config-workflow.sh`
5. `scripts/qa/verify-cross-browser-branding-workflow.sh`
6. `scripts/qa/verify-email-template-branding-workflow.sh`
7. `scripts/qa/verify-frontend-before-after-visuals-workflow.sh`
8. `scripts/qa/verify-frontend-branding-closure-workflow.sh`
9. `scripts/qa/verify-frontend-performance-spotcheck-workflow.sh`
10. `scripts/qa/verify-frontend-runtime-qa-workflow.sh`
11. `scripts/qa/verify-mfe-live-dom-audit-workflow.sh`
12. `scripts/qa/verify-mfe-selector-hardening-workflow.sh`
13. `scripts/qa/verify-npm-start-smoke-workflow.sh`
14. `scripts/qa/verify-paragon-runtime-contract-workflow.sh`
15. `scripts/qa/verify-paragon-theme-budget-workflow.sh`
16. `scripts/qa/verify-phase2-smoke-evidence-workflow.sh`
17. `scripts/qa/verify-release-evidence-workflow.sh`
18. `scripts/qa/verify-runtime-theme-drift-diagnose-workflow.sh`

## Execution Note

This tranche was executed in an isolated clean worktree to avoid colliding with parallel-agent dirty state in the primary workspace.  
No GitOps repository changes were required.
