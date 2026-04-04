---
name: ci-scope-and-timing
description: Understand CI scope boundaries and timing to avoid wasting cycles. Use when CI is slow, failing on unrelated checks, or when you need to add/modify CI gates. Prevents narrow fixes from paying broad CI tax.
---

# CI Scope and Timing

## CI Architecture

The CI pipeline has 4 consolidated jobs (was 74 micro-jobs):

| Job | What it runs | When |
|---|---|---|
| `static-validation` | All scripts in `ci-scripts-static.txt` via parallel runner | Every PR |
| `tutor-config-tests` | Tutor rendering + idempotency | Every PR |
| `security-scans` | TruffleHog (HEAD only) + pip-audit | Every PR |
| `test-coverage` | Python tests with coverage | Every PR |

## Script Inventories

| Inventory | Authority | Runs in CI? | Purpose |
|---|---|---|---|
| `ci_static_inventory` | `scripts/governance/script-registry.yaml` | Yes (static-validation job) | Offline/static verification |
| `ci_runtime_inventory` | `scripts/governance/script-registry.yaml` | No (manual) | Runtime/cluster-dependent checks |

Derived files (regenerated, never hand-edited):
- `.github/ci-scripts-static.txt` — full list
- `.github/ci-scripts-static-shard-01.txt` through `shard-03.txt` — parallel shards

## Adding a New CI Check

1. Write the script in `scripts/qa/verify-*.sh`
2. Register in `scripts/governance/script-registry.yaml` under `ci_static_inventory.entries`
3. Regenerate: `python3 scripts/governance/generate-ci-static-inventory.py --write`
4. Commit all three: script + registry + generated `.txt`
5. Scripts get 120s timeout by default via `run-scripts-parallel.sh`

## When CI Is Slow or Failing

### Classify the failure first

| Signal | Classification | Action |
|---|---|---|
| Your script fails deterministically | Code defect | Fix the script |
| Unrelated scripts fail | Infrastructure or stale test | Do NOT fix unrelated scripts in your PR |
| CI queued/hung past threshold | Infra block | Record in status docs, do not keep rerunning |
| Main is red | Cascade failure | Stabilize main FIRST with a targeted fix |

### Do NOT

- Bundle unrelated fixes to "make CI green"
- Retry failing CI hoping for flake resolution without investigation
- Add broad CI tax for narrow release-tooling fixes
- Skip `verify-new-ci-static-entries.sh` when adding scripts

## Script Governance Rules

- Every `scripts/qa/verify-*.sh` must be in the script registry
- `verify-script-governance-orphans.sh` catches unregistered scripts
- `verify-script-governance-census.sh` catches registry/filesystem drift
- New dangerous scripts must be registered in `DANGEROUS_SCRIPTS.md`

## Timing Rule

```
Local preflight (<5 min) → CI validates → Never debug on main
```

One hypothesis per PR. If CI fails, fix on the feature branch. Do not push
speculative fixes to main.

## Heavy Builds

`tutor images build` must run on `mereka-k8s-heavy-builders` ARC runners only:
- 4CPU/12GB + DinD sidecar
- PVC caches: `arc-docker-cache` (50Gi), `arc-dep-cache` (10Gi)

Lightweight checks run on `mereka-k8s-runners` (2CPU/4GB).

## References

- [CI_CD_RUNNERS.md](docs/ops/ci-cd/CI_CD_RUNNERS.md)
- [CI_OPTIMIZATION_TRACKER.md](docs/status/active/CI_OPTIMIZATION_TRACKER.md)
