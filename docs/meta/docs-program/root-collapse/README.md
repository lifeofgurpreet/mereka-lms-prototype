# Root Collapse Maps
_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-03-09 • Status: canonical_

Use this directory for the machine-readable collapse inventories that drive transitional-root closure. Start here when you need to know where a losing-root document was routed, why it moved, and whether the convergence wave treated it as a move, a stub, or a frozen compatibility surface.

## Collapse Model

The docs-program collapse lane converges the repository toward this top-level
knowledge model:

- `docs/` for active, hand-authored, reader-facing docs
- `specs/` for normative requirements and delivery contracts
- `verification/` for claim/check/status artifacts
- `evidence/` for proof artifacts
- `reports/` for dated analysis and closures
- `generated/` for derived artifacts
- `tools/` for automation
- `archive/` for inactive retained material

## Start Here

| If you need to... | Read this first |
|---|---|
| Understand the target knowledge model, convergence waves, and freeze rules for root collapse | This README |
| See how `docs/operations/**` was collapsed into winning roots | [`docs-operations-collapse-map.yaml`](docs-operations-collapse-map.yaml) |
| See how `docs/architecture/**` was collapsed | [`docs-architecture-collapse-map.yaml`](docs-architecture-collapse-map.yaml) |
| See how legacy `specs/testmaps/**` is treated | [`docs-legacy-testmaps-collapse-map.yaml`](docs-legacy-testmaps-collapse-map.yaml) |
| Review the remaining transitional roots that were collapsed to stubs | [`docs-runbooks-collapse-map.yaml`](docs-runbooks-collapse-map.yaml), [`docs-onboarding-collapse-map.yaml`](docs-onboarding-collapse-map.yaml), [`docs-branding-collapse-map.yaml`](docs-branding-collapse-map.yaml) |
| Review the top-level evidence collapse | [`docs-top-level-evidence-collapse-map.yaml`](docs-top-level-evidence-collapse-map.yaml) |

## Wave Model

### Wave 1

- Move artifacts that clearly do not belong in `docs/`
- Reserve stable homes for generated outputs and ADR process docs
- Keep mixed buckets in place until they are sampled and split by document kind

### Wave 2

- Dissolve transitional buckets such as the legacy ops root, legacy operations
  root, legacy branding root, legacy CI/CD root, legacy concepts root, and
  legacy migrations root
- Add forwarding stubs where needed
- Tighten CI enforcement after path churn settles

## Freeze Rules

Until Wave 2 is complete:

- New authored docs go only into `docs/adr/`, `docs/concepts/architecture/`,
  `docs/guides/`, `docs/ops/`, `docs/reference/`, `docs/policies/`,
  `docs/evidence/`, `docs/status/`, or `docs/meta/`
- New generated outputs go only into `generated/`
- New proof goes only into `docs/evidence/`
- New verification artifacts go only into `verification/`
- New dated audits, status snapshots, and closures go only into `reports/YYYY/`
- Do not add new files to retired transitional roots such as the legacy
  operations, branding, onboarding, runbooks, CI/CD, or migrations roots

## Use this directory for

- deterministic inventories of losing-root files
- explicit destination mappings for convergence work
- reviewer traceability during root-collapse changes
- proof that transitional roots were collapsed intentionally rather than ad hoc

## How to use the maps

1. Pick the losing root you are reviewing.
2. Read the matching collapse map before moving or stubbing anything.
3. Confirm the entry for the file names the destination root, destination path, and action.
4. Only then touch the canonical file and leave the transitional stub behind.

## Review standard

- A collapse map should be complete enough that a reviewer can explain every move without re-deriving the routing logic.
- If a live file in a losing root is not represented here, the convergence work is incomplete.
- If a map entry still points to a losing root, fix the inventory before moving files.

## What this directory is not

- Not the primary architecture front door. Use [`../../../architecture/README.md`](../../../architecture/README.md) and [`../../../architecture/PLATFORM_AUTHORITY_MAP.md`](../../../architecture/PLATFORM_AUTHORITY_MAP.md).
- Not the place for runtime procedures or architecture law.
