# Wave Architecture Root Reset Tracker

> Historical tracker for a superseded reset model.
>
> This wave attempted to retire `docs/architecture/**` in favor of
> `docs/concepts/architecture/**`. That is no longer the repo model.
> Current stable architecture front doors live under `docs/architecture/**`,
> while `docs/concepts/architecture/**` is retained for explicitly canonical
> standards and deep reference context.

For current docs-program execution, use:

- [POST_REBASE_INTAKE_2026-04-13.md](POST_REBASE_INTAKE_2026-04-13.md)
- [REVIEW_HARDENING_BOARD_2026-04-13.md](REVIEW_HARDENING_BOARD_2026-04-13.md)
- [DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md](DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md)

For the current architecture front door, use:

- [../../architecture/README.md](../../architecture/README.md)

Status: completed
Owner: codex
Branch: docs/architecture-root-reset
Worktree: /home/gurpreet/projects/k8s/mereka-lms-wt-architecture-root-reset
Started from: c0de95d631e327abbb40a1cb3c49960984748d9e

## Historical Objective

Retire `docs/architecture/**` as an active documentation root so that:
- `docs/concepts/architecture/**` is the only living architecture root
- `docs/adr/**` is the only ADR and RFC root
- `docs/guides/standards/**` is the only standards root
- `docs/meta/docs-program/**` is the only docs-program governance root

This objective is retained for historical traceability only. It does not
describe current repo truth.

## Packet A Classification

### Delete after reference rewrite

- `docs/architecture/ADR_LANGUAGE_STYLE.md`
- `docs/architecture/ADR_NUMBERING_AND_NAMING.md`
- `docs/architecture/AGENT_WORKPACKETS.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/FOUNDATIONS_PROGRAM.md`
- `docs/architecture/PROGRAM_UPDATE_V2_BRIEF.md`
- `docs/architecture/charter.md`
- `docs/architecture/decision-map.md`
- `docs/architecture/constitution/**`
- `docs/architecture/overviews/**`
- `docs/architecture/rfc/**`
- `docs/architecture/diagrams/adr-layer-map.mmd`
- `docs/architecture/diagrams/decision-graph.mmd`
- `docs/architecture/diagrams/repo-structure.txt`

### Retain only if needed

- `docs/architecture/README.md`
  - preferred end state: tombstone only

### Move into canonical living architecture root

- `docs/architecture/bundle-rules.yaml` -> `docs/concepts/architecture/bundle-rules.yaml`
- `docs/architecture/glossary.yaml` -> `docs/concepts/architecture/glossary.yaml`

## Sidecar Decision

- `bundle-rules.yaml` is live: consumed by `scripts/qa/build_decision_graph.py` and `scripts/qa/resolve_adr_impact.py`
- `glossary.yaml` is live: referenced by ADR authoring and governance docs for controlled tokens
- neither sidecar should remain under a retired compatibility root
- packet B will move both files into `docs/concepts/architecture/` and update consumers

## Reference Sweep

Observed live internal references fall into these groups:
- active docs and specs still pointing at wrapper paths under `docs/architecture/overviews/**` and `docs/architecture/rfc/**`
- governance docs still treating `docs/architecture/charter.md`, `glossary.yaml`, and `bundle-rules.yaml` as active
- scripts and validators still consuming `docs/architecture/**` as if it were canonical
- archive and superseded docs also contain old references; these are lower priority unless they block clean validation

## Packet Targets

### Packet B

- move the two surviving sidecars into `docs/concepts/architecture/`
- update direct consumers and governance references

### Packet C

- rewrite active internal references away from `docs/architecture/**`
- delete wrapper trees and dead diagrams

### Packet D

- reduce `docs/architecture/**` to tombstone-only `README.md` or remove directory entirely if safe
- add no-regrowth guardrail

### Packet E

- write closeout and review handoff

## Open Risks

- historical/archive surfaces and a few transitional-policy files still mention `docs/architecture/**` intentionally as retired topology history
- some legacy scripts already pointed at now-canonical `docs/concepts/architecture/**` files that were missing from this wave's explicit classification; those refs were rewritten when they were active, but this wave did not attempt to normalize every historical prompt or archive reference

## Historical Wave End State

- this wave reduced `docs/architecture/**` toward a tombstone-only state
- `bundle-rules.yaml` and `glossary.yaml` were moved under
  `docs/concepts/architecture/`
- wrapper trees under `constitution/`, `overviews/`, `rfc/`, and `diagrams/`
  were deleted
- active internal references at that time were rewritten toward
  `docs/concepts/architecture/**`, `docs/adr/**`,
  `docs/reference/architecture/**`, or docs-program roots

## Current Canonical Model

- `docs/architecture/**` is the stable architecture front-door root
- `docs/concepts/architecture/**` is retained for explicitly canonical
  standards and deep reference material
- the maintained read-first authority surfaces are
  `docs/architecture/README.md` and
  `docs/architecture/PLATFORM_AUTHORITY_MAP.md`
