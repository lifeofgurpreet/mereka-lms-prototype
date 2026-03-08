# Repository Topology Move Ledger

## Intent

Converge the repository toward this top-level knowledge model:

- `docs/` for active, hand-authored, reader-facing docs
- `specs/` for normative requirements and delivery contracts
- `verification/` for claim/check/status artifacts
- `evidence/` for proof artifacts
- `reports/` for dated analysis and closures
- `generated/` for derived artifacts
- `tools/` for automation
- `archive/` for inactive retained material

## Wave model

### Wave 1

- Move artifacts that clearly do not belong in `docs/`
- Reserve stable homes for generated outputs and ADR process docs
- Keep mixed buckets in place until they are sampled and split by document kind

### Wave 2

- Dissolve transitional buckets such as `docs/ops/`, `docs/operations/`, `docs/branding/`, `docs/ci-cd/`, `docs/concepts/`, and `docs/migrations/`
- Add forwarding stubs where needed
- Tighten CI enforcement after path churn settles

## High-confidence moves already applied

| From | To |
|---|---|
| `docs/runbooks/README.md` | `docs/meta/adr-process/README.md` |
| `docs/runbooks/adr-authoring.md` | `docs/meta/adr-process/adr-authoring.md` |
| `docs/runbooks/adr-review.md` | `docs/meta/adr-process/adr-review.md` |
| `docs/runbooks/adr-rollout.md` | `docs/meta/adr-process/adr-rollout.md` |
| `docs/adr/_generated/bundles/*` | `generated/adr-bundles/*` |
| `docs/adr/_generated/graph.json` | `generated/graphs/adr-graph.json` |
| `docs/adr/_generated/decision-map.md` | `generated/decision-maps/adr-decision-map.md` |
| `docs/adr/_generated/README.md` | `generated/adr-bundles/README.md` |

## Next move candidates

### Low-risk next

- `docs/evidence/README.md` -> `evidence/README.md`
- `docs/evidence/index.yaml` -> `evidence/index.yaml`
- `docs/verification/runtime_local_fast_baseline.json` -> `verification/baselines/runtime_local_fast_baseline.json`
- `docs/verification/QA_SCRIPT_CATALOG.yml` -> `verification/catalogs/QA_SCRIPT_CATALOG.yml`
- `docs/verification/AC_VERIFICATION_STRATEGY_MATRIX.yml` -> `verification/catalogs/AC_VERIFICATION_STRATEGY_MATRIX.yml`

### Requires path-repair first

- `docs/qa/*`
- `generated/catalogs/docs-catalog.json`
- `docs/DOCS_REMEDIATION_PLAN_AND_TRACKER.md`
- `docs/status/active/NEXT10_TASKS.md`
- `docs/sprints/*`
- `docs/evidence/observability`
- broad `docs/verification/*` moves referenced by scripts

## Freeze rules

Until Wave 2 is complete:

- New authored docs go only into `docs/adr/`, `docs/architecture/`, `docs/guides/`, `docs/runbooks/`, `docs/reference/`, `docs/policies/`, `docs/standards/`, or `docs/meta/`
- New generated outputs go only into `generated/`
- New proof goes only into `evidence/`
- New verification artifacts go only into `verification/`
- New dated audits, status snapshots, and closures go only into `reports/YYYY/`
- Do not add new files to `docs/ops/`, `docs/operations/`, `docs/branding/`, `docs/ci-cd/`, `docs/concepts/`, `docs/onboarding/`, or `docs/migrations/`
