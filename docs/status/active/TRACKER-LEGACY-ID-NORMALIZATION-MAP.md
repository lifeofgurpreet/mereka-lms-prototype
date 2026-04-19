---
title: Tracker Legacy ID Normalization Map
type: normalization-map
owner: platform-review
status: active
observed_at: 2026-04-18T15:20Z
---

# Tracker Legacy ID Normalization Map

This document turns the current legacy-ID problem into an explicit rewrite /
quarantine plan.

It exists so tracker repair does not stall on an undefined policy question once
implementation starts.

## Current Legacy Set

Validated by `scripts/governance/inventory-tracker-legacy-ids.sh` against the
live `mereka-lms` tracker JSONL.

### Tombstones (`bd-*`)

These are historical tombstones from the old tracker namespace:

- `bd-10fq` — Interaction-state quality contract (loading/empty/error/success)
- `bd-2u20` — MFE selector hardening + slot-first migration pass
- `bd-3fzs` — Copy/terminology consistency contract across MFEs
- `bd-j8x2` — Frontend performance budgets + cache-contract gate
- `bd-rii5` — Accessibility conformance gate (keyboard/focus/landmarks)

### Closed foreign-prefix issues (`mereka-*`)

These are closed issues that use a foreign / non-canonical prefix:

- `mereka-11cl` — Fix dev credentials auth login 500 runtime
- `mereka-12c0` — Resolve Velero backup failures from exhausted GCP snapshot quota
- `mereka-2zzm` — Fix credentials runtime health and DID endpoint failures
- `mereka-6bi4` — Resolve Velero backup failures from exhausted GCP snapshot quota
- `mereka-mu5l` — World-class execution: LMS contract + migration truth + boundary cleanup

## Recommended Policy

### Rule 1 — Tombstones do not belong in the active execution JSONL

Recommendation:

- archive the five `bd-*` tombstones out of the live tracker JSONL
- preserve them in a timestamped archive file
- do not keep them in the active tracker source where they can distort prefix
  inference or planner behavior

Proposed archive path:

- `.beads/archive/legacy-bd-tombstones-20260418.jsonl`

### Rule 2 — Closed historical issues may be normalized in place

Recommendation:

- normalize the five closed `mereka-*` issues into the canonical
  `mereka-lms-*` namespace
- preserve an explicit mapping artifact for the rewrite

## Proposed Mapping

### Quarantine / archive

- `bd-10fq` -> archive only
- `bd-2u20` -> archive only
- `bd-3fzs` -> archive only
- `bd-j8x2` -> archive only
- `bd-rii5` -> archive only

### Normalize in place

- `mereka-11cl` -> `mereka-lms-11cl`
- `mereka-12c0` -> `mereka-lms-12c0`
- `mereka-2zzm` -> `mereka-lms-2zzm`
- `mereka-6bi4` -> `mereka-lms-6bi4`
- `mereka-mu5l` -> `mereka-lms-mu5l`

## Rewrite Constraints

- take a fresh backup of:
  - `.beads/issues.jsonl`
  - `.beads/beads.db`
  - `.beads/beads.db-wal` if present
- write a machine-readable mapping file before the rewrite
- validate no live references depend on the old IDs before replacing them
- perform the first normalization in a clean-room copy, not the live tracker
- only rebuild the tracker store from the normalized JSONL after the mapping is
  agreed

## Required Validation After Rewrite

- `inventory-tracker-legacy-ids.sh` reports zero legacy IDs
- `br doctor` is clean
- `br list` returns promptly
- `br create` does not report prefix mismatch
- create / show / list / sync / export all complete without storage warnings

## Why This Is The Recommended Shape

The current evidence already shows:

- native `--rename-prefix` rebuild attempts are not enough
- a fresh DB can still be unhealthy if the mixed-history JSONL is left intact
- the real poison is not only the DB/WAL pair; it is the source data policy

So the repair lane should treat normalization as a first-class step, not a
cleanup afterthought.
