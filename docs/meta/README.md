# Docs Meta Surface
_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-04-14 • Status: canonical_

This directory contains contributor-facing documentation program material,
templates, and governance support docs for the repository. Use it when you are
coordinating the docs system itself rather than reading product, platform, or
runtime guidance.

The docs-program subroot now carries an explicit authority registry for its
root-level surfaces. Use that registry and the current boards there instead of
reconstructing “current” versus “historical” status from prose alone.

## Start here

| If you need to... | Start here | Then go deeper in |
|---|---|---|
| Understand the active docs review-and-hardening program | [`docs-program/README.md`](docs-program/README.md) | [`docs-program/POST_REBASE_INTAKE_2026-04-13.md`](docs-program/POST_REBASE_INTAKE_2026-04-13.md) |
| Work on ADR process and authoring flow | [`adr-process/README.md`](adr-process/README.md) | `docs/guides/standards/**` for writing standards |
| Reuse a docs-system template | [`templates/README.md`](templates/README.md) | The specific template file |
| Check standing orders for maintainers or agents | [`standing-orders/README.md`](standing-orders/README.md) | The specific standing-order doc |

## Use this directory for

- docs program tracking and move ledgers
- contributor-facing ADR process material
- templates used by the docs operating system
- standing orders and governance handoff material for maintainers and agents

## Do not use this directory for

- accepted ADR decisions, which belong in `docs/adr/**`
- stable architecture front doors and models, which belong in `docs/architecture/**`
- operator runtime procedures, which belong in `docs/ops/**`

## What this root is not

- Not the front door for ordinary product or platform reading.
- Not the place for live runtime status or proof.
- Not a substitute for the documentation index or the platform authority map.
- Not a shortcut around the active docs-program intake/review control surfaces.
