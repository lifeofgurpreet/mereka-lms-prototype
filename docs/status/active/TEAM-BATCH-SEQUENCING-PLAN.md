---
title: Team Batch Sequencing Plan
type: team-execution-plan
owner: platform-review
status: active
observed_at: 2026-04-18T13:50Z
---

# Team Batch Sequencing Plan

This file answers the team-level question:

**How should the next team approach this work in batches so they do not fight
each other, thrash the queue, or lose truth?**

Use this with:

1. `CURRENT-OPERATOR-STATE.md` for live truth
2. `IMPLEMENTER-MARCHING-ORDERS.md` for single-agent routing
3. this file for team sequencing and batching

## Core Team Rule

Do not run five strategic programs at once.

The team should keep at most:

1. one **queue-clearing** batch
2. one **foundation** batch
3. one **frontier** batch

That keeps progress real while still allowing parallelism.

## Team Shape

Ideal minimum shape:

- **1 reviewer/planner**
  - owns `CURRENT-OPERATOR-STATE.md`
  - owns bead graph quality
  - decides the active batch and keeps the team in tranche
- **2 implementers**
  - each owns one bounded slice inside the active batch
- **1 flex implementer** if available
  - takes proof/evidence work, rebases CI-bound PRs, or burns bounded debt

If the team is only 2 people:

- one person acts as reviewer/planner + queue clearer
- one person acts as primary implementer
- do not run more than 2 active batches

## Batch Discipline

Each batch must have:

- a goal
- explicit entry criteria
- explicit exit criteria
- a max concurrency level
- a list of safe parallel slices

Do not move to the next batch because people are bored. Move because the exit
criteria are satisfied or a harder blocker is now clearer than more work on the
current batch.

## Batch 0 — Queue Clearing / Truth Stabilization

### Goal

Clear or reframe the high-leverage in-flight queue so the team stops paying
attention tax on stale PR state.

### Entry criteria

- important open PRs already exist
- or `main` has known wrong artifacts

### Work

- rebase/fix/land the highest-value in-flight PRs
- patch merged defects on `main`
- update `CURRENT-OPERATOR-STATE.md`
- kill stale assumptions about background PRs

### Max concurrency

- reviewer/planner: 1
- implementers on queue-clearing slices: up to 2
- no new strategic frontier lane yet

### Safe parallel slices

- CI failure diagnosis
- rebase + rerun queue
- docs authority cleanup directly tied to current PRs
- merged-but-wrong patch PRs

### Exit criteria

- no critical PR is stuck because nobody rechecked it
- `CURRENT-OPERATOR-STATE.md` and the actual queue agree
- no known merged defect is being ignored

## Batch 1 — Foundation Closure

### Goal

Finish the system-of-truth / system-of-control foundation so the rest of the
week does not run on drift.

### Included lanes

- governance / doctrine closure
- tracker reliability
- script first-class scaffolding for the highest-risk Tier A items

### Max concurrency

- 1 foundation lane at a time
- 1 bounded secondary support slice allowed

### Important rule

Do **not** run tracker reliability and broad MFE frontier work at the same
time. Tracker repair is too cognitively noisy.

### Recommended split

- implementer A: governance / doctrine or script Tier A hardening
- implementer B: tracker reliability only if explicitly assigned
- reviewer/planner: keep the authority surfaces and sequencing tight

### Exit criteria

- doctrine/governance chain is either landed or reduced to crisp blockers
- tracker lane is either restored or isolated to a precise failure class
- Tier A script list has an actual burn order, not just a scorecard

## Batch 2 — Release-Safety / Operational Proof

### Goal

Convert operational correctness from “docs and helpers exist” to “evidence is
captured.”

### Included lanes

- rollback drill proof
- DR / Velero proof
- runtime realization hardening
- promotion-chain observability hardening

### Max concurrency

- up to 2 slices in parallel

### Safe parallel slices

- rollback drill evidence on one side
- release-truth / realization-truth script hardening on the other

### Exit criteria

- at least one real operational proof artifact lands
- rollback or DR evidence is no longer purely theoretical

## Batch 3 — Script First-Class Burn

### Goal

Treat the top scripts/workflows as product assets, not bash residue.

### Included lanes

- `q69f`
- Tier A script hardening
- verifier portfolio cleanup
- script governance orphan burn

### Max concurrency

- up to 2 bounded script slices

### Safe parallel slices

- one contract/test hardening slice
- one workflow wire-in or orphan-burn slice

### Exit criteria

- top Tier A scripts have:
  - explicit contract
  - deterministic exit semantics
  - proof/self-test story
- at least one script/governance debt cluster is permanently reduced

## Batch 4 — MFE Proof and Closure Frontier

### Goal

Turn vague MFE concern into browser proof, semantic closure, and bounded
architecture decisions.

### Included lanes

- enterprise admin browser proof
- learner secondary endpoint semantic closure
- enterprise customization-surface inventory
- runtime-config consistency verification

### Max concurrency

- 1 proof lane
- 1 architecture/consistency lane

### Safe parallel slices

- implementer A: browser proof
- implementer B: runtime-config / customization-surface inventory

### Important rule

Do not begin broad MFE polish while enterprise proof and semantic closure are
still unknown.

### Exit criteria

- at least one enterprise/browser proof is captured
- one semantic/runtime ambiguity is closed or formally reframed
- the next MFE beads can be created from proof rather than speculation

## Batch 5 — Debt Burn / Expansion

### Goal

Use the stabilized foundation to burn recurring debt and widen the roadmap.

### Included lanes

- stale status archive
- merged-but-wrong follow-ups
- TODO cluster decomposition
- lower-risk script cleanup
- MFE follow-on beads

### Max concurrency

- flexible

### Exit criteria

- debt burn is reducing actual confusion, not just deleting files

## Sequencing Recommendation For The Next Team

### Phase A — first 1 to 2 days

1. Batch 0 — queue clearing / truth stabilization
2. Batch 1 — foundation closure

### Phase B — next 2 to 3 days

1. Batch 2 — release-safety / operational proof
2. Batch 3 — script first-class burn

### Phase C — after the foundation is stable

1. Batch 4 — MFE proof and closure frontier
2. Batch 5 — debt burn / expansion

## Suggested Operating Rhythm

### Daily

- reviewer/planner updates `CURRENT-OPERATOR-STATE.md`
- team confirms the active batch
- implementers claim bounded slices inside that batch

### Midday

- re-check whether the active batch should continue or exit
- if not, do not pivot

### End of day

- record:
  - batch still active or exited
  - what landed
  - what is blocked
  - what the first slice of tomorrow is

## Anti-Patterns

- one implementer on tracker archaeology while the rest start unrelated new
  programs
- multiple people independently deciding “what matters now”
- broad MFE work before the foundation and proof lanes are stable
- leaving queue clearing unfinished because new work feels more exciting
- using raw open-PR lists as the work plan

## Success Condition

The next team is succeeding if:

- everybody can name the current batch
- each person has one bounded slice inside that batch
- `CURRENT-OPERATOR-STATE.md` matches the actual tranche
- batch exits are explicit
- the team is not fragmenting into unrelated strategy threads
