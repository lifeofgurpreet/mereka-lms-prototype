# Wave 4 Closeout

_Audience: Reviewers, contributors, and agents • Owner: Platform Team • Last verified: 2026-03-09 • Status: historical closeout snapshot_

This is a historical closeout for the completed Wave 4 unified-knowledge
control-plane packet. It does not define the current docs-program execution or
review front door.

For current docs-program execution, use:

- [POST_REBASE_INTAKE_2026-04-13.md](POST_REBASE_INTAKE_2026-04-13.md)
- [REVIEW_HARDENING_BOARD_2026-04-13.md](REVIEW_HARDENING_BOARD_2026-04-13.md)
- [DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md](DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md)

For the current architecture front door, use:

- [../../architecture/README.md](../../architecture/README.md)

Retain this document only as historical closeout context for the completed
Wave 4 packet.

## What Wave 4 changed

- Added a shared docs/specs knowledge model instead of treating the two roots as unrelated systems.
- Added a unified machine-readable knowledge catalog and a unified graph.
- Added a reviewer-facing front door that explains how to interpret roots, lanes, generated surfaces, and compatibility wrappers.
- Added a wrapper-retirement ledger so compatibility surfaces are explicit inventory, not invisible debt.
- Added a single merge-time knowledge gate and wired it into the docs-policy CI path.

## What stayed intentionally unchanged

- `docs/` and `specs/` remain separate filesystem roots.
- Wave 3 decisions remain locked, including the Kajabi/MCT normative holdout.
- Compatibility wrappers were not force-retired; they were inventoried and justified first.

## Current unified state

- tracked files: 1591
- docs files: 1368
- specs files: 223
- compatibility surfaces: 5
- generated surfaces: 49
- archival surfaces: 292

## Recommended next step

- Open or refresh the PR for `docs/wave4-unified-knowledge-control-plane`, using the reviewer handoff and checklist as the front door for review.
