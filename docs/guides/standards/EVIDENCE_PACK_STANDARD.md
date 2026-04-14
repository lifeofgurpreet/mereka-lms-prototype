---
title: Evidence Pack Standard
owner: Platform Team
status: canonical
last_reviewed: 2026-03-08
last_verified: 2026-04-13
canonical_root: docs/guides/standards
doc_class: guide
audience:
  - contributors
summary: Defines the active evidence-pack contract, expected structure, and rejection criteria for docs/evidence.
tags:
  - docs.evidence
  - docs.policy
---

# Evidence Pack Standard

This standard defines the active evidence contract for `docs/evidence/**`.

## Authority

- Active evidence MUST live under `docs/evidence/**`.
- Top-level `evidence/**` is transitional compatibility only.
- `docs/archive/evidence/**` is cold storage only.

## Required path shape

`docs/evidence/<domain>/<YYYY-MM-DD>-<slug>/README.md`

Examples:
- `docs/evidence/operations/TENANT_ISOLATION_EVIDENCE.md`
- `docs/evidence/operations/ANALYTICS_KEY_ELIMINATION_EVIDENCE.md`

## Required README fields

Every active evidence pack README MUST include:

- owner
- capture date
- system or domain
- linked issue, PR, bead, or ticket
- acceptance criteria, gate, or claim proved
- redaction note
- retention class

## What a good evidence pack does

A good evidence pack lets a reviewer answer three questions quickly:
1. What claim is being proved?
2. What proof was captured?
3. Is the proof current enough to trust?

If a reader cannot answer those questions in under a minute, the pack is too vague.

## Content rules

- Evidence packs MUST prove a concrete claim, gate outcome, or runtime fact.
- Evidence packs MUST NOT become a second runbook or architecture narrative.
- Large raw payloads MAY be referenced externally, but the README MUST remain in-repo.
- Active docs SHOULD link to the winning evidence path, not to archive or superseded roots.

## Recommended structure

Use this structure unless the evidence type clearly needs a variation:

1. Claim proved
2. Scope
3. Capture context
4. Proof artifacts
5. Result
6. Redaction and retention notes

## What gets rejected

- Packs that only say a check "passed" without naming the claim proved.
- Packs that embed long operational procedures instead of linking the runbook.
- Packs that reference screenshots, logs, or JSON dumps without explaining why they matter.
- Packs that duplicate an already-active canonical pack for the same claim.
- Packs that read like a closure memo instead of proof.

## Domain guidance

Recommended active domains:

- `docs/evidence/operations/`
- add new domain subroots beneath `docs/evidence/` only when active packs exist

## Archive rule

When an evidence pack is no longer active:

1. move it to cold storage or supersede it
2. leave a compatibility pointer if active docs still reference the old path
3. do not keep two active canonical copies

## Writing standard

- Prefer short factual sentences over narrative retrospectives.
- State the runtime fact first, then list supporting artifacts.
- Use timestamps, identifiers, and environment names where they materially improve traceability.
- Do not bury the verdict at the end of the file.

## Related authority docs

- [Evidence Index](../../evidence/INDEX.md)
- [Documentation Index](../../README.md)
- [Docs / Specs Contract](./DOCS_SPECS_CONTRACT.md)
