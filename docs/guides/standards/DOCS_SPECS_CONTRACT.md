---
title: Docs / Specs Contract
owner: Platform Team
status: canonical
last_reviewed: 2026-03-08
canonical_root: docs/guides
doc_class: guide
summary: Defines the boundary between specs, docs, and generated testmaps so verification truth stays unambiguous.
tags:
  - docs
  - specs
  - verification
audience: Contributors
---

# Docs / Specs Contract

This contract separates explanation from intention and closes the current split-brain around verification artifacts.

## Start with the question

Before creating or editing a file, ask:

1. Am I defining what the system must do?
2. Or am I explaining how the current system works, how to operate it, or what happened?

If you are defining required behavior, you are probably changing `specs/**`.
If you are explaining or operating the current system, you are probably changing `docs/**`.

## Artifact roles

| Artifact | Root | Meaning |
| --- | --- | --- |
| Specs | `specs/**` | Normative intended behavior |
| Plans | `specs/plans/**` or explicit planning docs | Implementation sequencing and execution planning |
| Test plans | `specs/**` or plan-attached validation sections | Validation strategy |
| Spec catalog | `specs/catalog.json` | Machine-readable index of the normative spec corpus |
| Testmaps | generated output under `specs/_generated/testmaps/**` | Verification mapping derived from source annotations and spec metadata |
| Docs | `docs/**` | Explanation, operation, history, evidence, and status |

## Hard rules

- Specs define what MUST be true.
- Docs explain what IS true now, how to operate the system, or what happened.
- Docs MUST NOT masquerade as specs.
- Specs MUST NOT be replaced by prose in `docs/**`.
- Testmaps are generated artifacts and MUST NOT become a second manual truth plane.

## Quick routing guide

Use `specs/**` when the change answers:
- what the platform must do,
- what an API or workflow guarantees,
- what acceptance criteria define completion,
- what verification is required to call a behavior implemented.

Use `docs/**` when the change answers:
- how to operate the current system,
- how contributors should work,
- what architecture decisions and standards currently govern the repo,
- what evidence proves a claim,
- what the current status or readiness posture is.

## Verification truth

The verification mapping source of truth is:

1. spec acceptance criteria
2. `@covers` annotations in code and verification scripts
3. centralized manual verification metadata where automation is not possible

Generated testmaps are compatibility outputs from that source of truth.

## What signals that something belongs in specs

Move the work into `specs/**` if the document contains:
- normative requirements,
- acceptance criteria,
- testable feature scope,
- rollout and rollback requirements for feature behavior,
- edge cases that define expected product or system behavior.

If the key sentence starts with “the system MUST”, that is often a specs signal.

## Transitional reality

The repository still contains `specs/testmaps/**` as a frozen legacy path. During Wave 2B:

- treat those files as frozen compatibility artifacts
- do not edit them
- generate active outputs only under `specs/_generated/testmaps/**`
- update ADR-011 and supporting tooling so the filesystem matches the contract

The practical reading rule is:

- if you want the current generated verification map, read `specs/_generated/testmaps/**`
- if you encounter `specs/testmaps/**`, treat it as legacy compatibility and do not extend it

## What belongs in docs

Use `docs/**` for:

- living architecture standards under `docs/concepts/architecture/**`
- operator procedure under `docs/ops/**`
- contributor and user guidance under `docs/guides/**`
- reference and policy under `docs/reference/**` and `docs/policies/**`
- evidence under `docs/evidence/**`
- status under `docs/status/**`
- decision history under `docs/adr/**`

## What does not belong in docs

Do not use `docs/**` as the primary home for:

- normative product or platform requirements
- generated testmaps
- a second independent metadata catalog
- implementation plans masquerading as accepted architecture

## What gets rejected

- A docs change that silently changes required product behavior.
- A spec change hidden inside a guide, runbook, or architecture narrative.
- Manual edits to generated testmaps.
- Docs that try to become a second verification authority instead of linking specs and proof.
- Plans or proposals presented as accepted current law.

## Required contributor behavior

Before adding or changing files:

1. decide whether the change is a spec change or a docs change
2. place the file under the winning root for that artifact kind
3. regenerate generated artifacts instead of hand-editing them
4. update or add compatibility stubs when moving legacy paths

## Practical review test

Reviewers should ask:
1. If this file disappeared, would the required behavior of the system become ambiguous?
2. If yes, it probably belongs in `specs/**`.
3. If no, and it mainly helps readers understand or operate the current system, it probably belongs in `docs/**`.

## Related authority docs

- [ARCHITECTURE_CHARTER.md](../../concepts/architecture/ARCHITECTURE_CHARTER.md)
- [DOCUMENTATION_AUTHORITY_RESOLVER.md](../../concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md)
- [ADR-011: Convention-Based Spec Verification](../../adr/011-convention-based-spec-verification.md)
