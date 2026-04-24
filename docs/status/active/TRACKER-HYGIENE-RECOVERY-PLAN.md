---
title: Tracker Hygiene Recovery Plan
type: recovery-plan
owner: platform-release
status: active
observed_at: 2026-04-18T15:00Z
---

# Tracker Hygiene Recovery Plan

This document turns the current `.beads` reliability problem into an explicit
workstream.

The planner and implementer loops should treat tracker hygiene as a real system
dependency, not an incidental annoyance. If `br` is flaky, queue quality
decays, bead creation slows down, and the rolling state surface becomes harder
to trust.

Companion artifact:

- `TRACKER-LEGACY-ID-NORMALIZATION-MAP.md`
- `TRACKER-LEGACY-ID-NORMALIZATION-MAP.json`

## Why This Exists

The tracker is now important enough that it needs the same treatment as any
other control-plane surface:

- observed facts
- bounded risk classification
- safe operating mode
- recommended recovery sequence
- exit criteria

## Observed Facts

Evidence gathered on `2026-04-18` from the `Biji-Biji-Initiative/mereka-lms`
repo checkout on the VPS:

- `br doctor` reports:
  - `OK jsonl.parse: Parsed 725 records`
  - `OK sqlite.integrity_check`
  - `OK counts.db_vs_jsonl: Both have 725 records`
  - `ERROR schema.tables: Missing tables: issues, dependencies, labels, comments, events, config, metadata, dirty_issues, export_hashes, blocked_issues_cache, child_counters`
- `.beads/issues.jsonl` contains `10` non-conforming IDs:
  - tombstones: `bd-10fq`, `bd-2u20`, `bd-3fzs`, `bd-j8x2`, `bd-rii5`
  - closed foreign-prefix IDs: `mereka-11cl`, `mereka-12c0`, `mereka-2zzm`, `mereka-6bi4`, `mereka-mu5l`
- `.beads/` contains a long recovery/corruption trail:
  - `beads.db.corrupt.*`
  - `beads.db.broken.*`
  - `beads.db.recovered.*`
  - `beads.db.malformed.*`
  - `beads.db-wal.partial.*`
  - `backup-20260417-corrupt/`
- direct planner mutation was proven unsafe:
  - a stale-allowed DB-only create could succeed
  - later export / flush encountered WAL corruption
  - a subsequent create hit `database disk image is malformed`
- containment already exists:
  - `issues.jsonl` backup created as `issues.jsonl.backup.20260418T143654`

Additional recovery-lab findings gathered after the first audit:

- rebuilding *in place* on a copied degraded tracker store with:
  - `br sync --import-only --rename-prefix --rebuild`
  - did **not** clear the legacy IDs
  - did **not** fix the schema-table error
  - and left DB/JSONL parity in a worse state
- rebuilding from a **clean-room** `.beads/` directory containing only:
  - `issues.jsonl`
  - `config.yaml`
  - does create a fresh `beads.db` / `beads.db-wal`
  - and `br doctor` then reports `OK schema.tables`
  - but the import still times out under `timeout 25`
  - the legacy IDs remain in JSONL
  - and `timeout 15 br list --limit 10` also times out against the rebuilt store
- the copied `config.yaml` still says:
  - `issue-prefix: mereka-lms`
  - but `br sync` auto-detects the prefix from JSONL as `mereka`
  - which is direct evidence that the mixed-prefix JSONL is contaminating
    prefix inference

The current working conclusion is:

- fresh DB creation alone is not enough
- legacy-ID normalization must happen before the tracker can be considered
  healthy again

Dry-run normalization preview result:

- `preview-tracker-legacy-normalization.py` validates the current mapping
  cleanly against the live JSONL
- current preview summary:
  - `total_rows: 725`
  - `legacy_rows: 10`
  - `archive: 5`
  - `rename: 5`
  - `normalized_rows: 720`
  - `archived_rows: 5`
- preview output was successfully written to:
  - `/tmp/mereka-tracker-normalization-preview/`

This means the proposed mapping is internally consistent and executable as a
dry run. The remaining work is to decide when and how to apply it to the live
tracker source, then rebuild and validate the store.

Normalized clean-room rebuild result:

- a clean-room store built from the preview-generated `normalized-issues.jsonl`
  contains `0` legacy IDs
- even in that state:
  - `timeout 30 br sync --import-only --rebuild` still exits `124`
  - `br doctor` reports superficially healthy schema/integrity
  - `timeout 15 br list --limit 10` still exits `124`
