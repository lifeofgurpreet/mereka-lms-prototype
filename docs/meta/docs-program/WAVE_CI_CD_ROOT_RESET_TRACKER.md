---
title: Wave CI/CD Root Reset Tracker
owner: Platform Team
status: canonical
last_verified: 2026-03-10
canonical_root: docs/meta/docs-program
doc_class: tracker
summary: Packet tracker for retiring docs/ci-cd as a living documentation root.
tags:
  - docs
  - ci-cd
  - root-reset
audience: Contributors
---

# Wave CI/CD Root Reset Tracker

## Objective

Retire `docs/ci-cd/**` as a living documentation root. The canonical CI/CD operator surface already lives under `docs/ops/ci-cd/**`.

## Canonical owner after reset

- Canonical living CI/CD root: `docs/ops/ci-cd/**`
- Transitional compatibility root to retire: `docs/ci-cd/**`

## File classification

### Delete after rewriting refs

- `docs/ci-cd/FASTLANE_AUTOMATION.md`
- `docs/ci-cd/TUTOR_CONFIG_CI.md`
- `docs/ci-cd/ios-cicd-spec.md`

### Retain

- `docs/ci-cd/README.md`
  - Create as a tombstone-only redirect to `docs/ops/ci-cd/**`.

## Reference pressure found in Packet A

Only historical topology/program ledgers still mentioned `docs/ci-cd/**`. No active canonical docs, specs, infra, or scripts rely on the legacy root.

## Sidecar decision

No canonical sidecars or generator-owned assets exist under `docs/ci-cd/**`. The root is duplicate prose only.

## Packet record

### Packet A

- Scope: classify `docs/ci-cd/**`, prove canonical target root, record reference sweep.

### Packet B

- Scope: add the tombstone README and update active front-door docs to reflect the retired-root state.

### Packet C

- Scope: delete duplicate files from `docs/ci-cd/**`.

### Packet D

- Scope: add the no-regrowth guard and wire it into docs policy checks.

### Packet E

- Scope: closeout and review handoff.
