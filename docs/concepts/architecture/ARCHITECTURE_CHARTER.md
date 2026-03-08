# Architecture Charter
_Audience: Engineering Team • Owner: Platform Team • Last verified: 2026-03-08 • Status: canonical_

This charter defines the living architecture control model for the repository. It exists so humans and agents can determine which documentation roots are current law, which ones are transitional, and which ones are cold storage.

## Mission

Operate one documentation control plane per artifact kind:

- living architecture standards
- operator procedure
- decision history
- normative specs
- evidence
- active status
- archive

The repository MUST have one winner per artifact kind. Transitional surfaces MAY remain for compatibility, but they MUST NOT compete with canonical roots.

## Authority model

1. `specs/**` is the normative intended-behavior system.
2. `docs/concepts/architecture/**` is the canonical living architecture and standards root.
3. `docs/ops/**` is the canonical operator-doc root.
4. `docs/adr/**` is the decision ledger. ADRs record accepted, superseded, historical, and exception decisions; they are not the whole living architecture system.
5. `docs/guides/**`, `docs/reference/**`, and `docs/policies/**` are canonical supporting surfaces.
6. `docs/evidence/**` is the only active evidence root.
7. `docs/status/**` is the only active reporting and status root.
8. `docs/archive/**` is cold storage only.

## Non-negotiables

- Canonical docs MUST NOT silently route readers into transitional roots.
- Transitional roots MUST be stub-only once their content has been migrated.
- Archive material MUST NOT be treated as active guidance or current status.
- In-document metadata is the source of truth for document identity and ownership.
- Generated artifacts MUST be derived from source docs and MUST NOT become a second independent truth plane.
- Testmaps are generated verification artifacts, not hand-authored policy.
- Proposed decisions MUST live outside the accepted ADR hot path.
- Open edX and Tutor process guidance MUST default to official sources first:
  - `https://docs.openedx.org`
  - `https://docs.tutor.edly.io`
  - `https://open-edx-proposals.readthedocs.io`

## Required reading hot path

Start here before broad repo exploration:

1. [DOCUMENTATION_AUTHORITY_RESOLVER.md](DOCUMENTATION_AUTHORITY_RESOLVER.md)
2. [DOCS_SPECS_CONTRACT.md](../../guides/standards/DOCS_SPECS_CONTRACT.md)
3. the relevant architecture standard in this directory
4. the relevant ops quickref or runbook under `docs/ops/**`
5. accepted ADRs or active exceptions only if the work changes an already-decided area

## Operational meaning

- If you are deciding what MUST be true now, read `docs/concepts/architecture/**`.
- If you are deciding how to operate the platform, read `docs/ops/**`.
- If you are deciding what the system is intended to do, read `specs/**`.
- If you are deciding what was previously chosen, read `docs/adr/**`.
- If you are deciding whether something actually happened, read `docs/evidence/**`.
- If you are deciding current status or open follow-up, read `docs/status/**`.

## Transitional policy

The following roots are transitional in Wave 2 and must converge toward stub-only compatibility:

- `docs/operations/**`
- `docs/onboarding/**`
- `docs/branding/**`
- `docs/runbooks/**`
- `docs/architecture/**`

They MAY preserve compatibility notes and replacement pointers during migration. They MUST NOT continue to grow as competing active roots.
