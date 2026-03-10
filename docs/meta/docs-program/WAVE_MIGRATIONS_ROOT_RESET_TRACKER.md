---
title: Wave Migrations Root Reset Tracker
owner: Platform Team
status: canonical
last_verified: 2026-03-10
canonical_root: docs/meta/docs-program
doc_class: tracker
summary: Classification tracker for retiring docs/migrations as a mixed legacy root.
tags:
  - docs
  - migrations
  - root-reset
audience: Contributors
---

# Wave Migrations Root Reset Tracker

## Objective

Retire `docs/migrations/**` as a mixed legacy root by rehoming its contents into the actual owning roots:

- `docs/reference/migrations/**` for factual source-system and mapping reference
- `docs/status/migrations/**` for active migration status and decisions
- `docs/ops/runbooks/migrations/**` for execution and rollback procedures
- archive/report surfaces for closed historical material

This is not a wrapper-only retirement. The current root still mixes reference, status, and runbook content.

## Canonical owners after reset

- Migration reference: `docs/reference/migrations/**`
- Migration status: `docs/status/migrations/**`
- Migration runbooks: `docs/ops/runbooks/migrations/**`
- Historical migration records: archive/report surfaces

## Packet A classification

### Root-level files

- `docs/migrations/README.md`
  - target: tombstone-only root README after rehoming
- `docs/migrations/BBI-K8-MIGRATION.md`
  - class: historical migration plan
  - target: archive/report surface
- `docs/migrations/KAJABI_COURSES_WITHOUT_COMPLETION_DATA.md`
  - class: migration decision/status note
  - target: `docs/status/migrations/**`
- `docs/migrations/SKILLOURFUTURE_BRAND_MIGRATION.md`
  - class: migration execution guide
  - target: `docs/ops/runbooks/migrations/**`

### Kajabi subtree

- `KAJABI_MIGRATION.md`
  - class: execution guide
  - target: `docs/ops/runbooks/migrations/kajabi/**`
- `KAJABI_MIGRATION_VERIFICATION.md`
  - class: execution verification report/checklist
  - target: `docs/ops/runbooks/migrations/kajabi/**`
- `ROLLBACK_AND_SAFETY.md`
  - class: rollback runbook
  - target: `docs/ops/runbooks/migrations/kajabi/**`
- `KAJABI_CERTIFICATE_MIGRATION.md`
  - class: domain-specific migration reference
  - target: `docs/reference/migrations/kajabi/**`
- `KAJABI_LESSON_CONTENT_FIX.md`
  - class: troubleshooting / repair runbook
  - target: `docs/ops/runbooks/migrations/kajabi/**`
- `KAJABI_LESSON_CONTENT_ISSUE.md`
  - class: issue analysis / historical troubleshooting note
  - target: archive/report surface or supporting reference, pending packet review
- `KAJABI_MIGRATION_NOTES.md`
  - class: mixed operator notes
  - target: likely archive/report surface after extracting any still-live commands

### MCT subtree

- `API_EXPLORATION.md`
  - class: API/source reference
  - target: `docs/reference/migrations/mct/**`
- `DATA_MODEL_COMPLETE.md`
  - class: source/data reference
  - target: `docs/reference/migrations/mct/**`
- `DOCUMENTATION_COMPLETE.md`
  - class: historical closeout/narrative
  - target: archive/report surface
- `EXPORT_COMPLETE.md`
  - class: historical export completion note
  - target: archive/report surface
- `EXPORT_GUIDE.md`
  - class: execution guide
  - target: `docs/ops/runbooks/migrations/mct/**`
- `EXPORT_SUCCESS.md`
  - class: historical status note
  - target: `docs/status/migrations/**` or archive/report surface, pending packet review
- `EXPORT_SUMMARY.md`
  - class: historical summary note
  - target: archive/report surface
- `EXPORT_TESTING.md`
  - class: execution/test procedure
  - target: `docs/ops/runbooks/migrations/mct/**`
- `EXPORT_TEST_RESULTS.md`
  - class: historical verification evidence
  - target: archive/report surface
- `MCT_PLATFORM_RESEARCH.md`
  - class: source research/reference
  - target: `docs/reference/migrations/mct/**`
- `MCT_PRE_MIGRATION_INVENTORY.md`
  - class: source inventory/reference
  - target: `docs/reference/migrations/mct/**`
- `MCT_TO_OPENEDX_MAPPING.md`
  - class: mapping reference
  - target: `docs/reference/migrations/mct/**`
- `MCT_USER_IMPORT_COMPLETE.md`
  - class: historical completion note
  - target: archive/report surface
- `MIGRATION_PLAN.md`
  - class: execution plan/runbook
  - target: `docs/ops/runbooks/migrations/mct/**`
- `OPENEDX_PROGRAMS_SETUP.md`
  - class: reference/setup note
  - target: `docs/reference/migrations/mct/**`
- `OPS_MCT_README.md`
  - class: operator guide
  - target: `docs/ops/runbooks/migrations/mct/**`
- `PROGRAMS_SETUP_PLAN.md`
  - class: execution plan
  - target: `docs/ops/runbooks/migrations/mct/**`
- `SMOKE_TEST.md`
  - class: runbook/verification procedure
  - target: `docs/ops/runbooks/migrations/mct/**`
- `VIDEO_MIGRATION.md`
  - class: execution guide
  - target: `docs/ops/runbooks/migrations/mct/**`

## Packet sequence

### Packet A

- Scope: classify all `docs/migrations/**` files and lock target homes.

### Packet B

- Scope: rehome root-level files and obvious Kajabi/MCT reference docs.

### Packet C

- Scope: rehome execution guides into `docs/ops/runbooks/migrations/**`.

### Packet D

- Scope: rehome or archive historical notes/status summaries and rewrite references.

### Packet E

- Scope: collapse `docs/migrations/**` to a tombstone README, add no-regrowth guard, and close out.

## Current blocker status

Not blocked. The root is large, but the ownership model is now explicit enough to proceed packet-by-packet without guessing.
