# Evidence Index
_Audience: Contributors • Owner: Platform Team • Last verified: 2026-03-08 • Status: canonical_

This is the active evidence root for Wave 2.

## Scope

Use `docs/evidence/**` for proof packs, validation bundles, screenshots, exported traces, and other material that demonstrates a claim or gate outcome.

## Transition note

Some evidence still exists outside this root from the earlier topology cleanup. During Wave 2:

- new active evidence must converge here
- top-level `evidence/**` is superseded compatibility only
- archive evidence remains cold-only under `docs/archive/evidence/**`
- compatibility pointers may still reference older locations until migration completes

## Expected pack shape

`docs/evidence/<domain>/<YYYY-MM-DD>-<slug>/README.md`

Each pack should include:

- owner
- capture date
- system or domain
- linked issue or ticket
- acceptance criteria or gate proved
- redaction note
- retention class

## Current active domains

- `docs/evidence/operations/`
