# RFC-035 Frontend Runtime Composition And Dependency Alignment

Status: proposed
Source record: `docs/adr/035-frontend-runtime-composition-and-dependency-alignment.md`

## Intent

Make runtime composition, plugin slots, and dependency alignment the default frontend extension model.

## Why This Is Still An RFC

The policy direction is clear, but this remains active architecture work that should graduate only after the migration path is stable.

## Candidate Invariants

- Supported slots and hooks win over source patching.
- Runtime configuration is deterministic.
- Dependency compatibility ranges are declared.
