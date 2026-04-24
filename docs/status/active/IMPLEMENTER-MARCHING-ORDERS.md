---
title: Implementer Marching Orders
type: execution-routing
owner: platform-review
status: active
observed_at: 2026-04-18T13:45Z
---

# Implementer Marching Orders

This file answers one question only:

**What should an implementer agent do next, right now, without guessing?**

Use this with:

1. `CURRENT-OPERATOR-STATE.md` for live truth
2. this file for routing and priority
3. `TEAM-BATCH-SEQUENCING-PLAN.md` for team-level batch order
4. `NEXT-WEEK-IMPLEMENTER-BURN-QUEUE.md` for the medium-horizon map

If those disagree, `CURRENT-OPERATOR-STATE.md` wins on state and this file wins
on routing logic.

## Core Rule

Do not invent a new lane while a higher-leverage in-flight lane is still open.

That means:

1. clear important work already in flight
2. patch merged defects on `main`
3. then start the next durable lane

## Role Split

### Implementer agents

Default job:

- merge/fix/rebase/land work
- harden scripts and workflows
- execute browser/runtime proofs
- burn bounded debt from an already-shaped queue

### Reviewer / planner agents

Default job:

- keep `CURRENT-OPERATOR-STATE.md` accurate
- keep the bead graph honest
- shape and split the next lanes
- discover debt and turn it into ready work

### Important restriction

If tracker hygiene is degraded, implementers should not improvise tracker
surgery unless the active assignment is explicitly the tracker lane.

## Start Here Every Time

1. Read `CURRENT-OPERATOR-STATE.md`.
2. Re-prove live truth if the current loop has not already done so.
3. Check whether there is high-leverage work already open and close to landing.
4. Only if the in-flight queue is stable should you start a fresh lane.

## Decision Tree

### A. Is there an important open queue already in flight?

If yes:

- work that queue first
- rebase/fix CI/address review/arm auto-merge
- do not start a new broad workstream

Use this rule especially for:

- governance / doctrine chain
- promotion / realization chain
- release-safety gaps
- high-value reviewer/planner pack PRs

### B. Is `main` known wrong?

If yes:

- patch `main` before doing helper work
- examples:
  - broken runbook
  - misleading retry default
  - bad operator prompt
  - merged false-truth doc

### C. Is tracker hygiene degraded?

If yes:

- use tracker reads, but be careful with mutation
- follow `TRACKER-HYGIENE-RECOVERY-PLAN.md`
- if your task does not require tracker repair, keep moving in docs/code/PRs
  without turning the hour into tracker archaeology

### D. If queue is stable and `main` is not wrong, take the first incomplete lane below.

## Durable Lane Order

### Lane 1 — Queue Clearing

Goal:

- land or kill the high-leverage open PRs already in motion

Done means:

- no important PR is stuck because nobody rechecked it
- CI failures are understood, not just observed
- mergeable work is rebased and auto-merge-armed

### Lane 2 — Governance / Doctrine Closure

Goal:

- make truth-repair rules executable, not aspirational

Typical work:

- runbook-executable verifier
- retraction-sweep verifier
- rolling-state generator wiring
- loop/README authority cleanup

Done means:

- the doctrine chain is enforced in code/docs/scripts

Default first bounded slice:

- land/fix the highest-value open doctrine/governance PR already in flight
- if none are open, harden the rolling-state / loop / README authority chain
  before inventing new doctrine work

### Lane 3 — Tracker Reliability

Goal:

- restore safe planner mutation

Important:

- this is a specialized lane
- only take it when explicitly working tracker reliability or when the queue is
  blocked on tracker health

Done means:

- normalized source policy is settled
- rebuild path is understood
- store health is proven from a repo-root harness

Default first bounded slice:

- do not start with broad repair
- first produce one decisive proof artifact:
  - normalization map
  - repo-root rebuild repro
  - or nondeterminism threshold evidence
- then turn that exact proof into the next repair step

### Lane 4 — Script First-Class Program

Goal:

- make Tier A scripts worthy of depending on

Typical work:

- help text
- explicit context/env handling
- deterministic exit codes
- self-tests
- fixture coverage
- wiring into real workflows

Primary entrypoint:

- `mereka-lms-q69f`

Default first bounded slice:

- take the top unchecked Tier A item from `SCRIPT-TIER-A-FIRST-10.md`
- define its contract, tests, exit behavior, and next burn action

### Lane 5 — Rollback / DR Evidence

Goal:

- move from “runbook exists” to “runbook proven”

Typical work:

- rollback drill evidence
- DR/Velero audit proof

Done means:

- operators have actual evidence, not just scripts/docs

Default first bounded slice:

- prefer rollback drill evidence first if it is authorized and bounded
- otherwise run the DR audit proof path and capture the gap precisely

### Lane 6 — MFE Executable Frontier

Goal:

- turn MFE uncertainty into bounded proofs and fixes

Primary entrypoint:

- `mereka-lms-m0u5`

Typical work:

- browser proof
- semantic closure
- selector debt split
- runtime-config consistency
- enterprise admin / learner data proof

Default first bounded slice:

- start with enterprise admin browser proof
- if blocked on credentials/data contract, convert that blocker into an exact
  proof-backed issue instead of broad MFE prose

### Lane 7 — Debt Burn

Goal:

- reduce recurring confusion and operational drag

Good candidates:

- orphan allowlist cleanup
- stale status archive
- merged-but-wrong follow-ups
- high-value TODO cluster decomposition

Default first bounded slice:

- prefer debt that reduces future operator confusion:
  - stale status archive
  - merged-but-wrong follow-up
  - orphan allowlist cleanup

## What Implementers Should Not Do

- do not start a new strategic program because the current one feels messy
- do not create status-doc churn when `CURRENT-OPERATOR-STATE.md` would do
- do not treat `br ready` as the only authority if live truth says otherwise
- do not spend an hour mostly polling
- do not let a broken `main` artifact sit while working on helpers

## Default Next-Move Policy

If you finish a task and genuinely do not know what to do next:

1. check `CURRENT-OPERATOR-STATE.md`
2. clear any important open queue already in motion
3. if there is no such queue, take the first incomplete lane in this file
4. if that lane is broad, choose the smallest bounded slice that produces a
   merge, a clean PR, or a decisive proof artifact

## Success Condition

An implementer following this file should never need oral context to answer:

- what is highest priority
- whether they should merge/fix/rebase or start fresh work
- which durable lane comes next
- when they should avoid tracker surgery
