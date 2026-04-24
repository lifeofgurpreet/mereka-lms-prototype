# Foundations Rework Program (v2 Overlay)
_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-03-09 • Status: historical overlay planning snapshot_

This is a historical overlay-program plan for the ADR-governance rework wave.
It does not define the current docs-program execution front door.

For current docs-program execution, use:

- [POST_REBASE_INTAKE_2026-04-13.md](POST_REBASE_INTAKE_2026-04-13.md)
- [REVIEW_HARDENING_BOARD_2026-04-13.md](REVIEW_HARDENING_BOARD_2026-04-13.md)
- [DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md](DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md)

For the current architecture front door, use:

- [../../architecture/README.md](../../architecture/README.md)

Retain this document only as a historical target-state reference for the
earlier ADR-overlay restructuring plan.

## Mission

Refactor architecture knowledge into a durable, machine-checkable governance layer without breaking existing ADR paths in wave 1.

## Execution Model

- Wave 1: in-place governance overlay
- Wave 2: optional physical ADR restructuring after graph/index safety

## Target Steady State

- Constitution docs are the living law.
- ADRs are the historical decision ledger.
- RFCs hold undecided future architecture.
- Contracts define machine-checkable interfaces.
- Runbooks and evidence sit outside ADR bodies.

## Phases

### Phase 0 — Freeze And Inventory

- Stop new ADR authoring in old shape.
- Build contradiction register and full ADR inventory.
- Classify each ADR as `foundation | domain | migration | exception`.

Exit gate:
- ADR file frontmatter is the source ADR ledger; `manifest.yaml`, `classification-map.yaml`, and `status-map.yaml` are generated compatibility maps.

### Phase 1 — Install Overlay OS

- Add charter, glossary, bundle rules, validator suite, decision-graph generator, generated bundle artifacts.
- Keep existing ADR filenames and paths.

Exit gate:
- `scripts/qa/verify_adr_suite.sh` passes.

### Phase 2 — Constitutional ADRs

Author in order:
- ADR-028 Platform Sources of Truth and Control Planes
- ADR-029 Identity, Session, and Domain-Boundary Strategy
- ADR-030 Feature Flag and Rollout Lifecycle
- ADR-031 Deprecation and Removal Policy
- ADR-032 Data Governance, PII, Retention, and Deletion
- ADR-033 Tenant Lifecycle Contract

### Phase 3 — Contradiction Resolution

Resolve known conflicts across ADR-003, ADR-017, ADR-019, ADR-021, ADR-024, and ADR README behavior.

### Phase 4 — Domain Completeness

Author next ring as proposals first, then accept selectively:
- RFC/ADR-034..ADR-041 (eventing, frontend composition, cache, async, commerce, i18n, versioning, authz)

### Phase 5 — CI Enforcement

- Run ADR suite in CI as blocking.
- Fail on expired exceptions, broken references, missing manifest entries.

### Phase 6 — Operating Rhythm

- Monthly: contradiction + exception review.
- Quarterly: constitution review.
