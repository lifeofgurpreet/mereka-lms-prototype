# Phantom-Metric Audit

## What

A **phantom metric** is a metric name referenced in a PrometheusRule `expr` that
does NOT exist in the live Prometheus `__name__` inventory. Rules referencing
phantom metrics cannot fire — they are dead detection logic.

## Why

On 2026-04-21 the Velero BackupStorageLocation `Unavailable` alert was
discovered to have been dead for ~a week on prod, while DR backups silently
stopped. Root cause: the alert expression referenced
`velero_backup_storage_location_available` — a metric that does not exist
(the real KSM-CRD metric is `velero_bsl_info`). See bead `mereka-lms-krco`
and the full audit bead `mereka-lms-33d8`.

That's a failure class, not a one-off. 157 rule entries across the prod
estate referenced phantom metrics when the audit ran.

## Files

| File | Purpose |
|---|---|
| `../audit-prometheus-phantom-metrics.py` | Audit tool (live or offline modes) |
| `baseline-metric-names.json` | Snapshot of the Prometheus `__name__` inventory used as the CI baseline |
| `refresh-baseline.sh` | Regenerate `baseline-metric-names.json` from a live cluster |

## Modes

```bash
# 1. Live against a cluster (needs kubectl + network reach)
./scripts/qa/audit-prometheus-phantom-metrics.py --context rke2-prod --format md

# 2. Offline for CI (snapshot + rendered kustomize)
kubectl kustomize deploy/k8s/overlays/local/ > /tmp/rendered.yaml
# (wrap kustomize into a PrometheusRule-only JSON doc — see CI wiring below)
./scripts/qa/audit-prometheus-phantom-metrics.py \
  --rules-file /tmp/rules.json \
  --names-file scripts/qa/phantom-audit/baseline-metric-names.json \
  --format check
```

## Formats

| `--format` | Output |
|---|---|
| `md` | Full markdown report per rule object |
| `summary` | One-screen counters — use in PR comments |
| `jsonl` | Machine-readable record per phantom rule |
| `check` | Exit 1 if any non-speculative phantom is found |

## Speculative label convention

When you intentionally ship an alert referencing a metric that isn't yet emitted
(e.g. instrumentation planned for a later sprint), mark the rule with:

```yaml
- alert: ContentLibraryExportLarge
  expr: content_library_export_size_bytes > 1e9
  for: 5m
  labels:
    severity: info
    speculative: "true"   # exempts this rule from the phantom-metric gate
```

The `check` mode treats such alerts as exempt. Rules WITHOUT this label must
reference metrics that exist in the baseline.

## Refresh cadence

`baseline-metric-names.json` is a committed snapshot. It should be refreshed:

- Quarterly (baseline drift)
- When a new exporter / scrape target is deployed
- When an alert author needs a metric that doesn't exist in the current baseline

To refresh:

```bash
./scripts/qa/phantom-audit/refresh-baseline.sh --context rke2-prod
git add scripts/qa/phantom-audit/baseline-metric-names.json
git commit -m "chore(qa): refresh phantom-audit baseline"
```

## CI integration (current state)

Registered as a `ci_runtime_inventory` entry in `scripts/governance/script-registry.yaml`
(runtime-only; not part of offline static-validation CI because it depends on a
snapshot comparison against checked-in state). Intended future wiring:

1. New workflow step renders `kubectl kustomize deploy/k8s/overlays/local/`
2. Extracts PrometheusRule objects into a temp JSON
3. Runs `audit-prometheus-phantom-metrics.py --format check`
4. Fails the build if any non-speculative phantom is found

Until that workflow is added, run `--format check` manually as part of release
gates.

## Classification

Each phantom is classified:

| Kind | Meaning |
|---|---|
| `LIKELY_TYPO` | Close match exists in live inventory (trigram Jaccard ≥0.6). Alert author expected it to fire; probable typo or upstream rename. **Highest severity** — fix it. |
| `FAMILY_EXISTS` | Metric family prefix has live siblings, but the exact name doesn't. Often means exporter collector is disabled, or the metric was renamed across exporter versions. |
| `NO_TRACE` | No trace of this metric anywhere. Speculative alert, missing exporter, or app not yet instrumented. Either finish the instrumentation or add `speculative: "true"`. |

## Related artifacts

- `reports/2026/audits/PHANTOM_METRIC_AUDIT_2026-04-21.md` — first full estate audit
- Bead `mereka-lms-33d8` — audit follow-up tracker
- Bead `mereka-lms-krco` — origin incident