- the import path still auto-detects prefix `mereka` despite:
  - `issue-prefix: mereka-lms`
  - zero remaining legacy IDs in JSONL

Updated working conclusion:

- legacy-ID normalization is necessary
- but it is **not sufficient**
- there is still a deeper tracker responsiveness / import-path problem after
  normalization
- the recovery lane therefore has two required closures:
  1. source normalization
  2. post-normalization `br` storage / responsiveness diagnosis

Additional storage finding from the normalized clean-room experiment:

- after a timed-out normalized rebuild attempt, direct `sqlite3` access fails
  with:
  - `database disk image is malformed (11)`
- this means the import path is not merely slow; under interruption it can
  leave a broken store behind
- `br doctor` and superficial schema checks are therefore not sufficient proof
  of post-rebuild health

## Risk Classification

### What is still healthy

- JSONL remains parseable
- issue count parity between DB and JSONL is currently reported as equal
- read-oriented commands still produce useful output

### What is degraded

- prefix hygiene is not clean
- storage-layer trust is weak
- write-path behavior is not deterministic
- export / flush safety is not established

### What this means operationally

The tracker is usable for reading and planning, but not yet trustworthy for
unbounded mutation.

Treat it like a degraded database:

- safe for observation
- unsafe for casual surgery
- repair should be deliberate and auditable

## Immediate Safe Operating Procedure

Until tracker hygiene is repaired:

1. Prefer read-only commands:
   - `br list`
   - `br show`
   - `br ready`
   - `br doctor`
2. Do not perform bulk tracker edits from normal hourly loops.
3. Do not assume `br sync --flush-only` is harmless.
4. Before any repair attempt, create a fresh timestamped backup of:
   - `.beads/issues.jsonl`
   - `.beads/beads.db`
   - `.beads/beads.db-wal` if present
5. If a new bead is absolutely required before repair:
   - create it only from a dedicated repair session
   - record the exact command used
   - immediately validate both JSONL and `br doctor`
   - stop if any write-path warning appears
6. Keep planner truth mirrored in docs while tracker health is degraded.

Read-only audit command:

```bash
bash scripts/governance/audit-tracker-hygiene.sh <repo-root>
```

Normalization preview command:

```bash
python3 scripts/governance/preview-tracker-legacy-normalization.py <repo-root>
```

Current expected behavior:

- exit `0` only when tracker hygiene is healthy enough for normal mutation
- exit `1` when degradation is detected but the audit completed successfully
- exit `2` on hard audit failure (missing files / unreadable tracker)

## Recommended Recovery Sequence

### Phase 1 — Freeze and Inventory

- snapshot the current `.beads/` directory
- record all non-conforming IDs
- record current DB/WAL file sizes and timestamps
- confirm the latest good JSONL backup

### Phase 2 — Decide Legacy-ID Policy

Choose one policy and apply it consistently:

- rewrite legacy IDs into the canonical `mereka-lms-*` namespace
- or quarantine foreign / tombstone history outside the live execution graph

Recommendation:

- preserve history, but remove non-conforming IDs from the active execution
  surface
- closed foreign-prefix issues and old `bd-*` tombstones should not keep
  poisoning normal planner operations
- create an explicit mapping artifact from old ID -> normalized/quarantined form
- do not let `br` infer the active prefix from mixed historical JSONL

### Phase 2.5 — Normalize Legacy IDs In Source

Before another rebuild attempt:

- inventory the exact legacy IDs and their current semantic status
- use `TRACKER-LEGACY-ID-NORMALIZATION-MAP.md` as the default rewrite policy
  unless live evidence forces a revision
- decide which ones are:
  - tombstone history to quarantine
  - closed historical issues to normalize
  - records that should stay in an archive, not the active tracker JSONL
- rewrite the JSONL source deliberately, with:
  - a timestamped backup
  - a machine-readable old->new mapping
  - a short human log explaining each class of rewrite

Recommendation:

- closed foreign-prefix `mereka-*` issues should be normalized into the
  canonical `mereka-lms-*` namespace or archived out of the active graph
- `bd-*` tombstones should not remain in the live execution JSONL if they
  distort prefix inference or tracker behavior
- normalization should be done once, explicitly, rather than hoping
  `--rename-prefix` cleans mixed history on import

## New Evidence — 2026-04-18T13:40Z

The tracker diagnosis has moved past "legacy IDs might be the whole problem."

Confirmed on live evidence:

- `br config get issue-prefix` returns `mereka-lms` in:
  - the live repo
  - `/tmp/mereka-tracker-repo-attempt4`
  - `/tmp/mereka-tracker-repo-attempt5`
