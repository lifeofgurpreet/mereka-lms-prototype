---
title: Script Tier A First 10
type: burn-list
owner: platform-review
status: active
observed_at: 2026-04-18T15:20Z
---

# Script Tier A First 10

This is the first concrete burn list under the script first-class program.

It is intentionally narrow. The repo has more than a thousand script-like
files; the right move is not “audit everything,” but “name the highest-leverage
Tier A surfaces and harden them in order.”

## Working Rule

When auditing script reality, do not trust the current VPS checkout branch by
default.

Observed on `2026-04-18`:

- working tree branch: `docs/final-deliverables-rc07-closed-20260418`
- `origin/main` is ahead by multiple governance / CI / runbook commits

Implication:

- script inventories should be checked against `origin/main`, not just `HEAD`
- otherwise planners will misclassify already-landed work as absent

## First 10 Targets

### 1. `scripts/governance/generate-current-operator-state.sh`

- repo: `mereka-lms`
- present on `HEAD`: yes
- present on `origin/main`: yes
- why Tier A: rolling authority file generator; directly shapes operator truth
- hardening target:
  - deterministic output contract
  - explicit handling of tracker-degraded state
  - footer that states generation source/time/context

### 2. `scripts/governance/audit-tracker-hygiene.sh`

- repo: `mereka-lms`
- present on `HEAD`: yes (new local/VPS addition)
- present on `origin/main`: not yet
- why Tier A: planner safety gate while tracker repair is open
- hardening target:
  - shellcheck clean
  - document expected exit codes
  - add a minimal self-test fixture

### 3. `scripts/qa/verify-docs-authority-invariants.sh`

- repo: `mereka-lms`
- present on `HEAD`: yes
- present on `origin/main`: yes
- why Tier A: blocks stale or malformed authority docs from landing
- hardening target:
  - broaden checks for rolling-vs-historical doc entrypoints
  - catch workstation-specific path leakage early

### 4. `scripts/qa/verify-script-governance-orphans.sh`

- repo: `mereka-lms`
- present on `HEAD`: yes
- present on `origin/main`: yes
- known evidence: has a same-name test companion
- why Tier A: script governance signal for the whole repo
- hardening target:
  - convert current orphan list into a burn-down register
  - keep allowlist debt bounded and intentional

### 5. `scripts/ci/run-with-retry.sh`

- repo: `mereka-lms`
- present on `HEAD`: no
- present on `origin/main`: yes
- why Tier A: directly affects security-scan truth and CI semantics
- hardening target:
  - verify all wire-ins use safe retry classes
  - prevent generic exit `1` from being normalized as transient

### 6. `scripts/ci/emit-promotion-chain-metrics.sh`

- repo: `mereka-lms`
- present on `HEAD`: no
- present on `origin/main`: yes
- why Tier A: release-timing observability for promotion chain truth
- hardening target:
  - wire into actual promotion path
  - document the canonical stage vocabulary

### 7. `scripts/qa/verify-pods-on-digest.sh`

- repo: `mereka-lms`
- present on `HEAD`: no
- present on `origin/main`: yes
- why Tier A: live realization truth, not just deployment spec truth
- hardening target:
  - explicit `--context`
  - multi-container safety
  - deterministic failure messaging

### 8. `scripts/qa/verify-mereka-lms-runtime-realization.sh`

- repo: `bbi-infrastructure`
- present on checked path: yes
- why Tier A: cross-repo runtime proof for Argo -> live pod realization
- hardening target:
  - ensure pod `imageID` gate remains canonical
  - verify selector assumptions remain correct as workloads evolve

### 9. `.github/workflows/post-merge-cluster-validation.yml`

- repo: `bbi-infrastructure`
- present: yes
- why Tier A: workflow, but functionally part of script control plane
- hardening target:
  - keep runtime realization checks and post-merge validation in one coherent
    proof chain
  - ensure proof steps emit actionable evidence, not just pass/fail

### 10. `scripts/governance/verify-retraction-sweep.sh`

- repo: `mereka-lms`
- present on `HEAD`: no
- present on `origin/main`: no
- present on feature branch history: yes
- why Tier A: doctrine enforcement against retracted-theory drift
- hardening target:
  - land cleanly
  - move from WARN-mode prototype to an intentional policy mode

## Recommended First Burn Order

1. `generate-current-operator-state.sh`
2. `audit-tracker-hygiene.sh`
3. `verify-docs-authority-invariants.sh`
4. `verify-script-governance-orphans.sh`
5. `run-with-retry.sh`
6. `verify-pods-on-digest.sh`
7. `verify-mereka-lms-runtime-realization.sh`
8. `post-merge-cluster-validation.yml`
9. `emit-promotion-chain-metrics.sh`
10. `verify-retraction-sweep.sh`

## What “First-Class” Means For This List

Each item should eventually have:

- a clear usage contract
- deterministic exit behavior
- explicit context/env handling
- at least one proof path or self-test
- a named failure class it closes
- a canonical owner in docs/governance

## Planner Note

Do not try to seed all ten as beads while tracker repair is still open.

Until tracker hygiene is restored:

- use this document as the planner queue
- promote only the highest-leverage items into tracker work
- keep the rolling state file honest about which items are doc-backed versus
  tracker-backed
