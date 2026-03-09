# Documentation Authority Resolver
_Audience: Contributors • Owner: Platform Team • Last verified: 2026-03-08 • Status: canonical_

This document resolves documentation split-brain. If two paths appear to answer the same question, use this resolver to determine the winner.

## Fast routing

Use this table before reading or writing:

| If your question is about... | Start here |
| --- | --- |
| Intended behavior or acceptance criteria | `specs/**` |
| Current architecture rules or standards | `docs/concepts/architecture/**` |
| How to operate or recover the platform | `docs/ops/**` |
| Why a technical decision was made | `docs/adr/**` |
| How contributors or users should do something | `docs/guides/**` |
| Reference detail or policy boundaries | `docs/reference/**`, `docs/policies/**` |
| Proof that something is true | `docs/evidence/**` |
| Current status, readiness, or migration posture | `docs/status/**` |

## Resolver order

Apply these rules in order:

1. If the question is about intended behavior, `specs/**` wins.
2. If the question is about living architecture policy or standards, `docs/concepts/architecture/**` wins.
3. If the question is about operator procedure, `docs/ops/**` wins.
4. If the question is about accepted or superseded technical decisions, `docs/adr/**` wins.
5. If the question is about user or contributor guidance, `docs/guides/**` wins.
6. If the question is about supporting reference or policy, `docs/reference/**` and `docs/policies/**` win.
7. If the question is about proof, `docs/evidence/**` wins.
8. If the question is about current reporting or open status, `docs/status/**` wins.
9. If the path is under `docs/archive/**`, it is historical context only and MUST NOT override active roots.

## What to do when two docs disagree

1. Identify the artifact kind first.
2. Use the winning root for that artifact kind.
3. Treat the losing root as stale, transitional, or historical unless it clearly points back to the winner.
4. Fix the losing path in the same change if you are already touching this area.

If a transitional or archive path contradicts a winning root, the winning root governs.

## Root winners

| Artifact kind | Canonical root | Transitional roots | Cold / historical root |
| --- | --- | --- | --- |
| Living architecture / standards | `docs/concepts/architecture/**` | `docs/architecture/**` | `docs/archive/**` |
| Operator procedures | `docs/ops/**` | `docs/operations/**`, `docs/runbooks/**` | `docs/archive/**` |
| Human guidance / onboarding | `docs/guides/**` | `docs/onboarding/**`, `docs/branding/**` | `docs/archive/**` |
| Decision history | `docs/adr/**` | none | `docs/adr/historical/**`, `docs/archive/**` |
| Evidence / proof | `docs/evidence/**` | `evidence/**` | `docs/archive/evidence/**` |
| Active reporting / status | `docs/status/**` | `reports/2026/status/**`, `reports/2026/readiness/**` | `docs/archive/reports/**` |
| Specs / intended behavior | `specs/**` | none | `specs/archive/**` |

## Practical decision tests

Use these tests when you are unsure:

- If removing the file would make required system behavior ambiguous, it probably belongs in `specs/**`.
- If the file mainly helps someone operate, navigate, or understand the current system, it belongs in `docs/**`.
- If the file proves a runtime fact, it belongs in `docs/evidence/**`.
- If the file reports current posture or blockers, it belongs in `docs/status/**`.

## Metadata rule

- In-document metadata is the source of truth.
- `docs/catalog.json` is derived output. It MUST be generated from `generated/catalogs/docs-catalog.json` or mechanically checked against document metadata.
- A document with missing required metadata MUST NOT be treated as canonical.

## Catalog rule

`docs/catalog.json` does not exist to create a second authority plane. Its only valid purposes are:

- generated navigation
- search indexing
- lightweight tooling summaries

If catalog output disagrees with in-document metadata, the document metadata wins and the catalog MUST be regenerated.
Use `python3 tools/docs/verify/build-doc-catalog.py` as the compiler entrypoint for
`generated/catalogs/docs-catalog.json` and `docs/catalog.json`.

Operationally, the catalog now has two enforced layers:

- `generated/catalogs/docs-catalog.json` is the maintained source catalog for winning roots.
- `docs/catalog.json` is the derived mirror and MUST match the generated source exactly.

If a change touches a winning-root doc and does not also update `generated/catalogs/docs-catalog.json`, the change is invalid.

## Testmap rule

Testmaps are generated verification mapping artifacts.

- `@covers` annotations and spec metadata are the true source.
- `specs/testmaps/**` is a compatibility location until migration to `specs/_generated/testmaps/**` is complete.
- Manual edits to generated testmaps are not authoritative and must be treated as drift.

## Terms

- `canonical`: active root that new readers and new links must target
- `transitional`: compatibility root kept temporarily to avoid breakage; content should collapse to stubs
- `historical`: retained decision or migration history that is still meaningful but not part of the default hot path
- `archive`: cold storage; useful for audit, provenance, or incident reconstruction, but not active truth

## Stub rules for transitional roots

Transitional files MUST:

- fit on one screen
- say `Status: superseded` or equivalent frontmatter
- include `superseded_by`
- point to the canonical replacement path
- avoid substantive duplicated guidance

## Link policy

Canonical docs MUST NOT point readers to transitional or archive roots unless the link is explicitly marked as legacy, historical, or superseded context.

Examples:

- `docs/ops/**` SHOULD link to `docs/reference/**`, `docs/policies/**`, `docs/evidence/**`, and `docs/status/**`
- `docs/ops/**` MUST NOT use `docs/operations/**` as live procedure authority
- `docs/concepts/architecture/**` MUST NOT depend on `docs/architecture/**` as current law

## Review rule

If a reviewer cannot tell which root wins without reading multiple documents, the docs are still split-brain and the change is incomplete.

## Wave 2 resolver decisions

These are locked for this wave:

- `docs/ops/**` is the canonical operator-doc root
- `docs/operations/**` is stub-only transitional
- `docs/evidence/**` is the single active evidence root
- `docs/status/**` is the single active status root
- `docs/concepts/architecture/**` is the canonical architecture narrative and living standards root
- `docs/architecture/**` is transitional if retained
- proposed `ADR-034` to `ADR-041` must leave the accepted ADR hot path and live in `docs/adr/rfc/`

## Local validation entrypoints

```bash
tools/docs/verify/verify-docs-policy.sh
python3 tools/docs/verify/verify-doc-catalog-governance.py --range HEAD~1...HEAD
python3 tools/docs/verify/verify-doc-catalog-health.py --max-stale-days 45
python3 tools/docs/verify/scan-doc-catalog-residue.py --fail-on-residue
python3 scripts/qa/spec-tools/spec_verify.py specs/ --scan-dirs tests/ scripts/ --repo-root .
```
