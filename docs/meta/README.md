# Docs Meta Surface
_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-03-09 • Status: canonical_

This directory contains contributor-facing documentation program material, templates, and governance support docs for the repository. Use it when you are coordinating the docs system itself rather than reading product, platform, or runtime guidance.

## Start here

| If you need to... | Start here | Then go deeper in |
|---|---|---|
| Understand the active docs-improvement program | [`docs-program/README.md`](docs-program/README.md) | `docs/DOCS_REMEDIATION_PLAN_AND_TRACKER.md` |
| Work on ADR process and authoring flow | [`adr-process/README.md`](adr-process/README.md) | `docs/guides/standards/**` for writing standards |
| Reuse a docs-system template | [`templates/README.md`](templates/README.md) | The specific template file |
| Check standing orders for maintainers or agents | [`standing-orders/README.md`](standing-orders/README.md) | The specific standing-order doc |

## Use this directory for

- docs program tracking and move ledgers
- contributor-facing ADR process material
- templates used by the docs operating system
- standing orders and governance handoff material for maintainers and agents

## Common contributor routes

| Question | Start here | Move elsewhere when... |
|---|---|---|
| "How is the docs system itself being maintained?" | `docs-program/README.md` | You need public reader guidance, then use `docs/README.md` |
| "How do I write or review an ADR?" | `adr-process/README.md` | You need durable writing standards, then use `docs/guides/standards/**` |
| "Where is the reusable shape for this artifact?" | `templates/README.md` | You need the final live artifact, then use the canonical root for that artifact type |
| "What standing instructions govern my lane?" | `standing-orders/README.md` | You need runtime operations, then use `docs/ops/**` |

## Do not use this directory for

- accepted ADR decisions, which belong in `docs/adr/**`
- living architecture standards, which belong in `docs/concepts/architecture/**`
- operator runtime procedures, which belong in `docs/ops/**`

## What this root is not

- Not the front door for ordinary product or platform reading.
- Not the place for live runtime status or proof.
- Not a substitute for the authority resolver or the architecture charter.

## Review standard

- A file here should help maintain the documentation system, not the product/runtime itself.
- If the content becomes useful to ordinary operators or readers, move it to `docs/guides/**`, `docs/ops/**`, or another canonical reader root.
- If the content becomes durable technical law, move it to `docs/concepts/architecture/**`.
