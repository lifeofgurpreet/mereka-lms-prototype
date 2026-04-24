---
title: "br tracker SQLite corruption — repair plan (HUMAN-GATED, NOT autonomous)"
type: evidence-bundle
status: active
observed_at: 2026-04-20T00:25Z
owner: platform-release
bead: "mereka-lms-6et6 (tracker hygiene) — relates"
produced_by: slice-79 parallel-agent-5 (read-only diagnosis)
severity: MODERATE (data is safe; DB is corrupt)
---

# br tracker SQLite corruption — repair plan

## Corruption assessment: MODERATE, recoverable

### JSONL is authoritative and intact

- `.beads/issues.jsonl`: 771 valid entries, fully intact
- `.br_history/` contains 21 snapshots of continuous history
- No data loss risk

### SQLite DB is the corrupted derived index

- Current state: `database disk image is malformed: page 959 is never used`
- Root cause: page fragmentation + WAL corruption from prior crash/unclean-shutdown cycles. Multiple incident windows visible (March 2-4, April 16-17).
- Symptoms:
  - `br create` fails with `UNIQUE constraint failed: export_hashes.issue_id`
  - `br search` returns API errors
  - `br doctor` reports dozens of "Tree N page N cell N: invalid page number"
  - DB count and JSONL count differ

### Why this is recoverable

The JSONL IS the source of truth. The SQLite DB is a derived index that can be rebuilt. `br sync --import-jsonl` (or equivalent) rebuilds the DB from JSONL; `br doctor` should then report clean.

## Recommended repair sequence (5-10 min, HUMAN-DRIVEN)

### Step 0 — verify JSONL integrity

```bash
cd /home/gurpreet/projects/k8s/mereka-lms
wc -l .beads/issues.jsonl
# Expect: 771 (or current live count)
python3 -c "
import json
ok = 0
bad = 0
with open('.beads/issues.jsonl') as f:
    for line in f:
        try:
            json.loads(line)
            ok += 1
        except:
            bad += 1
print(f'valid: {ok}, malformed: {bad}')
"
# Expect: valid == wc -l result, malformed == 0
```

### Step 1 — back up corrupted state

```bash
mkdir -p .beads/.backup-$(date -u +%Y%m%dT%H%M%SZ)
cp -r .beads/*.db .beads/*.db-wal .beads/*.db-shm .beads/.backup-*/ 2>/dev/null || true
```

### Step 2 — try SQLite native `.recover` mode

```bash
sqlite3 .beads/beads.db ".recover" > /tmp/beads-recovered.sql 2>&1
# If this completes without massive errors, the DB is recoverable at SQL level.
# Inspect /tmp/beads-recovered.sql for row counts.
```

### Step 3 — delete corrupted DB; let `br` rebuild from JSONL

```bash
# STOP any running br daemon first:
pkill -f br-daemon 2>/dev/null || true

# Remove derived artifacts (JSONL stays untouched):
rm -f .beads/beads.db .beads/beads.db-wal .beads/beads.db-shm .beads/.write.lock

# Reinitialize DB from JSONL:
br sync --import-jsonl
# OR if that command doesn't exist: br doctor --rebuild
# OR: br init (if tracker supports re-init from existing JSONL)
```

### Step 4 — verify clean state

```bash
br doctor
# Expect: all OK, no corruption errors

br list --status open --priority 0 --priority 1 | head -20
# Expect: shows known P0/P1 beads (m0u5.10.7 still open, mefk.1 closed, 2xwo closed, etc.)

wc -l .beads/issues.jsonl
# Expect: same count as Step 0 (no data loss)
```

### Step 5 — commit recovery state

```bash
git add .beads/issues.jsonl
git diff --cached .beads/issues.jsonl | head -50
# If diff is clean (no unexpected deletions), commit:
git commit -m "chore(beads): rebuild SQLite tracker index from authoritative JSONL (tracker-repair)"
git push
```

## Risk register

| Risk | Mitigation |
|---|---|
| Deleting DB corrupts fresh beads not yet flushed to JSONL | Step 0 verifies JSONL count first. Any unflushed beads would be in the corrupted DB only — check `.beads/.write.lock` for clues. |
| `br sync --import-jsonl` doesn't exist | Fall through to `br init` or raw SQLite rebuild. Check `br --help \| grep -iE "rebuild\|import\|recover"` first. |
| JSONL itself is corrupt | Step 0 validates line-by-line JSON parsing. If any line fails, STOP and investigate before deleting DB. |
| Concurrent writer during rebuild | `pkill br-daemon` + `rm .beads/.write.lock` prevents this. |

## Why this is NOT autonomous

Per `docs/status/active/TRACKER-HYGIENE-RECOVERY-PLAN.md`:

> "Before non-trivial tracker surgery, read: TRACKER-HYGIENE-RECOVERY-PLAN.md"

This repair touches `.beads/*.db` files that ARE in the git surface. A mistake here loses real work. Requires explicit user authorization before execution.

## Open beads that might be in flight (check these against JSONL after repair)

- `mereka-lms-m0u5.10.7` (P0, open per JSONL — credential rotation; slice-79 #1912 closed the remaining scrub but bead not closed yet due to corruption)
- `mereka-lms-rrk8` (opened slice 74 — CSP no-op; bbi-infra#3367 closed the actual fix; bead not closed in app-repo tracker yet)
- `mereka-lms-2xwo` (closed slice 71)
- `mereka-lms-mefk` (closed slice 69)
- `mereka-lms-mefk.1` (closed slice 69)
- `mereka-lms-vfd5` (closed slice 69)

Post-repair, these closures should persist because they were flushed to JSONL before the corruption incident.

## #1894 relevance assessment (produced by this agent)

- PR #1894 is "docs(status): current MFE execution plan after shadow-settings retractions"
- Still reflects post-#1906/#1908 state correctly
- Auto-merge armed; standing CI gate
- Action: do NOT close, rebase, or rewrite. Stands as guidance artifact.
- Expected completion: when CI greens (5 pending jobs at time of this agent's investigation)
- If blocked >1 hour after CI-green claim, check the gate in detail

## Related

- Slice-79 agent-5 read-only investigation
- `docs/status/active/TRACKER-HYGIENE-RECOVERY-PLAN.md`
- Bead `mereka-lms-6et6` (tracker hygiene: repair br prefix mismatch; same-area work)