- `strace` on `br sync --import-only --rebuild -v` from a normalized
  repo-root harness shows the command opens:
  - `~/.beads/config.yaml`
  - `/tmp/mereka-tracker-repo-attempt6/.beads/config.yaml`
  - the normalized `.beads/issues.jsonl`
- despite that, the same rebuild still logs:
  - `Auto-detected prefix from JSONL (no prefix configured) detected_prefix=mereka`

That means the failure is no longer accurately described as "missing config."
The stronger conclusion is:

- the rebuild/import path is either:
  - ignoring the resolved `issue-prefix`
  - re-deriving prefix from JSONL even after config load
  - or passing the wrong config state into the import worker

Separately, a normalized repo-root rebuild with no inherited `beads.db` or WAL
still fails badly:

- `timeout 12 br sync --import-only --rebuild -v` times out
- it leaves behind:
  - `.beads/beads.db` (`4.0K`)
  - `.beads/beads.db-wal` (`391K`)
- a follow-up `br list` on the same repo-local store returns:
  - `DATABASE_ERROR`
  - `internal error: malformed SQLite record blob`

Subset probing makes the failure class even clearer:

- normalized subsets of `1..10` rows rebuild and list cleanly
- repeated runs at `20` rows are **flaky**:
  - some runs succeed cleanly
  - some runs time out and then leave malformed-store behavior
- repeated runs at `50` rows are consistently bad:
  - `sync` times out every run
  - `list` usually fails with database errors afterward

That points away from "one poisonous row" and toward a nondeterministic
rebuild/import/storage bug that gets worse as graph size rises.

So the recovery lane is now explicitly two-part:

1. normalize/quarantine the 10 legacy IDs
2. diagnose the deeper rebuild/storage bug that survives normalization

One more operational correction:

- probing a bare `.beads` directory with only `BR_DATA_DIR=... br ...` is not a
  trustworthy final health check
- those probes can drift into unrelated global tracker state
- final validation must happen from a full repo checkout/worktree

### Phase 3 — Rebuild Storage From Clean Source

Recommendation:

- trust clean JSONL more than the current DB/WAL pair
- rebuild a fresh tracker DB from a cleaned JSONL source
- do not keep layering new writes on top of the currently suspect WAL history
- validate rebuild in a clean-room directory first, not on the live store
- if normalized clean-room rebuild still hangs, split that into an explicit
  storage/CLI diagnosis lane rather than pretending normalization solved it

### Phase 4 — Validate Write Safety

The rebuilt tracker should prove all of the following before it is declared
healthy:

- `br doctor` has no schema-table error
- `br list` returns promptly without hanging
- direct `sqlite3` reads succeed without `malformed` errors
- no prefix mismatch on create
- create → show → list → sync/export works cleanly
- no malformed / WAL-integrity error appears
- JSONL remains parseable after test writes
- if schema looks healthy but `list` / `sync` still hang, the tracker is still
  not restored

### Phase 5 — Re-open Planner Mutation

Only after the validation above:

- allow normal bead creation from hourly loops
- close the tracker hygiene bead
- fold the repaired operating procedure into:
  - `CURRENT-OPERATOR-STATE.md`
  - `HOURLY-OPERATOR-LOOP-PROMPT.md`
  - the reviewer/planner charter

## Proposed Exit Criteria

Tracker hygiene is considered restored when:

- all active issue IDs conform to the repo prefix policy
- `br doctor` is clean
- the DB/WAL pair is either rebuilt or proven healthy
- `br list` is responsive on the rebuilt store
- prefix inference no longer drifts to `mereka`
- direct `sqlite3` reads are healthy on the rebuilt store
- one scratch create/export/delete cycle succeeds without storage warnings
- planner-created beads can be added from normal loops without special handling

## What Not To Do

- do not hand-wave the problem because `br list` still works
- do not keep creating beads casually while storage errors are active
- do not rewrite history without a backup
- do not leave the rolling state file unaware of tracker degradation
- do not let tracker repair become folklore hidden in shell history
- do not treat `br doctor` alone as sufficient proof of tracker health if
  `br list` / `br sync` still hang

## Recommended Next Bead Shape

When tracker creation is safe again, the repair lane should be represented as:

- tracker hygiene inventory
- legacy ID policy decision
- storage rebuild / recovery
- post-repair validation
- loop-policy update

That keeps recovery auditable and prevents “fixed somehow” from becoming the
new state.
