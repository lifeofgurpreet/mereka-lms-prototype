# Status Reporting Standard
_Audience: Contributors • Owner: Platform Team • Last verified: 2026-03-08 • Status: canonical_

This standard defines the active reporting contract for `docs/status/**`.

## Authority

- Active status and readiness reporting MUST live under `docs/status/**`.
- `reports/**` is not an active reporting root for current operational truth.
- `docs/archive/reports/**` is cold storage only.

## Winning active roots

Use these status buckets:

- `docs/status/active/`
- `docs/status/readiness/`
- `docs/status/migrations/`
- `docs/status/weekly/`
- `docs/status/incidents/`

## Required status fields

Every active status document SHOULD include:

- owner
- date or reporting window
- scope
- current state
- explicit blockers or open risks
- next decision or next action

## Content rules

- Active status docs MUST describe current operational truth.
- Time-bound reports MUST move out of the hot path when they become historical.
- Status docs MUST NOT become a second architecture standard or long-term runbook.
- Status docs SHOULD link to current evidence packs when they make factual claims.

## Migration and readiness guidance

- `docs/status/migrations/` is for active migration posture, not historical writeups.
- `docs/status/readiness/` is for go/no-go, readiness, and release posture.
- Once a status document stops representing live truth, it SHOULD be archived or superseded.

## Archive rule

Do not keep active reporting in archive roots. If a status document is retained for history:

1. move it to cold storage or supersede it
2. leave a stub only when compatibility is required
3. keep the active root free of stale closures

## Related authority docs

- [Status Index](../../status/INDEX.md)
- [Documentation Authority Resolver](../../concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md)
- [Docs / Specs Contract](./DOCS_SPECS_CONTRACT.md)
