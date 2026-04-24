# Retired Root Remediation Proof

## Scope

This proof records the bounded Lane G slice that removes enterprise-tenancy living content from the retired `docs/architecture/**` and `docs/operations/**` roots.

## Files Moved

- `docs/architecture/ADMIN_SURFACES_AND_ENTRYPOINTS.md` -> `docs/reference/architecture/ADMIN_SURFACES_AND_ENTRYPOINTS.md`
- `docs/architecture/ENTERPRISE_TENANT_VARIANTS.md` -> `docs/reference/architecture/ENTERPRISE_TENANT_VARIANTS.md`
- `docs/architecture/STABLE_CONFIG_ROLLOUT_DEBT.md` -> `docs/stabilization/STABLE_CONFIG_ROLLOUT_DEBT.md`
- `docs/architecture/TENANT_DOMAIN_AUTHORITY_MATRIX.md` -> `docs/reference/architecture/TENANT_DOMAIN_AUTHORITY_MATRIX.md`
- `docs/architecture/TENANT_DOMAIN_SURFACE_AUTHORITY.md` -> `docs/reference/architecture/TENANT_DOMAIN_SURFACE_AUTHORITY.md`
- `docs/architecture/TENANT_MODEL_RECOMMENDATION.md` -> `docs/reference/architecture/TENANT_MODEL_RECOMMENDATION.md`
- `docs/operations/ENTERPRISE_BOOTSTRAP_APPLY_RUNBOOK.md` -> `docs/ops/runbooks/ENTERPRISE_BOOTSTRAP_APPLY_RUNBOOK.md`
- `docs/operations/ENTERPRISE_DATA_MODEL_AUDIT.md` -> `docs/stabilization/ENTERPRISE_DATA_MODEL_AUDIT.md`

## Files Tombstoned Or Collapsed

- `docs/architecture/SALVAGE_BRANCH_LEDGER.md` removed as a retired-root duplicate of `docs/reference/architecture/SALVAGE_BRANCH_LEDGER.md`
- `docs/operations/ENTERPRISE_DATA_AUDIT.md` removed as a duplicate of `docs/stabilization/ENTERPRISE_DATA_MODEL_AUDIT.md`
- `docs/architecture/README.md` retained as the only allowed architecture tombstone
- `docs/operations/README.md` retained as the only allowed operations tombstone

## References Updated

- `docs/reviews/ENTERPRISE_TENANCY_REVIEW_SUMMARY.md` now points to canonical `docs/reference/**`, `docs/ops/runbooks/**`, and `docs/stabilization/**` paths

## Verifier Result

Primary verifier:

- `scripts/qa/verify-retired-root-remediation.sh`

Supporting governance artifacts:

- `docs/stabilization/RETIRED_ROOT_REMEDIATION_LEDGER.md`
- `docs/stabilization/retired-root-remediation-ledger.v1.yaml`
- `docs/stabilization/DOCS_ROOT_AUTHORITY_CONTRACT.md`

Expected result for this slice:

- only `docs/architecture/README.md` and `docs/operations/README.md` remain under the retired roots
- active review docs no longer point to retired-root substantive files

## Intentionally Deferred Debt

- governance docs may still mention retired roots when documenting the retirement contract itself
- any future file with ambiguous canonical ownership must be classified in the ledger before migration, not guessed into a new root
