# Specifications

Use this root for normative system behavior, interface contracts, and generated verification surfaces.

## Start here

- Read [INDEX.md](INDEX.md) for the human-facing spec inventory.
- Read [catalog.json](catalog.json) for the machine-readable spec catalog.
- Read [_generated/indexes/spec-read-first.md](_generated/indexes/spec-read-first.md) for the shortest generated reading path.
- Read [_generated/graph.json](_generated/graph.json) for the machine-readable dependency graph.
- Read [standards/SPEC_SYSTEM_CHARTER.md](standards/SPEC_SYSTEM_CHARTER.md) for what belongs in `specs/`.
- Read [standards/DOCS_SPECS_BOUNDARY.md](standards/DOCS_SPECS_BOUNDARY.md) for the docs/specs sibling-root contract.
- Read [plans/README.md](plans/README.md) for execution and rollout plans.
- Read [proposals/README.md](proposals/README.md) for not-yet-normative candidate spec work.
- Read [_generated/testmaps/README.md](_generated/testmaps/README.md) for active generated verification mapping.

## Root contract

- `specs/` defines expected behavior.
- `docs/` explains, governs, and routes humans.
- Generated spec artifacts stay under `specs/_generated/**`.
- Frozen legacy verification artifacts stay under `specs/testmaps/**` until retirement.
- Root-level compatibility wrappers may remain only when they redirect to canonical content under `specs/standards/**`, `specs/plans/**`, `specs/proposals/**`, or `specs/templates/**`.
