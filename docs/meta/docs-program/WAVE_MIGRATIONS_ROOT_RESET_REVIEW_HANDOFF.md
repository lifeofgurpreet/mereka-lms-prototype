---
title: Wave Migrations Root Reset Review Handoff
owner: Platform Team
status: historical review handoff snapshot
last_verified: 2026-04-14
canonical_root: docs/meta/docs-program
doc_class: review_handoff
summary: Reviewer handoff for the migrations root retirement wave.
tags:
  - docs
  - migrations
  - root-reset
audience: Reviewers
---

# Wave Migrations Root Reset Review Handoff

This document is retained as historical migrations-root reset review context.
It does not define the current docs-program execution front door or the
current architecture front door.

For current docs-program execution, use:

- [POST_REBASE_INTAKE_2026-04-13.md](POST_REBASE_INTAKE_2026-04-13.md)
- [REVIEW_HARDENING_BOARD_2026-04-13.md](REVIEW_HARDENING_BOARD_2026-04-13.md)
- [DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md](DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md)

For the current architecture front door, use:

- [../../architecture/README.md](../../architecture/README.md)

## Review focus

Confirm that:

- `docs/migrations/**` is tombstone-only
- execution guidance now lives only under `docs/ops/runbooks/migrations/**`
- reference material now lives only under `docs/reference/migrations/**`
- migration status now lives under `docs/status/migrations/**`
- historical narrative/result docs now live under archive report surfaces
- no active doc or spec still depends on `docs/migrations/**` as living truth

## Read-first

1. `docs/migrations/README.md`
2. `docs/ops/runbooks/migrations/README.md`
3. `docs/reference/migrations/README.md`
4. `docs/status/migrations/README.md`
5. `docs/meta/docs-program/WAVE_MIGRATIONS_ROOT_RESET_TRACKER.md`
6. `docs/meta/docs-program/WAVE_MIGRATIONS_ROOT_RESET_CLOSEOUT.md`

## Validation commands

- `python3 tools/docs/verify/verify_legacy_migrations_root.py --repo-root .`
- `python3 tools/docs/verify/build-doc-catalog.py --root .`
- `bash tools/docs/verify/verify-docs-policy.sh --range origin/main...HEAD`
- `bash scripts/qa/verify-migration-rollback.sh`
- `bash scripts/qa/test-verify-migration-rollback.sh`
