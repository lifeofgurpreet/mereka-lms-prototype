---
title: Architecture Charter
owner: Platform Team
status: canonical
last_reviewed: 2026-03-08
last_updated: 2026-03-10
canonical_root: docs/concepts/architecture
doc_class: architecture-standard
summary: Defines the documentation and architecture control plane, winning roots, and non-negotiable authority rules.
tags:
  - architecture
  - governance
  - control-plane
governs:
  - platform.control-plane
  - platform.repo-boundary
  - docs.policy
review_cycle: quarterly
---

# Architecture Charter

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

## What this charter is for

Use this charter when you need to answer:
- which root governs a kind of document,
- what counts as active truth,
- what must be treated as compatibility-only,
- and what the repository will reject even if the prose is technically correct.

## What this charter is not

This charter does not replace:
- `specs/**` for intended behavior,
- `docs/adr/**` for decision history,
- `docs/ops/**` for operating procedures,
- `docs/evidence/**` for proof,
- or `docs/status/**` for current posture.

It defines the control plane that tells you which of those artifacts wins.

## Authority model

1. `specs/**` is the normative intended-behavior system.
2. `docs/concepts/architecture/**` is the canonical living architecture and standards root.
3. `docs/ops/**` is the canonical operator-doc root.
4. `docs/adr/**` is the decision ledger. ADRs record accepted, superseded, historical, and exception decisions; they are not the whole living architecture system.
5. `docs/guides/**`, `docs/reference/**`, and `docs/policies/**` are canonical supporting surfaces.
6. `docs/evidence/**` is the only active evidence root.
7. `docs/status/**` is the only active reporting and status root.
8. `docs/archive/**` is cold storage only.

## Operating rule

If two documents appear to answer the same question, the one in the winning root governs and the other one is stale, transitional, or historical unless it explicitly points back to the winner.

## Non-negotiables

- Canonical docs MUST NOT silently route readers into transitional roots.
- Transitional roots MUST be stub-only once their content has been migrated.
- Archive material MUST NOT be treated as active guidance or current status.
- In-document metadata is the source of truth for document identity and ownership.
- Generated artifacts MUST be derived from source docs and MUST NOT become a second independent truth plane.
- Winning-root docs MUST remain cataloged in `generated/catalogs/docs-catalog.json`.
- A change to a winning-root doc MUST ship with the matching source-catalog update in the same diff.
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

## Fast reading paths

Use the smallest path that matches the task:

- Change architecture or governance:
  1. this charter
  2. authority resolver
  3. docs/specs contract
  4. relevant architecture standard
- Change operational behavior:
  1. authority resolver
  2. relevant `docs/ops/**` index
  3. relevant policy or reference doc
- Review whether a claim is true:
  1. status doc
  2. linked evidence pack
  3. supporting policy or spec if needed

## Operational meaning

- If you are deciding what MUST be true now, read `docs/concepts/architecture/**`.
- If you are deciding how to operate the platform, read `docs/ops/**`.
- If you are deciding what the system is intended to do, read `specs/**`.
- If you are deciding what was previously chosen, read `docs/adr/**`.
- If you are deciding whether something actually happened, read `docs/evidence/**`.
- If you are deciding current status or open follow-up, read `docs/status/**`.

## Transitional policy

The following retained paths are tombstone-only compatibility surfaces:

- `docs/operations/README.md`
- `docs/runbooks/README.md`
- `docs/architecture/README.md`
- `docs/branding/README.md`
- `docs/ci-cd/README.md`
- `docs/migrations/README.md`

They MAY preserve a minimal replacement pointer at the root. They MUST NOT continue to grow as competing active roots.

## Review test

The docs system is healthy only if a new contributor can answer “where should this go?” and “which document wins?” without reading multiple conflicting roots.

## Enforcement posture

Wave 2 is not advisory only anymore. The repository now blocks:

- canonical docs that link into transitional/archive paths without explicit legacy context
- changed transitional docs that are not superseded stubs
- archive writes without explicit override
- winning-root catalog residue
- winning-root doc changes that do not update the source catalog
