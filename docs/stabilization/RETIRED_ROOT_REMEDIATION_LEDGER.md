# Retired Root Remediation Ledger
_Audience: Contributors and reviewers • Owner: Platform Team • Last updated: 2026-03-11 • Status: canonical_

This ledger records the bounded retirement slice for legacy content that still lived under `docs/architecture/**` and `docs/operations/**`.

## Scope

This slice covers the enterprise-tenancy documents that were still creating docs-governance ambiguity:

- living content under retired roots
- active review docs still linking to retired-root paths
- duplicate artifacts that kept two live answers in circulation

It does not attempt a repo-wide prose rewrite. If a destination is ambiguous, that item stays classified and deferred instead of being guessed into a new root.

## Classification Legend

| Classification | Meaning |
| --- | --- |
| `ACTIVE` | Living content was still parked in a retired root and needed migration |
| `SUPERSEDED` | A stronger canonical replacement already existed |
| `DUPLICATE` | The retired-root file duplicated another active artifact and should collapse |
| `TOMBSTONE_CANDIDATE` | Transitional file that should shrink to a stub or disappear once references are repaired |
| `REFERENCE_ONLY` | Intentional compatibility tombstone; may remain in the retired root |

## Retired-Root Inventory

| Retired path | Classification | Canonical destination | Inbound references before | Resolution in this slice |
| --- | --- | --- | --- | --- |
| docs/architecture/ADMIN_SURFACES_AND_ENTRYPOINTS.md | `ACTIVE` | `docs/reference/architecture/ADMIN_SURFACES_AND_ENTRYPOINTS.md` | `docs/reviews/ENTERPRISE_TENANCY_REVIEW_SUMMARY.md` | Moved to canonical reference root; retired-root file removed |
| docs/architecture/ENTERPRISE_TENANT_VARIANTS.md | `ACTIVE` | `docs/reference/architecture/ENTERPRISE_TENANT_VARIANTS.md` | `docs/reviews/ENTERPRISE_TENANCY_REVIEW_SUMMARY.md` | Moved to canonical reference root; retired-root file removed |
| docs/architecture/SALVAGE_BRANCH_LEDGER.md | `DUPLICATE` | `docs/reference/architecture/SALVAGE_BRANCH_LEDGER.md` | `docs/reviews/ENTERPRISE_TENANCY_REVIEW_SUMMARY.md` | Retired-root duplicate removed; canonical reference copy retained |
| docs/architecture/STABLE_CONFIG_ROLLOUT_DEBT.md | `ACTIVE` | `docs/stabilization/STABLE_CONFIG_ROLLOUT_DEBT.md` | `docs/reviews/ENTERPRISE_TENANCY_REVIEW_SUMMARY.md` | Moved to stabilization root; retired-root file removed |
| docs/architecture/TENANT_DOMAIN_AUTHORITY_MATRIX.md | `ACTIVE` | `docs/reference/architecture/TENANT_DOMAIN_AUTHORITY_MATRIX.md` | `docs/reviews/ENTERPRISE_TENANCY_REVIEW_SUMMARY.md` | Moved to canonical reference root; retired-root file removed |
| docs/architecture/TENANT_DOMAIN_SURFACE_AUTHORITY.md | `ACTIVE` | `docs/reference/architecture/TENANT_DOMAIN_SURFACE_AUTHORITY.md` | `docs/reviews/ENTERPRISE_TENANCY_REVIEW_SUMMARY.md` | Moved to canonical reference root; retired-root file removed |
| docs/architecture/TENANT_MODEL_RECOMMENDATION.md | `ACTIVE` | `docs/reference/architecture/TENANT_MODEL_RECOMMENDATION.md` | `docs/reviews/ENTERPRISE_TENANCY_REVIEW_SUMMARY.md` | Moved to canonical reference root; retired-root file removed |
| docs/operations/ENTERPRISE_BOOTSTRAP_APPLY_RUNBOOK.md | `ACTIVE` | `docs/ops/runbooks/ENTERPRISE_BOOTSTRAP_APPLY_RUNBOOK.md` | `docs/reviews/ENTERPRISE_TENANCY_REVIEW_SUMMARY.md` | Moved to canonical runbook root; retired-root file removed |
| docs/operations/ENTERPRISE_DATA_AUDIT.md | `DUPLICATE` | `docs/stabilization/ENTERPRISE_DATA_MODEL_AUDIT.md` | `docs/reviews/ENTERPRISE_TENANCY_REVIEW_SUMMARY.md` | Retired-root duplicate removed; canonical stabilization copy retained |
| docs/operations/ENTERPRISE_DATA_MODEL_AUDIT.md | `ACTIVE` | `docs/stabilization/ENTERPRISE_DATA_MODEL_AUDIT.md` | `docs/reviews/ENTERPRISE_TENANCY_REVIEW_SUMMARY.md` | Moved to stabilization root; retired-root file removed |
| `docs/architecture/README.md` | `REFERENCE_ONLY` | `docs/concepts/architecture/README.md` | governance docs only | Retained as the only allowed architecture-root tombstone |
| `docs/operations/README.md` | `REFERENCE_ONLY` | `docs/ops/README.md` | governance docs only | Retained as the only allowed operations-root tombstone |

## References Repaired

This slice updated active review references away from retired roots:

- `docs/reviews/ENTERPRISE_TENANCY_REVIEW_SUMMARY.md`

Governance and proof artifacts are allowed to name retired roots only as retirement context:

- this ledger
- `docs/stabilization/DOCS_ROOT_AUTHORITY_CONTRACT.md`
- `scripts/qa/verify-retired-root-remediation.sh`
- `var/proofs/retired-root-remediation.md`

## Canonical Root Decisions Locked By This Slice

| Document type | Canonical root |
| --- | --- |
| enterprise surface maps, tenancy matrices, tenancy recommendations | `docs/reference/architecture/**` |
| enterprise bootstrap operator procedure | `docs/ops/runbooks/**` |
| remediation debt, audits, and stabilization ledgers | `docs/stabilization/**` |

## Deferred Debt

Remaining retired-root debt after this slice is intentionally narrow:

- `docs/architecture/README.md` stays as a tombstone-only redirect
- `docs/operations/README.md` stays as a tombstone-only redirect
- governance docs may still reference retired roots when documenting the retirement contract itself

Anything beyond those cases is verifier-owned debt and should fail the retired-root remediation check.
