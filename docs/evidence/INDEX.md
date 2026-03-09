# Evidence Index
_Audience: Contributors • Owner: Platform Team • Last verified: 2026-03-08 • Status: canonical_

This is the active evidence root.

## Scope

Use `docs/evidence/**` for proof packs, validation bundles, screenshots, exported traces, and other material that demonstrates a claim or gate outcome.

## Start here

- Need proof that a runtime or gate claim is true:
  - start with the relevant domain subroot under `docs/evidence/**`
- Need to know how an evidence pack should be written:
  - read the [Evidence Pack Standard](../guides/standards/EVIDENCE_PACK_STANDARD.md)
- Need to know whether evidence is the right artifact type:
  - read the [Documentation Authority Resolver](../concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md)

## Common routes

| If your question is... | Start here | Move elsewhere when... |
|---|---|---|
| "Where is the proof that this claim is true?" | The relevant domain subroot under `docs/evidence/**` | You actually need live rollout state, not proof, then use `docs/status/**` |
| "How should I structure this pack?" | [Evidence Pack Standard](../guides/standards/EVIDENCE_PACK_STANDARD.md) | You are writing a reusable template, then use `docs/meta/templates/**` |
| "Does this belong in evidence at all?" | [Documentation Authority Resolver](../concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md) | The artifact is really a procedure or status note |

## Authority rule

- new active evidence belongs under `docs/evidence/**`
- top-level `evidence/**` is superseded compatibility only
- `docs/archive/evidence/**` is cold-only historical context

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

## What belongs here

- proof that a gate passed or failed
- proof that a runtime condition is true
- proof that a migration, rollout, or verification step happened

## What does not belong here

- long operator procedures
- living architecture policy
- active status reporting
- closure memos that summarize history without proving a concrete claim

## Current active domains

- `docs/evidence/operations/`

## Standards

- [Evidence Pack Standard](../guides/standards/EVIDENCE_PACK_STANDARD.md)
- [Documentation Authority Resolver](../concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md)

## Review standard

- A file here should prove a concrete claim, gate, or runtime condition.
- If a document cannot answer “what claim does this prove?” it probably belongs in `docs/status/**`, `docs/ops/**`, or `docs/meta/**` instead.
- Evidence should stay tightly scoped, linkable, and reusable by reviewers.
