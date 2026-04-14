# Docs Program
_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-04-14 • Status: canonical_

Use this root for the active documentation review-and-hardening program:
intake control surfaces, deterministic collapse inventories, metadata
contracts, and the bounded docs-program surfaces that still guide work.
Start here when you are coordinating or reviewing documentation work across
multiple slices. Do not use this root for reader-facing product guidance or
runtime operations.

Root-level docs-program authority is declared in
[`authority-registry.v1.yaml`](authority-registry.v1.yaml). The intake board,
review board, and milestone ledger are execution views over that registry, not
parallel truth stores.

## Start Here

| If you need to... | Read this first | Then go deeper in |
|---|---|---|
| Understand the active docs review-and-hardening lane | [`POST_REBASE_INTAKE_2026-04-13.md`](POST_REBASE_INTAKE_2026-04-13.md) | [`REVIEW_HARDENING_BOARD_2026-04-13.md`](REVIEW_HARDENING_BOARD_2026-04-13.md) |
| Check which root-level docs-program surfaces are allowed to act current | [`authority-registry.v1.yaml`](authority-registry.v1.yaml) | [`../../reference/generated/docs-program-authority-summary.md`](../../reference/generated/docs-program-authority-summary.md) |
| Understand where docs were moved and why | [`root-collapse/README.md`](root-collapse/README.md) | The specific collapse map for that losing root |
| Review the deterministic collapse inventories for losing roots | [`root-collapse/README.md`](root-collapse/README.md) | The specific collapse map for that root |
| Understand the metadata model for canonical docs and generated surfaces | [`metadata/METADATA_MODEL.md`](metadata/METADATA_MODEL.md) | The schema, taxonomy, and class map in `metadata/` |
| Check the current tranche sequence and completed outcomes | [`POST_REBASE_INTAKE_2026-04-13.md`](POST_REBASE_INTAKE_2026-04-13.md) | [`DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md`](DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md) |
| Review active docs-program bundles that still matter | The relevant bundle in this root | [`../README.md`](../README.md) for broader meta surfaces |

## Use this directory for

- active intake, review, and milestone control surfaces
- topology collapse guidance and debt tracking
- deterministic collapse inventories and metadata contracts
- bounded docs-program bundles that are still operationally relevant

## What This Root Is Not

- Not the front door for general readers. Use [`../../README.md`](../../README.md) first.
- Not the place for runtime procedures. Use [`../../ops/README.md`](../../ops/README.md).
- Not the place for architecture law. Use [`../../architecture/README.md`](../../architecture/README.md).
- Not the place to treat historical packet docs as live authority; use the
  intake board, review board, and milestone ledger first.
