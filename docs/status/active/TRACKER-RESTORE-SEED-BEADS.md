---
title: Tracker Restore Seed Beads
type: seed-queue
owner: platform-review
status: active
observed_at: 2026-04-18T15:35Z
---

# Tracker Restore Seed Beads

These are candidate beads to create once tracker hygiene is restored.

They exist here so planning momentum does not stall while `.beads` is in
degraded mode.

## Rules

- do not bulk-create these while tracker repair is still open
- create only the highest-leverage ready items first
- preserve dependency order
- if live truth changes, revise the seed bead text before creation

## Seed 1 — Tracker Legacy ID Inventory + Policy

- title: `Tracker hygiene: inventory legacy IDs and choose normalization policy`
- priority: `P1`
- lane: tracker reliability
- goal:
  - decide whether legacy `bd-*` and foreign-prefix `mereka-*` IDs are
    normalized, quarantined, or retained as historical tombstones outside the
    active execution graph
  - produce an explicit old->new mapping artifact for any rewrite

## Seed 2 — Tracker Storage Rebuild / Recovery

- title: `Tracker hygiene: rebuild clean DB/WAL state from trusted JSONL source`
- priority: `P1`
- lane: tracker reliability
- depends on: Seed 1
- goal:
  - re-establish a healthy DB/WAL pair and remove the current malformed/corrupt
    storage ambiguity
  - validate the rebuild in a clean-room directory before touching the live
    store

## Seed 3 — Tracker Post-Repair Validation

- title: `Tracker hygiene: validate create/show/sync/export after recovery`
- priority: `P1`
- lane: tracker reliability
- depends on: Seed 2
- goal:
  - prove the repaired tracker can handle normal planner mutation without
  prefix/schema/WAL failures
  - prove `br list` is responsive and prefix inference no longer drifts

## Seed 3.5 — Tracker Rebuild / Storage Nondeterminism Diagnosis

- title: `Tracker hygiene: diagnose nondeterministic br rebuild/storage failure after normalization`
- priority: `P1`
- lane: tracker reliability
- depends on: Seed 2
- goal:
  - determine why a zero-legacy-ID repo-root store still shows flaky rebuild
    behavior after normalization
  - capture the now-proven pattern:
    - `1..10` normalized rows succeed
    - `20` rows are flaky across repeated runs
    - `50+` rows usually time out and/or poison the store
  - isolate whether the remaining fault is:
    - rebuild-path config propagation
    - prefix derivation during import
    - DB/WAL behavior under modest graph size
    - or another CLI/storage bug
  - explain why timed-out rebuilds can leave a store that later reports
    malformed SQLite / WAL errors

## Seed 4 — Tier A Script: Rolling State Generator Hardening

- title: `Tier A: harden generate-current-operator-state.sh contract and degraded-state handling`
- priority: `P1`
- lane: script first-class
- goal:
  - make rolling-state generation deterministic, explicit, and safe under
    tracker degradation

## Seed 5 — Tier A Script: Tracker Hygiene Audit Self-Test

- title: `Tier A: add fixture-backed self-test for audit-tracker-hygiene.sh`
- priority: `P2`
- lane: script first-class
- goal:
  - add minimal fixtures for healthy, degraded, and hard-fail tracker states

## Seed 6 — Tier A Script: Docs Authority Invariants Expansion

- title: `Tier A: expand verify-docs-authority-invariants.sh for rolling-vs-historical authority checks`
- priority: `P2`
- lane: script first-class
- goal:
  - guard the rolling-state model more directly

## Seed 7 — Tier A Script: Orphan Burn Register

- title: `Tier A: turn verify-script-governance-orphans.sh output into bounded burn register`
- priority: `P2`
- lane: script first-class
- goal:
  - convert raw orphan detection into explicit burn-down work

## Seed 8 — MFE: Enterprise Admin Browser Proof

- title: `MFE: browser-prove enterprise admin authenticated data visibility`
- priority: `P1`
- lane: MFE frontier
- goal:
  - close the “shell renders but data visibility is unproven” gap

## Seed 9 — MFE: Learner Secondary Endpoint Semantic Closure

- title: `MFE: retire temporary learner secondary-endpoint routing mitigation`
- priority: `P1`
- lane: MFE frontier
- goal:
  - replace mitigation debt with either a real fix or an explicit durable
    contract decision

## Seed 10 — MFE: Enterprise Customization Surface Matrix

- title: `MFE: map enterprise customization surfaces by slot/runtime/build capability`
- priority: `P2`
- lane: MFE frontier
- goal:
  - make enterprise customization limits explicit and actionable

## Seed 11 — MFE: Runtime Config Consistency Verification

- title: `MFE: verify runtime-config consistency for high-risk tenant/domain surfaces`
- priority: `P2`
- lane: MFE frontier
- goal:
  - convert runtime-config policy into stronger active verification

## Seed 12 — MFE: Selector Debt Live/Risky Split

- title: `MFE: split dead selector residue from live risky selector debt`
- priority: `P2`
- lane: MFE frontier
- goal:
  - stop broad selector debt from obscuring the narrower live-risk set

## Recommended First Creation Order

1. Seed 1
2. Seed 2
3. Seed 3
4. Seed 3.5
5. Seed 4
6. Seed 8
7. Seed 9
8. Seed 10

That ordering restores the execution graph first, then installs the next
highest-leverage script and MFE lanes.
