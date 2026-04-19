---
title: Next Week Implementer Burn Queue
type: execution-queue
owner: platform-review
status: active
observed_at: 2026-04-18T12:40Z
---

# Next Week Implementer Burn Queue

This is the reviewer/planner execution queue for the next week of implementer
work.

It is built from:

- current live queue truth
- current active docs
- current debt scan
- current script surface scan
- current MFE issue evidence

It is not meant to replace `CURRENT-OPERATOR-STATE.md`. It is the medium-horizon
queue the rolling file should keep pointing into.

It also does not replace `IMPLEMENTER-MARCHING-ORDERS.md`.

Use:

- `CURRENT-OPERATOR-STATE.md` for live truth
- `IMPLEMENTER-MARCHING-ORDERS.md` for routing / lane choice
- `TEAM-BATCH-SEQUENCING-PLAN.md` for batch order and concurrency limits
- this file for the next-week backlog once the current lane is known

## Week Objective

Move from “the operator-surface tranche mostly landed” to:

1. doctrine/governance closure
2. tracker reliability
3. first-class script hardening
4. concrete MFE/browser-proof backlog
5. debt burn that actually reduces future confusion

## Lane 1 — Close The Governance / Doctrine Chain

### Goal

Finish the truth-repair enforcement chain so status authority and canonical
artifacts are harder to let rot.

### Work

- land:
  - `y69t.1` — runbook executable verifier
  - `y69t.2` — retraction sweep verifier
  - `y69t.3` — doctrine wiring into generator / loop prompt / README
- keep `CURRENT-OPERATOR-STATE.md` as the rolling authority surface
- keep numbered docs historical

### Why

This is the anti-drift foundation. Without it, future loops regress back into
stale prose and manual trust.

## Lane 2 — Restore Tracker Reliability

### Goal

Make `br` creation and planning reliable again.

### Evidence

- `.beads/issues.jsonl` contains 10 non-conforming IDs
- planner commands intermittently fail with prefix mismatch
- DB/WAL state shows real corruption history and flush problems

### Work

- inventory and normalize/quarantine the 10 legacy bad IDs with an explicit
  mapping artifact
- rebuild the tracker from a cleaned JSONL source, not from the current mixed
  history
- validate that `br list` is responsive and prefix inference no longer drifts
- re-establish a safe operating procedure for planner-created beads

### Proven findings

- in-place `br sync --import-only --rename-prefix --rebuild` on a copied
  degraded store did not clear the legacy IDs and did not fix the schema-table
  problem
- a clean-room rebuild from only `issues.jsonl` + `config.yaml` does create a
  fresh DB/WAL pair and clears the schema-table error, but still times out and
  leaves legacy IDs in JSONL
- a clean-room rebuild from the preview-generated **normalized** JSONL removes
  legacy IDs entirely, but `timeout 30 br sync --import-only --rebuild` and
  `timeout 15 br list` still hang
- after that timed-out normalized rebuild, direct `sqlite3` queries on the
  rebuilt store fail with `database disk image is malformed (11)`
- current evidence points to:
  1. legacy-ID normalization as a prerequisite
  2. a second, deeper tracker responsiveness / import-path bug that survives
     normalization and can leave a broken store behind

### Why

The tracker is the execution graph. If it is flaky, planning quality decays and
 implementers lose leverage.

## Lane 3 — Script First-Class Program

### Goal

Tier the critical script surface and harden Tier A.

### Evidence

- 1228 script-like files
- 655 verify-like scripts
- only 109 test-like scripts
- 575 verify-like scripts without a same-name `test-...` companion by heuristic
- debt markers are dominated by `scripts/`

### Existing bead

- `mereka-lms-q69f`

### Work

- identify Tier A scripts:
  - promotion
  - runtime realization
  - governance
  - runbook-facing
  - cluster mutation
- score each Tier A script
- open burn beads for the worst gaps

### Immediate follow-ons

- `lb4c.6` wire S6.1 helper into real workflows
- `lb4c.7` wire S6.2 helper into post-push Trivy/SBOM with safe retry semantics
- `lb4c.8` harden `verify-pods-on-digest.sh` for explicit context and
  multi-container selection

## Lane 4 — Debt Burn Program

### Goal

Turn today’s debt evidence into sequenced burn work.

### Evidence

Debt marker counts:

- `scripts`: 232
- `docs`: 162
- `infrastructure`: 28
- `specs`: 14

### Work

- build a burn queue for:
  - merged-but-wrong artifacts
  - status authority debt
  - runbook executability debt
  - script governance orphan debt
  - high-value TODO clusters

### High-value quick wins

- `#1827` remove 6 stale orphan-allowlist entries
- existing `mereka-lms-fyu6` related script/orphan governance work
- libraries foundation TODO decomposition
- mobile secrets TODO cluster decomposition

## Lane 5 — Rollback / DR Evidence

### Goal

Move rollback from theory to proved evidence.

### Existing beads

- `lb4c.9` — dry-run promotion rollback drill end to end on dev, capture evidence
- `mereka-lms-v5vj` — verify DR: run audit-velero.sh and prove backup/restore works

### Why

This closes the last big gap in executable operational trust. A runbook that is
 syntactically correct but never exercised is not enough.

## Lane 6 — MFE Issue Map To Executable Backlog

### Goal

Stop treating “MFE later” as a vague future category.

### Existing bead

- `mereka-lms-m0u5`

### Issue classes already visible

1. enterprise admin data visibility is still not browser-proven
2. learner secondary endpoints still carry mitigation debt
3. enterprise MFEs remain a distinct customization surface
4. selector debt remains real
5. runtime-config / multisite consistency needs continual verification
6. performance budgets are stronger in policy than enforcement

### Work

- split the MFE issue map into implementable beads:
  - browser proof
  - semantic/runtime closure
  - selector/slot debt
  - runtime-config consistency
  - enterprise data readiness
  - performance enforcement

## Lane 7 — Opportunistic P1/P2 Queue While CI Runs

Good parallel work when the main governance chain is waiting on CI:

- `jj97.11` — raw build telemetry schema
- `lb4c.6` / `.7` / `.8` wire-ins and hardening
- orphan / allowlist cleanup
- docs authority cleanup that directly reduces operator confusion

## Sequencing Recommendation

### First 24 hours

1. finish governance/doctrine chain
2. restore tracker reliability
3. remove stale orphan allowlist entries
4. execute rollback drill evidence

### Next 48 hours

1. script first-class tiering
2. S6 wire-ins and hardening (`lb4c.6`, `.7`, `.8`)
3. MFE issue map split into executable beads

### Next week

1. browser-proof enterprise admin data visibility
2. close learner secondary-endpoint mitigation debt
3. performance/runtime-config enforcement work

## Success Condition

By the end of the week:

- doctrine is enforced, not just written
- the tracker is trustworthy
- Tier A scripts are being governed as first-class assets
- debt burn is a real program, not a note
- MFE work is represented as concrete issue classes with beads
