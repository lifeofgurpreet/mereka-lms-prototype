---
title: Wave Migrations Root Reset Closeout
owner: Platform Team
status: canonical
last_verified: 2026-03-10
canonical_root: docs/meta/docs-program
doc_class: closeout
summary: Final state and validation record for retiring docs/migrations as a mixed legacy root.
tags:
  - docs
  - migrations
  - root-reset
audience: Contributors
---

# Wave Migrations Root Reset Closeout

## Final state

`docs/migrations/**` is no longer a living mixed root. Its final shape is:

```text
docs/migrations/
  README.md
```

## Canonical owners

- Runbooks: `docs/ops/runbooks/migrations/**`
- Reference: `docs/reference/migrations/**`
- Status: `docs/status/migrations/**`
- Historical reports: `docs/archive/reports/mct/**` and `docs/archive/reports/migrations/**`

## What moved

- Kajabi execution guides moved to `docs/ops/runbooks/migrations/kajabi/**`
- MCT execution guides moved to `docs/ops/runbooks/migrations/mct/**`
- Kajabi migration notes and lesson-content issue analysis moved to `docs/reference/migrations/kajabi/**`
- MCT export/result/completion narratives moved to `docs/archive/reports/mct/**`
- `BBI-K8-MIGRATION.md` moved to `docs/archive/reports/migrations/**`

## Guardrail

`tools/docs/verify/verify_legacy_migrations_root.py` enforces that `docs/migrations/**` stays tombstone-only and that active files do not depend on this root as primary truth.

## Validation

- `python3 tools/docs/verify/verify_legacy_migrations_root.py --repo-root .`
- `python3 tools/docs/verify/build-doc-catalog.py --root .`
- `bash tools/docs/verify/verify-docs-policy.sh --range origin/main...HEAD`
- `bash scripts/qa/verify-migration-rollback.sh`
- `bash scripts/qa/test-verify-migration-rollback.sh`

## Remaining residue

- `docs/mct/MCT_MIGRATION_STATUS.md` remains a compatibility shim outside the retired root.
- Generated catalogs and graph projections were refreshed as follow-up projections, not hand-maintained truth.
