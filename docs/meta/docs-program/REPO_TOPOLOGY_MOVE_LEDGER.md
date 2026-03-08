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
| legacy ADR process readme | `docs/meta/adr-process/README.md` |
| legacy ADR authoring guide | `docs/meta/adr-process/adr-authoring.md` |
| legacy ADR review guide | `docs/meta/adr-process/adr-review.md` |
| legacy ADR rollout guide | `docs/meta/adr-process/adr-rollout.md` |
| legacy generated ADR bundles | `generated/adr-bundles/*` |
| legacy generated ADR graph | `generated/graphs/adr-graph.json` |
| legacy generated ADR decision map | `generated/decision-maps/adr-decision-map.md` |
| legacy generated ADR readme | `generated/adr-bundles/README.md` |

## Next move candidates

### Low-risk next

- legacy evidence index -> `docs/evidence/INDEX.md`
- legacy evidence manifest -> `docs/evidence/index.yaml`
- legacy verification runtime baseline -> `verification/baselines/runtime_local_fast_baseline.json`
- legacy QA script catalog -> `verification/catalogs/QA_SCRIPT_CATALOG.yml`
- legacy AC verification strategy matrix -> `verification/catalogs/AC_VERIFICATION_STRATEGY_MATRIX.yml`

### Requires path-repair first

- `docs/qa/*`
- `generated/catalogs/docs-catalog.json`
- `docs/DOCS_REMEDIATION_PLAN_AND_TRACKER.md`
- `docs/status/active/NEXT10_TASKS.md`
- `reports/2026/sprints/*`
- `docs/evidence/observability`
- broad `docs/verification/*` moves referenced by scripts

## Freeze rules

Until Wave 2 is complete:

- New authored docs go only into `docs/adr/`, `docs/concepts/architecture/`, `docs/guides/`, `docs/ops/`, `docs/reference/`, `docs/policies/`, `docs/evidence/`, `docs/status/`, or `docs/meta/`
- New generated outputs go only into `generated/`
- New proof goes only into `docs/evidence/`
- New verification artifacts go only into `verification/`
- New dated audits, status snapshots, and closures go only into `reports/YYYY/`
- Do not add new files to `docs/operations/`, `docs/branding/`, `docs/onboarding/`, `docs/runbooks/`, `docs/architecture/`, `docs/ci-cd/`, or `docs/migrations/`
