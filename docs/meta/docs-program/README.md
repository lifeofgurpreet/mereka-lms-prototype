# Docs Program
_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-03-09 • Status: canonical_

Use this root for the active documentation improvement program: remediation plans, topology ledgers, implementation roadmaps, and bounded program bundles that still guide work. Start here when you are coordinating or reviewing documentation work across multiple slices. Do not use this root for reader-facing product guidance or runtime operations.

## Start Here

| If you need to... | Read this first | Then go deeper in |
|---|---|---|
| Understand the current docs remediation direction | [`../../DOCS_REMEDIATION_PLAN_AND_TRACKER.md`](../../DOCS_REMEDIATION_PLAN_AND_TRACKER.md) | [`IMPLEMENTATION_ROADMAP.md`](IMPLEMENTATION_ROADMAP.md) |
| Understand where docs were moved and why | [`REPO_TOPOLOGY_MOVE_LEDGER.md`](REPO_TOPOLOGY_MOVE_LEDGER.md) | [`boundary-debt-manifest.md`](boundary-debt-manifest.md) |
| Review the deterministic collapse inventories for losing roots | [`root-collapse/README.md`](root-collapse/README.md) | The specific collapse map for that root |
| Check the current execution roadmap | [`IMPLEMENTATION_ROADMAP.md`](IMPLEMENTATION_ROADMAP.md) | [`SPEC_COVERAGE.md`](SPEC_COVERAGE.md) |
| Understand the architecture-governance rework as a docs program | [`ARCHITECTURE_GOVERNANCE_OVERLAY.md`](ARCHITECTURE_GOVERNANCE_OVERLAY.md) | [`FOUNDATIONS_PROGRAM.md`](FOUNDATIONS_PROGRAM.md) and [`PROGRAM_UPDATE_V2_BRIEF.md`](PROGRAM_UPDATE_V2_BRIEF.md) |
| Review active docs program bundles | The relevant bundle in this root | [`../README.md`](../README.md) for broader meta surfaces |

## Use this directory for

- active docs program plans
- move ledgers and topology debt tracking
- implementation roadmaps for documentation work
- architecture-governance program material that is no longer living architecture law
- bounded docs program bundles that are still operationally relevant

## Common contributor routes

| Question | Start here | Why |
|---|---|---|
| "What is the current cleanup or remediation wave?" | [`../../DOCS_REMEDIATION_PLAN_AND_TRACKER.md`](../../DOCS_REMEDIATION_PLAN_AND_TRACKER.md) | That is the live top-level program tracker |
| "Where did a root or file move?" | [`REPO_TOPOLOGY_MOVE_LEDGER.md`](REPO_TOPOLOGY_MOVE_LEDGER.md) | It is the reader-facing move ledger |
| "How was a losing root collapsed?" | [`root-collapse/README.md`](root-collapse/README.md) | The collapse maps are the deterministic inventory |
| "What still feels messy in the docs system?" | [`boundary-debt-manifest.md`](boundary-debt-manifest.md) | It tracks remaining structural debt directly |

## What This Root Is Not

- Not the front door for general readers. Use [`../../README.md`](../../README.md) first.
- Not the place for runtime procedures. Use [`../../ops/README.md`](../../ops/README.md).
- Not the place for architecture law. Use [`../../concepts/architecture/README.md`](../../concepts/architecture/README.md).

## Review standard

- A file here should help maintain or review the docs system itself.
- If it explains how to do real platform work, move it to `docs/ops/**` or `docs/guides/**`.
- If it defines enduring technical law, move it to `docs/concepts/architecture/**`.
