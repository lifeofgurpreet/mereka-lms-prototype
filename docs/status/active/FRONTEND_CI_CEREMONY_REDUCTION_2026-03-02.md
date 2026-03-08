# Frontend CI Ceremony Reduction (2026-03-02)

## Scope

This change removes redundant frontend workflow wrappers and paired meta verifier scripts, and consolidates enforcement into `ci.yml` static-validation lanes and existing contract scripts.

## Deletion Matrix

| Removed workflow wrapper | Removed meta verifier script | Why redundant | Consolidated replacement path |
|---|---|---|---|
| `.github/workflows/frontend-branding-closure.yml` | `scripts/qa/verify-workflow-script-references.sh` | Wrapper-only ceremony replaced by consolidated static workflow/script reference checks | `ci.yml` static-validation lane (`run-scripts-parallel` + explicit frontend gates) and `scripts/qa/verify-ci-cd-pipeline.sh --section gitops` |
| `.github/workflows/frontend-runtime-qa.yml` | `scripts/qa/run-frontend-runtime-blocker-sweep.sh` | Legacy wrapper duplication removed in favor of consolidated runtime QA entrypoint | `ci.yml` static-validation lane with `verify-paragon-token-coverage.sh` (from `.github/ci-scripts-static.txt`) + explicit `verify-certificate-branding.sh` step |

## Makefile De-duplication

Parameterized duplicated frontend QA targets:

- `qa-npm-start-smoke` (uses `QA_ENV=prod|dev`, `REQUIRE_RUNTIME_THEME=1`)
- `qa-branding-screenshots` (uses `QA_ENV=prod|dev`, optional `QA_MFE_ONLY=1`)
- `qa-branding-before-after` (uses `QA_ENV=prod|dev`, optional `QA_MFE_ONLY=1`)

Removed duplicated prod/dev/mfe wrapper targets for the three families above.

## Before/After Counts

| Metric | Before | After | Delta |
|---|---:|---:|---:|
| Workflow files (`.github/workflows/*.yml`) | 61 | 59 | -2 |
| Verify scripts (`scripts/**/verify-*.sh`) | 505 | 503 | -2 |
| Make targets (`Makefile` target declarations) | 78 | 71 | -7 |

## Validation

Executed and passing after consolidation:

- `./scripts/qa/verify-workflow-script-references.sh`
- `./scripts/qa/run-frontend-runtime-blocker-sweep.sh`
- `./scripts/qa/verify-ci-cd-pipeline.sh --section gitops`
