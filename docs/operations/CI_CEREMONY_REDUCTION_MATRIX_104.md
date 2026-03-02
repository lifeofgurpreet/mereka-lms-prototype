# CI Ceremony Reduction Matrix (#104 Follow-on)

Date: 2026-03-02  
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
| Workflow files (`.github/workflows/*.yml`) | 60 |
| Verify scripts (`scripts/qa/verify-*.sh`) | 495 |
| Make targets (`Makefile` target declarations) | 76 |

## Deletion / Consolidation Matrix

| Candidate | Type | Why redundant | Canonical replacement | Status |
|---|---|---|---|---|
| `.github/workflows/policy-checks.yml` | Workflow wrapper | Manual-only fanout of contract wrappers that duplicate checks already covered by `ci.yml` static lanes | `ci.yml` + `verify-ci-cd-pipeline.sh` | Planned |
| `scripts/qa/verify-*-workflow.sh` family (18 files) | Meta wrapper scripts | Checks wrapper/workflow shape rather than runtime behavior; high ceremony, low signal | Direct source/runtime checks already in `ci-scripts-static.txt` | Planned |
| `Makefile` frontend QA wrapper aliases (env-specific duplicates) | Make target duplication | Multiple targets differ only by env/flags | Parameterized canonical targets (`QA_ENV`, `QA_MFE_ONLY`, gate flags) | In progress |

## Projected Counts After Follow-on Tranche

If the `policy-checks` workflow and 18 meta wrapper scripts are removed in one focused tranche:

| Metric | Current | Projected | Delta |
|---|---:|---:|---:|
| Workflow files | 60 | 59 | -1 |
| Verify scripts | 495 | 477 | -18 |
| Make targets | 76 | 70-73 | -3 to -6 |

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

This follow-on reduction is gated on a clean integration window because several contract scripts currently have parallel-agent local modifications in this worktree.  
To avoid mixing unrelated edits, execute removal tranche only when those files are either merged upstream or isolated in a clean branch.
