# Docs / Specs Contract
_Audience: Contributors • Owner: Platform Team • Last verified: 2026-03-08 • Status: canonical_

This contract separates explanation from intention and closes the current split-brain around verification artifacts.

## Artifact roles

| Artifact | Root | Meaning |
| --- | --- | --- |
| Specs | `specs/**` | Normative intended behavior |
| Plans | `specs/plans/**` or explicit planning docs | Implementation sequencing and execution planning |
| Test plans | `specs/**` or plan-attached validation sections | Validation strategy |
| Testmaps | generated output | Verification mapping derived from source annotations and spec metadata |
| Docs | `docs/**` | Explanation, operation, history, evidence, and status |

## Hard rules

- Specs define what MUST be true.
- Docs explain what IS true now, how to operate the system, or what happened.
- Docs MUST NOT masquerade as specs.
- Specs MUST NOT be replaced by prose in `docs/**`.
- Testmaps are generated artifacts and MUST NOT become a second manual truth plane.

## Verification truth

The verification mapping source of truth is:

1. spec acceptance criteria
2. `@covers` annotations in code and verification scripts
3. centralized manual verification metadata where automation is not possible

Generated testmaps are compatibility outputs from that source of truth.

## Transitional reality

The repository still contains `specs/testmaps/**`. During Wave 2:

- treat those files as generated compatibility artifacts
- do not manually curate them as the primary source
- move tooling toward `specs/_generated/testmaps/**`
- update ADR-011 and supporting tooling so the filesystem matches the contract

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

## Required contributor behavior

Before adding or changing files:

1. decide whether the change is a spec change or a docs change
2. place the file under the winning root for that artifact kind
3. regenerate generated artifacts instead of hand-editing them
4. update or add compatibility stubs when moving legacy paths

## Related authority docs

- [ARCHITECTURE_CHARTER.md](../../concepts/architecture/ARCHITECTURE_CHARTER.md)
- [DOCUMENTATION_AUTHORITY_RESOLVER.md](../../concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md)
- [ADR-011: Convention-Based Spec Verification](../../adr/011-convention-based-spec-verification.md)
