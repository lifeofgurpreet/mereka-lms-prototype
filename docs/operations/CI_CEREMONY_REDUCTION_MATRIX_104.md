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

## Execution Note

This follow-on reduction is gated on a clean integration window because several contract scripts currently have parallel-agent local modifications in this worktree.  
To avoid mixing unrelated edits, execute removal tranche only when those files are either merged upstream or isolated in a clean branch.
