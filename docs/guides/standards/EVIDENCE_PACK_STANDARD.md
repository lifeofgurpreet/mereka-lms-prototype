# Evidence Pack Standard
_Audience: Contributors • Owner: Platform Team • Last verified: 2026-03-08 • Status: canonical_

This standard defines the active evidence contract for `docs/evidence/**`.

## Authority

- Active evidence MUST live under `docs/evidence/**`.
- Top-level `evidence/**` is transitional compatibility only.
- `docs/archive/evidence/**` is cold storage only.

## Required path shape

`docs/evidence/<domain>/<YYYY-MM-DD>-<slug>/README.md`

Examples:
- `docs/evidence/operations/2026-03-08-runtime-proof/README.md`
- `docs/evidence/tenants/2026-03-08-branding-parity/README.md`

## Required README fields

Every active evidence pack README MUST include:

- owner
- capture date
- system or domain
- linked issue, PR, bead, or ticket
- acceptance criteria, gate, or claim proved
- redaction note
- retention class

## Content rules

- Evidence packs MUST prove a concrete claim, gate outcome, or runtime fact.
- Evidence packs MUST NOT become a second runbook or architecture narrative.
- Large raw payloads MAY be referenced externally, but the README MUST remain in-repo.
- Active docs SHOULD link to the winning evidence path, not to archive or superseded roots.

## Domain guidance

Recommended active domains:

- `docs/evidence/operations/`
- `docs/evidence/observability/`
- `docs/evidence/branding/`
- `docs/evidence/tenants/`

## Archive rule

When an evidence pack is no longer active:

1. move it to cold storage or supersede it
2. leave a compatibility pointer if active docs still reference the old path
3. do not keep two active canonical copies

## Related authority docs

- [Evidence Index](../../evidence/INDEX.md)
- [Documentation Authority Resolver](../../concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md)
- [Docs / Specs Contract](./DOCS_SPECS_CONTRACT.md)
